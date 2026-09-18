import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Ui.SettingsSection {
    id: editor
    required property var service
    readonly property var profiles: service.profileSettings
    property var selectedCategories: ["appearance"]
    objectName: "profilePolicies"
    title: "Profile policies / Copy"
    expanded: false
    function confirmSwitch(name) {
        switchDialog.confirm(name);
    }
    Ui.Label { text: "Create from" }
    Ui.Dropdown { id: duplicateSource; objectName: "duplicateSource"; model: ["Defaults"].concat(editor.profiles.profiles.map(entry => entry.name)); Layout.fillWidth: true }
    Ui.Label { text: "New profile name"; color: Ui.Theme.muted; font.pixelSize: 11 }
    RowLayout {
        Layout.fillWidth: true
        Ui.TextField { id: newName; objectName: "newProfileName"; placeholderText: "New profile name"; Accessible.name: "New profile name"; maximumLength: 32; Layout.fillWidth: true; Layout.minimumWidth: 0 }
        Ui.ActionButton { text: "Create"; onClicked: if (editor.profiles.add(newName.text, duplicateSource.currentText)) newName.text = "" }
    }
    Ui.Label { text: "Copy into " + editor.profiles.activeName }
    Ui.Dropdown { id: copySource; objectName: "copyProfileSource"; model: editor.profiles.profiles.map(entry => entry.name).filter(name => name !== editor.profiles.activeName); Layout.fillWidth: true }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: editor.profiles.categories
            Ui.Toggle {
                required property string modelData
                text: modelData
                checked: editor.selectedCategories.includes(modelData)
                onToggled: editor.selectedCategories = checked ? editor.selectedCategories.concat([modelData]) : editor.selectedCategories.filter(category => category !== modelData)
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Ui.ActionButton { objectName: "previewProfileCopy"; text: "Preview copy"; enabled: editor.selectedCategories.length > 0 && copySource.count > 0; onClicked: copyDialog.open() }
        Ui.ActionButton { objectName: "undoProfileCopy"; text: "Undo copy"; enabled: !!editor.profiles.copyUndo && editor.profiles.copyUndo.name === editor.profiles.activeName; onClicked: editor.profiles.undoCopy() }
    }
    Ui.Label { text: "Local AI" }
    Ui.Dropdown { objectName: "profileAiAction"; model: ["Keep", "Load", "Unload", "Stop"]; currentIndex: model.indexOf(editor.profiles.currentProfile.ai.action); onActivated: editor.profiles.setPolicy("ai", "action", currentText); Layout.fillWidth: true }
    Ui.Dropdown { model: editor.service.models; currentIndex: editor.profiles.currentProfile.ai.model; onActivated: editor.profiles.setPolicy("ai", "model", currentIndex); Layout.fillWidth: true }
    Ui.Dropdown { model: ["RTX 5090", "RTX 3080"]; currentIndex: editor.profiles.currentProfile.ai.gpu; onActivated: editor.profiles.setPolicy("ai", "gpu", currentIndex); Layout.fillWidth: true }
    Ui.Label { text: "VRAM budget (GiB)" }
    Ui.ValueControl { Accessible.name: "VRAM budget (GiB)"; from: 1; to: 32; value: editor.profiles.currentProfile.ai.budget; onValueModified: value => editor.profiles.setPolicy("ai", "budget", value) }
    Ui.Label { text: "Notifications" }
    Ui.Dropdown { objectName: "profileNotificationMode"; model: ["Normal", "Priority", "DND"]; currentIndex: model.indexOf(editor.profiles.currentProfile.notifications.mode); onActivated: editor.profiles.setPolicy("notifications", "mode", currentText); Layout.fillWidth: true }
    Ui.Toggle { text: "Allow urgent notifications"; checked: editor.profiles.currentProfile.notifications.urgent; onToggled: editor.profiles.setPolicy("notifications", "urgent", checked) }
    Ui.Toggle { text: "Apply audio output"; checked: editor.profiles.currentProfile.audio.enabled; onToggled: editor.profiles.setPolicy("audio", "enabled", checked) }
    Ui.Dropdown { model: ["Default", "Headphones", "Speakers"]; currentIndex: model.indexOf(editor.profiles.currentProfile.audio.device); enabled: editor.profiles.currentProfile.audio.enabled; onActivated: editor.profiles.setPolicy("audio", "device", currentText); Layout.fillWidth: true }
    Ui.Label { text: "Output volume" }
    Ui.ValueControl { Accessible.name: "Profile output volume"; from: 0; to: 100; value: editor.profiles.currentProfile.audio.volume; enabled: editor.profiles.currentProfile.audio.enabled; onValueModified: value => editor.profiles.setPolicy("audio", "volume", value) }
    Ui.Label { text: editor.service.profileSwitchStatus; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
    Ui.ActionButton { text: "Finish preview requests"; visible: editor.service.waitingProfile !== ""; onClicked: editor.service.activeRequests = 0 }
    Ui.ActionButton { text: "Cancel pending switch"; visible: editor.service.waitingProfile !== ""; onClicked: editor.service.waitingProfile = "" }
    Dialog {
        id: copyDialog
        objectName: "profileCopyDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(500, parent.width - 24)
        modal: true
        font.family: Ui.Theme.textFont
        palette.window: Ui.Theme.ink
        palette.windowText: Ui.Theme.paper
        palette.text: Ui.Theme.paper
        palette.base: Ui.Theme.ink
        palette.button: Ui.Theme.ink
        palette.buttonText: Ui.Theme.paper
        title: "Copy into " + editor.profiles.activeName
        standardButtons: Dialog.Ok | Dialog.Cancel
        contentItem: ScrollView {
            implicitHeight: 240
            clip: true
            TextArea {
                readOnly: true
                color: Ui.Theme.paper
                font.family: Ui.Theme.textFont
                wrapMode: TextEdit.Wrap
                text: {
                    const source = editor.profiles.profiles.find(entry => entry.name === copySource.currentText);
                    if (!source) return "";
                    function values(profile, category) {
                        if (category !== "appearance") return profile[category];
                        return Object.assign({}, profile.appearance, {
                            palette: profile.palette, source: profile.source,
                            wallpaper: profile.wallpaper, wallpaperFile: profile.wallpaperFile
                        });
                    }
                    return editor.selectedCategories.map(category => category + "\n" + JSON.stringify(values(editor.profiles.currentProfile, category)) + "\n-> " + JSON.stringify(values(source, category))).join("\n\n");
                }
            }
        }
        onAccepted: editor.profiles.copyFrom(copySource.currentText, editor.selectedCategories)
    }
    ProfileSwitch {
        id: switchDialog
        service: editor.service
    }
}