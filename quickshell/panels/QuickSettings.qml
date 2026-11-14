pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../core" as Core
import "../components"
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: statusContent
    required property var root
    required property var panel
    property bool powerMenuOpen: false
    property real availableHeight: 1000000
    readonly property real contentHeight: Math.min(Math.max(0, availableHeight), naturalContentHeight)
    readonly property real naturalContentHeight: 2 * uiGeometry.metric("panelInset") + (powerMenuOpen ? powerActions.height : uiGeometry.metric("quickHeader") + uiGeometry.metric("contentGap") + mainControls.implicitHeight) + (actionError.visible ? actionError.implicitHeight + uiGeometry.metric("contentGap") : 0)
    visible: panel.shownSection === "status" && opacity > 0
    opacity: panel.contentAlpha
    enabled: !panel.busy
    onVisibleChanged: if (!visible) { powerMenuOpen=false; viewport.contentY=0; }
    onPowerMenuOpenChanged: viewport.contentY=0
    function showPower(open) {
        powerMenuOpen = open;
        if (open) statusContent.forceActiveFocus();
        else powerButton.forceActiveFocus();
    }
    Keys.onEscapePressed: event => {
        if (powerMenuOpen) { showPower(false); event.accepted = true; }
        else event.accepted = false;
    }

    Connections {
        target: statusContent.Window.window
        function onActiveFocusItemChanged() { viewport.ensureVisible(statusContent.Window.window.activeFocusItem); }
    }
    Flickable {
        id: viewport
        objectName: "quickSettingsViewport"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: controls.implicitHeight
        interactive: !statusContent.panel.busy && statusContent.naturalContentHeight > statusContent.contentHeight + 0.5
        boundsBehavior: Flickable.StopAtBounds
        function ensureVisible(focused) {
            if (!interactive || !statusContent.visible || !focused) return;
            let ancestor=focused;
            while (ancestor && ancestor!==controls) ancestor=ancestor.parent;
            if (!ancestor) return;
            const point=focused.mapToItem(controls,0,0);
            let next=contentY;
            if (point.y < next) next=point.y;
            else if (point.y+focused.height > next+height) next=point.y+focused.height-height;
            contentY=Math.max(0,Math.min(contentHeight-height,next));
        }
        ScrollBar.vertical: ThemedScrollBar { policy: viewport.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
    Column {
        id: controls
        width: parent.width
        spacing: uiGeometry.metric("contentGap")

        Item {
            objectName: "quickSettingsHeader"
            visible: !statusContent.powerMenuOpen
            width: parent.width; height: uiGeometry.metric("quickHeader")
            Row {
                height: parent.height; spacing: uiGeometry.metric("quickHeaderGap"); visible: !statusContent.powerMenuOpen
                Repeater {
                    model: ["settings", "notifications"]
                    Rectangle {
                        id: headerAction
                        required property string modelData
                        width: uiGeometry.metric("quickHeader"); height: uiGeometry.metric("quickHeader"); radius: uiGeometry.radius("control", width, height)
                        color: headerMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                        border.width: activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.primary
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData === "settings" ? "Settings" : "Notifications"
                        Accessible.onPressAction: headerAction.activate()
                        Keys.onReturnPressed: headerAction.activate()
                        Keys.onSpacePressed: headerAction.activate()
                        function activate() {
                            if (modelData === "settings") { statusContent.panel.dismiss(); statusContent.root.openSettings(); }
                            else statusContent.panel.toggle(modelData);
                        }
                        Glyph { anchors.centerIn: parent; width: uiGeometry.metric("quickHeaderIcon"); height: width; name: parent.modelData }
                        MouseArea {
                            id: headerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: headerAction.activate()
                        }
                    }
                }
            }
            Rectangle {
                id: powerButton
                objectName: "powerButton"
                visible: !statusContent.powerMenuOpen
                enabled: visible
                anchors.right: parent.right; width: uiGeometry.metric("quickHeader"); height: uiGeometry.metric("quickHeader"); radius: uiGeometry.radius("control", width, height)
                color: powerMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                border.width: activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.primary
                activeFocusOnTab: visible
                Accessible.role: Accessible.Button
                Accessible.name: "Power options"
                Accessible.description: "Activate to show power actions"
                Accessible.onPressAction: powerButton.activate()
                Keys.onReturnPressed: powerButton.activate()
                Keys.onSpacePressed: powerButton.activate()
                function activate() { if (visible) statusContent.showPower(true); }
                Glyph { anchors.centerIn: parent; width: uiGeometry.metric("quickHeaderIcon"); height: width; name: "power" }
                ThemedToolTip { visible: powerMouse.containsMouse; text: powerButton.Accessible.name }
                MouseArea { id: powerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: powerButton.activate() }
            }
        }

        Grid {
            id: powerActions
            objectName: "powerActions"
            visible: statusContent.powerMenuOpen
            x: -uiGeometry.metric("powerOutset"); width: parent.width - 2 * x
            columnSpacing: uiGeometry.metric("powerGap"); rowSpacing: columnSpacing
            // Break into rows when scaled controls no longer fit; column choice never depends on child sizes.
            readonly property real minimumCell: uiGeometry.metric("actionIcon") + uiGeometry.metric("actionLabelBottom") + uiGeometry.metric("actionMinInset")
            columns: Math.max(1, Math.min(powerItems.count, Math.floor((width + columnSpacing) / (minimumCell + columnSpacing))))
            readonly property real cellSize: Math.max(0, (width - columnSpacing * (columns - 1)) / columns)
            height: Math.ceil(powerItems.count / columns) * cellSize + Math.max(0, Math.ceil(powerItems.count / columns) - 1) * rowSpacing
            Repeater {
                id: powerItems
                model: [
                    {label: "Shutdown", icon: "power", command: ["systemctl", "poweroff"]},
                    {label: "Sign Out", icon: "desktop", command: ["hyprctl", "dispatch", "hl.dsp.exit()"]},
                    {label: "Restart", icon: "rotate", command: ["systemctl", "reboot"]},
                    {label: "Sleep", icon: "night", command: ["systemctl", "suspend"]},
                    {label: "Hibernate", icon: "lock", command: ["systemctl", "hibernate"]}
                ]
                QuickActionCard {
                    required property var modelData
                    width: powerActions.cellSize; height: width
                    label: modelData.label; icon: modelData.icon
                    destructive: modelData.label === "Shutdown"
                    available: modelData.label !== "Hibernate" || !!statusContent.root.network.hibernateSupported
                    onTriggered: {
                        statusContent.showPower(false);
                        statusContent.panel.dismiss();
                        statusContent.root.defer(modelData.command);
                    }
                }
            }
        }
        Column {
            id: mainControls
            visible: !statusContent.powerMenuOpen
            width: parent.width; spacing: uiGeometry.metric("contentGap")
        Row {
            width: parent.width; height: uiGeometry.metric("quickTileHeight"); spacing: uiGeometry.metric("contentGap")
            ControlTile {
                width: Math.max(0, (parent.width - parent.spacing) / 2); height: parent.height; wide: true; radius: uiGeometry.radius("action", width, height)
                label: "Wi-Fi"; icon: "wifi"
                detail: statusContent.root.network.wifiHardBlocked ? "Hardware blocked" : statusContent.root.network.wifiBlocked ? "Radio off" : statusContent.root.network.wifi ? "Connected" : "Not connected"
                active: statusContent.root.network.wifi && !statusContent.root.network.wifiBlocked
                available: !!statusContent.root.network.wifiPresent && !!statusContent.root.network.radioWritable && !statusContent.root.network.wifiHardBlocked && !statusContent.root.actionBusy
                onTriggered: statusContent.panel.toggle("wifi")
            }
            ControlTile {
                width: Math.max(0, (parent.width - parent.spacing) / 2); height: parent.height; wide: true; radius: uiGeometry.radius("action", width, height)
                label: "Bluetooth"; icon: "bluetooth"
                detail: !Bluetooth.defaultAdapter ? "Unavailable" : statusContent.root.bluetoothOn ? "On" : "Off"
                active: statusContent.root.bluetoothOn
                available: !!Bluetooth.defaultAdapter
                onTriggered: statusContent.panel.toggle("bluetooth")
            }
        }

        Rectangle {
            width: parent.width; height: Math.ceil(quickItems.count / 4) * uiGeometry.metric("quickGridHeight") + 2 * uiGeometry.metric("quickGridInset"); radius: uiGeometry.radius("action", width, height); color: Core.Theme.surfaceContainer
            Grid {
                anchors.centerIn: parent; columns: 4; columnSpacing: uiGeometry.metric("quickGridGap"); rowSpacing: 0
                Repeater {
                    id: quickItems
                    model: [
                        {label: "Sound", icon: statusContent.root.preferences.audioMode === "alert" ? "notifications" : statusContent.root.audioOn ? "sound" : "muted", active: statusContent.root.preferences.audioMode !== "mute", run: "audio"},
                        {label: "Microphone", icon: statusContent.root.micOn ? "mic" : "mic-off", active: statusContent.root.micOn, run: "mic"},
                        {label: "Screenshot", icon: "screenshot", active: false, run: "capture"},
                        {label: "Desktop", icon: "desktop", active: false, run: "desktop"},
                        {label: "Airplane mode", icon: "airplane", active: !!statusContent.root.network.airplane, run: "airplane", available: !!statusContent.root.network.radioWritable},
                        {label: "Do not disturb", icon: "focus", active: !!statusContent.root.preferences.dnd, run: "dnd"},
                        {label: "Screen record", icon: "screenshot", active: !!statusContent.root.network.recording, run: "record", available: !!statusContent.root.network.recordingAvailable},
                        {label: "Battery saver", icon: "battery", active: !!statusContent.root.network.batterySaver, run: "battery-saver", available: !!statusContent.root.network.batterySaverAvailable}
                    ]
                    Item {
                        id: quickAction
                        required property var modelData
                        readonly property bool isToggle: ["audio", "mic", "airplane", "battery-saver", "record", "dnd"].indexOf(modelData.run) !== -1
                        readonly property bool canTrigger: modelData.available !== false
                        readonly property string stateLabel: !canTrigger ? "Unavailable" : modelData.run === "audio" ? (statusContent.root.preferences.audioMode === "alert" ? "Alert" : modelData.active ? "Sound" : "Muted") : modelData.active ? "On" : "Off"
                        width: Math.max(0, (mainControls.width - 2 * uiGeometry.metric("quickGridInset") - 3 * uiGeometry.metric("quickGridGap")) / 4); height: uiGeometry.metric("quickGridHeight")
                        activeFocusOnTab: canTrigger
                        Accessible.role: canTrigger ? Accessible.Button : Accessible.StaticText
                        Accessible.checkable: isToggle
                        Accessible.checked: isToggle && modelData.active
                        Accessible.name: modelData.label + (modelData.available === false ? ", unavailable" : isToggle ? ", " + stateLabel : "")
                        Accessible.onPressAction: quickAction.trigger()
                        Keys.onReturnPressed: quickAction.trigger()
                        Keys.onSpacePressed: quickAction.trigger()
                        function trigger() {
                            if (!canTrigger) return;
                            const action = modelData.run;
                            if (action === "audio") statusContent.root.cycleAudioMode();
                            else if (action === "mic" && statusContent.root.mic && statusContent.root.mic.audio) statusContent.root.mic.audio.muted = !statusContent.root.mic.audio.muted;
                            else if (action === "capture") { statusContent.panel.dismiss(); statusContent.root.defer([Quickshell.env("HOME") + "/.local/bin/hypr-screenshot"]); }
                            else if (action === "desktop") { statusContent.panel.dismiss(); statusContent.root.defer([Quickshell.env("HOME") + "/.local/bin/hypr-desktop"]); }
                            else if (action === "dnd") statusContent.root.setPreference("dnd", !statusContent.root.preferences.dnd);
                            else if (action === "airplane" || action === "battery-saver") statusContent.root.runAction(action, modelData.active ? "off" : "on");
                            else if (action === "record") { statusContent.panel.dismiss(); statusContent.root.defer(["python3", Qt.resolvedUrl("../services/recording.py").toString().replace("file://", ""), "toggle"]); }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: uiGeometry.metric("quickActionSize"); height: width; radius: uiGeometry.radius("control", width, height); opacity: quickAction.modelData.available === false ? Core.Theme.disabledTileOpacity : 1
                            color: Core.Theme.stateColor(quickAction.modelData.active ? Core.Theme.secondaryContainer : Core.Theme.surfaceContainerHigh,quickAction.modelData.active ? Core.Theme.onSecondaryContainer : Core.Theme.onSurface,iconMouse.containsMouse,iconMouse.pressed,quickAction.activeFocus)
                            border.width: quickAction.activeFocus ? uiGeometry.stroke(true) : 0
                            border.color: Core.Theme.primary
                            Glyph { anchors.centerIn: parent; width: uiGeometry.metric("icon"); height: width; name: quickAction.modelData.icon; ink: quickAction.modelData.active ? Core.Theme.onSecondaryContainer : Core.Theme.onSurface }
                        }
                        Text {
                            x: uiGeometry.metric("actionTextInset"); y: uiGeometry.metric("quickActionLabelY"); width: Math.max(0, parent.width - 2 * x); height: uiGeometry.metric("quickActionLabelHeight")
                            text: quickAction.modelData.label; color: Core.Theme.textPrimary
                            font.pixelSize: uiGeometry.metric("fontAction"); horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        }
                        Text {
                            x: uiGeometry.metric("actionTextInset"); y: uiGeometry.metric("quickActionStateY"); width: Math.max(0, parent.width - 2 * x); height: uiGeometry.metric("quickActionStateHeight")
                            visible: !quickAction.canTrigger
                            text: "Unavailable"
                            color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.metric("fontAction")
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: iconMouse; anchors.fill: parent; hoverEnabled: true
                            enabled: quickAction.canTrigger
                            cursorShape: Qt.PointingHandCursor
                            onClicked: quickAction.trigger()
                        }
                        ThemedToolTip { visible: iconMouse.containsMouse; text: quickAction.modelData.run === "audio" && statusContent.root.preferences.audioMode === "alert" ? "Audible alert mode" : quickAction.modelData.label + (quickAction.modelData.available === false ? " unavailable" : "") }
                    }
                }
            }
        }

        Rectangle {
            id: sliderCard
            objectName: "sliderCard"
            width: parent.width; height: sliderRows.implicitHeight + 2 * uiGeometry.metric("iconGap")
            radius: uiGeometry.radius("action", width, height); color: Core.Theme.surfaceContainer
            Column {
                id: sliderRows
                x: uiGeometry.metric("iconGap"); y: x; width: Math.max(0, parent.width - 2 * x); spacing: uiGeometry.metric("contentGap")
                QuickSliderRow {
                    objectName: "volumeRow"
                    width: parent.width
                    accessibleName: "Volume"; icon: "music"
                    minimum: 0; maximum: 150
                    available: !!statusContent.root.sink && !!statusContent.root.sink.audio
                    level: available ? statusContent.root.sink.audio.volume * 100 : 0
                    onEdited: value => { if (available) statusContent.root.sink.audio.volume = value / 100; }
                    actionName: "Cycle sound mode"
                    actionDescription: statusContent.root.preferences.audioMode === "alert" ? "Alert" : statusContent.root.preferences.audioMode === "mute" ? "Muted" : "Sound"
                    actionIcon: statusContent.root.preferences.audioMode === "alert" ? "notifications" : statusContent.root.preferences.audioMode === "mute" ? "muted" : "sound"
                    onActionTriggered: statusContent.root.cycleAudioMode()
                }
                QuickSliderRow {
                    objectName: "brightnessRow"
                    width: parent.width
                    accessibleName: "Brightness"; icon: "brightness"
                    minimum: 5; maximum: 100
                    available: statusContent.root.network.brightness >= 0
                    level: available ? statusContent.root.network.brightness : 5
                    onEdited: value => statusContent.root.setBrightness(value)
                    actionName: Core.Theme.mode === "dark" ? "Switch to light theme" : "Switch to dark theme"
                    actionDescription: Core.Theme.applying ? Core.Theme.operationLabel : !actionAvailable ? "Alternate theme mode unavailable" : Core.Theme.mode + " theme"
                    actionIcon: "night"
                    actionCheckable: true
                    actionActive: Core.Theme.mode === "dark"
                    actionAvailable: !Core.Theme.applying && !!Core.Theme.selectedPack && Core.Theme.selectedPack.valid && Core.Theme.selectedPack.modes.indexOf(Core.Theme.mode === "dark" ? "light" : "dark") !== -1
                    onActionTriggered: Core.Theme.setMode(Core.Theme.mode === "dark" ? "light" : "dark")
                }
            }
        }

        MediaCard {
            visible: !!statusContent.root.player && (!!statusContent.root.player.isPlaying || !!statusContent.root.player.trackTitle)
            width: parent.width
            height: visible ? implicitHeight : 0
            player: statusContent.root.player
        }

        Rectangle {
            width: parent.width; height: SystemTray.items.values.length + statusContent.root.trayWindows.length ? trayFlow.implicitHeight + 2 * uiGeometry.metric("contentGap") : 0
            visible: height > 0; radius: uiGeometry.radius("action", width, height); color: Core.Theme.surfaceContainer
            Flow {
                id: trayFlow
                x: uiGeometry.metric("contentGap"); y: x; width: Math.max(0, parent.width - 2 * x); spacing: uiGeometry.metric("contentGap")
                Repeater {
                    model: SystemTray.items.values
                    Rectangle {
                        id: trayButton
                        required property var modelData
                        width: uiGeometry.metric("traySize"); height: width; radius: uiGeometry.radius("tray", width, height)
                        color: trayMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                        border.width: activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.primary
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Open " + (modelData.title || modelData.id)
                        Accessible.onPressAction: modelData.activate()
                        Keys.onReturnPressed: modelData.activate()
                        Keys.onSpacePressed: modelData.activate()
                        Image { anchors.centerIn: parent; width: uiGeometry.metric("trayIcon"); height: width; source: parent.modelData.icon; fillMode: Image.PreserveAspectFit }
                        MouseArea { id: trayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData.activate() }
                        ThemedToolTip { visible: trayMouse.containsMouse; text: trayButton.modelData.title || trayButton.modelData.id }
                    }
                }
                Repeater {
                    model: statusContent.root.trayWindows
                    Rectangle {
                        id: windowButton
                        required property var modelData
                        width: uiGeometry.metric("traySize"); height: width; radius: uiGeometry.radius("tray", width, height)
                        color: windowMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                        border.width: activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.primary
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Restore " + (modelData.title || modelData.class)
                        Accessible.onPressAction: windowButton.activate()
                        Keys.onReturnPressed: windowButton.activate()
                        Keys.onSpacePressed: windowButton.activate()
                        function activate() { statusContent.root.defer(["python3", Qt.resolvedUrl("../services/windows.py").toString().replace("file://", ""), "restore", modelData.address]); statusContent.panel.dismiss(); }
                        Image { id: windowIcon; anchors.centerIn: parent; width: uiGeometry.metric("trayIcon"); height: width
                            source: Quickshell.iconPath(parent.modelData.class, true); visible: status === Image.Ready }
                        Text { visible: !windowIcon.visible; anchors.centerIn: parent; text: parent.modelData.class.slice(0, 1); color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.metric("fontBody") }
                        MouseArea { id: windowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: windowButton.activate() }
                        ThemedToolTip { visible: windowMouse.containsMouse; text: windowButton.modelData.title || windowButton.modelData.class }
                    }
                }
            }
        }

        Text {
            visible: Core.Theme.errorMessage.length > 0
            width: parent.width; text: Core.Theme.errorMessage
            color: Core.Theme.error; font.pixelSize: uiGeometry.metric("fontAction"); wrapMode: Text.WordWrap
        }
        }
        Text {
            id: actionError
            visible: statusContent.root.actionError.length > 0
            width: parent.width; text: statusContent.root.actionError
            color: Core.Theme.error; font.pixelSize: uiGeometry.metric("fontAction"); elide: Text.ElideRight
        }
    }

    }
}
