"""Actual nested Wayland renders. Requires an already isolated session launch.json.
Never targets the user's compositor. Media/notifications are deterministic device fixtures.
Screenshots contain local artwork: keep outputs untracked and do not redistribute them.
"""
import argparse, hashlib, json, os, re, shutil, signal, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--session',required=True);args=parser.parse_args()
b=Path(args.session).resolve();launch=json.loads((b/'launch.json').read_text());env=launch['env']
assert env['XDG_CONFIG_HOME'].startswith(str(b)), 'must isolate configuration'
assert env['XDG_RUNTIME_DIR']!=os.environ.get('XDG_RUNTIME_DIR'), 'must isolate compositor IPC'
assert env['HYPRLAND_INSTANCE_SIGNATURE']!=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'), 'must not target user compositor'
output=ROOT/'outputs/material-theme';output.mkdir(parents=True,exist_ok=True)
for pidfile in ['source-shell.pid','fixture-shell.pid']:
    if (b/pidfile).exists():
        try:os.kill(int((b/pidfile).read_text()),signal.SIGTERM)
        except ProcessLookupError:pass
h=b/'harness';shutil.rmtree(h,ignore_errors=True);shutil.copytree(ROOT/'quickshell',h,ignore=shutil.ignore_patterns('__pycache__'))
services=h/'core/SystemServices.qml';s=services.read_text();s=s.replace('readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null','''readonly property var player: fixtureMedia ? fixturePlayer : null
    property bool fixtureMedia: true
    property var fixturePlayer: ({isPlaying:true,trackTitle:"Material verification",trackArtist:"Local fixture",identity:"Fixture",trackArtUrl:"",length:240,position:95,canSeek:true,previous:function(){},next:function(){},togglePlaying:function(){},seek:function(){}})''');services.write_text(s)
