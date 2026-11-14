pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
Scope {
 id: service
 property var monitors: ({})
 property var switchingUntil: ({})
 property string responseError: ""
 readonly property string errorMessage: responseError || refresh.errorMessage
 readonly property string script: Qt.resolvedUrl("../services/workspaces.py").toString().replace("file://", "")
 function forMonitor(name) { return monitors[name] || { current: 1, used: [1], revision: 0, desktop: false }; }
 function isSwitching(name) { return switchingUntil[name] !== undefined; }
 function validSnapshot(value) {
  if (!value || value.error || !value.monitors || typeof value.monitors !== "object" || Array.isArray(value.monitors)) return false;
  return Object.values(value.monitors).every(m => m && Number.isInteger(m.current) && m.current>=1 && m.current<=9
   && Array.isArray(m.used) && m.used.every(n => Number.isInteger(n) && n>=1 && n<=9)
   && Number.isFinite(m.revision) && typeof m.desktop === "boolean");
 }
 function accept(text) {
  try {
   const result=JSON.parse(text);
   if (result.error) { responseError=result.error; return; }
   if (!validSnapshot(result)) { responseError="Could not read monitor workspaces"; return; }
   const flashes=Object.assign({},switchingUntil);
   const now=Date.now();
   for (const name in result.monitors) {
    if (monitors[name] && monitors[name].revision!==result.monitors[name].revision) flashes[name]=now+1000;
   }
   for (const name in flashes) if (!result.monitors[name]) delete flashes[name];
   responseError=""; switchingUntil=flashes; monitors=result.monitors;
   if (Object.keys(flashes).length) flash.restart();
  } catch(e) { responseError="Could not read workspaces"; }
 }
 function select(number,monitor) { if (!selectProcess.running) { selectProcess.command=["python3",script,"switch",String(number),"--monitor",monitor]; selectProcess.running=true; } }
 Process {
  id: selectProcess
  stdout: StdioCollector { id: selectionResult }
  onExited: (exitCode, exitStatus) => {
   if (exitCode!==0 || exitStatus!==0) { service.responseError="Could not switch workspace"; refresh.request(); }
   else service.accept(selectionResult.text);
  }
 }
 StateReader {
  id: refresh; label: "Workspaces"; command: ["python3",service.script,"sync"]
  validate: value => service.validSnapshot(value)
  onAccepted: value => service.accept(JSON.stringify(value))
 }
 Timer {
  id: flash; interval: 100; repeat: true
  onTriggered: {
   const remaining={}; const now=Date.now();
   for (const name in service.switchingUntil) if (service.switchingUntil[name]>now) remaining[name]=service.switchingUntil[name];
   service.switchingUntil=remaining;
   if (!Object.keys(remaining).length) stop();
  }
 }
 Connections {
  target: Hyprland
  function onRawEvent(event) { if (["workspacev2","focusedmonv2","monitoraddedv2","monitorremoved","movewindowv2","openwindow","closewindow","configreloaded"].indexOf(event.name)!==-1) refresh.request(); }
 }
}
