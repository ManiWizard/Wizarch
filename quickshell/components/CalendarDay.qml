pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
Rectangle {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: tile
    property string primaryText: ""
    property string secondaryText: ""
    property string accessibleLabel: ""
    property bool dayOff: false
    readonly property color dayOffInk: color.r*0.299+color.g*0.587+color.b*0.114 > 0.5 ? "#b3261e" : "#ffb4ab"
    property bool today: false
    property bool selected: false
    property bool compact: true
    property real strength: 1
    property var events: []
    signal activated()
    radius: uiGeometry.radius("navigation", width, height)
    color: selected ? Core.Theme.primaryContainer : pointer.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainer
    border.width: activeFocus || today ? 1 : 0
    border.color: Core.Theme.primary
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel + (dayOff ? ", weekly day off" : "") + (today ? ", today" : "") + (events.length ? ", " + events.length + " local events" : "")
    Accessible.onPressAction: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()
    // Fade the visual content while retaining the full, stable input target.
    opacity: pointer.containsMouse || activeFocus ? Math.max(0.72,strength) : strength
    Row {
        x: uiGeometry.dp(6); y: uiGeometry.dp(5); spacing: uiGeometry.dp(3)
        Repeater {
            model: tile.events.slice(0,2)
            Text { required property var modelData; text: modelData.icon || "●"; color: modelData.color || Core.Theme.primary; font.pixelSize: modelData.icon ? uiGeometry.dp(12) : uiGeometry.dp(9) }
        }
        Text { visible: tile.events.length>2; text: "+"+(tile.events.length-2); color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(8) }
    }
    Rectangle { visible: tile.events.length>0; width: uiGeometry.dp(4); height: uiGeometry.dp(4); radius: uiGeometry.radius("control", width, height); x: parent.width-uiGeometry.dp(8); y: uiGeometry.dp(5); color: tile.events.length ? tile.events[0].color || Core.Theme.primary : Core.Theme.primary }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: tile.height-(tile.secondaryText ? uiGeometry.dp(31) : uiGeometry.dp(22)); text: tile.primaryText; color: tile.dayOff ? tile.dayOffInk : tile.selected ? Core.Theme.textOnPrimaryContainer : Core.Theme.textPrimary; font.pixelSize: tile.compact ? uiGeometry.dp(12) : uiGeometry.dp(17); font.weight: tile.today || tile.selected ? Font.DemiBold : Font.Normal }
    Text { visible: tile.secondaryText!==""; anchors.horizontalCenter: parent.horizontalCenter; y: tile.height-uiGeometry.dp(14); text: tile.secondaryText; color: tile.dayOff ? Qt.alpha(tile.dayOffInk,0.8) : tile.selected ? Core.Theme.textOnPrimaryContainer : Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(9) }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.activated() }
}
