import QtQuick
import "../core" as Core
Rectangle {
 width: 1; height: 19
 gradient: Gradient {
  GradientStop { position: 0; color: "transparent" }
  GradientStop { position: 0.28; color: Core.Theme.divider }
  GradientStop { position: 0.72; color: Core.Theme.divider }
  GradientStop { position: 1; color: "transparent" }
 }
}
