import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    required property var manager
    required property var applications
    required property var preferences
    property int section: 0
    readonly property var slots: Array.from({length: 12}, (_, index) => "Tile " + (index + 1))
    readonly property var rows: manager.windows.filter(window => (window.title + " " + window.appId + " " + window.subtitle).toLowerCase().includes(search.text.trim().toLowerCase())).map(window => Object.assign({}, window, {group: window.monitor.toUpperCase() + " / WORKSPACE " + window.workspace})).sort((first, second) => first.group.localeCompare(second.group) || first.windowId - second.windowId)
    signal closeRequested()
    signal focusRequested(int windowId)
    signal windowCloseRequested(int windowId)
    signal moveRequested(int windowId, string monitor, int workspace)
    signal placeRequested(int windowId, int slot)
    signal floatingRequested(int windowId, bool floating)
    signal reserveRequested(string appId, string monitor, int workspace, int slot)
    signal removeRuleRequested(string appId)
    implicitWidth: 860
    implicitHeight: 640
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        RowLayout {
            Ui.Label { text: "TILE MANAGER"; font.family: Ui.Theme.displayFont; font.pixelSize: 18; Layout.fillWidth: true }
            Ui.Label { text: panel.manager.windows.length + " open"; color: Ui.Theme.muted }
            Ui.ActionButton { objectName: "closeWindowOverview"; iconName: "x"; description: "Close tile manager"; onClicked: panel.closeRequested() }
        }
        RowLayout {
            Ui.ActionButton { objectName: "overviewWindowsTab"; text: "Windows"; checked: panel.section === 0; onClicked: panel.section = 0 }
            Ui.ActionButton { objectName: "overviewRulesTab"; text: "App rules"; checked: panel.section === 1; onClicked: panel.section = 1 }
            Item { Layout.fillWidth: true }
            Ui.Dropdown {
                objectName: "overviewLayout"
                Layout.maximumWidth: 150
                model: ["Auto", "Split", "Columns", "Centered"]
                currentIndex: model.indexOf(panel.preferences.tilingLayout)
                Accessible.name: "Tiling layout"
                onActivated: panel.preferences.setAppearance("tilingLayout", currentText)
            }
        }
        Ui.TextField {
            id: search
            objectName: "windowSearch"
            visible: panel.section === 0
            Layout.fillWidth: true
            placeholderText: "Search open windows"
            font.family: Ui.Theme.textFont
            color: Ui.Theme.paper
            placeholderTextColor: Ui.Theme.muted
            selectionColor: Ui.Theme.paper
            selectedTextColor: Ui.Theme.ink
            Accessible.name: "Search open windows"
        }
        ListView {
            id: windowList
            objectName: "overviewWindowList"
            visible: panel.section === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: panel.rows
            section.property: "group"
            section.delegate: Ui.Label {
                required property string section
                width: windowList.width
                height: 32
                text: section
                color: Ui.Theme.muted
                font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
            ScrollBar.vertical: ScrollBar {}
            delegate: ColumnLayout {
                id: row
                required property var modelData
                readonly property var rule: panel.manager.rules.find(rule => rule.appId === modelData.appId)
                width: windowList.width
                height: 96
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Ui.Label { text: row.modelData.title + " / " + row.modelData.subtitle; Layout.fillWidth: true; Layout.minimumWidth: 0 }
                    Ui.ActionButton {
                        objectName: "focusWindow" + row.modelData.windowId
                        iconName: "eye"
                        description: "Focus " + row.modelData.title
                        checked: panel.manager.focusedId === row.modelData.windowId
                        onClicked: panel.focusRequested(row.modelData.windowId)
                    }
                    Ui.ActionButton {
                        objectName: "closeWindow" + row.modelData.windowId
                        iconName: "x"
                        description: "Close " + row.modelData.title
                        onClicked: panel.windowCloseRequested(row.modelData.windowId)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Ui.Dropdown {
                        objectName: "windowMonitor" + row.modelData.windowId
                        Layout.maximumWidth: 130
                        minimumContentWidth: 90
                        model: panel.manager.monitors
                        currentIndex: model.indexOf(row.modelData.monitor)
                        Accessible.name: "Move window to display"
                        onActivated: panel.moveRequested(row.modelData.windowId, currentText, row.modelData.workspace)
                    }
                    Ui.Dropdown {
                        objectName: "windowWorkspace" + row.modelData.windowId
                        Layout.maximumWidth: 120
                        minimumContentWidth: 90
                        model: panel.manager.workspaces.map(workspace => "WS " + workspace)
                        currentIndex: panel.manager.workspaces.indexOf(row.modelData.workspace)
                        Accessible.name: "Move window to workspace"
                        onActivated: panel.moveRequested(row.modelData.windowId, row.modelData.monitor, panel.manager.workspaces[currentIndex])
                    }
                    Ui.Dropdown {
                        objectName: "windowSlot" + row.modelData.windowId
                        Layout.maximumWidth: 120
                        minimumContentWidth: 90
                        model: panel.slots.slice(0, panel.manager.orderedWindows(row.modelData.monitor, row.modelData.workspace).filter(window => !window.floating).length)
                        currentIndex: panel.manager.orderedWindows(row.modelData.monitor, row.modelData.workspace).filter(window => !window.floating).findIndex(window => window.windowId === row.modelData.windowId)
                        enabled: !row.modelData.floating && !row.rule
                        Accessible.name: "Window tile position"
                        onActivated: panel.placeRequested(row.modelData.windowId, currentIndex)
                    }
                    Item { Layout.fillWidth: true }
                    Ui.ActionButton {
                        objectName: "floatWindow" + row.modelData.windowId
                        iconName: "square"
                        description: row.modelData.floating ? "Tile window" : "Float window"
                        checked: row.modelData.floating
                        onClicked: panel.floatingRequested(row.modelData.windowId, !row.modelData.floating)
                    }
                    Ui.ActionButton {
                        objectName: "reserveWindow" + row.modelData.windowId
                        iconName: "pin"
                        description: row.rule ? "Remove app tile rule" : "Remember this app's tile"
                        checked: Boolean(row.rule)
                        enabled: !row.modelData.floating
                        onClicked: {
                            if (row.rule) panel.removeRuleRequested(row.modelData.appId);
                            else panel.reserveRequested(row.modelData.appId, row.modelData.monitor, row.modelData.workspace, panel.manager.orderedWindows(row.modelData.monitor, row.modelData.workspace).filter(window => !window.floating).findIndex(window => window.windowId === row.modelData.windowId));
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            }
            Ui.Label { objectName: "windowsEmptyState"; anchors.centerIn: parent; text: search.text ? "No matching windows" : "No open windows"; visible: windowList.count === 0; color: Ui.Theme.muted }
        }
        ColumnLayout {
            visible: panel.section === 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Ui.Dropdown { id: ruleApp; objectName: "ruleApp"; model: panel.applications.map(app => app.name); Accessible.name: "App for tile rule" }
                Ui.Dropdown { id: ruleMonitor; objectName: "ruleMonitor"; minimumContentWidth: 90; model: panel.manager.monitors; Accessible.name: "Rule display" }
                Ui.Dropdown { id: ruleWorkspace; objectName: "ruleWorkspace"; minimumContentWidth: 90; model: panel.manager.workspaces.map(workspace => "WS " + workspace); Accessible.name: "Rule workspace" }
                Ui.Dropdown { id: ruleSlot; objectName: "ruleSlot"; minimumContentWidth: 90; model: panel.slots; Accessible.name: "Preferred tile" }
                Ui.ActionButton {
                    objectName: "saveWindowRule"
                    iconName: "pin"
                    description: "Save app tile rule"
                    onClicked: panel.reserveRequested(panel.applications[ruleApp.currentIndex].appId, ruleMonitor.currentText, panel.manager.workspaces[ruleWorkspace.currentIndex], ruleSlot.currentIndex)
                }
            }
            ListView {
                id: ruleList
                objectName: "windowRulesList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: panel.manager.rules
                spacing: 8
                ScrollBar.vertical: ScrollBar {}
                delegate: RowLayout {
                    required property var modelData
                    width: ruleList.width
                    height: 52
                    Ui.Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: modelData.appId + " / " + modelData.monitor + " / WS " + modelData.workspace + " / Tile " + (modelData.slot + 1)
                        wrapMode: Text.WordWrap
                    }
                    Ui.ActionButton {
                        objectName: "removeWindowRule_" + modelData.appId
                        iconName: "x"
                        description: "Remove " + modelData.appId + " tile rule"
                        onClicked: panel.removeRuleRequested(modelData.appId)
                    }
                }
                Ui.Label { anchors.centerIn: parent; text: "No app tile rules"; visible: ruleList.count === 0; color: Ui.Theme.muted }
            }
        }
        Ui.Label { objectName: "windowRuleError"; text: panel.manager.error; visible: text !== ""; color: Ui.Theme.paper; Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideNone }
    }
}