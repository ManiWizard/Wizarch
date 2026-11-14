import QtQuick
import QtQuick.Controls
import "../core" as Core
ToolTip {
    property var uiGeometry: Core.Geometry.contextFor(parent)

 id: tip
 contentItem: Text { text: tip.text; font: tip.font; color: Core.Theme.inverseOnSurface }
 background: Rectangle { color: Core.Theme.inverseSurface; radius: uiGeometry.radius("tooltip", width, height) }
}
