import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../../Components" as Ui

Rectangle {
    id: panel
    objectName: "captureManager"
    required property var service
    required property var windows
    property string mode: "Screen"
    property bool pinnedOnly: false
    property string query: ""
    readonly property var filtered: service.entries.filter(entry => (!pinnedOnly || entry.pinned) && entry.name.toLowerCase().includes(query.toLowerCase()))
    signal captureRequested(string mode, int windowId)
    signal copyRequested(int captureId)
    signal closeRequested()
    implicitWidth: 820
    implicitHeight: 620
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius
    FileDialog {
        id: saveDialog
        title: "Save preview screenshot"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PNG images (*.png)"]
        defaultSuffix: "png"
        onAccepted: panel.service.save(selectedFile)
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Ui.Label { text: "Screenshots"; font.family: Ui.Theme.displayFont; font.pixelSize: 20; Layout.fillWidth: true }
            Ui.ActionButton { objectName: "closeCapture"; iconName: "x"; description: "Close screenshot manager"; onClicked: panel.closeRequested() }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: ["Screen", "Window", "Region"]
                Ui.ActionButton { required property string modelData; objectName: "captureMode" + modelData; text: modelData; checked: panel.mode === modelData; enabled: !panel.service.busy; onClicked: panel.mode = modelData }
            }
            Ui.ActionButton {
                objectName: "takeCapture"
                iconName: "scissors"
                iconOnly: false
                text: "Capture"
                description: "Capture simulated desktop"
                enabled: !panel.service.busy && (panel.mode !== "Window" || windowPicker.currentIndex >= 0)
                onClicked: panel.captureRequested(panel.mode, windowPicker.currentIndex >= 0 && panel.windows[windowPicker.currentIndex] ? panel.windows[windowPicker.currentIndex].windowId : -1)
            }
        }
        Ui.Dropdown {
            id: windowPicker
            objectName: "captureWindowPicker"
            visible: panel.mode === "Window"
            Layout.fillWidth: true
            model: panel.windows.map(window => window.title)
            Accessible.name: "Window to capture"
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.TextField {
                objectName: "captureSearch"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                placeholderText: "Search captures"
                color: Ui.Theme.paper
                font.family: Ui.Theme.textFont
                onTextChanged: panel.query = text
            }
            Ui.ActionButton { objectName: "capturePinnedOnly"; iconName: "pin"; description: "Pinned captures only"; checked: panel.pinnedOnly; onClicked: panel.pinnedOnly = !panel.pinnedOnly }
            Ui.ActionButton { objectName: "captureClear"; iconName: "x"; description: "Clear unpinned captures"; enabled: panel.service.entries.some(entry => !entry.pinned); onClicked: clearDialog.open() }
        }
        Image {
            id: image
            objectName: "captureImage"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 100
            source: panel.service.selected ? panel.service.selected.source : ""
            fillMode: Image.PreserveAspectFit
            Ui.Label { anchors.centerIn: parent; visible: !panel.service.selected; text: "No captures"; color: Ui.Theme.muted }
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.Label { text: panel.service.selected ? panel.service.selected.name : ""; Layout.fillWidth: true }
            Ui.Label { objectName: "captureDimensions"; text: image.status === Image.Ready ? image.sourceSize.width + " x " + image.sourceSize.height : ""; font.pixelSize: 11; color: Ui.Theme.muted }
            Ui.ActionButton { objectName: "capturePin"; iconName: "pin"; description: "Pin capture"; checked: panel.service.selected ? panel.service.selected.pinned : false; enabled: !!panel.service.selected && !panel.service.busy; onClicked: panel.service.pin(panel.service.selectedId) }
            Ui.ActionButton { objectName: "captureCopy"; iconName: "clipboard"; description: "Copy to preview clipboard"; enabled: image.status === Image.Ready && !panel.service.busy; onClicked: panel.copyRequested(panel.service.selectedId) }
            Ui.ActionButton { objectName: "captureSave"; iconName: "folder-open"; description: "Save PNG"; enabled: image.status === Image.Ready && !panel.service.busy; onClicked: saveDialog.open() }
            Ui.ActionButton { objectName: "captureDelete"; iconName: "x"; description: "Delete capture"; enabled: !!panel.service.selected && !panel.service.busy; onClicked: panel.service.remove(panel.service.selectedId) }
        }
        ListView {
            id: library
            objectName: "captureLibrary"
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            orientation: ListView.Horizontal
            clip: true
            spacing: 8
            model: panel.filtered
            delegate: Button {
                required property var modelData
                objectName: "captureTile" + modelData.captureId
                width: 126
                height: 88
                padding: 4
                Accessible.name: modelData.name
                background: Rectangle { color: modelData.captureId === panel.service.selectedId ? Ui.Theme.paper : Ui.Theme.groupSurface; radius: Ui.Theme.radius }
                contentItem: Image { source: modelData.source; fillMode: Image.PreserveAspectFit }
                onClicked: panel.service.selectedId = modelData.captureId
                ToolTip.visible: hovered
                ToolTip.text: modelData.name + (modelData.pinned ? " / Pinned" : "")
            }
        }
        Ui.Label { objectName: "captureStatus"; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: panel.service.error || "Preview desktop / " + panel.service.status; color: Ui.Theme.muted; font.pixelSize: 11 }
    }
    Dialog {
        id: clearDialog
        objectName: "captureClearDialog"
        anchors.centerIn: parent
        width: Math.min(360, panel.width - 24)
        modal: true
        title: "Clear unpinned captures?"
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: panel.service.clearUnpinned()
    }
}