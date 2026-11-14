pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
Rectangle {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: card
    property string label: ""
    property string icon: "power"
    property bool available: true
    property bool destructive: false
    signal triggered()
    readonly property color ink: destructive ? Core.Theme.onErrorContainer : Core.Theme.onSurface
    implicitHeight: uiGeometry.controlHeight("action", actionIcon.height + Math.max(uiGeometry.metric("actionLabelHeight"), actionLabel.implicitHeight) + uiGeometry.metric("actionMinInset") + uiGeometry.metric("actionLabelBottom") - uiGeometry.metric("actionLabelHeight"))
    radius: uiGeometry.radius("action", width, height)
    color: Core.Theme.stateColor(destructive ? Core.Theme.errorContainer : Core.Theme.surfaceContainer, ink, pointer.containsMouse, pointer.pressed, activeFocus)
    opacity: available ? 1 : Core.Theme.disabledTileOpacity
    border.width: activeFocus ? uiGeometry.stroke() : 0; border.color: Core.Theme.primary
    enabled: available
    activeFocusOnTab: available
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: available ? "" : "Unavailable on this system"
    Accessible.ignored: !visible
    function activate() { if (available) triggered(); }
    Accessible.onPressAction: activate()
    Keys.onReturnPressed: activate()
    Keys.onSpacePressed: activate()
    Glyph { id: actionIcon; anchors.horizontalCenter: parent.horizontalCenter; y: Math.max(uiGeometry.metric("actionMinInset"), (card.height - uiGeometry.metric("actionContent")) / 2); width: uiGeometry.metric("actionIcon"); height: width; name: card.icon; ink: card.ink }
    Text { id: actionLabel; x: uiGeometry.metric("actionTextInset"); y: Math.max(actionIcon.y + actionIcon.height, parent.height - Math.max(uiGeometry.metric("actionLabelBottom"), implicitHeight)); width: Math.max(0, parent.width - 2 * x); height: Math.max(uiGeometry.metric("actionLabelHeight"), implicitHeight); text: card.label; color: card.ink; font.pixelSize: uiGeometry.metric("fontAction"); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; wrapMode: Text.WordWrap }
    MouseArea { id: pointer; anchors.fill: parent; enabled: card.available; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.activate() }
    ThemedToolTip { visible: pointer.containsMouse; text: card.label }
}
