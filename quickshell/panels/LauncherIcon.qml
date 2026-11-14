import QtQuick
import Quickshell
import "../core" as Core
import "LauncherModel.js" as Model

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: icon
    property string appName: ""
    property string iconName: ""
    readonly property bool ready: artwork.status === Image.Ready
    Image {
        id: artwork
        anchors.fill: parent
        source: Model.iconSource(icon.iconName, name => Quickshell.iconPath(name, true))
        sourceSize.width: Math.ceil(width * 2 * uiGeometry.devicePixelRatio); sourceSize.height: Math.ceil(height * 2 * uiGeometry.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        visible: icon.ready
    }
    Rectangle {
        anchors.fill: parent; visible: !icon.ready
        radius: uiGeometry.proportionalRadius("launcherIcon", width, height); color: Core.Theme.surfaceContainerHigh
        Rectangle {
            x: parent.width * .18; y: parent.height * .2
            width: parent.width * .64; height: parent.height * .6
            radius: uiGeometry.proportionalRadius("launcherIconDetail", width, height); color: "transparent"
            border.width: uiGeometry.dp(1); border.color: Core.Theme.textSecondary
            Rectangle { x: uiGeometry.dp(1); y: parent.height * .23; width: parent.width - uiGeometry.dp(2); height: uiGeometry.dp(1); color: Core.Theme.textSecondary; opacity: .65 }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * .3
                height: parent.height * .62; verticalAlignment: Text.AlignVCenter
                text: icon.appName.trim().slice(0, 1).toUpperCase()
                color: Core.Theme.textSecondary; font.pixelSize: Math.max(uiGeometry.dp(9), parent.height * .48); font.weight: Font.Medium
            }
        }
    }
}
