"""Additional actual production controls on the already isolated matrix harness."""
import argparse,hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--session',required=True);b=Path(a.parse_args().session).resolve();launch=json.loads((b/'launch.json').read_text());env=launch['env'];assert env['XDG_CONFIG_HOME'].startswith(str(b)) and env['XDG_RUNTIME_DIR'].endswith('/wm3')
h=b/'harness';shell=h/'shell.qml';template=h/'controls-original.qml';
if not template.exists():template.write_text(shell.read_text())
s=template.read_text();s=re.sub(r'  function controls\(kind:string\):string.*?(?=  function query\(text:string\):void)', '', s, flags=re.S);s=s.replace('  function query(text:string):void', '''  function controls(kind:string):string {
   let p=fixture.mainPill(),l=fixture.find(p.contentItem,item=>item.searchText!==undefined);
   if(kind==="selection" || kind==="caret") { l.searchText="Material selection";let input=fixture.find(l,item=>typeof item.selectAll==="function" && item.text===l.searchText);input.forceActiveFocus();if(kind==="selection")input.selectAll();else{input.deselect();input.cursorPosition=input.text.length;input.cursorVisible=true;}return JSON.stringify({focus:input.activeFocus,selection:input.selectedText,cursorVisible:input.cursorVisible}); }
   if(kind==="context") {l.openContext("empty",null,null,30,70);return JSON.stringify({open:l.contextOpen,entries:l.contextEntries.length});}
   let choice=fixture.find(window.contentItem,item=>item.popup && item.model && item.model.indexOf && item.model.indexOf("light")!==-1);
   if(kind==="mode-popup") {choice.forceActiveFocus();choice.popup.open();return JSON.stringify({visible:choice.popup.visible,current:choice.currentIndex});}
   if(kind==="close-popup") {choice.popup.close();return "{}";}
   return "{}";
  }
  function metadata():string {
   let card=fixture.find(window.contentItem,item=>item.theme && item.theme.identity===Core.Theme.selectedIdentity);
   card.theme=Object.assign({},card.theme,{name:"Theme <b>literal</b>",description:"Data <i>only</i>"});
   let label=fixture.find(card,item=>item.text==="Theme <b>literal</b>");let description=fixture.find(card,item=>item.text==="Data <i>only</i>");
   let view=fixture.find(window.contentItem,item=>item.page!==undefined && item.contentY!==undefined);view.contentY=0;
   return JSON.stringify({name:label.text,plain:label.textFormat===Text.PlainText && description.textFormat===Text.PlainText});
  }
  function tooltip():string {
   let seen=new Set();function walk(item){if(seen.has(item))return null;seen.add(item);if(item.text==="Apps" && typeof item.open==="function")return item;for(let child of [...(item.children || []),...(item.data || [])]){let result=walk(child);if(result)return result;}return null;}
   let tip=walk(fixture.mainPill().contentItem);return JSON.stringify({visible:tip.visible,background:String(tip.background.color),ink:String(tip.contentItem.color)});
  }
  function query(text:string):void''');shell.write_text(s)
log=b/'controls-shell.log';p=subprocess.Popen(['quickshell','-p',str(h)],env=env,stdout=log.open('w'),stderr=subprocess.STDOUT);records=[]
driver=subprocess.Popen([str(b/'pointer/pointer')],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
def call(target,method,*args):return subprocess.check_output(['quickshell','ipc','--pid',str(p.pid),'call','--',target,method,*map(str,args)],env=env,text=True,stderr=subprocess.STDOUT,timeout=5).strip()
def probe():return json.loads(call('verify-material','probe'))
def wait(identity,mode):
 end=time.monotonic()+10
 while time.monotonic()<end:
  x=probe()
  if x['identity']==identity and x['mode']==mode and not x['applying'] and not x['busy'] and abs(x['width']-x['targetWidth'])<.1 and abs(x['height']-x['targetHeight'])<.1:return x
  time.sleep(.04)
 raise AssertionError(x)
def pointer(command):driver.stdin.write(command+'\n');driver.stdin.flush();assert driver.stdout.readline().strip()=='ok';time.sleep(.13)
source=hashlib.sha256(b''.join(p.read_bytes() for p in sorted((ROOT/'quickshell').rglob('*')) if p.is_file() and p.suffix in ('.qml','.py','.js','.json'))).hexdigest()
def capture(theme,mode,surface,state):
 v=probe();assert v['actualRoles']==v['roles'];path=ROOT/'outputs/material-theme'/f'{theme}-{mode}-{surface}.png';subprocess.run(['grim','-o','WAYLAND-1',str(path)],env=env,check=True,timeout=5);records.append({'path':str(path),'theme':theme,'mode':mode,'surface':surface,'sourceHash':source,'revision':v['revision'],'state':state,'fixture':'existing production controls, actual nested Wayland; no device setter called'})
try:
 end=time.monotonic()+10
 while 'Configuration Loaded' not in log.read_text():
  assert p.poll() is None and time.monotonic()<end,log.read_text();time.sleep(.05)
 custom=json.loads(subprocess.check_output(['python3',str(h/'services/themes.py'),'import',str(ROOT/'examples/material-collection')],env=env,text=True))['installed'][0]
 for theme,identity in [('eclipse','bundled:eclipse'),('wizarch','bundled:wizarch'),('aurora-highcontrast',custom)]:
  for mode in ['dark','light']:
   call('verify-material','apply',identity,mode);wait(identity,mode)
   call('panel-WAYLAND-1','show','launcher');time.sleep(.6);wait(identity,mode)
   state=json.loads(call('verify-material','controls','selection'));assert state['selection']=='Material selection' and state['focus'];time.sleep(.12);capture(theme,mode,'search-selection',state)
   state=json.loads(call('verify-material','controls','caret'));assert state['focus'] and state['cursorVisible'];time.sleep(.1);capture(theme,mode,'search-caret',state)
   state=json.loads(call('verify-material','controls','context'));assert state['open'] and state['entries']>0;time.sleep(.3);wait(identity,mode);capture(theme,mode,'launcher-context-menu',state)
   call('verify-material','settings','appearance');call('verify-material','scrollAppearance');time.sleep(.2);state=json.loads(call('verify-material','controls','mode-popup'));assert state['visible'];time.sleep(.12);capture(theme,mode,'appearance-mode-popup',state);call('verify-material','controls','close-popup');state=json.loads(call('verify-material','metadata'));assert state['plain'];time.sleep(.1);capture(theme,mode,'appearance-literal-metadata',state);call('verify-material','closeSettings')
   call('panel-WAYLAND-1','show','');time.sleep(.55);wait(identity,mode);pointer('move 888 30');time.sleep(.3);state=json.loads(call('verify-material','tooltip'));v=probe();assert state['visible'] and state['background']==v['roles']['inverseSurface'] and state['ink']==v['roles']['inverseOnSurface'],state;capture(theme,mode,'apps-tooltip',state);pointer('move 2 2')
 errors=subprocess.check_output(['hyprctl','configerrors'],env=env,text=True);assert not errors.strip()
 warnings=[x for x in log.read_text().splitlines() if re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop|Failed to load',x)];assert not warnings,warnings
 (ROOT/'outputs/material-theme/controls-index.json').write_text(json.dumps({'sourceHash':source,'screenshots':records,'warnings':warnings,'compositorErrors':errors},indent=2)+'\n');print('PASS:',len(records),'additional actual controls captures; selection/caret/context menu/mode popup/tooltip in all six modes')
finally:driver.stdin.close();driver.wait(timeout=5);p.terminate();p.wait(timeout=5)
