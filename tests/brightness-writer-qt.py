"""Production brightness queue: optimistic edits, stale poll rejection and recovery."""
from pathlib import Path
import os,shutil,subprocess,tempfile,select,time,json
src=Path(__file__).resolve().parents[1]/'quickshell'
with tempfile.TemporaryDirectory(prefix='wizarch-brightness-') as tmp:
 root=Path(tmp);(root/'core').mkdir();(root/'services').mkdir()
 shutil.copy2(src/'core/StateReader.qml',root/'core/StateReader.qml')
 (root/'services/desktop-status.py').write_text('''import sys,json,time
from pathlib import Path
p=Path(__file__).with_name('level');level=int(p.read_text()) if p.exists() else 50
if len(sys.argv)>1:
 value=int(sys.argv[2]);log=p.with_name('actions');actions=json.loads(log.read_text()) if log.exists() else [];actions.append(value);log.write_text(json.dumps(actions));time.sleep(.35)
 if value==99:print('{"ok":false}');sys.exit(1)
 level=value;p.write_text(str(level))
else:time.sleep(.6)
print(json.dumps({'ok':True,'wifi':True,'brightness':level}))
''')
 s=(src/'core/SystemServices.qml').read_text()
 setter=s[s.index('    function setBrightness('):s.index('    function defer(')]
 block=s[s.index('    property string scrollingError:'):s.index('    Timer {\n        id: deferredAction')]
 block=block.replace('id: actionResult }','id: actionResult }\n        stderr: StdioCollector { onStreamFinished: if(text.trim())console.log("ACTION_STDERR:"+text) }')
 poll=s[s.index('    StateReader {\n        id: networkPoll'):s.rfind('\n}')]
 (root/'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "core"
ShellRoot {
 id:root
 property var network: ({wifi:true,brightness:50})
 property string stateError:""
 property int phase:0
 property bool keepLatest:false
'''+(setter+block+poll).replace('../services/desktop-status.py','services/desktop-status.py')+'''

 Timer {interval:30;repeat:true;running:true;onTriggered:{try{
  if(root.keepLatest && root.network.brightness!==90)throw new Error("stale response replaced latest edit: "+root.network.brightness);
  if(root.phase===0){root.setBrightness(70);if(root.network.brightness!==70)throw new Error("edit not immediate");root.phase=1;}
  else if(root.phase===1 && systemAction.running){root.setBrightness(90);root.keepLatest=true;root.phase=2;}
  else if(root.phase===2 && !root.brightnessPending && !systemAction.running && root.confirmedBrightness===90){root.keepLatest=false;root.setBrightness(99);root.phase=3;}
  else if(root.phase===3 && root.controlError){if(root.network.brightness!==90)throw new Error("failure did not restore confirmed brightness");root.setBrightness(65);root.phase=4;}
  else if(root.phase===4 && !root.brightnessPending && !systemAction.running && root.network.brightness===65 && !root.actionError){console.log("BRIGHTNESS_PASS: immediate edits, in-flight latest value, stale poll rejection, failed write recovery and retry");stop();}
 }catch(e){console.error("BRIGHTNESS_FAIL: "+e);stop();}}}
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_CONFIG_HOME=str(root/'config'))
 p=subprocess.Popen(['qs','-p',str(root/'shell.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);lines=[]
 try:
  end=time.monotonic()+12
  while time.monotonic()<end:
   if select.select([p.stdout],[],[],.2)[0]:
    line=p.stdout.readline();lines.append(line)
    if 'BRIGHTNESS_PASS:' in line or 'BRIGHTNESS_FAIL:' in line:break
   if p.poll() is not None:break
 finally:p.terminate();p.wait(timeout=3)
 output=''.join(lines);print(output)
 assert 'BRIGHTNESS_PASS:' in output and 'BRIGHTNESS_FAIL:' not in output,output
 assert json.loads((root/'services/actions').read_text())==[70,90,99,65]
 assert not any(e in output for e in ['ReferenceError','TypeError','Binding loop','Failed to load configuration']),output
