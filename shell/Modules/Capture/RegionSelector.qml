import QtQuick
import QtQuick.Controls
import "../../Components" as Ui

Item {
    id: selector
    objectName: "regionSelector"
    required property url frameSource
    required property int request
    property point startPoint
    property rect selection: Qt.rect(0, 0, 0, 0)
    property bool cropping: false
    signal accepted(int request, var result)
    signal cancelled()
    signal failed()
    focus: true
    Keys.onEscapePressed: cancelled()
    onVisibleChanged: if (visible) { selection = Qt.rect(0, 0, 0, 0); cropping = false; forceActiveFocus(); }
    Image { anchors.fill: parent; source: selector.frameSource; fillMode: Image.Stretch }
    Rectangle { anchors.fill: parent; color: Ui.Theme.ink; opacity: 0.35 }
    Rectangle {
        x: selector.selection.x
        y: selector.selection.y
        width: selector.selection.width
        height: selector.selection.height
        color: "transparent"
        border.width: 2
        border.color: Ui.Theme.paper
    }
    MouseArea {
        objectName: "regionDragArea"
        anchors.fill: parent
        enabled: !selector.cropping
        cursorShape: Qt.CrossCursor
        onPressed: mouse => { selector.startPoint = Qt.point(mouse.x, mouse.y); selector.selection = Qt.rect(mouse.x, mouse.y, 0, 0); }
        onPositionChanged: mouse => {
            if (!pressed) return;
            const endX = Math.max(0, Math.min(width, mouse.x));
            const endY = Math.max(0, Math.min(height, mouse.y));
            selector.selection = Qt.rect(Math.min(selector.startPoint.x, endX), Math.min(selector.startPoint.y, endY), Math.abs(endX - selector.startPoint.x), Math.abs(endY - selector.startPoint.y));
        }
    }
    Item {
        id: crop
        x: -width - 1
        width: Math.round(selector.selection.width)
        height: Math.round(selector.selection.height)
        clip: true
        Image {
            id: cropImage
            x: -selector.selection.x
            y: -selector.selection.y
            width: selector.width
            height: selector.height
            source: selector.frameSource
            fillMode: Image.Stretch
        }
    }
    Row {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 16
        spacing: 8
        Ui.ActionButton {
            objectName: "regionConfirm"
            iconName: "scissors"
            grouped: true
            description: "Capture selected region"
            enabled: selector.selection.width >= 8 && selector.selection.height >= 8 && !selector.cropping && cropImage.status === Image.Ready
            onClicked: {
                const request = selector.request;
                selector.cropping = true;
                if (!crop.grabToImage(result => selector.accepted(request, result), Qt.size(crop.width, crop.height))) { selector.cropping = false; selector.failed(); }
            }
        }
        Ui.ActionButton { objectName: "regionCancel"; iconName: "x"; grouped: true; description: "Cancel capture"; onClicked: selector.cancelled() }
    }
}