from pathlib import Path
import os,shutil,subprocess,tempfile
src=Path(__file__).resolve().parents[1] / 'quickshell'
folder=Path(tempfile.mkdtemp(prefix='wizarch-writer-'))
(folder/'core').mkdir();(folder/'services').mkdir()
shutil.copy(src/'core/PreferenceQueue.js',folder/'core')
shutil.copy(src/'services/preferences.py',folder/'services/real-preferences.py')
(folder/'services/preferences.py').write_text('''import os,sys,time,subprocess
from pathlib import Path
p=Path(os.environ['XDG_CONFIG_HOME'])/'writes'
if len(sys.argv)>1:
 n=int(p.read_text())+1 if p.exists() else 1;p.write_text(str(n))
 if n==1: time.sleep(.5)
 if n==3: print('malformed output');sys.exit(1)
r=subprocess.run([sys.executable,str(Path(__file__).with_name('real-preferences.py'))]+sys.argv[1:]);sys.exit(r.returncode)
''')
s=(src/'core/SystemServices.qml').read_text()
start=s.index('    property var preferenceQueue:');end=s.index('    function playAlert()',start)
block=s[start:end]
loadstart=s.index('    Process {\n        id: preferenceLoad');loadend=s.index('    readonly property var indicators',loadstart)
load=s[loadstart:loadend]

fixture='''import QtQuick
import Quickshell
import Quickshell.Io
import "PreferenceQueue.js" as PreferenceQueue
ShellRoot {
 id: root
 Component.onCompleted: root.setPreference("dnd", true)
 property var preferences: ({})
 Timer {id: spacingDebounce; interval:180}
'''+block+load+'''
 property int phase:0
 Timer {
  interval:40; running:true; repeat:true
  onTriggered: {

   if(phase===0 && root.preferencesLoaded){ root.setPreference("systemVolume",20);root.setPreference("systemVolume",21);root.setPreference("calendarEvents",[{id:"fixture",date:"2026-10-09",title:"Before",color:"",icon:""}]);phase=1; }
   else if(phase===1 && preferenceWriter.running){root.setPreference("systemVolume",40);root.setPreference("calendarEvents",[{id:"fixture",date:"2026-10-09",title:"After",color:"#aabbcc",icon:"★"}]);phase=2;}
   else if(phase===2 && !preferenceWriter.running && Object.keys(root.preferenceQueue.pending).length===0){
    if(root.preferenceError || root.preferences.systemVolume!==40) throw new Error("rapid save failed");
    root.setPreference("systemVolume",50);phase=3;
   }
   else if(phase===3 && root.preferenceError){root.setPreference("systemVolume",60);root.setCalendarSystems("solar","solar");root.setCalendarSystems("solar","gregorian");root.retryPreferences();phase=4;}
   else if(phase===4 && !preferenceWriter.running && Object.keys(root.preferenceQueue.pending).length===0 && !root.preferenceError){console.log("WRITER_PASS: "+root.preferences.systemVolume);phase=5;}
  }
 }
}
'''
(folder/'core/TestWriter.qml').write_text(fixture.replace('ShellRoot {', 'Scope {'))
(folder/'shell.qml').write_text('import Quickshell\nimport \"core\"\nShellRoot { TestWriter {} }\n')
env=dict(os.environ,XDG_CONFIG_HOME=str(folder/'config'))
proc=subprocess.Popen(['qs','-p',str(folder/'shell.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
try:
 import time
 deadline=time.monotonic()+8
 # Read asynchronously so a failed fixture cannot hang this check.
 import select
 lines=[]
 while time.monotonic()<deadline:
  if select.select([proc.stdout],[],[],.2)[0]:
   line=proc.stdout.readline();lines.append(line)
   if 'WRITER_PASS' in line:break
  if proc.poll() is not None:break
 print(''.join(lines))
 assert any('WRITER_PASS: 60' in line for line in lines), 'Qt writer integration failed'
 import json
 saved=json.loads((folder/'config/wizarch/preferences.json').read_text())
 assert saved['systemVolume']==60
 assert saved['dnd'] is True
 assert saved['calendarPrimary']=='solar' and saved['calendarSecondary']=='gregorian'
 assert saved['calendarEvents']==[{'id':'fixture','date':'2026-10-09','title':'After','color':'#aabbcc','icon':'★'}]
 assert (folder/'config/writes').read_text()=='4'
 print('PASS: real Qt Process/stdout/exit handling, in-flight edits, malformed failure/retry, final disk value 60')
finally:
 proc.terminate();proc.wait(timeout=3)
