"""Deterministic current-design captures on an explicitly isolated compositor."""
import argparse,json,os,re,runpy,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--session',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--scale-check',action='store_true');p.add_argument('--input-only',action='store_true');p.add_argument('--input-driver',type=Path);p.add_argument('--hotplug',action='store_true');p.add_argument('--stress',action='store_true');args=p.parse_args()
env=json.loads((args.session/'launch.json').read_text())['env']
assert env['XDG_RUNTIME_DIR']!=os.environ.get('XDG_RUNTIME_DIR')
assert env['HYPRLAND_INSTANCE_SIGNATURE']!=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
h=out/'harness';shutil.copytree(args.source,h,ignore=shutil.ignore_patterns('__pycache__'),dirs_exist_ok=True)
# No live service/device writes: fixture state, frozen time and palette, real components.
active=json.loads((Path.home()/'.local/state/wizarch/theme/active.json').read_text())
runpy.run_path(str(ROOT/'tests/theme-fixture.py'))['write_theme'](h,args.source)
f=h/'core/Theme.qml';text=f.read_text().replace('property var palette: Fallback.colors','property var palette: '+json.dumps(active['colors'])).replace('property string wallpaper: ""','property string wallpaper: '+json.dumps(active['wallpaper'])).replace('property string logo: ""','property string logo: '+json.dumps(active.get('logo','')));f.write_text(text)
(h/'core/Workspaces.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {function forMonitor(name){return {current:1,used:[1,3],revision:0,desktop:false};}function isSwitching(name){return false;}function select(number,monitor){}}\n')
prefs=json.loads((Path.home()/'.config/wizarch/preferences.json').read_text());prefs['uiScaleByOutput']={}
(h/'shell.qml').write_text((ROOT/'tests/upgrade-fixture.qml').read_text().replace('FIXTURE_PREFERENCES',json.dumps(prefs)))
env=dict(env,XDG_CONFIG_HOME=str(out/'config'),XDG_STATE_HOME=str(out/'state'),XDG_DATA_HOME=str(out/'data'),XDG_CACHE_HOME=str(out/'cache'),QT_QPA_PLATFORM='wayland')
log=out/'shell.log';process=subprocess.Popen(['qs','-p',str(h),'--no-color'],env=env,stdout=log.open('w'),stderr=subprocess.STDOUT)
def call(function,*values):
 return subprocess.check_output(['qs','ipc','--pid',str(process.pid),'call','--','upgrade-test',function,*map(str,values)],env=env,text=True,stderr=subprocess.STDOUT,timeout=5).strip()
