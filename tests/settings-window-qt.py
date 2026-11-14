"""Exercise the actual Settings QML with isolated preferences and device stubs."""
from pathlib import Path
import json, os, re, select, shutil, subprocess, tempfile, time
src = Path(__file__).resolve().parents[1] / 'quickshell'
with tempfile.TemporaryDirectory(prefix='wizarch-settings-') as temporary:
    folder = Path(temporary)
    for directory in ('components', 'panels', 'core', 'services'):
        (folder / directory).mkdir()
    for name in ['SettingsWindow', 'SettingsSection', 'SettingsRow', 'SettingsSwitch', 'SettingsChoice', 'SettingsButton', 'SettingsSlider', 'SettingsThemeCard', 'Glyph', 'ThemedToolTip', 'ThemedScrollBar']:
        shutil.copy2(src / 'components' / (name + '.qml'), folder / 'components')
    for name in ['SettingsView', 'SettingsConnectivity']:
        shutil.copy2(src / 'panels' / (name + '.qml'), folder / 'panels')
    (folder / 'assets').symlink_to(src / 'assets', target_is_directory=True)
    import runpy
    runpy.run_path(str(Path(__file__).with_name('theme-fixture.py')))['write_theme'](folder,src,True)
    (folder / 'core/Workspaces.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { function forMonitor(name) { return {current:3}; } }\n')
    (folder / 'core/qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Geometry 1.0 Geometry.qml\nGeometryContext 1.0 GeometryContext.qml\nsingleton Workspaces 1.0 Workspaces.qml\n')
    (folder / 'services/wifi.py').write_text('import json\nprint(json.dumps({"ok":True,"networks":[]}))\n')
    (folder / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "components"
import "core" as Core
ShellRoot {
 id: fixture
 QtObject {
  id: state
  property bool settingsWindowOpen: true
  property string settingsPage: "settings"
  property var preferences: ({edgeConnected:true,autoHide:true,revealMode:"overlay",hideOnEmptyMonitor:false,screenBorder:true,borderThickness:8,matchWindowCorners:true,borderRadius:0,windowSpacing:35,dnd:false,notificationSounds:true,systemVolume:50,alertPattern:"triple",audioMode:"sound"})
  property string preferenceError: ""
  property bool preferenceWriterBusy: false
  property string spacingError: ""
  property string actionError: ""
  property var network: ({wifi:true,ethernet:false,wifiPresent:true,wifiBlocked:false,radioWritable:true,brightness:65,batterySaverAvailable:true,batterySaver:false,hotspotAvailable:true,hotspot:false,airplane:false})
  property var sink: ({description:"Fixture output",audio:{volume:0.5,muted:false}})
  property var mic: ({description:"Fixture input",audio:{volume:0.7,muted:false}})
  property bool audioOn: true
  property bool micOn: true
  property bool bluetoothOn: false
  property bool hasBattery: true
  property int batteryPercent: 73
  property var edits: []
  function setPreference(key,value) { let next=Object.assign({},preferences);next[key]=value;preferences=next;edits=edits.concat([{key:key,value:value}]); }
  function setCalendarSystems(primary,secondary) { if(primary===secondary)secondary="off";setPreference("calendarPrimary",primary);setPreference("calendarSecondary",secondary); }
  function setWindowSpacing(value) { setPreference("windowSpacing",Math.round(value)); }
  function runAction(action,value) { edits=edits.concat([{key:action,value:value}]); }
  function setBrightness(value) { setPreference("fixtureBrightness",value); }
  function cycleAudioMode() { setPreference("audioMode","quiet"); }
  function playAlert() { setPreference("fixtureAlert",true); }
  function retryPreferences() { preferenceError=""; }
 }
 SettingsWindow { id: window; root: state }
 function expect(ok,message) { if(!ok) throw new Error(message); }
 function find(item,predicate) {
  if(predicate(item)) return item;
  let children=item.children || [];
  for(let child of children) { let found=find(child,predicate);if(found)return found; }
  return null;
 }
 function labelled(text) { let result=find(window.contentItem,item=>item.label===text);expect(!!result,"missing "+text);return result; }
 function action(row) { return row.children[1].children[0]; }
 property int phase: 0
 Timer {
  interval: 100; running:true; repeat:true
  onTriggered: {
   try {
    if(phase===0) {
     expect(window.currentPage==="appearance","legacy Settings routing");state.settingsPage="themes";expect(window.currentPage==="appearance","Themes routing");
     expect(state.edits.length===0,"opening must not write preferences");
     window.setSearchQuery("CoRnEr");
    } else if(phase===1) {
     expect(window.filteredCategories.length===1 && window.currentPage==="panel","corner search: "+JSON.stringify(window.filteredCategories)+" page="+window.currentPage);window.setSearchQuery("spacing");
    } else if(phase===2) {
     expect(window.currentPage==="multitasking","spacing search");window.setSearchQuery("no-such-setting");
    } else if(phase===3) {
     expect(window.filteredCategories.length===0,"empty results");window.setSearchQuery("");
    } else if(phase===4) {
     expect(window.filteredCategories.length===12,"clear search");
     window.selectPage("panel");let before=state.settingsPage;window.selectPage("invalid");expect(state.settingsPage===before,"invalid page");
     labelled("Border thickness").edited(6);expect(state.preferences.borderThickness===6,"thickness save");
     let toggle=action(labelled("Match window corners"));toggle.checked=false;toggle.toggled();
     expect(state.preferences.matchWindowCorners===false && labelled("Inner corner radius").available,"manual corner enable");
     labelled("Inner corner radius").edited(0);expect(state.preferences.borderRadius===0,"zero radius");
     let choice=action(labelled("Reveal behaviour"));choice.activated(0);expect(state.preferences.revealMode==="push","reveal choice");
     toggle=action(labelled("Auto-hide panel"));toggle.checked=false;toggle.toggled();expect(state.preferences.autoHide===false && !choice.enabled,"auto-hide dependency");
     window.selectPage("multitasking");labelled("Window spacing").edited(42);expect(state.preferences.windowSpacing===42,"native spacing setter");
     window.selectPage("notifications");action(labelled("Alert pattern")).activated(1);expect(state.preferences.alertPattern==="double","alert pattern");
     window.selectPage("sound");expect(!find(window.contentItem,item=>item.label==="Output device"),"output device row removed");let sound=action(labelled("Sound"));sound.checked=false;sound.toggled();expect(state.sink.audio.muted,"sound mute retained");sound.checked=true;sound.toggled();expect(!state.sink.audio.muted,"sound unmute retained");labelled("Volume").edited(125);expect(state.sink.audio.volume===1.25,"playback volume");labelled("Input volume").edited(0);expect(state.mic.audio.volume===0,"input zero volume");
     window.selectPage("calendar");action(labelled("Primary calendar")).activated(1);expect(state.preferences.calendarPrimary==="solar","primary calendar");
     action(labelled("Secondary calendar")).activated(2);expect(state.preferences.calendarSecondary==="off","duplicate secondary off");
     action(labelled("Secondary calendar")).activated(1);expect(state.preferences.calendarSecondary==="gregorian","optional secondary");
     window.selectPage("appearance");let card=find(window.contentItem,item=>item.theme && item.activated);expect(!!card,"theme card");card.activated();expect(Core.Theme.lastApplied==="bundled:wizarch","theme activation");
     window.navigationCollapsed=true;state.preferenceError="Settings could not be saved. Your changes are queued.";
    } else if(phase===5) {
     expect(window.sidebarWidth===68,"compact sidebar");
     let retry=find(window.contentItem,item=>item.text==="Retry" && item.clicked);expect(!!retry,"retry button");retry.clicked();expect(state.preferenceError==="","retry route");
     window.navigationCollapsed=false;
    } else if(phase===6) {
     expect(window.sidebarWidth===240,"wide sidebar");window.navigationCollapsed=true;expect(window.sidebarWidth===68,"collapse");window.navigationCollapsed=false;
    } else if(phase>=7 && phase<19) { window.selectPage(window.categories[phase-7].id); }
    else if(phase===19) {
     expect(state.edits.length===13,"unexpected preference edits: "+state.edits.length);
     window.closeSettings();expect(!state.settingsWindowOpen && !window.visible,"close synchronization");
     state.settingsWindowOpen=true;expect(window.visible,"reopen");
     window.openSearch();
    } else if(phase===20) {
     window.closeSearch();
     let trigger=find(window.contentItem,item=>item.Accessible && item.Accessible.name==="Search settings");
     expect(!window.searchActive && trigger.activeFocus && trigger.visualFocus,"closing search restores trigger focus");
     window.uiGeometry.uiScale=1.5;window.openSearch();
    } else if(phase===21) {
     let view=find(window.contentItem,item=>item.page!==undefined && item.contentHeight!==undefined);
     expect(Math.abs(view.y-window.uiGeometry.dp(128))<.01,"search offset follows owning scale");
     expect(view.height>=0,"bounded page viewport");
     expect(window.minimumSize.width===720 && window.minimumSize.height===645,"minimum window follows control scale");window.closeSearch();
     console.log("SETTINGS_PASS: routing, search, preference handlers, audio, themes, compact/wide navigation, Retry, all pages, close/reopen, search focus restoration and scaled spacing");
    }
    phase++;
   } catch(error) { console.error("SETTINGS_FAIL: "+error);phase=100; }
  }
 }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_CONFIG_HOME=str(folder / 'config'))
    proc = subprocess.Popen(['qs', '-p', str(folder / 'shell.qml'), '--no-color'], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = []
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if select.select([proc.stdout], [], [], .2)[0]:
                line = proc.stdout.readline(); lines.append(line)
                if 'SETTINGS_PASS' in line or 'SETTINGS_FAIL' in line: break
            if proc.poll() is not None: break
        print(''.join(lines))
        assert any('SETTINGS_PASS:' in line for line in lines), 'Settings QML integration failed'
        assert not any(re.search(r'(ReferenceError|TypeError|Unable to assign|Binding loop)', line) for line in lines), 'QML runtime error'
    finally:
        proc.terminate(); proc.wait(timeout=3)
