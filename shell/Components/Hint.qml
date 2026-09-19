import QtQuick
import QtQuick.Controls

ToolTip {
    id: root
    visible: parent && parent.hovered
    text: parent && parent.description ? parent.description : ""
    delay: 650
    timeout: 4000
    margins: 8
    padding: 0
    horizontalPadding: 8
    verticalPadding: 5
    implicitWidth: Math.min(240, hintText.implicitWidth + horizontalPadding * 2)
    implicitHeight: hintText.implicitHeight + verticalPadding * 2
    contentItem: Text {
        id: hintText
        text: root.text
        textFormat: Text.PlainText
        font.family: Theme.textFont
        font.pixelSize: 11
        color: Theme.paper
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 2
        elide: Text.ElideRight
    }
    background: Rectangle {
        color: Theme.ink
        border.color: Theme.line
        border.width: 1
        radius: 4
    }
}