pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import "../core" as Core
import "../panels"

// Standard application toplevel; Hyprland manages its tiling and window controls.
FloatingWindow {
    property var uiGeometry: Core.GeometryContext { uiScale: Core.Geometry.scaleForOutput(settingsWindow.screen ? settingsWindow.screen.name : ""); devicePixelRatio: settingsWindow.devicePixelRatio }

    id: settingsWindow
    required property var root
    title: "Wizarch Settings"
    visible: root.settingsWindowOpen
    implicitWidth: uiGeometry.dp(1120)
    implicitHeight: uiGeometry.dp(800)
    minimumSize: Qt.size(uiGeometry.dp(480), uiGeometry.dp(430))
    color: Core.Theme.surfaceContainerLow
    property bool navigationCollapsed: false
    property bool searchActive: false
    readonly property bool compactNavigation: width < uiGeometry.dp(820) || navigationCollapsed
    readonly property int sidebarWidth: compactNavigation ? uiGeometry.dp(68) : uiGeometry.dp(240)
    readonly property string currentPage: root.settingsPage === "settings" || root.settingsPage === "themes" ? "appearance" : root.settingsPage
    readonly property var categories: [
        {id:"wifi",title:"Wi-Fi",icon:"wifi",keywords:"wireless networks connect password",group:0},
        {id:"network",title:"Network",icon:"desktop",keywords:"ethernet wired airplane hotspot",group:0},
        {id:"bluetooth",title:"Bluetooth",icon:"bluetooth",keywords:"devices headphones pair connect",group:0},
        {id:"displays",title:"Displays",icon:"desktop",keywords:"monitors brightness screen resolution",group:1},
        {id:"sound",title:"Sound",icon:"sound",keywords:"audio playback input microphone volume mute",group:1},
        {id:"power",title:"Power",icon:"battery",keywords:"battery saver energy",group:1},
        {id:"multitasking",title:"Multitasking",icon:"focus",keywords:"workspaces windows spacing gaps tiling scrolling",group:1},
        {id:"appearance",title:"Appearance",icon:"night",keywords:"style theme colours colors wallpaper background",group:1},
        {id:"panel",title:"Panel",icon:"settings",keywords:"pill placement connected floating auto-hide border thickness frame corners reveal",group:1},
        {id:"notifications",title:"Notifications",icon:"notifications",keywords:"alert sounds pattern disturb dnd",group:2},
        {id:"calendar",title:"Calendar",icon:"calendar",keywords:"date Gregorian Solar Hijri Persian Jalali secondary week weekday style Iranian Saturday Monday Sunday day off weekend month year local events",group:2},
        {id:"keyboard",title:"Keyboard",icon:"apps",keywords:"shortcuts keys bindings resize move monitor",group:2}
    ]
    readonly property var filteredCategories: categories.filter(item => (item.title + " " + item.keywords).toLowerCase().indexOf(searchField.text.toLowerCase().trim()) !== -1)
    readonly property string pageTitle: (categories.find(item => item.id === currentPage) || categories[7]).title
    onFilteredCategoriesChanged: {
        if (root && filteredCategories.length && !filteredCategories.some(item => item.id===currentPage)) selectPage(filteredCategories[0].id);
    }
    function selectPage(id) { if (categories.some(item => item.id === id)) root.settingsPage=id; }
    function closeSearch() { searchActive=false; searchField.clear(); searchButton.forceActiveFocus(Qt.TabFocusReason); }
    function openSearch() { searchActive=true; Qt.callLater(() => searchField.forceActiveFocus()); }
    function setSearchQuery(text) { openSearch(); searchField.text=text; }
    function closeSettings() { root.settingsWindowOpen=false; }
    onVisibleChanged: {
        if (!visible) { Core.Theme.cancelPreview(); if (root.settingsWindowOpen) root.settingsWindowOpen=false; searchActive=false; searchField.clear(); }
    }
    Shortcut { sequences: [StandardKey.Find]; enabled: settingsWindow.visible; onActivated: settingsWindow.openSearch() }
    Shortcut { sequence: "Escape"; enabled: settingsWindow.visible; onActivated: { if (settingsWindow.searchActive) { settingsWindow.closeSearch(); } else settingsWindow.closeSettings(); } }
    Rectangle {
        id: sidebar; property var uiGeometry: settingsWindow.uiGeometry; width: settingsWindow.sidebarWidth; height: parent.height; color: Core.Theme.surfaceContainer
        Rectangle { anchors.right: parent.right; width: uiGeometry.dp(1); height: parent.height; color: Qt.alpha(Core.Theme.outlineVariant,0.35) }
        SettingsButton {
            id: searchButton
            x: settingsWindow.compactNavigation ? uiGeometry.dp(15) : uiGeometry.dp(12); y: uiGeometry.dp(17); width: uiGeometry.dp(38); height: uiGeometry.dp(38)
            Accessible.name: "Search settings"; onClicked: settingsWindow.openSearch()
            Glyph { anchors.centerIn: parent; width: uiGeometry.dp(21); height: uiGeometry.dp(21); name: "search" }
            ThemedToolTip { visible: parent.hovered; text: "Search settings · Ctrl+F" }
        }
        Text { visible: !settingsWindow.compactNavigation; x: uiGeometry.dp(57); y: uiGeometry.dp(25); width: parent.width-uiGeometry.dp(108); text: "Settings"; color: Core.Theme.textPrimary; horizontalAlignment: Text.AlignHCenter; font.pixelSize: uiGeometry.dp(18); font.weight: Font.DemiBold }
        SettingsButton {
            visible: !settingsWindow.compactNavigation; x: parent.width-uiGeometry.dp(50); y: uiGeometry.dp(17); width: uiGeometry.dp(38); height: uiGeometry.dp(38); text: "☰"
            Accessible.name: "Collapse navigation"; onClicked: settingsWindow.navigationCollapsed=true
            ThemedToolTip { visible: parent.hovered; text: "Collapse navigation" }
        }
        ListView {
            id: navigation; x: uiGeometry.dp(10); y: uiGeometry.dp(82); width: parent.width-uiGeometry.dp(20); height: parent.height-y-(settingsWindow.navigationCollapsed && settingsWindow.width>=uiGeometry.dp(820) ? uiGeometry.dp(56) : uiGeometry.dp(12))
            clip: true; spacing: uiGeometry.dp(4); model: settingsWindow.filteredCategories
            ScrollBar.vertical: ThemedScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Item {
                id: entry
                required property var modelData
                required property int index
                readonly property bool separated: index>0 && modelData.group !== settingsWindow.filteredCategories[index-1].group
                width: navigation.width; height: uiGeometry.dp(48) + (separated ? uiGeometry.dp(16) : 0)
                Rectangle { visible: entry.separated; width: parent.width; height: uiGeometry.dp(1); y: uiGeometry.dp(5); color: Qt.alpha(Core.Theme.outlineVariant,0.45) }
                Rectangle {
                    id: navButton; y: entry.separated ? uiGeometry.dp(16) : 0; width: parent.width; height: uiGeometry.dp(48); radius: uiGeometry.radius("navigation", width, height)
                    color: settingsWindow.currentPage===entry.modelData.id ? Core.Theme.surfaceContainerHighest : navMouse.containsMouse ? Core.Theme.surfaceContainerHigh : "transparent"
                    border.width: activeFocus ? uiGeometry.dp(2) : 0; border.color: Core.Theme.primary
                    activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: entry.modelData.title
                    Accessible.onPressAction: settingsWindow.selectPage(entry.modelData.id)
                    Keys.onReturnPressed: settingsWindow.selectPage(entry.modelData.id)
                    Keys.onSpacePressed: settingsWindow.selectPage(entry.modelData.id)
                    Glyph { x: settingsWindow.compactNavigation ? (parent.width-width)/2 : uiGeometry.dp(14); anchors.verticalCenter: parent.verticalCenter; width: uiGeometry.dp(22); height: uiGeometry.dp(22); name: entry.modelData.icon }
                    Text { visible: !settingsWindow.compactNavigation; x: uiGeometry.dp(49); anchors.verticalCenter: parent.verticalCenter; width: parent.width-x-uiGeometry.dp(10); text: entry.modelData.title; elide: Text.ElideRight; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(15) }
                    MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsWindow.selectPage(entry.modelData.id) }
                    ThemedToolTip { visible: settingsWindow.compactNavigation && navMouse.containsMouse; text: entry.modelData.title }
                }
            }
        }
        SettingsButton {
            visible: settingsWindow.navigationCollapsed && settingsWindow.width>=uiGeometry.dp(820)
            x: uiGeometry.dp(15); y: parent.height-uiGeometry.dp(48); width: uiGeometry.dp(38); height: uiGeometry.dp(38); text: "›"
            Accessible.name: "Expand navigation"; onClicked: settingsWindow.navigationCollapsed=false
        }
    }
    Item {
        id: main; property var uiGeometry: settingsWindow.uiGeometry; x: sidebar.width; width: parent.width-x; height: parent.height
        Text { x: uiGeometry.dp(32); y: uiGeometry.dp(24); width: parent.width-uiGeometry.dp(100); horizontalAlignment: Text.AlignHCenter; text: settingsWindow.pageTitle; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(19); font.weight: Font.DemiBold }
        SettingsButton {
            x: parent.width-uiGeometry.dp(54); y: uiGeometry.dp(17); width: uiGeometry.dp(38); height: uiGeometry.dp(38)
            Accessible.name: "Close settings"; onClicked: settingsWindow.closeSettings()
            Glyph { anchors.centerIn: parent; width: uiGeometry.dp(19); height: uiGeometry.dp(19); name: "close" }
        }
        TextField { selectionColor: Core.Theme.primaryContainer; selectedTextColor: Core.Theme.onPrimaryContainer;
            id: searchField; visible: settingsWindow.searchActive
            x: uiGeometry.dp(24); y: uiGeometry.dp(72); width: parent.width-uiGeometry.dp(48); height: uiGeometry.dp(42)
            placeholderText: "Search settings"; font.pixelSize: uiGeometry.dp(14); color: Core.Theme.textPrimary; placeholderTextColor: Core.Theme.textSecondary
            Accessible.name: "Search settings"
            background: Rectangle { radius: uiGeometry.radius("navigation", width, height); color: Core.Theme.surfaceContainerHigh; border.width: searchField.activeFocus ? uiGeometry.dp(2) : 1; border.color: searchField.activeFocus ? Core.Theme.primary : Core.Theme.outlineVariant }
        }
        Rectangle {
            id: saveFailure; visible: settingsWindow.root.preferenceError !== ""
            x: uiGeometry.dp(24); y: uiGeometry.dp(72) + (settingsWindow.searchActive ? uiGeometry.dp(56) : 0); width: parent.width-uiGeometry.dp(48)
            height: Math.max(uiGeometry.dp(60),errorText.implicitHeight+uiGeometry.dp(24)); radius: uiGeometry.radius("tile", width, height); color: Core.Theme.surfaceContainerHigh; border.width: uiGeometry.dp(1); border.color: Core.Theme.error
            Text {
                id: errorText; x: uiGeometry.dp(14); y: uiGeometry.dp(12); width: parent.width-uiGeometry.dp(110); text: settingsWindow.root.preferenceError
                wrapMode: Text.Wrap; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(13); Accessible.role: Accessible.AlertMessage
            }
            SettingsButton { anchors.right: parent.right; anchors.rightMargin: uiGeometry.dp(12); anchors.verticalCenter: parent.verticalCenter; text: "Retry"; enabled: !settingsWindow.root.preferenceWriterBusy; onClicked: settingsWindow.root.retryPreferences() }
        }
        SettingsView { uiGeometry: settingsWindow.uiGeometry; owningOutput: settingsWindow.screen ? settingsWindow.screen.name : "";
            id: settingsContent; root: settingsWindow.root; page: settingsWindow.currentPage
            y: uiGeometry.dp(72) + (settingsWindow.searchActive ? uiGeometry.dp(56) : 0) + (saveFailure.visible ? saveFailure.height+uiGeometry.dp(16) : 0)
            width: parent.width; height: Math.max(0, parent.height-y)
            visible: settingsWindow.filteredCategories.length>0
        }
        Text { visible: settingsWindow.filteredCategories.length===0; anchors.centerIn: parent; text: "No settings found"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(16) }
    }
}
