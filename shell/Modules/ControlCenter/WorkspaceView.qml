import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

ColumnLayout {
    id: view
    required property var manager
    property string monitor: manager.activeMonitor
    readonly property var windows: manager.orderedWindows(monitor, manager.activeWorkspace)
    signal workspaceRequested(string monitor, int number)
    signal focusRequested(int windowId)
    spacing: 16
    onMonitorChanged: if (!manager.monitors.includes(monitor)) monitor = manager.activeMonitor
    Connections {
        target: view.manager
        function onMonitorsChanged() {
            if (!view.manager.monitors.includes(view.monitor)) view.monitor = view.manager.defaultMonitor;
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Ui.Label { text: "Display"; color: Ui.Theme.muted; font.pixelSize: 11 }
        Ui.Dropdown {
            objectName: "homeWorkspaceMonitor"
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            model: view.manager.monitors
            currentIndex: model.indexOf(view.monitor)
            enabled: count > 0
            Accessible.name: "Workspace display"
            onActivated: view.monitor = currentText
        }
    }
    Ui.Label {
        visible: !view.manager.monitors.length
        text: "No display connected"
        Layout.fillWidth: true
        color: Ui.Theme.muted
    }
    GridLayout {
        objectName: "homeWorkspaceGrid"
        Layout.fillWidth: true
        columns: view.width >= 440 ? 4 : 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: view.manager.workspaces
            Ui.ActionButton {
                id: workspace
                required property int modelData
                readonly property var members: view.manager.windows.filter(window => window.monitor === view.monitor && window.workspace === modelData)
                objectName: "controlWorkspace" + modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 100
                Layout.preferredHeight: 88
                enabled: view.manager.monitors.includes(view.monitor)
                checked: view.manager.activeWorkspace === modelData && view.manager.activeMonitor === view.monitor
                grouped: true
                description: "Workspace " + modelData + ", " + members.length + " windows on " + view.monitor
                onClicked: view.workspaceRequested(view.monitor, modelData)
                contentItem: ColumnLayout {
                    spacing: 6
                    Ui.Label {
                        text: String(workspace.modelData).padStart(2, "0")
                        Layout.fillWidth: true
                        font.family: Ui.Theme.displayFont
                        font.pixelSize: 22
                        color: workspace.checked || workspace.down ? Ui.Theme.ink : Ui.Theme.paper
                    }
                    Ui.Label {
                        text: workspace.members.length ? workspace.members.length + (workspace.members.length === 1 ? " window" : " windows") : "Empty"
                        Layout.fillWidth: true
                        font.pixelSize: 10
                        color: workspace.checked || workspace.down ? Ui.Theme.ink : Ui.Theme.muted
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Ui.Label { text: "Workspace " + view.manager.activeWorkspace; Layout.fillWidth: true; font.pixelSize: 13 }
        Ui.Label { text: view.windows.length + " open"; color: Ui.Theme.muted; font.pixelSize: 11 }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
    Ui.Label {
        objectName: "homeWorkspaceEmpty"
        visible: view.windows.length === 0
        text: "No windows on this workspace"
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Ui.Theme.muted
    }
    Repeater {
        model: view.windows
        Ui.ActionButton {
            id: windowButton
            required property var modelData
            objectName: "homeWorkspaceWindow" + modelData.windowId
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: 62
            checked: view.manager.focusedId === modelData.windowId
            description: modelData.title + ", " + modelData.subtitle + ", " + (modelData.floating ? "floating" : "tiled")
            onClicked: view.focusRequested(modelData.windowId)
            contentItem: ColumnLayout {
                spacing: 4
                Ui.Label { text: windowButton.modelData.title; Layout.fillWidth: true; color: windowButton.checked || windowButton.down ? Ui.Theme.ink : Ui.Theme.paper }
                Ui.Label {
                    text: windowButton.modelData.subtitle + " / " + (windowButton.modelData.floating ? "Floating" : "Tiled")
                    Layout.fillWidth: true
                    font.pixelSize: 10
                    color: windowButton.checked || windowButton.down ? Ui.Theme.ink : Ui.Theme.muted
                }
            }
        }
    }
}