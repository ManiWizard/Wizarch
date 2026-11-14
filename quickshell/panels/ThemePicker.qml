pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

 id: picker
 required property var panel
 readonly property real contentHeight: 208
 Rectangle {
  width: 30; height: 28; radius: uiGeometry.radius("control", width, height); color: backMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
  border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
  activeFocusOnTab: true
  Accessible.role: Accessible.Button; Accessible.name: "Back to settings"
  Accessible.onPressAction: picker.panel.toggle("settings")
  Keys.onReturnPressed: picker.panel.toggle("settings")
  Keys.onSpacePressed: picker.panel.toggle("settings")
  Text { anchors.centerIn: parent; text: "‹"; color: Core.Theme.textPrimary; font.pixelSize: 23 }
  MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: picker.panel.toggle("settings") }
 }
 Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Wizarch themes"; color: Core.Theme.textPrimary; font.pixelSize: 15 }
 ListView {
  y: 32; width: parent.width; height: 122; spacing: 8; orientation: ListView.Horizontal; clip: true
  model: Core.Theme.catalog
  delegate: Rectangle {
   id: themeCard
   required property var modelData
   width: 158; height: 120; radius: uiGeometry.radius("button", width, height)
   color: mouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainer
   border.width: activeFocus ? 2 : 1; border.color: modelData.identity === Core.Theme.selectedIdentity || activeFocus ? Core.Theme.primary : Core.Theme.outlineVariant
   activeFocusOnTab: !Core.Theme.applying && modelData.valid
   Accessible.role: Accessible.Button
   Accessible.name: modelData.name + (modelData.identity === Core.Theme.selectedIdentity ? ", selected" : "")
   Accessible.description: modelData.description
   Accessible.onPressAction: themeCard.activate()
   Keys.onReturnPressed: themeCard.activate()
   Keys.onSpacePressed: themeCard.activate()
   function activate() { if (!Core.Theme.applying && modelData.valid) Core.Theme.apply(modelData.identity); }
   Image { x: 6; y: 6; width: 146; height: 43; source: themeCard.modelData.wallpaper; fillMode: Image.PreserveAspectCrop; clip: true; asynchronous: true; sourceSize: Qt.size(146,43); cache: false }
   Text { x: 9; y: 55; width: 140; textFormat: Text.PlainText; text: themeCard.modelData.name + (themeCard.modelData.identity === Core.Theme.selectedIdentity ? "  ✓" : ""); color: Core.Theme.textPrimary; font.pixelSize: 11 }
   Text { x: 9; y: 75; width: 140; height: 36; textFormat: Text.PlainText; text: themeCard.modelData.description; color: Core.Theme.textSecondary; font.pixelSize: 10; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
   MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: !Core.Theme.applying && themeCard.modelData.valid; cursorShape: Qt.PointingHandCursor; onClicked: themeCard.activate() }
  }
 }
 Text { y: 158; width: parent.width; textFormat: Text.PlainText; text: Core.Theme.errorMessage; color: Core.Theme.error; font.pixelSize: 9; elide: Text.ElideRight }
}
