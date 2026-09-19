import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: root
    required property var windows
    required property var manager
    signal focusRequested(int windowId)
    signal closeRequested(int windowId)
    signal minimizeRequested(int windowId)
    signal dismissRequested()
    objectName: "bottomPickerSurface"
    color: Ui.Theme.ink
    radius: 4
    border.color: Ui.Theme.line
    focus: true
    Keys.onEscapePressed: dismissRequested()
    ListView {
        id: windowList
        anchors.fill: parent
        anchors.margins: 4
        clip: true
        spacing: 4
        model: root.windows
        ScrollBar.vertical: ScrollBar {}
        delegate: Ui.ActionButton {
            id: windowOption
            required property var modelData
            objectName: "bottomWindow" + modelData.windowId
            width: windowList.width
            height: 30
            rightPadding: minimizeButton.visible ? 64 : 34
            text: modelData.title + (modelData.minimized ? " / Minimized" : " / WS " + modelData.workspace) + (root.manager.monitors.length > 1 ? " / " + modelData.monitor : "")
            description: text
            checked: modelData.windowId === root.manager.focusedId
            contentItem: RowLayout {
                spacing: 8
                Ui.Label {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: windowOption.modelData.title
                    font.pixelSize: 11
                    color: windowOption.checked || windowOption.down ? Ui.Theme.ink : Ui.Theme.paper
                }
                Ui.Label {
                    text: windowOption.modelData.minimized ? "Minimized" : "WS " + windowOption.modelData.workspace
                    font.pixelSize: 10
                    color: windowOption.checked || windowOption.down ? Ui.Theme.ink : Ui.Theme.muted
                }
            }
            onClicked: root.focusRequested(modelData.windowId)
            Ui.ActionButton {
                id: minimizeButton
                objectName: "bottomWindowMinimize" + windowOption.modelData.windowId
                anchors.right: parent.right
                anchors.rightMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                padding: 6
                visible: typeof root.manager.minimize === "function"
                enabled: root.manager.controlsEnabled === true && !root.manager.busy
                iconName: windowOption.modelData.minimized ? "arrow-up" : "minus"
                icon.color: windowOption.checked || windowOption.down ? Ui.Theme.ink : Ui.Theme.paper
                description: (windowOption.modelData.minimized ? "Restore " : "Minimize ") + windowOption.modelData.title
                onClicked: windowOption.modelData.minimized ? root.focusRequested(windowOption.modelData.windowId) : root.minimizeRequested(windowOption.modelData.windowId)
            }
            Ui.ActionButton {
                objectName: "bottomWindowClose" + windowOption.modelData.windowId
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                padding: 6
                iconName: "x"
                icon.color: windowOption.checked || windowOption.down ? Ui.Theme.ink : Ui.Theme.paper
                description: "Close " + windowOption.modelData.title
                onClicked: root.closeRequested(windowOption.modelData.windowId)
            }
        }
    }
}