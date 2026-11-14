import QtQuick
import "Geometry.js" as Model

QtObject {
    id: geometry

    // Explicit upstream inputs; never bind these to rendered item dimensions.
    property real uiScale: 1
    property real referenceFontSize: 13
    property real fontSize: 13
    property real devicePixelRatio: 1

    readonly property var inputs: ({
        uiScale: geometry.uiScale,
        referenceFontSize: geometry.referenceFontSize,
        fontSize: geometry.fontSize,
        devicePixelRatio: geometry.devicePixelRatio
    })
    readonly property real lengthScale: Model.scale(inputs)
    readonly property real cubicCircleFactor: Model.cubicCircleFactor

    function dp(value) { return Model.align(value * lengthScale, inputs); }
    function metric(name) { return Model.metric(name, inputs); }
    function align(value) { return Model.align(value, inputs); }
    function constraint(name) { return Model.constraint(name); }
    function radius(role, width, height) { return Model.radius(role, width, height, inputs); }
    function proportionalRadius(role, width, height) { return Model.proportionalRadius(role, width, height, inputs); }
    function wheelOuterRadius(width, height) { return Model.wheelOuterRadius(width, height, inputs); }
    function wheelInnerRadius(outer) { return Model.wheelInnerRadius(outer, inputs); }
    function capsule(width, height) { return Model.capsule(width, height); }
    function boundedRadius(preferred, width, height) { return Model.boundedRadius(preferred, width, height); }
    function insetRadius(outer, inset, width, height) { return Model.insetRadius(outer, inset, width, height); }
    function controlHeight(role, contentHeight) { return Model.controlHeight(role, contentHeight, inputs); }
    function fit(preferred, available) { return Model.fit(preferred, available); }
    function clamp(minimum, maximum, value) { return Model.clamp(minimum, maximum, value); }
    function stroke(focused) { return Model.stroke(focused, inputs); }
}
