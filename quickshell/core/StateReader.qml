import QtQuick
import Quickshell
import Quickshell.Io

// One bounded reader per source: coalesce events, preserve the last accepted
// snapshot in the caller, and retry temporary failures without a tight loop.
Scope {
    id: reader
    property var command: []
    property var validate: value => value !== null && typeof value === "object" && !Array.isArray(value)
    property string label: "Desktop state"
    property string errorMessage: ""
    property int reconcileInterval: 10000
    property int retryDelay: 500
    property bool pending: false
    property bool timedOut: false
    property bool awaiting: false
    property int requestTimeout: 15000
    readonly property bool busy: awaiting || process.running
    signal accepted(var value)

    function request() {
        if (busy) pending = true;
        else if (!retry.running && !debounce.running) debounce.start();
    }
    function reject() {
        awaiting=false;
        timeout.stop();
        startCheck.stop();
        errorMessage=label + " unavailable; retaining last state and retrying.";
        pending=false;
        retry.interval=retryDelay;
        retry.restart();
        retryDelay=Math.min(30000, retryDelay*2);
    }
    Component.onCompleted: request()
    Timer { id: debounce; interval: 80; onTriggered: { reader.timedOut=false; reader.awaiting=true; timeout.restart(); startCheck.restart(); process.running=true; } }
    Timer { id: retry; interval: 500; onTriggered: reader.request() }
    Timer { interval: reader.reconcileInterval; running: interval > 0; repeat: true; onTriggered: reader.request() }
    Timer { id: startCheck; interval: 250; onTriggered: { if (reader.awaiting && !process.running) reader.reject(); } }
    Timer { id: timeout; interval: reader.requestTimeout; onTriggered: { reader.timedOut=true; if (process.running) process.signal(9); else reader.reject(); } }
    Process {
        id: process
        command: reader.command
        stdout: StdioCollector { id: output }
        onExited: (exitCode, exitStatus) => {
            reader.awaiting=false; timeout.stop(); startCheck.stop();
            try {
                if (reader.timedOut || exitCode !== 0 || exitStatus !== 0) throw new Error("Read failed");
                const value=JSON.parse(output.text);
                if (!reader.validate(value)) throw new Error("Invalid snapshot");
                reader.errorMessage="";
                reader.retryDelay=500;
                reader.accepted(value);
                if (reader.pending) { reader.pending=false; debounce.restart(); }
            } catch (e) {
                reader.reject();
            }
        }
    }
}
