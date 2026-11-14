pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../core" as Core
import "LauncherModel.js" as Model
import "../components"

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: launcher
    required property var root
    required property var panel
    property alias searchText: searchInput.text
    property string activeGroup: ""
    property bool showAll: false
    property bool creatingGroup: false
    property string editingGroupName: ""
    property string newGroupType: "compact"
    property string newGroupAppId: ""
    property string pendingDeleteName: ""
    property int currentIndex: 0
    property bool contextOpen: false
    property string contextKind: ""
    property var contextApp: null
    property var contextGroup: null
    property real contextX: 0
    property real contextY: 0

    property var recentIds: []
    property var pendingRecentIds: []
    property var homeRenderKeys: []
    property point dragOffset: Qt.point(0, 0)
    property string notice: ""
    property var desktopExclusions: ({})
    property bool commandConfirmed: false
    property string feedback: ""
    property int menuIndex: 0
    property var contextReturnFocus: null
    property var dragSource: null
    property point dragPoint: Qt.point(0, 0)
    property bool dragCanceled: false
    // The pill morphs its viewport; tile placement uses the final launcher width.
    property real layoutWidth: uiGeometry.dp(384)
    property real openingProgress: 0
    readonly property real gridGap: uiGeometry.dp(10)
    readonly property real gridMinimumCellWidth: uiGeometry.dp(84)
    readonly property int gridColumns: Math.max(1, Math.min(4, Math.floor((layoutWidth + gridGap) / (gridMinimumCellWidth + gridGap))))
    readonly property real gridCellWidth: (layoutWidth - (gridColumns - 1) * gridGap) / gridColumns
    readonly property real gridCellHeight: uiGeometry.dp(98)
    readonly property bool homeMode: !creatingGroup && !activeGroup && !showAll && !searchText
    readonly property var homeLayout: Model.layout(homeEntries, gridColumns, gridCellWidth, gridCellHeight, gridGap)
    readonly property var resultsLayout: Model.layout(results.map(app => ({kind:"app", app:app})), gridColumns, gridCellWidth, gridCellHeight, gridGap)
    readonly property var recentApps: recentIds.map(id => visibleApps.find(app => app.id === id)).filter(app => !!app).slice(0, 4)
    readonly property var recentEntries: recentApps.map(app => ({kind:"app", key:"recent:"+app.id, app:app}))
    readonly property var homeSelectionEntries: homeEntries.concat(recentEntries)
    readonly property var recentLayout: Model.layout(recentEntries, gridColumns, gridCellWidth, gridCellHeight, gridGap)
    readonly property real pinsHeight: homeEntries.length ? homeLayout.height : uiGeometry.dp(28)
    readonly property real recentTop: pinsHeight + uiGeometry.dp(42)
    readonly property real totalHomeHeight: recentTop + (recentApps.length ? recentLayout.height : uiGeometry.dp(26))
    readonly property var homeSelectionSlots: homeLayout.slots.concat(recentLayout.slots.map(slot => Object.assign({},slot,{y:slot.y+recentTop})))
    readonly property int selectionCount: homeMode ? homeSelectionEntries.length : results.length
    readonly property bool searchFocus: searchInput.activeFocus
    readonly property var dropTile: {
        if (!dragSource || dragCanceled || dragPoint.x < 0 || dragPoint.x > homeScroll.width || dragPoint.y < homeScroll.contentY || dragPoint.y > homeScroll.contentY + homeScroll.height) return null;
        for (let i = 0; i < homeRepeater.count; i++) {
            const tile = homeRepeater.itemAt(i);
            if (tile && tile !== dragSource && homeLayout.slots[tile.navigationIndex] && dragPoint.x >= homeLayout.slots[tile.navigationIndex].x && dragPoint.x <= homeLayout.slots[tile.navigationIndex].x + tile.width && dragPoint.y >= homeLayout.slots[tile.navigationIndex].y && dragPoint.y <= homeLayout.slots[tile.navigationIndex].y + tile.height) return tile;
        }
        return null;
    }
    readonly property string dropIntent: dropTile ? Model.destination(dragSource.entry, dropTile.entry, dragPoint.x-homeLayout.slots[dropTile.navigationIndex].x, dragPoint.y-homeLayout.slots[dropTile.navigationIndex].y, dropTile.width, dropTile.height) : ""
    readonly property var snapPlacement: {
        if (!dragSource || !dropTile || !dropIntent) return null;
        if (dropIntent === "group") return homeLayout.slots[dropTile.navigationIndex];
        const keys = Model.reorder(homeEntries.map(entry => entry.key), dragSource.orderKey, dropTile.orderKey, dropIntent === "after");
        const entries = keys.map(key => homeEntries.find(entry => entry.key === key));
        return Model.layout(entries, gridColumns, gridCellWidth, gridCellHeight, gridGap).slots[keys.indexOf(dragSource.orderKey)];
    }
    readonly property bool commandMode: searchText.startsWith(">")
    readonly property var selectedGroup: root.preferences.appGroups.find(g => g.name === activeGroup) || null
    readonly property var visibleApps: root.sortedApps.filter(app => !app.noDisplay && !desktopExclusions[app.id] && app.name && app.command.length > 0 && root.preferences.hiddenApps.indexOf(app.id) < 0)
    readonly property var pinnedApps: Model.unique(root.preferences.pinnedApps).map(id => savedApp(id)).filter(app => !!app)
    readonly property var homeEntries: {
        const entries = root.preferences.appGroups.map(group => ({kind: "group", key: "group:" + group.name, group: group})).concat(pinnedApps.map(app => ({kind: "app", key: "app:" + app.id, app: app})));
        const order = Model.logicalOrder(root.preferences);
        return entries.sort((a, b) => order.indexOf(a.key) - order.indexOf(b.key));
    }
    readonly property var results: commandMode ? [] : (searchText ? (showAll || !selectedGroup ? visibleApps : groupApps(selectedGroup)).filter(app => (app.name + " " + (app.genericName || "") + " " + (app.keywords || []).join(" ")).toLowerCase().includes(searchText.toLowerCase())) : showAll ? visibleApps : selectedGroup ? groupApps(selectedGroup) : pinnedApps)
    readonly property var selectedEntry: homeMode ? (homeSelectionEntries[currentIndex] && homeSelectionEntries[currentIndex].app || null) : results[currentIndex] || null
    readonly property var contextEntries: contextOpen ? buildContextEntries() : []
    readonly property real contentHeight: contentColumn.implicitHeight + uiGeometry.dp(36)

    visible: panel.shownSection === "launcher" && opacity > 0
    opacity: panel.contentAlpha
    enabled: !panel.busy

    onVisibleChanged: {
        openingFade.stop();
        openingProgress = 0;
        if (visible) openingFade.start();
    }
    NumberAnimation { id: openingFade; target: launcher; property: "openingProgress"; from: 0; to: 1; duration: 340 }
    function openingOpacity(top) {
        // All items fade concurrently, with a small delay for lower rows, without moving.
        const delay = Math.min(.22, Math.max(0, top) / 1600);
        const progress = Math.max(0, Math.min(1, (openingProgress-delay)/.78));
        return 1-Math.pow(1-progress,3);
    }

    function refreshHistory() { if (!recentReader.running && !recentWriter.running) recentReader.running = true; }
    function recordRecent(app) {
        recentIds = [app.id].concat(recentIds.filter(id => id !== app.id)).slice(0,24);
        pendingRecentIds = pendingRecentIds.concat([app.id]);
        flushRecent();
    }
    function flushRecent() {
        if (recentWriter.running || !pendingRecentIds.length) return;
        const next = pendingRecentIds.slice();
        recentWriter.command = ["python3", Qt.resolvedUrl("launcher-history.py").toString().replace("file://", ""), "record", next.shift()];
        pendingRecentIds = next; recentWriter.running = true;
    }
    Process {
        id: recentReader
        command: ["python3", Qt.resolvedUrl("launcher-history.py").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { if (!launcher.pendingRecentIds.length && !recentWriter.running) launcher.recentIds = JSON.parse(text); } catch (error) {} } }
    }
    Process { id: recentWriter; onRunningChanged: if (!running) Qt.callLater(launcher.flushRecent) }
    onHomeEntriesChanged: {
        const keys = homeEntries.map(entry => entry.key);
        const next = homeRenderKeys.filter(key => keys.indexOf(key) >= 0).concat(keys.filter(key => homeRenderKeys.indexOf(key) < 0));
        if (next.join("\n") !== homeRenderKeys.join("\n")) homeRenderKeys = next;
    }
    function homeTileAt(index) {
        if (index >= homeEntries.length) return recentRepeater.itemAt(index-homeEntries.length);
        for (let i=0; i<homeRepeater.count; i++) if (homeRepeater.itemAt(i).navigationIndex === index) return homeRepeater.itemAt(i);
        return null;
    }
    Process {
        id: visibilityReader
        command: ["python3", Qt.resolvedUrl("launcher-desktop.py").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector { onStreamFinished: {
            try { launcher.desktopExclusions = JSON.parse(text); }
            catch (error) { launcher.feedback = "Desktop visibility information could not be read."; }
        } }
    }
    Connections { target: DesktopEntries; function onApplicationsChanged() { if (!visibilityReader.running) visibilityReader.running = true; } }
    onSelectionCountChanged: currentIndex = Math.max(0, Math.min(currentIndex, selectionCount - 1))
    function savedApp(id) {
        if (desktopExclusions[id] || root.preferences.hiddenApps.indexOf(id) >= 0) return null;
        const app = root.sortedApps.find(a => a.id === id) || DesktopEntries.byId(id);
        if (app && app.noDisplay) return null;
        return app && app.name && app.command.length ? app : {id:id, name:id, icon:"", command:[], unavailable:true, keywords:[]};
    }
    function closeContext() {
        contextOpen = false;
        if (contextReturnFocus && contextReturnFocus.visible) contextReturnFocus.forceActiveFocus();
        else focusSearch();
    }
    function selectIndex(index) {
        currentIndex = Math.max(0, Math.min(index, selectionCount - 1));
        if (homeMode && homeSelectionSlots[currentIndex]) {
            const slot = homeSelectionSlots[currentIndex];
            if (slot.y < homeScroll.contentY) homeScroll.contentY = slot.y;
            else if (slot.y + slot.height > homeScroll.contentY + homeScroll.height) homeScroll.contentY = slot.y + slot.height - homeScroll.height;
        } else if (searchText) searchRows.positionViewAtIndex(currentIndex, ListView.Contain);
        else if (resultsLayout.slots[currentIndex]) {
            const slot = resultsLayout.slots[currentIndex];
            appsGrid.contentY = Math.max(0, Math.min(appsGrid.contentHeight - appsGrid.height, slot.y + slot.height - appsGrid.height));
        }
    }
    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (dragSource) { dragCanceled = true; feedback = "Move canceled"; }
            else if (contextOpen) closeContext();
            else if (pendingDeleteName) { pendingDeleteName = ""; focusSearch(); }
            else if (searchText) { searchText = ""; focusSearch(); }
            else if (activeGroup || showAll || creatingGroup) goBack();
            else panel.dismiss();
        } else if (contextOpen) {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) menuIndex = (menuIndex + (event.key === Qt.Key_Down ? 1 : contextEntries.length - 1)) % contextEntries.length;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) chooseContext(contextEntries[menuIndex]);
            else if (event.key === Qt.Key_Tab) closeContext();
            else return;
            menuScroll.contentY = Math.max(0, Math.min(menuScroll.contentHeight-menuScroll.height, menuIndex*36-menuScroll.height+36));
        } else if (!creatingGroup && !commandMode && [Qt.Key_Down,Qt.Key_Up,Qt.Key_Left,Qt.Key_Right].indexOf(event.key) >= 0) {
            const direction = event.key === Qt.Key_Down ? "down" : event.key === Qt.Key_Up ? "up" : event.key === Qt.Key_Left ? "left" : "right";
            if (homeMode) selectIndex(Model.neighbor(homeSelectionSlots,currentIndex,direction));
            else if (searchText && (direction === "left" || direction === "right")) return;
            else selectIndex(currentIndex + (direction === "down" ? (searchText ? 1 : gridColumns) : direction === "up" ? (searchText ? -1 : -gridColumns) : direction === "left" ? -1 : 1));
        } else if ((event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) && !creatingGroup && !commandMode) {
            const entry = homeMode ? homeSelectionEntries[currentIndex] : selectedEntry ? {kind:"app",app:selectedEntry} : null;
            openContext(entry ? entry.kind : "empty", entry ? entry.app : null, entry ? entry.group : null, 0, 84);
        } else return;
        if (!contextOpen && !creatingGroup && !commandMode && [Qt.Key_Down,Qt.Key_Up,Qt.Key_Left,Qt.Key_Right].indexOf(event.key) >= 0 && !searchInput.activeFocus) {
            if (homeMode && homeTileAt(currentIndex)) homeTileAt(currentIndex).forceActiveFocus();
            else if (searchText) { searchRows.currentIndex = currentIndex; if (searchRows.currentItem) searchRows.currentItem.forceActiveFocus(); }
            else if (appsRepeater.itemAt(currentIndex)) appsRepeater.itemAt(currentIndex).forceActiveFocus();
        }
        event.accepted = true;
    }
    Keys.onPressed: event => handleKey(event)
    function groupType(group) { return group && (group.type === "large" || group.type === "stack") ? "large" : "compact"; }
    function groupApps(group) { return group ? Model.unique(group.apps).map(id => savedApp(id)).filter(app => !!app) : []; }
    function reset() { Qt.callLater(() => { launcher.layoutWidth = launcher.panel.targetWidth - uiGeometry.dp(36); }); searchText = ""; activeGroup = ""; showAll = false; creatingGroup = false; editingGroupName = ""; newGroupAppId = ""; pendingDeleteName = ""; contextOpen = false; commandConfirmed = false; feedback = ""; notice = ""; dragSource = null; currentIndex = 0; refreshHistory(); }
    function focusSearch() { searchInput.forceActiveFocus(); }
    function openGroup(group) { activeGroup = group.name; showAll = false; searchText = ""; currentIndex = 0; contextOpen = false; focusSearch(); }
    function goBack() {
        if (creatingGroup) { creatingGroup = false; editingGroupName = ""; }
        else if (showAll) showAll = false;
        else activeGroup = "";
        searchText = ""; currentIndex = 0; contextOpen = false; pendingDeleteName = ""; focusSearch();
    }
    function launchApp(app) {
        if (!app) return;
        if (app.unavailable) { feedback = app.name + " is unavailable. Its saved place is retained."; notice = app.name + " is unavailable"; return; }
        Core.Theme.launchApplication(app);
        recordRecent(app);
        panel.dismiss();
    }
    function runSelected() {
        if (commandMode) {
            const route = Model.commandRoute(searchText, commandConfirmed);
            if (route.action === "confirm") commandConfirmed = true;
            else if (route.action === "execute") { Quickshell.execDetached(["sh", "-c", route.command]); panel.dismiss(); }
        } else if (homeMode) {
            const entry = homeSelectionEntries[currentIndex];
            if (entry) { if (entry.kind === "group") openGroup(entry.group); else launchApp(entry.app); }
        } else activateResultApp(selectedEntry);
    }
    function setPinned(app, pinned) {
        const next = root.preferences.pinnedApps.filter(id => id !== app.id);
        if (pinned) next.push(app.id);
        const order = Model.logicalOrder(root.preferences).filter(key => key !== "app:" + app.id);
        if (pinned) order.push("app:" + app.id);
        root.setPreferences({pinnedApps: next, launcherOrder: order});
    }
    function reorderHome(sourceKey, targetKey, after) {
        const order = Model.logicalOrder(root.preferences);
        const next = Model.reorder(order, sourceKey, targetKey, after);
        if (next !== order) root.setPreference("launcherOrder", next);
    }
    function moveAppToGroup(app, group) {
        if (!app || !group || !root.preferences.appGroups.some(g => g.name === group.name)) return;
        const groups = root.preferences.appGroups.map(g => g.name === group.name ? Object.assign({}, g, {apps: Model.unique(g.apps.concat([app.id]))}) : g);
        const pins = root.preferences.pinnedApps.filter(id => id !== app.id);
        const order = Model.logicalOrder(root.preferences).filter(key => key !== "app:" + app.id);
        root.setPreferences({appGroups: groups, pinnedApps: pins, launcherOrder: order});
    }
    function setGroupApp(groupName, app, included) {
        const next = root.preferences.appGroups.map(g => {
            if (g.name !== groupName) return g;
            const apps = Model.unique(g.apps.filter(id => id !== app.id));
            if (included) apps.push(app.id);
            return Object.assign({}, g, {apps: apps});
        });
        root.setPreference("appGroups", next);
    }
    function activateResultApp(app) {
        if (!app) return;
        if (activeGroup && showAll) {
            const group = root.preferences.appGroups.find(g => g.name === activeGroup);
            if (group) setGroupApp(group.name, app, group.apps.indexOf(app.id) < 0);
        } else launchApp(app);
    }
    function beginGroup(app, group) {
        contextOpen = false; pendingDeleteName = ""; searchText = "";
        editingGroupName = group ? group.name : "";
        newGroupType = group ? groupType(group) : "compact";
        newGroupAppId = app ? app.id : "";
        groupInput.text = group ? group.name : "";
        creatingGroup = true;
        Qt.callLater(() => groupInput.forceActiveFocus());
    }
    function saveGroup() {
        const name = groupInput.text.trim();
        if (!name || root.preferences.appGroups.some(g => g.name.toLowerCase() === name.toLowerCase() && g.name !== editingGroupName)) return;
        if (editingGroupName) {
            const order = Model.logicalOrder(root.preferences).map(key => key === "group:" + editingGroupName ? "group:" + name : key);
            root.setPreferences({appGroups: root.preferences.appGroups.map(g => g.name === editingGroupName ? Object.assign({}, g, {name: name, type: newGroupType}) : g), launcherOrder: order});
            if (activeGroup === editingGroupName) activeGroup = name;
        } else {
            const groups = root.preferences.appGroups.slice();
            groups.push({name: name, type: newGroupType, apps: newGroupAppId ? [newGroupAppId] : []});
            root.setPreferences({appGroups: groups, launcherOrder: Model.logicalOrder(root.preferences).concat(["group:" + name])});
            activeGroup = "";
        }
        creatingGroup = false; editingGroupName = ""; newGroupAppId = ""; groupInput.text = "";
        showAll = false; searchText = ""; currentIndex = 0; focusSearch();
    }
    function setGroupType(group, type) {
        root.setPreference("appGroups", root.preferences.appGroups.map(g => g.name === group.name ? Object.assign({}, g, {type: type}) : g));
        contextOpen = false;
    }
    function openContext(kind, app, group, x, y) {
        contextKind = kind; contextApp = app; contextGroup = group;
        contextReturnFocus = launcher.Window.window ? launcher.Window.window.activeFocusItem : searchInput;
        menuIndex = 0;
        contextX = Math.max(0, Math.min(x, width - contextPanel.width));
        contextY = Math.max(0, y);
        contextOpen = true;
        Qt.callLater(() => contextPanel.forceActiveFocus());
    }
    function buildContextEntries() {
        if (contextKind === "app" && contextApp) {
            const app = contextApp;
            const entries = (app.unavailable ? [] : [{action: "launch", label: "Open " + app.name}]).concat([{action: "pin", label: root.preferences.pinnedApps.indexOf(app.id) >= 0 ? "Unpin from launcher" : "Pin to launcher"}, {action: "create", label: "Create group with app", section: true}]);
            for (const group of root.preferences.appGroups) entries.push({action: "membership", groupName: group.name, label: (group.apps.indexOf(app.id) >= 0 ? "Remove from " : "Add to ") + group.name + (group.apps.indexOf(app.id) < 0 && root.preferences.pinnedApps.indexOf(app.id) >= 0 ? " · keep pin" : ""), section: group === root.preferences.appGroups[0]});
            return entries;
        }
        if (contextKind === "group" && contextGroup) return [
            {action: "openGroup", label: "Open " + contextGroup.name},
            {action: "editApps", label: "Edit apps"},
            {action: "switchType", section: true, label: groupType(contextGroup) === "large" ? "Use compact preview" : "Use large preview"},
            {action: "rename", label: "Rename group"},
            {action: "delete", section: true, label: "Delete group"}
        ];
        return [{action: "create", label: "Create group"}].concat(showAll ? [] : [{action: "all", label: "Show all apps"}]);
    }
    function chooseContext(entry) {
        const app = contextApp;
        const group = contextGroup;
        closeContext();
        if (entry.action === "launch") launchApp(app);
        else if (entry.action === "pin") setPinned(app, root.preferences.pinnedApps.indexOf(app.id) < 0);
        else if (entry.action === "create") beginGroup(app, null);
        else if (entry.action === "membership") {
            const target = root.preferences.appGroups.find(g => g.name === entry.groupName);
            if (target) setGroupApp(target.name, app, target.apps.indexOf(app.id) < 0);
        } else if (entry.action === "openGroup") openGroup(group);
        else if (entry.action === "editApps") { activeGroup = group.name; showAll = true; searchText = ""; focusSearch(); }
        else if (entry.action === "switchType") setGroupType(group, groupType(group) === "large" ? "compact" : "large");
        else if (entry.action === "rename") beginGroup(null, group);
        else if (entry.action === "delete") { pendingDeleteName = group.name; Qt.callLater(() => deleteCancel.forceActiveFocus()); }
        else if (entry.action === "all") { showAll = true; activeGroup = ""; focusSearch(); }
        if (["pin", "membership", "switchType"].indexOf(entry.action) >= 0) Qt.callLater(focusSearch);
    }
    function deleteGroup() {
        const name = pendingDeleteName;
        root.setPreferences({appGroups: root.preferences.appGroups.filter(g => g.name !== name), launcherOrder: Model.logicalOrder(root.preferences).filter(key => key !== "group:" + name)});
        if (activeGroup === name) activeGroup = "";
        pendingDeleteName = ""; Qt.callLater(focusSearch);
    }

    Timer {
        interval: 40; repeat: true; running: !!launcher.dragSource && !launcher.dragCanceled
        onTriggered: {
            const localY = launcher.dragPoint.y - homeScroll.contentY;
            const delta = localY < 0 || localY > homeScroll.height || launcher.dragPoint.x < 0 || launcher.dragPoint.x > homeScroll.width ? 0 : localY < 24 ? -8 : localY > homeScroll.height - 24 ? 8 : 0;
            const before = homeScroll.contentY;
            homeScroll.contentY = Math.max(0, Math.min(homeScroll.contentHeight-homeScroll.height, before+delta));
            launcher.dragPoint = Qt.point(launcher.dragPoint.x, launcher.dragPoint.y+homeScroll.contentY-before);
        }
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton; onClicked: mouse => launcher.openContext("empty", null, null, mouse.x, mouse.y) }

    Column {
        id: contentColumn
        width: launcher.layoutWidth
        spacing: uiGeometry.dp(10)

        Rectangle {
            id: searchBox
            opacity: launcher.openingOpacity(0)
            width: parent.width; height: uiGeometry.dp(48); radius: uiGeometry.radius("softCard", width, height)
            color: Core.Theme.surfaceContainerHigh
            border.width: uiGeometry.dp(1)
            border.color: searchInput.activeFocus ? Core.Theme.primary : Core.Theme.outlineVariant
            MouseArea { anchors.fill: parent; z: -1; onClicked: launcher.focusSearch() }
            Glyph { visible: !launcher.commandMode; x: uiGeometry.dp(14); y: uiGeometry.dp(15); width: uiGeometry.dp(18); height: uiGeometry.dp(18); name: "search" }
            Text { visible: launcher.commandMode; x: uiGeometry.dp(12); y: uiGeometry.dp(14); text: "⌘"; font.pixelSize: uiGeometry.dp(16); font.family: "monospace"; color: Core.Theme.primary }
            TextInput {
                id: searchInput; objectName: "launcherSearch"; x: uiGeometry.dp(44); y: uiGeometry.dp(8); width: parent.width - uiGeometry.dp(98); height: uiGeometry.dp(31)
                verticalAlignment: TextInput.AlignVCenter; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(14)
                font.family: launcher.commandMode ? "monospace" : Qt.application.font.family
                selectionColor: Core.Theme.primaryContainer; selectedTextColor: Core.Theme.onPrimaryContainer
                Accessible.name: launcher.commandMode ? "Shell command" : launcher.activeGroup && !launcher.showAll ? "Search " + launcher.activeGroup : "Search apps"
                Accessible.description: "Start with > to run a command"
                onTextChanged: { launcher.currentIndex = 0; launcher.commandConfirmed = false; launcher.feedback = ""; launcher.notice = ""; launcher.contextOpen = false; }
                Keys.onPressed: event => {
                    launcher.handleKey(event);
                    if (event.accepted) return;
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (!event.isAutoRepeat) launcher.runSelected(); event.accepted = true; }
                    else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) { launcher.beginGroup(null, null); event.accepted = true; }
                }
            }
            Text { x: uiGeometry.dp(44); y: uiGeometry.dp(8); height: uiGeometry.dp(31); verticalAlignment: Text.AlignVCenter; width: parent.width-uiGeometry.dp(98); elide: Text.ElideRight; visible: !searchInput.text; text: "Search apps or type > for commands"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(13) }
            Rectangle {
                id: commandAction; activeFocusOnTab: true; border.width: activeFocus ? 1 : 0; border.color: Core.Theme.primary
                x: parent.width - uiGeometry.dp(42); y: uiGeometry.dp(10); width: uiGeometry.dp(28); height: uiGeometry.dp(28); radius: uiGeometry.radius("header", width, height); color: commandMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainer
                Accessible.role: Accessible.Button; Accessible.name: launcher.commandMode ? "Search applications" : "Enter command mode"
                function activate() { launcher.searchText = launcher.commandMode ? "" : "> "; launcher.focusSearch(); }
                Accessible.onPressAction: activate()
                Keys.onReturnPressed: activate(); Keys.onSpacePressed: activate()
                Glyph { visible: launcher.commandMode; anchors.centerIn: parent; width: uiGeometry.dp(14); height: uiGeometry.dp(14); name: "search" }
                Text { visible: !launcher.commandMode; anchors.centerIn: parent; text: "⌘"; color: Core.Theme.textSecondary; font.family: "monospace"; font.pixelSize: uiGeometry.dp(12) }
                MouseArea { id: commandMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.activate() }
            }
        }

        Item { width: parent.width; height: uiGeometry.dp(30); opacity: launcher.openingOpacity(y)
            Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: parent.width - uiGeometry.dp(175); elide: Text.ElideRight; text: launcher.commandMode ? "Command" : launcher.creatingGroup ? (launcher.editingGroupName ? "Rename group" : "New group") : launcher.showAll && launcher.activeGroup ? "Add apps to " + launcher.activeGroup : launcher.showAll ? "All apps" : launcher.activeGroup ? launcher.activeGroup : launcher.searchText ? "Search results" : "Pinned"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(14); font.weight: Font.Medium }
            Row { anchors.right: parent.right; spacing: uiGeometry.dp(8)
                Rectangle { id: backAction; visible: launcher.activeGroup || launcher.showAll || launcher.creatingGroup; width: visible ? uiGeometry.dp(70) : 0; height: uiGeometry.dp(30); radius: uiGeometry.radius("navigation", width, height); border.width: activeFocus ? uiGeometry.dp(2) : 0; border.color: Core.Theme.primary; color: backMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                    activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: "Back"; Accessible.onPressAction: launcher.goBack()
                    Keys.onReturnPressed: launcher.goBack(); Keys.onSpacePressed: launcher.goBack()
                    Text { anchors.centerIn: parent; text: "← Back"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11) }
                    MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: launcher.goBack() }
                }
                Rectangle { id: allAction; visible: !launcher.showAll && !launcher.creatingGroup && !launcher.commandMode; width: visible ? uiGeometry.dp(70) : 0; height: uiGeometry.dp(30); radius: uiGeometry.radius("navigation", width, height); border.width: activeFocus ? uiGeometry.dp(2) : 0; border.color: Core.Theme.primary; color: allMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                    activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: launcher.activeGroup ? "Edit group apps" : "Show all apps"; Accessible.onPressAction: allAction.activate()
                    Keys.onReturnPressed: allAction.activate(); Keys.onSpacePressed: allAction.activate()
                    function activate() { launcher.showAll = true; launcher.searchText = ""; launcher.currentIndex = 0; launcher.focusSearch(); }
                    Text { anchors.centerIn: parent; text: launcher.activeGroup ? "Edit apps" : "All apps"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11) }
                    MouseArea { id: allMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: allAction.activate() }
                }
            }
        }

        Column { visible: launcher.creatingGroup; width: parent.width; spacing: uiGeometry.dp(10)
            Rectangle { width: parent.width; height: uiGeometry.dp(42); radius: uiGeometry.radius("tile", width, height); color: Core.Theme.surfaceContainerHigh; border.width: groupInput.activeFocus ? uiGeometry.dp(2) : 1; border.color: groupInput.activeFocus ? Core.Theme.primary : Core.Theme.outlineVariant
                TextInput { selectionColor: Core.Theme.primaryContainer; selectedTextColor: Core.Theme.onPrimaryContainer; id: groupInput; x: uiGeometry.dp(14); width: parent.width - uiGeometry.dp(28); height: parent.height; verticalAlignment: TextInput.AlignVCenter; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(13); Accessible.name: "Group name"; onAccepted: launcher.saveGroup() }
                Text { visible: !groupInput.text; x: uiGeometry.dp(14); anchors.verticalCenter: parent.verticalCenter; text: "Group name"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(13) }
            }
            Text { visible: !!groupInput.text && launcher.root.preferences.appGroups.some(g => g.name.toLowerCase() === groupInput.text.trim().toLowerCase() && g.name !== launcher.editingGroupName); width: parent.width; text: "A group with this name already exists"; color: Core.Theme.error; font.pixelSize: uiGeometry.dp(11) }
            Text { text: "Preview size"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(11) }
            Row { spacing: uiGeometry.dp(8)
                Repeater { model: [{type: "compact", label: "Compact · 4 icons"}, {type: "large", label: "Large · 9 tiles"}]
                    Rectangle { id: typeChoice; required property var modelData; width: uiGeometry.dp(142); height: uiGeometry.dp(36); radius: uiGeometry.radius("compactControl", width, height); color: launcher.newGroupType === modelData.type ? Core.Theme.secondaryContainer : Core.Theme.surfaceContainerHigh
                        activeFocusOnTab: true; border.width: activeFocus ? uiGeometry.dp(2) : 0; border.color: Core.Theme.primary
                        Accessible.role: Accessible.Button; Accessible.name: modelData.label + (launcher.newGroupType === modelData.type ? ", selected" : ""); Accessible.onPressAction: launcher.newGroupType = modelData.type
                        Keys.onReturnPressed: launcher.newGroupType = modelData.type; Keys.onSpacePressed: launcher.newGroupType = modelData.type
                        Text { anchors.centerIn: parent; text: typeChoice.modelData.label; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11) }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launcher.newGroupType = typeChoice.modelData.type }
                    }
                }
                Rectangle { id: saveAction; border.width: activeFocus ? uiGeometry.dp(2) : 0; border.color: Core.Theme.primary; width: uiGeometry.dp(80); height: uiGeometry.dp(36); radius: uiGeometry.radius("compactControl", width, height); color: Core.Theme.primaryContainer
                    activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: launcher.editingGroupName ? "Save group" : "Create group"; Accessible.onPressAction: launcher.saveGroup()
                    Keys.onReturnPressed: launcher.saveGroup(); Keys.onSpacePressed: launcher.saveGroup()
                    Text { anchors.centerIn: parent; text: launcher.editingGroupName ? "Save" : "Create"; color: Core.Theme.textOnPrimaryContainer; font.pixelSize: uiGeometry.dp(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launcher.saveGroup() }
                }
            }
        }

        Rectangle { visible: !!launcher.pendingDeleteName; width: parent.width; height: visible ? uiGeometry.dp(72) : 0; radius: uiGeometry.radius("tile", width, height); color: Core.Theme.surfaceContainerHigh
            Text { x: uiGeometry.dp(12); y: uiGeometry.dp(10); width: parent.width - uiGeometry.dp(24); elide: Text.ElideRight; text: "Delete “" + launcher.pendingDeleteName + "”? Apps remain installed."; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(12) }
            Row { x: uiGeometry.dp(12); y: uiGeometry.dp(36); spacing: uiGeometry.dp(8)
                Rectangle { id: deleteCancel; border.width: activeFocus ? uiGeometry.dp(2) : 0; border.color: Core.Theme.primary; width: uiGeometry.dp(70); height: uiGeometry.dp(28); radius: uiGeometry.radius("button", width, height); color: Core.Theme.surfaceContainer
                    activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: "Cancel deletion"; Accessible.onPressAction: launcher.pendingDeleteName = ""
                    Keys.onReturnPressed: launcher.pendingDeleteName = ""; Keys.onSpacePressed: launcher.pendingDeleteName = ""
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launcher.pendingDeleteName = "" }
                }
                Rectangle { border.width: activeFocus ? uiGeometry.dp(2) : 0; border.color: Core.Theme.primary; width: uiGeometry.dp(104); height: uiGeometry.dp(28); radius: uiGeometry.radius("button", width, height); color: Core.Theme.surfaceContainer
                    activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: "Delete group " + launcher.pendingDeleteName; Accessible.onPressAction: launcher.deleteGroup()
                    Keys.onReturnPressed: launcher.deleteGroup(); Keys.onSpacePressed: launcher.deleteGroup()
                    Text { anchors.centerIn: parent; text: "Delete group"; color: Core.Theme.error; font.pixelSize: uiGeometry.dp(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launcher.deleteGroup() }
                }
            }
        }

        Text { visible: launcher.commandMode; width: parent.width; wrapMode: Text.Wrap; text: !launcher.searchText.slice(1).trim() ? "Type a shell command after >" : launcher.commandConfirmed ? "Ready to execute · press Enter again to confirm" : "Shell command · press Enter to review, then Enter to execute"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(11) }

        Flickable { id: homeScroll; visible: !launcher.creatingGroup && !launcher.activeGroup && !launcher.showAll && !launcher.searchText
            width: parent.width; height: visible ? Math.min(launcher.totalHomeHeight, uiGeometry.dp(352)) : 0; contentHeight: launcher.totalHomeHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ThemedScrollBar { policy: homeScroll.contentHeight > homeScroll.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
            MouseArea { z: -1; anchors.fill: parent; acceptedButtons: Qt.RightButton; onClicked: mouse => { const point = parent.mapToItem(launcher, mouse.x, mouse.y); launcher.openContext("empty", null, null, point.x, point.y); } }
            Item { id: homeFlow; width: homeScroll.width; height: launcher.totalHomeHeight
                Text { opacity: launcher.openingOpacity(homeScroll.y); visible: !launcher.homeEntries.length; text: "No pinned apps"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(12) }
                LauncherDragOverlay {
                    id: dragVisual; objectName: "launcherDragGrid"; z: 30; width: parent.width; height: launcher.homeLayout.height
                    gridParent: homeFlow; sourceTile: launcher.dragSource; pointer: launcher.dragPoint; grabOffset: launcher.dragOffset
                    destination: launcher.snapPlacement; canceled: launcher.dragCanceled
                    columns: launcher.gridColumns; cellWidth: launcher.gridCellWidth; cellHeight: launcher.gridCellHeight; gap: launcher.gridGap; gridHeight: launcher.homeLayout.height
                }
                Repeater { id: homeRepeater; model: launcher.homeRenderKeys
                    Item { id: homeTile; required property string modelData; required property int index
                        readonly property var entry: launcher.homeEntries.find(entry => entry.key === modelData) || {kind:"app",key:modelData,app:{name:"",icon:"",unavailable:true}}
                        readonly property int navigationIndex: launcher.homeEntries.findIndex(entry => entry.key === modelData)
                        readonly property bool folder: entry.kind === "group"
                        readonly property bool large: folder && launcher.groupType(entry.group) === "large"
                        readonly property var folderApps: folder ? launcher.groupApps(entry.group) : []
                        readonly property string orderKey: entry.key
                        objectName: orderKey
                        readonly property var placement: launcher.homeLayout.slots[navigationIndex] || {x:0,y:0,width:0,height:0}
                        x: placement.x; y: placement.y; width: placement.width; height: placement.height
                        HoverHandler { id: tileHover }
                        z: 0; opacity: (mover.active ? .28 : 1) * launcher.openingOpacity(homeScroll.y + placement.y - homeScroll.contentY)
                        Behavior on x { enabled: launcher.visible && !launcher.panel.busy && launcher.openingProgress >= 1; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on y { enabled: launcher.visible && !launcher.panel.busy && launcher.openingProgress >= 1; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { enabled: launcher.openingProgress >= 1; NumberAnimation { duration: 100 } }
                        onActiveFocusChanged: if (activeFocus) launcher.selectIndex(navigationIndex)
                        activeFocusOnTab: true; Accessible.role: Accessible.Button
                        Accessible.name: folder ? entry.group.name + ", " + (large ? "large" : "compact") + " group, " + folderApps.length + " apps" : "Open " + entry.app.name
                        Accessible.onPressAction: homeTile.activate()
                        Keys.onReturnPressed: homeTile.activate(); Keys.onSpacePressed: homeTile.activate()
                        Keys.onPressed: event => launcher.handleKey(event)
                        function activate() { if (folder) launcher.openGroup(entry.group); else launcher.launchApp(entry.app); }
                        DragHandler { id: mover; target: null; acceptedButtons: Qt.LeftButton
                            onActiveChanged: {
                                if (active) { launcher.closeContext(); launcher.dragSource = homeTile; launcher.dragCanceled = false; launcher.dragOffset = centroid.pressPosition; launcher.selectIndex(homeTile.navigationIndex); updateDestination(); }
                                else if (launcher.dragSource === homeTile) Qt.callLater(() => {
                                    if (launcher.dragSource !== homeTile) return;
                                    if (!launcher.dragCanceled && launcher.visible && !launcher.panel.busy) {
                                        const target = launcher.dropTile;
                                        const intent = launcher.dropIntent;
                                        if (target && intent === "group") launcher.moveAppToGroup(homeTile.entry.app, target.entry.group);
                                        else if (target && intent) launcher.reorderHome(homeTile.orderKey, target.orderKey, intent === "after");
                                    }
                                    launcher.dragSource = null;
                                });
                            }
                            onCanceled: { launcher.dragCanceled = true; launcher.feedback = "Move canceled"; }
                            onCentroidChanged: if (active) updateDestination()
                            function updateDestination() { launcher.dragPoint = homeTile.mapToItem(homeFlow, centroid.position.x, centroid.position.y); }
                        }
                        Rectangle { visible: homeTile.folder; width: homeTile.large ? homeTile.width : uiGeometry.dp(70); height: homeTile.large ? homeTile.height - uiGeometry.dp(26) : uiGeometry.dp(70); anchors.horizontalCenter: parent.horizontalCenter; radius: uiGeometry.radius(homeTile.large ? "launcherGroupLarge" : "launcherGroup", width, height)
                            color: tileHover.hovered || homeTile.navigationIndex === launcher.currentIndex ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh; border.width: uiGeometry.dp(1); border.color: homeTile.activeFocus || (launcher.searchFocus && homeTile.navigationIndex === launcher.currentIndex) ? Core.Theme.primary : Core.Theme.outlineVariant
                            MouseArea { visible: homeTile.large; anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => { if (launcher.dragSource) return; const point = homeTile.mapToItem(launcher, mouse.x, mouse.y); if (mouse.button === Qt.RightButton) launcher.openContext("group", null, homeTile.entry.group, point.x, point.y); else launcher.openGroup(homeTile.entry.group); }
                            }
                            Grid { visible: !homeTile.large; anchors.centerIn: parent; columns: 2; spacing: uiGeometry.dp(3)
                                Repeater { model: 4
                                    Item { required property int index; width: uiGeometry.dp(27); height: uiGeometry.dp(27); readonly property var entry: index < homeTile.folderApps.length ? homeTile.folderApps[index] : null
                                        LauncherIcon { visible: !!parent.entry; anchors.centerIn: parent; width: uiGeometry.dp(22); height: uiGeometry.dp(22); iconName: parent.entry ? parent.entry.icon : ""; appName: parent.entry ? parent.entry.name : "" }
                                    }
                                }
                            }
                            Grid { visible: homeTile.large; x: uiGeometry.dp(12); y: uiGeometry.dp(10); columns: 3; spacing: uiGeometry.dp(7)
                                Repeater { model: 9
                                    Rectangle { id: slot; required property int index; width: (homeTile.width - uiGeometry.dp(38)) / 3; height: width; radius: uiGeometry.radius("tile", width, height)
                                        readonly property var entry: index < 8 && index < homeTile.folderApps.length ? homeTile.folderApps[index] : null
                                        color: index === 8 ? Core.Theme.surfaceContainer : "transparent"
                                        LauncherIcon { visible: !!slot.entry; anchors.centerIn: parent; width: uiGeometry.dp(36); height: uiGeometry.dp(36); iconName: slot.entry ? slot.entry.icon : ""; appName: slot.entry ? slot.entry.name : "" }
                                        Text { visible: slot.index === 8; anchors.centerIn: parent; text: "•••"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(16) }
                                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => {
                                                if (launcher.dragSource) return;
                                                const point = slot.mapToItem(launcher, mouse.x, mouse.y);
                                                if (mouse.button === Qt.RightButton) {
                                                    if (slot.entry) launcher.openContext("app", slot.entry, null, point.x, point.y);
                                                    else launcher.openContext("group", null, homeTile.entry.group, point.x, point.y);
                                                } else if (slot.index === 8 || !slot.entry) launcher.openGroup(homeTile.entry.group);
                                                else launcher.launchApp(slot.entry);
                                            }
                                        }
                                    }
                                }
                            }
                            MouseArea { visible: !homeTile.large; anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => { if (launcher.dragSource) return; const point = homeTile.mapToItem(launcher, mouse.x, mouse.y); if (mouse.button === Qt.RightButton) launcher.openContext("group", null, homeTile.entry.group, point.x, point.y); else launcher.openGroup(homeTile.entry.group); }
                            }
                        }
                        LauncherIcon { visible: !homeTile.folder; anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.dp(14); width: uiGeometry.dp(38); height: uiGeometry.dp(38); iconName: homeTile.folder ? "" : homeTile.entry.app.icon; appName: homeTile.folder ? "" : homeTile.entry.app.name }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: homeTile.height - uiGeometry.dp(24); width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: homeTile.folder ? homeTile.entry.group.name : homeTile.entry.app.name + (homeTile.entry.app.unavailable ? " · unavailable" : ""); color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11) }
                        Rectangle { visible: !homeTile.folder; z: -1; anchors.fill: parent; radius: uiGeometry.radius("section", width, height); color: tileHover.hovered || homeTile.navigationIndex === launcher.currentIndex ? Core.Theme.hoverSurface : "transparent"; border.width: homeTile.activeFocus || (launcher.searchFocus && homeTile.navigationIndex === launcher.currentIndex) ? 1 : 0; border.color: Core.Theme.primary }
                        Rectangle { z: 8; visible: launcher.dropTile === homeTile && launcher.dropIntent === "group"; anchors.fill: parent; radius: uiGeometry.radius("section", width, height); color: Core.Theme.primaryContainer; opacity: .8
                            Text { anchors.centerIn: parent; width: parent.width - uiGeometry.dp(12); wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; text: "Move into\n" + (homeTile.folder ? homeTile.entry.group.name : ""); color: Core.Theme.textOnPrimaryContainer; font.pixelSize: uiGeometry.dp(11) }
                        }
                        Rectangle { z: 8; visible: launcher.dropTile === homeTile && launcher.dropIntent !== "group" && !!launcher.dropIntent; x: launcher.dropIntent === "before" ? 0 : parent.width - uiGeometry.dp(3); width: uiGeometry.dp(3); height: parent.height; radius: uiGeometry.radius("insertionMarker", width, height); color: Core.Theme.primary }
                        MouseArea { id: homeHit; hoverEnabled: true; visible: !homeTile.folder; anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => { if (launcher.dragSource) return; const point = homeTile.mapToItem(launcher, mouse.x, mouse.y); if (mouse.button === Qt.RightButton) launcher.openContext("app", homeTile.entry.app, null, point.x, point.y); else { launcher.selectIndex(homeTile.navigationIndex); launcher.launchApp(homeTile.entry.app); } }
                        }
                    }
                }
                Text { opacity: launcher.openingOpacity(homeScroll.y + y - homeScroll.contentY); y: launcher.recentTop - uiGeometry.dp(30); text: "Recently used"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(13); font.weight: Font.Medium }
                Text { opacity: launcher.openingOpacity(homeScroll.y + y - homeScroll.contentY); visible: !launcher.recentApps.length; y: launcher.recentTop; text: "No recent apps"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(12) }
                Repeater { id: recentRepeater; model: launcher.recentApps
                    Item {
                        id: recentTile; required property var modelData; required property int index
                        readonly property int navigationIndex: launcher.homeEntries.length + index
                        objectName: "recent:" + modelData.id
                        opacity: launcher.openingOpacity(homeScroll.y + launcher.recentTop + placement.y - homeScroll.contentY)
                        readonly property var placement: launcher.recentLayout.slots[index] || {x:0,y:0}
                        x: placement.x; y: launcher.recentTop + placement.y
                        width: launcher.gridCellWidth; height: launcher.gridCellHeight
                        activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: "Open " + modelData.name
                        Accessible.onPressAction: launcher.launchApp(modelData)
                        onActiveFocusChanged: if (activeFocus) launcher.selectIndex(navigationIndex)
                        Keys.onPressed: event => launcher.handleKey(event)
                        Keys.onReturnPressed: launcher.launchApp(modelData); Keys.onSpacePressed: launcher.launchApp(modelData)
                        Rectangle { anchors.fill: parent; radius: uiGeometry.radius("softCard", width, height); color: recentMouse.containsMouse || recentTile.navigationIndex === launcher.currentIndex ? Core.Theme.hoverSurface : "transparent"; border.width: recentTile.activeFocus || (launcher.searchFocus && recentTile.navigationIndex === launcher.currentIndex) ? 1 : 0; border.color: Core.Theme.primary }
                        LauncherIcon { anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.dp(14); width: uiGeometry.dp(38); height: uiGeometry.dp(38); iconName: recentTile.modelData.icon; appName: recentTile.modelData.name }
                        Text { y: uiGeometry.dp(74); width: parent.width; horizontalAlignment: Text.AlignHCenter; text: recentTile.modelData.name; elide: Text.ElideRight; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11) }
                        MouseArea { id: recentMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => { const point = recentTile.mapToItem(launcher,mouse.x,mouse.y); if (mouse.button === Qt.RightButton) launcher.openContext("app",recentTile.modelData,null,point.x,point.y); else launcher.launchApp(recentTile.modelData); }
                        }
                    }
                }
            }
        }

        Text { visible: !!launcher.notice || !!launcher.root.preferenceError; width: parent.width; wrapMode: Text.Wrap; text: launcher.root.preferenceError || launcher.notice; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(11) }


        Text { visible: !launcher.creatingGroup && !launcher.searchText && !launcher.commandMode && launcher.activeGroup && !launcher.showAll && launcher.results.length === 0; text: "This group is empty. Choose Edit apps to add one."; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(11) }
        Text { visible: !launcher.creatingGroup && launcher.showAll && !launcher.searchText && launcher.results.length === 0; width: parent.width; wrapMode: Text.Wrap; text: "No visible apps are available. Saved pins and groups are retained."; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(11) }
        Text { visible: !launcher.creatingGroup && !!launcher.searchText && !launcher.commandMode && launcher.results.length === 0; text: "No matching apps"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(11) }

        Flickable { id: appsGrid; visible: !launcher.creatingGroup && !launcher.searchText && !launcher.commandMode && (launcher.showAll || launcher.activeGroup)
            width: parent.width; height: visible ? Math.min(launcher.resultsLayout.height, uiGeometry.dp(314)) : 0; contentHeight: launcher.resultsLayout.height; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ThemedScrollBar { policy: appsGrid.contentHeight > appsGrid.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
            MouseArea { z: -1; anchors.fill: parent; acceptedButtons: Qt.RightButton; onClicked: mouse => { const point = parent.mapToItem(launcher, mouse.x, mouse.y); launcher.openContext("empty", null, null, point.x, point.y); } }
            Item { width: appsGrid.width; height: launcher.resultsLayout.height
            Repeater { id: appsRepeater; model: launcher.results
            Item { id: appCell; required property var modelData; required property int index; width: launcher.gridCellWidth; height: launcher.gridCellHeight
                readonly property var placement: launcher.resultsLayout.slots[index] || {x:0,y:0}
                x: placement.x; y: placement.y
                onActiveFocusChanged: if (activeFocus) launcher.selectIndex(index)
                readonly property bool editing: !!launcher.activeGroup && launcher.showAll
                readonly property bool included: editing && launcher.root.preferences.appGroups.some(g => g.name === launcher.activeGroup && g.apps.indexOf(modelData.id) >= 0)
                activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: editing ? (included ? "Remove " : "Add ") + modelData.name + (included ? " from " : " to ") + launcher.activeGroup : "Open " + modelData.name
                Accessible.onPressAction: launcher.activateResultApp(modelData)
                Keys.onReturnPressed: launcher.activateResultApp(modelData); Keys.onSpacePressed: launcher.activateResultApp(modelData)
                Keys.onPressed: event => launcher.handleKey(event)
                Rectangle { anchors.fill: parent; anchors.margins: uiGeometry.dp(3); radius: uiGeometry.insetRadius(uiGeometry.radius("section", appCell.width, appCell.height), anchors.leftMargin, width, height); color: appHit.containsMouse || (appCell.activeFocus || index === launcher.currentIndex) ? Core.Theme.hoverSurface : "transparent"; border.width: appCell.activeFocus || (launcher.searchFocus && index === launcher.currentIndex) ? 1 : 0; border.color: Core.Theme.primary }
                LauncherIcon { anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.dp(8); width: uiGeometry.dp(36); height: uiGeometry.dp(36); iconName: appCell.modelData.icon; appName: appCell.modelData.name }
                Rectangle { visible: appCell.editing; x: parent.width - uiGeometry.dp(29); y: uiGeometry.dp(3); width: uiGeometry.dp(24); height: uiGeometry.dp(24); radius: uiGeometry.radius("control", width, height); color: appCell.included ? Core.Theme.secondaryContainer : Core.Theme.surfaceContainerHigh
                    Text { anchors.centerIn: parent; text: appCell.included ? "✓" : "+"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(13) }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.dp(50); width: parent.width - uiGeometry.dp(8); text: appCell.modelData.name + (appCell.modelData.unavailable ? " · unavailable" : ""); color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11); horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                MouseArea { id: appHit; anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => { const point = appCell.mapToItem(launcher, mouse.x, mouse.y); if (mouse.button === Qt.RightButton) launcher.openContext("app", appCell.modelData, null, point.x, point.y); else launcher.activateResultApp(appCell.modelData); }
                }
            }
        }
            }
            }

        ListView { id: searchRows; visible: !launcher.creatingGroup && !!launcher.searchText && !launcher.commandMode
            width: parent.width; height: visible ? Math.min(5, launcher.results.length) * uiGeometry.dp(46) : 0; spacing: uiGeometry.dp(4); clip: true; model: launcher.results; currentIndex: launcher.currentIndex; boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle { id: resultRow; required property var modelData; required property int index; width: searchRows.width; height: uiGeometry.dp(42); radius: uiGeometry.radius("compactControl", width, height)
                readonly property bool editing: !!launcher.activeGroup && launcher.showAll
                readonly property bool included: editing && launcher.root.preferences.appGroups.some(g => g.name === launcher.activeGroup && g.apps.indexOf(modelData.id) >= 0)
                color: rowHit.containsMouse || index === launcher.currentIndex ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                border.width: activeFocus || (launcher.searchFocus && index === launcher.currentIndex) ? 1 : 0; border.color: Core.Theme.primary; activeFocusOnTab: true
                onActiveFocusChanged: if (activeFocus) launcher.selectIndex(index)
                Accessible.role: Accessible.Button; Accessible.name: editing ? (included ? "Remove " : "Add ") + modelData.name + (included ? " from " : " to ") + launcher.activeGroup : "Open " + modelData.name; Accessible.onPressAction: launcher.activateResultApp(modelData)
                Keys.onReturnPressed: launcher.activateResultApp(modelData); Keys.onSpacePressed: launcher.activateResultApp(modelData)
                Keys.onPressed: event => launcher.handleKey(event)
                LauncherIcon { x: uiGeometry.dp(10); anchors.verticalCenter: parent.verticalCenter; width: uiGeometry.dp(28); height: uiGeometry.dp(28); iconName: resultRow.modelData.icon; appName: resultRow.modelData.name }
                Text { x: uiGeometry.dp(48); anchors.verticalCenter: parent.verticalCenter; width: parent.width - uiGeometry.dp(76); elide: Text.ElideRight; text: resultRow.modelData.name + (resultRow.modelData.unavailable ? " · unavailable" : ""); color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(12) }
                Text { visible: resultRow.editing; x: parent.width - uiGeometry.dp(27); anchors.verticalCenter: parent.verticalCenter; text: resultRow.included ? "✓" : "+"; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(14) }
                MouseArea { id: rowHit; anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => { const point = resultRow.mapToItem(launcher, mouse.x, mouse.y); if (mouse.button === Qt.RightButton) launcher.openContext("app", resultRow.modelData, null, point.x, point.y); else launcher.activateResultApp(resultRow.modelData); }
                }
            }
        }
        Item { width: parent.width; height: uiGeometry.dp(12); MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton; onClicked: mouse => { const point = parent.mapToItem(launcher, mouse.x, mouse.y); launcher.openContext("empty", null, null, point.x, point.y); } } }
    }

    MouseArea { z: 99; visible: launcher.contextOpen; anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: launcher.closeContext() }
    Rectangle { id: contextPanel; objectName: "launcherContext"; z: 100; visible: launcher.contextOpen; x: launcher.contextX; y: Math.min(launcher.contextY, Math.max(0, launcher.height - height)); width: Math.min(uiGeometry.dp(270), launcher.width); height: Math.min(uiGeometry.dp(300), launcher.height, menuColumn.implicitHeight + uiGeometry.dp(12));
        focus: launcher.contextOpen
        Keys.onPressed: event => launcher.handleKey(event); radius: uiGeometry.radius("softCard", width, height)
        color: Core.Theme.surfaceContainerHighest; border.width: uiGeometry.dp(1); border.color: Core.Theme.outlineVariant
        Flickable { id: menuScroll; anchors.fill: parent; anchors.margins: uiGeometry.dp(6); contentHeight: menuColumn.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column { id: menuColumn; width: parent.width; spacing: uiGeometry.dp(2)
                Repeater { model: launcher.contextEntries
                    Rectangle { id: menuRow; required property var modelData; required property int index; width: menuColumn.width; height: uiGeometry.dp(34); radius: uiGeometry.radius("field", width, height); color: menuMouse.containsMouse || index === launcher.menuIndex ? Core.Theme.hoverSurface : "transparent"
                        activeFocusOnTab: true; Accessible.role: Accessible.Button; Accessible.name: modelData.label; Accessible.onPressAction: launcher.chooseContext(modelData)
                        Keys.onReturnPressed: launcher.chooseContext(modelData); Keys.onSpacePressed: launcher.chooseContext(modelData)
                        Text { x: uiGeometry.dp(10); anchors.verticalCenter: parent.verticalCenter; width: parent.width - uiGeometry.dp(20); elide: Text.ElideRight; text: menuRow.modelData.label; color: menuRow.modelData.action === "delete" ? Core.Theme.error : Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11) }
                        Rectangle { visible: !!menuRow.modelData.section; width: parent.width - uiGeometry.dp(20); x: uiGeometry.dp(10); height: uiGeometry.dp(1); color: Core.Theme.outlineVariant }
                        MouseArea { id: menuMouse; anchors.fill: parent; hoverEnabled: true; onEntered: launcher.menuIndex = menuRow.index; cursorShape: Qt.PointingHandCursor; onClicked: launcher.chooseContext(menuRow.modelData) }
                    }
                }
            }
        }
    }
}
