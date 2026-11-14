pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../core" as Core

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: picker
    required property var root
    required property var panel
    readonly property bool clipboardMode: panel.shownSection === "clipboard"
    readonly property bool emojiMode: panel.shownSection === "emoji"
    readonly property real contentHeight: pickerContent.implicitHeight + 36
    visible: (clipboardMode || emojiMode) && opacity > 0
    opacity: panel.contentAlpha
    enabled: !panel.busy
    Keys.onEscapePressed: event => { if (confirmClear) { confirmClear = false; event.accepted = true; } }
    property var entries: []
    property string query: ""
    property bool confirmClear: false
    readonly property var emoji: ["😀","😄","😂","🥹","😊","😍","😘","😎","🤔","😭","😡","👍","👎","👏","🙏","💪","👋","🤝","❤️","🧡","💛","💚","💙","💜","🔥","✨","🎉","💯","✅","❌","⚠️","⭐","🌙","☀️","🌈","🌸","🍕","☕","🎵","💻","📌","🚀","🏠","🐈","🐕","😴","🤖"]
    readonly property var emojiNames: ["Grinning face","Smiling face","Face with tears of joy","Holding back tears","Smiling face with smiling eyes","Heart eyes","Face blowing a kiss","Sunglasses","Thinking face","Crying face","Angry face","Thumbs up","Thumbs down","Clapping hands","Folded hands","Flexed biceps","Waving hand","Handshake","Red heart","Orange heart","Yellow heart","Green heart","Blue heart","Purple heart","Fire","Sparkles","Party popper","One hundred","Check mark","Cross mark","Warning","Star","Crescent moon","Sun","Rainbow","Cherry blossom","Pizza","Coffee","Music note","Laptop","Pushpin","Rocket","House","Cat","Dog","Sleeping face","Robot"]
    readonly property var emojiEntries: emoji.map((symbol, index) => ({symbol: symbol, name: emojiNames[index]}))
    onVisibleChanged: { if (visible && clipboardMode) refresh(); if (!visible) confirmClear = false; }
    onConfirmClearChanged: if (confirmClear) Qt.callLater(() => { if (picker.confirmClear) cancelButton.forceActiveFocus(); })
    function refresh() { history.running = true; }
    function run(action, argument) {
        const path = Qt.resolvedUrl("../services/input-tools.py").toString().replace("file://", "");
        if (action === "paste" || action === "emoji") {
            panel.dismiss();
            root.defer(["python3", path, action, argument]);
        } else {
            command.command = argument === undefined ? ["python3", path, action] : ["python3", path, action, argument];
            command.running = true;
        }
    }
    Process { id: history; command: ["python3", Qt.resolvedUrl("../services/input-tools.py").toString().replace("file://", ""), "list"]
        stdout: StdioCollector { onStreamFinished: { try { picker.entries = JSON.parse(text).entries || []; } catch (e) { picker.entries = []; } } }
    }
    Process { id: command; stdout: StdioCollector { onStreamFinished: picker.refresh() } }
    Column { id: pickerContent; anchors.fill: parent; spacing: 9; enabled: !picker.confirmClear
        Item { width: parent.width; height: 29
            Rectangle {
                id: closeButton; width: 29; height: 29; radius: uiGeometry.radius("control", width, height); color: closeMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                activeFocusOnTab: true
                Accessible.role: Accessible.Button; Accessible.name: "Close " + (picker.clipboardMode ? "clipboard history" : "emoji picker")
                Accessible.onPressAction: picker.panel.dismiss()
                Keys.onReturnPressed: picker.panel.dismiss()
                Keys.onSpacePressed: picker.panel.dismiss()
                Text { anchors.centerIn: parent; text: "‹"; color: Core.Theme.textPrimary; font.pixelSize: 23 }
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: picker.panel.dismiss() }
            }
            Text { anchors.centerIn: parent; text: picker.clipboardMode ? "Clipboard history" : "Emoji"; color: Core.Theme.textPrimary; font.pixelSize: 15; font.weight: Font.Medium }
            Rectangle {
                id: clearButton; visible: picker.clipboardMode && picker.entries.length > 0
                anchors.right: parent.right; width: 64; height: 29; radius: uiGeometry.radius("softCard", width, height)
                color: clearMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                activeFocusOnTab: visible
                Accessible.role: Accessible.Button; Accessible.name: "Clear clipboard history"
                Accessible.onPressAction: picker.confirmClear = true
                Keys.onReturnPressed: picker.confirmClear = true
                Keys.onSpacePressed: picker.confirmClear = true
                Text { anchors.centerIn: parent; text: "Clear all"; color: Core.Theme.textPrimary; font.pixelSize: 10 }
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: picker.confirmClear = true }
            }
        }
        Rectangle { width: parent.width; height: 34; radius: uiGeometry.radius("navigation", width, height); color: Core.Theme.surfaceContainerHigh
            TextInput { selectionColor: Core.Theme.primaryContainer; selectedTextColor: Core.Theme.onPrimaryContainer; id: filter; anchors.fill: parent; anchors.margins: 8; color: Core.Theme.textPrimary; font.pixelSize: 11
                Accessible.name: picker.clipboardMode ? "Search clipboard history" : "Search emoji by name"
                onTextChanged: picker.query = text
                Text { visible: !filter.text; text: picker.clipboardMode ? "Search history" : "Search emoji by name"; color: Core.Theme.textSecondary; font.pixelSize: 10 } }
        }
        Rectangle { width: parent.width; height: 270; radius: uiGeometry.radius("softCard", width, height); color: Core.Theme.surfaceContainer
            Flickable { anchors.fill: parent; anchors.margins: 8; contentHeight: content.height; clip: true
                Column { id: content; width: parent.width; spacing: 4
                    Repeater { model: picker.clipboardMode ? picker.entries.filter(item => item.preview.toLowerCase().includes(picker.query.toLowerCase())) : picker.emojiEntries.filter(item => !picker.query || item.name.toLowerCase().includes(picker.query.toLowerCase()) || item.symbol.includes(picker.query))
                        Rectangle { id: choice; required property var modelData; width: content.width; height: picker.clipboardMode ? 38 : 40; radius: uiGeometry.radius("button", width, height)
                            color: itemMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainerHigh
                            border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: picker.clipboardMode ? "Paste " + modelData.preview : "Insert " + modelData.name
                            Accessible.onPressAction: choice.activate()
                            Keys.onReturnPressed: choice.activate()
                            Keys.onSpacePressed: choice.activate()
                            function activate() { picker.run(picker.clipboardMode ? "paste" : "emoji", picker.clipboardMode ? modelData.id : modelData.symbol); }
                            Text { x: 9; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 50; elide: Text.ElideRight
                                text: picker.clipboardMode ? parent.modelData.preview : parent.modelData.symbol; textFormat: Text.PlainText
                                color: Core.Theme.textPrimary; font.pixelSize: picker.clipboardMode ? 11 : 21 }
                            MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: choice.activate() }
                            Rectangle {
                                z: 2; visible: picker.clipboardMode
                                anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                                width: 28; height: 28; radius: uiGeometry.radius("control", width, height); color: deleteMouse.containsMouse ? Core.Theme.hoverSurface : "transparent"
                                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                                activeFocusOnTab: visible
                                Accessible.role: Accessible.Button; Accessible.name: "Delete clipboard item: " + choice.modelData.preview
                                Accessible.onPressAction: picker.run("delete", choice.modelData.id)
                                Keys.onReturnPressed: picker.run("delete", choice.modelData.id)
                                Keys.onSpacePressed: picker.run("delete", choice.modelData.id)
                                Text { anchors.centerIn: parent; text: "×"; color: Core.Theme.textSecondary; font.pixelSize: 16 }
                                MouseArea { id: deleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: picker.run("delete", choice.modelData.id) }
                            }
                        }
                    }
                    Text { visible: picker.clipboardMode && picker.entries.length === 0; text: "History is empty"; color: Core.Theme.textSecondary; font.pixelSize: 11 }
                    Text { visible: !picker.clipboardMode && picker.query && picker.emojiEntries.filter(item => item.name.toLowerCase().includes(picker.query.toLowerCase()) || item.symbol.includes(picker.query)).length === 0; text: "No matching emoji"; color: Core.Theme.textSecondary; font.pixelSize: 11 }
                }
            }
        }
    }
    Rectangle {
        z: 2; visible: picker.confirmClear; anchors.fill: parent
        color: Qt.alpha(Core.Theme.scrim, 0.55)
        MouseArea { anchors.fill: parent; onClicked: picker.confirmClear = false }
    }
    Rectangle {
        id: clearDialog
        z: 3; visible: picker.confirmClear
        x: 12; y: 68; width: parent.width - 24; height: 156; radius: uiGeometry.radius("section", width, height)
        color: Core.Theme.surfaceContainerHigh
        border.width: 1; border.color: Core.Theme.outlineVariant
        Accessible.role: Accessible.Dialog; Accessible.name: "Clear clipboard history?"
        Text { x: 16; y: 16; text: "Clear clipboard history?"; color: Core.Theme.textPrimary; font.pixelSize: 14; font.weight: Font.Medium }
        Text { x: 16; y: 47; width: parent.width - 32; wrapMode: Text.Wrap; text: "All saved items will be removed."; color: Core.Theme.textSecondary; font.pixelSize: 11 }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; spacing: 8
            Rectangle {
                id: cancelButton
                width: 76; height: 34; radius: uiGeometry.radius("tile", width, height); color: cancelMouse.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainer
                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                activeFocusOnTab: picker.confirmClear
                Accessible.role: Accessible.Button; Accessible.name: "Cancel"
                Accessible.onPressAction: picker.confirmClear = false
                Keys.onReturnPressed: picker.confirmClear = false
                Keys.onSpacePressed: picker.confirmClear = false
                Text { anchors.centerIn: parent; text: "Cancel"; color: Core.Theme.textPrimary; font.pixelSize: 11 }
                MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: picker.confirmClear = false }
            }
            Rectangle {
                width: 96; height: 34; radius: uiGeometry.radius("tile", width, height); color: confirmMouse.containsMouse ? Core.Theme.hoverActiveSurface : Core.Theme.secondaryContainer
                border.width: activeFocus ? 2 : 0; border.color: Core.Theme.primary
                activeFocusOnTab: picker.confirmClear
                Accessible.role: Accessible.Button; Accessible.name: "Clear history"
                Accessible.onPressAction: { picker.confirmClear = false; picker.run("clear"); }
                Keys.onReturnPressed: { picker.confirmClear = false; picker.run("clear"); }
                Keys.onSpacePressed: { picker.confirmClear = false; picker.run("clear"); }
                Text { anchors.centerIn: parent; text: "Clear history"; color: Core.Theme.onSecondaryContainer; font.pixelSize: 11 }
                MouseArea { id: confirmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { picker.confirmClear = false; picker.run("clear"); } }
            }
        }
    }
}
