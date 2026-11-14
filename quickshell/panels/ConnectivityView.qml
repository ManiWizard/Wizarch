pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Bluetooth
import "../core" as Core
import "../components"

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: detail
    required property var root
    required property var panel
    readonly property real contentHeight: detailContent.implicitHeight + 36
    readonly property bool wifiView: panel.shownSection === "wifi"
    readonly property bool bluetoothView: panel.shownSection === "bluetooth"
    visible: (wifiView || bluetoothView) && opacity > 0
    opacity: panel.contentAlpha
    enabled: !panel.busy
    property var networks: []
    property string selectedSsid: ""
    property string errorText: ""
    onVisibleChanged: if (visible && wifiView) refresh()
    function refresh() { wifiList.running = true; }
    Process {
        id: wifiList
        command: ["python3", Qt.resolvedUrl("../services/wifi.py").toString().replace("file://", ""), "list"]
        stdout: StdioCollector { onStreamFinished: {
            try { const result = JSON.parse(text); detail.networks = result.networks || []; detail.errorText = result.ok ? "" : result.error; }
            catch (e) { detail.errorText = "Could not list networks"; }
        } }
    }
    Process {
        id: wifiConnect
        stdout: StdioCollector { onStreamFinished: {
            try { const result = JSON.parse(text); detail.errorText = result.ok ? "" : result.error; if (result.ok) { detail.selectedSsid = ""; detail.refresh(); } }
            catch (e) { detail.errorText = "Connection failed"; }
        } }
    }
    Column {
        id: detailContent
        anchors.fill: parent; spacing: 10
        Row {
            width: parent.width; height: 30; spacing: 8
            Rectangle {
                width: 30; height: 30; radius: uiGeometry.radius("control", width, height); color: backMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                activeFocusOnTab: true
                Accessible.role: Accessible.Button; Accessible.name: "Back to quick settings"
                Accessible.onPressAction: detail.panel.toggle("status")
                Keys.onReturnPressed: detail.panel.toggle("status")
                Keys.onSpacePressed: detail.panel.toggle("status")
                Text { anchors.centerIn: parent; text: "‹"; color: Core.Theme.textPrimary; font.pixelSize: 23 }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: detail.panel.toggle("status") }
            }
            Text { text: detail.wifiView ? "Wi-Fi" : "Bluetooth"; color: Core.Theme.textPrimary; font.pixelSize: 15; font.weight: Font.Medium }
            Item { width: 120; height: 1 }
            SettingsSwitch {
                checked: detail.wifiView ? !detail.root.network.wifiBlocked : detail.root.bluetoothOn
                enabled: detail.wifiView ? !!detail.root.network.wifiPresent && !!detail.root.network.radioWritable : !!Bluetooth.defaultAdapter
                Accessible.name: detail.wifiView ? "Wi-Fi" : "Bluetooth"
                onToggled: {
                    if (detail.wifiView) detail.root.runAction("wifi", checked ? "on" : "off");
                    else if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = checked;
                }
            }
        }
        Rectangle { width: parent.width; height: 245; radius: uiGeometry.radius("softCard", width, height); color: Core.Theme.surfaceContainer
            Flickable { anchors.fill: parent; anchors.margins: 8; contentHeight: entries.height; clip: true
                Column { id: entries; width: parent.width; spacing: 3
                    Repeater { model: detail.wifiView ? detail.networks : Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices.values : []
                        Rectangle { id: entry; required property var modelData; width: entries.width; height: 39; radius: uiGeometry.radius("button", width, height)
                            color: entryMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                            border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: (detail.wifiView ? modelData.ssid : modelData.name || modelData.deviceName) + ", " + (modelData.connected ? "connected" : "not connected")
                            Accessible.onPressAction: entry.activate()
                            Keys.onReturnPressed: entry.activate()
                            Keys.onSpacePressed: entry.activate()
                            function activate() {
                                if (detail.wifiView) {
                                    detail.selectedSsid = modelData.connected ? "" : modelData.ssid;
                                    if (detail.selectedSsid) Qt.callLater(() => password.forceActiveFocus());
                                }
                                else modelData.connected = !modelData.connected;
                            }
                            Text { x: 11; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; elide: Text.ElideRight
                                text: detail.wifiView ? parent.modelData.ssid : parent.modelData.name || parent.modelData.deviceName
                                color: Core.Theme.textPrimary; font.pixelSize: 11 }
                            Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                text: detail.wifiView ? (parent.modelData.connected ? "Connected" : parent.modelData.signal + "%") : (parent.modelData.connected ? "Connected" : "Connect")
                                color: Core.Theme.textSecondary; font.pixelSize: 9 }
                            MouseArea { id: entryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: entry.activate() }
                        }
                    }
                    Text { visible: entries.children.length <= 1; text: detail.wifiView ? "No Wi-Fi networks found" : "No Bluetooth devices found"; color: Core.Theme.textSecondary; font.pixelSize: 11 }
                }
            }
        }
        Row { visible: detail.wifiView && detail.selectedSsid !== ""; spacing: 6; height: visible ? 34 : 0
            TextInput { selectionColor: Core.Theme.primaryContainer; selectedTextColor: Core.Theme.onPrimaryContainer; id: password; width: 235; height: 30; echoMode: TextInput.Password; color: Core.Theme.textPrimary; font.pixelSize: 11
                Accessible.name: "Password for " + detail.selectedSsid
                Text { text: "Password for " + detail.selectedSsid; visible: !password.text; color: Core.Theme.textSecondary; font.pixelSize: 10 } }
            Rectangle { width: 70; height: 30; radius: uiGeometry.radius("navigation", width, height); color: Core.Theme.secondaryContainer
                id: connectButton
                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                activeFocusOnTab: true
                Accessible.role: Accessible.Button; Accessible.name: "Connect to " + detail.selectedSsid
                Accessible.onPressAction: connectButton.activate()
                Keys.onReturnPressed: connectButton.activate()
                Keys.onSpacePressed: connectButton.activate()
                function activate() {
                    wifiConnect.command = ["python3", Qt.resolvedUrl("../services/wifi.py").toString().replace("file://", ""), "connect", detail.selectedSsid, password.text];
                    wifiConnect.running = true; password.text = "";
                }
                Text { anchors.centerIn: parent; text: "Connect"; color: Core.Theme.onSecondaryContainer; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connectButton.activate() }
            }
        }
        Text { visible: detail.errorText !== ""; width: parent.width; wrapMode: Text.Wrap; text: detail.errorText; color: Core.Theme.error; font.pixelSize: 10 }
        Text { visible: detail.bluetoothView; text: Bluetooth.defaultAdapter ? "Select a device to connect or disconnect" : "No Bluetooth adapter"; color: Core.Theme.textSecondary; font.pixelSize: 10 }
    }
}
