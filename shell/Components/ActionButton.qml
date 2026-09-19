import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string iconName: ""
    property string iconSource: ""
    property string description: text
    property bool displayType: false
    property bool iconOnly: true
    property bool grouped: false
    implicitWidth: (iconName || iconSource) && iconOnly ? 36 : Math.max(40, implicitContentWidth + 24)
    implicitHeight: 34
    padding: 8
    hoverEnabled: true
    // TabFocus (not StrongFocus) so a mouse click doesn't leave a stuck focus ring/border
    focusPolicy: Qt.TabFocus
    font.family: displayType ? Theme.displayFont : Theme.textFont
    font.pixelSize: 13
    font.letterSpacing: 0
    icon.source: iconSource || (iconName ? Qt.resolvedUrl("../Assets/Icons/" + iconName + ".svg") : "")
    icon.width: 16
    icon.height: 16
    icon.color: iconSource ? "transparent" : checked || down ? Theme.ink : Theme.paper
    display: iconName || iconSource ? (iconOnly ? AbstractButton.IconOnly : AbstractButton.TextBesideIcon) : AbstractButton.TextOnly
    palette.buttonText: checked || down ? Theme.ink : Theme.paper
    palette.brightText: Theme.ink
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        radius: Theme.radius
        antialiasing: true
        color: control.checked || control.down ? Theme.paper : control.hovered ? Theme.hover : control.grouped ? Theme.groupSurface : Theme.clear
        border.width: control.activeFocus ? Theme.controlBorderWidth(control) : 0
        border.pixelAligned: false
        border.color: Theme.paper
    }
    Accessible.name: description
}