pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
Column {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: section
    property string title: ""
    property string description: ""
    property real padding: uiGeometry.metric("sectionPadding")
    default property alias content: body.data
    spacing: uiGeometry.metric("sectionGap")
    Text { visible: section.title !== ""; width: parent.width; text: section.title; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.metric("fontSectionTitle"); font.weight: Font.DemiBold }
    Text { visible: section.description !== ""; width: parent.width; text: section.description; wrapMode: Text.Wrap; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.metric("fontBody"); lineHeight: 1.2 }
    Rectangle {
        width: parent.width; height: body.implicitHeight + section.padding * 2
        radius: uiGeometry.radius("section", width, height); color: Core.Theme.surfaceContainerHigh
        Column { id: body; x: section.padding; y: section.padding; width: Math.max(0, parent.width - section.padding * 2); spacing: uiGeometry.metric("contentGap") }
    }
}