(h/'shell.qml').write_text('''pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "core" as Core
import "components"
ShellRoot {
 id: fixture
 Core.SystemServices { id: services }
 Core.ScrollingStackState { id: nativeFrames; sourceScript:"scrolling-frame.py" }
 Variants { model:Quickshell.screens; Wallpaper {} }
 Variants { model:Quickshell.screens; ScrollingFrameGuard { root:services;state:nativeFrames } }
 property var pills: []
 Variants { model:Quickshell.screens; Pill { root:services;Component.onCompleted:fixture.pills=fixture.pills.concat([this]);Component.onDestruction:fixture.pills=fixture.pills.filter(p=>p!==this) } }
 SettingsWindow { id:window;root:services }
 QuickWheel { id:wheel }
 function find(item,predicate) { if(predicate(item))return item;for(let child of item.children || []){const match=find(child,predicate);if(match)return match;}return null; }
 function mainPill() { return pills.find(p=>p.modelData.name==="WAYLAND-1") || pills[0]; }
 IpcHandler {
  target:"verify-material"
  function settings(page:string):void { for(let p of fixture.pills)p.dismiss();services.openSettings(page); }
  function closeSettings():void { window.closeSettings(); }
  function notify():void { services.notifications=[{appName:"Verification",summary:"Ordinary notification",body:"A local fixture; no external message sent.",urgency:1,dismiss:function(){}},{appName:"Verification",summary:"Urgent fixture",body:"Urgency also has a visible text label.",urgency:2,dismiss:function(){}}]; }
  function query(text:string):void { let l=fixture.find(fixture.mainPill().contentItem,item=>item.searchText!==undefined);l.searchText=text; }
  function calendar():void { let c=fixture.find(fixture.mainPill().contentItem,item=>item.viewMode!==undefined);c.page=new Date(2027,0,15,12);c.showMode(1); }
  function controlState(name:string):string {let control=fixture.find(window.contentItem,item=>item.text===name && item.clicked);let pt=control.mapToItem(window.contentItem,control.width/2,control.height/2);return JSON.stringify({x:pt.x,y:pt.y,hovered:control.hovered,down:control.down,background:String(control.background.color),ink:String(Core.Theme.onSurface)});}
  function scrollAppearance():void {let view=fixture.find(window.contentItem,item=>item.page!==undefined && item.contentY!==undefined);view.contentY=Math.max(0,view.contentHeight-view.height);}
  function focusControls():void { let control=fixture.find(window.contentItem,item=>item.text==="Apply" && item.clicked);if(control)control.forceActiveFocus(); }
  function preview(identity:string):void { Core.Theme.preview(identity); }
  function autoHide(enabled:bool):void { services.preferences=Object.assign({},services.preferences,{autoHide:enabled,hideOnEmptyMonitor:true}); }
  function cancelPreview():void { Core.Theme.cancelPreview(); }
  function apply(identity:string,mode:string):void { Core.Theme.apply(identity,mode); }
  function probe():string {
   let actual={};for(let role in Core.Theme.palette)actual[role]=String(Core.Theme[role]);
   let p=fixture.mainPill(),l=fixture.find(p.contentItem,item=>item.searchText!==undefined),c=fixture.find(p.contentItem,item=>item.viewMode!==undefined);
   return JSON.stringify({revision:Core.Theme.revision,error:Core.Theme.errorMessage,applying:Core.Theme.applying,identity:Core.Theme.selectedIdentity,mode:Core.Theme.mode,width:p.surfaceWidth,height:p.surfaceHeight,section:p.section,shown:p.shownSection,busy:p.busy,autoHide:p.autoHide,canAutoHide:p.canAutoHide,hideRequested:p.hideRequested,hideProgress:p.hideProgress,query:l.searchText,calendar:c.page.toISOString(),viewMode:c.viewMode,draft:Core.Theme.draftIdentity,settingsPage:window.currentPage,pills:fixture.pills.length,ink:String(Core.Theme.onSurface),background:String(Core.Theme.surface),primary:String(Core.Theme.primary),roles:Core.Theme.palette,actualRoles:actual,targetWidth:p.expanded ? p.targetWidth : 194,targetHeight:p.expanded ? p.targetHeight : 42});
  }
 }
}
''')
# Only isolated preferences, read-only fixture devices; no interaction calls device setters.
prefs=Path(env['XDG_CONFIG_HOME'])/'wizarch/preferences.json';prefs.parent.mkdir(parents=True,exist_ok=True)
prefs.write_text(json.dumps({'edgeConnected':True,'screenBorder':True,'borderThickness':10,'borderRadius':10,'autoHide':False,'matchWindowCorners':True,'windowSpacing':35,'notificationSounds':False,'pinnedApps':['org.kde.dolphin.desktop'],'appGroups':[],'launcherOrder':[]}))
log=b/'fixture-shell.log';p=subprocess.Popen(['quickshell','-p',str(h)],env=env,stdout=log.open('w'),stderr=subprocess.STDOUT,start_new_session=True);(b/'fixture-shell.pid').write_text(str(p.pid))
def call(target,function,*arguments):
    return subprocess.check_output(['quickshell','ipc','--pid',str(p.pid),'call','--',target,function,*map(str,arguments)],env=env,text=True,stderr=subprocess.STDOUT,timeout=5).strip()
def probe(): return json.loads(call('verify-material','probe'))
def applied(identity,mode):
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        value=settled()
        if value['identity']==identity and value['mode']==mode:return value
        if value['error']:raise AssertionError(value['error'])
        time.sleep(.025)
    raise AssertionError('committed snapshot was not observed')
def settled():
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        value=probe()
        if not value['applying'] and not value['busy'] and abs(value['width']-value['targetWidth'])<.1 and abs(value['height']-value['targetHeight'])<.1:return value
        time.sleep(.035)
    raise AssertionError('theme/pill failed to settle')
def panel(section):
    call('panel-WAYLAND-1','show',section);time.sleep(.52);settled()
