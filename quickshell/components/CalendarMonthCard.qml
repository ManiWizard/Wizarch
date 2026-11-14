pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
import "../core/CalendarDate.js" as Dates
import "../core/CalendarEvents.js" as Events
Rectangle {
    property var uiGeometry: Core.Geometry.contextFor(parent)

    id: card
    property date month
    property date selectedDate
    property date todayDate
    property string system: "gregorian"
    property string weekStart: "auto"
    property var events: []
    readonly property bool selected: Dates.heading(month,system)===Dates.heading(selectedDate,system)
    readonly property bool current: Dates.heading(month,system)===Dates.heading(todayDate,system)
    signal activated()
    radius: uiGeometry.radius("navigation", width, height); color: selected ? Core.Theme.primaryContainer : pointer.containsMouse ? Core.Theme.hoverSurface : Core.Theme.surfaceContainer
    border.width: activeFocus || current ? 1 : 0; border.color: Core.Theme.primary
    activeFocusOnTab: enabled; Accessible.role: Accessible.Button; Accessible.name: Dates.heading(month,system)
    Accessible.onPressAction: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()
    Text { x: uiGeometry.dp(8); y: uiGeometry.dp(5); width: parent.width-uiGeometry.dp(14); text: Dates.name(card.month,card.system); elide: Text.ElideRight; color: card.selected ? Core.Theme.textOnPrimaryContainer : Core.Theme.textPrimary; font.pixelSize: uiGeometry.dp(10); font.weight: Font.DemiBold }
    Grid {
        x: uiGeometry.dp(9); y: uiGeometry.dp(25); columns: 7; spacing: uiGeometry.dp(2)
        Repeater {
            model: 42
            Rectangle {
                required property int index
                readonly property date day: Dates.dateAt(card.month,card.system,true,index,card.weekStart)
                readonly property bool inside: Dates.parts(day,card.system).month===Dates.parts(card.month,card.system).month
                readonly property bool marked: Events.forDate(card.events,Dates.key(day)).length>0
                width: (card.width-2*uiGeometry.dp(9)-6*uiGeometry.dp(2))/7; height: uiGeometry.dp(3); radius: uiGeometry.radius("insertionMarker", width, height)
                opacity: inside && Dates.supported(day) ? 1 : 0.10
                color: Dates.isDayOff(day,card.system,card.weekStart) ? (card.color.r*0.299+card.color.g*0.587+card.color.b*0.114 > 0.5 ? "#b3261e" : "#ffb4ab") : Dates.key(day)===Dates.key(card.todayDate) || marked ? Core.Theme.primary : card.selected ? Qt.alpha(Core.Theme.textOnPrimaryContainer,0.35) : Qt.alpha(Core.Theme.textSecondary,0.30)
            }
        }
    }
    Text { x: uiGeometry.dp(8); y: parent.height-uiGeometry.dp(13); text: card.current ? "CURRENT" : Dates.monthDays(card.month,card.system)+" days"; color: card.selected ? Core.Theme.textOnPrimaryContainer : Core.Theme.textSecondary; font.pixelSize: uiGeometry.dp(7) }
    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.activated() }
}
