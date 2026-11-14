import QtQuick
import "PreferenceQueue.js" as PreferenceQueue
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
    property bool settingsWindowOpen: false
    property string settingsPage: "settings"
    function openSettings(page) { settingsPage = page || "settings"; settingsWindowOpen = true; }
    property var preferences: ({uiScaleByOutput: {},audioMode: "sound", notificationSounds: true, systemVolume: 55, alertPattern: "single", dnd: false, pinnedApps: [], appGroups: [], launcherOrder: [], hiddenApps: [], edgeConnected: true, screenBorder: false, borderThickness: 3, borderRadius: 12, autoHide: false, hideOnEmptyMonitor: false, revealMode: "push", matchWindowCorners: true, windowSpacing: 75, calendarPrimary: "gregorian", calendarSecondary: "solar", calendarWeekStart: "auto", calendarEvents: []})
    Binding { target: Geometry; property: "uiScaleByOutput"; value: root.preferences.uiScaleByOutput || ({}) }
    property string spacingError: ""
    function setWindowSpacing(value) {
        setPreference("windowSpacing", Math.round(value));
        spacingDebounce.restart();
    }
    Timer {
        id: spacingDebounce; interval: 180
        onTriggered: {
            if (!root.preferencesLoaded || spacingApply.running) { restart(); return; }
            spacingApply.command = ["python3", Qt.resolvedUrl("../services/window-spacing.py").toString().replace("file://", ""), String(root.preferences.windowSpacing)];
            spacingApply.running = true;
        }
    }
    Process {
        id: spacingApply
        stdout: StdioCollector { onStreamFinished: {
            try { const result = JSON.parse(text); root.spacingError = result.ok ? "" : "Could not apply window spacing."; }
            catch (e) { root.spacingError = "Could not apply window spacing."; }
        } }
    }
    property real volumeBeforeAlert: -1
    property var preferenceQueue: PreferenceQueue.create()
    readonly property bool preferenceWriterBusy: preferenceWriter.running || preferenceLoad.running
    property string preferenceError: ""
    property bool preferencesLoaded: false
    function setPreference(key, value) {
        const changes = {}; changes[key] = value; setPreferences(changes);
    }
    function setPreferences(changes) {
        preferences = Object.assign({}, preferences, changes);
        PreferenceQueue.enqueue(preferenceQueue, changes);
        if (!preferenceError) preferenceDebounce.restart();
    }
    function setCalendarSystems(primary, secondary) {
        if (["gregorian", "solar"].indexOf(primary) < 0 || ["off", "gregorian", "solar"].indexOf(secondary) < 0) return;
        if (primary === secondary) secondary = "off";
        setPreferences({calendarPrimary: primary, calendarSecondary: secondary});
    }
    function retryPreferences() {
        if (!preferencesLoaded) { if (!preferenceLoad.running) preferenceLoad.running = true; return; }
        PreferenceQueue.retry(preferenceQueue);
        // Keep the error visible until all retained changes have saved.
        preferenceDebounce.restart();
    }
    function flushPreferences() {
        const batch = PreferenceQueue.take(preferenceQueue);
        if (!batch) return;
        preferenceWriter.command = ["python3", Qt.resolvedUrl("../services/preferences.py").toString().replace("file://", ""), "merge", JSON.stringify(batch)];
        preferenceWriter.running = true;
    }
    Timer { id: preferenceDebounce; interval: 180; onTriggered: root.flushPreferences() }
    Process {
        id: preferenceWriter
        stdout: StdioCollector { id: preferenceOutput }
        onExited: (exitCode, exitStatus) => {
            const success = exitCode === 0 && exitStatus === 0 && PreferenceQueue.validResponse(preferenceOutput.text, root.preferenceQueue.inFlight || {});
            PreferenceQueue.finish(root.preferenceQueue, success);
            if (!success) root.preferenceError = "Settings could not be saved";
            else if (Object.keys(root.preferenceQueue.pending).length === 0) root.preferenceError = "";
            if (success) preferenceDebounce.restart();
        }
    }
    function playAlert() {
        if (!preferences.notificationSounds || preferences.dnd || preferences.audioMode === "mute") return;
        Quickshell.execDetached(["python3", Qt.resolvedUrl("../services/alert.py").toString().replace("file://", ""), preferences.alertPattern, String(preferences.systemVolume)]);
    }
    function cycleAudioMode() {
        const modes = ["sound", "alert", "mute"];
        const next = modes[(modes.indexOf(preferences.audioMode) + 1) % modes.length];
        setPreference("audioMode", next);
        if (sink && sink.audio) {
            if (next === "alert") {
                volumeBeforeAlert = sink.audio.volume;
                sink.audio.volume = Math.min(0.22, Math.max(0.12, sink.audio.volume));
            } else if (next === "sound" && volumeBeforeAlert >= 0) {
                sink.audio.volume = volumeBeforeAlert;
                volumeBeforeAlert = -1;
            }
            sink.audio.muted = next === "mute";
        }
        if (next === "alert") playAlert();
    }
    property var notifications: []
    property var trayWindows: []
    property real matchedFrameRadius: 14
    readonly property string stateError: windowState.errorMessage || frameMetrics.errorMessage
    StateReader {
        id: frameMetrics
        label: "Window frame metrics"
        reconcileInterval: 30000
        command: ["python3", Qt.resolvedUrl("../services/frame-metrics.py").toString().replace("file://", "")]
        validate: value => value && Number.isFinite(value.radius) && value.radius >= 0
        onAccepted: value => root.matchedFrameRadius = value.radius
    }
    property var occupiedMonitors: ({})
    StateReader {
        id: windowState
        label: "Window state"
        command: ["python3", Qt.resolvedUrl("../services/window-state.py").toString().replace("file://", ""), "--snapshot"]
        validate: value => value && value.occupiedMonitors && typeof value.occupiedMonitors === "object" && !Array.isArray(value.occupiedMonitors) && Object.values(value.occupiedMonitors).every(v => typeof v === "boolean") && Array.isArray(value.trayWindows)
        onAccepted: value => { root.occupiedMonitors=value.occupiedMonitors; root.trayWindows=value.trayWindows; }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2", "workspacev2", "activespecial", "activespecialv2", "monitoraddedv2", "monitorremoved", "changefloatingmode", "fullscreen", "configreloaded"].indexOf(event.name) !== -1) windowState.request();
            if (["configreloaded", "monitoraddedv2", "monitorremoved"].indexOf(event.name) !== -1) frameMetrics.request();
        }
    }

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
            root.playAlert();
            notification.closed.connect(() => {
                root.notifications = root.notifications.filter(item => item !== notification);
            });
        }
    }
    readonly property date clockDate: clock.date
    readonly property bool actionBusy: systemAction.running
    function setBrightness(value) {
        if (!Number.isFinite(value)) return;
        pendingBrightness=Math.max(5,Math.min(100,Math.round(value)));
        brightnessPending=true;
        network=Object.assign({},network,{brightness:pendingBrightness});
        brightnessDebounce.restart();
    }
    function defer(command) { deferredAction.command = command; deferredAction.restart(); }
    readonly property bool hasBattery: UPower.displayDevice.isPresent
    readonly property int batteryPercent: Math.round(UPower.displayDevice.percentage * 100)
    readonly property var mic: Pipewire.defaultAudioSource
    readonly property bool micOn: mic && mic.audio && !mic.audio.muted
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    property string scrollingError: ""
    property string controlError: ""
    readonly property string actionError: controlError || networkPoll.errorMessage || stateError || scrollingError
    property real pendingBrightness: 50
    property real confirmedBrightness: -1
    property bool brightnessPending: false
    property int controlGeneration: 0
    function acceptStatus(text) {
        try {
            const result = JSON.parse(text);
            if (result && result.ok === true && typeof result.wifi === "boolean" && Number.isFinite(result.brightness)) {
                confirmedBrightness=result.brightness;
                network=brightnessPending ? Object.assign({},result,{brightness:pendingBrightness}) : result;
                controlError="";
                return true;
            }
            controlError="Control unavailable. Please try again.";
        } catch (e) { controlError = "Could not read system state."; }
        return false;
    }
    function runAction(action, value) {
        if (systemAction.running) return;
        controlGeneration++;
        systemAction.action=action;
        systemAction.requestedValue=action === "brightness" ? Number(value) : 0;
        systemAction.command = ["python3", Qt.resolvedUrl("../services/desktop-status.py").toString().replace("file://", ""), action, String(value)];
        systemAction.running = true;
    }
    Process {
        id: systemAction
        property string action: ""
        property real requestedValue: 0
        stdout: StdioCollector { id: actionResult }
        onExited: (exitCode, exitStatus) => {
            if (action === "brightness" && requestedValue === root.pendingBrightness) root.brightnessPending=false;
            const success=exitCode === 0 && exitStatus === 0 && root.acceptStatus(actionResult.text);
            if (!success) {
                if (exitCode !== 0 || exitStatus !== 0) root.controlError="Control unavailable. Please try again.";
                if (!root.brightnessPending && root.confirmedBrightness >= 0) root.network=Object.assign({},root.network,{brightness:root.confirmedBrightness});
            }
            root.controlGeneration++;
            networkPoll.request();
        }
    }
    Timer {
        id: brightnessDebounce; interval: 150
        onTriggered: { if (!root.brightnessPending) return; if (systemAction.running) restart(); else root.runAction("brightness", root.pendingBrightness); }
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
    Process {
        id: preferenceLoad
        command: ["python3", Qt.resolvedUrl("../services/preferences.py").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector { id: loadedPreferences }
        onExited: (exitCode, exitStatus) => {
            try {
                const saved = JSON.parse(loadedPreferences.text);
                if (exitCode !== 0 || exitStatus !== 0 || !saved || typeof saved !== "object" || Array.isArray(saved)) throw new Error("Invalid preferences");
                root.preferences = PreferenceQueue.load(root.preferenceQueue, saved);
                root.preferencesLoaded = true;
                PreferenceQueue.retry(root.preferenceQueue);
                if (Object.keys(root.preferenceQueue.pending).length === 0) root.preferenceError = "";
                preferenceDebounce.restart(); spacingDebounce.restart();
            } catch (e) { root.preferenceError = "Settings could not be loaded"; }
        }
    }
    readonly property var indicators: [hasBattery, network.wifi, bluetoothOn, audioOn, network.tunnel === true]
    PwObjectTracker { objects: [root.sink, root.mic].filter(n => n !== null) }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    StateReader {
        id: networkPoll
        property int startedGeneration: 0
        onBusyChanged: if (busy) startedGeneration=root.controlGeneration
        label: "System controls"
        reconcileInterval: 15000
        command: ["python3", Qt.resolvedUrl("../services/desktop-status.py").toString().replace("file://", "")]
        validate: value => value && value.ok === true && typeof value.wifi === "boolean" && Number.isFinite(value.brightness)
        onAccepted: value => {
            if (startedGeneration === root.controlGeneration && !root.brightnessPending && !systemAction.running) {
                root.confirmedBrightness=value.brightness;
                root.network=value;
            }
        }
    }
}
