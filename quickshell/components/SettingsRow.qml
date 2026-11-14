pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: row
    property string label: ""
    property string description: ""
    property real controlWidth: uiGeometry.metric("rowControlWidth")
    default property alias control: action.data
    implicitHeight: uiGeometry.controlHeight("row", labels.implicitHeight + 2 * uiGeometry.metric("rowPadding"))
    height: implicitHeight
    Column {
        id: labels; x: uiGeometry.metric("rowLabelInset"); anchors.verticalCenter: parent.verticalCenter
        width: uiGeometry.fit(Math.max(uiGeometry.metric("rowLabelMinimum"), parent.width - action.width - uiGeometry.metric("rowGap")), parent.width - action.width - uiGeometry.metric("rowGap")); spacing: uiGeometry.metric("labelGap")
        Text { width: parent.width; text: row.label; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.metric("fontLabel"); wrapMode: Text.Wrap }
        Text { visible: row.description !== ""; width: parent.width; text: row.description; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.metric("fontDescription"); wrapMode: Text.Wrap; lineHeight: 1.15 }
    }
    Item { id: action; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: uiGeometry.fit(row.controlWidth, parent.width * 0.48); height: parent.height }
}
