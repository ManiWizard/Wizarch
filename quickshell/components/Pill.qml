pragma ComponentBehavior: Bound
import QtQuick
import "../core/RevealIntent.js" as RevealIntent
import QtQuick.Controls
import QtQuick.Shapes
import "../core" as Core
import "../panels"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.Mpris

PanelWindow {
    property var uiGeometry: Core.GeometryContext { uiScale: Core.Geometry.scaleForOutput(pillWindow.modelData.name); devicePixelRatio: pillWindow.devicePixelRatio }

    id: pillWindow
    required property var modelData
    required property var root
    screen: modelData
    readonly property var workspaceState: Core.Workspaces.forMonitor(modelData.name)
    readonly property bool workspaceSwitching: Core.Workspaces.isSwitching(modelData.name)
    onWorkspaceSwitchingChanged: { if (workspaceSwitching && expanded) dismiss(); }
    readonly property bool edgeConnected: root.preferences.edgeConnected !== false
    readonly property bool screenBorder: edgeConnected && root.preferences.screenBorder === true
    readonly property real borderThickness: uiGeometry.clamp(uiGeometry.constraint("borderThicknessMinimum"), uiGeometry.constraint("borderThicknessMaximum"), root.preferences.borderThickness || uiGeometry.constraint("borderThicknessDefault"))
    readonly property real visualClipTop: screenBorder ? borderThickness : 0
    readonly property real panelTop: screenBorder ? borderThickness : edgeConnected ? uiGeometry.metric("panelTop") : 0
    readonly property real borderRadius: uiGeometry.clamp(0, uiGeometry.constraint("borderRadiusMaximum"), root.preferences.borderRadius === undefined ? uiGeometry.radius("panel", modelData.width, modelData.height) : root.preferences.borderRadius)
    // Match the window's visible outer corner, without adding desktop gaps.
    readonly property real frameRadius: root.preferences.matchWindowCorners !== false
        ? root.matchedFrameRadius
        : borderRadius
    readonly property bool autoHide: root.preferences.autoHide === true
    readonly property bool overlayWindows: autoHide && root.preferences.revealMode === "overlay"
    readonly property bool canAutoHide: autoHide && (root.preferences.hideOnEmptyMonitor === true || root.occupiedMonitors[modelData.name] === true)
    property real openReservation: uiGeometry.metric("pillHeight")
    onCanAutoHideChanged: { reveal(); scheduleHide(); }
    property bool hideRequested: false
    readonly property bool autoHidden: canAutoHide && hideRequested && !expanded && !busy && !pillWindow.workspaceSwitching
    // Animate a fixed collapsed travel distance; resizing content never retargets it.
    property real hideProgress: autoHidden ? 1 : 0
    readonly property real hideOffset: -hideProgress * (uiGeometry.metric("pillHeight") + panelTop + uiGeometry.metric("shoulderWidth"))
    Behavior on hideProgress {
        NumberAnimation { duration: 280; easing.type: Easing.InOutCubic }
    }
    Timer {
        id: revealThenOpen; interval: 290
        onTriggered: if (pillWindow.expanded) opening.restart()
    }
    function reveal() { hideRequested = false; hideDelay.stop(); }
    function scheduleHide() {
        if (canAutoHide && !expanded && !busy && !bodyHover.hovered && !edgeMouse.containsMouse) hideDelay.restart();
    }
    onAutoHideChanged: { reveal(); scheduleHide(); }
    onBusyChanged: scheduleHide()
    Component.onCompleted: scheduleHide()
    Timer {
        id: hideDelay; interval: 1200
        onTriggered: {
            if (pillWindow.canAutoHide && !pillWindow.expanded && !pillWindow.busy && !bodyHover.hovered && !edgeMouse.containsMouse)
                pillWindow.hideRequested = true;
        }
    }
    // A narrow, independent edge target remains reachable when the body is hidden.
    PanelWindow {
        screen: pillWindow.modelData
        visible: pillWindow.autoHide
        anchors.top: true
        implicitWidth: Math.min(pillWindow.modelData.width, uiGeometry.metric("revealWidth")); implicitHeight: (pillWindow.screenBorder ? pillWindow.borderThickness : 0) + uiGeometry.metric("revealHeight")
        // The hot zone must stay at y=0, not below other exclusive surfaces.
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.namespace: "wizarch-reveal"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea {
            id: edgeMouse; anchors.fill: parent; hoverEnabled: true
            property real lastX: 0
            property real lastY: 0
            property bool towardPanel: false
            function arm() { if (!intentDelay.running) intentDelay.start(); }
            onEntered: {
                lastX = mouseX; lastY = mouseY;
                // Entering at the bottom is an approach from below, toward the edge.
                towardPanel = mouseY >= height - uiGeometry.constraint("revealApproachInset");
                if (towardPanel) arm();
            }
            onPositionChanged: {
                const intent = RevealIntent.movement(mouseX, mouseY, lastX, lastY, width / 2);
                if (intent < 0) { towardPanel = false; intentDelay.stop(); }
                else if (intent > 0) { towardPanel = true; arm(); }
                lastX = mouseX; lastY = mouseY;
            }
            onExited: { intentDelay.stop(); towardPanel = false; pillWindow.scheduleHide(); }
            Timer {
                id: intentDelay; interval: 120
                onTriggered: if (edgeMouse.containsMouse && edgeMouse.towardPanel) pillWindow.reveal()
            }
        }
    }
    property string section: ""
    property string shownSection: ""
    property real surfaceWidth: collapsedWidth
    property real surfaceHeight: uiGeometry.metric("pillHeight")
    property real contentAlpha: 0
    property real headerAlpha: 1
    property bool busy: opening.running || closing.running || revealThenOpen.running
    readonly property real collapsedWidth: uiGeometry.fit(uiGeometry.metric("pillWidth"), modelData.width)
    readonly property real targetWidth: uiGeometry.fit(uiGeometry.metric(section === "launcher" ? "launcherWidth" : "panelWidth"), Math.max(0, modelData.width - 2 * uiGeometry.metric("shoulderWidth")))
    readonly property real targetHeight: section === "launcher" ? launcher.contentHeight : section === "status" ? statusContent.contentHeight : section === "notifications" ? notificationsContent.contentHeight : section === "wifi" || section === "bluetooth" ? connectivityContent.contentHeight : section === "clipboard" || section === "emoji" ? inputContent.contentHeight : section === "clock" ? calendar.contentHeight : uiGeometry.metric("pillHeight")
    function dismiss() { if (section !== "") section = ""; }
    HyprlandFocusGrab {
        id: outsideGrab
        windows: [pillWindow]
        onCleared: pillWindow.dismiss()
    }
    readonly property bool expanded: section !== ""
    function launchCurrentApp() {
        const entry = launcher.selectedEntry;
        if (!entry) return;
        if (entry.runInTerminal) Quickshell.execDetached({command: ["kitty", "-e"].concat(entry.command), workingDirectory: entry.workingDirectory});
        else entry.execute();
        dismiss();
    }
    function toggle(name) { if (!busy) section = section === name ? "" : name; }
    function resizeToContent() {
        // Content changes must wait until the hidden pill has finished revealing.
        if (!expanded || opening.running || closing.running || revealThenOpen.running) return;
        if (Math.abs(surfaceHeight - targetHeight) >= uiGeometry.constraint("resizeEpsilon")) {
            heightResize.stop(); heightResize.to = targetHeight; heightResize.start();
        }
        if (Math.abs(surfaceWidth - targetWidth) >= uiGeometry.constraint("resizeEpsilon")) {
            widthResize.stop(); widthResize.to = targetWidth; widthResize.start();
        }
    }
    anchors.top: true
    margins.top: edgeConnected ? 0 : uiGeometry.metric("panelTop")
    // The transparent window follows the animated body and its active content.
    implicitWidth: Math.min(modelData.width, uiGeometry.metric("panelWindowWidth"))
    // Keep the Wayland surface stable while the masked body animates.
    implicitHeight: modelData.height
    // Reserve before reveal; release only once the pill is completely hidden.
    exclusiveZone: overlayWindows ? (screenBorder ? borderThickness : 0)
        : expanded || shownSection !== "" ? Math.ceil(openReservation + panelTop)
        : autoHidden && hideProgress >= 0.999 ? (screenBorder ? borderThickness : 0)
        : Math.ceil(uiGeometry.metric("pillHeight") + panelTop)
    color: "transparent"
    WlrLayershell.namespace: "quickshell"
    WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: body; radius: body.radius }
    onSectionChanged: {
        const wasHidden = hideProgress > 0.01;
        revealThenOpen.stop();
        reveal();
        if (section === "") scheduleHide();
        if (section !== "") {
            openReservation = targetHeight;
            const switching = shownSection !== "" && !closing.running && surfaceWidth >= uiGeometry.metric("panelWidth") - uiGeometry.stroke(false);
            closing.stop(); shownSection = section; if (section === "launcher") launcher.reset();
            if (section === "clock") calendar.reset();
            if (switching) {
                contentAlpha = 1;
                Qt.callLater(() => { pillWindow.resizeToContent(); if (pillWindow.section === "launcher") launcher.focusSearch(); else body.forceActiveFocus(); });
            } else if (wasHidden) revealThenOpen.restart();
            else opening.restart();
        } else { outsideGrab.active = false; opening.stop(); heightResize.stop(); widthResize.stop(); closing.restart(); }
    }
    onTargetHeightChanged: {
        if (expanded) openReservation = targetHeight;
        if (expanded && shownSection === section) Qt.callLater(pillWindow.resizeToContent);
    }
    SequentialAnimation {
        id: opening
        onStopped: Qt.callLater(pillWindow.resizeToContent)
        NumberAnimation { target: pillWindow; property: "headerAlpha"; to: 0; duration: 90 }
        ParallelAnimation {
            NumberAnimation { target: pillWindow; property: "surfaceWidth"; to: pillWindow.targetWidth; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: pillWindow; property: "surfaceHeight"; to: pillWindow.targetHeight; duration: 250; easing.type: Easing.OutCubic }
        }
        NumberAnimation { target: pillWindow; property: "contentAlpha"; to: 1; duration: 120 }
        ScriptAction { script: { if (pillWindow.section === "launcher") launcher.focusSearch(); else body.forceActiveFocus(); outsideGrab.active = true; } }
    }
    SequentialAnimation {
        id: closing
        NumberAnimation { target: pillWindow; property: "contentAlpha"; to: 0; duration: 90 }
        ParallelAnimation {
            NumberAnimation { target: pillWindow; property: "surfaceHeight"; to: uiGeometry.metric("pillHeight"); duration: 250; easing.type: Easing.InOutCubic }
            NumberAnimation { target: pillWindow; property: "surfaceWidth"; to: pillWindow.collapsedWidth; duration: 250; easing.type: Easing.InOutCubic }
        }
        ScriptAction { script: pillWindow.shownSection = "" }
        NumberAnimation { target: pillWindow; property: "headerAlpha"; to: 1; duration: 120 }
    }
    NumberAnimation { id: heightResize; target: pillWindow; property: "surfaceHeight"; to: uiGeometry.metric("pillHeight"); duration: 240; easing.type: Easing.OutCubic }
    NumberAnimation { id: widthResize; target: pillWindow; property: "surfaceWidth"; to: uiGeometry.metric("panelWidth"); duration: 240; easing.type: Easing.OutCubic }
    IpcHandler {
        target: "panel-" + pillWindow.modelData.name
        function setUiScale(value: real): void {
            if (!Number.isFinite(value) || value < 1 || value > 2 || Math.round(value*4) !== value*4) return;
            const values = Object.assign({}, pillWindow.root.preferences.uiScaleByOutput || ({}));
            values[pillWindow.modelData.name] = value;
            pillWindow.root.setPreference("uiScaleByOutput", values);
        }
        function geometrySnapshot(): string {
            return JSON.stringify({output:pillWindow.modelData.name,uiScale:uiGeometry.uiScale,dpr:uiGeometry.devicePixelRatio,collapsedWidth:collapsedWidth,surfaceWidth:surfaceWidth,surfaceHeight:surfaceHeight,targetWidth:targetWidth,targetHeight:targetHeight,section:section,launcherColumns:launcher.gridColumns,launcherCellHeight:launcher.gridCellHeight,calendarNaturalHeight:calendar.naturalHeight,calendarViewportHeight:calendar.height});
        }

        function previewSettingsWindow(): void { pillWindow.dismiss(); pillWindow.root.openSettings(); }
        function togglePanel(section: string): void {
            if (section === "settings" || section === "themes") {
                pillWindow.dismiss(); pillWindow.root.openSettings(section); return;
            }
            if (["launcher", "clock", "status", "notifications", "wifi", "bluetooth", "clipboard", "emoji"].indexOf(section) !== -1) pillWindow.toggle(section);
        }
        function calendarMonth(month: bool): void { calendar.showMode(month ? 1 : 0); }
        function calendarMode(mode: int): void { if (mode >= 0 && mode <= 2) calendar.showMode(mode); }
        function show(section: string): void {
            if (["", "launcher", "clock", "status", "notifications", "wifi", "bluetooth", "clipboard", "emoji"].indexOf(section) !== -1) pillWindow.section = section;
        }
    }
    ScreenBorder { panel: pillWindow }
    Item {
        id: movingContent
        property var uiGeometry: pillWindow.uiGeometry
        y: pillWindow.visualClipTop
        width: pillWindow.width; height: pillWindow.height - y
        clip: true
    OverlayShadow { uiGeometry: pillWindow.uiGeometry; panel: pillWindow }

    // Concave shoulders meet the inner screen-frame edge when enabled.
    Shape {
        preferredRendererType: Shape.CurveRenderer
        visible: pillWindow.edgeConnected
        anchors.horizontalCenter: parent.horizontalCenter
        y: (pillWindow.screenBorder ? pillWindow.borderThickness : 0) + pillWindow.hideOffset - pillWindow.visualClipTop
        width: pillWindow.surfaceWidth + 2 * uiGeometry.metric("shoulderWidth")
        height: uiGeometry.metric("shoulderHeight")
        antialiasing: true
        ShapePath {
            strokeWidth: -1
            fillColor: Core.Theme.surface
            startX: 0; startY: 0
            PathLine { x: pillWindow.surfaceWidth + 2 * uiGeometry.metric("shoulderWidth"); y: 0 }
            PathCubic { x: pillWindow.surfaceWidth + uiGeometry.metric("shoulderWidth"); y: uiGeometry.metric("shoulderHeight");
                control1X: pillWindow.surfaceWidth + uiGeometry.metric("shoulderWidth") + uiGeometry.metric("shoulderControlY"); control1Y: 0;
                control2X: pillWindow.surfaceWidth + uiGeometry.metric("shoulderWidth"); control2Y: uiGeometry.metric("shoulderControlY") }
            PathLine { x: uiGeometry.metric("shoulderWidth"); y: uiGeometry.metric("shoulderHeight") }
            PathCubic { x: 0; y: 0;
                control1X: uiGeometry.metric("shoulderWidth"); control1Y: uiGeometry.metric("shoulderControlY");
                control2X: uiGeometry.metric("shoulderControlX"); control2Y: 0 }
        }
    }
    Rectangle {
        id: body
        y: pillWindow.panelTop + pillWindow.hideOffset - pillWindow.visualClipTop
        anchors.horizontalCenter: parent.horizontalCenter
        width: pillWindow.surfaceWidth; height: pillWindow.surfaceHeight
        radius: uiGeometry.radius("panel", width, height)
        antialiasing: true
        clip: true
        HoverHandler {
            id: bodyHover
            onHoveredChanged: { if (hovered) pillWindow.reveal(); else pillWindow.scheduleHide(); }
        }
        border.width: pillWindow.edgeConnected && !pillWindow.screenBorder ? uiGeometry.stroke(false) : 0
        border.color: pillWindow.screenBorder ? Core.Theme.surface : Qt.alpha(Core.Theme.surfaceContainerHighest, 0.22)
        color: Core.Theme.surface
        Keys.onPressed: event => { if (event.key === Qt.Key_Escape) { pillWindow.dismiss(); event.accepted = true; } }
        Row {
            id: header
            opacity: pillWindow.workspaceSwitching ? 0 : pillWindow.headerAlpha
            Behavior on opacity { NumberAnimation { duration: 110 } }
            visible: opacity > 0
            enabled: !pillWindow.busy && !pillWindow.expanded
            x: uiGeometry.metric("headerInset")
            y: uiGeometry.metric("headerInset")
            width: Math.max(0, parent.width - 2 * x)
            height: uiGeometry.metric("headerHeight")
            Item {
                id: launcherButton
                width: uiGeometry.metric("headerButtonWidth"); height: header.height
                activeFocusOnTab: true
                Accessible.role: Accessible.Button; Accessible.name: "Apps"
                Accessible.onPressAction: pillWindow.toggle("launcher")
                Keys.onReturnPressed: pillWindow.toggle("launcher")
                Keys.onSpacePressed: pillWindow.toggle("launcher")
                Rectangle { anchors.fill: parent; anchors.leftMargin: uiGeometry.metric("headerHighlightInset"); anchors.rightMargin: uiGeometry.metric("headerHighlightInset"); radius: uiGeometry.radius("header", width, height); color: launcherMouse.containsMouse || pillWindow.section === "launcher" ? Core.Theme.hoverSurface : "transparent"; border.width: launcherButton.activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.primary; Behavior on color { enabled: !Core.Theme.publishing; ColorAnimation { duration: 130 } } }
                Glyph { visible: pillWindow.workspaceState.used.length < 2; anchors.centerIn: parent; width: uiGeometry.metric("headerIcon"); height: width; name: "arch"; ink: Core.Theme.textPrimary }
                Text { visible: pillWindow.workspaceState.used.length > 1; anchors.centerIn: parent; text: pillWindow.workspaceState.current; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.metric("fontHeaderWorkspace"); font.weight: Font.Medium }
                MouseArea { id: launcherMouse; acceptedButtons: Qt.LeftButton | Qt.RightButton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mouse => { if (mouse.button === Qt.RightButton) pillWindow.root.openSettings("themes"); else pillWindow.toggle("launcher"); } }
                ThemedToolTip { visible: launcherMouse.containsMouse; text: "Apps" }
            }
            Item { width: uiGeometry.metric("headerDividerWidth"); height: parent.height; FadedDivider { anchors.centerIn: parent } }
            Item {
                id: clockButton
                width: Math.max(0, header.width - 2 * (uiGeometry.metric("headerButtonWidth") + uiGeometry.metric("headerDividerWidth"))); height: header.height
                activeFocusOnTab: true
                Accessible.role: Accessible.Button; Accessible.name: "Calendar, " + Qt.formatDateTime(pillWindow.root.clockDate, "dddd, MMMM d, h:mm AP")
                Accessible.onPressAction: pillWindow.toggle("clock")
                Keys.onReturnPressed: pillWindow.toggle("clock")
                Keys.onSpacePressed: pillWindow.toggle("clock")
                Rectangle { anchors.fill: parent; anchors.leftMargin: uiGeometry.metric("headerHighlightInset"); anchors.rightMargin: uiGeometry.metric("headerHighlightInset"); radius: uiGeometry.radius("header", width, height); color: clockMouse.containsMouse || pillWindow.section === "clock" ? Core.Theme.hoverSurface : "transparent"; border.width: clockButton.activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.primary; Behavior on color { enabled: !Core.Theme.publishing; ColorAnimation { duration: 130 } } }
                Text { anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.metric("headerTimeY"); text: Qt.formatDateTime(root.clockDate, "HH:mm"); color: Core.Theme.textPrimary; font.family: "Noto Sans"; font.pixelSize: uiGeometry.metric("fontHeaderClock"); font.weight: Font.Medium; font.letterSpacing: 0.2 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.metric("headerDateY"); height: uiGeometry.metric("headerDateHeight"); spacing: uiGeometry.metric("headerDateGap")
                    Text { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(root.clockDate, "ddd").toUpperCase(); color: Core.Theme.textSecondary; font.family: "Noto Sans"; font.pixelSize: uiGeometry.metric("fontHeaderDate"); font.weight: Font.Medium; font.letterSpacing: 0.2 }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: uiGeometry.metric("headerDot"); height: width; radius: uiGeometry.radius("control", width, height); color: Qt.alpha(Core.Theme.textSecondary, 0.55) }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(root.clockDate, "MMM d").toUpperCase(); color: Core.Theme.textSecondary; font.family: "Noto Sans"; font.pixelSize: uiGeometry.metric("fontHeaderDate"); font.weight: Font.Medium; font.letterSpacing: 0.2 }
                }
                MouseArea { id: clockMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pillWindow.toggle("clock") }
            }
            Item { width: uiGeometry.metric("headerDividerWidth"); height: parent.height; FadedDivider { anchors.centerIn: parent } }
            Item {
                id: statusButton
                width: uiGeometry.metric("headerButtonWidth"); height: header.height
                activeFocusOnTab: true
                Accessible.role: Accessible.Button; Accessible.name: "Quick settings"
                Accessible.onPressAction: pillWindow.toggle("status")
                Keys.onReturnPressed: pillWindow.toggle("status")
                Keys.onSpacePressed: pillWindow.toggle("status")
                Rectangle { anchors.fill: parent; anchors.leftMargin: uiGeometry.metric("headerHighlightInset"); anchors.rightMargin: uiGeometry.metric("headerHighlightInset"); radius: uiGeometry.radius("header", width, height); color: statusMouse.containsMouse || pillWindow.section === "status" ? Core.Theme.hoverSurface : "transparent"; border.width: statusButton.activeFocus ? uiGeometry.stroke(true) : 0; border.color: Core.Theme.primary; Behavior on color { enabled: !Core.Theme.publishing; ColorAnimation { duration: 130 } } }
                Canvas {
                    id: emblem
                    property real chargePhase: 0
                    NumberAnimation on chargePhase { from: 0; to: 1; duration: 1700; loops: Animation.Infinite; running: UPower.displayDevice.state === UPowerDeviceState.Charging }
                    onChargePhaseChanged: requestPaint()
                    anchors.centerIn: parent; width: uiGeometry.metric("emblemSize"); height: width
                    antialiasing: true
                    onPaint: {
                        const c = getContext("2d"); c.reset();
                        c.scale(width / 30, height / 30); // Canvas artwork uses its original 30-unit coordinate system.
                        c.lineCap = "round"; c.lineWidth = 1.8;
                        const gap = 0.23, span = Math.PI - 2 * gap;
                        const rightStart = -Math.PI / 2 + gap;
                        const leftStart = Math.PI / 2 + gap;
                        function arc(start, amount, color) {
                            if (amount <= 0) return;
                            c.strokeStyle = color; c.beginPath(); c.arc(15, 15, 11.2, start, start + span * amount); c.stroke();
                        }
                        arc(rightStart, 1, Core.Theme.surfaceContainerHighest);
                        arc(leftStart, 1, Core.Theme.surfaceContainerHighest);
                        if (root.hasBattery) {
                            const charge = Math.max(0, Math.min(100, root.batteryPercent));
                            // Right drains bottom-to-top (100–50%); left top-to-bottom (50–0%).
                            arc(rightStart, Math.max(0, (charge - 50) / 50), Core.Theme.textSecondary);
                            arc(leftStart, Math.min(1, charge / 50), Core.Theme.textSecondary);
                            if (UPower.displayDevice.state === UPowerDeviceState.Charging) {
                                c.lineWidth = 2.2;
                                arc(rightStart + span * (emblem.chargePhase * 0.72), 0.22, Core.Theme.primary);
                                arc(leftStart + span * (emblem.chargePhase * 0.72), 0.22, Core.Theme.primary);
                            }
                        }
                        c.lineWidth = 1.35;
                        c.strokeStyle = root.network.wifi || root.network.ethernet ? Core.Theme.textPrimary : Core.Theme.textSecondary;
                        if (root.network.wifi) {
                            for (let r of [7, 4.1]) { c.beginPath(); c.arc(15, 19, r, -Math.PI * 0.75, -Math.PI * 0.25); c.stroke(); }
                            c.fillStyle = c.strokeStyle; c.beginPath(); c.arc(15, 19, 1, 0, Math.PI * 2); c.fill();
                        } else if (root.network.ethernet) {
                            // Keep the wired symbol clear of the charge arcs.
                            c.save(); c.translate(15, 15); c.scale(0.85, 0.85); c.translate(-15, -15);
                            c.lineJoin = "round";
                            c.strokeRect(8.5, 10.5, 12, 8);
                            c.beginPath(); c.moveTo(13.5, 18.5); c.lineTo(13.5, 21);
                            c.moveTo(10.5, 21); c.lineTo(16.5, 21); c.stroke();
                            c.fillStyle = Core.Theme.surface; c.fillRect(17.5, 16, 5.5, 6);
                            c.strokeRect(18, 16.5, 4.5, 4);
                            c.beginPath(); c.moveTo(19.5, 16.5); c.lineTo(19.5, 15);
                            c.moveTo(21, 16.5); c.lineTo(21, 15);
                            c.moveTo(20.25, 20.5); c.lineTo(20.25, 23); c.stroke();
                            c.restore();
                        } else {
                            c.beginPath(); c.arc(15, 17, 6, 0, Math.PI * 2); c.moveTo(9, 17); c.lineTo(21, 17); c.moveTo(15, 11); c.lineTo(15, 23); c.stroke();
                        }

                    }
                    Connections { target: Core.Theme; function onPaletteChanged() { emblem.requestPaint(); } }
            Connections { target: pillWindow.root; function onBatteryPercentChanged() { emblem.requestPaint(); } function onIndicatorsChanged() { emblem.requestPaint(); } }
                }
                MouseArea { id: statusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pillWindow.toggle("status") }
                ThemedToolTip { visible: statusMouse.containsMouse; text: "Quick settings" }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.metric("workspaceY"); spacing: uiGeometry.metric("workspaceGap")
            opacity: pillWindow.workspaceSwitching && !pillWindow.expanded ? 1 : 0
            visible: opacity > 0; enabled: visible
            Behavior on opacity { NumberAnimation { duration: 110 } }
            Repeater {
                model: 9
                Rectangle {
                    required property int index
                    width: uiGeometry.metric("workspaceWidth"); height: uiGeometry.metric("workspaceHeight"); radius: uiGeometry.radius("workspace", width, height)
                    color: pillWindow.workspaceState.current === index+1 ? Core.Theme.primaryContainer : "transparent"
                    Text { anchors.centerIn: parent; text: parent.index+1; color: pillWindow.workspaceState.current === parent.index+1 ? Core.Theme.textOnPrimaryContainer : pillWindow.workspaceState.used.indexOf(parent.index+1)!==-1 ? Core.Theme.textPrimary : Core.Theme.textSecondary; font.pixelSize: uiGeometry.metric("fontWorkspace") }
                    MouseArea { anchors.fill: parent; onClicked: Core.Workspaces.select(parent.index+1, pillWindow.modelData.name) }
                }
            }
        }
        LauncherView { uiGeometry: pillWindow.uiGeometry;
            id: launcher; root: pillWindow.root; panel: pillWindow
            x: uiGeometry.metric("panelInset"); y: x; width: Math.max(0, parent.width - 2 * x); height: Math.max(0, parent.height - 2 * y)
        }
        CalendarView { uiGeometry: pillWindow.uiGeometry;
            id: calendar; root: pillWindow.root; x: uiGeometry.metric("panelInset"); y: uiGeometry.metric("calendarInset"); width: Math.max(0, parent.width - 2 * x); height: Math.max(0, contentHeight - 2 * y)
            availableHeight: Math.max(uiGeometry.metric("calendarMinimumHeight"), pillWindow.modelData.height - uiGeometry.metric("screenContentReserve"))
            today: root.clockDate
            visible: pillWindow.shownSection === "clock" && opacity > 0
            opacity: pillWindow.contentAlpha; enabled: !pillWindow.busy
        }
        QuickSettings { uiGeometry: pillWindow.uiGeometry; availableHeight: Math.max(0, pillWindow.modelData.height-uiGeometry.metric("screenContentReserve")); id: statusContent; root: pillWindow.root; panel: pillWindow; x: uiGeometry.metric("panelInset"); y: x; width: Math.max(0, parent.width - 2 * x); height: Math.max(0, parent.height - 2 * y) }
        NotificationCenter { uiGeometry: pillWindow.uiGeometry; id: notificationsContent; root: pillWindow.root; panel: pillWindow; x: uiGeometry.metric("panelInset"); y: x; width: Math.max(0, parent.width - 2 * x); height: Math.max(0, parent.height - 2 * y) }
        ConnectivityView { uiGeometry: pillWindow.uiGeometry; id: connectivityContent; root: pillWindow.root; panel: pillWindow; x: uiGeometry.metric("panelInset"); y: x; width: Math.max(0, parent.width - 2 * x); height: Math.max(0, parent.height - 2 * y) }
        InputPicker { uiGeometry: pillWindow.uiGeometry; id: inputContent; root: pillWindow.root; panel: pillWindow; x: uiGeometry.metric("panelInset"); y: x; width: Math.max(0, parent.width - 2 * x); height: Math.max(0, parent.height - 2 * y) }

    }
    }
}