records=[];behavior=[];performance=[];additional={}
driver_path=b/'pointer/pointer'
driver=subprocess.Popen([str(driver_path)],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True) if driver_path.exists() else None
def pointer(command):
    driver.stdin.write(command+'\n');driver.stdin.flush();assert driver.stdout.readline().strip()=='ok'
    time.sleep(.13)
content_hash=hashlib.sha256(b''.join(p.read_bytes() for p in sorted((ROOT/'quickshell').rglob('*')) if p.is_file() and p.suffix in ('.qml','.py','.js','.json'))).hexdigest()
def capture(theme,mode,surface):
    value=probe();path=output/(theme+'-'+mode+'-'+surface+'.png')
    subprocess.run(['grim','-o','WAYLAND-1',str(path)],env=env,check=True,timeout=5)
    from PIL import Image
    with Image.open(path) as im:
        colors=im.convert('RGB').getcolors(im.width*im.height)
        histogram={rgb:count for count,rgb in colors}
        def count(color):
            expected=tuple(int(color[i:i+2],16) for i in (1,3,5))
            return sum(n for rgb,n in histogram.items() if max(abs(x-y) for x,y in zip(rgb,expected))<=8)
        counts={role:count(value['roles'][role]) for role in ['surface','onSurface','onSurfaceVariant','primary','secondaryContainer','tertiaryContainer']}
    assert counts['onSurface']>0, (surface,'render lacks foreground role',counts)
    records.append({'theme':theme,'mode':mode,'surface':surface,'path':str(path),'revision':value['revision'],'sourceHash':content_hash,'pixels':counts,'pixelTolerance':8,'fixture':'actual production QML in nested Hyprland; deterministic media/notification data','geometry':{k:value[k] for k in ['width','height','section','busy']}})
