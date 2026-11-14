pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Fallback.js" as Fallback
Scope {
 id: theme
 property var data: ({})
 readonly property var palette: data.colors || Fallback.colors
 readonly property string name: data.name || "Built-in fallback"
 readonly property string selectedId: data.id || ""
 readonly property string selectedIdentity: data.identity || ""
 readonly property string mode: data.mode || "dark"
 readonly property string wallpaperId: data.wallpaperId || ""
 readonly property string revision: data.revision || "fallback"
 readonly property string wallpaper: data.wallpaper || ""
 readonly property string logo: data.logo || ""
 property var catalog: []
 property int catalogRetryDelay: 500
 property string catalogFailureMessage: ""
 function catalogFailure(message) {
  if (!errorMessage || errorMessage===catalogFailureMessage) errorMessage=message;
  catalogFailureMessage=message;
 }
 Timer { id: catalogRetry; interval: theme.catalogRetryDelay; onTriggered: catalogWatch.running=true }
 property string errorMessage: ""
 property string operationLabel: "Applying theme…"
 property bool publishing: false
 property var pendingRequest: null
 property bool requestInFlight: false
 readonly property bool applying: bootstrap.running || requestInFlight || applyProcess.running || pendingRequest !== null
 readonly property string script: Qt.resolvedUrl("../services/themes.py").toString().replace("file://", "")
 readonly property bool initialized: bootstrap.running === false
 readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/wizarch/theme/active.json"
 property string draftIdentity: ""
 property string draftMode: ""
 property string draftWallpaper: ""
 readonly property var selectedPack: catalog.find(p => p.identity === selectedIdentity) || null
 readonly property var draftPack: catalog.find(p => p.identity === (draftIdentity || selectedIdentity)) || null
 readonly property var draftColors: draftPack && draftPack.valid ? !hasDraft && draftPack.identity===selectedIdentity && (!draftMode || draftMode===mode) ? palette : (draftPack.previewSchemes || draftPack.schemes)[draftMode || mode] || draftPack.colors : palette
 readonly property var draftWallpapers: draftPack ? draftPack.wallpapers : []
 readonly property bool hasDraft: draftIdentity !== "" || draftMode !== "" || draftWallpaper !== ""
 function preview(identity) {
  const p = catalog.find(p => p.identity === identity);
  if (!p || !p.valid) { errorMessage = p ? p.diagnostics.join("; ") : "Theme unavailable; refresh catalog."; return; }
  draftIdentity=identity; draftMode=p.overrideMode || (p.modes.indexOf(mode)!==-1 ? mode : p.defaultMode);
  draftWallpaper=p.overrideWallpaper || (p.identity===selectedIdentity ? wallpaperId : p.defaultWallpaper); errorMessage="";
 }
 function cancelPreview() { draftIdentity=""; draftMode=""; draftWallpaper=""; }
 function applyDraft() { apply(draftIdentity || selectedIdentity, draftMode || mode, draftWallpaper || wallpaperId); }
 function apply(identity, requestedMode, requestedWallpaper) {
  pendingRequest={identity:identity,mode:requestedMode || "",wallpaper:requestedWallpaper || ""}; errorMessage="";
  dispatch.restart();
 }
 // Qt needs a desktop theme adapter on bare Hyprland. Preserve explicit adapters.
 function launchApplication(app) {
  const environment={QT_QPA_PLATFORMTHEME:Quickshell.env("QT_QPA_PLATFORMTHEME") || "gtk3"};
  const command=app.runInTerminal ? ["kitty","-e"].concat(app.command) : app.command;
  Quickshell.execDetached({command:command,workingDirectory:app.workingDirectory,environment:environment});
 }
 function setMode(value) { apply(selectedIdentity,value,wallpaperId); }
 function setWallpaper(value) { apply(selectedIdentity,mode,value); }
 function refresh() { if (!listing.running) listing.running=true; }
 function importLocal(path) {
  if (applying) return;
  if (!path || path[0]!=="/") { errorMessage="Local collection path must be absolute."; return; }
  errorMessage=""; operationLabel="Importing local collection…";
  requestInFlight=true; applyProcess.command=["python3",script,"import",path]; applyProcess.running=true;
 }
 function rollback() { if (applying) return; operationLabel="Restoring prior theme…"; requestInFlight=true; applyProcess.command=["python3",script,"rollback"]; applyProcess.running=true; }
 FileView {
  id: state; path: theme.initialized ? theme.statePath : ""; preload: theme.initialized; watchChanges: true
  onFileChanged: reload()
  onLoaded: {
   try {
    const candidate=JSON.parse(text());
    if (candidate.schemaVersion!==1 || !candidate.colors || !/^[a-f0-9]{64}$/.test(candidate.revision) || ["light","dark"].indexOf(candidate.mode)===-1 || typeof candidate.name!=="string" || !candidate.selection || candidate.identity!==candidate.selection.identity || candidate.mode!==candidate.selection.mode || !/^file:\/\/\//.test(candidate.wallpaper) || (candidate.logo && !/^file:\/\/\//.test(candidate.logo)) || Object.keys(candidate.colors).length!==Object.keys(Fallback.colors).length) throw new Error("Invalid theme snapshot");
    for (let key in Fallback.colors) if (typeof candidate.colors[key]!=="string" || !/^#[0-9a-fA-F]{6}$/.test(candidate.colors[key])) throw new Error("Missing theme role: "+key);
    theme.publishing=true; theme.data=candidate; Qt.callLater(() => theme.publishing=false);
   } catch(e) { theme.errorMessage="Theme snapshot invalid; retaining usable palette. "+e; }
  }
 }
 Process {
  id: bootstrap; command: ["python3",theme.script,"bootstrap"]; running:true
  stdout: StdioCollector { onStreamFinished: {
   try { const r=JSON.parse(text); if (!r.ok) theme.errorMessage=r.error; } catch(e) { theme.errorMessage="Theme recovery failed; run themes.py recover."; }

  } }
  onExited: { Qt.callLater(() => state.reload()); catalogWatch.running=true; }
 }
 Process {
  id: catalogWatch; command: ["python3",theme.script,"watch"]
  onExited: { theme.catalogFailure("Theme catalog disconnected; retaining current themes and retrying."); catalogRetry.restart(); theme.catalogRetryDelay=Math.min(30000,theme.catalogRetryDelay*2); }
  stdout: SplitParser { onRead: line => {
   try { const r=JSON.parse(line); if (r.ok && Array.isArray(r.catalog)) { theme.catalog=r.catalog; theme.catalogRetryDelay=500; if (theme.errorMessage===theme.catalogFailureMessage) theme.errorMessage=""; theme.catalogFailureMessage=""; } else theme.catalogFailure(r.error || "Catalog unavailable; retaining current themes."); } catch(e) { theme.catalogFailure("Catalog invalid; retaining current themes."); }
  } }
 }
 Process {
  id: listing; command: ["python3",theme.script,"refresh"]
  stdout: StdioCollector { onStreamFinished: {
   try { const r=JSON.parse(text); if (Array.isArray(r)) theme.catalog=r; else theme.errorMessage=r.error; } catch(e) { theme.errorMessage="Catalog refresh failed."; }
  } }
 }
 Timer {
  id: dispatch; interval: 25
  onTriggered: {
   if (!theme.pendingRequest || theme.requestInFlight || applyProcess.running) return;
   theme.requestInFlight=true; const r=theme.pendingRequest; theme.pendingRequest=null;
   const args=["python3",theme.script,"apply",r.identity];
   if (r.mode) args.push("--mode",r.mode); if (r.wallpaper) args.push("--wallpaper",r.wallpaper);
   theme.operationLabel="Applying theme…"; applyProcess.command=args; applyProcess.running=true;
  }
 }
 Process {
  id: applyProcess
  stdout: StdioCollector { onStreamFinished: {
   try { const r=JSON.parse(text); if (!r.ok) theme.errorMessage=r.error; else { theme.errorMessage=r.warning || ""; state.reload(); theme.cancelPreview(); } } catch(e) { theme.errorMessage="Theme operation failed; previous snapshot retained."; }
  } }
  onExited: (exitCode, exitStatus) => { theme.requestInFlight=false; if (exitCode!==0 && !theme.errorMessage) theme.errorMessage="Theme process interrupted. Use Refresh or restart for recovery."; dispatch.restart(); }
 }
 // Material state maxima; lower the layer when an approved exported foreground is near 4.5:1.
 readonly property real hoverOpacity: 0.08
 readonly property real focusOpacity: 0.10
 readonly property real pressedOpacity: 0.10
 readonly property real disabledControlOpacity: 0.45
 readonly property real disabledTileOpacity: 0.55
 function luminance(c) {
  const a=[c.r,c.g,c.b].map(v => v<=0.04045 ? v/12.92 : Math.pow((v+0.055)/1.055,2.4));
  return a[0]*0.2126+a[1]*0.7152+a[2]*0.0722;
 }
 function contrast(a,b) { const x=luminance(a),y=luminance(b); return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05); }
 function composite(base, ink, alpha) { return Qt.rgba(Math.round((ink.r*alpha+base.r*(1-alpha))*255)/255,Math.round((ink.g*alpha+base.g*(1-alpha))*255)/255,Math.round((ink.b*alpha+base.b*(1-alpha))*255)/255,1); }
 function stateColor(base, ink, hovered, pressed, focused) {
  let alpha=pressed ? pressedOpacity : focused ? focusOpacity : hovered ? hoverOpacity : 0;
  let result=composite(base,ink,alpha);
  while (alpha>0 && contrast(ink,result)<4.5) { alpha=Math.max(0,alpha-0.01); result=composite(base,ink,alpha); }
  return result;
 }
 readonly property color primary: palette.primary || Fallback.colors.primary
 readonly property alias onPrimary: inks.primary
 readonly property color primaryContainer: palette.primaryContainer || Fallback.colors.primaryContainer
 readonly property alias onPrimaryContainer: inks.primarycontainer
 readonly property color inversePrimary: palette.inversePrimary || Fallback.colors.inversePrimary
 readonly property color secondary: palette.secondary || Fallback.colors.secondary
 readonly property alias onSecondary: inks.secondary
 readonly property color secondaryContainer: palette.secondaryContainer || Fallback.colors.secondaryContainer
 readonly property alias onSecondaryContainer: inks.secondarycontainer
 readonly property color tertiary: palette.tertiary || Fallback.colors.tertiary
 readonly property alias onTertiary: inks.tertiary
 readonly property color tertiaryContainer: palette.tertiaryContainer || Fallback.colors.tertiaryContainer
 readonly property alias onTertiaryContainer: inks.tertiarycontainer
 readonly property color primaryFixed: palette.primaryFixed || Fallback.colors.primaryFixed
 readonly property color primaryFixedDim: palette.primaryFixedDim || Fallback.colors.primaryFixedDim
 readonly property alias onPrimaryFixed: inks.primaryfixed
 readonly property alias onPrimaryFixedVariant: inks.primaryfixedvariant
 readonly property color secondaryFixed: palette.secondaryFixed || Fallback.colors.secondaryFixed
 readonly property color secondaryFixedDim: palette.secondaryFixedDim || Fallback.colors.secondaryFixedDim
 readonly property alias onSecondaryFixed: inks.secondaryfixed
 readonly property alias onSecondaryFixedVariant: inks.secondaryfixedvariant
 readonly property color tertiaryFixed: palette.tertiaryFixed || Fallback.colors.tertiaryFixed
 readonly property color tertiaryFixedDim: palette.tertiaryFixedDim || Fallback.colors.tertiaryFixedDim
 readonly property alias onTertiaryFixed: inks.tertiaryfixed
 readonly property alias onTertiaryFixedVariant: inks.tertiaryfixedvariant
 readonly property color error: palette.error || Fallback.colors.error
 readonly property alias onError: inks.error
 readonly property color errorContainer: palette.errorContainer || Fallback.colors.errorContainer
 readonly property alias onErrorContainer: inks.errorcontainer
 readonly property color surface: palette.surface || Fallback.colors.surface
 readonly property alias onSurface: inks.surface
 readonly property alias onSurfaceVariant: inks.surfacevariant
 readonly property color surfaceDim: palette.surfaceDim || Fallback.colors.surfaceDim
 readonly property color surfaceBright: palette.surfaceBright || Fallback.colors.surfaceBright
 readonly property color surfaceContainerLowest: palette.surfaceContainerLowest || Fallback.colors.surfaceContainerLowest
 readonly property color surfaceContainerLow: palette.surfaceContainerLow || Fallback.colors.surfaceContainerLow
 readonly property color surfaceContainer: palette.surfaceContainer || Fallback.colors.surfaceContainer
 readonly property color surfaceContainerHigh: palette.surfaceContainerHigh || Fallback.colors.surfaceContainerHigh
 readonly property color surfaceContainerHighest: palette.surfaceContainerHighest || Fallback.colors.surfaceContainerHighest
 readonly property color inverseSurface: palette.inverseSurface || Fallback.colors.inverseSurface
 readonly property color inverseOnSurface: palette.inverseOnSurface || Fallback.colors.inverseOnSurface
 readonly property color outline: palette.outline || Fallback.colors.outline
 readonly property color outlineVariant: palette.outlineVariant || Fallback.colors.outlineVariant
 readonly property color shadow: palette.shadow || Fallback.colors.shadow
 readonly property color scrim: palette.scrim || Fallback.colors.scrim
 readonly property color surfaceTint: palette.surfaceTint || Fallback.colors.surfaceTint
 QtObject {
  id: inks
  readonly property color primary: theme.palette.onPrimary || Fallback.colors.onPrimary
  readonly property color primarycontainer: theme.palette.onPrimaryContainer || Fallback.colors.onPrimaryContainer
  readonly property color secondary: theme.palette.onSecondary || Fallback.colors.onSecondary
  readonly property color secondarycontainer: theme.palette.onSecondaryContainer || Fallback.colors.onSecondaryContainer
  readonly property color tertiary: theme.palette.onTertiary || Fallback.colors.onTertiary
  readonly property color tertiarycontainer: theme.palette.onTertiaryContainer || Fallback.colors.onTertiaryContainer
  readonly property color primaryfixed: theme.palette.onPrimaryFixed || Fallback.colors.onPrimaryFixed
  readonly property color primaryfixedvariant: theme.palette.onPrimaryFixedVariant || Fallback.colors.onPrimaryFixedVariant
  readonly property color secondaryfixed: theme.palette.onSecondaryFixed || Fallback.colors.onSecondaryFixed
  readonly property color secondaryfixedvariant: theme.palette.onSecondaryFixedVariant || Fallback.colors.onSecondaryFixedVariant
  readonly property color tertiaryfixed: theme.palette.onTertiaryFixed || Fallback.colors.onTertiaryFixed
  readonly property color tertiaryfixedvariant: theme.palette.onTertiaryFixedVariant || Fallback.colors.onTertiaryFixedVariant
  readonly property color error: theme.palette.onError || Fallback.colors.onError
  readonly property color errorcontainer: theme.palette.onErrorContainer || Fallback.colors.onErrorContainer
  readonly property color surface: theme.palette.onSurface || Fallback.colors.onSurface
  readonly property color surfacevariant: theme.palette.onSurfaceVariant || Fallback.colors.onSurfaceVariant
 }
 // Compatibility aliases: canonical roles always win; legacy custom roles are not alternate sources.
 readonly property color background: surface
 readonly property alias onBackground: inks.surface
 readonly property color surfaceVariant: surfaceContainerHighest
 readonly property color textPrimary: onSurface
 readonly property color textSecondary: onSurfaceVariant
 readonly property color textOnPrimaryContainer: onPrimaryContainer
 readonly property color divider: outlineVariant
 readonly property color hoverSurface: stateColor(surfaceContainerHigh,onSurface,true,false,false)
 readonly property color hoverActiveSurface: stateColor(secondaryContainer,onSecondaryContainer,true,false,false)
}
