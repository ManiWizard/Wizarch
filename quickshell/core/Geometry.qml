pragma Singleton
import QtQuick
import "Geometry.js" as Model

GeometryContext {
    id: geometry
    property var uiScaleByOutput: ({})
    function scaleForOutput(name) { return Model.outputScale(uiScaleByOutput, name); }
    function contextFor(item) {
        var current = item;
        while (current) {
            if (current.uiGeometry !== undefined && current.uiGeometry !== null) return current.uiGeometry;
            current = current.parent;
        }
        return geometry;
    }
}
