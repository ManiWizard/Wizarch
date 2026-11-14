"""A real Theme facade retains its catalog when a watcher dies and recovers it."""
from pathlib import Path
import os,shutil,subprocess,tempfile,select,time,json
src=Path(__file__).resolve().parents[1]/'quickshell'
with tempfile.TemporaryDirectory(prefix='wizarch-theme-watcher-') as tmp:
 root=Path(tmp);(root/'core').mkdir();(root/'services').mkdir();(root/'state/wizarch/theme').mkdir(parents=True)
 for name in ['Theme.qml','Fallback.js']:shutil.copy2(src/'core'/name,root/'core'/name)
 (root/'core/qmldir').write_text('singleton Theme 1.0 Theme.qml\n')
 # Reuse known valid data solely as an isolated input; no activation is performed.
 shutil.copy2(Path.home()/'.local/state/wizarch/theme/active.json',root/'state/wizarch/theme/active.json')
 (root/'services/themes.py').write_text('''import sys,json,time
from pathlib import Path
if sys.argv[1]=='watch':
 p=Path(__file__).with_name('runs');n=int(p.read_text())+1 if p.exists() else 1;p.write_text(str(n))
 if n==1:print(json.dumps({'ok':True,'catalog':[{'identity':'first'}]}),flush=True);time.sleep(.2)
 elif n==2:print('invalid json',flush=True);time.sleep(.2)
 else:print(json.dumps({'ok':True,'catalog':[{'identity':'recovered'}]}),flush=True);time.sleep(60)
else:print('{"ok":true}')
''')
 (root/'shell.qml').write_text('''import QtQuick
import Quickshell
import "core" as Core
ShellRoot {
 id:fixture
 property bool firstSeen:false
 property bool failed:false
 Timer {interval:30;repeat:true;running:true;onTriggered:{
  if(Core.Theme.catalog.length && Core.Theme.catalog[0].identity==="first")fixture.firstSeen=true;
  if(Core.Theme.errorMessage.indexOf("catalog")!==-1 || Core.Theme.errorMessage.indexOf("Catalog")!==-1) {
   fixture.failed=true;
   if(!Core.Theme.catalog.length || Core.Theme.catalog[0].identity!=="first") {console.error("THEME_WATCHER_FAIL: lost last valid catalog");stop();}
  }
  if(Core.Theme.catalog.length && Core.Theme.catalog[0].identity==="recovered") {
   if(!fixture.firstSeen || !fixture.failed || Core.Theme.errorMessage!=="")console.error("THEME_WATCHER_FAIL: reconnect state");
   else console.log("THEME_WATCHER_PASS: retained catalog across process exit and malformed stream, reconnected and cleared its own error");
   stop();
  }
 }}
}
''')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_CONFIG_HOME=str(root/'config'),XDG_STATE_HOME=str(root/'state'))
 process=subprocess.Popen(['qs','-p',str(root/'shell.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 lines=[]
 try:
  deadline=time.monotonic()+15
  while time.monotonic()<deadline:
   if select.select([process.stdout],[],[],.2)[0]:
    line=process.stdout.readline();lines.append(line)
    if 'THEME_WATCHER_PASS:' in line or 'THEME_WATCHER_FAIL:' in line:break
   if process.poll() is not None:break
 finally:process.terminate();process.wait(timeout=3)
 output=''.join(lines);print(output)
 assert 'THEME_WATCHER_PASS:' in output and 'THEME_WATCHER_FAIL:' not in output,output
 assert not any(e in output for e in ['ReferenceError','TypeError','Binding loop','Failed to load configuration']),output
