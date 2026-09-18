import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string iconName: ""
    property string description: text
    property bool displayType: false
    property bool iconOnly: true
    property bool grouped: false
    implicitWidth: iconName && iconOnly ? 36 : Math.max(40, implicitContentWidth + 24)
    implicitHeight: 34
    padding: 8
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: displayType ? Theme.displayFont : Theme.textFont
    font.pixelSize: 13
    font.letterSpacing: 0
    icon.source: iconName ? Qt.resolvedUrl("../Assets/Icons/" + iconName + ".svg") : ""
    icon.width: 16
    icon.height: 16
    icon.color: checked || down ? Theme.ink : Theme.paper
    display: iconName ? (iconOnly ? AbstractButton.IconOnly : AbstractButton.TextBesideIcon) : AbstractButton.TextOnly
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
    ToolTip.visible: hovered && description.length > 0
    ToolTip.delay: 500
    ToolTip.text: description
}