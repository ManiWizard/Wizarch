import QtQuick
import "../core" as Core
import QtQuick.Controls
Item {
    id: control
    property string label: ""
    property string icon: "sound"
    property real level: 0
    property real minimum: 0
    property real maximum: 100
    property bool available: true
    signal edited(real value)
    height: 58
    opacity: available ? 1 : 0.5
    Glyph { x: 0; y: 0; width: 17; height: 17; name: control.icon }
    Text { x: 26; y: 0; text: control.label; color: Core.Theme.textPrimary; font.family: "Noto Sans"; font.pixelSize: 11 }
    Text { anchors.right: parent.right; text: control.available ? Math.round(slider.value) + "%" : "Unavailable"; color: Core.Theme.textPrimary; font.family: "Noto Sans"; font.pixelSize: 10 }
    Slider {
        id: slider; x: 0; y: 23; width: parent.width; height: 25
        from: control.minimum; to: control.maximum; stepSize: 1
        value: control.level
        enabled: control.available
        Accessible.name: control.label
        onMoved: control.edited(value)
        background: Rectangle {
            x: slider.leftPadding; y: slider.topPadding + (slider.availableHeight - height) / 2
            width: slider.availableWidth; height: 20; radius: 7; color: Qt.alpha(Core.Theme.surfaceContainerHighest, 0.141)
            Rectangle { width: Math.max(14, slider.visualPosition * parent.width); height: parent.height; radius: 7; color: Core.Theme.textSecondary }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: 14; height: 24; radius: 5; color: Core.Theme.textPrimary
            border.width: slider.activeFocus ? 2 : 0; border.color: Core.Theme.outline
        }
    }
}
