pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../core" as Core
import "../components"

Flickable {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: settings
    required property var root
    property string page: "appearance"
    property string owningOutput: ""
    contentHeight: content.implicitHeight + 64
    clip: true; boundsBehavior: Flickable.StopAtBounds
    onPageChanged: contentY=0
    ScrollBar.vertical: ThemedScrollBar { policy: ScrollBar.AsNeeded }
    Column {
        id: content; x: (parent.width - width) / 2; y: uiGeometry.dp(32)
        width: Math.min(uiGeometry.dp(900), Math.max(uiGeometry.dp(280), settings.width - (settings.width < uiGeometry.dp(500) ? uiGeometry.dp(32) : uiGeometry.dp(64))))
        spacing: uiGeometry.dp(28)
        Column {
            visible: settings.page === "appearance"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                id: interfaceScaleSection; width: parent.width; title: "Interface size"
                description: "Scale the interface on a selected display. Other displays keep their own size."
                property string selectedOutput: settings.owningOutput
                Connections { target: Quickshell
                    function onScreensChanged() {
                        if (!Quickshell.screens.some(output => output.name===interfaceScaleSection.selectedOutput))
                            interfaceScaleSection.selectedOutput = Quickshell.screens.some(output => output.name===settings.owningOutput) ? settings.owningOutput : "";
                    }
                }
                SettingsChoice {
                    width: parent.width; model: Quickshell.screens.map(output => output.name)
                    currentIndex: model.indexOf(interfaceScaleSection.selectedOutput)
                    Accessible.name: "Display for interface scaling"
                    onActivated: index => interfaceScaleSection.selectedOutput = model[index]
                }
                SettingsChoice {
                    width: parent.width; model: ["100%", "125%", "150%", "175%", "200%"]
                    currentIndex: Math.round((Core.Geometry.scaleForOutput(interfaceScaleSection.selectedOutput)-1)*4)
                    enabled: interfaceScaleSection.selectedOutput !== ""
                    Accessible.name: "Interface scale"
                    onActivated: index => {
                        if (!interfaceScaleSection.selectedOutput || !Quickshell.screens.some(output=>output.name===interfaceScaleSection.selectedOutput)) return;
                        const values = Object.assign({}, settings.root.preferences.uiScaleByOutput || ({}));
                        values[interfaceScaleSection.selectedOutput] = 1 + index/4;
                        settings.root.setPreference("uiScaleByOutput", values);
                    }
                }
            }
            SettingsSection {
                width: parent.width; title: "Style"
                description: "Preview a local theme, then apply its colors and selected wallpaper. Geometry stays unchanged."
                GridLayout {
                    width: parent.width; columns: width >= 540 ? 2 : 1; columnSpacing: uiGeometry.dp(18); rowSpacing: uiGeometry.dp(18)
                    Repeater {
                        model: Core.Theme.catalog
                        SettingsThemeCard {
                            required property var modelData; theme: Object.assign({},modelData,{colors:modelData.valid ? (modelData.previewSchemes || modelData.schemes)[Core.Theme.draftMode || modelData.overrideMode || Core.Theme.mode] || modelData.colors : Core.Theme.palette})
                            Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
                            selected: modelData.identity === (Core.Theme.draftIdentity || Core.Theme.selectedIdentity)
                            onActivated: Core.Theme.preview(modelData.identity)
                        }
                    }
                }
                Text { visible: Core.Theme.applying || Core.Theme.errorMessage !== ""; width: parent.width; text: Core.Theme.applying ? Core.Theme.operationLabel : Core.Theme.errorMessage; textFormat: Text.PlainText; color: Core.Theme.errorMessage ? Core.Theme.error : Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(13); wrapMode: Text.Wrap }
            }
            SettingsSection {
                width: parent.width; title: "Theme colours"; description: "The current theme’s accent and supporting colours."
                Flow {
                    width: parent.width; spacing: uiGeometry.dp(20)
                    Repeater {
                        model: [{name:"Primary / accent",color:Core.Theme.draftColors.primary},{name:"Secondary",color:Core.Theme.draftColors.secondary},{name:"Tertiary",color:Core.Theme.draftColors.tertiary}]
                        Row {
                            required property var modelData; spacing: uiGeometry.dp(10)
                            Rectangle { width: uiGeometry.dp(30); height: uiGeometry.dp(30); radius: uiGeometry.radius("control", width, height); color: parent.modelData.color }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.name; font.pixelSize: uiGeometry.dp(14); color: Core.Theme.textPrimary }
                        }
                    }
                }
            }
            SettingsSection {
                width: parent.width; title: "Mode and wallpaper"
                description: "Preview changes locally here. Apply also sets the desktop light/dark preference for apps following the system; Cancel or closing Settings discards the preview. Wallpaper changes keep the chosen palette."
                SettingsChoice {
                    width: parent.width; model: Core.Theme.draftPack ? Core.Theme.draftPack.modes : ["dark"]
                    currentIndex: model.indexOf(Core.Theme.draftMode || Core.Theme.mode)
                    Accessible.name: "Theme mode"
                    onActivated: index => Core.Theme.draftMode=model[index]
                }
                GridLayout {
                    width: parent.width; columns: width >= 500 ? 3 : width >= 340 ? 2 : 1; columnSpacing: uiGeometry.dp(14); rowSpacing: uiGeometry.dp(14)
                    Repeater {
                        model: Core.Theme.draftWallpapers
                        SettingsThemeCard {
                            required property var modelData
                            theme: ({name:modelData.name,description:"Wallpaper preview",wallpaper:modelData.url,colors:Core.Theme.draftColors,valid:true})
                            wallpaperOnly: true; Layout.fillWidth: true; Layout.preferredHeight: implicitHeight
                            selected: modelData.id === (Core.Theme.draftWallpaper || Core.Theme.wallpaperId)
                            onActivated: Core.Theme.draftWallpaper=modelData.id
                        }
                    }
                }
                Row {
                    spacing: uiGeometry.dp(10)
                    SettingsButton { text: "Apply"; enabled: !Core.Theme.applying && !!Core.Theme.draftPack && Core.Theme.draftPack.valid; onClicked: Core.Theme.applyDraft() }
                    SettingsButton { text: "Cancel preview"; enabled: Core.Theme.hasDraft && !Core.Theme.applying; onClicked: Core.Theme.cancelPreview() }
                    SettingsButton { text: "Refresh"; enabled: !Core.Theme.applying; onClicked: Core.Theme.refresh() }
                    SettingsButton { text: "Roll back"; enabled: !Core.Theme.applying; onClicked: Core.Theme.rollback() }
                }
            }
            SettingsSection {
                width: parent.width; title: "Theme sources"
                description: "Import a local collection folder containing catalog.json. GitHub URL sources and automatic updates are planned and unavailable in this build."
                TextField {
                    id: localCollection; width: parent.width; placeholderText: "/absolute/path/to/collection"; enabled: !Core.Theme.applying
                    color: Core.Theme.onSurface; placeholderTextColor: Core.Theme.onSurfaceVariant
                    selectionColor: Core.Theme.primaryContainer; selectedTextColor: Core.Theme.onPrimaryContainer
                    background: Rectangle { radius: uiGeometry.radius("field", width, height); color: Core.Theme.surfaceContainerHighest; border.width: localCollection.activeFocus ? uiGeometry.dp(2) : 1; border.color: localCollection.activeFocus ? Core.Theme.primary : Core.Theme.outlineVariant }
                    Accessible.name: "Local theme collection folder"
                }
                SettingsButton { text: "Import local collection"; enabled: !Core.Theme.applying && localCollection.text.trim().length>0; onClicked: Core.Theme.importLocal(localCollection.text.trim()) }
            }
        }

        Column {
            visible: settings.page === "calendar"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                width: parent.width; title: "Calendar systems"
                description: "The primary calendar sets month boundaries, navigation and the year overview. Choose weekday order and the weekly day off independently below. Supported dates: 1901–2099."
                SettingsRow {
                    width: parent.width; label: "Primary calendar"; description: "Date headings and navigation"
                    SettingsChoice {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width
                        model: ["Gregorian", "Solar Hijri"]; currentIndex: settings.root.preferences.calendarPrimary === "solar" ? 1 : 0
                        Accessible.name: "Primary calendar"
                        onActivated: index => settings.root.setCalendarSystems(index === 1 ? "solar" : "gregorian", settings.root.preferences.calendarSecondary || "off")
                    }
                }
                SettingsRow {
                    width: parent.width; label: "Secondary calendar"; description: "Optional supplementary dates; choosing the primary switches this off."
                    SettingsChoice {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width
                        model: ["Off", "Gregorian", "Solar Hijri"]; currentIndex: ["off","gregorian","solar"].indexOf(settings.root.preferences.calendarSecondary || "off")
                        Accessible.name: "Secondary calendar"
                        onActivated: index => settings.root.setCalendarSystems(settings.root.preferences.calendarPrimary || "gregorian", ["off","gregorian","solar"][index])
                    }
                }
            }
            SettingsSection {
                width: parent.width; title: "Weekday style"
                description: "The style sets weekday order and marks the last day of each week red as the weekly day off. The opening view keeps the selected date centered."
                SettingsRow {
                    width: parent.width; label: "Weekday style"; description: "Iranian: Friday off. Monday-first: Sunday off. Sunday-first: Saturday off."
                    SettingsChoice {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width
                        model: ["Follow calendar", "Iranian · Sat–Fri", "Mon–Sun", "Sun–Sat"]
                        currentIndex: Math.max(0,["auto","saturday","monday","sunday"].indexOf(settings.root.preferences.calendarWeekStart || "auto"))
                        Accessible.name: "Weekday style"
                        onActivated: index => settings.root.setPreference("calendarWeekStart",["auto","saturday","monday","sunday"][index])
                    }
                }
            }
            SettingsSection {
                width: parent.width; title: "Local events"
                description: "Select a date in the pill, then use + Event to add a title, optional emoji and colour. Events stay on this device and follow the same civil date in either calendar. Up to 500 entries."
            }
        }
        Column {
            visible: settings.page === "panel"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                width: parent.width; title: "Placement"
                SettingsRow {
                    width: parent.width; label: "Panel placement"; description: "Connect the pill to the screen edge or let it float."
                    SettingsChoice { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width; model: ["Connected to edge","Floating"]; currentIndex: settings.root.preferences.edgeConnected !== false ? 0 : 1; Accessible.name: "Panel placement"; onActivated: index => settings.root.setPreference("edgeConnected",index===0) }
                }
            }
            SettingsSection {
                width: parent.width; title: "Auto-hide"
                SettingsRow {
                    width: parent.width; label: "Auto-hide panel"; description: "Reveal at the top centre. Open panels stay visible."; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: settings.root.preferences.autoHide===true; Accessible.name: "Auto-hide panel"; onToggled: settings.root.setPreference("autoHide",checked) }
                }
                SettingsRow {
                    width: parent.width; label: "Reveal behaviour"; description: "Make room for the panel or reveal it over windows."
                    SettingsChoice { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width; enabled: settings.root.preferences.autoHide===true; model: ["Push windows","Overlay windows"]; currentIndex: settings.root.preferences.revealMode==="overlay" ? 1 : 0; Accessible.name: "Reveal behaviour"; onActivated: index => settings.root.setPreference("revealMode",index===1 ? "overlay" : "push") }
                }
                SettingsRow {
                    width: parent.width; label: "Hide on empty monitors"; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; enabled: settings.root.preferences.autoHide===true; checked: settings.root.preferences.hideOnEmptyMonitor===true; Accessible.name: "Hide on empty monitors"; onToggled: settings.root.setPreference("hideOnEmptyMonitor",checked) }
                }
            }
            SettingsSection {
                visible: settings.root.preferences.edgeConnected !== false; width: parent.width; title: "Screen frame"
                SettingsRow {
                    width: parent.width; label: "Screen border"; description: "Keep a continuous frame around the monitor."; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: settings.root.preferences.screenBorder===true; Accessible.name: "Screen border"; onToggled: settings.root.setPreference("screenBorder",checked) }
                }
                SettingsSlider { width: parent.width; label: "Border thickness"; minimum: 1; maximum: 10; unit: " px"; available: settings.root.preferences.screenBorder===true; level: settings.root.preferences.borderThickness || 3; onEdited: value => settings.root.setPreference("borderThickness",Math.round(value)) }
                SettingsRow {
                    width: parent.width; label: "Match window corners"; description: "Follow Hyprland’s window rounding automatically."; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; enabled: settings.root.preferences.screenBorder===true; checked: settings.root.preferences.matchWindowCorners!==false; Accessible.name: "Match window corners"; onToggled: settings.root.setPreference("matchWindowCorners",checked) }
                }
                SettingsSlider { width: parent.width; label: "Inner corner radius"; minimum: 0; maximum: 40; unit: " px"; available: settings.root.preferences.screenBorder===true && settings.root.preferences.matchWindowCorners===false; level: settings.root.preferences.borderRadius===undefined ? 12 : settings.root.preferences.borderRadius; onEdited: value => settings.root.setPreference("borderRadius",Math.round(value)) }
            }
        }
        Column {
            visible: settings.page === "sound"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                width: parent.width; title: "Playback"
                SettingsRow {
                    width: parent.width; label: "Sound"; description: "Enable or mute playback sound."; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; enabled: !!settings.root.sink && !!settings.root.sink.audio; checked: settings.root.audioOn; Accessible.name: "Sound"; onToggled: if (settings.root.sink && settings.root.sink.audio) settings.root.sink.audio.muted=!checked }
                }
                SettingsSlider { width: parent.width; label: "Volume"; minimum: 0; maximum: 150; available: !!settings.root.sink && !!settings.root.sink.audio; level: available ? settings.root.sink.audio.volume*100 : 0; onEdited: value => { if (settings.root.sink && settings.root.sink.audio) settings.root.sink.audio.volume=value/100; } }
            }
            SettingsSection {
                width: parent.width; title: "Input"
                SettingsRow {
                    width: parent.width; label: "Microphone"; description: settings.root.mic ? settings.root.mic.description : "No microphone available"; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; enabled: !!settings.root.mic && !!settings.root.mic.audio; checked: settings.root.micOn; Accessible.name: "Microphone"; onToggled: if (settings.root.mic && settings.root.mic.audio) settings.root.mic.audio.muted=!checked }
                }
                SettingsSlider { width: parent.width; label: "Input volume"; available: !!settings.root.mic && !!settings.root.mic.audio; level: available ? settings.root.mic.audio.volume*100 : 0; onEdited: value => { if (settings.root.mic && settings.root.mic.audio) settings.root.mic.audio.volume=value/100; } }
            }
            SettingsSection {
                width: parent.width; title: "Sound mode"
                SettingsRow {
                    width: parent.width; label: "Audio mode"; description: "Sound, quiet alerts, or mute"; controlWidth: 100
                    SettingsButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: settings.root.preferences.audioMode; Accessible.name: "Change audio mode"; onClicked: settings.root.cycleAudioMode() }
                }
            }
        }
        Column {
            visible: settings.page === "notifications"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                width: parent.width; title: "Notifications"
                SettingsRow {
                    width: parent.width; label: "Do not disturb"; description: "Keep notification alerts silent."; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: settings.root.preferences.dnd===true; Accessible.name: "Do not disturb"; onToggled: settings.root.setPreference("dnd",checked) }
                }
                SettingsRow {
                    width: parent.width; label: "Notification sounds"; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: settings.root.preferences.notificationSounds; Accessible.name: "Notification sounds"; onToggled: settings.root.setPreference("notificationSounds",checked) }
                }
                SettingsSlider { width: parent.width; label: "Alert volume"; level: settings.root.preferences.systemVolume; onEdited: value => settings.root.setPreference("systemVolume",Math.round(value)) }
                SettingsRow {
                    width: parent.width; label: "Alert pattern"
                    SettingsChoice {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width; model: ["Single","Double","Triple"]
                        currentIndex: ["single","double","triple"].indexOf(settings.root.preferences.alertPattern)
                        Accessible.name: "Alert pattern"
                        onActivated: index => settings.root.setPreference("alertPattern",["single","double","triple"][index])
                    }
                }
                SettingsButton { text: "Test alert"; onClicked: settings.root.playAlert() }
            }
        }
        Column {
            visible: settings.page === "multitasking"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                width: parent.width; title: "Window spacing"
                SettingsSlider { width: parent.width; label: "Window spacing"; minimum: 0; maximum: 150; level: settings.root.preferences.windowSpacing===undefined ? 75 : settings.root.preferences.windowSpacing; description: settings.root.spacingError || "100% restores the original spacing."; onEdited: value => settings.root.setWindowSpacing(value) }
                Text {
                    property real scale: (settings.root.preferences.windowSpacing===undefined ? 75 : settings.root.preferences.windowSpacing)/100
                    text: "Between windows: " + Math.round(5*scale) + " px · Outer gap: " + Math.round(20*scale) + " px"
                    color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(13)
                }
            }
            SettingsSection {
                width: parent.width; title: "Workspaces"; description: "Each monitor has nine independent workspaces. Switching one monitor leaves the others in place."
                Repeater {
                    model: Quickshell.screens
                    SettingsRow {
                        required property var modelData; width: parent.width; label: modelData.name
                        description: "Nine workspaces · Current: " + Core.Workspaces.forMonitor(modelData.name).current
                        controlWidth: 1
                    }
                }
            }
            SettingsSection {
                width: parent.width; title: "Tiling and Scrolling"
                Text { width: parent.width; text: "Use Super+Ctrl+L to change the current workspace’s layout. Scrolling keeps one large window with small real-window peeks at the sides."; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(14); wrapMode: Text.Wrap; lineHeight: 1.3 }
            }
        }
        Column {
            visible: settings.page === "displays"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                width: parent.width; title: "Connected displays"
                Repeater {
                    model: Quickshell.screens
                    SettingsRow {
                        required property var modelData; width: parent.width; label: modelData.name
                        description: modelData.width + " × " + modelData.height + " logical pixels"; controlWidth: 1
                    }
                }
            }
            SettingsSection {
                width: parent.width; title: "Brightness"
                SettingsSlider { width: parent.width; label: "Laptop brightness"; minimum: 5; maximum: 100; available: settings.root.network.brightness>=0; level: available ? settings.root.network.brightness : 5; onEdited: value => settings.root.setBrightness(value) }
            }
        }
        Column {
            visible: settings.page === "power"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                width: parent.width; title: "Battery"
                SettingsRow { width: parent.width; label: settings.root.hasBattery ? "Battery level" : "Battery"; description: settings.root.hasBattery ? settings.root.batteryPercent + "% remaining" : "No battery detected"; controlWidth: 1 }
                SettingsRow {
                    width: parent.width; label: "Battery saver"; description: settings.root.network.batterySaverAvailable ? "Reduce power usage with the power-saver profile." : "A power-profile service is not available."; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; enabled: settings.root.network.batterySaverAvailable===true; checked: settings.root.network.batterySaver===true; Accessible.name: "Battery saver"; onToggled: settings.root.runAction("battery-saver",checked ? "on" : "off") }
                }
            }
        }
        SettingsConnectivity { visible: settings.page === "wifi"; width: parent.width; root: settings.root; wifi: true }
        SettingsConnectivity { visible: settings.page === "bluetooth"; width: parent.width; root: settings.root; wifi: false }
        Column {
            visible: settings.page === "network"; width: parent.width; spacing: uiGeometry.dp(28)
            SettingsSection {
                width: parent.width; title: "Connections"
                SettingsRow { width: parent.width; label: "Wired connection"; description: settings.root.network.ethernet ? "Connected" : "No active wired connection"; controlWidth: 1 }
                SettingsRow { width: parent.width; label: "Wi-Fi"; description: settings.root.network.wifi ? "Connected" : "Not connected"; controlWidth: 1 }
                SettingsRow {
                    width: parent.width; label: "Airplane mode"; description: "Turn off wireless radios."; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; enabled: settings.root.network.radioWritable===true; checked: settings.root.network.airplane===true; Accessible.name: "Airplane mode"; onToggled: settings.root.runAction("airplane",checked ? "on" : "off") }
                }
                SettingsRow {
                    width: parent.width; label: "Wi-Fi hotspot"; controlWidth: 50
                    SettingsSwitch { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; enabled: settings.root.network.hotspotAvailable===true; checked: settings.root.network.hotspot===true; Accessible.name: "Wi-Fi hotspot"; onToggled: settings.root.runAction("hotspot",checked ? "on" : "off") }
                }
            }
        }
        SettingsSection {
            visible: settings.page === "keyboard"; width: parent.width; title: "Keyboard shortcuts"
            Repeater {
                model: [
                    {action:"Focus a window",keys:"Super + arrows"},
                    {action:"Move window to another monitor",keys:"Super + Shift + arrows"},
                    {action:"Switch local workspace",keys:"Super + 1–9"},
                    {action:"Move window to local workspace",keys:"Super + Shift + 1–9"},
                    {action:"Cycle local workspaces",keys:"Super + scroll"},
                    {action:"Show or restore desktop",keys:"Super + D"},
                    {action:"Next / previous window",keys:"Alt + Tab / Shift + Tab"},
                    {action:"Toggle Dwindle / Scrolling",keys:"Super + Ctrl + L"},
                    {action:"Swap columns or windows",keys:"Super + Ctrl + Alt + ← / →"},
                    {action:"Change Dwindle split",keys:"Super + J"},
                    {action:"Toggle floating / tiled",keys:"Super + T / Shift + V"},
                    {action:"Fullscreen / maximize",keys:"Super + F / Alt + F"},
                    {action:"Minimize / restore",keys:"Super + M / Shift + M"},
                    {action:"Pin across workspaces",keys:"Super + O"},
                    {action:"Resize width / height",keys:"Super + − / = · Shift: height"},
                    {action:"Resize steps",keys:"Alt: 25 px · Default: 100 px · Ctrl: 300 px"},
                    {action:"Move / resize by dragging",keys:"Super + left / right mouse"},
                    {action:"Open quick-action wheel",keys:"Super + W · Arrows / Tab · Enter"},
                    {action:"Close window",keys:"Super + C"},
                    {action:"Clipboard / emoji",keys:"Super + V / ."},
                    {action:"Lock session",keys:"Super + L"}
                ]
                SettingsRow {
                    required property var modelData; width: parent.width; label: modelData.action; controlWidth: 230
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width; text: parent.parent.modelData.keys; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(13); wrapMode: Text.Wrap; horizontalAlignment: Text.AlignRight }
                }
            }
        }
        Text { visible: settings.root.actionError !== "" && ["wifi","network","sound","bluetooth","power","displays"].indexOf(settings.page)!==-1; width: parent.width; text: settings.root.actionError; color: Core.Theme.error; font.pixelSize: uiGeometry.dp(13); wrapMode: Text.Wrap }
    }
}
