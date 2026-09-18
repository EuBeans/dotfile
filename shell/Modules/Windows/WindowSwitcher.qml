import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts
import "../../Components" as Ui

Ui.RetroDrawer {
    id: switcher
    required property var windows
    required property var applications
    required property var recentIds
    required property int focusedId
    property var snapshotIds: []
    property int selectedId: -1
    property var previousFocus: null
    readonly property var candidates: snapshotIds.map(windowId => windows.find(window => window.windowId === windowId)).filter(window => window)
    signal focusRequested(int windowId)
    objectName: "windowSwitcher"
    implicitWidth: 460
    implicitHeight: Math.min(420, 68 + candidates.length * 58)
    floating: true
    onDismissRequested: cancel()
    onCandidatesChanged: {
        if (!opened) return;
        if (!candidates.length) cancel();
        else if (!candidates.some(window => window.windowId === selectedId)) selectedId = candidates[0].windowId;
    }

    function cycle(direction) {
        if (!opened) {
            if (!windows.length) return;
            previousFocus = Window.window ? Window.window.activeFocusItem : null;
            snapshotIds = recentIds.filter(windowId => windows.some(window => window.windowId === windowId));
            snapshotIds = snapshotIds.concat(windows.filter(window => !snapshotIds.includes(window.windowId)).map(window => window.windowId));
            selectedId = focusedId;
            opened = true;
            forceActiveFocus();
        }
        const index = candidates.findIndex(window => window.windowId === selectedId);
        const next = (index + direction + candidates.length) % candidates.length;
        selectedId = candidates[next].windowId;
        list.positionViewAtIndex(next, ListView.Contain);
    }
    function cancel() {
        opened = false;
        if (previousFocus) previousFocus.forceActiveFocus();
        previousFocus = null;
    }
    function commit() {
        const chosen = selectedId;
        cancel();
        if (windows.some(window => window.windowId === chosen)) focusRequested(chosen);
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Alt && !event.isAutoRepeat) { commit(); event.accepted = true; }
    }
    Keys.onReturnPressed: commit()
    Keys.onEnterPressed: commit()
    Keys.onLeftPressed: cycle(-1)
    Keys.onRightPressed: cycle(1)
    Keys.onUpPressed: cycle(-1)
    Keys.onDownPressed: cycle(1)
    Connections {
        target: switcher.Window.window
        function onActiveChanged() {
            if (!switcher.Window.window.active && switcher.opened) switcher.cancel();
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Ui.Theme.surface
        border.color: Ui.Theme.surfaceEdge
        radius: Ui.Theme.panelRadius
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            Ui.Label { text: "SWITCH WINDOW"; font.family: Ui.Theme.displayFont; font.pixelSize: 16; Layout.fillWidth: true }
            ListView {
                id: list
                objectName: "switcherCandidates"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: switcher.candidates
                ScrollBar.vertical: ScrollBar {}
                delegate: Ui.ActionButton {
                    id: candidate
                    required property var modelData
                    readonly property var application: switcher.applications.find(app => app.appId === modelData.appId)
                    objectName: "switchWindow" + modelData.windowId
                    width: list.width
                    height: 54
                    checked: switcher.selectedId === modelData.windowId
                    description: modelData.title + " / " + modelData.monitor + " / Workspace " + modelData.workspace
                    contentItem: RowLayout {
                        spacing: 14
                        IconImage {
                            objectName: "switcherIcon" + candidate.modelData.windowId
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            source: Qt.resolvedUrl("../../Assets/Icons/" + (candidate.application ? candidate.application.icon : "square") + ".svg")
                            color: candidate.checked || candidate.down ? Ui.Theme.ink : Ui.Theme.paper
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Ui.Label { Layout.fillWidth: true; text: candidate.modelData.title; color: candidate.checked || candidate.down ? Ui.Theme.ink : Ui.Theme.paper }
                            Ui.Label { Layout.fillWidth: true; text: (candidate.application ? candidate.application.name : candidate.modelData.appId) + " / " + candidate.modelData.monitor + " / WS " + candidate.modelData.workspace; font.pixelSize: 11; color: candidate.checked || candidate.down ? Ui.Theme.ink : Ui.Theme.muted }
                        }
                    }
                    onClicked: { switcher.selectedId = modelData.windowId; switcher.commit(); }
                }
            }
        }
    }
}