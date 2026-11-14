import QtQuick
import "../core" as Core
Rectangle {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: tile
    property string label: ""
    property string detail: ""
    property string icon: "apps"
    property bool active: false
    property bool available: true
    property bool wide: false
    signal triggered()
    implicitHeight: uiGeometry.controlHeight("tile", Math.max(tileIcon.y + tileIcon.height, tileLabel.y + tileLabel.implicitHeight, tile.wide ? tileDetail.y + tileDetail.implicitHeight : 0))
    radius: uiGeometry.radius("tile", width, height)
    color: Core.Theme.stateColor(active ? Core.Theme.secondaryContainer : Core.Theme.surfaceContainer, active ? Core.Theme.onSecondaryContainer : Core.Theme.onSurface, mouse.containsMouse && available, mouse.pressed, activeFocus)
    border.width: uiGeometry.stroke()
    border.color: active && available && (activeFocus || mouse.containsMouse) ? Core.Theme.onSecondaryContainer : activeFocus ? Core.Theme.primary : mouse.containsMouse && available ? Core.Theme.outline : Core.Theme.outlineVariant
    opacity: available ? 1 : Core.Theme.disabledTileOpacity
    activeFocusOnTab: available
    Accessible.role: Accessible.Button
    Accessible.name: label + ", " + detail
    Accessible.onPressAction: if (available) triggered()
    Keys.onReturnPressed: if (available) triggered()
    Keys.onSpacePressed: if (available) triggered()
    Glyph { id: tileIcon; x: tile.wide ? uiGeometry.metric("tileWideInset") : (parent.width - width) / 2; y: tile.wide ? uiGeometry.metric("tileWideIconY") : uiGeometry.metric("tileIconY"); width: uiGeometry.metric("tileIcon"); height: width; name: tile.icon; ink: tile.active ? Core.Theme.onSecondaryContainer : Core.Theme.onSurface }
    Text { id: tileLabel; x: tile.wide ? uiGeometry.metric("tileWideTextX") : uiGeometry.metric("tileTextInset"); y: tile.wide ? uiGeometry.metric("tileWideLabelY") : uiGeometry.metric("tileLabelY"); width: Math.max(0, parent.width - x - uiGeometry.metric(tile.wide ? "tileWideTextEnd" : "tileTextInset")); text: tile.label; horizontalAlignment: tile.wide ? Text.AlignLeft : Text.AlignHCenter; color: tile.active ? Core.Theme.onSecondaryContainer : Core.Theme.onSurface; font.family: "Noto Sans"; font.pixelSize: uiGeometry.metric("fontTile"); elide: Text.ElideRight }
    Text { id: tileDetail; x: uiGeometry.metric("tileWideTextX"); y: Math.max(uiGeometry.metric("tileDetailY"), tileLabel.y + tileLabel.implicitHeight); width: Math.max(0, parent.width - uiGeometry.metric("tileDetailEnd")); visible: tile.wide; text: tile.detail; color: tile.active ? Core.Theme.onSecondaryContainer : mouse.containsMouse ? Core.Theme.onSurface : Core.Theme.onSurfaceVariant; font.family: "Noto Sans"; font.pixelSize: uiGeometry.metric("fontDetail"); elide: Text.ElideRight }
    MouseArea { id: mouse; anchors.fill: parent; enabled: tile.available; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.triggered() }
    Behavior on color { enabled: !Core.Theme.publishing; ColorAnimation { duration: 120 } }
}
