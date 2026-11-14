pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../core" as Core
import "../core/MediaMetadata.js" as Metadata

Rectangle {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: card
    objectName: "mediaCard"
    property var player: null
    // Explicit per-source classification can be supplied by an integration.
    property string mediaKindOverride: ""
    // Optional genuine app integration: supports(player), isFavorite(player),
    // toggle(player). No generic MPRIS favorite operation exists.
    property var favoriteAdapter: null
    readonly property string mediaKind: Metadata.kind(player, mediaKindOverride)
    readonly property bool knownLength: !!player && !!player.lengthSupported && isFinite(player.length) && player.length > 0
    readonly property bool knownPosition: !!player && !!player.positionSupported
    readonly property real duration: knownLength ? player.length : 0
    readonly property real position: knownPosition ? Math.max(0, player.position) : 0
    readonly property bool seekable: knownLength && knownPosition && !!player.canControl && !!player.canSeek
    readonly property bool canFavorite: mediaKind === "music" && !!player && !!player.canControl && !!favoriteAdapter && favoriteAdapter.supports(player)
    readonly property var desktopApp: {
        const apps = DesktopEntries.applications.values;
        if (!player || !player.desktopEntry) return null;
        const id = player.desktopEntry.replace(/\.desktop$/, "");
        return apps.find(app => app.id.replace(/\.desktop$/, "") === id) || DesktopEntries.byId(id) || DesktopEntries.byId(id + ".desktop");
    }
    readonly property string appName: desktopApp ? desktopApp.name : player ? (player.identity || "Media player") : "Media player"
    readonly property bool artworkReady: artwork.status === Image.Ready
    readonly property color ink: Core.Theme.onSurface
    width: uiGeometry.dp(324); implicitHeight: uiGeometry.dp(166); height: implicitHeight; radius: uiGeometry.radius("softCard", width, height); color: Core.Theme.surfaceContainer
    clip: true

    Image {
        id: artwork; objectName: "mediaArtwork"
        anchors.fill: parent
        source: card.player ? card.player.trackArtUrl : ""
        fillMode: Image.PreserveAspectCrop; asynchronous: true
        visible: card.artworkReady
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask }
    }
    Rectangle { id: artMask; anchors.fill: parent; radius: card.radius; layer.enabled: true; visible: false }
    // Opaque enough for palette ink to retain contrast even on extreme artwork.
    Rectangle {
        anchors.fill: parent; radius: card.radius
        color: Core.Theme.surfaceContainer
        opacity: card.artworkReady ? (Core.Theme.mode === "dark" ? 0.84 : 0.90) : 1
    }
    Timer {
        interval: 500; repeat: true
        running: card.visible && !!card.player && card.player.isPlaying && card.knownPosition
        onTriggered: card.player.positionChanged()
    }
    Image {
        id: appIcon; x: uiGeometry.dp(14); y: uiGeometry.dp(10); width: uiGeometry.dp(18); height: uiGeometry.dp(18)
        source: card.desktopApp && card.desktopApp.icon ? Quickshell.iconPath(card.desktopApp.icon, true) : ""
        fillMode: Image.PreserveAspectFit; visible: status === Image.Ready
    }
    Glyph { x: uiGeometry.dp(14); y: uiGeometry.dp(10); width: uiGeometry.dp(18); height: uiGeometry.dp(18); name: "apps"; ink: card.ink; visible: !appIcon.visible }
    Text { x: uiGeometry.dp(38); y: uiGeometry.dp(12); width: parent.width - uiGeometry.dp(52); text: card.appName; color: card.ink; font.pixelSize: uiGeometry.dp(10); font.weight: Font.Medium; elide: Text.ElideRight; maximumLineCount: 1 }
    Text { objectName: "mediaTitle"; x: uiGeometry.dp(14); y: uiGeometry.dp(34); width: parent.width - uiGeometry.dp(28); text: card.player ? (card.player.trackTitle || "Untitled media") : ""; color: card.ink; font.pixelSize: uiGeometry.dp(14); font.weight: Font.DemiBold; elide: Text.ElideRight; maximumLineCount: 1 }
    Text { objectName: "mediaArtist"; x: uiGeometry.dp(14); y: uiGeometry.dp(55); width: parent.width - uiGeometry.dp(28); text: card.player ? card.player.trackArtist : ""; color: Core.Theme.onSurfaceVariant; font.pixelSize: uiGeometry.dp(11); elide: Text.ElideRight; maximumLineCount: 1 }
    Slider {
        id: progress; objectName: "mediaProgress"; x: uiGeometry.dp(14); y: uiGeometry.dp(73); width: parent.width - uiGeometry.dp(28); height: uiGeometry.dp(24)
        from: 0; to: card.knownLength ? card.duration : 1; stepSize: 1
        enabled: card.seekable; activeFocusOnTab: enabled || activeFocus
        onEnabledChanged: if (!enabled) focus = false
        Accessible.name: "Media position"
        Accessible.description: card.seekable ? "Use arrow keys to seek" : "Seeking unavailable"
        Binding { target: progress; property: "value"; delayed: true; restoreMode: Binding.RestoreNone; value: card.knownLength ? Math.min(card.duration, card.position) : 0; when: !progress.pressed }
        onMoved: if (card.seekable) card.player.position = Math.max(0, Math.min(card.duration, value))
        background: Rectangle {
            x: progress.leftPadding; y: (progress.height - height) / 2; width: progress.availableWidth; height: uiGeometry.dp(4); radius: uiGeometry.radius("control", width, height); color: Core.Theme.outlineVariant
            Rectangle { width: card.knownLength && card.knownPosition ? progress.visualPosition * parent.width : 0; height: parent.height; radius: uiGeometry.radius("control", width, height); color: Core.Theme.primary }
        }
        handle: Rectangle {
            x: progress.leftPadding + progress.visualPosition * (progress.availableWidth - width); y: (progress.height - height) / 2
            width: progress.activeFocus || progress.pressed ? uiGeometry.dp(14) : uiGeometry.dp(10); height: width; radius: uiGeometry.radius("control", width, height); color: Core.Theme.primary
            visible: card.seekable; border.width: progress.activeFocus ? uiGeometry.dp(2) : 0; border.color: card.ink
        }
    }
    Text { objectName: "mediaElapsed"; x: uiGeometry.dp(14); y: uiGeometry.dp(98); text: card.knownPosition ? Metadata.time(card.position) : "—:—"; color: Core.Theme.onSurfaceVariant; font.pixelSize: uiGeometry.dp(10) }
    Text { objectName: "mediaDuration"; x: parent.width - width - uiGeometry.dp(14); y: uiGeometry.dp(98); text: card.knownLength ? Metadata.time(card.duration) : "—:—"; color: Core.Theme.onSurfaceVariant; font.pixelSize: uiGeometry.dp(10) }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.dp(118); spacing: uiGeometry.dp(10)
        Repeater {
            model: ["shuffle", "previous", "play", "next", "favorite"]
            Button {
                id: control
                required property string modelData
                objectName: "media-" + modelData
                readonly property bool supported: !!card.player && (modelData === "shuffle" ? card.mediaKind === "music" && card.player.shuffleSupported : modelData === "favorite" ? card.canFavorite : modelData === "previous" ? card.player.canGoPrevious : modelData === "next" ? card.player.canGoNext : card.player.isPlaying ? card.player.canPause : card.player.canPlay)
                readonly property bool selected: !!card.player && (modelData === "shuffle" ? card.player.shuffle : modelData === "favorite" ? card.canFavorite && card.favoriteAdapter.isFavorite(card.player) : modelData === "play")
                visible: supported; width: visible ? uiGeometry.dp(38) : 0; height: uiGeometry.dp(40)
                enabled: supported && !!card.player.canControl; activeFocusOnTab: (enabled && visible) || activeFocus
                onEnabledChanged: if (!enabled) focus = false
                onVisibleChanged: if (!visible) focus = false
                Accessible.name: modelData === "play" ? (card.player && card.player.isPlaying ? "Pause" : "Play") : modelData === "shuffle" ? "Shuffle" : modelData === "favorite" ? "Favorite" : modelData === "previous" ? "Previous track" : "Next track"
                Accessible.checkable: modelData === "shuffle" || modelData === "favorite"
                Accessible.checked: Accessible.checkable && selected
                function activate() {
                    if (!enabled || !visible) return;
                    if (modelData === "shuffle") card.player.shuffle = !card.player.shuffle;
                    else if (modelData === "previous") card.player.previous();
                    else if (modelData === "next") card.player.next();
                    else if (modelData === "favorite") card.favoriteAdapter.toggle(card.player);
                    else if (card.player.isPlaying) card.player.pause();
                    else card.player.play();
                }
                onClicked: activate()
                contentItem: Item { Glyph { anchors.centerIn: parent; width: uiGeometry.dp(20); height: uiGeometry.dp(20); name: control.modelData === "play" ? (card.player && card.player.isPlaying ? "pause" : "play") : control.modelData; ink: control.selected ? Core.Theme.onPrimaryContainer : card.ink } }
                background: Rectangle { radius: uiGeometry.radius("tile", width, height); color: Core.Theme.stateColor(control.selected ? Core.Theme.primaryContainer : Core.Theme.surfaceContainerHigh,control.selected ? Core.Theme.onPrimaryContainer : card.ink,control.hovered,control.down,control.activeFocus); border.width: control.activeFocus ? uiGeometry.dp(2) : 0; border.color: Core.Theme.primary; opacity: control.enabled ? 1 : Core.Theme.disabledControlOpacity }
                ThemedToolTip { visible: control.hovered; text: control.Accessible.name }
            }
        }
    }
}
