pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
import "../panels"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.Mpris

PanelWindow {
    id: pillWindow
    required property var modelData
    required property var root
    screen: modelData
    property string section: ""
    property string shownSection: ""
    property real surfaceWidth: 194
    property real surfaceHeight: 42
    property real contentAlpha: 0
    property real headerAlpha: 1
    property bool busy: opening.running || closing.running
    readonly property real targetHeight: section === "launcher" ? 320 : section === "status" || section === "notifications" ? 530 : section === "themes" ? 208 : calendar.monthView ? 402 : 208
    function dismiss() { if (section !== "") section = ""; }
    function activity() { if (expanded && section !== "launcher" && !busy) idleClose.restart(); }
    Timer { id: idleClose; interval: 30000; onTriggered: pillWindow.dismiss() }
    HyprlandFocusGrab {
        id: outsideGrab
        windows: [pillWindow]
        onCleared: pillWindow.dismiss()
    }
    readonly property bool expanded: section !== ""
    function launchCurrentApp() {
        const entry = launcher.selectedEntry;
        if (!entry) return;
        if (entry.runInTerminal) Quickshell.execDetached({command: ["kitty", "-e"].concat(entry.command), workingDirectory: entry.workingDirectory});
        else entry.execute();
        dismiss();
    }
    function toggle(name) { if (!busy) section = section === name ? "" : name; }
    anchors.top: true
    margins.top: 4
    // Fixed transparent surface: only the rounded body is rendered and accepts input.
    implicitWidth: 360
    implicitHeight: 560
    exclusiveZone: 28
    color: "transparent"
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: body; radius: body.radius }
    onSectionChanged: {
        idleClose.stop();
        if (section !== "") {
            closing.stop(); shownSection = section; launcher.searchText = "";
            if (section === "clock") calendar.reset();
            opening.restart();
        } else { outsideGrab.active = false; opening.stop(); calendarResize.stop(); closing.restart(); }
    }
    SequentialAnimation {
        id: opening
        onStopped: { if (pillWindow.expanded) Qt.callLater(pillWindow.activity); }
        NumberAnimation { target: pillWindow; property: "headerAlpha"; to: 0; duration: 90 }
        NumberAnimation { target: pillWindow; property: "surfaceWidth"; to: 360; duration: 190; easing.type: Easing.InOutCubic }
        NumberAnimation { target: pillWindow; property: "surfaceHeight"; to: pillWindow.targetHeight; duration: 250; easing.type: Easing.InOutCubic }
        NumberAnimation { target: pillWindow; property: "contentAlpha"; to: 1; duration: 120 }
        ScriptAction { script: { if (pillWindow.section === "launcher") launcher.focusSearch(); else body.forceActiveFocus(); outsideGrab.active = true; pillWindow.activity(); } }
    }
    SequentialAnimation {
        id: closing
        NumberAnimation { target: pillWindow; property: "contentAlpha"; to: 0; duration: 90 }
        NumberAnimation { target: pillWindow; property: "surfaceHeight"; to: 42; duration: 230; easing.type: Easing.InOutCubic }
        NumberAnimation { target: pillWindow; property: "surfaceWidth"; to: 194; duration: 190; easing.type: Easing.InOutCubic }
        ScriptAction { script: pillWindow.shownSection = "" }
        NumberAnimation { target: pillWindow; property: "headerAlpha"; to: 1; duration: 120 }
    }
    NumberAnimation { id: calendarResize; target: pillWindow; property: "surfaceHeight"; to: pillWindow.targetHeight; duration: 240; easing.type: Easing.InOutCubic }
    IpcHandler {
        target: "panel-" + pillWindow.modelData.name
        function togglePanel(section: string): void { if (["launcher", "clock", "status", "notifications", "themes"].indexOf(section) !== -1) pillWindow.toggle(section); }
        function calendarMonth(month: bool): void { calendar.monthView = month; calendarResize.restart(); }
        function show(section: string): void {
            if (["", "launcher", "clock", "status", "notifications", "themes"].indexOf(section) !== -1) pillWindow.section = section;
        }
    }
    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        width: pillWindow.surfaceWidth; height: pillWindow.surfaceHeight
        radius: 12
        antialiasing: true
        clip: true
        border.width: 1
        border.color: Qt.alpha(Core.Theme.surfaceContainerHighest, 0.22)
        color: Core.Theme.surface
        Keys.onPressed: event => { pillWindow.activity(); if (event.key === Qt.Key_Escape) { pillWindow.dismiss(); event.accepted = true; } }
        HoverHandler { onPointChanged: pillWindow.activity() }
        TapHandler { acceptedButtons: Qt.AllButtons; gesturePolicy: TapHandler.DragThreshold; onPressedChanged: pillWindow.activity() }
        WheelHandler { blocking: false; onWheel: pillWindow.activity() }
        Row {
            id: header
            opacity: Core.Workspaces.switching ? 0 : pillWindow.headerAlpha
            Behavior on opacity { NumberAnimation { duration: 110 } }
            visible: opacity > 0
            enabled: !pillWindow.busy && !pillWindow.expanded
            x: 4
            y: 4
            width: parent.width - 8
            height: 34
            Item {
                width: 35; height: 34
                Rectangle { anchors.fill: parent; anchors.leftMargin: 3; anchors.rightMargin: 3; radius: 7; color: launcherMouse.containsMouse || pillWindow.section === "launcher" ? Core.Theme.hoverSurface : "transparent"; Behavior on color { ColorAnimation { duration: 130 } } }
                Image { visible: Core.Workspaces.used.length < 2; anchors.centerIn: parent; width: 18; height: 18; source: Core.Theme.logo; sourceSize: Qt.size(36,36) }
                Text { visible: Core.Workspaces.used.length > 1; anchors.centerIn: parent; text: Core.Workspaces.current; color: Core.Theme.textPrimary; font.pixelSize: 14; font.weight: Font.Medium }
                MouseArea { id: launcherMouse; acceptedButtons: Qt.LeftButton | Qt.RightButton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mouse => pillWindow.toggle(mouse.button === Qt.RightButton ? "themes" : "launcher") }
            }
            FadedDivider { anchors.verticalCenter: parent.verticalCenter }
            Item {
                width: header.width - 72; height: 34
                Rectangle { anchors.fill: parent; anchors.leftMargin: 3; anchors.rightMargin: 3; radius: 7; color: clockMouse.containsMouse || pillWindow.section === "clock" ? Core.Theme.hoverSurface : "transparent"; Behavior on color { ColorAnimation { duration: 130 } } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; y: 2; text: Qt.formatDateTime(root.clockDate, "HH:mm"); color: Core.Theme.textPrimary; font.family: "Noto Sans"; font.pixelSize: 16; font.weight: Font.Normal }
                Text { anchors.horizontalCenter: parent.horizontalCenter; y: 22; text: Qt.formatDateTime(root.clockDate, "ddd · MMM d").toUpperCase(); color: Core.Theme.textSecondary; font.family: "Noto Sans"; font.pixelSize: 8; font.letterSpacing: 0.8 }
                MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pillWindow.toggle("clock") }
            }
            FadedDivider { anchors.verticalCenter: parent.verticalCenter }
            Item {
                width: 35; height: 34
                Rectangle { anchors.fill: parent; anchors.leftMargin: 3; anchors.rightMargin: 3; radius: 7; color: statusMouse.containsMouse || pillWindow.section === "status" ? Core.Theme.hoverSurface : "transparent"; Behavior on color { ColorAnimation { duration: 130 } } }
                Canvas {
                    id: emblem
                    anchors.centerIn: parent; width: 30; height: 30
                    antialiasing: true
                    onPaint: {
                        const c = getContext("2d"); c.reset();
                        c.lineCap = "round"; c.lineWidth = 1.8;
                        const gap = 0.23, span = Math.PI - 2 * gap;
                        const rightStart = -Math.PI / 2 + gap;
                        const leftStart = Math.PI / 2 + gap;
                        function arc(start, amount, color) {
                            if (amount <= 0) return;
                            c.strokeStyle = color; c.beginPath(); c.arc(15, 15, 11.2, start, start + span * amount); c.stroke();
                        }
                        arc(rightStart, 1, Core.Theme.surfaceContainerHighest);
                        arc(leftStart, 1, Core.Theme.surfaceContainerHighest);
                        if (root.hasBattery) {
                            const charge = Math.max(0, Math.min(100, root.batteryPercent));
                            // Right drains bottom-to-top (100–50%); left top-to-bottom (50–0%).
                            arc(rightStart, Math.max(0, (charge - 50) / 50), Core.Theme.textSecondary);
                            arc(leftStart, Math.min(1, charge / 50), Core.Theme.textSecondary);
                        }
                        c.lineWidth = 1.35;
                        c.strokeStyle = root.network.wifi ? Core.Theme.textPrimary : Core.Theme.textSecondary;
                        for (let r of [7, 4.1]) { c.beginPath(); c.arc(15, 19, r, -Math.PI * 0.75, -Math.PI * 0.25); c.stroke(); }
                        c.fillStyle = c.strokeStyle; c.beginPath(); c.arc(15, 19, 1, 0, Math.PI * 2); c.fill();

                    }
                    Connections { target: Core.Theme; function onPaletteChanged() { emblem.requestPaint(); } }
            Connections { target: pillWindow.root; function onBatteryPercentChanged() { emblem.requestPaint(); } function onIndicatorsChanged() { emblem.requestPaint(); } }
                }
                MouseArea { id: statusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pillWindow.toggle("status") }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: 7; spacing: 2
            opacity: Core.Workspaces.switching && !pillWindow.expanded ? 1 : 0
            visible: opacity > 0; enabled: visible
            Behavior on opacity { NumberAnimation { duration: 110 } }
            Repeater {
                model: 9
                Rectangle {
                    required property int index
                    width: 18; height: 28; radius: 6
                    color: Core.Workspaces.current === index+1 ? Core.Theme.primaryContainer : "transparent"
                    Text { anchors.centerIn: parent; text: parent.index+1; color: Core.Workspaces.current === parent.index+1 ? Core.Theme.textOnPrimaryContainer : Core.Workspaces.used.indexOf(parent.index+1)!==-1 ? Core.Theme.textPrimary : Core.Theme.textSecondary; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: Core.Workspaces.select(parent.index+1) }
                }
            }
        }
        Connections { target: Core.Workspaces; function onSwitchingChanged() { if (Core.Workspaces.switching && pillWindow.expanded) pillWindow.dismiss(); } }
        LauncherView {
            id: launcher; root: pillWindow.root; panel: pillWindow
            x: 18; y: 18; width: parent.width - 36; height: parent.height - 70
        }
        CalendarView {
            id: calendar; x: 18; y: 22; width: 324; height: 366
            today: root.clockDate
            visible: pillWindow.shownSection === "clock" && opacity > 0
            opacity: pillWindow.contentAlpha; enabled: !pillWindow.busy
            onModeChanged: { pillWindow.activity(); calendarResize.restart(); }
        }
        QuickSettings { root: pillWindow.root; panel: pillWindow; x: 18; y: 18; width: parent.width - 36; height: parent.height - 70 }
        NotificationCenter { root: pillWindow.root; panel: pillWindow; x: 18; y: 18; width: parent.width - 36; height: parent.height - 36 }
        ThemePicker { x: 18; y: 18; width: 324; height: 172; panel: pillWindow; visible: pillWindow.shownSection === "themes" && opacity > 0; opacity: pillWindow.contentAlpha; enabled: !pillWindow.busy }

    }
}
