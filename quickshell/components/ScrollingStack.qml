pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Io
import "../core" as Core

// Large app pages form a recessed stack in the right gutter. Rendering and input
// are clipped to the exposed edges, inside the frame and below the pill.
PanelWindow {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: stack
    required property var modelData
    required property var root
    required property var state
    screen: modelData
    readonly property var workspaceState: state.monitors[modelData.name] || null
    readonly property var cards: workspaceState ? workspaceState.cards : []
    readonly property real frame: root.preferences.edgeConnected !== false
        && root.preferences.screenBorder === true
        ? Math.max(1, Math.min(10, root.preferences.borderThickness || 3)) : 0
    readonly property real step: Math.min(36, modelData.width * 0.025)
    readonly property real gutter: cards.length * step + 12
    readonly property real radius: root.preferences.matchWindowCorners !== false
        ? root.matchedFrameRadius : uiGeometry.clamp(0, uiGeometry.constraint("borderRadiusMaximum"),
            root.preferences.borderRadius === undefined ? uiGeometry.radius("panel", modelData.width, modelData.height) : root.preferences.borderRadius)
    property var slotAddresses: ["", "", "", ""]
    function syncSlots() {
        const needed = workspaceState ? [workspaceState.active].concat(workspaceState.cards.map(card => card.address)) : [];
        const slots = slotAddresses.slice();
        for (const address of needed) {
            if (slots.indexOf(address) !== -1) continue;
            const free = slots.findIndex(value => needed.indexOf(value) === -1);
            if (free !== -1) slots[free] = address;
        }
        for (let i = 0; i < slots.length; i++) if (needed.indexOf(slots[i]) === -1) slots[i] = "";
        if (JSON.stringify(slots) !== JSON.stringify(slotAddresses)) slotAddresses = slots;
    }
    onWorkspaceStateChanged: syncSlots()
    Component.onCompleted: syncSlots()
    function previewFor(address) {
        const index = slotAddresses.indexOf(address);
        return index < 0 ? null : pages.itemAt(index);
    }
    visible: cards.length > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "wizarch-scrolling-stack"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    // Input is restricted to the exposed edges; the desktop remains click-through.
    mask: Region { item: edgeInput }

    function sourceFor(address) {
        for (const top of Hyprland.toplevels.values) {
            if ("0x" + top.address.replace(/^0x/, "") === address) return top.wayland || null;
        }
        return null;
    }
    function activate(address) {
        if (!cards.some(card => card.address === address)) return;
        const source = sourceFor(address);
        if (source) source.activate();
    }
    IpcHandler {
        target: "stack-" + stack.modelData.name
        function select(address: string): void { stack.activate(address); }
        function status(): string {
            return JSON.stringify({visible: stack.visible, gutter: stack.gutter,
                workspace: stack.workspaceState, sources: stack.cards.map(card => !!stack.sourceFor(card.address)),
                cache: [0, 1, 2, 3].map(index => {
                    const preview = pages.itemAt(index);
                    return preview ? {address: preview.address, ready: preview.hasPreview,
                        cached: preview.cachedFrame !== null, hovered: preview.hovered,
                        allowed: preview.mayCapture, source: !!preview.hasSource} : null;
                }),
                previews: stack.cards.map(card => {
                    const preview = stack.previewFor(card.address);
                    return preview ? preview.hasPreview : false;
                })});
        }
    }

    PanelWindow {
        screen: stack.modelData
        visible: stack.visible
        anchors { top: true; bottom: true; right: true }
        implicitWidth: stack.gutter
        exclusiveZone: stack.gutter
        // Arrange this transparent reservation after the pill's Top-layer zone,
        // so the pill remains centered on the physical output, not the gutter.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wizarch-stack-reserve"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {}
    }

    // Clip to the original frame's inner outline. The card painter must never
    // cover its corners, even though the frame retains its original Bottom layer.
    ClippingRectangle {
        id: frameClip
        x: stack.frame; y: stack.frame
        width: stack.width - stack.frame * 2
        height: stack.height - stack.frame * 2
        radius: uiGeometry.boundedRadius(stack.radius, width, height)
        color: "transparent"
        Item {
            id: insideFrame
            x: frameClip.width - stack.gutter
            width: stack.gutter; height: frameClip.height
            clip: true
            // Continue the actual desktop wallpaper through the gutter. Filling it
            // with the frame color made the existing 8 px border appear much wider.
            Rectangle { anchors.fill: parent; color: Core.Theme.shadow; z: -100 }
            Image {
                x: -insideFrame.x - stack.frame; y: -stack.frame
                width: stack.width; height: stack.height
                source: Core.Theme.wallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                z: -99
            }
            Repeater {
                id: pages
                model: 4
                ClippingRectangle {
                    id: card
                    required property int index
                    readonly property string address: stack.slotAddresses[index]
                    readonly property int cardIndex: stack.cards.findIndex(value => value.address === address)
                    readonly property var entry: cardIndex < 0 ? null : stack.cards[cardIndex]
                    readonly property real depth: cardIndex + 1
                    readonly property bool hasPreview: capture.hasContent
                    readonly property bool hasSource: !!capture.captureSource
                    property var cachedFrame: null
                    property string capturedAddress: ""
                    readonly property bool hovered: hover.containsMouse
                    readonly property bool mayCapture: stack.visible && stack.workspaceState
                        && stack.workspaceState.capture.indexOf(address) !== -1
                    readonly property real inset: Math.max(stack.radius + 8, insideFrame.height * 0.035) * depth
                    onAddressChanged: {
                        cachedFrame = null;
                        capturedAddress = "";
                        Qt.callLater(ensureSource);
                    }
                    function ensureSource() {
                        if (mayCapture) capturedAddress = address;
                    }
                    Component.onCompleted: ensureSource()
                    // Keep the active capture's scene graph alive off the gutter so
                    // its still frame is available immediately after focus changes.
                    visible: address !== ""
                    z: 3 - cardIndex
                    // Successively smaller pages fan toward the right edge.
                    width: Math.max(100, (stack.width - stack.frame * 2 - stack.gutter) * (1 - depth * 0.045))
                    height: Math.max(100, insideFrame.height - inset * 2)
                    x: stack.step * depth - width
                    y: inset
                    radius: uiGeometry.boundedRadius(uiGeometry.clamp(uiGeometry.radius("field", width, height), uiGeometry.radius("launcherGroup", width, height), stack.radius), width, height)
                    color: Core.Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: hover.containsMouse ? Core.Theme.primary : Core.Theme.outlineVariant
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Item {
                        anchors.fill: parent
                        clip: true
                        ScreencopyView {
                            id: capture
                            anchors.fill: parent
                            captureSource: card.address && card.capturedAddress === card.address
                                ? stack.sourceFor(card.address) : null
                            live: false
                            paintCursor: false
                            onCaptureSourceChanged: { card.cachedFrame = null; captureDelay.restart(); }
                            onHasContentChanged: if (hasContent) cacheDelay.restart()
                        }
                        Image { anchors.fill: parent; cache: false; source: card.cachedFrame ? card.cachedFrame.url : "" }
                        Rectangle { anchors.fill: parent; color: Core.Theme.scrim; opacity: Math.max(0, card.cardIndex) * 0.12 }
                    }
                    // A readable page spine is useful even when an app cannot export.
                    Item {
                        width: 16; height: parent.height
                        anchors.right: parent.right
                        Rectangle { anchors.fill: parent; color: Core.Theme.surfaceContainerHigh; opacity: 0.85 }
                        Text {
                            anchors.centerIn: parent
                            width: parent.height - 48
                            rotation: 90
                            text: card.entry ? card.entry.title || card.entry.app : ""
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            color: hover.containsMouse ? Core.Theme.primary : Core.Theme.textSecondary
                            font.pixelSize: 11
                        }
                    }
                    onMayCaptureChanged: if (mayCapture) { ensureSource(); captureDelay.restart(); }
                    function refreshCapture() {
                        if (mayCapture && capture.captureSource) {
                            capture.captureFrame();
                            cacheDelay.restart();
                        }
                    }
                    Timer { id: captureDelay; interval: 180;
                        onTriggered: card.refreshCapture() }
                    Timer { interval: 2000; running: card.mayCapture && capture.captureSource !== null;
                        repeat: true; onTriggered: card.refreshCapture() }
                    Timer { id: cacheDelay; interval: 350; onTriggered: {
                        if (!capture.hasContent || !card.mayCapture) return;
                        const address = card.address;
                        capture.grabToImage(result => {
                            if (card.address === address) card.cachedFrame = result;
                        }, Qt.size(1024, Math.max(1, Math.round(1024 * capture.height / capture.width))));
                    } }
                    MouseArea {
                        id: hover; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (card.entry) stack.activate(card.entry.address)
                    }
                }
            }
        }
    }
    Item {
        id: edgeInput
        x: stack.width - stack.frame - stack.gutter
        y: stack.frame + Math.max(stack.radius + 8, insideFrame.height * 0.035)
        width: stack.gutter - 8
        height: Math.max(0, insideFrame.height - 2 * (y - stack.frame))
    }
}
