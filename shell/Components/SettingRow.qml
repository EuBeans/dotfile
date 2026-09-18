import QtQuick
import QtQuick.Layouts

GridLayout {
    id: row
    property string label: ""
    default property alias controls: fields.data
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    columns: width >= 440 ? 2 : 1
    columnSpacing: 20
    rowSpacing: 6
    Label {
        text: row.label
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        font.pixelSize: 11
        color: Theme.muted
        wrapMode: Text.WordWrap
    }
    RowLayout {
        id: fields
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 264
        spacing: 8
    }
}