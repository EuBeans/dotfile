import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Dialog {
    id: dialog
    required property var service
    property string targetName: ""
    property var preview: null
    objectName: "profileSwitchDialog"
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(500, parent.width - 24)
    modal: true
    font.family: Ui.Theme.textFont
    palette.window: Ui.Theme.ink
    palette.windowText: Ui.Theme.paper
    palette.text: Ui.Theme.paper
    palette.base: Ui.Theme.ink
    palette.button: Ui.Theme.groupSurface
    palette.buttonText: Ui.Theme.paper
    palette.highlight: Ui.Theme.paper
    palette.highlightedText: Ui.Theme.ink
    background: Rectangle {
        objectName: "profileSwitchBackground"
        color: Ui.Theme.ink
        border.color: Ui.Theme.surfaceEdge
        radius: Ui.Theme.panelRadius
    }
    title: "Switch to " + targetName
    standardButtons: Dialog.Cancel
    function confirm(name) {
        const profile = service.profileSettings.profiles.find(entry => entry.name === name);
        if (!profile) return;
        if (name === service.profile) return;
        if (!service.aiBusy && (service.runningRequests === 0 || profile.ai.action === "Keep")) {
            service.applyProfile(name, "Wait");
            return;
        }
        targetName = name;
        preview = service.profileSettings.clone(profile);
        open();
    }
    contentItem: ColumnLayout {
        Ui.Label {
            objectName: "profileSwitchDetails"
            text: dialog.preview ? "Layout: " + dialog.preview.tiling.tilingLayout + "\nAI: " + dialog.preview.ai.action + " / Notifications: " + dialog.preview.notifications.mode + "\nAudio: " + (dialog.preview.audio.enabled ? dialog.preview.audio.device + " / " + dialog.preview.audio.volume + "%" : "Unchanged") + "\nUnsaved drafts retained. Existing windows stay in place." : ""
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            Layout.fillWidth: true
        }
        Ui.Label { text: dialog.service.runningRequests + " active requests / Preview services only"; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Ui.ActionButton { objectName: "profileApplyWait"; text: dialog.service.runningRequests ? "Wait for requests" : "Apply"; enabled: !dialog.service.aiBusy; onClicked: { dialog.service.applyProfile(dialog.targetName, "Wait"); dialog.close(); } }
            Ui.ActionButton { objectName: "profileApplyCancel"; text: "Cancel requests and apply"; visible: dialog.service.runningRequests > 0; enabled: !dialog.service.aiBusy; onClicked: { dialog.service.applyProfile(dialog.targetName, "Cancel"); dialog.close(); } }
            Ui.ActionButton { objectName: "profileApplyKeep"; text: "Leave AI unchanged"; enabled: !dialog.service.aiBusy; onClicked: { dialog.service.applyProfile(dialog.targetName, "Keep"); dialog.close(); } }
        }
    }
}