def probe():return json.loads(call('probe'))
def ctl(*values):return subprocess.check_output(['hyprctl',*values],env=env,text=True,stderr=subprocess.STDOUT,timeout=5)
records=[]
try:
 for _ in range(60):
  try:
   data=probe()
   if len(data['pills'])==2:break
  except subprocess.SubprocessError:pass
  if process.poll() is not None:raise RuntimeError(log.read_text())
  time.sleep(.1)
 else:raise RuntimeError('Fixture did not start: '+log.read_text())
 time.sleep(1)
 for output in ([] if args.input_only else ['UPGRADE-A','UPGRADE-B']):
  for surface in ['hidden','revealed','launcher','status','clock','notifications','settings','wheel']:
   call('show',surface,output);time.sleep(.9 if surface!='revealed' else .4)
   file=out/(output+'-'+surface+'.png');subprocess.run(['grim','-o',output,str(file)],env=env,check=True,timeout=5)
   data=probe();records.append({'surface':surface,'output':output,'probe':data,'capture':file.name})
   for panel in data['pills']:
    if not panel['section']:assert panel['keyboard']==0,('closed panel retained keyboard',data)
 call('show','revealed','UPGRADE-A');time.sleep(.5)
 if args.hotplug:
  initial=probe();ctl('output','remove','UPGRADE-B');time.sleep(.7);assert len(probe()['pills'])==1
  ctl('output','create','headless','UPGRADE-B');ctl('eval','hl.monitor({output="UPGRADE-B",mode="1920x1080@60",position="1920x0",scale=1})');time.sleep(.8)
  assert len(probe()['pills'])==2
  before=next(p for p in initial['pills'] if p['output']=='UPGRADE-A');after=next(p for p in probe()['pills'] if p['output']=='UPGRADE-A')
  assert before['width']==after['width'] and before['height']==after['height'],(before,after)
  records.append({'hotplug':'passed','before':before,'after':after})
 if args.scale_check:
  call('scale',2);call('show','status','UPGRADE-A');time.sleep(1)
  scaled=probe();state=json.loads(call('statusViewport'))
  (out/'scale-probe.json').write_text(json.dumps({'geometry':scaled,'status':state},indent=2)+'\n')
  panel=next(p for p in scaled['pills'] if p['output']=='UPGRADE-A')
  assert panel['targetHeight']<=1080 and state['viewport'] and state['viewport']['interactive'],('scaled Quick Settings overflows monitor',scaled,state)
  subprocess.run(['grim','-o','UPGRADE-A',str(out/'scale-top.png')],env=env,check=True,timeout=5)
  call('scrollStatus');time.sleep(.2);state=json.loads(call('statusViewport'))
  assert state['viewport']['contentY']>0 and state['viewport']['contentY']+state['viewport']['height']>=state['viewport']['contentHeight']-.1,state
  subprocess.run(['grim','-o','UPGRADE-A',str(out/'scale-bottom.png')],env=env,check=True,timeout=5)
  records.append({'scale2':'bounded viewport reaches all content','state':state})
  call('scale',1);call('show','hidden','UPGRADE-A');time.sleep(.6)
 if args.input_driver:
  driver=subprocess.Popen([str(args.input_driver.resolve())],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
  def send(command):
   driver.stdin.write(command+'\n');driver.stdin.flush();assert driver.stdout.readline().strip()=='ok';time.sleep(.06)
  def key(code):send('key '+str(code))
  def click(x,y):send(f'move {x} {y}');send('button 272 1');send('button 272 0')
  try:
   send('extent 3840 1080')
   for output,offset in [('UPGRADE-A',0),('UPGRADE-B',1920)]:
    call('show','status',output);time.sleep(.8);click(offset+1128,420);key(15)
    data=probe();panel=next(p for p in data['pills'] if p['output']==output)
    assert panel['focusName'],('Tab did not enter visible controls',data)
    key(1);time.sleep(.5);assert all(not p['section'] and p['keyboard']==0 for p in probe()['pills'])
    call('show','launcher',output);time.sleep(.8);key(30);key(1);time.sleep(.15)
    assert all(not p['query'] for p in probe()['pills']),probe()
    key(1);time.sleep(.5)
    assert all(not p['section'] for p in probe()['pills']),probe()
    call('show','wheel',output);time.sleep(.3);key(102);assert probe()['wheelSelection']==0
    key(15);assert probe()['wheelSelection']==1
    send('mods 1');key(15);send('mods 0');assert probe()['wheelSelection']==0
    key(28);time.sleep(.3);assert not probe()['wheel']
    call('show','settings',output);time.sleep(.4)
    ctl('eval','local w=hl.get_window("title:Wizarch Settings"); if w then hl.dispatch(hl.dsp.focus({window=w})) end')
    send('mods 4');key(33);send('mods 0');time.sleep(.2);assert probe()['settings']['search']
    key(1);time.sleep(.15);assert not probe()['settings']['search']
    assert probe()['settings']['focusName']=='Search settings',probe()
    key(1);time.sleep(.2);assert not probe()['settings']['visible']
   if args.scale_check:
    call('scale',2);call('show','status','UPGRADE-A');time.sleep(.8);click(1310,100)
    maximum=0
    for _ in range(26):
     key(15);state=json.loads(call('statusViewport'));maximum=max(maximum,state['viewport']['contentY'])
    assert maximum>0,('keyboard focus never scrolled enlarged controls',state)
    key(1);time.sleep(.3);call('scale',1)
    records.append({'scaledKeyboardScroll':maximum})
   records.append({'physicalInputOutputs':2,'checks':'mouse focus, Tab, typed launcher/Escape, wheel Home/Tab/Shift+Tab/Enter, Settings Ctrl+F/Escape and restored trigger focus'})
  finally:
   driver.stdin.close();driver.wait(timeout=3)
 def resource():
  fields=Path(f'/proc/{process.pid}/stat').read_text().split()
  return {'cpuTicks':int(fields[13])+int(fields[14]),'rssBytes':int(fields[23])*os.sysconf('SC_PAGE_SIZE')}
 call('show','hidden','UPGRADE-A');call('show','hidden','UPGRADE-B');time.sleep(.6)
 idleBefore=resource();time.sleep(10);idleAfter=resource()
 records.append({'idleSeconds':10,'before':idleBefore,'after':idleAfter,'cpuTicks':idleAfter['cpuTicks']-idleBefore['cpuTicks']})
 if args.stress:
  samples=[]
  for batch in range(3):
   for repeat in range(2):
    for surface in ['launcher','status','clock','notifications','settings','wheel','hidden','revealed']:
     call('show',surface,'UPGRADE-A');time.sleep(.3)
   call('show','hidden','UPGRADE-A');time.sleep(.6);samples.append(resource())
  # Caches may grow once. The last two equal-work batches must approach a plateau.
  assert samples[-1]['rssBytes']-samples[-2]['rssBytes'] < 12*1024*1024,samples
  records.append({'stressOpens':48,'samples':samples})
 errors=ctl('configerrors');assert not errors.strip(),errors
 warnings=[l for l in log.read_text().splitlines() if re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop|Failed to load',l)]
 assert not warnings,warnings
 (out/'index.json').write_text(json.dumps({'records':records,'errors':errors,'runtimeErrors':warnings},indent=2)+'\n')
 print('UPGRADE_WAYLAND_PASS:',len(records),'records',out)
finally:
 process.terminate();process.wait(timeout=5)
