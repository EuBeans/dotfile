import QtQuick
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    property string pendingAction: ""
    property string lastAction: ""
    signal actionRequested(string action)
    signal closeRequested()
    color: Ui.Theme.surface
    radius: Ui.Theme.panelRadius
    topLeftRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    bottomLeftRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    implicitWidth: 320
    implicitHeight: content.implicitHeight + 40
    onVisibleChanged: pendingAction = ""
    MouseArea { anchors.fill: parent }
    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        RowLayout {
            Ui.Label { text: "SESSION"; font.family: Ui.Theme.displayFont; Layout.fillWidth: true }
            Ui.ActionButton { iconName: "x"; description: "Close power menu"; onClicked: panel.closeRequested() }
        }
        Repeater {
            model: ["Lock", "Log out", "Suspend", "Restart", "Shut down"]
            Ui.ActionButton {
                required property string modelData
                objectName: "power" + modelData.replace(/ /g, "")
                text: modelData
                Layout.fillWidth: true
                visible: panel.pendingAction === ""
                onClicked: panel.pendingAction = modelData
            }
        }
        Ui.Label { text: panel.pendingAction + "?"; visible: panel.pendingAction !== ""; Layout.fillWidth: true }
        RowLayout {
            visible: panel.pendingAction !== ""
            Ui.ActionButton { objectName: "powerCancel"; text: "Cancel"; onClicked: panel.pendingAction = "" }
            Ui.ActionButton { objectName: "powerConfirm"; text: "Confirm"; onClicked: { panel.actionRequested(panel.pendingAction); panel.pendingAction = ""; } }
        }
        Ui.Label { text: panel.lastAction ? "Preview: " + panel.lastAction : ""; visible: panel.lastAction !== ""; color: Ui.Theme.muted; Layout.fillWidth: true }
    }
}