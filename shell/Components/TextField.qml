import QtQuick
import QtQuick.Controls as Controls

Controls.TextField {
    id: field
    implicitHeight: 38
    font.family: Theme.textFont
    font.pixelSize: 12
    color: Theme.paper
    placeholderTextColor: Theme.muted
    selectionColor: Theme.paper
    selectedTextColor: Theme.ink
    padding: 10
    selectByMouse: true
    hoverEnabled: true
    background: Rectangle {
        radius: Theme.radius
        antialiasing: true
        color: field.hovered ? Theme.hover : Theme.groupSurface
        border.width: Theme.controlBorderWidth(field)
        border.pixelAligned: false
        border.color: field.activeFocus ? Theme.paper : Theme.line
        opacity: field.enabled ? 1 : 0.5
    }
}