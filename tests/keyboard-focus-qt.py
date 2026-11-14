"""Verify real keyboard activation and focus visibility with no desktop input."""
from pathlib import Path
import os,runpy,shutil,subprocess,tempfile,select,time
src=Path(__file__).resolve().parents[1]/'quickshell'
with tempfile.TemporaryDirectory(prefix='wizarch-keyboard-') as tmp:
 root=Path(tmp);(root/'core').mkdir();(root/'components').mkdir()
 shutil.copy2(src/'components/SettingsButton.qml',root/'components')
 runpy.run_path(str(Path(__file__).with_name('theme-fixture.py')))['write_theme'](root,src)
 (root/'core/qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Geometry 1.0 Geometry.qml\nGeometryContext 1.0 GeometryContext.qml\n')
 (root/'shell.qml').write_text('''import QtQuick
import QtTest
import Quickshell
import "components"
ShellRoot {
 id:fixture
 property int activations:0
 FloatingWindow {
  visible:true;implicitWidth:400;implicitHeight:200
  TestCase {id:input;name:"KeyboardFocus";when:false}
  Row {
   SettingsButton {id:flat;flat:true;text:"Flat action";onClicked:fixture.activations++}
   SettingsButton {id:disabled;enabled:false;text:"Disabled"}
   SettingsButton {visible:false;text:"Hidden"}
   SettingsButton {id:next;text:"Next action";onClicked:fixture.activations++}
  }
 }
 property int phase:0
 Timer {interval:120;repeat:true;running:true;onTriggered:{try{
  if(fixture.phase===0)flat.forceActiveFocus(Qt.TabFocusReason);
  else if(fixture.phase===1) {
   if(!flat.visualFocus || flat.background.border.width<=0)throw new Error("flat keyboard focus invisible");
   input.keyClick(Qt.Key_Return);input.keyClick(Qt.Key_Space);
   if(fixture.activations!==2)throw new Error("Enter/Space activation");
   input.keyClick(Qt.Key_Tab);
   if(!next.activeFocus || disabled.activeFocus)throw new Error("Tab did not skip hidden/disabled controls");
   input.keyClick(Qt.Key_Backtab);
   if(!flat.activeFocus)throw new Error("reverse traversal");
   console.log("KEYBOARD_FOCUS_PASS: flat focus is visible, Enter/Space activate, Tab and Shift+Tab skip unavailable controls");stop();
  }
  fixture.phase++;
 }catch(e){console.error("KEYBOARD_FOCUS_FAIL: "+e);stop();}}}
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_CONFIG_HOME=str(root/'config'))
 process=subprocess.Popen(['qs','-p',str(root/'shell.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);lines=[]
 try:
  deadline=time.monotonic()+8
  while time.monotonic()<deadline:
   if select.select([process.stdout],[],[],.2)[0]:
    line=process.stdout.readline();lines.append(line)
    if 'KEYBOARD_FOCUS_PASS:' in line or 'KEYBOARD_FOCUS_FAIL:' in line:break
   if process.poll() is not None:break
 finally:process.terminate();process.wait(timeout=3)
 output=''.join(lines);print(output)
 assert 'KEYBOARD_FOCUS_PASS:' in output and 'KEYBOARD_FOCUS_FAIL:' not in output,output
 assert not any(e in output for e in ['ReferenceError','TypeError','Binding loop','Failed to load configuration']),output
