"""Validate real Quick Settings QML with isolated state and mocked power commands."""
from pathlib import Path
import os,re,runpy,select,shutil,subprocess,sys,tempfile,time
src=Path(__file__).resolve().parents[1]/'quickshell'
out=Path('/home/Mw/ChatGPT/Wizarch Shell/audit/quick-settings-20261009');out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='wizarch-quick-settings-') as temp:
 folder=Path(temp)
 for d in ['components','core','panels']:(folder/d).mkdir()
 for name in ['ControlTile','QuickActionCard','QuickSliderRow','Glyph','ThemedToolTip','ThemedScrollBar','MediaCard']:shutil.copy2(src/'components'/f'{name}.qml',folder/'components')
 shutil.copy2(src/'core/MediaMetadata.js',folder/'core/MediaMetadata.js')
 shutil.copy2(src/'core/MediaMetadata.js',folder/'core')
 shutil.copytree(src/'assets',folder/'assets')
 for name in ['QuickSettings','NotificationCenter']:shutil.copy2(src/'panels'/f'{name}.qml',folder/'panels')
 runpy.run_path(str(src.parent/'tests/theme-fixture.py'))['write_theme'](folder,src)
 p=folder/'core/Theme.qml';s=p.read_text();s=s.replace(' property var draftPack:', ' property var selectedPack: ({modes:["light","dark"],valid:true})\n function setMode(value) {mode=value;}\n property var draftPack:');p.write_text(s)
 (folder/'core/qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Geometry 1.0 Geometry.qml\nGeometryContext 1.0 GeometryContext.qml\n')
 qml='''pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "panels"
import "core" as Core
ShellRoot {
 id:fixture
 QtObject {
  id:state
  property var preferences: ({audioMode:"sound",dnd:false})
  property var network: ({wifi:true,wifiPresent:true,radioWritable:true,wifiBlocked:false,wifiHardBlocked:false,brightness:75,hibernateSupported:false,recordingAvailable:false,batterySaverAvailable:false})
  property bool actionBusy:false
  property bool bluetoothOn:false
  property bool audioOn:true
  property bool micOn:true
  property QtObject audio: QtObject {property real volume:0.5;property bool muted:false}
  property var sink: ({audio:audio})
  property var mic: ({audio:{muted:false}})
  property var player:null
  property var trayWindows:[]
  property var notifications:[]
  property string actionError:""
  property var commands:[]
  property int settingsOpened:0
  function defer(command){commands=commands.concat([command]);}
  function cycleAudioMode(){let modes=["sound","alert","mute"];preferences=Object.assign({},preferences,{audioMode:modes[(modes.indexOf(preferences.audioMode)+1)%3]});}
  function setBrightness(value){network=Object.assign({},network,{brightness:value});}
  function openSettings(){settingsOpened++;}
  function setPreference(key,value){let next={};next[key]=value;preferences=Object.assign({},preferences,next);}
  function runAction(action,value){}
  function clearNotifications(){notifications=[];}
 }
 QtObject { id:panel;property string shownSection:"status";property real contentAlpha:1;property bool busy:false;function dismiss(){shownSection="";}function toggle(name){shownSection=name;} }
 FloatingWindow {
  visible:true;implicitWidth:360;implicitHeight:quick.contentHeight;color:Core.Theme.surfaceContainerLow
  title:"Quick Settings validation fixture"
  TestCase {id: input; name:"QuickSettingsInput"; when:false}
  minimumSize: Qt.size(360, 0); maximumSize: Qt.size(360, 600)
  QuickSettings {id:quick;root:state;panel:panel;x:18;y:18;width:324;height:contentHeight-36}
  NotificationCenter {id:center;root:state;panel:panel;x:18;y:18;width:324;height:contentHeight-36}
 }
 function expect(ok,label){if(!ok)throw new Error(label);}
 function find(item,predicate){if(predicate(item))return item;for(let child of item.children || []){let result=find(child,predicate);if(result)return result;}return null;}
 function named(name){return find(quick,item=>item.objectName===name);}
 property int phase:0
 property bool captureBusy:false
 property real originalHeight:0
 property int settle:0
 property real keyboardTime:0
 property bool inputBusy:false
 function capture(name){captureBusy=true;quick.grabToImage(result=>{expect(result.saveToFile("OUTPUT/"+name+".png"),"capture");captureBusy=false;phase++;});}
 Timer {interval:180;running:true;repeat:true;onTriggered:{
  if(fixture.captureBusy || fixture.inputBusy)return;
  if(fixture.phase===5 && fixture.settle++<2)return;
  try {
   let v=fixture.named("volumeRow"),b=fixture.named("brightnessRow"),powers=fixture.named("powerActions");
   if(fixture.phase===0){fixture.originalHeight=quick.contentHeight;fixture.expect(v.height===44 && b.height===44,"row heights");let card=fixture.named("sliderCard");fixture.expect(card.width===324 && card.height===120,"shared card sizing");fixture.expect(v.parent===b.parent && v.parent.parent===card,"both rows grouped");fixture.expect(v.parent.x===12 && v.parent.y===12 && v.width===300,"card padding");fixture.expect(b.y+b.height<=card.height-24,"rows fit with bottom padding");fixture.expect(String(card.color)!==String(v.controlSurface),"card and control surfaces distinct");for(let row of [v,b]){let button=fixture.find(row,item=>item.objectName==="sliderAction");fixture.expect(button.width===row.height && button.height===row.height,"action square matches slider height");}for(let row of [v,b]) {
 let action=fixture.find(row,item=>item.objectName==="sliderAction");
 let surface=fixture.find(row,item=>item.objectName==="sliderSurface");
 fixture.expect(action.radius<action.height*.4 && Math.abs(action.radius-surface.radius)<.001,"slider and action share visibly noncircular corners");
}
for(let name of ["Settings","Notifications","Power options"]) {
 let header=fixture.find(quick,item=>item.Accessible && item.Accessible.name===name);
 fixture.expect(!!header && header.radius<header.height*.4,"header action visibly noncircular: "+name);
}
fixture.capture("quick-settings");}
   else if(fixture.phase===1){v.edited(81);fixture.expect(state.sink.audio.volume===0.81,"volume write");b.edited(63);fixture.expect(state.network.brightness===63,"brightness write");v.actionTriggered();fixture.expect(state.preferences.audioMode==="alert","alert mode");v.actionTriggered();fixture.expect(state.preferences.audioMode==="mute","muted mode");v.actionTriggered();fixture.expect(state.preferences.audioMode==="sound","sound mode");b.actionTriggered();fixture.expect(Core.Theme.mode==="light","theme infrastructure call");fixture.named("powerButton").activate();fixture.phase++;}
   else if(fixture.phase===2){fixture.expect(quick.contentHeight<fixture.originalHeight && powers.visible,"power replaces controls and height updates");fixture.expect(quick.activeFocus && !fixture.named("powerButton").activeFocus,"power view owns keyboard focus");fixture.expect(!fixture.named("powerButton").visible && !fixture.named("powerButton").enabled && !fixture.named("powerButton").activeFocusOnTab,"power trigger hidden and non-interactive");fixture.expect(!fixture.named("quickSettingsHeader").visible && powers.y===0 && quick.contentHeight===100,"power view has no header gap");fixture.expect(!fixture.find(quick,item=>item.text==="Power"),"no power heading");fixture.expect(!fixture.find(quick,item=>item.Accessible && item.Accessible.name==="Back to quick settings"),"no power Back control");fixture.expect(fixture.named("powerButton").Accessible.name==="Power options","existing power toggle retained");let cards=powers.children.filter(item=>item.label!==undefined);fixture.expect(cards.length===5,"five power actions");fixture.expect(cards.filter(item=>item.destructive).length===1 && cards[0].destructive,"shutdown only destructive");for(let card of cards){fixture.expect(card.width===card.height,"square card");}let h=cards[4];fixture.expect(!h.available && !h.enabled && !h.activeFocusOnTab,"hibernate unavailable and skipped by keyboard");h.activate();fixture.expect(state.commands.length===0,"disabled action refused");fixture.capture("power");}
   else if(fixture.phase===3){let cards=powers.children.filter(item=>item.label!==undefined);for(let card of cards.slice(0,4)){quick.showPower(true);card.activate();}fixture.expect(JSON.stringify(state.commands)==='[["systemctl","poweroff"],["hyprctl","dispatch","hl.dsp.exit()"],["systemctl","reboot"],["systemctl","suspend"]]',"mock power dispatch");state.network=Object.assign({},state.network,{hibernateSupported:true});panel.shownSection="status";quick.showPower(true);cards[4].activate();fixture.expect(state.commands[4][1]==="hibernate","mock hibernate dispatch");panel.shownSection="status";quick.showPower(true);fixture.inputBusy=true;input.keyClick(Qt.Key_Tab);fixture.expect(cards.some(card=>card.activeFocus),"Tab enters visible power cards");input.keyClick(Qt.Key_Escape);fixture.inputBusy=false;fixture.expect(!quick.powerMenuOpen && fixture.named("powerButton").visible && fixture.named("powerButton").activeFocus,"Escape returns and restores trigger focus");let settings=fixture.find(quick,item=>item.Accessible && item.Accessible.name==="Settings");fixture.expect(!!settings,"main Settings retained");settings.activate();fixture.expect(state.settingsOpened===1,"main Settings opens existing destination");panel.shownSection="status";quick.width=264;fixture.phase++;}
   else if(fixture.phase===4){fixture.expect(v.width===240,"narrow row responds");fixture.capture("narrow");}
   else if(fixture.phase===5){quick.showPower(true);fixture.expect(quick.contentHeight===88,"narrow power height");fixture.capture("power-narrow");}
   else if(fixture.phase===6){panel.shownSection="notifications";fixture.expect(!quick.powerMenuOpen,"power reset on section leave");fixture.expect(!fixture.find(center,item=>item.Accessible && item.Accessible.name==="Settings"),"notification settings removed");fixture.expect(!!fixture.find(center,item=>item.Accessible && item.Accessible.name==="Back to quick settings"),"notification back");state.sink=null;state.network=Object.assign({},state.network,{brightness:-1});panel.shownSection="status";quick.showPower(false);fixture.phase++;}
   else if(fixture.phase===7){fixture.expect(!v.available && !b.available,"unavailable sliders");fixture.expect(!fixture.find(v,item=>item.objectName==="levelSlider").enabled,"unavailable audio disabled");Core.Theme.applying=true;fixture.expect(!b.actionAvailable,"theme busy disabled");fixture.capture("unavailable");}
   else if(fixture.phase===8){
    fixture.inputBusy=true;
    state.audio.volume=0.5;state.sink={audio:state.audio};state.network=Object.assign({},state.network,{brightness:75});Core.Theme.applying=false;
    let slider=fixture.find(v,item=>item.objectName==="levelSlider");input.mouseMove(slider,slider.width/2,slider.height/2);fixture.expect(v.valueVisible,"hover reveals value");
    input.mouseMove(quick,quick.width+10,quick.height+10);fixture.expect(!v.valueVisible,"leave hides value");
    input.mouseClick(slider,slider.width*.8,2);fixture.expect(Math.abs(state.sink.audio.volume-1.2)<.03,"top of full capsule clicks");
    input.mousePress(slider,slider.width*.2,slider.height-2);input.mouseMove(slider,slider.width*.65,slider.height-2,20,Qt.LeftButton);fixture.expect(slider.pressed && v.valueVisible,"drag reveals value");input.mouseRelease(slider,slider.width*.65,slider.height-2);fixture.expect(Math.abs(state.sink.audio.volume-.98)<.03,"full capsule drag writes");
    input.mouseMove(quick,quick.width+10,quick.height+10);slider.forceActiveFocus();let before=slider.value;input.keyClick(Qt.Key_Right);fixture.expect(slider.value>before && v.valueVisible,"keyboard changes and reveals");input.mouseMove(fixture.named("powerButton"),15,15);fixture.keyboardTime=Date.now();fixture.inputBusy=false;fixture.phase++;
   }
   else if(fixture.phase===9){fixture.capture("capsule-adjusting");}
   else if(fixture.phase===10){if(Date.now()-fixture.keyboardTime<1600)return;fixture.inputBusy=true;input.mouseMove(fixture.named("powerButton"),15,15);fixture.inputBusy=false;fixture.find(v,item=>item.objectName==="levelSlider").hoverEnabled=false;fixture.expect(!v.valueVisible,"keyboard reveal expires after adjustment without hover");fixture.expect(b.actionIcon==="night" && v.icon==="music" && b.icon==="brightness","fixed glyphs");let action=fixture.find(b,item=>item.objectName==="sliderAction");let light=String(action.color);Core.Theme.mode="dark";fixture.expect(b.actionActive && String(action.color)!==light,"theme state changes background");fixture.phase++;}
   else if(fixture.phase===11){Core.Geometry.uiScale=1.25;Core.Geometry.fontSize=20;quick.width=264;quick.showPower(true);fixture.phase++;}
   else if(fixture.phase===12){fixture.expect(powers.columns<5 && powers.columns>=1,"large text power grid reflows");fixture.expect(powers.cellSize>=powers.minimumCell,"power cards retain calibrated usable minimum");fixture.expect(v.height===Core.Geometry.metric("quickSliderHeight"),"scaled slider height");let cards=powers.children.filter(item=>item.label!==undefined);for(let card of cards)fixture.expect(card.width===card.height && card.width===powers.cellSize,"reflow preserves square cards");fixture.expect(powers.height>powers.cellSize,"power grid uses additional row");Core.Geometry.uiScale=1;Core.Geometry.fontSize=13;fixture.phase++;}
   else if(fixture.phase===13){console.log("QUICK_SETTINGS_PASS: real QML, responsive square cards, matching slider/action heights, mock power dispatch, three sound modes, theme toggle, slider writes, disabled capabilities, content heights, notification back, large-text scaled power reflow");fixture.phase++;}
  }catch(error){console.error("QUICK_SETTINGS_FAIL: "+error);fixture.phase=100;}
 }}
}
'''.replace('OUTPUT',str(out))
 (folder/'shell.qml').write_text(qml)
 proc=subprocess.Popen(['quickshell','-p',str(folder),'--no-color'],env=dict(os.environ,QT_QPA_PLATFORM='wayland' if '--wayland' in sys.argv else 'offscreen',XDG_CONFIG_HOME=str(folder/'config')),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 lines=[]
 try:
  deadline=time.monotonic()+15
  while time.monotonic()<deadline:
   if select.select([proc.stdout],[],[],0.2)[0]:
    line=proc.stdout.readline();lines.append(line)
    if 'QUICK_SETTINGS_PASS:' in line or 'QUICK_SETTINGS_FAIL:' in line:break
   if proc.poll() is not None:break
  print(''.join(lines))
  assert any('QUICK_SETTINGS_PASS:' in line for line in lines),'QML integration failed'
  assert not any(re.search(r'(ReferenceError|TypeError|Unable to assign|Binding loop|Cannot assign)',line) for line in lines),'QML runtime error'
 finally:proc.terminate();proc.wait(timeout=3)
