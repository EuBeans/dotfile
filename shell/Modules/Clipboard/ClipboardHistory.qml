import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    required property var entries
    property bool opened: false
    property string status: ""
    property bool confirmClear: false
    readonly property var matches: entries.filter(entry => (entry.text + " " + entry.kind).toLowerCase().includes(search.text.trim().toLowerCase())).slice().sort((first, second) => Number(second.pinned) - Number(first.pinned))
    signal copyRequested(int entryId)
    signal pinRequested(int entryId, bool pinned)
    signal removeRequested(int entryId)
    signal clearRequested()
    signal closeRequested()
    implicitWidth: 580
    implicitHeight: 530
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius
    onOpenedChanged: {
        confirmClear = false;
        if (opened) Qt.callLater(() => { if (panel.opened) search.forceActiveFocus(); });
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        RowLayout {
            Ui.Label { text: "CLIPBOARD"; font.family: Ui.Theme.displayFont; font.pixelSize: 18; Layout.fillWidth: true }
            Ui.ActionButton {
                objectName: "clearClipboard"
                iconName: "rotate-ccw"
                description: "Clear unpinned history"
                enabled: panel.entries.some(entry => !entry.pinned)
                onClicked: panel.confirmClear = true
            }
            Ui.ActionButton { objectName: "closeClipboard"; iconName: "x"; description: "Close clipboard history"; onClicked: panel.closeRequested() }
        }
        RowLayout {
            visible: panel.confirmClear
            Layout.fillWidth: true
            Ui.Label { text: "Clear unpinned entries?"; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WordWrap }
            Ui.ActionButton { objectName: "cancelClipboardClear"; text: "Cancel"; onClicked: panel.confirmClear = false }
            Ui.ActionButton { objectName: "confirmClipboardClear"; text: "Clear"; onClicked: { panel.clearRequested(); panel.confirmClear = false; } }
        }
        Ui.TextField {
            id: search
            objectName: "clipboardSearch"
            Layout.fillWidth: true
            placeholderText: "Search clipboard history"
            font.family: Ui.Theme.textFont
            color: Ui.Theme.paper
            placeholderTextColor: Ui.Theme.muted
            selectionColor: Ui.Theme.paper
            selectedTextColor: Ui.Theme.ink
            Accessible.name: "Search clipboard history"
            onAccepted: if (panel.matches.length) panel.copyRequested(panel.matches[0].entryId)
        }
        ListView {
            id: history
            objectName: "clipboardEntries"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            model: panel.matches
            ScrollBar.vertical: ScrollBar {}
            delegate: ColumnLayout {
                id: entryRow
                required property var modelData
                width: history.width
                height: modelData.kind === "image" && modelData.image ? 156 : 86
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Ui.Label { text: entryRow.modelData.text; Layout.fillWidth: true; Layout.minimumWidth: 0; maximumLineCount: 2; wrapMode: Text.WrapAnywhere }
                    Ui.ActionButton { objectName: "copyClip" + entryRow.modelData.entryId; iconName: "clipboard"; description: "Copy entry"; onClicked: panel.copyRequested(entryRow.modelData.entryId) }
                    Ui.ActionButton { objectName: "pinClip" + entryRow.modelData.entryId; iconName: "pin"; description: checked ? "Unpin entry" : "Pin entry"; checked: entryRow.modelData.pinned; onClicked: panel.pinRequested(entryRow.modelData.entryId, !checked) }
                    Ui.ActionButton { objectName: "removeClip" + entryRow.modelData.entryId; iconName: "x"; description: "Delete entry"; onClicked: panel.removeRequested(entryRow.modelData.entryId) }
                }
                Image {
                    visible: entryRow.modelData.kind === "image" && !!entryRow.modelData.image
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    source: entryRow.modelData.image || ""
                    sourceSize.width: 500
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Ui.Label { text: entryRow.modelData.kind === "image" ? "IMAGE" : "TEXT"; font.pixelSize: 10; color: Ui.Theme.muted }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            }
            Ui.Label { objectName: "clipboardEmptyState"; anchors.centerIn: parent; text: panel.status || (search.text ? "No matching entries" : "Clipboard history is empty"); visible: history.count === 0; color: Ui.Theme.muted }
        }
    }
}