import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: section
    property string title: ""
    property bool expanded: true
    default property alias content: body.data
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredWidth: 0
    spacing: 12

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.line
    }
    ActionButton {
        id: header
        objectName: section.objectName + "Toggle"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.maximumWidth: section.width
        implicitHeight: 38
        text: section.title
        description: (section.expanded ? "Collapse " : "Expand ") + section.title
        Accessible.description: section.expanded ? "Expanded" : "Collapsed"
        onClicked: section.expanded = !section.expanded
        contentItem: RowLayout {
            Label {
                text: section.title
                Layout.fillWidth: true
                font.bold: true
                font.family: Theme.textFont
                color: header.down ? Theme.ink : Theme.paper
            }
            Label {
                text: section.expanded ? "-" : "+"
                color: header.down ? Theme.ink : Theme.paper
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 20
            }
        }
    }
    ColumnLayout {
        id: body
        visible: section.expanded
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: Math.max(0, section.width - 16)
        Layout.maximumWidth: Math.max(0, section.width - 16)
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.bottomMargin: 8
        spacing: 12
    }
}
