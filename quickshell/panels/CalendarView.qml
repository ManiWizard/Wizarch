pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../core" as Core
import "../core/CalendarDate.js" as Dates
import "../core/CalendarEvents.js" as Events
import "../components"
Item {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: cal
    required property var root
    property date today: new Date()
    property int viewMode: 0
    property date page: Dates.clamp(today)
    property real availableHeight: 600
    readonly property string primary: root.preferences.calendarPrimary || "gregorian"
    readonly property string secondary: root.preferences.calendarSecondary && root.preferences.calendarSecondary !== primary ? root.preferences.calendarSecondary : "off"
    readonly property string weekStart: root.preferences.calendarWeekStart || "auto"
    readonly property var events: root.preferences.calendarEvents || []
    readonly property var dayEvents: Events.forDate(events,Dates.key(page))
    readonly property bool monthView: viewMode===1
    readonly property int monthWeeks: Dates.weeks(page,primary,weekStart)
    readonly property real cellHeight: uiGeometry.dp(monthWeeks===6 ? 43 : monthWeeks===5 ? 52 : 66)
    readonly property real gridHeight: viewMode===2 ? uiGeometry.dp(312) : uiGeometry.dp(24) + (monthView ? monthWeeks*cellHeight+(monthWeeks-1)*uiGeometry.dp(4) : uiGeometry.dp(70))
    readonly property real naturalHeight: uiGeometry.dp(52)+gridHeight+(viewMode===0 ? details.height+uiGeometry.dp(12) : uiGeometry.dp(28))
    readonly property real contentHeight: Math.min(availableHeight,naturalHeight+uiGeometry.dp(44))
    property bool editing: false
    property string editingId: ""
    property string editorError: ""
    signal modeChanged()
    function reset() { viewMode=0; page=Dates.clamp(today); editing=false; editorError=""; modeChanged(); }
    function showMode(mode) { viewMode=mode; editing=false; modeChanged(); }
    function changePage(direction) { if (!Dates.canMove(page,primary,viewMode,direction)) return; page=Dates.move(page,primary,viewMode,direction); editing=false; }
    function dateAt(index) { return Dates.dateAt(page,primary,monthView,index,weekStart); }
    function select(day) { if(!Dates.supported(day))return; page=day; showMode(0); }
    function edit(event) {
        editingId=event ? event.id : ""; titleInput.text=event ? event.title : "";
        colorInput.text=event ? event.color : ""; iconInput.text=event ? event.icon : "";
        dateInput.text=event ? event.date : Dates.key(page); editorError=""; editing=true;
        Qt.callLater(()=>titleInput.forceActiveFocus());
    }
    function saveEvent() {
        var text=titleInput.text.trim(), color=colorInput.text.trim(), iso=dateInput.text.trim();
        var fields=iso.split("-"), d=new Date(Number(fields[0]),Number(fields[1])-1,Number(fields[2]),12);
        if(!text || text.length>100) {editorError="Enter a title (1–100 characters).";return;}
        if(!/^\d{4}-\d{2}-\d{2}$/.test(iso) || Dates.key(d)!==iso || !Dates.supported(d)) {editorError="Use a valid date: YYYY-MM-DD, 1901–2099.";return;}
        if(color && !/^#[0-9a-fA-F]{6}$/.test(color)) {editorError="Colour must be #RRGGBB or blank.";return;}
        if(!editingId && events.length>=500) {editorError="The local calendar holds up to 500 events.";return;}
        var event={id:editingId || Date.now().toString(36)+Math.random().toString(36).slice(2,8),date:iso,title:text,color:color,icon:iconInput.text};
        root.setPreference("calendarEvents",Events.save(events,event));page=d;editing=false;
    }
    onPrimaryChanged: { editing=false; modeChanged(); }
    Flickable {
        id: viewport
        anchors.fill: parent; contentHeight: cal.naturalHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ThemedScrollBar { policy: ScrollBar.AsNeeded; visible: viewport.contentHeight > viewport.height + 1 }
        Item {
            width: cal.width; height: cal.naturalHeight
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.dp(2); spacing: uiGeometry.dp(4)
                SettingsButton { flat: true; text: Dates.name(cal.page,cal.primary); font.pixelSize: uiGeometry.dp(14); padding: 0; implicitWidth: contentItem.implicitWidth; height: uiGeometry.dp(28); onClicked: cal.showMode(1); Accessible.name: "Choose month" }
                SettingsButton { flat: true; text: Dates.parts(cal.page,cal.primary).year; font.pixelSize: uiGeometry.dp(14); padding: 0; implicitWidth: contentItem.implicitWidth; height: uiGeometry.dp(28); onClicked: cal.showMode(2); Accessible.name: "Choose year" }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: uiGeometry.dp(34); text: cal.secondary!=="off" ? Dates.heading(cal.page,cal.secondary) : cal.primary==="solar" ? "Solar Hijri" : "Gregorian"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(10) }
            Repeater {
                model: [-1,1]
                SettingsButton {
                    required property int modelData
                    flat: true
                    x: modelData<0 ? 0 : cal.width-uiGeometry.dp(28); y: uiGeometry.dp(2); width: uiGeometry.dp(28); height: uiGeometry.dp(28); text: modelData<0 ? "‹" : "›"
                    enabled: Dates.canMove(cal.page,cal.primary,cal.viewMode,modelData)
                    Accessible.name: (modelData<0 ? "Previous" : "Next")+(cal.viewMode===2 ? " year" : cal.monthView ? " month" : " week")
                    onClicked: cal.changePage(modelData)
                }
            }
            Column {
                visible: cal.viewMode!==2; y: uiGeometry.dp(52); spacing: uiGeometry.dp(4)
                Row {
                    spacing: uiGeometry.dp(4)
                    Repeater {
                        model: 7
                        Rectangle {
                            required property int index
                            width: (cal.width-6*uiGeometry.dp(4))/7; height: uiGeometry.dp(20); radius: uiGeometry.radius("control", width, height); color: Core.Theme.surfaceContainerHigh
                            opacity: cal.monthView ? 1 : Dates.fade(index)
                            Text { anchors.centerIn: parent; text: cal.monthView ? Dates.weekdayName(parent.index,cal.primary,cal.weekStart) : Qt.formatDateTime(cal.dateAt(parent.index),"ddd"); color: (cal.monthView ? parent.index===6 : Dates.isDayOff(cal.dateAt(parent.index),cal.primary,cal.weekStart)) ? Core.Theme.error : Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(9) }
                        }
                    }
                }
                Grid {
                    columns: 7; spacing: uiGeometry.dp(4)
                    Repeater {
                        model: cal.monthView ? cal.monthWeeks*7 : 7
                        CalendarDay {
                            required property int index
                            readonly property date day: cal.dateAt(index)
                            width: (cal.width-6*uiGeometry.dp(4))/7; height: cal.monthView ? cal.cellHeight : uiGeometry.dp(70)
                            enabled: Dates.supported(day)
                            primaryText: Dates.parts(day,cal.primary).day
                            secondaryText: cal.secondary!=="off" ? Dates.parts(day,cal.secondary).day : ""
                            dayOff: Dates.isDayOff(day,cal.primary,cal.weekStart)
                            today: Dates.key(day)===Dates.key(cal.today); selected: Dates.key(day)===Dates.key(cal.page)
                            compact: cal.monthView
                            strength: cal.monthView ? Dates.parts(day,cal.primary).month===Dates.parts(cal.page,cal.primary).month ? 1 : 0.25 : Dates.fade(index)
                            events: Events.forDate(cal.events,Dates.key(day))
                            accessibleLabel: Dates.name(day,cal.primary)+" "+Dates.parts(day,cal.primary).day+", "+Dates.parts(day,cal.primary).year
                            onActivated: cal.select(day)
                        }
                    }
                }
            }
            Grid {
                visible: cal.viewMode===2; y: uiGeometry.dp(52); columns: 3; spacing: uiGeometry.dp(6)
                Repeater {
                    model: 12
                    CalendarMonthCard {
                        required property int index
                        width: (cal.width-2*uiGeometry.dp(6))/3; height: uiGeometry.dp(73.5)
                        month: Dates.fromParts(Dates.parts(cal.page,cal.primary).year,index,1,cal.primary)
                        enabled: !isNaN(month.getTime()) && Dates.supported(Dates.clamp(month)) && Dates.parts(Dates.clamp(month),cal.primary).month===index
                        opacity: enabled ? 1 : 0.25
                        selectedDate: cal.page; todayDate: cal.today; system: cal.primary; weekStart: cal.weekStart; events: cal.events
                        onActivated: { cal.page=Dates.clamp(month); cal.showMode(1); }
                    }
                }
            }
            Text { visible: cal.viewMode!==0; y: uiGeometry.dp(52)+cal.gridHeight+8; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cal.viewMode===2 ? "Choose a month · dots show local events and today" : "Choose a date · local events only"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(9) }
            Column {
                id: details; visible: cal.viewMode===0; y: uiGeometry.dp(52)+cal.gridHeight+12; width: parent.width; spacing: uiGeometry.dp(8)
                Row {
                    width: parent.width
                    Text { width: parent.width-uiGeometry.dp(138); anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(cal.page,"ddd")+" · "+Dates.name(cal.page,cal.primary)+" "+Dates.parts(cal.page,cal.primary).day; elide: Text.ElideRight; color: Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(11) }
                    SettingsButton { flat: true; text: "Today"; width: uiGeometry.dp(60); height: uiGeometry.dp(28); onClicked: cal.reset() }
                    SettingsButton { flat: true; text: "+ Event"; width: uiGeometry.dp(78); height: uiGeometry.dp(28); onClicked: cal.edit(null) }
                }
                ListView {
                    visible: cal.dayEvents.length>0 && !cal.editing; width: parent.width; height: Math.min(3,cal.dayEvents.length)*uiGeometry.dp(30)
                    model: cal.dayEvents; clip: true; boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ThemedScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: SettingsButton {
                        flat: true
                        required property var modelData
                        width: details.width; height: uiGeometry.dp(28); text: (modelData.icon || "●")+"  "+modelData.title
                        Accessible.name: "Edit local event "+modelData.title
                        onClicked: cal.edit(modelData)
                    }
                }
                Text { visible: cal.dayEvents.length>3 && !cal.editing; text: cal.dayEvents.length+" events · scroll to see all"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(9) }
                Column {
                    visible: cal.editing; width: parent.width; spacing: uiGeometry.dp(6)
                    TextField { id: titleInput; objectName: "titleInput"; width: parent.width; height: uiGeometry.dp(32); maximumLength: 100; placeholderText: "Local event title"; color: Core.Theme.textPrimary; placeholderTextColor: Core.Theme.textSecondary; Accessible.name: "Event title"; background: Rectangle { radius: uiGeometry.radius("field", width, height); color: Core.Theme.surfaceContainerHigh; border.width: titleInput.activeFocus ? 1 : 0; border.color: Core.Theme.primary } }
                    Text { text: "Event date: Gregorian YYYY-MM-DD"; color: Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(9) }
                    Row {
                        width: parent.width; spacing: uiGeometry.dp(6)
                        TextField { id: dateInput; objectName: "dateInput"; width: uiGeometry.dp(112); height: uiGeometry.dp(32); maximumLength: 10; placeholderText: "YYYY-MM-DD"; color: Core.Theme.textPrimary; placeholderTextColor: Core.Theme.textSecondary; Accessible.name: "Event civil date YYYY-MM-DD"; background: Rectangle { radius: uiGeometry.radius("field", width, height); color: Core.Theme.surfaceContainerHigh } }
                        TextField { id: iconInput; objectName: "iconInput"; width: uiGeometry.dp(67); height: uiGeometry.dp(32); maximumLength: 8; placeholderText: "Emoji"; color: Core.Theme.textPrimary; placeholderTextColor: Core.Theme.textSecondary; Accessible.name: "Optional event emoji icon"; background: Rectangle { radius: uiGeometry.radius("field", width, height); color: Core.Theme.surfaceContainerHigh } }
                        TextField { id: colorInput; objectName: "colorInput"; width: parent.width-uiGeometry.dp(191); height: uiGeometry.dp(32); maximumLength: 7; placeholderText: "#RRGGBB"; color: Core.Theme.textPrimary; placeholderTextColor: Core.Theme.textSecondary; Accessible.name: "Optional event colour"; background: Rectangle { radius: uiGeometry.radius("field", width, height); color: Core.Theme.surfaceContainerHigh } }
                    }
                    Text { visible: cal.editorError!==""; width: parent.width; text: cal.editorError; wrapMode: Text.Wrap; color: Core.Theme.error; font.pixelSize: uiGeometry.dp(10) }
                    Row {
                        spacing: uiGeometry.dp(6)
                        SettingsButton { text: "Save"; height: uiGeometry.dp(28); onClicked: cal.saveEvent() }
                        SettingsButton { text: "Cancel"; height: uiGeometry.dp(28); onClicked: cal.editing=false }
                        SettingsButton { visible: cal.editingId!==""; text: "Delete"; height: uiGeometry.dp(28); onClicked: { cal.root.setPreference("calendarEvents",Events.remove(cal.events,cal.editingId));cal.editing=false; } }
                    }
                }
                Text { visible: cal.root.preferenceError!==""; width: parent.width; text: cal.root.preferenceError; color: Core.Theme.error; wrapMode: Text.Wrap; font.pixelSize: uiGeometry.dp(10) }
                SettingsButton { visible: cal.root.preferenceError!==""; text: "Retry save"; height: uiGeometry.dp(28); onClicked: cal.root.retryPreferences() }
            }
        }
    }
}
