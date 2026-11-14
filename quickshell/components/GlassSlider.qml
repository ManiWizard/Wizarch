pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../core" as Core

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: control
    property string unit: "%"
    property string label: ""
    property string icon: "sound"
    property real level: 0
    property real minimum: 0
    property real maximum: 100
    property bool available: true
    signal edited(real value)
    height: uiGeometry.controlHeight("glassSlider", slider.y + slider.height)
    opacity: available ? 1 : 0.55

    Glyph { x: 0; y: uiGeometry.metric("glassIconY"); width: uiGeometry.metric("glassIcon"); height: width; name: control.icon }
    Text { id: labelText; x: uiGeometry.metric("glassLabelX"); y: 0; text: control.label; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.metric("fontGlass") }
    Text { anchors.right: parent.right; y: 0; text: control.available ? Math.round(slider.value) + control.unit : "Unavailable"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.metric("fontGlass") }
    Slider {
        id: slider; x: 0; y: Math.max(uiGeometry.metric("glassSliderY"), labelText.implicitHeight + uiGeometry.metric("contentGap")); width: parent.width; height: uiGeometry.controlHeight("glassSliderTrack", uiGeometry.metric("sliderHandle"))
        from: control.minimum; to: control.maximum; stepSize: 1
        enabled: control.available
        Accessible.name: control.label
        Accessible.description: control.available ? Math.round(value) + (control.unit === "%" ? " percent" : " pixels") : "Unavailable"
        Binding { target: slider; property: "value"; value: control.level; when: !slider.pressed }
        onMoved: control.edited(value)
        background: Rectangle {
            x: slider.leftPadding; y: slider.topPadding + (slider.availableHeight - height) / 2
            width: Math.max(0, slider.availableWidth); height: uiGeometry.metric("quickTrack"); radius: uiGeometry.radius("control", width, height); color: Core.Theme.surfaceContainerHighest
            Rectangle { width: Math.max(0, slider.visualPosition * parent.width); height: parent.height; radius: uiGeometry.radius("control", width, height); color: Core.Theme.primary }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * Math.max(0, slider.availableWidth - width)
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: uiGeometry.fit(uiGeometry.metric("sliderHandle"), slider.availableWidth); height: uiGeometry.metric("sliderHandle"); radius: uiGeometry.radius("control", width, height); color: Core.Theme.primary
            border.width: slider.activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.textPrimary
        }
    }
}
