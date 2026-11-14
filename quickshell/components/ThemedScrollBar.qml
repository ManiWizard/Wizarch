import QtQuick
import QtQuick.Controls
import "../core" as Core
ScrollBar {
    property var uiGeometry: Core.Geometry.contextFor(parent)

 id: bar
 contentItem: Rectangle { implicitWidth: uiGeometry.dp(6); implicitHeight: uiGeometry.dp(6); radius: uiGeometry.radius("control", width, height); color: Core.Theme.stateColor(Core.Theme.outline,Core.Theme.surface,bar.hovered,bar.pressed,bar.activeFocus) }
}
