import QtQuick
import QtQuick.Controls

Switch {
    id: control
    property bool stacked: false
    font.family: Theme.textFont
    font.pixelSize: 13
    spacing: 10
    padding: 6
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4
    indicator: Rectangle {
        objectName: control.objectName + "Track"
        implicitWidth: 44
        implicitHeight: 22
        x: control.stacked ? (control.width - width) / 2 : control.leftPadding
        y: control.stacked ? control.topPadding + 6 : (control.height - height) / 2
        radius: 11
        antialiasing: true
        color: control.checked ? Theme.paper : Theme.ink
        border.color: control.activeFocus ? Theme.paper : Theme.muted
        border.width: Theme.controlBorderWidth(control)
        border.pixelAligned: false
        Rectangle {
            width: 16
            height: 16
            x: 3 + control.visualPosition * (parent.width - width - 6)
            y: 3
            radius: 8
            color: control.checked ? Theme.ink : Theme.paper
        }
    }
    contentItem: Label {
        text: control.text
        font: control.font
        color: Theme.paper
        objectName: control.objectName + "Label"
        leftPadding: control.stacked ? 0 : control.indicator.width + control.spacing
        topPadding: control.stacked ? control.indicator.height + 14 : 0
        horizontalAlignment: control.stacked ? Text.AlignHCenter : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}