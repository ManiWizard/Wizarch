"""Load actual calendar components; render on Wayland using an isolated state facade."""
from pathlib import Path
import os,re,runpy,select,shutil,subprocess,sys,tempfile,time
src=Path(__file__).resolve().parents[1]/'quickshell'
output=Path('/home/Mw/ChatGPT/Wizarch Shell/audit/calendar-20261009');output.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='wizarch-calendar-') as temp:
 folder=Path(temp)
 for d in ['components','core','panels']: (folder/d).mkdir()
 for name in ['CalendarDay','CalendarMonthCard','SettingsButton','ThemedScrollBar']:shutil.copy2(src/'components'/f'{name}.qml',folder/'components')
 for name in ['Solar.js','CalendarDate.js','CalendarEvents.js']:shutil.copy2(src/'core'/name,folder/'core')
 shutil.copy2(src/'panels/CalendarView.qml',folder/'panels')
 runpy.run_path(str(Path(__file__).with_name('theme-fixture.py')))['write_theme'](folder,src)
 (folder/'core/qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Geometry 1.0 Geometry.qml\nGeometryContext 1.0 GeometryContext.qml\n')
 shell='''pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "panels"
import "core" as Core
import "core/CalendarDate.js" as Dates
ShellRoot {
 id:fixture
 QtObject {
  id:state
  property var preferences: ({calendarPrimary:"gregorian",calendarSecondary:"solar",calendarEvents:[]})
  property string preferenceError:""
  function setPreference(key,value) {var next={};next[key]=value;preferences=Object.assign({},preferences,next);}
  function retryPreferences() {}
 }
 FloatingWindow {
  id:window;visible:true;implicitWidth:360;implicitHeight:cal.contentHeight;color:Core.Theme.surfaceContainerLow
  title:"Calendar validation fixture"
  CalendarView {id:cal;root:state;x:18;y:22;width:324;height:contentHeight-44;today:new Date(2026,9,9,12);availableHeight:600}
 }
 FloatingWindow {visible:false;CalendarView {id:peer;root:state;width:324;height:contentHeight-44;today:new Date(2026,9,9,12)}}
 function expect(ok,label) {if(!ok)throw new Error(label);}
 function find(item,name) {if(item.objectName===name)return item;for(let child of item.children || []){let found=find(child,name);if(found)return found;}return null;}
 function match(item,predicate) {if(predicate(item))return item;for(let child of item.children || []){let found=match(child,predicate);if(found)return found;}return null;}
 function input(name,text) {find(cal,name).text=text;}
 property int phase:0
 property bool captureBusy:false
 function capture(name) {
  captureBusy=true;
  cal.grabToImage(result=>{expect(result.saveToFile("OUTPUT/"+name+".png"),"save image");captureBusy=false;phase++;});
 }
 Timer {
  interval:140;running:true;repeat:true
  onTriggered: {
   if(fixture.captureBusy)return;
   try {
    if(fixture.phase===0) {
     peer.reset();cal.reset();
     let dateCard=fixture.match(cal,item=>item.primaryText!==undefined && item.radius!==undefined);
     expect(!!dateCard && Math.abs(dateCard.radius-Core.Geometry.radius("control",dateCard.width,dateCard.height))<.001,"date card follows shared new shape profile");
     expect(Dates.key(cal.dateAt(3))==="2026-10-09","today centered");cal.changePage(1);expect(Dates.key(cal.page)==="2026-10-16","rolling navigation");expect(Dates.key(peer.page)==="2026-10-09","independent monitor page");cal.reset();
     expect(cal.contentHeight<600,"week fit");fixture.capture("week");
    } else if(fixture.phase===1) {
     cal.edit(null);fixture.input("titleInput","Dentist");fixture.input("dateInput","2026-02-30");cal.saveEvent();expect(cal.editing && cal.editorError!=="","invalid civil date refused");
     fixture.input("dateInput","2026-10-09");fixture.input("iconInput","★");fixture.input("colorInput","#83d4b4");cal.saveEvent();expect(state.preferences.calendarEvents.length===1 && cal.dayEvents.length===1,"event saved");
     fixture.phase++;
    } else if(fixture.phase===2) {cal.edit(cal.dayEvents[0]);fixture.capture("event-editor");}
    else if(fixture.phase===3) {fixture.input("titleInput","Updated local fixture");cal.saveEvent();expect(cal.dayEvents.length===1 && cal.dayEvents[0].title==="Updated local fixture","edit replaces entry");cal.page=new Date(2026,9,9,12);cal.showMode(1);expect(cal.monthWeeks===5,"five weeks");fixture.capture("month-five");}
    else if(fixture.phase===4) {cal.page=new Date(2021,1,1,12);expect(cal.monthWeeks===4,"four weeks");fixture.capture("month-four");}
    else if(fixture.phase===5) {cal.page=new Date(2026,2,1,12);expect(cal.monthWeeks===6,"six weeks");fixture.capture("month-six");}
    else if(fixture.phase===6) {cal.page=new Date(2026,9,9,12);cal.showMode(2);fixture.capture("year");}
    else if(fixture.phase===7) {var monthCard=fixture.match(cal,item=>item.month!==undefined && item.system!==undefined && Dates.parts(item.month,"gregorian").month===6);expect(!!monthCard,"year month card");monthCard.activated();expect(cal.viewMode===1 && cal.page.getMonth()===6,"month selection enters grid");state.preferences=Object.assign({},state.preferences,{calendarPrimary:"solar",calendarSecondary:"gregorian"});cal.page=Dates.fromParts(1405,6,9,"solar");cal.showMode(1);expect(Dates.parts(cal.page,cal.primary).year===1405,"solar year");expect(cal.dateAt(0).getDay()===6,"Saturday start");fixture.capture("solar-month");}
    else if(fixture.phase===8) {cal.showMode(2);fixture.capture("solar-year");}
    else if(fixture.phase===9) {state.preferences=Object.assign({},state.preferences,{calendarSecondary:"off"});cal.reset();expect(cal.secondary==="off" && peer.secondary==="off" && peer.primary==="solar","shared immediate calendar preferences");cal.select(new Date(2026,9,9,12));expect(cal.dayEvents.length===1,"markers survive calendar change");fixture.capture("secondary-off");}
    else if(fixture.phase===10) {
     var palette=JSON.parse(JSON.stringify(Core.Theme.palette));palette.surface="#fafafa";palette.surfaceContainerLow="#f5f5f5";palette.surfaceContainer="#eeeeee";palette.surfaceContainerHigh="#e5e5e5";palette.surfaceContainerHighest="#dddddd";palette.onSurface="#202020";palette.onSurfaceVariant="#505050";palette.primary="#006a60";palette.primaryContainer="#9cf3df";palette.onPrimaryContainer="#00201c";Core.Theme.palette=palette;
     cal.showMode(1);fixture.capture("light-month");
    } else if(fixture.phase===11) {
     cal.availableHeight=240;cal.edit(cal.dayEvents[0]);expect(cal.contentHeight===240 && cal.height===196,"constrained height scroll");fixture.capture("short-screen-editor");
    } else if(fixture.phase===12) {
     cal.showMode(1);state.setPreference("calendarWeekStart","monday");expect(cal.dateAt(0).getDay()===1,"Solar calendar Monday override");state.setPreference("calendarWeekStart","saturday");expect(cal.dateAt(0).getDay()===6,"Saturday override");state.setPreference("calendarWeekStart","sunday");expect(cal.dateAt(0).getDay()===0,"Sunday override");state.setPreference("calendarWeekStart","auto");
     cal.edit(cal.dayEvents[0]);var del=fixture.match(cal,item=>item.text==="Delete" && item.clicked);expect(!!del,"delete action");del.clicked();cal.reset();expect(cal.dayEvents.length===0 && !cal.editing && cal.viewMode===0,"reset and removal");
     console.log("CALENDAR_PASS: real QML loading, centered reset/navigation, editor validation/save/edit, marker associations, 4/5/6 week grids, Gregorian/Solar year, secondary Off, light theme, constrained scroll sizing");fixture.phase++;
    }
   }catch(error){console.error("CALENDAR_FAIL: "+error);fixture.phase=100;}
  }
 }
}
'''.replace('OUTPUT',str(output))
 (folder/'shell.qml').write_text(shell)
 env=dict(os.environ,QT_QPA_PLATFORM='wayland' if '--wayland' in sys.argv else 'offscreen',XDG_CONFIG_HOME=str(folder/'config'))
 proc=subprocess.Popen(['quickshell','-p',str(folder),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 lines=[]
 try:
  deadline=time.monotonic()+15
  while time.monotonic()<deadline:
   if select.select([proc.stdout],[],[],0.2)[0]:
    line=proc.stdout.readline();lines.append(line)
    if 'CALENDAR_PASS' in line or 'CALENDAR_FAIL' in line:break
   if proc.poll() is not None:break
  print(''.join(lines))
  assert any('CALENDAR_PASS:' in l for l in lines),'Calendar QML integration failed'
  assert not any(re.search(r'(ReferenceError|TypeError|Unable to assign|Binding loop)',l) for l in lines),'QML runtime error'
 finally:
  proc.terminate();proc.wait(timeout=3)
