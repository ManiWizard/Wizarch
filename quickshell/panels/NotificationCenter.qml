pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
import "../components"

Item {
    id: center
    required property var root
    required property var panel
    visible: panel.shownSection === "notifications" && opacity > 0
    opacity: panel.contentAlpha
    enabled: !panel.busy

    Item {
        width: parent.width; height: 30
        Row {
            height: parent.height; spacing: 7
            Rectangle {
                width: 30; height: 30; radius: 15; color: Core.Theme.surfaceContainerHigh
                Glyph { anchors.centerIn: parent; width: 17; height: 17; name: "settings" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: center.panel.toggle("status") }
            }
            Rectangle {
                width: 30; height: 30; radius: 15; color: Core.Theme.secondaryContainer
                Glyph { anchors.centerIn: parent; width: 17; height: 17; name: "notifications" }
            }
        }
        Rectangle {
            visible: center.root.notifications.length > 0
            anchors.right: parent.right; width: 68; height: 30; radius: 15
            color: clearMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
            Text { anchors.centerIn: parent; text: "Clear all"; color: Core.Theme.textPrimary; font.pixelSize: 10 }
            MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { center.root.clearNotifications(); center.panel.activity(); } }
        }
    }

    Rectangle {
        visible: center.root.notifications.length === 0
        x: 0; y: 40; width: parent.width; height: 126; radius: 14
        color: Core.Theme.surfaceContainer
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; y: 29; width: 27; height: 27; name: "notifications"; opacity: 0.65 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 74; text: "No notifications"; color: Core.Theme.textSecondary; font.pixelSize: 12 }
    }

    ListView {
        id: list
        visible: center.root.notifications.length > 0
        x: 0; y: 40; width: parent.width; height: parent.height - 40
        clip: true; spacing: 8
        model: center.root.notifications
        delegate: Rectangle {
            required property var modelData
            width: list.width; height: modelData.body ? 88 : 66; radius: 14
            color: Core.Theme.surfaceContainer
            Glyph { x: 12; y: 14; width: 20; height: 20; name: "notifications" }
            Text {
                x: 42; y: 10; width: parent.width - 85
                text: parent.modelData.appName || "App"
                color: Core.Theme.textSecondary; font.pixelSize: 9; elide: Text.ElideRight
            }
            Text {
                x: 42; y: 27; width: parent.width - 85
                text: parent.modelData.summary
                color: Core.Theme.textPrimary; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideRight
            }
            Text {
                visible: parent.modelData.body.length > 0
                x: 42; y: 48; width: parent.width - 57
                text: parent.modelData.body
                textFormat: Text.PlainText; color: Core.Theme.textSecondary
                font.pixelSize: 10; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Rectangle {
                x: parent.width - 34; y: 10; width: 24; height: 24; radius: 12
                color: dismissMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                Glyph { anchors.centerIn: parent; width: 12; height: 12; name: "close" }
                MouseArea { id: dismissMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { parent.parent.modelData.dismiss(); center.panel.activity(); } }
            }
        }
    }
}
