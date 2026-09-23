pragma ComponentBehavior: Bound
import QtQuick
import "../core" as Core
import "../core/Solar.js" as Solar
Item {
    id: cal
    property date today: new Date()
    property bool monthView: false
    property date page: new Date(today.getFullYear(), today.getMonth(), today.getDate(), 12)
    signal modeChanged()
    function reset() { monthView = false; page = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 12); }
    function changePage(direction) {
        if ((page.getFullYear() <= 1901 && direction < 0) || (page.getFullYear() >= 2099 && direction > 0)) return;
        page = monthView ? new Date(page.getFullYear(), page.getMonth()+direction, 1, 12) : new Date(page.getFullYear(), page.getMonth(), page.getDate()+7*direction, 12);
    }
    function dateAt(index) {
        let start = monthView ? new Date(page.getFullYear(),page.getMonth(),1,12) : new Date(page.getFullYear(),page.getMonth(),page.getDate(),12);
        return new Date(start.getFullYear(),start.getMonth(),start.getDate()-(start.getDay()+6)%7+index,12);
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 2; text: cal.page.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy"); color: Core.Theme.textPrimary; font.pixelSize: 16; font.family: "Noto Sans" }
    MouseArea { x: 38; y: 0; width: parent.width-76; height: 36; cursorShape: Qt.PointingHandCursor; onClicked: { cal.monthView = !cal.monthView; cal.modeChanged(); } }
    Repeater {
        model: [-1,1]
        Rectangle {
            required property int modelData
            x: modelData < 0 ? 0 : cal.width-30; y: 0; width: 30; height: 30; radius: 8; color: mouse.containsMouse ? Core.Theme.hoverSurface : "transparent"
            Text { anchors.centerIn: parent; text: parent.modelData < 0 ? "‹" : "›"; color: Core.Theme.textPrimary; font.pixelSize: 22 }
            MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: cal.changePage(parent.modelData) }
        }
    }
    Grid {
        y: 44; columns: 7; spacing: 4
        Repeater { model: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]; Text { required property string modelData; width: (cal.width-24)/7; height: 20; text: modelData; horizontalAlignment: Text.AlignHCenter; color: Core.Theme.textSecondary; font.pixelSize: 10 } }
        Repeater {
            model: cal.monthView ? 42 : 7
            Rectangle {
                required property int index
                readonly property date day: cal.dateAt(index)
                readonly property bool isToday: Qt.formatDateTime(day,"yyyy-MM-dd") === Qt.formatDateTime(cal.today,"yyyy-MM-dd")
                width: (cal.width-24)/7; height: cal.monthView ? 41 : 64; radius: 8
                color: isToday ? Core.Theme.primaryContainer : dayMouse.containsMouse ? Core.Theme.hoverSurface : "transparent"
                opacity: !cal.monthView || day.getMonth() === cal.page.getMonth() ? 1 : 0.45
                Text { anchors.horizontalCenter: parent.horizontalCenter; y: cal.monthView ? 3 : 12; text: parent.day.getDate(); color: parent.isToday ? Core.Theme.textOnPrimaryContainer : Core.Theme.textPrimary; font.pixelSize: cal.monthView ? 13 : 17 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; y: cal.monthView ? 23 : 39; text: Solar.day(parent.day); color: parent.isToday ? Core.Theme.textOnPrimaryContainer : Core.Theme.textSecondary; font.pixelSize: 9 }
                MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { cal.monthView = !cal.monthView; cal.modeChanged(); } }
            }
        }
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: cal.monthView ? 342 : 148; text: "Gregorian · Solar Hijri"; color: Core.Theme.textSecondary; font.pixelSize: 9 }
}
