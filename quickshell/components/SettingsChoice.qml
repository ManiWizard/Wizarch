import QtQuick
import QtQuick.Controls
import "../core" as Core
ComboBox {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: choice
    implicitHeight: uiGeometry.controlHeight("choice", contentItem.implicitHeight + 2 * uiGeometry.metric("buttonVerticalPadding")); font.pixelSize: uiGeometry.metric("fontBody")
    leftPadding: uiGeometry.metric("choiceInset"); rightPadding: uiGeometry.metric("choiceIndicatorInset")
    palette.buttonText: Core.Theme.textPrimary
    palette.text: Core.Theme.textPrimary
    palette.window: Core.Theme.surfaceContainerHighest
    palette.base: Core.Theme.surfaceContainerHighest
    palette.highlight: Core.Theme.primaryContainer
    palette.highlightedText: Core.Theme.textOnPrimaryContainer
    contentItem: Text { text: choice.displayText; font: choice.font; color: Core.Theme.textPrimary; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    background: Rectangle { radius: uiGeometry.radius("button", width, height); color: Core.Theme.surfaceContainerHighest; border.width: uiGeometry.stroke(choice.activeFocus); border.color: choice.activeFocus ? Core.Theme.primary : Core.Theme.outlineVariant }
    indicator: Text { x: Math.max(0, choice.width - uiGeometry.metric("choiceArrowInset")); y: (choice.height - height) / 2; text: "⌄"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.metric("fontArrow") }
    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: choice.width
        text: modelData; highlighted: choice.highlightedIndex === index
        contentItem: Text { text: parent.text; font: choice.font; color: parent.highlighted ? Core.Theme.onPrimaryContainer : Core.Theme.onSurface; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { color: parent.highlighted ? Core.Theme.primaryContainer : Core.Theme.surfaceContainerHighest }
    }
    opacity: enabled ? 1 : Core.Theme.disabledControlOpacity
}
