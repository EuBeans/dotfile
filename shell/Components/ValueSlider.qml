import QtQuick
import QtQuick.Controls

Slider {
    id: control
    implicitHeight: 30
    orientation: Qt.Horizontal
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        objectName: control.objectName + "Track"
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: 6
        radius: 3
        color: Theme.ink
        antialiasing: true
        border.width: Theme.controlBorderWidth(control)
        border.pixelAligned: false
        border.color: control.activeFocus ? Theme.paper : Theme.line
        Rectangle {
            objectName: control.objectName + "Fill"
            x: control.mirrored ? parent.width - width : 0
            width: parent.width * control.position
            height: parent.height
            radius: 3
            color: Theme.paper
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + (control.availableHeight - height) / 2
        width: 12
        height: 18
        radius: 3
        color: Theme.paper
        antialiasing: true
        border.width: Theme.controlBorderWidth(control)
        border.pixelAligned: false
        border.color: Theme.ink
    }
}