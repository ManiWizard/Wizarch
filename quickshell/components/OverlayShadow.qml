pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../core" as Core

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: separation
    required property var panel
    anchors.fill: parent
    visible: panel.overlayWindows && panel.hideProgress < 1
    // Theme-aware contrast, without wallpaper copies or desktop pixel polling.
    readonly property real surfaceLightness: 0.2126 * Core.Theme.surface.r + 0.7152 * Core.Theme.surface.g + 0.0722 * Core.Theme.surface.b
    readonly property bool darkSurface: surfaceLightness < 0.5
    Rectangle {
        id: shadowSource
        anchors.horizontalCenter: parent.horizontalCenter
        y: separation.panel.panelTop + separation.panel.hideOffset - separation.panel.visualClipTop
        width: separation.panel.surfaceWidth; height: separation.panel.surfaceHeight
        radius: uiGeometry.radius("panel", width, height)
        color: Core.Theme.surface
        visible: false; layer.enabled: true
    }
    MultiEffect {
        anchors.fill: shadowSource
        source: shadowSource
        shadowEnabled: true
        shadowColor: separation.darkSurface ? "#ffffff" : "#000000"
        shadowOpacity: separation.darkSurface ? 0.18 : 0.28
        shadowBlur: 0.65
        shadowVerticalOffset: uiGeometry.metric("shadowOffset")
        shadowHorizontalOffset: 0
        autoPaddingEnabled: true
    }
}
