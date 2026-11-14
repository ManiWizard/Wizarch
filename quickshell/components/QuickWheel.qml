pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../core" as Core
import "../core/WheelNavigation.js" as Navigation

Scope {
    property var uiGeometry: Core.GeometryContext { uiScale: Core.Geometry.scaleForOutput(wheel.targetScreen ? wheel.targetScreen.name : ""); devicePixelRatio: surface.devicePixelRatio }

    id: wheel
    signal actionRequested(var command)
    property bool opened: false
    onOpenedChanged: { motion.stop();motion.to=opened ? 1 : 0;motion.start(); }
    Component.onCompleted: surface.progress=opened ? 1 : 0
    property var targetScreen: null
    property string previousWindow: ""
    property int selectedIndex: 0
    property real lastPointerX: 0
    property real lastPointerY: 0
    property bool pointerMode: false
    readonly property var geometry: ({x:surface.centerX,y:surface.centerY,inner:surface.innerRadius,outer:surface.outerRadius,width:surface.width,height:surface.height})
    readonly property var actions: [
        {id:"launcher",label:"Launcher",icon:"apps",detail:"Find and open an app"},
        {id:"calendar",label:"Calendar",icon:"calendar",detail:"Date and calendar"},
        {id:"quick-settings",label:"Quick settings",icon:"sound",detail:"Sound, radios and system controls"},
        {id:"notifications",label:"Notifications",icon:"notifications",detail:"Your notification history"},
        {id:"clipboard",label:"Clipboard",icon:"clipboard",detail:"Choose a saved clipboard item"},
        {id:"screenshot",label:"Screenshot",icon:"screenshot",detail:"Select an area to capture"},
        {id:"themes",label:"Themes",icon:"night",detail:"Choose your shell appearance"},
        {id:"settings",label:"Settings",icon:"settings",detail:"Open Wizarch Settings"}
    ]
    function openAt(monitor, x, y, previous) {
        const screen=Quickshell.screens.find(s=>s.name===monitor);
        if (!screen || !Number.isFinite(x) || !Number.isFinite(y)) return;
        actionDelay.stop();
        targetScreen=screen; previousWindow=previous;
        lastPointerX=screen.width/2; lastPointerY=screen.height/2; pointerMode=false; selectedIndex=-1; opened=true;
        Qt.callLater(() => { if (opened) input.forceActiveFocus(); });
    }
    function cancel() { opened=false; actionDelay.stop(); }
    function cycle(delta) { pointerMode=false; selectedIndex=Navigation.cycle(selectedIndex,delta,actions.length); }
    function point(x,y) {
        // A stationary pointer must not undo a keyboard selection on mapping.
        if (Math.hypot(x-lastPointerX,y-lastPointerY)<3) return;
        lastPointerX=x;lastPointerY=y;pointerMode=true;
        selectedIndex=Navigation.indexAt(x,y,surface.centerX,surface.centerY,surface.innerRadius,surface.outerRadius,actions.length);
    }
    function handleClick(x,y,button) {
        if (!opened) return false;
        if (button===Qt.RightButton) { cancel();return true; }
        if (button!==Qt.LeftButton) return false;
        const index=Navigation.indexAt(x,y,surface.centerX,surface.centerY,surface.innerRadius,surface.outerRadius,actions.length);
        if(index<0)cancel();else { selectedIndex=index;activate(); }
        return true;
    }
    function handleKey(key, modifiers, repeat) {
        if (!opened) return false;
        if (key===Qt.Key_Escape) cancel();
        else if (key===Qt.Key_Up) { pointerMode=false;selectedIndex=0; }
        else if (key===Qt.Key_Right) { pointerMode=false;selectedIndex=2; }
        else if (key===Qt.Key_Down) { pointerMode=false;selectedIndex=4; }
        else if (key===Qt.Key_Left) { pointerMode=false;selectedIndex=6; }
        else if (key===Qt.Key_Tab && !(modifiers & Qt.ShiftModifier)) cycle(1);
        else if (key===Qt.Key_Backtab || (key===Qt.Key_Tab && (modifiers & Qt.ShiftModifier))) cycle(-1);
        else if (key===Qt.Key_Home) { pointerMode=false;selectedIndex=0; }
        else if (key===Qt.Key_End) { pointerMode=false;selectedIndex=actions.length-1; }
        else if (key===Qt.Key_Return || key===Qt.Key_Enter || key===Qt.Key_Space) { if(!repeat)activate(); }
        else if (key===Qt.Key_W && (modifiers & Qt.MetaModifier)) cancel();
        else return false;
        return true;
    }
    function activate() {
        if (!opened || selectedIndex<0 || selectedIndex>=actions.length || !targetScreen) return;
        actionDelay.command=["python3",Qt.resolvedUrl("../services/quick-wheel.py").toString().replace("file://",""),"activate",targetScreen.name,actions[selectedIndex].id,previousWindow];
        opened=false; actionDelay.restart();
    }
    Timer { id: actionDelay; property var command: []; interval: 150; onTriggered: wheel.actionRequested(command) }
    function validateScreen() {
        if (opened && (!targetScreen || !Quickshell.screens.some(s=>s.name===wheel.targetScreen.name))) cancel();
    }
    Connections {
        target: Quickshell
        function onScreensChanged() { wheel.validateScreen(); }
    }
    IpcHandler {
        target: "quick-wheel"
        function toggle(monitor: string, x: real, y: real, previous: string): void { if (wheel.opened) wheel.cancel(); else wheel.openAt(monitor,x,y,previous); }
        function close(): void { wheel.cancel(); }
        function isOpen(): bool { return wheel.opened; }
    }
    PanelWindow {
        id: surface
        property var uiGeometry: wheel.uiGeometry
        screen: wheel.targetScreen
        visible: !!wheel.targetScreen && (wheel.opened || progress > 0.001)
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wizarch-quick-wheel"
        WlrLayershell.keyboardFocus: wheel.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region { width: wheel.opened ? surface.width : 0; height: wheel.opened ? surface.height : 0 }
        color: "transparent"
        readonly property real outerRadius: uiGeometry.wheelOuterRadius(width, height)
        readonly property real innerRadius: uiGeometry.wheelInnerRadius(outerRadius)
        readonly property real centerX: width/2
        readonly property real centerY: height/2
        property real progress: 0
        NumberAnimation { id: motion; target: surface; property: "progress"; duration: wheel.opened ? 170 : 110; easing.type: Easing.OutCubic }
        FocusScope {
            id: input; anchors.fill: parent; focus: wheel.opened; enabled: wheel.opened
            Accessible.role: Accessible.PopupMenu; Accessible.name: "Wizarch quick actions"
            Keys.onPressed: event => { event.accepted=wheel.handleKey(event.key,event.modifiers,event.isAutoRepeat); }
            Item {
                x: surface.centerX-surface.outerRadius; y: surface.centerY-surface.outerRadius
                width: surface.outerRadius*2; height: width
                opacity: surface.progress; scale: 0.94+surface.progress*0.06
                transformOrigin: Item.Center
                // One continuous translucent disk; the hub and selected sector sit above it.
                Rectangle { objectName: "wheelDisk"; anchors.fill: parent; radius: width/2; color: Qt.alpha(Core.Theme.surfaceContainerLow,0.94) }
                Repeater {
                    model: wheel.actions
                    Shape {
                        id: sector
                        required property var modelData
                        required property int index
                        readonly property real start: (-90+index*45-22.5)*Math.PI/180
                        readonly property real end: (-90+index*45+22.5)*Math.PI/180
                        readonly property real cx: surface.outerRadius
                        readonly property real cy: surface.outerRadius
                        readonly property bool selected: wheel.selectedIndex===index
                        anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: 0
                            strokeColor: "transparent"
                            fillColor: sector.selected ? Qt.alpha(Core.Theme.secondaryContainer,0.96) : "transparent"
                            startX: sector.cx+surface.innerRadius*Math.cos(sector.start); startY: sector.cy+surface.innerRadius*Math.sin(sector.start)
                            PathLine { x: sector.cx+surface.outerRadius*Math.cos(sector.start); y: sector.cy+surface.outerRadius*Math.sin(sector.start) }
                            PathArc { x: sector.cx+surface.outerRadius*Math.cos(sector.end); y: sector.cy+surface.outerRadius*Math.sin(sector.end); radiusX: surface.outerRadius; radiusY: surface.outerRadius; direction: PathArc.Clockwise }
                            PathLine { x: sector.cx+surface.innerRadius*Math.cos(sector.end); y: sector.cy+surface.innerRadius*Math.sin(sector.end) }
                            PathArc { x: sector.cx+surface.innerRadius*Math.cos(sector.start); y: sector.cy+surface.innerRadius*Math.sin(sector.start); radiusX: surface.innerRadius; radiusY: surface.innerRadius; direction: PathArc.Counterclockwise }
                        }
                        ShapePath {
                            id: selectionArc
                            strokeWidth: Math.max(2, surface.outerRadius*0.026)
                            strokeColor: sector.selected ? Core.Theme.primary : "transparent"
                            fillColor: "transparent"
                            readonly property real arcRadius: surface.outerRadius-strokeWidth/2
                            startX: sector.cx+arcRadius*Math.cos(sector.start); startY: sector.cy+arcRadius*Math.sin(sector.start)
                            PathArc { x: sector.cx+selectionArc.arcRadius*Math.cos(sector.end); y: sector.cy+selectionArc.arcRadius*Math.sin(sector.end); radiusX: selectionArc.arcRadius; radiusY: selectionArc.arcRadius; direction: PathArc.Clockwise }
                        }
                        Item {
                            readonly property real angle: (-90+sector.index*45)*Math.PI/180
                            readonly property real distance: (surface.innerRadius+surface.outerRadius)/2
                            x: sector.cx+Math.cos(angle)*distance-width/2; y: sector.cy+Math.sin(angle)*distance-height/2
                            width: surface.outerRadius*0.185; height: width
                            Accessible.role: Accessible.MenuItem; Accessible.name: sector.modelData.label
                            Accessible.description: sector.modelData.detail; Accessible.selected: sector.selected
                            Accessible.onPressAction: { wheel.selectedIndex=sector.index;wheel.activate(); }
                            Glyph { anchors.fill: parent; sourceSize: Qt.size(width, height); ink: sector.selected ? Core.Theme.onSecondaryContainer : Core.Theme.onSurface; name: sector.modelData.icon }
                        }
                    }
                }
                Rectangle {
                    objectName: "wheelHub"; anchors.centerIn: parent; width: surface.innerRadius*2; height: width; radius: width/2
                    color: Qt.alpha(Core.Theme.surfaceContainerHigh,0.98)
                    Text {
                        anchors.centerIn: parent; width: parent.width-uiGeometry.dp(28)
                        text: wheel.selectedIndex<0 ? "Cancel" : wheel.actions[wheel.selectedIndex].label
                        color: Core.Theme.textPrimary; font.pixelSize: Math.max(uiGeometry.dp(14),surface.outerRadius*0.089); font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    }
                }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPositionChanged: mouse => wheel.point(mouse.x,mouse.y)
                onClicked: mouse => wheel.handleClick(mouse.x,mouse.y,mouse.button)

            }
        }
    }
}
