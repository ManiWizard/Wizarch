pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
Scope {
 id: service
 property int current: 1
 property var used: [1]
 property int revision: -1
 property bool switching: false
 property string errorMessage: ""
 readonly property string script: Qt.resolvedUrl("../services/workspaces.py").toString().replace("file://", "")
 function accept(text) {
  try {
   const result=JSON.parse(text);
   if (result.error) { errorMessage=result.error; return; }
   errorMessage=""; current=result.current; used=result.used;
   if (revision>=0 && revision!==result.revision) { switching=true; flash.restart(); }
   revision=result.revision;
  } catch(e) { errorMessage="Could not read workspaces"; }
 }
 function select(number) { if (!selectProcess.running) { selectProcess.command=["python3",script,"switch",String(number)]; selectProcess.running=true; } }
 Process { id: selectProcess; stdout: StdioCollector { onStreamFinished: service.accept(text) } }
 Process { id: refresh; command: ["python3",service.script,"sync"]; running: true; stdout: StdioCollector { onStreamFinished: service.accept(text) } }
 Timer { id: debounce; interval: 100; onTriggered: { if (refresh.running) restart(); else refresh.running=true; } }
 Timer { id: flash; interval: 1000; onTriggered: service.switching=false }
 Connections {
  target: Hyprland
  function onRawEvent(event) { if (["workspacev2","focusedmonv2","monitoraddedv2","monitorremoved","movewindowv2","openwindow","closewindow"].indexOf(event.name)!==-1) debounce.restart(); }
 }
}
