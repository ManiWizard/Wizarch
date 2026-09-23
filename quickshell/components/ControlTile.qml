import QtQuick
import "../core" as Core
Rectangle {
    id: tile
    property string label: ""
    property string detail: ""
    property string icon: "apps"
    property bool active: false
    property bool available: true
    property bool wide: false
    signal triggered()
    radius: 12
    color: mouse.containsMouse && available ? (active ? Core.Theme.hoverActiveSurface : Core.Theme.hoverSurface) : active ? Core.Theme.secondaryContainer : Core.Theme.surfaceContainer
    border.width: 1
    border.color: activeFocus ? Core.Theme.primary : mouse.containsMouse && available ? Core.Theme.outline : Core.Theme.outlineVariant
    opacity: available ? 1 : 0.55
    activeFocusOnTab: available
    Accessible.role: Accessible.Button
    Accessible.name: label + ", " + detail
    Accessible.onPressAction: if (available) triggered()
    Keys.onReturnPressed: if (available) triggered()
    Keys.onSpacePressed: if (available) triggered()
    Glyph { x: tile.wide ? 12 : (parent.width - width) / 2; y: tile.wide ? 17 : 11; width: 21; height: 21; name: tile.icon }
    Text { x: tile.wide ? 44 : 3; y: tile.wide ? 12 : 38; width: parent.width - x - (tile.wide ? 8 : 3); text: tile.label; horizontalAlignment: tile.wide ? Text.AlignLeft : Text.AlignHCenter; color: Core.Theme.textPrimary; font.family: "Noto Sans"; font.pixelSize: 11; elide: Text.ElideRight }
    Text { x: 44; y: 30; width: parent.width - 52; visible: tile.wide; text: tile.detail; color: mouse.containsMouse ? Core.Theme.textPrimary : Core.Theme.textSecondary; font.family: "Noto Sans"; font.pixelSize: 9; elide: Text.ElideRight }
    MouseArea { id: mouse; anchors.fill: parent; enabled: tile.available; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.triggered() }
    Behavior on color { ColorAnimation { duration: 120 } }
}
