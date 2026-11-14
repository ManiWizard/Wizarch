import QtQuick
import QtQuick.Effects
import "../core" as Core
Image {
    property color ink: Core.Theme.onSurface
    property string name: "apps"
    source: Qt.resolvedUrl("../assets/icons/" + name + ".svg")
    sourceSize: Qt.size(32, 32)
    fillMode: Image.PreserveAspectFit
    smooth: true
    layer.enabled: true
    layer.effect: MultiEffect { colorization: 1; colorizationColor: ink }
}
