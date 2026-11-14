"""One event watcher for current catalog content; no selection or render polling."""
import ctypes, json, os, select, struct, time
from .catalog import Catalog

def watch(paths):
    catalog=Catalog(paths)
    libc=ctypes.CDLL(None,use_errno=True)
    fd=libc.inotify_init1(os.O_NONBLOCK|os.O_CLOEXEC)
    if fd<0: raise OSError(ctypes.get_errno(),'inotify unavailable; use explicit Refresh')
    watches=[]; config_watch=None
    def subscribe():
        nonlocal config_watch
        for wd in watches: libc.inotify_rm_watch(fd,wd)
        watches.clear()
        paths.data.mkdir(parents=True,exist_ok=True)
        paths.config.mkdir(parents=True,exist_ok=True)
        # Only current registered revisions, never every retained rollback directory.
        try: roots=[root for _,root in catalog.roots()]
        except (OSError,ValueError): roots=[paths.base/'themes']
        directories={paths.data,paths.config}
        pending=list(roots)
        directories.update(root.parent for root in roots[1:]) # installed catalog.json
        while pending and len(directories)<1024:
            root=pending.pop()
            if not root.is_dir() or root.is_symlink() or root in directories:continue
            directories.add(root)
            with os.scandir(root) as entries:
                for entry in entries:
                    if entry.is_dir(follow_symlinks=False):pending.append(root/entry.name)
                    if len(pending)+len(directories)>=1024:break
        for directory in directories:
            wd=libc.inotify_add_watch(fd,os.fsencode(directory),0x8|0x80|0x100|0x200|0x400|0x800)
            if wd>=0:watches.append(wd)
            if directory==paths.config:config_watch=wd
        try:
            while os.read(fd,65536):pass
        except BlockingIOError:pass
    def restructuring(buffer):
        offset=0;refresh=False;changed=False
        while offset+16<=len(buffer):
            wd,mask,_,length=struct.unpack_from('iIII',buffer,offset)
            name=buffer[offset+16:offset+16+length].split(b'\0',1)[0]
            offset+=16+length
            if wd==config_watch and name!=b'theme-overrides.json' and not mask&0xc00:continue
            changed=True
            refresh|=name==b'registry.json' or bool(mask&0x40000000) or bool(mask&0xc00)
        return refresh,changed
    def publish():
        try:value={'ok':True,'catalog':catalog.list()}
        except Exception as e:value={'ok':False,'error':str(e),'catalog':[]}
        print(json.dumps(value),flush=True)
    try:
        subscribe();publish()
        while True:
            select.select([fd],[],[])
            refresh,changed=restructuring(os.read(fd,65536));time.sleep(.15)
            try:
                while True:
                    more_refresh,more_changed=restructuring(os.read(fd,65536));refresh|=more_refresh;changed|=more_changed
            except BlockingIOError:pass
            if refresh:subscribe()
            if changed:publish()
    finally:os.close(fd)
