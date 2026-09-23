pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
import "../components"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.Mpris

Item {
            id: launcherContent
    required property var root
    required property var panel
    property alias searchText: search.text
    readonly property var selectedEntry: apps.model[apps.currentIndex]
    function focusSearch() { search.forceActiveFocus(); }
            visible: panel.shownSection === "launcher" && opacity > 0
            opacity: panel.contentAlpha; enabled: !panel.busy
            Rectangle {
                width: parent.width; height: 36; radius: 10
                color: Core.Theme.hoverSurface; border.width: 1; border.color: search.activeFocus ? Qt.alpha(Core.Theme.surfaceContainerHighest, 0.4) : Qt.alpha(Core.Theme.surfaceContainerHighest, 0.125)
                Glyph { x: 11; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; name: "search" }
                TextInput {
                    id: search; x: 37; y: 9; width: parent.width - 50; height: 20
                    color: Core.Theme.textPrimary; font.family: "Noto Sans"; font.pixelSize: 11; clip: true; selectByMouse: true
                    Accessible.name: "Search installed applications"
                    Text { text: "Search your apps"; color: Core.Theme.textSecondary; font: parent.font; visible: !search.text && !search.preeditText }
                    Keys.onDownPressed: apps.currentIndex = Math.min(apps.count - 1, apps.currentIndex + 5)
                    Keys.onUpPressed: apps.currentIndex = Math.max(0, apps.currentIndex - 5)
                    Keys.onTabPressed: apps.forceActiveFocus()
                    Keys.onReturnPressed: panel.launchCurrentApp()
                }
            }
            GridView {
                id: apps; y: 52; width: parent.width; height: 228; clip: true
                cellWidth: width / 5; cellHeight: 76
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: true; activeFocusOnTab: true
                model: root.sortedApps.filter(e => (e.name + " " + e.genericName).toLowerCase().includes(search.text.toLowerCase()))
                onModelChanged: currentIndex = count ? 0 : -1
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                Keys.onReturnPressed: panel.launchCurrentApp()
                Keys.onEscapePressed: search.forceActiveFocus()
                delegate: Item {
                    id: appCell; required property var modelData
    required property int index
                    width: apps.cellWidth; height: apps.cellHeight
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 2; radius: 10
                        color: appMouse.containsMouse || (apps.currentIndex === appCell.index && (apps.activeFocus || search.text.length > 0)) ? Core.Theme.hoverSurface : "transparent"
                        border.width: apps.activeFocus && apps.currentIndex === appCell.index ? 1 : 0; border.color: Qt.alpha(Core.Theme.surfaceContainerHighest, 0.467)
                    }
                    Image {
                        id: appIcon; anchors.horizontalCenter: parent.horizontalCenter; y: 9; width: 30; height: 30
                        source: Quickshell.iconPath(appCell.modelData.icon, true)
                        sourceSize: Qt.size(60,60); fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 9; width: 30; height: 30; radius: 9
                        color: Core.Theme.surfaceContainerHighest; visible: !appIcon.visible
                        Text { anchors.centerIn: parent; text: appCell.modelData.name.slice(0,1).toUpperCase(); color: Core.Theme.textPrimary; font.pixelSize: 15 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 46; width: parent.width - 5; height: 28
                        text: appCell.modelData.name; horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                        color: Core.Theme.textPrimary; font.family: "Noto Sans"; font.pixelSize: 9
                    }
                    Accessible.role: Accessible.Button; Accessible.name: appCell.modelData.name
                    MouseArea { id: appMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { apps.currentIndex = appCell.index; panel.launchCurrentApp(); } }
                }
                Text { anchors.centerIn: parent; visible: apps.count === 0; text: "No matching apps"; color: Core.Theme.textSecondary; font.pixelSize: 11 }
            }
        }
