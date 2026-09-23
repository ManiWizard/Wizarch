pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
Item {
 id: picker
 required property var panel
 Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Wizarch themes"; color: Core.Theme.textPrimary; font.pixelSize: 15 }
 ListView {
  y: 32; width: parent.width; height: 122; spacing: 8; orientation: ListView.Horizontal; clip: true
  model: Core.Theme.catalog
  delegate: Rectangle {
   required property var modelData
   width: 158; height: 120; radius: 9
   color: mouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainer
   border.width: 1; border.color: modelData.id === Core.Theme.selectedId ? Core.Theme.primary : Core.Theme.outlineVariant
   Image { x: 6; y: 6; width: 146; height: 43; source: modelData.wallpaper; fillMode: Image.PreserveAspectCrop; clip: true; asynchronous: true }
   Text { x: 9; y: 55; width: 140; text: modelData.name + (modelData.id === Core.Theme.selectedId ? "  ✓" : ""); color: Core.Theme.textPrimary; font.pixelSize: 11 }
   Text { x: 9; y: 75; width: 140; height: 36; text: modelData.description; color: Core.Theme.textSecondary; font.pixelSize: 9; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
   MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: !Core.Theme.applying; onClicked: { picker.panel.activity(); Core.Theme.apply(parent.modelData.id); } }
  }
 }
 Text { y: 158; width: parent.width; text: Core.Theme.errorMessage; color: Core.Theme.error; font.pixelSize: 9; elide: Text.ElideRight }
}
