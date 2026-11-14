pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core

Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: overlay
    property Item gridParent: null
    property var sourceTile: null
    property point pointer: Qt.point(0, 0)
    property point grabOffset: Qt.point(0, 0)
    property var destination: null
    property int columns: 4
    property real cellWidth: 88
    property real cellHeight: 98
    property real gap: 10
    property real gridHeight: 0
    property bool canceled: false
    readonly property bool dragging: !!sourceTile && !canceled
    readonly property real destinationX: snap.x
    readonly property real destinationY: snap.y
    readonly property real gridOpacity: cells.opacity
    enabled: false

    Canvas {
        id: cells
        objectName: "launcherGridLines"
        parent: overlay.gridParent || overlay
        z: -1; width: overlay.width; height: overlay.gridHeight
        opacity: overlay.dragging ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: overlay; function onCellWidthChanged() { cells.requestPaint(); } function onGapChanged() { cells.requestPaint(); } }
        Connections { target: Core.Theme; function onPaletteChanged() { cells.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset(); ctx.clearRect(0,0,width,height);
            if (width <= 0 || height <= 0) return;
            const dx = overlay.cellWidth+overlay.gap, dy = overlay.cellHeight+overlay.gap;
            const offset = -overlay.gap/2;
            ctx.strokeStyle = Core.Theme.textSecondary.toString(); ctx.lineWidth = 1;
            ctx.globalAlpha = .25; ctx.beginPath();
            for (let x=offset; x<=width; x+=dx) { const px=Math.round(x)+.5; ctx.moveTo(px,0); ctx.lineTo(px,height); }
            for (let y=offset; y<=height; y+=dy) { const py=Math.round(y)+.5; ctx.moveTo(0,py); ctx.lineTo(width,py); }
            ctx.stroke();
            // Short, slightly brighter arms sit exactly on each line intersection.
            ctx.globalAlpha = .4; ctx.beginPath();
            for (let x=offset; x<=width; x+=dx) for (let y=offset; y<=height; y+=dy) {
                const px=Math.round(x)+.5, py=Math.round(y)+.5;
                ctx.moveTo(px-3,py); ctx.lineTo(px+3,py);
                ctx.moveTo(px,py-3); ctx.lineTo(px,py+3);
            }
            ctx.stroke();
            // Multiply independent horizontal and vertical alpha ramps for all four edges.
            ctx.globalAlpha = 1; ctx.globalCompositeOperation = "destination-in";
            const fx=Math.min(.45,28/width), fy=Math.min(.45,28/height);
            const horizontal=ctx.createLinearGradient(0,0,width,0);
            horizontal.addColorStop(0,"transparent"); horizontal.addColorStop(fx,"black"); horizontal.addColorStop(1-fx,"black"); horizontal.addColorStop(1,"transparent");
            ctx.fillStyle=horizontal; ctx.fillRect(0,0,width,height);
            const vertical=ctx.createLinearGradient(0,0,0,height);
            vertical.addColorStop(0,"transparent"); vertical.addColorStop(fy,"black"); vertical.addColorStop(1-fy,"black"); vertical.addColorStop(1,"transparent");
            ctx.fillStyle=vertical; ctx.fillRect(0,0,width,height);
            ctx.globalCompositeOperation="source-over";
        }
    }
    Rectangle {
        id: snap
        objectName: "launcherSnapTarget"
        x: overlay.destination ? overlay.destination.x : 0
        y: overlay.destination ? overlay.destination.y : 0
        width: overlay.destination ? overlay.destination.width : overlay.cellWidth
        height: overlay.destination ? overlay.destination.height : overlay.cellHeight
        radius: uiGeometry.radius("tile", width, height); color: Core.Theme.primaryContainer
        border.width: uiGeometry.dp(1); border.color: Core.Theme.primary
        opacity: overlay.dragging && !!overlay.destination ? .45 : 0
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }
    Item {
        id: preview
        objectName: "launcherDragPreview"
        x: overlay.pointer.x - overlay.grabOffset.x
        y: overlay.pointer.y - overlay.grabOffset.y
        width: overlay.sourceTile ? overlay.sourceTile.width : 0
        height: overlay.sourceTile ? overlay.sourceTile.height : 0
        opacity: overlay.dragging ? .95 : 0
        scale: overlay.dragging ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 100 } }
        Rectangle { anchors.fill: parent; radius: uiGeometry.radius("section", width, height); color: Core.Theme.surfaceContainerHighest }
        ShaderEffectSource { anchors.fill: parent; sourceItem: overlay.sourceTile; live: true; hideSource: false; recursive: false }
    }
}
