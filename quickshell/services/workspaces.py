#!/usr/bin/env python3
"""Nine shared desktop groups, backed by a workspace per monitor."""
import fcntl,json,os,re,subprocess,sys,time
from pathlib import Path
BASE=Path(os.environ['XDG_RUNTIME_DIR'])
key=re.sub(r'[^a-zA-Z0-9_-]','_',os.environ.get('HYPRLAND_INSTANCE_SIGNATURE','session'))
STATE=BASE/('wizarch-workspaces-'+key+'.json')

def query(what): return json.loads(subprocess.check_output(['hyprctl',what,'-j'],text=True,timeout=3))
def dispatch(code):
    out=subprocess.check_output(['hyprctl','dispatch',code],text=True,timeout=3)
    if out.strip()!='ok': raise RuntimeError(out.strip())
def q(s): return json.dumps(s)
def selector(name): return name if name.isdigit() else 'name:'+name

def focus_group(state,monitors,group,desktop=False):
    focused=next((m['name'] for m in monitors if m['focused']),monitors[0]['name'])
    # Hyprland runs this Lua block synchronously, avoiding per-monitor IPC races.
    commands=[]
    for m in monitors:
        name='__desktop_'+m['name'] if desktop else state['map'][m['name']][str(group)]
        commands += ['hl.dispatch(hl.dsp.focus({ monitor = '+q(m['name'])+' }))',
                     'hl.dispatch(hl.dsp.focus({ workspace = '+q(selector(name))+' }))']
    commands.append('hl.dispatch(hl.dsp.focus({ monitor = '+q(focused)+' }))')
    result=subprocess.check_output(['hyprctl','eval','; '.join(commands)],text=True,timeout=4)
    if 'error' in result.lower(): raise RuntimeError(result.strip())
    # Ensure dispatch application has reached the expected monitor set before unlock.
    for _ in range(20):
        now=query('monitors')
        if all(m['activeWorkspace']['name']==('__desktop_'+m['name'] if desktop else state['map'][m['name']][str(group)]) for m in now): return
        time.sleep(.015)
    raise RuntimeError('Workspace group did not settle')

def main():
    action=sys.argv[1] if len(sys.argv)>1 else 'status'
    monitors=query('monitors')
    if not monitors: raise RuntimeError('No active monitors')
    state=json.loads(STATE.read_text()) if STATE.exists() else dict(current=1,used=[1],revision=0,map={},desktop=False)
    for m in monitors:
        if m['name'] not in state['map']:
            names={str(i):'wizarch-'+str(i)+'-'+m['name'] for i in range(1,10)}
            active=m['activeWorkspace']['name']
            if active.startswith('__desktop'):
                candidates=[w['name'] for w in query('workspaces') if w.get('monitor')==m['name'] and not w['name'].startswith(('__desktop','special:'))]
                active=next(iter(candidates),names[str(state['current'])])
            names[str(state['current'])]=active
            state['map'][m['name']]=names
    if action in ('switch','move'):
        value=sys.argv[2]
        group=(state['current']%9+1 if value=='next' else (state['current']-2)%9+1 if value=='prev' else int(value))
        if not 1<=group<=9: raise ValueError('Workspace must be 1–9')
        if action=='move':
            m=next(m for m in monitors if m['focused'])
            dispatch('hl.dsp.window.move({ workspace = '+q(selector(state['map'][m['name']][str(group)]))+', follow = false })')
        else:
            focus_group(state,monitors,group)
            state.update(current=group,desktop=False,revision=state['revision']+1)
        if group not in state['used']: state['used'].append(group)
    elif action=='desktop':
        state['desktop']=not state['desktop']
        focus_group(state,monitors,state['current'],state['desktop'])
    elif action=='sync':
        focused=next((m for m in monitors if m['focused']),monitors[0])
        reverse={v:int(k) for k,v in state['map'][focused['name']].items()}
        group=reverse.get(focused['activeWorkspace']['name'])
        if group is not None and group!=state['current']:
            focus_group(state,monitors,group)
            state.update(current=group,desktop=False,revision=state['revision']+1)
            if group not in state['used']: state['used'].append(group)
    elif action!='status': raise ValueError('Unknown action')
    occupied={c['workspace']['name'] for c in query('clients')}
    state['used']=sorted({state['current']} | {int(g) for groups in state['map'].values() for g,name in groups.items() if name in occupied})
    tmp=STATE.with_suffix('.tmp');tmp.write_text(json.dumps(state));tmp.replace(STATE)
    print(json.dumps({k:state[k] for k in ('current','used','revision','desktop')}))

if __name__=='__main__':
    try:
        with open(str(STATE)+'.lock','w') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX);main()
    except Exception as e:
        print(json.dumps({'error':str(e)}));sys.exit(1)
