import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: control
    property int from: 0
    property int to: 100
    property int stepSize: 1
    property int value: 0
    signal valueModified(int value)
    implicitWidth: 240
    Layout.preferredWidth: 220
    Layout.maximumWidth: 240
    Layout.minimumWidth: 160
    spacing: 8
    Keys.forwardTo: [number]

    ValueSlider {
        objectName: control.objectName + "Slider"
        Layout.fillWidth: true
        Layout.minimumWidth: 40
        from: control.from
        to: control.to
        stepSize: control.stepSize
        snapMode: Slider.SnapAlways
        value: control.value
        Accessible.name: control.Accessible.name
        onMoved: control.valueModified(Math.round(value))
    }
    SpinBox {
        id: number
        objectName: control.objectName + "Number"
        Layout.preferredWidth: 110
        implicitHeight: 34
        from: control.from
        to: control.to
        stepSize: control.stepSize
        value: control.value
        editable: true
        font.family: Theme.textFont
        font.pixelSize: 12
        leftPadding: 28
        rightPadding: 28
        Accessible.name: control.Accessible.name
        onValueModified: control.valueModified(value)
        background: Rectangle {
            radius: Theme.radius
            antialiasing: true
            color: Theme.groupSurface
            border.width: Theme.controlBorderWidth(number)
            border.pixelAligned: false
            border.color: number.activeFocus || number.contentItem.activeFocus ? Theme.paper : Theme.line
        }
        contentItem: TextInput {
            objectName: control.objectName + "Input"
            text: number.textFromValue(number.value, number.locale)
            font: number.font
            color: Theme.paper
            selectionColor: Theme.paper
            selectedTextColor: Theme.ink
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            readOnly: !number.editable
            validator: number.validator
            inputMethodHints: Qt.ImhDigitsOnly
            Accessible.name: control.Accessible.name
            selectByMouse: true
        }
        down.indicator: Rectangle {
            x: 1
            y: 1
            width: 26
            height: number.height - 2
            radius: Theme.radius
            color: number.down.pressed ? Theme.paper : number.down.hovered ? Theme.hover : Theme.clear
            opacity: number.down.enabled ? 1 : 0.35
            Label {
                anchors.centerIn: parent
                text: "-"
                color: number.down.pressed ? Theme.ink : Theme.paper
            }
        }
        up.indicator: Rectangle {
            x: number.width - width - 1
            y: 1
            width: 26
            height: number.height - 2
            radius: Theme.radius
            color: number.up.pressed ? Theme.paper : number.up.hovered ? Theme.hover : Theme.clear
            opacity: number.up.enabled ? 1 : 0.35
            Label {
                anchors.centerIn: parent
                text: "+"
                color: number.up.pressed ? Theme.ink : Theme.paper
            }
        }
    }
}