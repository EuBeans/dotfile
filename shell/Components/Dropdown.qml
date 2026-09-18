import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ComboBox {
    id: control
    property real minimumContentWidth: 120
    property real maximumContentWidth: 320
    readonly property real widestOptionWidth: {
        const options = model;
        const role = textRole;
        let widest = 0;
        for (let index = 0; index < count; index++) {
            const label = Array.isArray(options) ? (role ? options[index][role] : options[index]) : textAt(index);
            widest = Math.max(widest, textMetrics.advanceWidth(String(label ?? "")));
        }
        return widest;
    }
    implicitWidth: Math.ceil(Math.min(maximumContentWidth, Math.max(minimumContentWidth, widestOptionWidth + leftPadding + rightPadding)))
    implicitHeight: 34
    Layout.fillWidth: false
    Layout.alignment: Qt.AlignLeft
    Layout.minimumWidth: 0
    Layout.maximumWidth: parent ? parent.width : implicitWidth
    font.family: Theme.textFont
    font.pixelSize: 13
    font.letterSpacing: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : 0.4
    leftPadding: 12
    rightPadding: indicator.width + 20
    palette.base: Theme.ink
    palette.button: Theme.hover
    palette.text: Theme.paper
    palette.buttonText: Theme.paper
    palette.highlight: Theme.paper
    palette.highlightedText: Theme.ink
    palette.window: Theme.ink

    FontMetrics { id: textMetrics; font: control.font }

    background: Rectangle {
        objectName: control.objectName + "Background"
        radius: Theme.radius
        antialiasing: true
        color: control.down || control.hovered ? Theme.hover : Theme.groupSurface
        border.width: Theme.controlBorderWidth(control)
        border.pixelAligned: false
        border.color: control.visualFocus || control.popup.visible ? Theme.paper : Theme.line
    }
    contentItem: Label {
        text: control.displayText
        textFormat: Text.PlainText
        font: control.font
        color: Theme.paper
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    delegate: ItemDelegate {
        required property int index
        width: control.popup.availableWidth
        implicitHeight: 34
        text: control.textAt(index)
        font: control.font
        highlighted: control.highlightedIndex === index
        hoverEnabled: control.hoverEnabled
        contentItem: Label {
            text: parent.text
            textFormat: Text.PlainText
            font: control.font
            color: parent.highlighted ? Theme.ink : Theme.paper
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: parent.highlighted ? Theme.paper : parent.hovered ? Theme.hover : Theme.ink
        }
    }
    popup: Popup {
        objectName: control.objectName + "Popup"
        scale: {
            let inheritedScale = 1;
            let ancestor = control;
            while (ancestor) {
                inheritedScale *= ancestor.scale;
                ancestor = ancestor.parent;
            }
            return inheritedScale;
        }
        transformOrigin: Popup.TopLeft
        margins: 4
        y: control.height + 4
        width: Math.min(control.width, Math.max(0, (control.Window.width - 2 * margins) / Math.max(scale, 0.001)))
        implicitHeight: Math.min(contentItem.implicitHeight, 272) + topPadding + bottomPadding
        padding: 1
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            highlightRangeMode: ListView.ApplyRange
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        background: Rectangle {
            color: Theme.ink
            border.color: Theme.line
            radius: Theme.radius
        }
    }
}