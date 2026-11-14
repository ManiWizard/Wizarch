"""Exercise production wheel QML with an isolated action sink, without live actions."""
from pathlib import Path
import os,re,select,shutil,subprocess,tempfile,time,json
src=Path(__file__).resolve().parents[1]/'quickshell'
output=os.environ.get('WIZARCH_TEST_OUTPUT')
if not output: raise SystemExit('Set WIZARCH_TEST_OUTPUT explicitly; this Wayland fixture never chooses a default display.')
with tempfile.TemporaryDirectory(prefix='wizarch-wheel-') as temporary:
 folder=Path(temporary)
 for name in ['components','core','assets']:(folder/name).mkdir()
 for rel in ['components/QuickWheel.qml','components/Glyph.qml','core/WheelNavigation.js','core/Theme.qml']:shutil.copy2(src/rel,folder/rel)
 (folder/'assets/icons').symlink_to(src/'assets/icons',target_is_directory=True)
 import runpy
 runpy.run_path(str(Path(__file__).with_name('theme-fixture.py')))['write_theme'](folder,src)
 (folder/'core/qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Geometry 1.0 Geometry.qml\nGeometryContext 1.0 GeometryContext.qml\n')
 (folder/'shell.qml').write_text('''import QtQuick
import Quickshell
import "components"
ShellRoot {
 id: fixture
 property var commands: []
 property int phase: 0
 function expect(ok,message) { if(!ok)throw new Error(message); }
 QuickWheel { id: wheel; onActionRequested: command => fixture.commands=fixture.commands.concat([command]) }
 Timer {
  interval:100;running:true;repeat:true
  onTriggered: {
   try {
    if(phase===0) {
     wheel.openAt("missing",0,0,"");expect(!wheel.opened,"invalid monitor");
     wheel.openAt(Quickshell.screens.find(screen => screen.name === TEST_OUTPUT).name,320,240,"0x123abc");expect(wheel.opened && wheel.selectedIndex===-1,"open in Cancel dead zone");
    } else if(phase===1) {
     let g=wheel.geometry;wheel.point(g.x,g.y);
     wheel.handleKey(Qt.Key_Home,0,false);
     for(let i=0;i<8;i++)wheel.handleKey(Qt.Key_Tab,0,false);expect(wheel.selectedIndex===0,"Tab wrap");
     wheel.handleKey(Qt.Key_Tab,Qt.ShiftModifier,false);expect(wheel.selectedIndex===7,"Shift Tab");
     wheel.handleKey(Qt.Key_Up,0,false);expect(wheel.selectedIndex===0,"Up points north");
     wheel.handleKey(Qt.Key_Right,0,false);expect(wheel.selectedIndex===2,"Right points east");
     wheel.handleKey(Qt.Key_Down,0,false);expect(wheel.selectedIndex===4,"Down points south");
     wheel.handleKey(Qt.Key_Left,0,false);expect(wheel.selectedIndex===6,"Left points west");
     wheel.handleKey(Qt.Key_Home,0,false);expect(wheel.selectedIndex===0,"Home");
     wheel.handleKey(Qt.Key_End,0,false);expect(wheel.selectedIndex===7,"End");
     expect(g.x===g.width/2 && g.y===g.height/2,"surface center ignores invocation");
     wheel.point(g.x+1,g.y+1);expect(wheel.selectedIndex===7,"stationary pointer preserves keyboard");
     wheel.handleKey(Qt.Key_Return,0,true);expect(wheel.opened,"key repeat must not execute");
     wheel.handleKey(Qt.Key_Return,0,false);expect(!wheel.opened,"Enter dismisses before execution");
    } else if(phase===3) {
     expect(commands.length===1 && commands[0][4]==="settings" && commands[0][5]==="0x123abc","exact confirmed action");
     wheel.openAt(Quickshell.screens.find(screen => screen.name === TEST_OUTPUT).name,320,240,"0x123abc");
    } else if(phase===4) {
     let g=wheel.geometry;
     for(let i=0;i<8;i++) {let angle=(-90+i*45)*Math.PI/180;wheel.point(g.x+(g.inner+g.outer)/2*Math.cos(angle),g.y+(g.inner+g.outer)/2*Math.sin(angle));expect(wheel.selectedIndex===i,"pointer sector "+i);}
     wheel.point(g.x,g.y);expect(wheel.selectedIndex===-1,"centre cancels selection");wheel.handleKey(Qt.Key_Return,0,false);expect(wheel.opened && commands.length===1,"centre cannot execute");
     wheel.handleKey(Qt.Key_Escape,0,false);expect(!wheel.opened,"Escape closes");
     wheel.openAt(Quickshell.screens.find(screen => screen.name === TEST_OUTPUT).name,320,240,"");wheel.handleKey(Qt.Key_W,Qt.MetaModifier,false);expect(!wheel.opened,"Super W closes");
     wheel.openAt(Quickshell.screens.find(screen => screen.name === TEST_OUTPUT).name,320,240,"");wheel.handleKey(Qt.Key_Home,0,false);wheel.activate();wheel.cancel();
    } else if(phase===6) {
     expect(commands.length===1,"cancel clears pending action");
     wheel.openAt(Quickshell.screens.find(screen => screen.name === TEST_OUTPUT).name,320,240,"");let g=wheel.geometry;
     wheel.handleClick(g.x,g.y,Qt.LeftButton);expect(!wheel.opened,"centre click cancels");
     wheel.openAt(Quickshell.screens.find(screen => screen.name === TEST_OUTPUT).name,320,240,"");wheel.handleClick(0,0,Qt.RightButton);expect(!wheel.opened,"right click cancels");
     wheel.openAt(Quickshell.screens.find(screen => screen.name === TEST_OUTPUT).name,320,240,"0x123abc");
    } else if(phase===7) {
     let g=wheel.geometry;wheel.handleClick(g.x+(g.inner+g.outer)/2,g.y,Qt.LeftButton);expect(!wheel.opened && wheel.selectedIndex===2,"left click picks exact sector");
    } else if(phase===9) {
     expect(commands.length===2 && commands[1][4]==="quick-settings","mouse confirms exact action: "+JSON.stringify(commands));
     wheel.openAt(Quickshell.screens.find(screen => screen.name === TEST_OUTPUT).name,320,240,"");wheel.targetScreen=null;wheel.validateScreen();expect(!wheel.opened,"disconnected monitor cancels");
     console.log("WHEEL_PASS: keyboard navigation, confirmation, mouse sectors, dead zone, previous target, invalid monitor and cancellation");
    }
    phase++;
   } catch(error) { console.error("WHEEL_FAIL: "+error);phase=100; }
  }
 }
}
'''.replace('TEST_OUTPUT',json.dumps(output)))
 env=dict(os.environ,QT_QPA_PLATFORM='wayland',XDG_CONFIG_HOME=str(folder/'config'))
 proc=subprocess.Popen(['qs','-p',str(folder/'shell.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 lines=[]
 try:
  deadline=time.monotonic()+6
  while time.monotonic()<deadline:
   if select.select([proc.stdout],[],[],.2)[0]:
    line=proc.stdout.readline();lines.append(line)
    if 'WHEEL_PASS:' in line or 'WHEEL_FAIL:' in line:break
   if proc.poll() is not None:break
  print(''.join(lines))
  assert any('WHEEL_PASS:' in line for line in lines),'Wheel QML integration failed'
  assert not any(re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop',line) for line in lines),'QML runtime error'
 finally:proc.terminate();proc.wait(timeout=3)
