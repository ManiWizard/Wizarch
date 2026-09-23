import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core" as Core
PanelWindow {
 required property var modelData
 screen: modelData
 anchors { top: true; bottom: true; left: true; right: true }
 exclusionMode: ExclusionMode.Ignore
 WlrLayershell.layer: WlrLayer.Background
 WlrLayershell.namespace: "wizarch-wallpaper"
 color: "#000000"
 Image { anchors.fill: parent; source: Core.Theme.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true }
}
