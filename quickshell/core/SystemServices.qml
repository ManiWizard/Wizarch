import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications

Scope {
    id: root
    property var notifications: []
    function clearNotifications() {
        for (const notification of notifications.slice()) notification.dismiss();
    }
    NotificationServer {
        keepOnReload: true
        persistenceSupported: false
        bodySupported: true
        actionsSupported: false
        onNotification: notification => {
            notification.tracked = true;
            root.notifications = [notification].concat(root.notifications);
            notification.closed.connect(() => {
                root.notifications = root.notifications.filter(item => item !== notification);
            });
        }
    }
    readonly property date clockDate: clock.date
    readonly property bool actionBusy: systemAction.running
    function setBrightness(value) { pendingBrightness = value; brightnessDebounce.restart(); }
    function defer(command) { deferredAction.command = command; deferredAction.restart(); }
    readonly property bool hasBattery: UPower.displayDevice.isPresent
    readonly property int batteryPercent: Math.round(UPower.displayDevice.percentage * 100)
    readonly property var mic: Pipewire.defaultAudioSource
    readonly property bool micOn: mic && mic.audio && !mic.audio.muted
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    property string actionError: ""
    property real pendingBrightness: 50
    function acceptStatus(text) {
        try {
            const result = JSON.parse(text);
            if (result.ok) { network = result; actionError = ""; }
            else actionError = "Control unavailable. Please try again.";
        } catch (e) { actionError = "Could not read system state."; }
    }
    function runAction(action, value) {
        if (systemAction.running) return;
        systemAction.command = ["python3", Qt.resolvedUrl("../services/desktop-status.py").toString().replace("file://", ""), action, String(value)];
        systemAction.running = true;
    }
    Process {
        id: systemAction
        stdout: StdioCollector { onStreamFinished: root.acceptStatus(text) }
    }
    Timer {
        id: brightnessDebounce; interval: 150
        onTriggered: { if (systemAction.running) restart(); else root.runAction("brightness", root.pendingBrightness); }
    }
    Timer {
        id: deferredAction; property var command: []; interval: 700
        onTriggered: Quickshell.execDetached(command)
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioOn: sink && sink.audio && !sink.audio.muted
    readonly property bool bluetoothOn: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
    property var network: ({wifi: false, wifiPresent: false, brightness: -1})
    readonly property var sortedApps: DesktopEntries.applications.values.slice().sort((a,b) => a.name.localeCompare(b.name))
    readonly property var indicators: [hasBattery, network.wifi, bluetoothOn, audioOn, network.tunnel === true]
    PwObjectTracker { objects: [root.sink, root.mic].filter(n => n !== null) }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Process {
        id: networkPoll
        command: ["python3", Qt.resolvedUrl("../services/desktop-status.py").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector { onStreamFinished: root.acceptStatus(text) }
    }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: networkPoll.running = true }

}
