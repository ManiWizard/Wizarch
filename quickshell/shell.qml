pragma ComponentBehavior: Bound
import Quickshell
import "core" as Core
import "components"
ShellRoot {
 Core.SystemServices { id: services; scrollingError: nativeFrames.errorMessage }
 Core.ScrollingStackState { id: nativeFrames; sourceScript: "scrolling-frame.py" }
 Variants { model: Quickshell.screens; Wallpaper { } }
 Variants { model: Quickshell.screens; ScrollingFrameGuard { root: services; state: nativeFrames } }
 Variants { model: Quickshell.screens; Pill { root: services } }
 SettingsWindow { root: services }
 QuickWheel { onActionRequested: command => Quickshell.execDetached(command) }
}
