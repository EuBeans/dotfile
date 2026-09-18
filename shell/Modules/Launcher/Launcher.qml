import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts
import QtCore
import "../../Components" as Ui

Rectangle {
    id: panel
    objectName: "launcherPanel"
    required property var applications
    property var windows: []
    property var files: []
    property bool fileSearchAvailable: false
    property string mode: "Apps"
    readonly property var modes: ["Apps", "Run", "Files", "Windows"]
    property bool opened: false
    property bool favoritesOnly: false
    property var favoriteIds: []
    property var recentIds: []
    Settings {
        id: storage
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-preview/launcher.ini"
        property string favoritesJson: "[]"
        property string recentJson: "[]"
    }
    Component.onCompleted: {
        function validIds(json) {
            try {
                const values = JSON.parse(json);
                return Array.isArray(values) ? Array.from(new Set(values.filter(value => applications.some(app => app.appId === value)))).slice(0, 64) : [];
            } catch (_error) { return []; }
        }
        favoriteIds = validIds(storage.favoritesJson);
        recentIds = validIds(storage.recentJson);
    }
    function toggleFavorite(appId) {
        favoriteIds = favoriteIds.includes(appId) ? favoriteIds.filter(entry => entry !== appId) : favoriteIds.concat([appId]);
        storage.favoritesJson = JSON.stringify(favoriteIds);
        storage.setValue("favoritesJson", storage.favoritesJson);
        storage.sync();
    }
    function launch(appId) {
        recentIds = [appId].concat(recentIds.filter(entry => entry !== appId)).slice(0, 32);
        storage.recentJson = JSON.stringify(recentIds);
        storage.setValue("recentJson", storage.recentJson);
        storage.sync();
        launchRequested(appId);
    }
    readonly property var results: {
        const tokens = search.text.trim().toLowerCase().split(/\s+/).filter(token => token.length);
        if (mode === "Run") return search.text.trim() ? [{name: search.text.trim(), icon: "chevron-right", command: search.text.trim()}] : [];
        if (mode === "Files") return fileSearchAvailable ? files.filter(file => tokens.every(token => (file.name + " " + file.path).toLowerCase().includes(token))) : [];
        if (mode === "Windows") return windows.map(window => {
            const app = applications.find(entry => entry.appId === window.appId);
            return {windowId: window.windowId, name: window.title, detail: [app ? app.name : window.appId, window.subtitle, window.monitor, "Workspace " + window.workspace].join(" / "), icon: app ? app.icon : "monitor"};
        }).filter(window => tokens.every(token => (window.name + " " + window.detail).toLowerCase().includes(token)));
        const matches = applications.filter(app => {
            const text = (app.name + " " + app.category + " " + app.keywords).toLowerCase();
            return tokens.every(token => text.includes(token)) && (!favoritesOnly || favoriteIds.includes(app.appId));
        });
        return tokens.length ? matches : matches.slice().sort((first, second) => {
            const firstRecent = recentIds.indexOf(first.appId);
            const secondRecent = recentIds.indexOf(second.appId);
            return Number(favoriteIds.includes(second.appId)) - Number(favoriteIds.includes(first.appId)) || (firstRecent < 0 ? 999 : firstRecent) - (secondRecent < 0 ? 999 : secondRecent);
        });
    }
    signal launchRequested(string appId)
    signal runRequested(string command)
    signal fileRequested(string path)
    signal windowRequested(int windowId)
    signal closeRequested()
    implicitWidth: 668
    implicitHeight: 404
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius
    onOpenedChanged: if (opened) Qt.callLater(() => {
        if (!panel.opened) return;
        search.clear();
        panel.mode = "Apps";
        panel.favoritesOnly = false;
        resultsList.currentIndex = panel.results.length ? 0 : -1;
        search.forceActiveFocus();
    })
    onResultsChanged: resultsList.currentIndex = results.length ? 0 : -1

    function moveSelection(offset) {
        if (!results.length) return;
        resultsList.currentIndex = Math.max(0, Math.min(results.length - 1, resultsList.currentIndex + offset));
        resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain);
    }
    function launchSelection() {
        if (resultsList.currentIndex < 0 || resultsList.currentIndex >= results.length) return;
        const entry = results[resultsList.currentIndex];
        if (mode === "Apps") launch(entry.appId);
        else if (mode === "Windows") windowRequested(entry.windowId);
        else if (mode === "Files") fileRequested(entry.path);
        else runRequested(entry.command);
    }
    function selectMode(index, focusSearch) {
        mode = modes[(index + modes.length) % modes.length];
        resultsList.currentIndex = results.length ? 0 : -1;
        resultsList.positionViewAtBeginning();
        if (focusSearch) search.forceActiveFocus();
        else tabs.itemAt(modes.indexOf(mode)).forceActiveFocus(Qt.TabFocusReason);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            TextField {
                id: search
                objectName: "launcherSearch"
                anchors.fill: parent
                leftPadding: 36
                rightPadding: clearSearch.visible ? 68 : 36
                placeholderText: panel.mode === "Run" ? "Command..." : "Search..."
                color: Ui.Theme.paper
                placeholderTextColor: Ui.Theme.muted
                selectionColor: Ui.Theme.paper
                selectedTextColor: Ui.Theme.ink
                font.family: Ui.Theme.textFont
                font.pixelSize: 13
                selectByMouse: true
                Accessible.name: panel.mode === "Run" ? "Run command" : "Search " + panel.mode.toLowerCase()
                Keys.onDownPressed: panel.moveSelection(1)
                Keys.onUpPressed: panel.moveSelection(-1)
                Keys.onEscapePressed: panel.closeRequested()
                Keys.onTabPressed: event => {
                    if (event.modifiers & Qt.ControlModifier) panel.selectMode(panel.modes.indexOf(panel.mode) + 1, true);
                    else event.accepted = false;
                }
                onAccepted: panel.launchSelection()
                background: Rectangle {
                    radius: Ui.Theme.radius
                    color: Ui.Theme.groupSurface
                    antialiasing: true
                    border.width: Ui.Theme.controlBorderWidth(search)
                    border.pixelAligned: false
                    border.color: search.activeFocus ? Ui.Theme.paper : Ui.Theme.clear
                }
            }
            IconImage {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: Qt.resolvedUrl("../../Assets/Icons/search.svg")
                color: Ui.Theme.muted
            }
            Ui.ActionButton {
                id: clearSearch
                objectName: "clearLauncherSearch"
                anchors.right: closeButton.left
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 28
                implicitHeight: 28
                iconName: "rotate-ccw"
                description: "Clear search"
                visible: search.text.length > 0
                onClicked: { search.clear(); search.forceActiveFocus(); }
            }
            Ui.ActionButton {
                id: closeButton
                objectName: "closeLauncher"
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 28
                implicitHeight: 28
                iconName: "x"
                description: "Close launcher"
                onClicked: panel.closeRequested()
            }
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Rectangle {
                id: resultFrame
                objectName: "launcherResultFrame"
                anchors.fill: parent
                anchors.topMargin: tabStrip.height - stroke
                readonly property real stroke: Ui.Theme.controlBorderWidth(panel)
                color: Ui.Theme.surface
                radius: Ui.Theme.radius
                antialiasing: true
                border.width: stroke
                border.pixelAligned: false
                border.color: Ui.Theme.paper
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: parent.width
                    height: parent.radius
                    color: parent.color
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: parent.width
                    height: parent.stroke
                    color: Ui.Theme.paper
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: parent.stroke
                    height: parent.radius
                    color: Ui.Theme.paper
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: parent.stroke
                    height: parent.radius
                    color: Ui.Theme.paper
                }
            }
            Row {
                id: tabStrip
                objectName: "launcherTabs"
                width: parent.width
                height: 40
                Repeater {
                    id: tabs
                    model: panel.modes
                    delegate: Ui.ActionButton {
                        id: modeButton
                        required property string modelData
                        required property int index
                        objectName: "launcherTab_" + modelData
                        width: tabStrip.width / panel.modes.length
                        height: tabStrip.height
                        text: modelData
                        padding: 4
                        font.pixelSize: panel.width < 400 ? 11 : 13
                        iconOnly: false
                        iconName: panel.width < 400 ? "" : ["panels-top-left", "chevron-right", "folder-open", "monitor"][index]
                        icon.color: Ui.Theme.paper
                        palette.buttonText: Ui.Theme.paper
                        palette.brightText: Ui.Theme.paper
                        palette.highlight: Ui.Theme.paper
                        palette.highlightedText: Ui.Theme.paper
                        checked: panel.mode === modelData
                        Accessible.role: Accessible.PageTab
                        Accessible.selected: checked
                        onClicked: panel.selectMode(index, true)
                        Keys.onLeftPressed: panel.selectMode(index - 1, false)
                        Keys.onRightPressed: panel.selectMode(index + 1, false)
                        Keys.onDownPressed: search.forceActiveFocus()
                        Keys.onEscapePressed: panel.closeRequested()
                        background: Item {
                            Rectangle {
                                anchors.fill: parent
                                radius: Ui.Theme.radius
                                color: modeButton.down || modeButton.hovered ? Ui.Theme.hover : Ui.Theme.surface
                                border.width: resultFrame.stroke
                                border.color: Ui.Theme.paper
                                antialiasing: true
                                border.pixelAligned: false
                                visible: modeButton.checked || modeButton.activeFocus
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: resultFrame.stroke
                                anchors.rightMargin: resultFrame.stroke
                                height: Ui.Theme.radius
                                color: modeButton.down || modeButton.hovered ? Ui.Theme.hover : Ui.Theme.surface
                                visible: modeButton.checked
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                width: resultFrame.stroke
                                height: Ui.Theme.radius
                                color: Ui.Theme.paper
                                visible: modeButton.checked
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                width: resultFrame.stroke
                                height: Ui.Theme.radius
                                color: Ui.Theme.paper
                                visible: modeButton.checked
                            }
                        }
                    }
                }
            }
            ListView {
                id: resultsList
                objectName: "launcherResults"
                anchors.fill: resultFrame
                anchors.margins: 8
                clip: true
                model: panel.results
                currentIndex: count ? 0 : -1
                keyNavigationEnabled: false
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Keys.onDownPressed: panel.moveSelection(1)
                Keys.onUpPressed: panel.moveSelection(-1)
                Keys.onReturnPressed: panel.launchSelection()
                Keys.onEnterPressed: panel.launchSelection()
                Keys.onEscapePressed: panel.closeRequested()
                delegate: Item {
                    id: appTile
                    required property var modelData
                    required property int index
                    width: resultsList.width
                    height: 36
                    Ui.ActionButton {
                        id: appButton
                        objectName: panel.mode === "Apps" ? "launcherApp_" + appTile.modelData.appId : "launcherResult_" + appTile.index
                        anchors.fill: parent
                        anchors.rightMargin: resultsList.contentHeight > resultsList.height ? 8 : 0
                        anchors.bottomMargin: 4
                        rightPadding: panel.mode === "Apps" ? 36 : 8
                        checked: resultsList.currentIndex === appTile.index
                        description: appTile.modelData.name + (appTile.modelData.detail || appTile.modelData.category || appTile.modelData.path ? " / " + (appTile.modelData.detail || appTile.modelData.category || appTile.modelData.path) : "")
                        onActiveFocusChanged: if (activeFocus) resultsList.currentIndex = appTile.index
                        Keys.onDownPressed: { panel.moveSelection(1); search.forceActiveFocus(); }
                        Keys.onUpPressed: { panel.moveSelection(-1); search.forceActiveFocus(); }
                        Keys.onEscapePressed: panel.closeRequested()
                        onClicked: { resultsList.currentIndex = appTile.index; panel.launchSelection(); }
                        contentItem: RowLayout {
                            spacing: 8
                            IconImage {
                                objectName: "launcherIcon_" + (appTile.modelData.appId || appTile.index)
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                source: Qt.resolvedUrl("../../Assets/Icons/" + (appTile.modelData.icon || "folder-open") + ".svg")
                                color: appButton.checked || appButton.down ? Ui.Theme.ink : Ui.Theme.paper
                            }
                            Ui.Label {
                                objectName: "launcherResultLabel_" + appTile.index
                                text: appTile.modelData.name
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                color: appButton.checked || appButton.down ? Ui.Theme.ink : Ui.Theme.paper
                            }
                        }
                    }
                    Ui.ActionButton {
                        objectName: "launcherPin_" + (appTile.modelData.appId || "")
                        anchors.right: appButton.right
                        anchors.verticalCenter: appButton.verticalCenter
                        anchors.rightMargin: 4
                        implicitWidth: 28
                        implicitHeight: 28
                        iconName: "pin"
                        description: (checked ? "Unpin " : "Pin ") + appTile.modelData.name
                        visible: panel.mode === "Apps" && (appButton.hovered || appButton.checked || hovered || activeFocus || checked)
                        checked: panel.favoriteIds.includes(appTile.modelData.appId)
                        icon.color: checked || down || appButton.checked ? Ui.Theme.ink : Ui.Theme.paper
                        onClicked: panel.toggleFavorite(appTile.modelData.appId)
                    }
                }
                Ui.Label {
                    objectName: "launcherEmptyState"
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - 16)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: panel.mode === "Run" ? "No command entered" : panel.mode === "Files" && !panel.fileSearchAvailable ? "File search unavailable" : "No matching " + (panel.mode === "Apps" ? "applications" : panel.mode.toLowerCase())
                    color: Ui.Theme.muted
                    visible: resultsList.count === 0
                }
            }
        }
    }
}