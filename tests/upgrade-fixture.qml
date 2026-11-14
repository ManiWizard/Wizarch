pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "core" as Core
import "components"
ShellRoot {
 id: fixture
 property var pills: []
 Core.GeometryContext { id: scaleContext }
 QtObject {
  id: state
  property bool settingsWindowOpen: false
  property string settingsPage: "panel"
  property var preferences: FIXTURE_PREFERENCES
  property var sortedApps: DesktopEntries.applications.values.slice().sort((a,b) => a.name.localeCompare(b.name))
  property date clockDate: new Date(2026,9,21,12,0,0)
  property var occupiedMonitors: ({"UPGRADE-A":true,"UPGRADE-B":true})
  property real matchedFrameRadius: 14
  property bool hasBattery: true
  property int batteryPercent: 73
  property bool audioOn: true
  property bool micOn: true
  property bool bluetoothOn: false
  property var indicators: [true,true,false,true,false]
  property var sink: ({description:"Fixture output",audio:{volume:0.5,muted:false}})
  property var mic: ({description:"Fixture input",audio:{volume:0.7,muted:false}})
  property var player: ({isPlaying:true,trackTitle:"A quiet evening",trackArtist:"Fixture artist",identity:"Fixture player",trackArtUrl:"",length:240,position:95,lengthSupported:true,positionSupported:true,positionChanged:function(){},canSeek:true,canControl:true,canPause:true,canPlay:true,shuffleSupported:false,shuffle:false,canGoPrevious:true,canGoNext:true,canTogglePlaying:true,previous:function(){},next:function(){},togglePlaying:function(){},pause:function(){},play:function(){}})
  property var network: ({wifi:true,wifiPresent:true,radioWritable:true,wifiBlocked:false,wifiHardBlocked:false,brightness:65,batterySaverAvailable:false,recordingAvailable:false,hibernateSupported:false})
  property var notifications: [{summary:"Design baseline",appName:"Wizarch",body:"A deterministic notification",urgency:1,dismiss:function(){}}]
  property var trayWindows: []
  property bool actionBusy: false
  property string actionError: ""
  property string spacingError: ""
  property string preferenceError: ""
  property bool preferenceWriterBusy: false
  function setPreferences(values) { preferences=Object.assign({},preferences,values); }
  function setPreference(key,value) {const next={};next[key]=value;setPreferences(next);}
  function openSettings(page) { settingsPage=page || "panel";settingsWindowOpen=true; }
  function retryPreferences() {preferenceError="";}
  function clearNotifications() {notifications=[];}
  function cycleAudioMode() {}
  function setWindowSpacing(value) {}
  function setCalendarSystems(primary,secondary) {}
  function setBrightness(value) {}
  function playAlert() {}
  function defer(command) {}
  function runAction(action,value) {}
 }
 Binding {target:Core.Geometry;property:"uiScaleByOutput";value:state.preferences.uiScaleByOutput || ({})}
 QtObject {id:frames;property var monitors: ({"UPGRADE-A":true,"UPGRADE-B":true})}
 Variants {model:Quickshell.screens;Wallpaper {}}
 Variants {model:Quickshell.screens;ScrollingFrameGuard {root:state;state:frames}}
 Variants {
  model:Quickshell.screens
  Pill {
   root:state
   readonly property int keyboardMode: WlrLayershell.keyboardFocus
   Component.onCompleted: fixture.pills=fixture.pills.concat([this])
   Component.onDestruction: fixture.pills=fixture.pills.filter(p=>p!==this)
  }
 }
 SettingsWindow {id:settings;root:state}
 QuickWheel {id:wheel}
 function find(item,predicate) {if(predicate(item))return item;for(let child of item.children || []){const match=find(child,predicate);if(match)return match;}return null;}
 function focusName(item) {const focused=find(item,node=>node.activeFocus && node.Accessible && node.Accessible.name);return focused ? focused.Accessible.name : "";}
 IpcHandler {
  target:"upgrade-test"
  function show(section:string,output:string):void {
   state.settingsWindowOpen=false;wheel.cancel();
   for(let p of fixture.pills)p.dismiss();
   const p=fixture.pills.find(p=>p.modelData.name===output);
   if(section==="hidden")p.hideRequested=true;
   else if(section==="revealed")p.reveal();
   else if(section==="settings") {settings.screen=p.modelData;state.openSettings("panel");}
   else if(section==="wheel")wheel.openAt(output,960,540,"");
   else {p.section=section;const calendar=fixture.find(p.contentItem,item=>item.viewMode!==undefined);calendar.today=new Date(2026,9,21,12);calendar.page=new Date(2026,9,21,12);}
  }
  function closeSearch():void {settings.closeSearch();}
  function search():void {settings.openSearch();}
  function scale(value:real):void {state.preferences=Object.assign({},state.preferences,{uiScaleByOutput:{"UPGRADE-A":value}});}
  function statusViewport():string {
   const p=fixture.pills.find(p=>p.modelData.name==="UPGRADE-A");
   const quick=fixture.find(p.contentItem,item=>item.powerMenuOpen!==undefined);
   const viewport=fixture.find(quick,item=>item.objectName==="quickSettingsViewport");
   return JSON.stringify({natural:quick.naturalContentHeight===undefined ? quick.contentHeight : quick.naturalContentHeight,contentHeight:quick.contentHeight,viewport:viewport ? {height:viewport.height,contentHeight:viewport.contentHeight,contentY:viewport.contentY,interactive:viewport.interactive} : null});
  }
  function scrollStatus():void {
   const p=fixture.pills.find(p=>p.modelData.name==="UPGRADE-A");
   const viewport=fixture.find(p.contentItem,item=>item.objectName==="quickSettingsViewport");
   if(viewport)viewport.contentY=viewport.contentHeight-viewport.height;
  }
  function probe():string {
   return JSON.stringify({pills:fixture.pills.map(p=>({output:p.modelData.name,width:p.surfaceWidth,height:p.surfaceHeight,targetWidth:p.targetWidth,targetHeight:p.targetHeight,section:p.section,query:fixture.find(p.contentItem,item=>item.searchText!==undefined).searchText,keyboard:p.keyboardMode,hidden:p.hideProgress,focusName:fixture.focusName(p.contentItem)})),settings:{visible:settings.visible,width:settings.width,height:settings.height,search:settings.searchActive,focusName:fixture.focusName(settings.contentItem)},wheel:wheel.opened,wheelSelection:wheel.selectedIndex});
  }
 }
}
