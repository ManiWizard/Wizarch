import QtQuick
import QtQuick.Controls
import "../core" as Core
Button {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: button
    implicitHeight: uiGeometry.controlHeight("button", label.implicitHeight + 2 * uiGeometry.metric("buttonVerticalPadding")); implicitWidth: Math.max(implicitHeight, label.implicitWidth + 2 * uiGeometry.metric("buttonPadding"))
    font.pixelSize: uiGeometry.metric("fontBody")
    contentItem: Text { id: label; text: button.text; color: button.flat && (button.hovered || button.down) ? Core.Theme.primary : Core.Theme.textPrimary; font: button.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    background: Rectangle { radius: uiGeometry.radius("button", width, height); color: button.flat ? "transparent" : Core.Theme.stateColor(Core.Theme.surfaceContainerHighest,Core.Theme.onSurface,button.hovered,button.down,button.visualFocus); border.width: button.visualFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.primary }
    opacity: enabled ? 1 : Core.Theme.disabledControlOpacity
}
