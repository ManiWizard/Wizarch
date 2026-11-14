"""Isolated real-QML geometry capture; never starts the installed shell or invokes devices.

Run --source PATH --output PATH --label baseline to capture a pristine source tree.
Run --baseline PATH to compare final geometry to an earlier capture.
"""
from pathlib import Path
import argparse,json,os,re,runpy,select,shutil,subprocess,tempfile,time

def main():
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=Path(__file__).resolve().parents[1]/'quickshell');p.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'audit/geometry');p.add_argument('--label',default='final');p.add_argument('--baseline',type=Path);p.add_argument('--dpr',default='1');p.add_argument('--ui-scale',type=float,default=1);p.add_argument('--font-size',type=float,default=13);p.add_argument('--pill',action='store_true');args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='wizarch-geometry-') as temp:
  folder=Path(temp);(folder/'core').mkdir();shutil.copytree(args.source/'components',folder/'components');shutil.copytree(args.source/'assets',folder/'assets')
  runpy.run_path(str(Path(__file__).with_name('theme-fixture.py')))['write_theme'](folder,args.source)
  qmldir='singleton Theme 1.0 Theme.qml\n'
  for name in ['Geometry.qml','Geometry.js','GeometryContext.qml']:
   if (args.source/'core'/name).exists():shutil.copy2(args.source/'core'/name,folder/'core'/name)
  if (folder/'core/Geometry.qml').exists():qmldir+='singleton Geometry 1.0 Geometry.qml\nGeometryContext 1.0 GeometryContext.qml\n'
  (folder/'core/qmldir').write_text(qmldir)
  qml='''pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "components"
import "core" as Core
ShellRoot {
 id:fixture
 property var uiGeometry: Core.Geometry
 property int phase:0
 property bool busy:false
 property var samples:[]
 property var cases:["zero","tiny","half","full-checked-focused","narrow-large-font"]
 FloatingWindow {
  visible:true;implicitWidth:380;implicitHeight:450;color:Core.Theme.surface
  Item {id:canvas;anchors.fill:parent
   SettingsButton {id:button;objectName:"button";x:20;y:16;text:"Geometry button"}
   SettingsSwitch {id:toggle;objectName:"switch";x:20;y:66}
   SettingsSlider {id:settings;objectName:"settingsSlider";x:20;y:112;width:340;label:"Settings level"}
   GlassSlider {id:glass;objectName:"glassSlider";x:20;y:184;width:340;label:"Glass level"}
   QuickSliderRow {id:quick;objectName:"quickSlider";x:20;y:254;width:340;accessibleName:"Quick level";actionName:"Toggle";actionCheckable:true}
   SettingsSection {id:section;objectName:"section";x:20;y:322;width:340
    Rectangle {width:parent.width;height:30;color:Core.Theme.surface}
   }
  }
 }
 function flatten(item,path) {
  let data={path:path,type:String(item).split("(")[0],x:item.x,y:item.y,width:item.width,height:item.height};
  if(item.radius!==undefined)data.radius=item.radius;
  if(item.border!==undefined)data.border=item.border.width;
  let result=[data],index=0;
  for(let child of item.children||[])result=result.concat(flatten(child,path+"/"+(child.objectName||String(index++))));
  return result;
 }
 function snapshot(){let data={};for(let control of [button,toggle,settings,glass,quick,section])data[control.objectName]=flatten(control,control.objectName);samples.push({name:cases[phase],controls:data});busy=true;canvas.grabToImage(result=>{if(!result.saveToFile("OUTPUT/"+cases[phase]+".png"))console.error("GEOMETRY_FAIL: capture");busy=false;phase++;});}
 Timer {interval:200;repeat:true;running:true;onTriggered:{
  if(fixture.busy)return;
  if(fixture.phase===fixture.cases.length){console.log("GEOMETRY_RESULT: "+JSON.stringify(fixture.samples));stop();return;}
  let levels=[0,0.2,50,100,1];settings.level=levels[fixture.phase];glass.level=levels[fixture.phase];quick.level=levels[fixture.phase];
  toggle.checked=fixture.phase>=3;quick.actionActive=fixture.phase>=3;
  if(fixture.phase===3){toggle.forceActiveFocus();}
  if(fixture.phase===4){settings.width=160;glass.width=160;quick.width=160;section.width=160;button.font.pixelSize=20;}
  fixture.busy=true;settle.restart();
 }}
 Timer {id:settle;interval:170;onTriggered:{fixture.busy=false;fixture.snapshot();}}
}
'''.replace('OUTPUT',str(args.output.resolve()))
  if (folder/'core/Geometry.qml').exists():qml=qml.replace(' id:fixture',' id:fixture\n Component.onCompleted: {Core.Geometry.uiScale='+str(args.ui_scale)+'; Core.Geometry.fontSize='+str(args.font_size)+'; Core.Geometry.devicePixelRatio='+args.dpr+';}')
  if args.pill:
   source=(args.source/'components/Pill.qml').read_text();start=source.index('    Shape {',source.index('// Concave shoulders'));end=source.index('    Rectangle {',start);shape=source[start:end];bodyStart=end;bodyEnd=source.index('        HoverHandler {',bodyStart);body=source[bodyStart:bodyEnd]
   borderStart=source.index('        border.width:',bodyEnd);borderEnd=source.index('        Keys.onPressed:',borderStart);body+=source[borderStart:borderEnd]+'    }\n'
   qml="""import QtQuick
import QtQuick.Shapes
import Quickshell
import \"core\" as Core
ShellRoot {
 id:fixture
 property var uiGeometry: Core.Geometry
 property int phase:0
 property bool busy:false
 property var samples:[]
 property var cases:[\"collapsed\",\"expanded\",\"launcher\",\"hidden-offset\",\"floating\",\"screen-border\"]
 QtObject { id:pillWindow
  property real surfaceWidth:194
  property real surfaceHeight:42
  property bool edgeConnected:true
  property bool screenBorder:false
  property real borderThickness:3
  property real borderRadius:12
  property real hideOffset:0
  readonly property real visualClipTop:screenBorder ? borderThickness : 0
  readonly property real panelTop:screenBorder ? borderThickness : edgeConnected ? 4 : 0
 }
 FloatingWindow {visible:true;implicitWidth:484;implicitHeight:450;color:\"#448844\"
  Item { id:canvas;anchors.fill:parent;clip:true
SHAPES
  }
 }
 Timer {interval:220;repeat:true;running:true;onTriggered:{
  if(fixture.busy)return;
  if(fixture.phase===fixture.cases.length){console.log(\"GEOMETRY_RESULT: \"+JSON.stringify(fixture.samples));stop();return;}
  pillWindow.surfaceWidth=[194,360,420,194,194,194][fixture.phase];pillWindow.surfaceHeight=[42,420,360,42,42,42][fixture.phase];pillWindow.hideOffset=fixture.phase===3 ? -78 : 0;pillWindow.edgeConnected=fixture.phase!==4;pillWindow.screenBorder=fixture.phase===5;
  fixture.busy=true;settle.restart();
 }}
 Timer {id:settle;interval:180;onTriggered:{let nodes=[];for(let child of canvas.children)nodes.push({path:String(child).split(\"(\")[0],type:String(child).split(\"(\")[0],x:child.x,y:child.y,width:child.width,height:child.height,radius:child.radius===undefined ? 0 : child.radius,visible:child.visible});fixture.samples.push({name:fixture.cases[fixture.phase],controls:{pill:nodes}});canvas.grabToImage(result=>{if(!result.saveToFile(\"OUTPUT/\"+fixture.cases[fixture.phase]+\".png\"))console.error(\"GEOMETRY_FAIL: capture\");fixture.busy=false;fixture.phase++;});}}
}
""".replace('SHAPES',shape+body).replace('OUTPUT',str(args.output.resolve()))
  (folder/'shell.qml').write_text(qml)
  env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_SCALE_FACTOR=args.dpr,XDG_CONFIG_HOME=str(folder/'config'))
  proc=subprocess.Popen(['quickshell','-p',str(folder),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);lines=[];samples=None
  try:
   deadline=time.monotonic()+15
   while time.monotonic()<deadline:
    if select.select([proc.stdout],[],[],.2)[0]:
     line=proc.stdout.readline();lines.append(line)
     if 'GEOMETRY_RESULT: ' in line:samples=json.loads(line.split('GEOMETRY_RESULT: ',1)[1]);break
     if 'GEOMETRY_FAIL:' in line:break
    if proc.poll() is not None:break
  finally:
   proc.terminate();proc.wait(timeout=3)
  (args.output/'runtime.log').write_text(''.join(lines));assert samples is not None,'QML capture failed: '+''.join(lines)
  errors=[line for line in lines if re.search(r'ReferenceError|TypeError|Unable to assign|Binding loop|Cannot assign|GEOMETRY_FAIL',line)];assert not errors,'QML runtime errors: '+''.join(errors)
  violations=[]
  for sample in samples:
   for name,nodes in sample['controls'].items():
    for node in nodes:
     if node.get('radius',0)>min(node['width'],node['height'])/2+0.01:violations.append({'case':sample['name'],'path':node['path'],'radius':node['radius'],'width':node['width'],'height':node['height']})
     assert node['width']>=0 and node['height']>=0,('negative extent',node)
  result={'label':args.label,'source':str(args.source.resolve()),'dpr':args.dpr,'uiScale':args.ui_scale,'fontSize':args.font_size,'samples':samples,'radiusViolations':violations,'runtimeErrors':errors,'captures':[sample['name']+'.png' for sample in samples]}
  if args.baseline:
   baseline=json.loads(args.baseline.read_text());changes=[]
   for old,new in zip(baseline['samples'],samples):
    for name in old['controls']:
     before={n['path']:n for n in old['controls'][name]};after={n['path']:n for n in new['controls'][name]}
     for path in before.keys()&after.keys():
      for prop in ['x','y','width','height','radius','border']:
       if before[path].get(prop)!=after[path].get(prop):changes.append({'case':new['name'],'path':path,'property':prop,'baseline':before[path].get(prop),'final':after[path].get(prop)})
   rootChanges=[change for change in changes if '/' not in change['path'] and change['property'] in ['x','y','width','height']]
   result['baselineComparison']={'changes':changes,'rootDimensionChanges':rootChanges,'baselineRadiusViolationCount':len(baseline['radiusViolations'])}
   assert not [c for c in rootChanges if c['case']!='narrow-large-font'],'default control dimensions changed: '+json.dumps(rootChanges)
   assert not [c for c in changes if c['case']!='narrow-large-font' and c['property']!='radius'],'default child geometry changed: '+json.dumps(changes)
  (args.output/'geometry.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'label':args.label,'samples':len(samples),'radiusViolations':len(violations),'runtimeErrors':len(errors),'output':str(args.output)}))
  if args.label!='baseline':assert not violations,'radius exceeds drawable bounds: '+json.dumps(violations)
if __name__=='__main__':main()
