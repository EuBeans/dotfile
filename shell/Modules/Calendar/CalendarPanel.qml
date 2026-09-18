import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    property bool embedded: false
    required property date today
    property date selectedDate: today
    property int month: today.getMonth()
    property int year: today.getFullYear()
    signal closeRequested()
    implicitWidth: 380
    implicitHeight: contents.implicitHeight + 40
    color: embedded ? Ui.Theme.clear : Ui.Theme.surface
    border.color: embedded ? Ui.Theme.clear : Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius
    topLeftRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    bottomLeftRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0

    function selectDate(date) {
        selectedDate = date;
        month = date.getMonth();
        year = date.getFullYear();
    }
    function shiftMonth(offset) {
        const target = new Date(year, month + offset, 1, 12);
        const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0, 12).getDate();
        selectDate(new Date(target.getFullYear(), target.getMonth(), Math.min(selectedDate.getDate(), lastDay), 12));
    }
    function moveSelection(days) {
        selectDate(new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + days, 12));
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: panel.embedded ? 0 : 20
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: contents
            width: parent.width
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Ui.ActionButton { objectName: "calendarPrevious"; iconName: "skip-back"; description: "Previous month"; onClicked: panel.shiftMonth(-1) }
                Ui.Label {
                    objectName: "calendarMonth"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(new Date(panel.year, panel.month, 1, 12), "MMMM yyyy")
                    font.family: Ui.Theme.displayFont
                    font.pixelSize: 16
                }
                Ui.ActionButton { objectName: "calendarNext"; iconName: "skip-forward"; description: "Next month"; onClicked: panel.shiftMonth(1) }
                Ui.ActionButton { objectName: "closeCalendar"; visible: !panel.embedded; iconName: "x"; description: "Close calendar"; onClicked: panel.closeRequested() }
            }
            DayOfWeekRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                locale: grid.locale
                font.family: Ui.Theme.textFont
                palette.windowText: Ui.Theme.muted
            }
            MonthGrid {
                id: grid
                objectName: "calendarGrid"
                Layout.fillWidth: true
                Layout.preferredHeight: 234
                month: panel.month
                year: panel.year
                padding: 0
                spacing: 4
                activeFocusOnTab: true
                Accessible.name: "Calendar, " + Qt.formatDate(panel.selectedDate, "dddd, d MMMM yyyy")
                onClicked: date => {
                    panel.selectDate(new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), 12));
                    grid.forceActiveFocus();
                }
                delegate: Rectangle {
                    required property var model
                    objectName: "calendarDay" + Qt.formatDate(model.date, "yyyyMMdd")
                    readonly property bool checked: model.year === panel.selectedDate.getFullYear() && model.month === panel.selectedDate.getMonth() && model.day === panel.selectedDate.getDate()
                    color: checked ? Ui.Theme.paper : hover.hovered ? Ui.Theme.hover : Ui.Theme.clear
                    radius: Ui.Theme.radius
                    antialiasing: true
                    border.width: checked && grid.activeFocus ? Ui.Theme.controlBorderWidth(grid) : 0
                    border.pixelAligned: false
                    border.color: Ui.Theme.accent
                    opacity: model.month === panel.month ? 1 : 0.45
                    HoverHandler { id: hover }
                    Ui.Label {
                        anchors.fill: parent
                        text: String(parent.model.day)
                        color: parent.checked ? Ui.Theme.ink : Ui.Theme.paper
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: Qt.formatDate(model.date, "dddd, d MMMM yyyy")
                    Accessible.onPressAction: { panel.selectDate(new Date(model.year, model.month, model.day, 12)); grid.forceActiveFocus(); }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 12
                        height: 2
                        visible: parent.model.year === panel.today.getFullYear() && parent.model.month === panel.today.getMonth() && parent.model.day === panel.today.getDate()
                        color: parent.checked ? Ui.Theme.ink : Ui.Theme.paper
                    }
                }
                Keys.onLeftPressed: panel.moveSelection(-1)
                Keys.onRightPressed: panel.moveSelection(1)
                Keys.onUpPressed: panel.moveSelection(-7)
                Keys.onDownPressed: panel.moveSelection(7)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_PageUp) { panel.shiftMonth(-1); event.accepted = true; }
                    else if (event.key === Qt.Key_PageDown) { panel.shiftMonth(1); event.accepted = true; }
                    else if (event.key === Qt.Key_Home) { panel.selectDate(panel.today); event.accepted = true; }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
            Ui.Label {
                objectName: "calendarSelectedDate"
                Layout.fillWidth: true
                text: Qt.formatDate(panel.selectedDate, "dddd, d MMMM yyyy")
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
            Ui.ActionButton { objectName: "calendarToday"; text: "Today"; onClicked: { panel.selectDate(panel.today); grid.forceActiveFocus(); } }
        }
    }
}