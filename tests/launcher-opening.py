"""Focused Qt test: opening width morph cannot rearrange tiles; staggered fades restart."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='wizarch-launcher-opening-') as directory:
    folder = Path(directory)
    qml = '''pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "PANELS" as Panels
import "CORE" as Core
ShellRoot {
    id: test
    property int phase: 0
    property int samples: 0
    property bool stagger: false
    property var geometry: []
    QtObject {
        id: data
        property var preferences: ({pinnedApps:["a","b","c","d","e"],appGroups:[{name:"Large",type:"large",apps:["a"]}],launcherOrder:[],hiddenApps:[]})
        property string preferenceError: ""
        property var sortedApps: ["a","b","c","d","e"].map(id=>({id:id,name:id,icon:"",command:["never-executed"],noDisplay:false}))
        function setPreferences(value) {}
        function setPreference(key,value) {}
    }
    QtObject {
        id: panel
        property string shownSection: "launcher"
        property real contentAlpha: 0
        property bool busy: false
        property real targetWidth: 420
        function dismiss() {}
    }
    FloatingWindow {
        visible: true; implicitWidth: 420; implicitHeight: 600
        Item {
            id: viewport; width: 194; height: 600
            Panels.LauncherView { id: launcher; root: data; panel: panel; x: 18; y: 18; width: viewport.width-36; height: 564 }
        }
    }
    NumberAnimation { id: morph; target: viewport; property: "width"; from: 194; to: 420; duration: 250 }
    Timer {
        id: sampler; interval: 16; repeat: true; running: true
        onTriggered: {
            if (!test.phase) {
                if (launcher.homeEntries.length !== 6 || !launcher.homeTileAt(5)) return;
                launcher.reset(); panel.contentAlpha=1; morph.start(); test.phase=1; return;
            }
            if (test.phase===2) { launcher.reset(); panel.contentAlpha=1; morph.start(); test.phase=3; test.samples=0; return; }
            test.samples++;
            function checkCorners(item) {
                if (typeof item.radius === "number") {
                    if (!isFinite(item.radius) || item.radius < 0 || item.radius > Math.min(Math.max(0,item.width),Math.max(0,item.height))/2 + .0001)
                        throw new Error("invalid rendered radius " + item + ": " + item.radius + " in " + item.width + "x" + item.height);
                }
                if (item.visible && typeof item.radius === "number" && item.radius > 0 && Math.abs(item.radius-Core.Geometry.radius("control",item.width,item.height)) > .001)
                    throw new Error("visible launcher surface bypasses the shared new profile: " + item);
                for (const child of item.children || []) checkCorners(child);
            }
            checkCorners(launcher);
            const tiles=launcher.homeEntries.map((entry,index)=>launcher.homeTileAt(index));
            const geometry=tiles.map(tile=>({x:tile.x,y:tile.y,w:tile.width,h:tile.height}));
            function fail(message) { console.log("FAIL: "+message); Qt.quit(); }
            if (!test.geometry.length) test.geometry=geometry;
            if (JSON.stringify(geometry)!==JSON.stringify(test.geometry)) { fail("tiles moved during width morph"); return; }
            if (launcher.gridColumns!==4) { fail("opening grid changed column count"); return; }
            if (launcher.openingProgress>0 && launcher.openingProgress<.7) {
                const upper=tiles.find(tile=>tile.y===0), lower=tiles.find(tile=>tile.y>0);
                if (upper.opacity>lower.opacity) test.stagger=true;
            }
            if (test.samples<30) return;
            if (!test.stagger || tiles.some(tile=>Math.abs(tile.opacity-1)>.001)) { fail("fade did not stagger and finish: "+JSON.stringify({progress:launcher.openingProgress,stagger:test.stagger,tiles:tiles.map(tile=>({y:tile.y,opacity:tile.opacity})),visible:launcher.visible})); return; }
            if (test.phase===1) { panel.contentAlpha=0; viewport.width=194; test.phase=2; return; }
            console.log("PASS: stable mixed tile bounds through opening and reopening; individual row fades finish without motion"); Qt.quit();
        }
    }
}'''.replace('PANELS', (ROOT/'quickshell/panels').as_uri()).replace('CORE', (ROOT/'quickshell/core').as_uri())
    (folder/'shell.qml').write_text(qml)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_CONFIG_HOME=str(folder/'config'), XDG_STATE_HOME=str(folder/'state'))
    result = subprocess.run(['quickshell','-p',str(folder/'shell.qml'),'--no-color'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=12)
    forbidden = ['ReferenceError','TypeError','Unable to assign','Binding loop','Failed to load','FAIL:']
    assert result.returncode == 0 and 'PASS:' in result.stdout and not any(message in result.stdout for message in forbidden), result.stdout
    print(next(line for line in result.stdout.splitlines() if 'PASS:' in line))
