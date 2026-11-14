pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../core" as Core

// One filled frame: no overlapping stroke to fatten corners or screen edges.
// The notch itself is filled by Pill.qml in the same color, above this layer.
PanelWindow {
    property var uiGeometry: panel.uiGeometry || Core.Geometry

    id: frame
    required property var panel
    property bool reserveSpace: true
    screen: panel.modelData
    visible: panel.edgeConnected && panel.screenBorder
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "wizarch-screen-border"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}
    // Match the top frame reservation on all other edges, so gaps stay symmetric.
    Variants {
        model: frame.reserveSpace ? ["left", "right", "bottom"] : []
        PanelWindow {
            required property string modelData
            screen: frame.panel.modelData
            visible: frame.visible
            anchors {
                left: modelData !== "right"
                right: modelData !== "left"
                top: modelData !== "bottom"
                bottom: true
            }
            implicitWidth: modelData === "bottom" ? frame.panel.modelData.width : frame.panel.borderThickness
            implicitHeight: modelData === "bottom" ? frame.panel.borderThickness : frame.panel.modelData.height
            exclusiveZone: frame.panel.borderThickness
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "wizarch-frame-reserve-" + modelData
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            mask: Region {}
        }
    }
    Shape {
        id: outline
        width: frame.width; height: frame.height
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        readonly property real t: frame.panel.borderThickness
        readonly property real radius: uiGeometry.boundedRadius(frame.panel.frameRadius, Math.max(0, width - 2 * t), Math.max(0, height - 2 * t))
        // Standard cubic circular-arc approximation, rather than squarer quadratics.
        readonly property real arc: radius * uiGeometry.cubicCircleFactor
        readonly property real leftEdge: t
        readonly property real rightEdge: width - t
        readonly property real topEdge: t
        readonly property real bottomEdge: height - t
        ShapePath {
            strokeWidth: -1
            fillColor: Core.Theme.surface
            fillRule: ShapePath.OddEvenFill
            startX: 0; startY: 0
            PathLine { x: outline.width; y: 0 }
            PathLine { x: outline.width; y: outline.height }
            PathLine { x: 0; y: outline.height }
            PathLine { x: 0; y: 0 }
            PathMove { x: outline.leftEdge + outline.radius; y: outline.topEdge }
            PathLine { x: outline.rightEdge - outline.radius; y: outline.topEdge }
            PathCubic {
                x: outline.rightEdge; y: outline.topEdge + outline.radius
                control1X: outline.rightEdge - outline.radius + outline.arc; control1Y: outline.topEdge
                control2X: outline.rightEdge; control2Y: outline.topEdge + outline.radius - outline.arc
            }
            PathLine { x: outline.rightEdge; y: outline.bottomEdge - outline.radius }
            PathCubic {
                x: outline.rightEdge - outline.radius; y: outline.bottomEdge
                control1X: outline.rightEdge; control1Y: outline.bottomEdge - outline.radius + outline.arc
                control2X: outline.rightEdge - outline.radius + outline.arc; control2Y: outline.bottomEdge
            }
            PathLine { x: outline.leftEdge + outline.radius; y: outline.bottomEdge }
            PathCubic {
                x: outline.leftEdge; y: outline.bottomEdge - outline.radius
                control1X: outline.leftEdge + outline.radius - outline.arc; control1Y: outline.bottomEdge
                control2X: outline.leftEdge; control2Y: outline.bottomEdge - outline.radius + outline.arc
            }
            PathLine { x: outline.leftEdge; y: outline.topEdge + outline.radius }
            PathCubic {
                x: outline.leftEdge + outline.radius; y: outline.topEdge
                control1X: outline.leftEdge; control1Y: outline.topEdge + outline.radius - outline.arc
                control2X: outline.leftEdge + outline.radius - outline.arc; control2Y: outline.topEdge
            }
        }
    }
}
