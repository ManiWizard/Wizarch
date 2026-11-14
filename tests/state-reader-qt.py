"""Real QML reader: malformed data, process failure, coalescing and retry recovery."""
from pathlib import Path
import os,shutil,subprocess,tempfile,select,time
src=Path(__file__).resolve().parents[1]/'quickshell/core/StateReader.qml'
with tempfile.TemporaryDirectory(prefix='wizarch-state-reader-') as tmp:
    root=Path(tmp);shutil.copy2(src,root/'StateReader.qml')
    (root/'read.py').write_text('''import json,time,sys
from pathlib import Path
p=Path(__file__).with_name('count');n=int(p.read_text())+1 if p.exists() else 1;p.write_text(str(n));time.sleep(.15)
if n==1:print('{"value":1}')
elif n==2:print('bad json')
elif n==3:print('{"value":99}');sys.exit(1)
elif n==4:print('{"value":"invalid"}')
else:print(json.dumps({'value':n}))
''')
    (root/'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
 id:fixture
 property int phase:0
 property int acceptedCount:0
 property int value:0
 property bool sawFailure:false
 property bool missingRecovered:false
 property bool timeoutRecovered:false
 property int floodAccepted:0
 property bool floodVerified:false
 StateReader {
  id:flood;command:["python3","-c","import time;time.sleep(.15);print('{}')"];reconcileInterval:0
  onAccepted: value => fixture.floodAccepted++
 }
 Timer {id:storm;interval:10;repeat:true;running:true;onTriggered:flood.request()}
 Timer {interval:1000;running:true;onTriggered:{
  storm.stop();
  if(fixture.floodAccepted<2)console.error("STATE_READER_FAIL: continuous events starved reconciliation");
  else fixture.floodVerified=true;
 }}
 StateReader {
  id:missing;command:["/wizarch-nonexistent-reader"];reconcileInterval:0;requestTimeout:500
  onErrorMessageChanged: if(errorMessage) command=["python3","-c","print('{}')"]
  onAccepted: value => fixture.missingRecovered=true
 }
 StateReader {
  id:slow;command:["python3","-c","import time;time.sleep(60)"];reconcileInterval:0;requestTimeout:300
  onErrorMessageChanged: if(errorMessage) command=["python3","-c","print('{}')"]
  onAccepted: value => fixture.timeoutRecovered=true
 }
 StateReader {
  id:reader; command:["python3",Qt.resolvedUrl("read.py").toString().replace("file://", "")]; reconcileInterval:0
  validate: value => value && Number.isFinite(value.value)
  onAccepted: result => {fixture.value=result.value;fixture.acceptedCount++;}
 }
 Timer {interval:25;running:true;repeat:true;onTriggered:{
  try {
   if(fixture.phase===0 && fixture.value===1) {reader.request();reader.request();reader.request();fixture.phase=1;}
   if(reader.errorMessage) {fixture.sawFailure=true;if(fixture.value!==1)throw new Error("invalid data replaced last valid state");}
   if(fixture.phase===1 && fixture.value>=5 && fixture.missingRecovered && fixture.timeoutRecovered && fixture.floodVerified) {
    if(!fixture.sawFailure || fixture.acceptedCount!==2 || reader.errorMessage!=="")throw new Error("retry/coalescing invariant");
    console.log("STATE_READER_PASS: retained state through malformed JSON, nonzero exit and invalid schema; coalesced continuous events without starvation, killed a hung reader, recovered failed startup and retried successfully");stop();
   }
  }catch(e){console.error("STATE_READER_FAIL: "+e);stop();}
 }}
 Timer {interval:18000;running:true;onTriggered:{console.error("STATE_READER_FAIL: timeout");stop();}}
}
''')
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_CONFIG_HOME=str(root/'config'))
    process=subprocess.Popen(['qs','-p',str(root/'shell.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    lines=[]
    try:
        deadline=time.monotonic()+23
        while time.monotonic()<deadline:
            if select.select([process.stdout],[],[],.2)[0]:
                line=process.stdout.readline();lines.append(line)
                if 'STATE_READER_PASS:' in line or 'STATE_READER_FAIL:' in line:break
            if process.poll() is not None:break
    finally:
        process.terminate();process.wait(timeout=3)
    output=''.join(lines);print(output)
    assert 'STATE_READER_PASS:' in output and 'STATE_READER_FAIL:' not in output,output
    assert not any(e in output for e in ['ReferenceError','TypeError','Binding loop','Failed to load configuration']),output
