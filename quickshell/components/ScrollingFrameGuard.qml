pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
import Quickshell.Wayland

// Native offscreen columns can paint outside the reserved work area. Reuse the
// original frame outline as a click-through guard; keep its Bottom surface and
// reservations intact. No gutter, card, app capture, or pill contour is involved.
ScreenBorder {
    property var uiGeometry: Core.GeometryContext { uiScale: Core.Geometry.scaleForOutput(guard.modelData.name); devicePixelRatio: guard.devicePixelRatio }

    id: guard
    required property var modelData
    required property var root
    required property var state
    reserveSpace: false
    panel: QtObject {
        readonly property var modelData: guard.modelData
        readonly property bool edgeConnected: guard.root.preferences.edgeConnected !== false
        readonly property bool screenBorder: edgeConnected && guard.root.preferences.screenBorder === true
        readonly property real borderThickness: Math.max(1, Math.min(10, guard.root.preferences.borderThickness || 3))
        readonly property real borderRadius: uiGeometry.clamp(0, uiGeometry.constraint("borderRadiusMaximum"),
            guard.root.preferences.borderRadius === undefined ? uiGeometry.radius("panel", modelData.width, modelData.height) : guard.root.preferences.borderRadius)
        readonly property real frameRadius: guard.root.preferences.matchWindowCorners !== false
            ? guard.root.matchedFrameRadius : borderRadius
    }
    visible: panel.screenBorder && guard.state.monitors[modelData.name] === true
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "wizarch-peek-frame"
}
