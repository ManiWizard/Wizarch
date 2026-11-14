"""Exercise native layout and independent geometry contexts without physical displays."""
from pathlib import Path
import os,runpy,shutil,subprocess,tempfile,select,time,re
src=Path(__file__).resolve().parents[1]/'quickshell'
with tempfile.TemporaryDirectory(prefix='wizarch-scale-') as tmp:
 folder=Path(tmp)
 for name in ['components','panels','core']:shutil.copytree(src/name,folder/name)
 (folder/'assets').symlink_to(src/'assets',target_is_directory=True)
 runpy.run_path(str(Path(__file__).with_name('theme-fixture.py')))['write_theme'](folder,src)
 (folder/'core/qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Geometry 1.0 Geometry.qml\nGeometryContext 1.0 GeometryContext.qml\n')
 (folder/'shell.qml').write_text('''pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "core" as Core
import "panels"
import "components"
ShellRoot {
 id:test
 property real scale:1
 property int phase:0
 property var scales:[1,1.25,1.5,1.75,2]
 Core.GeometryContext {id:large;uiScale:test.scale;devicePixelRatio:1.5}
 Core.GeometryContext {id:normal;uiScale:1}
 QtObject {id:state;property var preferences:({pinnedApps:[],appGroups:[],launcherOrder:[],hiddenApps:[],calendarPrimary:"gregorian",calendarSecondary:"solar",calendarEvents:[]});property var sortedApps:[];property string preferenceError:"";function setPreference(k,v){} function setPreferences(v){} }
 QtObject {id:panel;property string shownSection:"launcher";property real contentAlpha:1;property bool busy:false;property real targetWidth:large.metric("launcherWidth");function dismiss(){} }
 FloatingWindow {visible:true;implicitWidth:1920;implicitHeight:1080
  Item {property var uiGeometry:large
   Item {
    SettingsSwitch {id:toggle}
    SettingsButton {id:button;text:"Native text"}
    CalendarView {id:cal;root:state;width:large.dp(324);height:Math.min(880,contentHeight)-large.dp(44);availableHeight:880;today:new Date(2026,9,9,12)}
    LauncherView {id:launcher;root:state;panel:panel;width:large.dp(384);height:900}
   }
  }
  Item {property var uiGeometry:normal;SettingsButton {id:peer;text:"Peer"}}
 }
 function expect(ok,label){if(!ok)throw new Error(label);}
 function all(item,predicate,result){if(predicate(item))result.push(item);for(let child of item.children||[])all(child,predicate,result);return result;}
 Timer {interval:300;repeat:true;running:true;onTriggered:{try{
  const ratio=test.scale;
  expect(button.uiGeometry===large && cal.uiGeometry===large && launcher.uiGeometry===large,"nested inherited owning context");
  expect(peer.uiGeometry===normal && peer.font.pixelSize===13,"independent peer baseline");
  expect(Math.abs(button.font.pixelSize-large.metric("fontBody"))<=0.51,"native font scale");
  expect(toggle.width===large.metric("switchWidth"),"scaled hit target");
  expect(launcher.gridColumns===4 && Math.abs(launcher.gridCellHeight-large.dp(98))<=0.51,"launcher cells and column count");
  expect(Math.abs(launcher.gridColumns*launcher.gridCellWidth+(launcher.gridColumns-1)*launcher.gridGap-launcher.layoutWidth)<.01,"launcher spans available width");
  cal.showMode(1);
  let days=all(cal,item=>item.primaryText!==undefined,[]).filter(item=>item.visible);
  expect(days.length>=28,"month day count");
  expect(Math.abs(days[0].width*7+large.dp(4)*6-cal.width)<.01,"seven-column month span");
  cal.showMode(2);
  let cards=all(cal,item=>item.month!==undefined&&item.system!==undefined,[]);
  expect(cards.length===12,"year has twelve months");
  expect(Math.abs(cards[0].width*3+large.dp(6)*2-cal.width)<.01,"three-column year span");
  expect(cal.contentHeight<=880 && cal.naturalHeight>0,"bounded calendar viewport");
  const outer=large.wheelOuterRadius(1920,1080);expect(outer*2<=1080 && outer===large.dp(200),"scaled radial diameter fits native screen");
  test.phase++;
  if(test.phase===test.scales.length){console.log("UI_SCALE_PASS");stop();}else test.scale=test.scales[test.phase];
 }catch(e){console.error("UI_SCALE_FAIL:"+e);stop();}}}
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_CONFIG_HOME=str(folder/'config'),XDG_STATE_HOME=str(folder/'state'))
 proc=subprocess.Popen(['qs','-p',str(folder),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 lines=[]
 try:
  until=time.monotonic()+12
  while time.monotonic()<until:
   if select.select([proc.stdout],[],[],.2)[0]:
    line=proc.stdout.readline();lines.append(line)
    if 'UI_SCALE_PASS' in line or 'UI_SCALE_FAIL' in line:break
   if proc.poll() is not None:break
  print(''.join(lines));assert any('UI_SCALE_PASS' in x for x in lines)
  assert not any(re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop',x) for x in lines)
 finally:proc.terminate();proc.wait(timeout=3)
