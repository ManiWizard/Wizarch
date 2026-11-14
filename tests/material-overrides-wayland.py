"""Actual production draft/card/apply agreement with inactive and edited-active local overrides.
Requires the isolated production matrix harness; never targets host IPC or device settings.
"""
import argparse,json,hashlib,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--session',required=True);b=Path(a.parse_args().session).resolve();env=json.loads((b/'launch.json').read_text())['env'];assert env['XDG_CONFIG_HOME'].startswith(str(b)) and env['XDG_RUNTIME_DIR'].endswith('/wm3')
h=b/'harness';shell=h/'shell.qml';original=shell.read_text();s=original.replace('  function query(text:string):void','''  function overridePreview(identity:string):string {Core.Theme.preview(identity);return JSON.stringify({draft:Core.Theme.draftColors,mode:Core.Theme.draftMode,wallpaper:Core.Theme.draftWallpaper,revision:Core.Theme.revision,applied:Core.Theme.palette});}
  function overrideCard(identity:string):string {let card=fixture.find(window.contentItem,item=>item.theme && item.theme.identity===identity);return JSON.stringify(card.previewColors);}
  function overrideAssetReady(identity:string):bool {let card=fixture.find(window.contentItem,item=>item.theme && item.theme.identity===identity);let image=fixture.find(card,item=>item.source && item.source.toString()===card.theme.wallpaper);return !!image && image.status===Image.Ready;}
  function overrideApply():void {Core.Theme.applyDraft();}
  function query(text:string):void''');shell.write_text(s)
# Keep current production singleton, including the review fixes; no facade mocking.
(h/'core/Theme.qml').write_bytes((ROOT/'quickshell/core/Theme.qml').read_bytes())
log=b/'override-shell.log';p=subprocess.Popen(['quickshell','-p',str(h)],env=env,stdout=log.open('w'),stderr=subprocess.STDOUT)
config=Path(env['XDG_CONFIG_HOME'])/'wizarch/theme-overrides.json';prior=config.read_bytes() if config.exists() else None
source=hashlib.sha256(b''.join(p.read_bytes() for p in sorted((ROOT/'quickshell').rglob('*')) if p.is_file() and p.suffix in ('.qml','.py','.js','.json'))).hexdigest();captures=[]
def call(method,*args):return subprocess.check_output(['quickshell','ipc','--pid',str(p.pid),'call','--','verify-material',method,*args],env=env,text=True,stderr=subprocess.STDOUT,timeout=5).strip()
def probe():return json.loads(call('probe'))
def wait(predicate):
 end=time.monotonic()+10
 while time.monotonic()<end:
  v=probe()
  if not v['applying'] and predicate(v):return v
  time.sleep(.04)
 raise AssertionError(v)
def write_override(schemes):
 temp=config.with_suffix('.tmp');temp.write_text(json.dumps({'schemaVersion':1,'packs':{'bundled:wizarch':{'schemes':schemes,'mode':'light','wallpaperId':'nocturne'}}}));temp.replace(config)
def preview_ready(expected):
 end=time.monotonic()+5
 while time.monotonic()<end:
  v=json.loads(call('overridePreview','bundled:wizarch'))
  if v['draft']==expected:return v
  time.sleep(.05)
 raise AssertionError(v)
def capture(surface,state):
 end=time.monotonic()+5
 while call('overrideAssetReady','bundled:wizarch')!='true':
  assert time.monotonic()<end,'preview wallpaper did not decode';time.sleep(.05)
 time.sleep(.15)
 path=ROOT/'outputs/material-theme'/('override-'+surface+'.png');subprocess.run(['grim','-o','WAYLAND-1',str(path)],env=env,check=True,timeout=5);captures.append({'path':str(path),'surface':surface,'sourceHash':source,'revision':probe()['revision'],'state':state,'fixture':'actual production QML and local per-mode overrides, isolated IPC/XDG; no device setters'})
try:
 end=time.monotonic()+10
 while 'Configuration Loaded' not in log.read_text():
  assert p.poll() is None and time.monotonic()<end,log.read_text();time.sleep(.05)
 call('apply','bundled:eclipse','dark');before=wait(lambda v:v['identity']=='bundled:eclipse' and v['mode']=='dark');call('settings','appearance');time.sleep(.2)
 schemes=json.loads((ROOT/'quickshell/themes/eclipse/colors.json').read_text())['schemes'];write_override(schemes);draft=preview_ready(schemes['light']);assert draft['revision']==before['revision'] and draft['applied']==before['roles'];assert draft['mode']=='light' and draft['wallpaper']=='nocturne'
 assert json.loads(call('overrideCard','bundled:wizarch'))==draft['draft'];capture('inactive-preview',{'mode':draft['mode'],'wallpaper':draft['wallpaper'],'colors':draft['draft'],'desktopRevisionUnchanged':True})
 call('overrideApply');after=wait(lambda v:v['identity']=='bundled:wizarch' and v['mode']=='light');assert after['roles']==draft['draft'];capture('applied',{'previewMatchesApplied':True})
 # An edited override for the active pack must also preview new colors before Apply.
 schemes=json.loads((ROOT/'quickshell/themes/wizarch/colors.json').read_text())['schemes'];write_override(schemes);draft=preview_ready(schemes['light']);assert draft['revision']==after['revision'];assert json.loads(call('overrideCard','bundled:wizarch'))==draft['draft'];capture('edited-active-preview',{'desktopRevisionUnchanged':True,'colors':draft['draft']});call('cancelPreview');assert probe()['revision']==after['revision']
 errors=subprocess.check_output(['hyprctl','configerrors'],env=env,text=True);assert not errors.strip();warnings=[x for x in log.read_text().splitlines() if re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop|Failed to load',x)];assert not warnings,warnings
 (ROOT/'outputs/material-theme/overrides-index.json').write_text(json.dumps({'sourceHash':source,'screenshots':captures,'warnings':warnings,'compositorErrors':errors},indent=2)+'\n');print('PASS: 3 actual override renders; inactive preview/card/apply agree; active override edits preview without publishing; Cancel preserves desktop')
finally:
 if prior is None:config.unlink(missing_ok=True)
 else:config.write_bytes(prior)
 p.terminate();p.wait(timeout=5);shell.write_text(original)
