pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: state
    property string sourceScript: "scrolling-stack.py"
    property var monitors: ({})
    property string serialized: ""
    readonly property string errorMessage: reader.errorMessage
    function refresh() { reader.request(); }
    StateReader {
        id: reader
        label: "Scrolling frame state"
        command: ["python3", Qt.resolvedUrl("../services/" + state.sourceScript).toString().replace("file://", ""), "--snapshot"]
        validate: value => value !== null && typeof value === "object" && !Array.isArray(value)
        onAccepted: value => {
            const text=JSON.stringify(value);
            if (text !== state.serialized) {
                state.serialized=text;
                state.monitors=value;
                Hyprland.refreshToplevels();
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["activewindowv2", "openwindow", "closewindow", "movewindowv2",
                 "workspacev2", "focusedmon", "focusedmonv2", "fullscreen", "changefloatingmode",
                 "activespecial", "activespecialv2", "monitoraddedv2", "monitorremoved",
                 "configreloaded"].indexOf(event.name) !== -1) reader.request();
        }
    }
}
