pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: card
    required property var theme
    readonly property var previewColors: theme.valid === false ? Core.Theme.palette : theme.colors || Core.Theme.palette
    property bool selected: false
    property bool wallpaperOnly: false
    signal activated()
    implicitHeight: wallpaperOnly ? 175 : 252
    activeFocusOnTab: !Core.Theme.applying && theme.valid !== false
    Accessible.role: Accessible.Button
    Accessible.name: theme.name + (theme.valid === false ? ", unavailable" : "") + (selected ? ", selected" : "")
    Accessible.description: theme.valid === false ? theme.diagnostics.join("; ") : wallpaperOnly ? "Preview wallpaper independently" : theme.description
    Accessible.onPressAction: card.activated()
    Keys.onReturnPressed: card.activated()
    Keys.onSpacePressed: card.activated()
    Rectangle {
        id: preview; x: 4; y: 4; width: parent.width - 8; height: card.wallpaperOnly ? 125 : 182
        radius: uiGeometry.radius("softCard", width, height); color: card.previewColors.surfaceContainer || Core.Theme.surfaceContainer
        border.width: card.selected || card.activeFocus ? 3 : 1
        border.color: card.selected || card.activeFocus ? Core.Theme.primary : Core.Theme.outlineVariant
        Image { x: 6; y: 6; width: parent.width - 12; height: parent.height - 12; source: card.theme.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize: Qt.size(Math.ceil(width),Math.ceil(height)); clip: true }
        Rectangle {
            visible: !card.wallpaperOnly && card.theme.valid !== false; x: parent.width * 0.4; y: 32; width: parent.width * 0.43; height: 84; radius: uiGeometry.radius("header", width, height)
            color: card.previewColors.surfaceContainerHigh
        }
        Rectangle {
            visible: !card.wallpaperOnly && card.theme.valid !== false; x: parent.width * 0.17; y: 70; width: parent.width * 0.48; height: 83; radius: uiGeometry.radius("header", width, height)
            color: card.previewColors.surface
            Rectangle { x: 0; y: 0; width: parent.width; height: 18; radius: uiGeometry.radius("header", width, height); color: card.previewColors.surfaceContainerHighest }
            Rectangle { x: 10; y: 33; width: parent.width * 0.6; height: 5; radius: uiGeometry.radius("previewLine", width, height); color: card.previewColors.outlineVariant }
            Rectangle { x: 10; y: 47; width: parent.width * 0.4; height: 5; radius: uiGeometry.radius("previewLine", width, height); color: card.previewColors.primary }
        }
        Rectangle {
            visible: card.selected; x: parent.width - 32; y: parent.height - 32; width: 24; height: 24; radius: uiGeometry.radius("control", width, height); color: Core.Theme.primary
            Text { anchors.centerIn: parent; text: "✓"; color: Core.Theme.onPrimary; font.pixelSize: 15 }
        }
    }
    Text { y: preview.height + 14; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: card.theme.name; textFormat: Text.PlainText; color: Core.Theme.textPrimary; font.pixelSize: 15; font.weight: Font.Medium }
    Text { visible: !card.wallpaperOnly; y: preview.height + 39; width: parent.width - 8; x: 4; textFormat: Text.PlainText; text: card.theme.valid === false ? card.theme.diagnostics.join("; ") : card.theme.description; color: Core.Theme.textSecondary; font.pixelSize: 11; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; maximumLineCount: 2; elide: Text.ElideRight }
    MouseArea { anchors.fill: parent; enabled: !Core.Theme.applying && card.theme.valid !== false; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.activated() }
}
