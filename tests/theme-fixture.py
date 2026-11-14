"""Pure resolved QML facade fixture shared by geometry/settings regression tests."""
from pathlib import Path
import json

def write_theme(folder, src, settings=False):
    for name in ['Geometry.qml', 'Geometry.js', 'GeometryContext.qml']:
        if (src/'core'/name).exists():
            (folder/'core'/name).write_bytes((src/'core'/name).read_bytes())
    (folder/'core/Fallback.js').write_bytes((src/'core/Fallback.js').read_bytes())
    schema=json.loads((src/'themes/wizarch/colors.json').read_text())['schemes']['dark']
    api='pragma Singleton\nimport QtQuick\nimport Quickshell\nimport "Fallback.js" as Fallback\nScope {\n id:theme\n property var palette: Fallback.colors\n'
    # Use readonly alias for Qt's on* parsing, just as the production facade does.
    for role in schema:
        if role.startswith('on'):
            api+=f' readonly property alias {role}: inks.{role[2:].lower()}\n'
        else:api+=f' readonly property color {role}: palette.{role}\n'
    api+=' QtObject { id:inks;\n'+''.join(f' readonly property color {role[2:].lower()}: theme.palette.{role}\n' for role in schema if role.startswith('on'))+' }\n'
    api+=''' property color textPrimary: palette.onSurface
 property color textSecondary: palette.onSurfaceVariant
 property color textOnPrimaryContainer: palette.onPrimaryContainer
 property color background: surface
 property color divider: outlineVariant
 property color hoverSurface: surfaceContainerHigh
 property color hoverActiveSurface: secondaryContainer
 property string operationLabel: "Applying theme…"
 property bool applying: false
 property bool publishing: false
 property string errorMessage: ""
 property string selectedId: "wizarch"
 property string selectedIdentity: "bundled:wizarch"
 property string mode: "dark"
 property string wallpaperId: "arcane"
 property string wallpaper: ""
 property string logo: ""
 property string draftIdentity: ""
 property string draftMode: ""
 property string draftWallpaper: ""
 property var draftColors: palette
 property var draftWallpapers: []
 property var draftPack: ({modes:["light","dark"],valid:true})
 property bool hasDraft: false
 property string lastApplied: ""
 property real disabledControlOpacity: 0.45
 property real disabledTileOpacity: 0.55
 property var catalog: [{id:"wizarch",identity:"bundled:wizarch",name:"Wizarch",description:"Fixture",valid:true,wallpaper:"",colors:Fallback.colors,schemes:{light:Fallback.colors,dark:Fallback.colors},modes:["light","dark"]}]
 function apply(id) { lastApplied=id; }
 function preview(id) { draftIdentity=id;lastApplied=id; }
 function applyDraft() { lastApplied=draftIdentity; }
 function cancelPreview() { draftIdentity=""; }
 function refresh() {}
 function importLocal(path) {}
 function rollback() {}
 function stateColor(base,ink,hovered,pressed,focused) { return base; }
}
'''
    (folder/'core/Theme.qml').write_text(api)