try:
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        if 'Configuration Loaded' in log.read_text():break
        if p.poll() is not None:raise AssertionError(log.read_text())
        time.sleep(.05)
    settled()
    # Functional local provider is exercised in the isolated store, without remote transport.
    result=json.loads(subprocess.check_output(['python3',str(h/'services/themes.py'),'import',str(ROOT/'examples/material-collection')],env=env,text=True))
    custom=result['installed'][0]
    matrix=[('eclipse','bundled:eclipse'),('wizarch','bundled:wizarch'),('aurora-highcontrast',custom)]
    pages=['wifi','network','bluetooth','displays','sound','power','multitasking','appearance','panel','notifications','keyboard']
    for theme,identity in matrix:
        for mode in ['dark','light']:
            panel('');t=time.monotonic();call('verify-material','apply',identity,mode);value=applied(identity,mode);performance.append({'theme':theme,'mode':mode,'requestToIdleMs':round((time.monotonic()-t)*1000,2)})
            assert value['identity']==identity and value['mode']==mode,value
            assert value['actualRoles']==value['roles'], 'QML canonical getters differ from resolved snapshot'
            capture(theme,mode,'closed-desktop-frame-wallpaper')
            assert abs(value['width']-194)<.1 and abs(value['height']-42)<.1,value
            panel('launcher');capture(theme,mode,'search')
            assert abs(probe()['width']-420)<.1,probe()
            call('verify-material','query','test retained query');before=probe()
            # Change mode while open: geometry/query/section survive. Restore without reopening.
            call('verify-material','apply',identity,'light' if mode=='dark' else 'dark');applied(identity,'light' if mode=='dark' else 'dark');after=probe()
            assert after['query']==before['query'] and after['section']=='launcher' and abs(after['width']-420)<.1
            call('verify-material','apply',identity,mode);applied(identity,mode);behavior.append({'theme':theme,'mode':mode,'openSearchStatePreserved':True})
            panel('clock');capture(theme,mode,'calendar-week');call('panel-WAYLAND-1','calendarMode',1);time.sleep(.28);capture(theme,mode,'calendar-month')
            call('panel-WAYLAND-1','calendarMode',2);time.sleep(.28);capture(theme,mode,'calendar-year')
            call('verify-material','calendar');before=probe();call('verify-material','apply',identity,'light' if mode=='dark' else 'dark');applied(identity,'light' if mode=='dark' else 'dark');after=probe();assert before['calendar']==after['calendar'] and after['viewMode']==1;call('verify-material','apply',identity,mode);applied(identity,mode);behavior[-1]['calendarNavigationPreserved']=True
            panel('status');capture(theme,mode,'quicksettings-media-disabled')
            call('verify-material','notify');panel('notifications');capture(theme,mode,'notifications-urgency')
            panel('');call('quick-wheel','toggle','WAYLAND-1',960,540,'');time.sleep(.24);capture(theme,mode,'wheel');call('quick-wheel','close');time.sleep(.25)
            for page in pages:
                call('verify-material','settings',page);time.sleep(.17);capture(theme,mode,'settings-'+page)
            call('verify-material','settings','appearance');call('verify-material','scrollAppearance');call('verify-material','focusControls');time.sleep(.05);capture(theme,mode,'appearance-focused')
            if driver:
                # Native floating placement/layout can settle after the first frame.
                # Re-read both coordinate spaces; require a real hover, never simulate it.
                deadline=time.monotonic()+2
                while time.monotonic()<deadline:
                    point=json.loads(call('verify-material','controlState','Refresh'))
                    clients=json.loads(subprocess.check_output(['hyprctl','clients','-j'],env=env,text=True))
                    client=next(c for c in clients if c['pid']==p.pid and c['title']=="Wizarch Settings")
                    pointer('move '+str(round(client['at'][0]+point['x']))+' '+str(round(client['at'][1]+point['y'])))
                    if json.loads(call('verify-material','controlState','Refresh'))['hovered']:break
                assert json.loads(call('verify-material','controlState','Refresh'))['hovered']
                capture(theme,mode,'appearance-hover')
                pointer('press');assert json.loads(call('verify-material','controlState','Refresh'))['down'];capture(theme,mode,'appearance-pressed')
                pointer('release');pointer('move 2 2')
            before=probe();selection=(Path(env['XDG_CONFIG_HOME'])/'wizarch/theme-selection.json').read_bytes();hypr=(Path(env['XDG_CONFIG_HOME'])/'hypr/wizarch-theme.lua').read_bytes()
            call('verify-material','preview','bundled:wizarch' if identity!='bundled:wizarch' else 'bundled:eclipse');assert probe()['draft']
            call('verify-material','closeSettings');assert not probe()['draft'];assert probe()['revision']==before['revision'];assert selection==(Path(env['XDG_CONFIG_HOME'])/'wizarch/theme-selection.json').read_bytes();assert hypr==(Path(env['XDG_CONFIG_HOME'])/'hypr/wizarch-theme.lua').read_bytes()
            # Activation during the morph must let the existing animation finish normally.
            panel('');call('panel-WAYLAND-1','show','launcher');time.sleep(.10);call('verify-material','apply',identity,'light' if mode=='dark' else 'dark');value=applied(identity,'light' if mode=='dark' else 'dark');assert value['section']=='launcher' and abs(value['width']-420)<.1,value
            call('verify-material','apply',identity,mode);applied(identity,mode)
            behavior[-1]['previewCancelPreservedDesktop']=True;behavior[-1]['morphSettled']=True
    if driver:
        panel('launcher');pointer('move 300 700');pointer('press');pointer('release');time.sleep(.55);assert probe()['section']==''
        call('verify-material','autoHide','true');assert probe()['autoHide'],probe();time.sleep(1.7);assert probe()['hideProgress']>.99,probe()
        pointer('move 960 12');pointer('move 960 10');time.sleep(.65);assert probe()['hideProgress']<.01,probe()
        call('verify-material','autoHide','false');time.sleep(.3);pointer('move 2 2')
        additional['outsideClickAndAutoHideReveal']={'pass':True,'hideDelayMs':1200,'edgeIntentMs':120,'hideMotionMs':280}
    # Failure is visible in Appearance while the committed snapshot stays usable.
    call('verify-material','settings','appearance');call('verify-material','scrollAppearance');before=probe()
    call('verify-material','apply','bundled:missing','dark');time.sleep(.7)
    assert not probe()['applying'] and probe()['error'] and probe()['revision']==before['revision']
    capture('aurora-highcontrast','light','appearance-activation-error')
    call('verify-material','apply',custom,'light');applied(custom,'light');call('verify-material','closeSettings')
    # Actual restart uses only the persisted complete snapshot and offline installed colors.
    before=probe();p.terminate();p.wait(timeout=5)
    p=subprocess.Popen(['quickshell','-p',str(h)],env=env,stdout=log.open('a'),stderr=subprocess.STDOUT,start_new_session=True);(b/'fixture-shell.pid').write_text(str(p.pid))
    time.sleep(.6);after=applied(custom,'light');assert after['revision']==before['revision'] and after['actualRoles']==before['actualRoles']
    additional['restartPersistence']={'revision':after['revision'],'pass':True}
    def resources():
        # Count only this fixture's descendants and its own descriptors.
        rows=subprocess.check_output(['ps','-eo','pid,ppid,args'],text=True).splitlines()[1:];children={}
        for row in rows:
            a=row.strip().split(None,2)
            if len(a)==3:children.setdefault(int(a[1]),[]).append((int(a[0]),a[2]))
        found=[];pending=[p.pid]
        while pending:
            for child,command in children.get(pending.pop(),[]):found.append((child,command));pending.append(child)
        return {'watchers':sum('themes.py watch' in c for _,c in found),'descendants':len(found),'descriptors':len(list((Path('/proc')/str(p.pid)/'fd').iterdir()))}
    time.sleep(.3);before=resources()
    for n in range(10):call('verify-material','apply',custom,'dark' if n%2==0 else 'light');applied(custom,'dark' if n%2==0 else 'light')
    time.sleep(.3);after=resources();assert before['watchers']==after['watchers']==1 and after['descriptors']<=before['descriptors']+3 and after['descendants']<=before['descendants']+1,(before,after)
    additional['repeatedSwitchResources']={'before':before,'after':after,'switches':10}
    # A second virtual output exercises per-monitor instances without host monitor changes.
    subprocess.run(['hyprctl','output','create','headless','M3-SECOND'],env=env,check=True,capture_output=True);time.sleep(.8)
    assert probe()['pills']==2;call('panel-M3-SECOND','show','clock');time.sleep(.6)
    path=output/'aurora-highcontrast-light-second-monitor-calendar.png';subprocess.run(['grim','-o','M3-SECOND',str(path)],env=env,check=True,timeout=5)
    additional['secondMonitor']={'pills':probe()['pills'],'path':str(path),'sourceHash':content_hash,'revision':probe()['revision'],'pass':True}
    subprocess.run(['hyprctl','output','remove','M3-SECOND'],env=env,check=True,capture_output=True);time.sleep(.4);assert probe()['pills']==1
    errors=subprocess.check_output(['hyprctl','configerrors'],env=env,text=True);assert not errors.strip(),errors
    warnings=[line for line in log.read_text().splitlines() if re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop|Failed to load',line)]
    assert not warnings,warnings
    (output/'index.json').write_text(json.dumps({'sourceHash':content_hash,'screenshots':records,'behavior':behavior,'switchPerformance':performance,'compositorErrors':errors,'warnings':warnings,'additional':additional},indent=2)+'\n')
    print('PASS:',len(records),'actual screenshots;',len(behavior),'mode behavior cases; nested compositor errors empty')
finally:
    if driver:driver.stdin.close();driver.wait(timeout=5)
    p.terminate();p.wait(timeout=5)
