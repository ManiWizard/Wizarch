pragma ComponentBehavior: Bound
import Quickshell
import "core" as Core
import "components"
ShellRoot {
 Core.SystemServices { id: services }
 Variants { model: Quickshell.screens; Wallpaper { } }
 Variants { model: Quickshell.screens; Pill { root: services } }
}
