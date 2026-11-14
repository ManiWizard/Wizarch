"""Production launcher inside the real Pill in an isolated compositor.
Run with --session work/launcher-verification; never points input at the user's compositor.
The session must supply launch.json and input/driver (launcher-input.c + Wayland protocols).
No command is executed: physical command checks stop at confirmation; JS intercepts routing.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--session', required=True)
b = Path(parser.parse_args().session).resolve()
env = json.loads((b/'launch.json').read_text())['env']
assert env['XDG_CONFIG_HOME'].startswith(str(b))
assert env['XDG_RUNTIME_DIR'] != os.environ.get('XDG_RUNTIME_DIR')
assert env['HYPRLAND_INSTANCE_SIGNATURE'] != os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
assert (Path(env['XDG_RUNTIME_DIR'])/env['WAYLAND_DISPLAY']).exists(), 'isolated compositor must be running'
assert (Path(env['XDG_RUNTIME_DIR'])/'hypr'/env['HYPRLAND_INSTANCE_SIGNATURE']/'.socket.sock').exists()
h = b/'test-harness'
h.mkdir(exist_ok=True)
for name in ['core','services','themes','assets','schemas','panels']:
    target = h/name
    if not target.exists(): target.symlink_to(ROOT/'quickshell'/name, target_is_directory=True)
(h/'components').mkdir(exist_ok=True)
for file in (ROOT/'quickshell/components').glob('*.qml'):
    target = h/'components'/file.name
    if file.name == 'Pill.qml': target.write_bytes(file.read_bytes())
    elif not target.exists(): target.symlink_to(file)
(h/'shell.qml').write_bytes((ROOT/'tests/launcher-fixture.qml').read_bytes())
output = ROOT/'outputs/launcher'
output.mkdir(parents=True,exist_ok=True)
initial = {'autoHide':False,'edgeConnected':True,'screenBorder':True,'borderThickness':10,'pinnedApps':['discord','teamspeak3','unavailable-fixture'], 'appGroups':[{'name':'Compact','type':'compact','apps':['brave-browser','v2rayN']},{'name':'Large','type':'large','apps':['chatgpt','spotify']}], 'launcherOrder':['group:Compact','group:Large','app:discord','app:teamspeak3','app:unavailable-fixture'],'hiddenApps':[]}
prefs = Path(env['XDG_CONFIG_HOME'])/'wizarch/preferences.json'
prefs.parent.mkdir(parents=True,exist_ok=True)
prefs.write_text(json.dumps(initial))
recent_path=Path(env['XDG_STATE_HOME'])/'wizarch/launcher/recent.json'
recent_path.parent.mkdir(parents=True,exist_ok=True);recent_path.write_text('[]\n')
records = []
process = None
driver = subprocess.Popen([str(b/'input/driver')],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
def monitor():
    return json.loads(subprocess.check_output(['hyprctl','-j','monitors'],env=env,text=True))[0]
def cx(): return monitor()['width']//2
def input(command):
    if command.startswith('move '):
        m=monitor();driver.stdin.write(f"extent {m['width']} {m['height']}\n");driver.stdin.flush();assert driver.stdout.readline().strip()=='ok'
    driver.stdin.write(command+'\n');driver.stdin.flush()
    assert driver.stdout.readline().strip() == 'ok'
    time.sleep(.065)
def key(code): input('key '+str(code))
def click(x,y,button=272):
    input(f'move {x} {y}');input(f'button {button} 1');input(f'button {button} 0')
def call(method,*args):
    return subprocess.check_output(['quickshell','ipc','--pid',str(process.pid),'call','--','verify-launcher',method,*map(str,args)],env=env,text=True,stderr=subprocess.STDOUT,timeout=5).strip()
def state(): return json.loads(call('state'))
def wait():
    end=time.monotonic()+8
    while time.monotonic()<end:
        s=state()
        if s['loaded'] and not s['busy'] and abs(s['height']-s['targetHeight'])<.2:return s
        time.sleep(.04)
    raise AssertionError(s)
def start(label):
    global process
    log=b/(label+'.log')
    process=subprocess.Popen(['quickshell','-p',str(h)],env=env,stdout=log.open('w'),stderr=subprocess.STDOUT)
    end=time.monotonic()+8
    while 'Configuration Loaded' not in log.read_text():
        assert process.poll() is None and time.monotonic()<end,log.read_text()
        time.sleep(.04)
    call('show');wait();click(cx(),50)
def capture(name):
    wait();path=output/(name+'.png')
    subprocess.run(['grim','-o','WAYLAND-1',str(path)],env=env,check=True,timeout=5)
    records.append({'name':name,'state':state(),'tiles':json.loads(call('tiles')),'path':str(path)})
def prefs_update(change):call('preferences',json.dumps(change));time.sleep(.35);wait()
def drag(source,destination,escape=False,capture_name=None):
    input(f'move {source[0]} {source[1]}');input('button 272 1');input(f'move {source[0]+15} {source[1]+15}');input(f'move {destination[0]} {destination[1]}')
    s=state();assert s['drag'],s
    if capture_name:
        assert s['gridOpacity']>0 and s['snap'],s
        capture(capture_name)
    if capture_name == 'drag-before':
        destination_again=screen(tile('group:Large'),180,35)
        input(f'move {destination_again[0]} {destination_again[1]}');middle=state()
        assert middle['snap'] and (abs(middle['snapX']-middle['snap']['x'])>.1 or abs(middle['snapY']-middle['snap']['y'])>.1),middle
        capture('snap-mid-animation');time.sleep(.2);settled=state()
        assert abs(settled['snapX']-settled['snap']['x'])<.2 and abs(settled['snapY']-settled['snap']['y'])<.2
        input(f'move {destination[0]} {destination[1]}')
    if escape:key(1)
    input('button 272 0')
    if capture_name == 'drag-before':
        moving=tile('app:discord');assert moving['x']>50.1,moving
    wait();time.sleep(.25)
def tile(keyname):return next(t for t in json.loads(call('tiles')) if t['key']==keyname)
# Pill content has shadow margins; its contentItem is centered, width surface+64.
def screen(tile,dx=30,dy=28):return (round(cx()-484/2+tile['x']+dx),round(tile['y']+dy))
try:
    start('physical')
    assert state()['home'][0]=='group:Compact'
    # Visible home selection opens groups, with grid-aware arrow behavior.
    key(106);assert state()['current']==1,state()
    key(28);assert state()['group']=='Large',state()
    key(1);assert state()['group']=='',state()
    key(108);assert state()['current']==3,state()
    key(103);assert state()['current']==0,state()
    capture('after-home')
    surfaces=json.loads(call('surfaces'))
    for surface in surfaces:
        if surface['key'].startswith('group:'):assert len(surface['panels'])==1 and surface['panels'][0]['border']==1,surface

    # Real right-click menus must not launch, drag, or mutate the targeted object.
    home_before=state()['home'];click(*screen(tile('group:Compact')),button=273);assert state()['context'] and not state()['drag'],state();key(1)
    click(*screen(tile('app:teamspeak3')),button=273);assert state()['context'] and state()['home']==home_before;key(1)
    original=json.loads(call('tiles'));order=state()['prefs']['launcherOrder']
    drag(screen(tile('group:Compact')),(cx()-60,700))
    assert json.loads(call('tiles'))==original and state()['prefs']['launcherOrder']==order
    drag(screen(tile('group:Compact')),screen(tile('group:Compact'),45,45))
    assert json.loads(call('tiles'))==original
    drag(screen(tile('app:discord')),screen(tile('group:Compact'),3,35),escape=True)
    assert json.loads(call('tiles'))==original and state()['prefs']['launcherOrder']==order
    # Edge reorder and center group move are distinct physical destinations.
    drag(screen(tile('app:discord')),screen(tile('group:Compact'),3,35),capture_name='drag-before')
    assert state()['prefs']['launcherOrder'][0]=='app:discord',state()
    saved=state()['prefs']['launcherOrder']
    call('dismiss');time.sleep(.55);call('show');wait();assert state()['prefs']['launcherOrder']==saved
    drag(screen(tile('app:discord')),screen(tile('group:Compact'),44,35),capture_name='drag-membership')
    s=state();assert 'discord' not in s['prefs']['pinnedApps'];assert 'discord' in s['prefs']['appGroups'][0]['apps']
    # Context Add retains its home pin, and keyboard dismissal restores search focus.
    call('context','app','teamspeak3');wait();key(108);assert state()['menuIndex']==1
    key(1);assert not state()['context'] and state()['focus']=='launcherSearch',state()
    call('context','app','teamspeak3');wait();s=state();entry=next(i for i,e in enumerate(s['menu']) if e.get('groupName')=='Compact')
    for _ in range(entry):key(108)
    key(28);assert 'teamspeak3' in state()['prefs']['pinnedApps'];assert 'teamspeak3' in state()['prefs']['appGroups'][0]['apps']
    # Long menu is clamped to the visible viewport and supports outside dismissal.
    call('context','group','Compact');capture('context-group');s=state();bounds=s['menuBounds']
    assert bounds['x']>=0 and bounds['x']+bounds['w']<=bounds['viewportW']+.1
    assert bounds['y']>=0 and bounds['y']+bounds['h']<=bounds['viewportH']+.1
    click(cx()-185,50);assert not state()['context'],state()
    # Keyboard context key, destructive confirmation, and Escape cancellation.
    click(cx(),50);key(127);assert state()['context']
    key(1);call('context','group','Compact');wait()
    for _ in range(len(state()['menu'])-1):key(108)
    key(28);assert state()['deleteName']=='Compact';key(1);assert not state()['deleteName'];assert any(g['name']=='Compact' for g in state()['prefs']['appGroups'])
    # Search remains visible; command requires two separate, non-repeated Enters.
    call('query','no-such-launcher-match');capture('no-match');assert not state()['results'];key(1);assert state()['query']==''
    call('query','> printf never-executed');key(28);assert state()['commandConfirmed'];capture('command-confirmation');key(1);assert state()['query']==''
    call('all');wait();capture('all-apps');icons=json.loads(call('icons'))
    assert any(i['icon']=='/home/Mw/.local/opt/v2rayN/v2rayN.png' and i['ready'] for i in icons),icons
    assert any(i['icon']=='network-wired' and not i['ready'] for i in icons),icons
    assert 'bssh' in state()['results'];assert 'org.quickshell' not in state()['results'];assert 'org.gnupg.pinentry-qt' not in state()['results']
    call('query','Avahi');key(108);assert state()['current']==1;key(1);key(1);assert not state()['all']
    # Tab moves focus and arrows keep Enter's focus target aligned with selection.
    key(15);key(15);key(106);s=state();assert s['focus']==s['home'][s['current']],s
    # Saved missing apps have a visible slot and remain removable/recoverable.
    click(*screen(tile('app:unavailable-fixture')));assert 'unavailable' in state()['feedback'];capture('unavailable')
    # Existing group preview switching, rename, creation and deliberate deletion.
    call('context','group','Compact');wait();key(108);key(108);key(28);assert state()['prefs']['appGroups'][0]['type']=='large'
    call('context','group','Compact');wait();key(108);key(108);key(28);assert state()['prefs']['appGroups'][0]['type']=='compact'
    call('context','group','Compact');wait();key(108);key(108);key(108);key(28);assert state()['creating']
    input('mods 4');key(30);input('mods 0')
    for code in [20,24,24,38,31]:key(code)
    key(28);assert state()['prefs']['appGroups'][0]['name']=='tools';assert 'group:tools' in state()['prefs']['launcherOrder'];assert 'group:Compact' not in state()['prefs']['launcherOrder']
    click(cx(),50);input('mods 4');key(49);input('mods 0');assert state()['creating']
    for code in [49,18,17]:key(code)
    key(28);assert any(g['name']=='new' for g in state()['prefs']['appGroups'])
    call('context','group','new');wait()
    for _ in range(4):key(108)
    key(28);assert state()['deleteName']=='new';key(15);key(28);assert not any(g['name']=='new' for g in state()['prefs']['appGroups'])
    call('recent','chatgpt');call('recent','teamspeak3');call('recent','chatgpt');time.sleep(.4)
    assert state()['recent']==['chatgpt','teamspeak3'];assert json.loads(recent_path.read_text())==['chatgpt','teamspeak3']
    call('dismiss');time.sleep(.55);call('show');wait();capture('recently-used')
    # Reach the recent section by keyboard without executing an app.
    for _ in range(4):key(108)
    s=state();assert s['current']>=len(s['home']) and s['selected'] in s['recent'],s
    saved=state()['prefs'];time.sleep(.4)
    persisted=json.loads(prefs.read_text());assert persisted['launcherOrder']==saved['launcherOrder']
    process.terminate();process.wait(timeout=5);start('restart');assert state()['prefs']['launcherOrder']==saved['launcherOrder'];assert state()['prefs']['appGroups']==saved['appGroups'];assert state()['recent']==['chatgpt','teamspeak3'];capture('after-restart')
    # Empty home/group and crowded mixed content; held drag scrolls without overlap.
    prefs_update({'pinnedApps':[],'appGroups':[],'launcherOrder':[]});capture('empty-home');assert not state()['home']
    app_ids=[a['id'] for a in json.loads(call('apps'))];prefs_update({'hiddenApps':app_ids});call('all');capture('empty-all-apps');assert not state()['results'];key(1);prefs_update({'hiddenApps':[]})
    prefs_update({'appGroups':[{'name':'Empty','type':'compact','apps':[]}]});key(28);assert state()['group']=='Empty' and not state()['results'];capture('empty-group');key(1)
    crowded=[{'name':'G'+str(i),'type':'large' if i%3==0 else 'compact','apps':[]} for i in range(18)]
    prefs_update({'appGroups':crowded,'pinnedApps':['teamspeak3'],'launcherOrder':[]});capture('crowded-home')
    source=screen(tile('group:G0'));input(f'move {source[0]} {source[1]}');input('button 272 1');input(f'move {source[0]+15} {source[1]+15}');input(f'move {cx()-160} {round(tile("group:G0")["y"]+state()["homeViewport"]-10)}');time.sleep(.8);capture('scrolling-drag');assert tile('group:G0')['y']<0;key(1);input('button 272 0');assert state()['prefs']['appGroups']==crowded
    # Long membership menus scroll with keyboard selection while remaining clamped.
    call('context','app','teamspeak3');wait();assert len(state()['menu'])>18
    for _ in range(len(state()['menu'])-1):key(108)
    assert state()['menuScrollY']>0;capture('context-scrolled');key(1)
    # Check every actual tile against the mathematical model, even while scrolled.
    positions=json.loads(call('tiles'))
    for i,a in enumerate(positions):
        for c in positions[i+1:]:assert a['x']+a['w']<=c['x']+.1 or c['x']+c['w']<=a['x']+.1 or a['y']+a['h']<=c['y']+.1 or c['y']+c['h']<=a['y']+.1,(a,c)
    warnings=[]
    for log in [b/'physical.log',b/'restart.log']:
        warnings += [line for line in log.read_text().splitlines() if re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop|Failed to load|Error:|Expected token',line)]
    assert not warnings,warnings
    owned=['LauncherView.qml','LauncherModel.js','LauncherIcon.qml','launcher-desktop.py','LauncherDragOverlay.qml','launcher-history.py']
    hashes={name:hashlib.sha256((ROOT/'quickshell/panels'/name).read_bytes()).hexdigest() for name in owned}
    (output/'verification.json').write_text(json.dumps({'sourceHashes':hashes,'screenshots':records,'warnings':warnings,'actualApps':json.loads(call('apps')),'physicalChecks':['pointer app/group context menus','spatial arrows','Enter opens group','Escape/back','Tab and focus','Menu key and menu arrows','outside menu dismissal','destructive cancellation','invalid/self/canceled drops','edge reorder','center move into group','membership retains pin','restart persistence','missing and path icons','no match','command confirmation only','empty states','crowded mixed grid','drag scrolling','preview size switching','group rename/create/delete','empty catalog','long menu keyboard scrolling','single thin group borders','drag grid and snap placement','snap animation intermediate and settled coordinates','tile reorder animation intermediate coordinates','recent MRU persistence and keyboard selection'], 'limits':['No physical command execution; intercepted in JS','App execution and terminal working-directory routing intercepted in focused tests','Super+Space compositor binding unchanged; panel IPC and pointer exercised']},indent=2)+'\n')
    print('PASS:',len(records),'actual Pill captures, physical keyboard/pointer/drag, icon readiness, saved restart arrangement, empty/crowded states; no QML warnings')
finally:
    driver.stdin.close();driver.wait(timeout=5)
    if process and process.poll() is None:process.terminate();process.wait(timeout=5)
