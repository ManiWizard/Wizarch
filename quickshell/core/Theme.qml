pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Scope {
 id: theme
 property var data: ({})
 readonly property var palette: data.colors || ({})
 readonly property string name: data.name || "Wizarch"
 readonly property string selectedId: data.id || "wizarch"
 readonly property string wallpaper: data.wallpaper || ""
 readonly property string logo: data.logo || ""
 property var catalog: []
 property string errorMessage: ""
 readonly property bool applying: applyProcess.running
 FileView {
  id: state; path: Qt.resolvedUrl("../state/active.json").toString().replace("file://", "")
  watchChanges: true
  onFileChanged: reload()
  onLoaded: { try { theme.data = JSON.parse(text()); } catch(e) { theme.errorMessage = "Theme could not be loaded"; } }
 }
 Process {
  id: listing; command: ["python3", Qt.resolvedUrl("../services/themes.py").toString().replace("file://", ""), "list"]; running: true
  stdout: StdioCollector { onStreamFinished: { try { theme.catalog = JSON.parse(text); } catch(e) {} } }
 }
 function apply(id) { if (applying) return; errorMessage=""; applyProcess.command=["python3", Qt.resolvedUrl("../services/themes.py").toString().replace("file://", ""), "apply", id]; applyProcess.running=true; }
 Process {
  id: applyProcess
  stdout: StdioCollector { onStreamFinished: { try { const r=JSON.parse(text); if (!r.ok) theme.errorMessage=r.error; else state.reload(); } catch(e) { theme.errorMessage="Theme change failed"; } } }
 }
 readonly property color background: palette.background || "#131313"
 readonly property color surface: palette.surface || "#131313"
 readonly property color surfaceDim: palette.surfaceDim || "#131313"
 readonly property color surfaceBright: palette.surfaceBright || "#393939"
 readonly property color surfaceContainerLowest: palette.surfaceContainerLowest || "#0e0e0e"
 readonly property color surfaceContainerLow: palette.surfaceContainerLow || "#1b1b1b"
 readonly property color surfaceContainer: palette.surfaceContainer || "#1f1f1f"
 readonly property color surfaceContainerHigh: palette.surfaceContainerHigh || "#2a2a2a"
 readonly property color surfaceContainerHighest: palette.surfaceContainerHighest || "#353535"
 readonly property color textPrimary: palette.onSurface || "#e2e2e2"
 readonly property color surfaceVariant: palette.surfaceVariant || "#474747"
 readonly property color textSecondary: palette.onSurfaceVariant || "#c6c6c6"
 readonly property color inverseSurface: palette.inverseSurface || "#e2e2e2"
 readonly property color inverseOnSurface: palette.inverseOnSurface || "#303030"
 readonly property color outline: palette.outline || "#919191"
 readonly property color outlineVariant: palette.outlineVariant || "#474747"
 readonly property color shadow: palette.shadow || "#000000"
 readonly property color scrim: palette.scrim || "#000000"
 readonly property color surfaceTint: palette.surfaceTint || "#c6c6c6"
 readonly property color primary: palette.primary || "#ffffff"
 readonly property color onPrimary: palette.onPrimary || "#1b1b1b"
 readonly property color primaryContainer: palette.primaryContainer || "#d4d4d4"
 readonly property color textOnPrimaryContainer: palette.onPrimaryContainer || "#000000"
 readonly property color inversePrimary: palette.inversePrimary || "#5e5e5e"
 readonly property color secondary: palette.secondary || "#c6c6c6"
 readonly property color onSecondary: palette.onSecondary || "#1b1b1b"
 readonly property color secondaryContainer: palette.secondaryContainer || "#474747"
 readonly property color onSecondaryContainer: palette.onSecondaryContainer || "#e2e2e2"
 readonly property color tertiary: palette.tertiary || "#e2e2e2"
 readonly property color onTertiary: palette.onTertiary || "#1b1b1b"
 readonly property color tertiaryContainer: palette.tertiaryContainer || "#919191"
 readonly property color onTertiaryContainer: palette.onTertiaryContainer || "#000000"
 readonly property color error: palette.error || "#ffb4ab"
 readonly property color onError: palette.onError || "#690005"
 readonly property color errorContainer: palette.errorContainer || "#93000a"
 readonly property color onErrorContainer: palette.onErrorContainer || "#ffdad6"
 readonly property color primaryFixed: palette.primaryFixed || "#5e5e5e"
 readonly property color primaryFixedDim: palette.primaryFixedDim || "#474747"
 readonly property color onPrimaryFixed: palette.onPrimaryFixed || "#ffffff"
 readonly property color onPrimaryFixedVariant: palette.onPrimaryFixedVariant || "#e2e2e2"
 readonly property color secondaryFixed: palette.secondaryFixed || "#c6c6c6"
 readonly property color secondaryFixedDim: palette.secondaryFixedDim || "#ababab"
 readonly property color onSecondaryFixed: palette.onSecondaryFixed || "#1b1b1b"
 readonly property color onSecondaryFixedVariant: palette.onSecondaryFixedVariant || "#3b3b3b"
 readonly property color tertiaryFixed: palette.tertiaryFixed || "#5e5e5e"
 readonly property color tertiaryFixedDim: palette.tertiaryFixedDim || "#474747"
 readonly property color onTertiaryFixed: palette.onTertiaryFixed || "#ffffff"
 readonly property color onTertiaryFixedVariant: palette.onTertiaryFixedVariant || "#e2e2e2"
 readonly property color divider: palette.divider || "#919191"
 readonly property color hoverSurface: palette.hoverSurface || "#474747"
 readonly property color hoverActiveSurface: palette.hoverActiveSurface || "#5e5e5e"
}
