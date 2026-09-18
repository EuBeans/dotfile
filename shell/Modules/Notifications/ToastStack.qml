import QtQuick
import QtQuick.Layouts
import "../../Components" as Ui

Column {
    id: stack
    required property var notifications
    property bool reducedMotion: false
    property int timeout: 4500
    signal dismissRequested(int notificationId)
    spacing: 10
    Repeater {
        model: stack.notifications
        Rectangle {
            id: toast
            required property int notificationId
            required property string title
            required property string message
            objectName: "toast" + notificationId
            width: stack.width
            height: content.implicitHeight + 28
            radius: Ui.Theme.panelRadius
            color: Ui.Theme.surface
            border.color: Ui.Theme.surfaceEdge
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: stack.reducedMotion || Ui.Theme.animationStyle === "Off" ? 0 : Ui.Theme.animationDuration } }
            Accessible.role: Accessible.AlertMessage
            Accessible.name: title + ". " + message
            HoverHandler { id: hover }
            Timer {
                interval: stack.timeout
                running: !hover.hovered
                onTriggered: stack.dismissRequested(toast.notificationId)
            }
            Rectangle { x: 0; y: 16; width: 3; height: 12; color: Ui.Theme.accent }
            RowLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Ui.Label { text: toast.title; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    Ui.Label { text: toast.message; color: Ui.Theme.muted; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
                }
                Ui.ActionButton {
                    objectName: "dismissToast" + toast.notificationId
                    iconName: "x"
                    description: "Dismiss notification"
                    onClicked: stack.dismissRequested(toast.notificationId)
                }
            }
        }
    }
}