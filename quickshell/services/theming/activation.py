"""Serialized, journaled publication; active.json is the observable commit point."""
import base64, hashlib, json, subprocess, time
from pathlib import Path
from .appearance import DesktopAppearance
from .catalog import Catalog
from .color import check_schemes
from .storage import atomic, lock, read_json, remove
from .validation import ROLES, validate

class Compositor:
    def call(self, args):
        r=subprocess.run(['hyprctl',*args],capture_output=True,text=True,timeout=5,check=True)
        return r.stdout.strip()
    def errors(self): return set(filter(None,self.call(['configerrors']).splitlines()))
    def reload(self): self.call(['reload'])
    def check(self, baseline):
        for _ in range(3):
            time.sleep(.08)
            new=self.errors()-baseline
            if new: raise RuntimeError('Hyprland rejected colors: '+ '\n'.join(sorted(new))[:400])

def lua(colors):
    # Geometry belongs to existing compositor/user configuration, never a color pack.
    return '-- Generated Wizard Material colors; no geometry or effects.\nhl.config({ general = { col = { active_border = { colors = {"rgba(%sff)"}, angle = 0 }, inactive_border = "rgba(%sff)" } } })\n' % (colors['primary'][1:],colors['outlineVariant'][1:])

class Engine:
    def __init__(self, paths, compositor=None, fault=None, appearance=None):
        self.appearance=appearance or DesktopAppearance()
        self.paths=paths; self.catalog=Catalog(paths); self.compositor=compositor or Compositor(); self.fault=fault or (lambda phase:None)
    def current(self):
        try: return self.validate_snapshot(read_json(self.paths.active))
        except (OSError,ValueError): return None
    def validate_snapshot(self, snapshot):
        validate('snapshot',snapshot)
        if any(snapshot[k]!=snapshot['selection'][k] for k in ('identity','mode','wallpaperId','revision')): raise ValueError('active: selection does not match committed snapshot')
        validate('selection',snapshot['selection']); validate('palette',{'schemaVersion':1,'schemes':{snapshot['selection']['mode']:snapshot['colors']}})
        if snapshot['schemaVersion']!=1 or snapshot['revision']!=snapshot['selection']['revision']: raise ValueError('active: invalid revision')
        return snapshot
    def capture(self):
        return {k:base64.b64encode(p.read_bytes()).decode() if p.exists() else None for k,p in self.targets().items()}
    def targets(self): return {'hypr':self.paths.hypr,'selection':self.paths.selection,'active':self.paths.active}
    def restore(self, files):
        if set(files)!=set(self.targets()): raise ValueError('recovery: incomplete saved files')
        if files.get('active'): self.validate_snapshot(json.loads(base64.b64decode(files['active'],validate=True)))
        if files.get('selection'): validate('selection',json.loads(base64.b64decode(files['selection'],validate=True)))
        errors=[]
        for key,p in self.targets().items():
            try:
                if files[key] is None:
                    if p.exists(): remove(p)
                else: atomic(p,base64.b64decode(files[key],validate=True))
            except Exception as e: errors.append(key+': '+str(e))
        if errors: raise RuntimeError('Rollback write failed: '+'; '.join(errors))
    def _reconcile(self, live):
        journal=self.paths.state/'journal.json'
        if not journal.exists(): return
        record=read_json(journal,1024*1024)
        self.validate_snapshot(record['snapshot'])
        current=self.current()
        if record.get('appearanceOnly'):
            if live: self.appearance.restore(record.get('appearance'))
            remove(journal)
            return
        if current and current['revision']==record['snapshot']['revision']:
            # Publication completed; repair selection/compositor files before finalizing.
            atomic(self.paths.selection,current['selection']); atomic(self.paths.hypr,lua(current['colors']))
            if live:
                self.compositor.reload(); self.compositor.check(set(record['baseline']))
                self.appearance.apply(current['mode'])
            atomic(self.paths.state/'previous-good.json',record['previous'])
            atomic(self.paths.state/'last-good.json',self.capture()); remove(journal)
        else:
            self.restore(record['previous'])
            if live:
                self.appearance.restore(record.get('appearance'))
                self.compositor.reload(); self.compositor.check(set(record['baseline']))
            remove(journal)
    def recover(self, live=True):
        with lock(self.paths.state/'operation.lock'):
            self._reconcile(live)
            current=self.current()
            if current:
                # Repair corrupted/missing preferences from the complete committed snapshot.
                try: selected=validate('selection',read_json(self.paths.selection))
                except (OSError,ValueError): selected=None
                if selected!=current['selection']: atomic(self.paths.selection,current['selection'])
                if live: self._sync_appearance(current)
                return {'ok':True,'revision':current['revision']}
            good=self.paths.state/'last-good.json'
            if good.exists():
                self.restore(read_json(good,1024*1024))
                if live:
                    self.compositor.reload()
                    if self.current(): self._sync_appearance(self.current())
                if self.current(): return {'ok':True,'recovered':True}
            return {'ok':True,'initialized':False}
    def snapshot(self, identity, mode=None, wallpaper=None):
        pack=self.catalog.get(identity); current=self.current()
        previous=current['selection'] if current else {}
        same=previous.get('identity')==pack['identity']
        override_file=self.paths.config/'theme-overrides.json'
        overrides=validate('overrides',read_json(override_file))['packs'].get(pack['identity'],{}) if override_file.exists() else {}
        mode=mode or overrides.get('mode') or (previous.get('mode') if previous.get('mode') in pack['modes'] else None) or pack['defaultMode']
        if mode not in pack['modes']: raise ValueError('selection.mode: unsupported mode')
        ids=[w['id'] for w in pack['wallpapers']]
        wallpaper=wallpaper or overrides.get('wallpaperId') or (previous.get('wallpaperId') if same and previous.get('wallpaperId') in ids else None) or pack['defaultWallpaper']
        if wallpaper not in ids: raise ValueError('selection.wallpaperId: missing wallpaper; refresh or select an available one')
        if overrides.get('schemes'): check_schemes(overrides['schemes'])
        colors=overrides.get('schemes',{}).get(mode,pack['schemes'][mode])
        payload={'identity':pack['identity'],'packRevision':pack['revision'],'mode':mode,'wallpaperId':wallpaper,'colors':colors,'wallpaperUrl':next(w['url'] for w in pack['wallpapers'] if w['id']==wallpaper),'logo':pack['logo']}
        revision=hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()
        selection={'schemaVersion':1,'identity':pack['identity'],'mode':mode,'wallpaperId':wallpaper,'revision':revision}
        if same and previous.get('overrides'):
            selection['overrides']=previous['overrides']
        validate('selection',selection)
        return {'schemaVersion':1,'revision':revision,'selection':selection,'id':pack['id'],'identity':pack['identity'],'name':pack['name'],'description':pack.get('description',''),'mode':mode,'wallpaperId':wallpaper,'colors':colors,'wallpaper':next(w['url'] for w in pack['wallpapers'] if w['id']==wallpaper),'logo':pack['logo'],'packVersion':pack['version'],'packRevision':pack['revision']}
    def _sync_appearance(self, snapshot):
        # Even unchanged apply/startup repairs a stale OS preference. A separate
        # journal flag distinguishes this from an active.json publication.
        previous=self.appearance.capture()
        journal=self.paths.state/'journal.json'
        atomic(journal,{'schemaVersion':1,'snapshot':snapshot,'appearanceOnly':True,'appearance':previous})
        try:
            self.appearance.apply(snapshot['mode'])
            remove(journal)
        except Exception as error:
            try:
                self.appearance.restore(previous); remove(journal)
            except Exception as rollback:
                raise RuntimeError(str(error)+'; '+str(rollback)+'; recovery journal retained. Run recover.') from error
            raise

    def _commit(self, snapshot, live):
        current=self.current()
        if current and current['revision']==snapshot['revision']:
            if live: self._sync_appearance(snapshot)
            return {'ok':True,'unchanged':True,'revision':snapshot['revision']}
        previous=self.capture(); baseline=self.compositor.errors() if live else set()
        record={'schemaVersion':1,'snapshot':snapshot,'previous':previous,'baseline':sorted(baseline),'appearance':self.appearance.capture() if live else None}
        journal=self.paths.state/'journal.json'; atomic(journal,record); self.fault('prepared')
        try:
            atomic(self.paths.hypr,lua(snapshot['colors'])); self.fault('compositor-written')
            if live: self.compositor.reload(); self.compositor.check(baseline)
            self.fault('compositor-accepted')
            if live: self.appearance.apply(snapshot['mode'])
            self.fault('appearance-applied')
            atomic(self.paths.selection,snapshot['selection']); self.fault('selection-written')
            atomic(self.paths.active,snapshot); self.fault('published')
            atomic(self.paths.state/'previous-good.json',previous)
            atomic(self.paths.state/'last-good.json',self.capture())
            remove(journal)
        except Exception as e:
            published=self.current()
            if published and published['revision']==snapshot['revision']:
                return {'ok':True,'revision':snapshot['revision'],'warning':'Theme committed; recovery journal retained because finalization failed: '+str(e)+'. Run themes.py recover.'}
            rollback_error=None
            try:
                self.restore(previous)
                if live:
                    self.appearance.restore(record.get('appearance'))
                    self.compositor.reload(); self.compositor.check(baseline)
                remove(journal)
            except Exception as rollback: rollback_error=str(rollback)
            raise RuntimeError(str(e)+ ('; '+rollback_error+'; recovery journal retained. Run recover.' if rollback_error else '; previous theme restored')) from e
        return {'ok':True,'revision':snapshot['revision'],'theme':snapshot['identity']}
    def apply(self, identity, mode=None, wallpaper=None, live=True):
        with lock(self.paths.state/'operation.lock'):
            self._reconcile(live)
            if not self.current() and (self.paths.state/'last-good.json').exists():
                self.restore(read_json(self.paths.state/'last-good.json',1024*1024))
                if live: self.compositor.reload()
            snapshot=self.snapshot(identity,mode,wallpaper)
            return self._commit(snapshot,live)
    def rollback(self, live=True):
        with lock(self.paths.state/'operation.lock'):
            self._reconcile(live)
            files=read_json(self.paths.state/'previous-good.json',1024*1024)
            if not files.get('active'): raise ValueError('rollback: no previous committed theme')
            snapshot=self.validate_snapshot(json.loads(base64.b64decode(files['active'])))
            return self._commit(snapshot,live)
    def bootstrap(self, live=True):
        result=self.recover(live)
        if self.current(): return result
        # Migrate identity and asset choice, retaining legacy state files unchanged.
        old=self.paths.base/'state/active.json'
        if self.paths.selection.exists():
            selected=validate('selection',read_json(self.paths.selection))
            return self.apply(selected['identity'],selected['mode'],selected['wallpaperId'],live)
        identity='wizarch'; wallpaper=None
        if old.exists():
            try:
                data=read_json(old); identity=data['id']
                if not isinstance(identity,str): raise ValueError('legacy.id: wrong type')
                pack=self.catalog.get(identity)
                old_path=data.get('wallpaper','')
                wallpaper=next((w['id'] for w in pack['wallpapers'] if w['url']==old_path),None)
            except (OSError,ValueError,KeyError) as e:
                # Preserve an established but unavailable selection; do not replace with another pack.
                raise ValueError('Migration retained old state; selected theme unavailable/corrupt: '+str(e)) from e
        return self.apply(identity,'dark',wallpaper,live)
