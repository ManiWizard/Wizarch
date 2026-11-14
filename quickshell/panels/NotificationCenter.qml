pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
import "../components"

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: center
    required property var root
    required property var panel
    readonly property real contentHeight: Math.min(530, root.notifications.length ? 76 + root.notifications.reduce((height, item) => height + (item.body ? 88 : 66), 0) + Math.max(0, root.notifications.length - 1) * 8 : 202)
    visible: panel.shownSection === "notifications" && opacity > 0
    opacity: panel.contentAlpha
    enabled: !panel.busy

    Item {
        width: parent.width; height: 30
        Text {
            anchors.centerIn: parent
            text: "Notifications"; color: Core.Theme.textPrimary
            font.pixelSize: 14; font.weight: Font.Medium
        }
        Row {
            height: parent.height; spacing: 7
            Rectangle {
                width: 30; height: 30; radius: uiGeometry.radius("control", width, height); color: Core.Theme.surfaceContainerHigh
                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                activeFocusOnTab: true
                Accessible.role: Accessible.Button; Accessible.name: "Back to quick settings"
                Accessible.onPressAction: center.panel.toggle("status")
                Keys.onReturnPressed: center.panel.toggle("status")
                Keys.onSpacePressed: center.panel.toggle("status")
                Glyph { anchors.centerIn: parent; width: 17; height: 17; name: "previous" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: center.panel.toggle("status") }
            }

        }
        Rectangle {
            visible: center.root.notifications.length > 0
            anchors.right: parent.right; width: 68; height: 30; radius: uiGeometry.radius("control", width, height)
            color: clearMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
            border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
            activeFocusOnTab: visible
            Accessible.role: Accessible.Button; Accessible.name: "Clear all notifications"
            Accessible.onPressAction: center.root.clearNotifications()
            Keys.onReturnPressed: center.root.clearNotifications()
            Keys.onSpacePressed: center.root.clearNotifications()
            Text { anchors.centerIn: parent; text: "Clear all"; color: Core.Theme.textPrimary; font.pixelSize: 10 }
            MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: center.root.clearNotifications() }
        }
    }

    Rectangle {
        visible: center.root.notifications.length === 0
        x: 0; y: 40; width: parent.width; height: 126; radius: uiGeometry.radius("softCard", width, height)
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
            id: notificationCard
            required property var modelData
            width: list.width; height: modelData.body ? 88 : 66; radius: uiGeometry.radius("softCard", width, height)
            color: Core.Theme.surfaceContainer
            readonly property bool urgent: modelData.urgency === 2
            border.width: urgent ? 1 : 0; border.color: Core.Theme.error
            Glyph { x: 12; y: 14; width: 20; height: 20; name: "notifications"; ink: notificationCard.urgent ? Core.Theme.error : Core.Theme.onSurface }
            Text {
                x: 42; y: 10; width: parent.width - 85
                text: (notificationCard.urgent ? "Urgent · " : "") + (parent.modelData.appName || "App")
                color: Core.Theme.textSecondary; font.pixelSize: 10; elide: Text.ElideRight
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
                font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Rectangle {
                id: dismissButton
                x: parent.width - 34; y: 10; width: 24; height: 24; radius: uiGeometry.radius("control", width, height)
                color: dismissMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Dismiss " + (notificationCard.modelData.appName || "notification") + ": " + notificationCard.modelData.summary
                Accessible.onPressAction: notificationCard.modelData.dismiss()
                Keys.onReturnPressed: notificationCard.modelData.dismiss()
                Keys.onSpacePressed: notificationCard.modelData.dismiss()
                Glyph { anchors.centerIn: parent; width: 12; height: 12; name: "close" }
                MouseArea { id: dismissMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: notificationCard.modelData.dismiss() }
            }
        }
    }
}
