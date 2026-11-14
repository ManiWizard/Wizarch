pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../core" as Core
Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: row
    property string accessibleName: ""
    property string icon: "music"
    property real minimum: 0
    property real maximum: 100
    property real level: 0
    property bool available: true
    property string actionName: ""
    property string actionDescription: ""
    property string actionIcon: "sound"
    property bool actionAvailable: true
    property bool actionCheckable: false
    property bool actionActive: false
    property color controlSurface: Core.Theme.surfaceContainerHigh
    readonly property bool valueVisible: available && ((slider.hoverEnabled && slider.hovered) || slider.pressed || keyboardReveal.running)
    signal edited(real value)
    signal actionTriggered()
    height: uiGeometry.controlHeight("quickSlider", uiGeometry.metric("icon"))
    Slider {
        id: slider; objectName: "levelSlider"
        width: Math.max(0, parent.width - action.width - uiGeometry.metric("quickSliderGap")); height: row.height
        padding: 0; hoverEnabled: true
        from: row.minimum; to: row.maximum; stepSize: 1; enabled: row.available
        opacity: enabled ? 1 : Core.Theme.disabledTileOpacity
        Accessible.name: row.accessibleName
        Accessible.description: row.available ? Math.round(value) + " percent" : "Unavailable"
        Binding { target: slider; property: "value"; value: row.level; when: !slider.pressed }
        onMoved: {
            row.edited(value);
            if (!pressed && activeFocus) keyboardReveal.restart();
        }
        onActiveFocusChanged: if (!activeFocus) keyboardReveal.stop()
        background: Rectangle {
            objectName: "sliderSurface"
            width: slider.width; height: slider.height; radius: uiGeometry.radius("control", width, height)
            color: Core.Theme.stateColor(row.controlSurface, Core.Theme.onSurface, slider.hovered, slider.pressed, slider.activeFocus)
            border.width: slider.activeFocus ? uiGeometry.stroke() : 0; border.color: Core.Theme.primary
            Rectangle {
                width: Math.max(0, slider.position * parent.width); height: parent.height; radius: uiGeometry.radius("control", width, height)
                color: Core.Theme.primaryContainer
            }
            // The rounded surface retains full-width level mapping and native input.
            Glyph { x: uiGeometry.metric("iconGap"); anchors.verticalCenter: parent.verticalCenter; width: uiGeometry.metric("icon"); height: width; name: row.icon; ink: slider.position * slider.width >= x+width ? Core.Theme.onPrimaryContainer : Core.Theme.onSurface }
            Text {
                objectName: "sliderValue"
                visible: row.valueVisible
                anchors.right: parent.right; anchors.rightMargin: uiGeometry.metric("iconGap"); anchors.verticalCenter: parent.verticalCenter
                text: Math.round(slider.value) + "%"; font.pixelSize: uiGeometry.metric("fontValue")
                color: slider.position * slider.width >= x+width ? Core.Theme.onPrimaryContainer : Core.Theme.onSurface
                Accessible.ignored: true
            }
        }
        // Keep Slider's native full-area pointer, drag and keyboard behavior without a visible thumb.
        handle: Item { width: 0; height: 0 }
        ThemedToolTip { visible: !row.available && unavailableHover.hovered; text: row.accessibleName + " unavailable" }
        HoverHandler { id: unavailableHover }
    }
    Timer { id: keyboardReveal; interval: 1400 }
    Rectangle {
        id: action; objectName: "sliderAction"
        readonly property color ink: row.actionActive ? Core.Theme.onPrimaryContainer : Core.Theme.onSurface
        anchors.right: parent.right; width: uiGeometry.fit(slider.height, row.width); height: slider.height; radius: uiGeometry.radius("control", width, height)
        color: Core.Theme.stateColor(row.actionActive ? Core.Theme.primaryContainer : row.controlSurface, ink, pointer.containsMouse, pointer.pressed, activeFocus)
        opacity: row.actionAvailable ? 1 : Core.Theme.disabledControlOpacity
        border.width: activeFocus ? uiGeometry.stroke() : 0; border.color: Core.Theme.primary
        enabled: row.actionAvailable
        activeFocusOnTab: row.actionAvailable
        Accessible.role: Accessible.Button; Accessible.name: row.actionName; Accessible.description: row.actionDescription
        Accessible.checkable: row.actionCheckable; Accessible.checked: row.actionCheckable && row.actionActive
        function activate() { if (row.actionAvailable) row.actionTriggered(); }
        Accessible.onPressAction: activate()
        Keys.onReturnPressed: activate(); Keys.onSpacePressed: activate()
        Glyph { anchors.centerIn: parent; width: uiGeometry.metric("icon"); height: width; name: row.actionIcon; ink: action.ink }
        MouseArea { id: pointer; anchors.fill: parent; enabled: row.actionAvailable; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: action.activate() }
        ThemedToolTip { visible: pointer.containsMouse; text: row.actionName + (row.actionDescription ? " · " + row.actionDescription : "") }
    }
}
