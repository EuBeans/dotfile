import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: bar
    objectName: "bottomBar"
    required property var manager
    required property var applications
    property string selectedApp: ""
    property var pickerAnchor: null
    property string openPanel: ""
    property bool compact: false
    property bool externalPicker: false
    property bool pickerOpen: false
    readonly property int entryCount: groups.length
    readonly property int entryWidth: compact ? 64 : 152
    readonly property var scopedWindows: manager.windows
    readonly property var groups: applications.filter(app => scopedWindows.some(window => window.appId === app.appId))
    readonly property var selectedWindows: scopedWindows.filter(window => window.appId === selectedApp)
    signal focusRequested(int windowId)
    signal windowCloseRequested(int windowId)
    signal windowMinimizeRequested(int windowId)
    signal launcherRequested()
    signal workspaceOverviewRequested()
    signal captureRequested()
    implicitWidth: content.implicitWidth + 16
    implicitHeight: 52
    color: Ui.Theme.ink
    radius: Ui.Theme.barRadius
    onSelectedWindowsChanged: if (selectedWindows && !selectedWindows.length) closeWindows()
    onWidthChanged: closeWindows()
    function closeWindows() {
        pickerOpen = false;
        picker.close();
    }
    function showWindows(appId) {
        const index = groups.findIndex(app => app.appId === appId);
        if (index < 0) return false;
        entries.positionViewAtIndex(index, ListView.Contain);
        entries.forceLayout();
        pickerAnchor = entries.itemAtIndex(index);
        selectedApp = appId;
        pickerOpen = true;
        if (!externalPicker) picker.open();
        return true;
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4
        Ui.ActionButton { objectName: "bottomLauncher"; iconName: "search"; description: "Applications"; onClicked: bar.launcherRequested() }
        Ui.ActionButton { objectName: "bottomOverview"; iconName: "panels-top-left"; description: "Workspace overview"; onClicked: bar.workspaceOverviewRequested() }
        ListView {
            id: workspaces
            objectName: "bottomWorkspaces"
            Layout.preferredWidth: Math.min(bar.compact ? 76 : 110, count * 26 - 2)
            Layout.minimumWidth: 50
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            clip: true
            spacing: 2
            model: bar.manager.workspaces
            boundsBehavior: Flickable.StopAtBounds
            delegate: Ui.ActionButton {
                required property int index
                required property int modelData
                objectName: "bottomWorkspace" + modelData
                width: 24
                height: workspaces.height
                leftPadding: 0
                rightPadding: 0
                iconOnly: false
                text: String(modelData)
                description: "Workspace " + modelData
                checked: bar.manager.activeWorkspace === modelData
                onActiveFocusChanged: if (activeFocus) workspaces.positionViewAtIndex(index, ListView.Contain)
                onClicked: { bar.closeWindows(); bar.manager.activeWorkspace = modelData; }
            }
        }
        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: Ui.Theme.line }
        ListView {
            id: entries
            objectName: "bottomEntries"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: Math.max(64, bar.entryCount * bar.entryWidth + Math.max(0, bar.entryCount - 1) * spacing)
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            clip: true
            spacing: 4
            model: bar.groups
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: Ui.ActionButton {
                id: appEntry
                required property int index
                required property var modelData
                readonly property var windows: bar.scopedWindows.filter(window => window.appId === modelData.appId)
                objectName: "bottomApp_" + modelData.appId
                width: bar.entryWidth
                height: entries.height
                rightPadding: 32
                iconName: modelData.icon
                iconSource: modelData.iconSource || ""
                iconOnly: bar.compact
                text: modelData.name + (windows.length > 1 ? " (" + windows.length + ")" : "")
                description: modelData.name + " / " + windows.length + (windows.length === 1 ? " window" : " windows")
                checked: windows.some(window => window.windowId === bar.manager.focusedId)
                onActiveFocusChanged: if (activeFocus) entries.positionViewAtIndex(index, ListView.Contain)
                onClicked: {
                    if (windows.length === 1) bar.focusRequested(windows[0].windowId);
                    else bar.showWindows(modelData.appId);
                }
                Ui.ActionButton {
                    objectName: "bottomClose_" + appEntry.modelData.appId
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    padding: 6
                    iconName: "x"
                    icon.color: appEntry.checked || appEntry.down ? Ui.Theme.ink : Ui.Theme.paper
                    description: "Close window of " + appEntry.modelData.name
                    onClicked: {
                        const window = appEntry.windows.find(entry => entry.windowId === bar.manager.focusedId) || appEntry.windows[appEntry.windows.length - 1];
                        if (window) bar.windowCloseRequested(window.windowId);
                    }
                }
            }
            Ui.Label { anchors.centerIn: parent; width: parent.width; horizontalAlignment: Text.AlignHCenter; visible: entries.count === 0; text: "No windows"; color: Ui.Theme.muted; font.pixelSize: 11 }
        }
        Ui.ActionButton { objectName: "captureButton"; iconName: "scissors"; description: "HyprQuickshot"; onClicked: bar.captureRequested() }
    }
    Popup {
        id: picker
        objectName: "bottomWindowPicker"
        parent: Overlay.overlay
        transformOrigin: Item.TopLeft
        onAboutToShow: {
            const barPosition = bar.mapToItem(parent, 0, 0);
            const anchorPosition = bar.pickerAnchor ? bar.pickerAnchor.mapToItem(parent, bar.pickerAnchor.width / 2, 0) : barPosition;
            scale = bar.mapToItem(parent, 1, 0).x - barPosition.x;
            x = Math.max(barPosition.x, Math.min(anchorPosition.x - width * scale / 2, barPosition.x + (bar.width - width) * scale));
            y = barPosition.y - (height + 6) * scale;
        }
        width: Math.min(280, bar.width)
        height: Math.min(218, bar.selectedWindows.length * 30 + Math.max(0, bar.selectedWindows.length - 1) * 4 + 8)
        padding: 0
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: null
        contentItem: WindowPicker {
            windows: bar.selectedWindows
            manager: bar.manager
            onFocusRequested: windowId => { bar.focusRequested(windowId); bar.closeWindows(); }
            onCloseRequested: windowId => bar.windowCloseRequested(windowId)
            onMinimizeRequested: windowId => bar.windowMinimizeRequested(windowId)
            onDismissRequested: bar.closeWindows()
        }
        onClosed: {
            bar.pickerOpen = false;
            if (bar.pickerAnchor) bar.pickerAnchor.forceActiveFocus();
            else entries.forceActiveFocus();
        }
    }
}