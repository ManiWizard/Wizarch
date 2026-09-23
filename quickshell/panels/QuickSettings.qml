pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../core" as Core
import "../components"
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Bluetooth

Item {
    id: statusContent
    required property var root
    required property var panel
    property bool powerMenuOpen: false
    visible: panel.shownSection === "status" && opacity > 0
    opacity: panel.contentAlpha
    enabled: !panel.busy
    onVisibleChanged: if (!visible) powerMenuOpen = false

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width; height: 30
            Row {
                height: parent.height; spacing: 7
                Repeater {
                    model: ["settings", "notifications"]
                    Rectangle {
                        required property string modelData
                        width: 30; height: 30; radius: 15
                        color: headerMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                        Glyph { anchors.centerIn: parent; width: 17; height: 17; name: parent.modelData }
                        MouseArea {
                            id: headerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                statusContent.panel.activity();
                                if (parent.modelData === "settings") statusContent.panel.toggle("themes");
                                else statusContent.panel.toggle("notifications");
                            }
                        }
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right; width: 30; height: 30; radius: 15
                color: powerMouse.containsMouse || statusContent.powerMenuOpen ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                Glyph { anchors.centerIn: parent; width: 17; height: 17; name: "power" }
                MouseArea { id: powerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { statusContent.powerMenuOpen = !statusContent.powerMenuOpen; statusContent.panel.activity(); } }
            }
        }

        Row {
            width: parent.width; height: 62; spacing: 8
            ControlTile {
                width: (parent.width - 8) / 2; height: parent.height; wide: true
                label: "Wi-Fi"; icon: "wifi"
                detail: statusContent.root.network.wifiHardBlocked ? "Hardware blocked" : statusContent.root.network.wifiBlocked ? "Radio off" : statusContent.root.network.wifi ? "Connected" : "Not connected"
                active: statusContent.root.network.wifi && !statusContent.root.network.wifiBlocked
                available: !!statusContent.root.network.wifiPresent && !!statusContent.root.network.radioWritable && !statusContent.root.network.wifiHardBlocked && !statusContent.root.actionBusy
                onTriggered: { statusContent.root.runAction("wifi", statusContent.root.network.wifiBlocked ? "on" : "off"); statusContent.panel.activity(); }
            }
            ControlTile {
                width: (parent.width - 8) / 2; height: parent.height; wide: true
                label: "Bluetooth"; icon: "bluetooth"
                detail: !Bluetooth.defaultAdapter ? "Unavailable" : statusContent.root.bluetoothOn ? "On" : "Off"
                active: statusContent.root.bluetoothOn
                available: !!Bluetooth.defaultAdapter
                onTriggered: { Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled; statusContent.panel.activity(); }
            }
        }

        Rectangle {
            width: parent.width; height: 207; radius: 14; color: Core.Theme.surfaceContainer
            Grid {
                anchors.centerIn: parent; columns: 4; columnSpacing: 12; rowSpacing: 4
                Repeater {
                    model: [
                        {label: "Sound", icon: statusContent.root.audioOn ? "sound" : "muted", active: statusContent.root.audioOn, run: "audio"},
                        {label: "Microphone", icon: statusContent.root.micOn ? "mic" : "mic-off", active: statusContent.root.micOn, run: "mic"},
                        {label: "Screenshot", icon: "screenshot", active: false, run: "capture"},
                        {label: "Desktop", icon: "desktop", active: false, run: "desktop"},
                        {label: "Battery", icon: "battery", active: UPower.onBattery, run: "battery"},
                        {label: "Brightness", icon: "brightness", active: false, run: "brightness"},
                        {label: "Apps", icon: "apps", active: false, run: "apps"},
                        {label: "Music", icon: "music", active: !!statusContent.root.player, run: "music"},
                        {label: "Airplane mode", icon: "airplane", active: false, run: "unavailable", available: false},
                        {label: "Auto rotate", icon: "rotate", active: false, run: "unavailable", available: false},
                        {label: "Night light", icon: "night", active: false, run: "unavailable", available: false},
                        {label: "Location", icon: "location", active: false, run: "unavailable", available: false},
                        {label: "Hotspot", icon: "hotspot", active: false, run: "unavailable", available: false},
                        {label: "Focus", icon: "focus", active: false, run: "unavailable", available: false},
                        {label: "Camera", icon: "camera", active: false, run: "unavailable", available: false},
                        {label: "Lock", icon: "lock", active: false, run: "unavailable", available: false}
                    ]
                    Item {
                        required property var modelData
                        width: 63; height: 45
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 42; height: 42; radius: 21; opacity: parent.modelData.available === false ? 0.4 : 1
                            color: parent.modelData.active ? Core.Theme.secondaryContainer : iconMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                            Glyph { anchors.centerIn: parent; width: 21; height: 21; name: parent.parent.modelData.icon }
                            MouseArea {
                                id: iconMouse; anchors.fill: parent; hoverEnabled: true
                                cursorShape: parent.parent.modelData.run === "battery" || parent.parent.modelData.available === false ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    const action = parent.parent.modelData.run;
                                    if (parent.parent.modelData.available === false) return;
                                    statusContent.panel.activity();
                                    if (action === "audio" && statusContent.root.sink && statusContent.root.sink.audio) statusContent.root.sink.audio.muted = !statusContent.root.sink.audio.muted;
                                    else if (action === "mic" && statusContent.root.mic && statusContent.root.mic.audio) statusContent.root.mic.audio.muted = !statusContent.root.mic.audio.muted;
                                    else if (action === "capture") { statusContent.panel.dismiss(); statusContent.root.defer([Quickshell.env("HOME") + "/.local/bin/hypr-screenshot"]); }
                                    else if (action === "desktop") { statusContent.panel.dismiss(); statusContent.root.defer([Quickshell.env("HOME") + "/.local/bin/hypr-desktop"]); }
                                    else if (action === "brightness" && statusContent.root.network.brightness >= 0) statusContent.root.setBrightness(statusContent.root.network.brightness > 50 ? 25 : 75);
                                    else if (action === "apps") statusContent.panel.toggle("launcher");
                                    else if (action === "music" && statusContent.root.player) statusContent.root.player.togglePlaying();
                                }
                            }
                        }
                        ToolTip.visible: iconMouse.containsMouse
                        ToolTip.text: modelData.run === "battery" ? (statusContent.root.hasBattery ? statusContent.root.batteryPercent + "%" : "External power") : modelData.label + (modelData.available === false ? " unavailable" : "")
                    }
                }
            }
        }

        Rectangle {
            width: parent.width; height: 88; radius: 14; color: Core.Theme.surfaceContainer
            Column {
                anchors.fill: parent; anchors.margins: 11; spacing: 6
                Row {
                    width: parent.width; height: 29; spacing: 10
                    Glyph { width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; name: statusContent.root.audioOn ? "sound" : "muted" }
                    Slider {
                        id: volumeSlider; width: parent.width - 28; height: parent.height
                        from: 0; to: 150; stepSize: 1
                        enabled: !!statusContent.root.sink && !!statusContent.root.sink.audio
                        value: enabled ? statusContent.root.sink.audio.volume * 100 : 0
                        Accessible.name: "Volume"
                        onMoved: { statusContent.root.sink.audio.volume = value / 100; statusContent.panel.activity(); }
                        background: Rectangle {
                            x: volumeSlider.leftPadding; y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                            width: volumeSlider.availableWidth; height: 17; radius: 9; color: Core.Theme.surfaceContainerHigh
                            Rectangle { width: Math.max(0, volumeSlider.visualPosition * parent.width); height: parent.height; radius: parent.radius; color: Core.Theme.primary }
                        }
                        handle: Item { width: 0; height: 0 }
                    }
                }
                Row {
                    width: parent.width; height: 29; spacing: 10
                    Glyph { width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; name: "brightness" }
                    Slider {
                        id: brightnessSlider; width: parent.width - 28; height: parent.height
                        from: 5; to: 100; stepSize: 1
                        enabled: statusContent.root.network.brightness >= 0
                        value: enabled ? statusContent.root.network.brightness : 5
                        Accessible.name: "Brightness"
                        onMoved: { statusContent.root.setBrightness(value); statusContent.panel.activity(); }
                        background: Rectangle {
                            x: brightnessSlider.leftPadding; y: brightnessSlider.topPadding + (brightnessSlider.availableHeight - height) / 2
                            width: brightnessSlider.availableWidth; height: 17; radius: 9; color: Core.Theme.surfaceContainerHigh
                            Rectangle { width: Math.max(0, brightnessSlider.visualPosition * parent.width); height: parent.height; radius: parent.radius; color: Core.Theme.secondary }
                        }
                        handle: Item { width: 0; height: 0 }
                    }
                }
            }
        }

        Rectangle {
            visible: !!statusContent.root.player && !!statusContent.root.player.isPlaying
            width: parent.width; height: visible ? 58 : 0; radius: 14; color: Core.Theme.surfaceContainer
            Glyph { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; name: "music" }
            Text { x: 43; y: 11; width: parent.width - 135; text: statusContent.root.player ? (statusContent.root.player.trackTitle || statusContent.root.player.identity) : ""; color: Core.Theme.textPrimary; font.pixelSize: 11; elide: Text.ElideRight }
            Text { x: 43; y: 31; width: parent.width - 135; text: statusContent.root.player ? (statusContent.root.player.trackArtist || statusContent.root.player.identity) : ""; color: Core.Theme.textSecondary; font.pixelSize: 9; elide: Text.ElideRight }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                Repeater {
                    model: ["previous", "pause", "next"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: 25; height: 28; radius: 9; color: mediaMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                        Glyph { anchors.centerIn: parent; width: 14; height: 14; name: parent.modelData }
                        MouseArea {
                            id: mediaMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!statusContent.root.player) return;
                                if (parent.index === 0) statusContent.root.player.previous();
                                else if (parent.index === 1) statusContent.root.player.togglePlaying();
                                else statusContent.root.player.next();
                                statusContent.panel.activity();
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: statusContent.root.actionError.length > 0
            width: parent.width; text: statusContent.root.actionError
            color: Core.Theme.error; font.pixelSize: 10; elide: Text.ElideRight
        }
    }

    Rectangle {
        z: 2; visible: statusContent.powerMenuOpen
        x: parent.width - width; y: 36; width: 150; height: 112; radius: 12
        color: Core.Theme.surfaceContainerHigh
        Column {
            anchors.fill: parent; anchors.margins: 5; spacing: 1
            Repeater {
                model: ["Log out", "Restart", "Power off"]
                Rectangle {
                    required property string modelData
                    width: 140; height: 33; radius: 8
                    color: optionMouse.containsMouse ? Core.Theme.hoverSurface : "transparent"
                    Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: parent.modelData; color: Core.Theme.textPrimary; font.pixelSize: 11 }
                    MouseArea {
                        id: optionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            statusContent.powerMenuOpen = false;
                            statusContent.panel.dismiss();
                            if (parent.modelData === "Log out") statusContent.root.defer(["hyprctl", "dispatch", "exit"]);
                            else if (parent.modelData === "Restart") statusContent.root.defer(["systemctl", "reboot"]);
                            else statusContent.root.defer(["systemctl", "poweroff"]);
                        }
                    }
                }
            }
        }
    }
}
