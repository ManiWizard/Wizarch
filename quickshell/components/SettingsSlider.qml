pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../core" as Core
Column {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: control
    property string label: ""
    property string description: ""
    property string unit: "%"
    property real level: 0
    property real minimum: 0
    property real maximum: 100
    property bool available: true
    signal edited(real value)
    spacing: uiGeometry.metric("contentGap"); opacity: available ? 1 : 0.5
    Item {
        width: parent.width; height: Math.max(uiGeometry.metric("sliderHeader"), labelText.implicitHeight)
        Text { id: labelText; width: Math.max(0, parent.width - uiGeometry.metric("valueWidth")); text: control.label; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.metric("fontLabel"); wrapMode: Text.Wrap }
        Text { anchors.right: parent.right; text: control.available ? Math.round(slider.value) + control.unit : "Unavailable"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.metric("fontBody") }
    }
    Slider {
        id: slider; width: parent.width; height: uiGeometry.controlHeight("slider", uiGeometry.metric("sliderHandle")); from: control.minimum; to: control.maximum; stepSize: 1
        enabled: control.available; Accessible.name: control.label
        Accessible.description: control.description
        Binding { target: slider; property: "value"; value: control.level; when: !slider.pressed }
        onMoved: control.edited(value)
        background: Rectangle {
            x: slider.leftPadding; y: (slider.height - height) / 2; width: Math.max(0, slider.availableWidth); height: uiGeometry.metric("settingsTrack"); radius: uiGeometry.radius("control", width, height); color: Core.Theme.surfaceContainerHighest
            Rectangle { height: parent.height; radius: uiGeometry.radius("control", width, height); width: Math.max(0, slider.visualPosition * parent.width); color: Core.Theme.primary }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * Math.max(0, slider.availableWidth - width); y: (slider.height - height) / 2
            width: uiGeometry.fit(uiGeometry.metric("sliderHandle"), slider.availableWidth); height: uiGeometry.metric("sliderHandle"); radius: uiGeometry.radius("control", width, height); color: Core.Theme.primary; border.width: slider.activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.textPrimary
        }
    }
    Text { visible: control.description !== ""; width: parent.width; text: control.description; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.metric("fontDescription"); wrapMode: Text.Wrap }
}
