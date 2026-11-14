#!/usr/bin/env python3
"""Open the quick-action wheel on the focused monitor and route existing actions."""
import fcntl, json, math, os, re, subprocess, sys, time
from pathlib import Path
ACTIONS = {'launcher':'launcher','calendar':'clock','quick-settings':'status','notifications':'notifications','clipboard':'clipboard','themes':'themes','settings':'settings'}

def query(name):
    return json.loads(subprocess.check_output(['hyprctl',name,'-j'],text=True,timeout=3))

def location(monitors):
    monitors=[m for m in monitors if not m.get('disabled') and m.get('mirrorOf','none')=='none']
    if not monitors: raise ValueError('No active monitor')
    monitor=next((m for m in monitors if m.get('focused')),monitors[0])
    scale=monitor.get('scale',1)
    width,height=monitor['width']/scale,monitor['height']/scale
    if monitor.get('transform',0)%2: width,height=height,width
    x,y=width/2,height/2
    global_x,global_y=monitor['x']+x,monitor['y']+y
    if not all(math.isfinite(n) for n in (x,y,global_x,global_y)) or min(width,height)<=0:
        raise ValueError('Invalid monitor geometry')
    return monitor['name'],x,y,global_x,global_y

def warp(x,y):
    # Legacy movecursor truncates to integers. The native Lua dispatcher preserves
    # fractional logical coordinates on scaled, rotated and offset outputs.
    code=f'hl.dispatch(hl.dsp.cursor.move({{x={x:.17g}, y={y:.17g}}}))'
    result=subprocess.run(['hyprctl','eval',code],check=True,timeout=3,capture_output=True,text=True)
    if result.stdout.strip()!='ok': raise ValueError('Cursor warp failed: '+result.stdout.strip())

def ipc(target, method, *arguments):
    command=['qs','ipc','-p',str(Path(__file__).resolve().parents[1]/'shell.qml'),'call','--',target,method,*map(str,arguments)]
    deadline=time.monotonic()+3
    while True:
        result=subprocess.run(command,check=True,timeout=3,capture_output=True,text=True)
        if 'Not ready to accept queries yet' not in (result.stdout+result.stderr): return result.stdout.strip()
        if time.monotonic()>=deadline: raise ValueError('The shell is still reloading; try again')
        time.sleep(.05)

def runtime_dir():
    env = os.environ.get('XDG_RUNTIME_DIR')
    if env:
        return Path(env)
    user_run = Path(f'/run/user/{os.getuid()}')
    if user_run.is_dir() and os.access(user_run, os.W_OK):
        return user_run
    fallback = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'wizarch/run'
    fallback.mkdir(parents=True, exist_ok=True)
    return fallback

def toggle():
    # Serialize repeated keybindings across helpers; closing never queries or moves
    # the pointer. Capture the previous app before a warp can change focus.
    runtime=runtime_dir()
    runtime.mkdir(parents=True,exist_ok=True)
    with (runtime/'wizarch-quick-wheel.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        state=ipc('quick-wheel','isOpen')
        if state=='true':
            ipc('quick-wheel','close')
            return
        if state!='false': raise ValueError('Invalid wheel state: '+str(state))
        monitor,x,y,global_x,global_y=location(query('monitors'))
        address=query('activewindow').get('address','')
        if not re.fullmatch(r'0x[0-9a-fA-F]+',address): address=''
        # Complete synthetic motion before the QML input surface is mapped.
        warp(global_x,global_y)
        ipc('quick-wheel','toggle',monitor,x,y,address)

def activate(monitor, action, previous):
    if action not in ACTIONS and action!='screenshot': raise ValueError('Unknown wheel action')
    if not any(m['name']==monitor and not m.get('disabled') for m in query('monitors')): raise ValueError('The selected monitor is no longer connected')
    if action=='screenshot':
        command=Path.home()/'.local/bin/hypr-screenshot'
        os.execv(str(command),[str(command)])
        return
    if action=='clipboard':
        cache=Path(os.environ.get('XDG_CACHE_HOME',str(Path.home()/'.cache')))/'wizarch/previous-window'
        if re.fullmatch(r'0x[0-9a-fA-F]+',previous):
            cache.parent.mkdir(parents=True,exist_ok=True)
            temporary=cache.with_suffix('.wheel-tmp');temporary.write_text(previous);temporary.replace(cache)
        else: cache.unlink(missing_ok=True)
    section=ACTIONS[action]
    ipc('panel-'+monitor,'togglePanel' if section in ('themes','settings') else 'show',section)

def main(args):
    if args==['toggle']: toggle()
    elif len(args)==4 and args[0]=='activate': activate(*args[1:])
    else: raise ValueError('Expected toggle or activate with monitor, action and previous window')
if __name__=='__main__':
    try: main(sys.argv[1:])
    except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as error:
        print('Wizarch wheel: '+str(error),file=sys.stderr);sys.exit(1)
