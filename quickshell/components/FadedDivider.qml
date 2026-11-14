import QtQuick
import "../core" as Core
Rectangle {
    property var uiGeometry: Core.Geometry.contextFor(parent)

 width: uiGeometry.dp(1); height: uiGeometry.dp(19)
 gradient: Gradient {
  GradientStop { position: 0; color: "transparent" }
  GradientStop { position: 0.28; color: Core.Theme.divider }
  GradientStop { position: 0.72; color: Core.Theme.divider }
  GradientStop { position: 1; color: "transparent" }
 }
}
