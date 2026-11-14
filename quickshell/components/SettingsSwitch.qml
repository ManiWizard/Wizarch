pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../core" as Core
Switch {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: toggle
    implicitWidth: uiGeometry.metric("switchWidth"); implicitHeight: uiGeometry.controlHeight("switch", 0)
    padding: 0; opacity: enabled ? 1 : Core.Theme.disabledControlOpacity
    indicator: Rectangle {
        id: track
        width: uiGeometry.fit(uiGeometry.metric("switchWidth"), toggle.width); height: uiGeometry.fit(uiGeometry.metric("switchTrackHeight"), toggle.height); y: (toggle.height - height) / 2; radius: uiGeometry.radius("control", width, height)
        color: Core.Theme.stateColor(toggle.checked ? Core.Theme.primary : Core.Theme.surfaceContainerHighest,toggle.checked ? Core.Theme.onPrimary : Core.Theme.onSurface,toggle.hovered,toggle.down,toggle.activeFocus)
        border.width: uiGeometry.stroke(toggle.activeFocus)
        border.color: toggle.activeFocus ? Core.Theme.textPrimary : Core.Theme.outlineVariant
        Rectangle {
            readonly property real inset: uiGeometry.fit(uiGeometry.metric("switchInset"), Math.min(track.width, track.height) / 2)
            x: toggle.checked ? Math.max(0, track.width - uiGeometry.fit(uiGeometry.metric("switchCheckedInset"), track.width) - width) : inset; y: inset
            width: Math.max(0, Math.min(track.width, track.height) - 2 * inset); height: width; radius: uiGeometry.insetRadius(track.radius, inset, width, height)
            color: toggle.checked ? Core.Theme.onPrimary : Core.Theme.textSecondary
            Behavior on x { NumberAnimation { duration: 120 } }
        }
    }
}
