pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Bluetooth
import "../core" as Core
import "../components"
Column {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: connectivity
    required property var root
    property bool wifi: true
    property var networks: []
    property string selectedSsid: ""
    property string errorMessage: ""
    spacing: 26
    onVisibleChanged: if (visible && wifi) refresh()
    function refresh() { if (!wifiList.running) wifiList.running = true; }
    Process {
        id: wifiList; command: ["python3", Qt.resolvedUrl("../services/wifi.py").toString().replace("file://", ""), "list"]
        stdout: StdioCollector { onStreamFinished: {
            try { const result=JSON.parse(text); connectivity.networks=result.networks || []; connectivity.errorMessage=result.ok ? "" : result.error; }
            catch(e) { connectivity.errorMessage="Could not list Wi-Fi networks"; }
        } }
    }
    Process {
        id: wifiConnect
        stdout: StdioCollector { onStreamFinished: {
            try { const result=JSON.parse(text); connectivity.errorMessage=result.ok ? "" : result.error; if (result.ok) { connectivity.selectedSsid=""; connectivity.refresh(); } }
            catch(e) { connectivity.errorMessage="Connection failed"; }
        } }
    }
    SettingsSection {
        width: parent.width; title: connectivity.wifi ? "Wi-Fi" : "Bluetooth"
        SettingsRow {
            width: parent.width; label: connectivity.wifi ? "Wireless networking" : "Bluetooth adapter"
            description: connectivity.wifi ? "Connect to nearby wireless networks" : "Connect headphones, keyboards and other devices"
            controlWidth: 50
            SettingsSwitch {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: connectivity.wifi ? !connectivity.root.network.wifiBlocked : connectivity.root.bluetoothOn
                enabled: connectivity.wifi ? !!connectivity.root.network.wifiPresent && !!connectivity.root.network.radioWritable : !!Bluetooth.defaultAdapter
                Accessible.name: connectivity.wifi ? "Wi-Fi" : "Bluetooth"
                onToggled: {
                    if (connectivity.wifi) connectivity.root.runAction("wifi", checked ? "on" : "off");
                    else if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled=checked;
                }
            }
        }
    }
    SettingsSection {
        width: parent.width; title: connectivity.wifi ? "Available networks" : "Devices"
        SettingsButton { visible: connectivity.wifi; text: wifiList.running ? "Scanning…" : "Refresh networks"; enabled: !wifiList.running; onClicked: connectivity.refresh() }
        Repeater {
            model: connectivity.wifi ? connectivity.networks : Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices.values : []
            SettingsRow {
                id: entry; required property var modelData; width: parent.width
                label: connectivity.wifi ? modelData.ssid : modelData.name || modelData.deviceName
                description: connectivity.wifi ? (modelData.connected ? "Connected" : modelData.signal + "% signal · " + (modelData.security || "Open network")) : (modelData.connected ? "Connected" : "Not connected")
                controlWidth: 100
                SettingsButton {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.connected ? (connectivity.wifi ? "Connected" : "Disconnect") : "Connect"
                    enabled: !wifiConnect.running && (!connectivity.wifi || !entry.modelData.connected)
                    Accessible.name: text + " " + entry.label
                    onClicked: {
                        if (connectivity.wifi) { connectivity.selectedSsid=entry.modelData.ssid; Qt.callLater(() => password.forceActiveFocus()); }
                        else entry.modelData.connected=!entry.modelData.connected;
                    }
                }
            }
        }
        Text {
            visible: (connectivity.wifi ? connectivity.networks.length : Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices.values.length : 0)===0
            width: parent.width; wrapMode: Text.Wrap; text: connectivity.wifi ? (wifiList.running ? "Looking for networks…" : "No wireless networks found") : (Bluetooth.defaultAdapter ? "No Bluetooth devices found" : "No Bluetooth adapter available")
            color: Core.Theme.textSecondary; font.pixelSize: 14
        }
    }
    SettingsSection {
        visible: connectivity.wifi && connectivity.selectedSsid !== ""; width: parent.width; title: "Connect to " + connectivity.selectedSsid
        TextField { selectionColor: Core.Theme.primaryContainer; selectedTextColor: Core.Theme.onPrimaryContainer;
            id: password; width: parent.width; height: 42; echoMode: TextInput.Password; placeholderText: "Network password"; font.pixelSize: 14
            color: Core.Theme.textPrimary; placeholderTextColor: Core.Theme.textSecondary
            Accessible.name: "Password for " + connectivity.selectedSsid
            background: Rectangle { radius: uiGeometry.radius("field", width, height); color: Core.Theme.surfaceContainerHighest; border.width: password.activeFocus ? 2 : 1; border.color: password.activeFocus ? Core.Theme.primary : Core.Theme.outlineVariant }
        }
        Row {
            spacing: 8
            SettingsButton {
                text: "Connect"; enabled: !wifiConnect.running
                onClicked: { wifiConnect.command=["python3",Qt.resolvedUrl("../services/wifi.py").toString().replace("file://", ""),"connect",connectivity.selectedSsid,password.text]; wifiConnect.running=true; password.clear(); }
            }
            SettingsButton { text: "Cancel"; onClicked: { connectivity.selectedSsid=""; password.clear(); } }
        }
    }
    Text { visible: connectivity.errorMessage !== ""; width: parent.width; text: connectivity.errorMessage; color: Core.Theme.error; font.pixelSize: 13; wrapMode: Text.Wrap }
}
