import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts
import QtCore
import "../../Components" as Ui

Rectangle {
    id: panel
    required property var applications
    property bool opened: false
    property bool favoritesOnly: false
    property bool gridMode: false
    property var favoriteIds: []
    property var recentIds: []
    readonly property var categories: ["All categories"].concat(Array.from(new Set(applications.map(app => app.category))).sort())
    Settings {
        id: storage
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-preview/launcher.ini"
        property string favoritesJson: "[]"
        property string recentJson: "[]"
        property bool grid: false
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
        gridMode = storage.grid;
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
        const matches = applications.filter(app => {
            const text = (app.name + " " + app.category + " " + app.keywords).toLowerCase();
            return tokens.every(token => text.includes(token)) && (!favoritesOnly || favoriteIds.includes(app.appId)) && (category.currentIndex <= 0 || app.category === category.currentText);
        });
        return tokens.length ? matches : matches.slice().sort((first, second) => {
            const firstRecent = recentIds.indexOf(first.appId);
            const secondRecent = recentIds.indexOf(second.appId);
            return Number(favoriteIds.includes(second.appId)) - Number(favoriteIds.includes(first.appId)) || (firstRecent < 0 ? 999 : firstRecent) - (secondRecent < 0 ? 999 : secondRecent);
        });
    }
    signal launchRequested(string appId)
    signal closeRequested()
    implicitWidth: 620
    implicitHeight: 580
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius
    onOpenedChanged: if (opened) Qt.callLater(() => {
        if (!panel.opened) return;
        search.clear();
        category.currentIndex = 0;
        panel.favoritesOnly = false;
        resultsList.currentIndex = panel.results.length ? 0 : -1;
        search.forceActiveFocus();
    })
    onResultsChanged: resultsList.currentIndex = results.length ? 0 : -1

    function moveSelection(offset) {
        if (!results.length) return;
        resultsList.currentIndex = Math.max(0, Math.min(results.length - 1, resultsList.currentIndex + offset));
        resultsList.positionViewAtIndex(resultsList.currentIndex, GridView.Contain);
    }
    function launchSelection() {
        if (resultsList.currentIndex >= 0 && resultsList.currentIndex < results.length)
            launch(results[resultsList.currentIndex].appId);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        RowLayout {
            Ui.Label { text: "APPLICATIONS"; font.family: Ui.Theme.displayFont; font.pixelSize: 18; Layout.fillWidth: true }
            Ui.ActionButton { objectName: "closeLauncher"; iconName: "x"; description: "Close launcher"; onClicked: panel.closeRequested() }
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.TextField {
                id: search
                objectName: "launcherSearch"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                implicitHeight: 40
                placeholderText: "Search applications"
                color: Ui.Theme.paper
                placeholderTextColor: Ui.Theme.muted
                selectionColor: Ui.Theme.paper
                selectedTextColor: Ui.Theme.ink
                font.family: Ui.Theme.textFont
                font.pixelSize: 14
                selectByMouse: true
                Accessible.name: "Search applications"
                Keys.onDownPressed: panel.moveSelection(1)
                Keys.onUpPressed: panel.moveSelection(-1)
                onAccepted: panel.launchSelection()
            }
            Ui.ActionButton {
                objectName: "clearLauncherSearch"
                iconName: "x"
                description: "Clear search"
                enabled: search.text.length > 0
                onClicked: { search.clear(); search.forceActiveFocus(); }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.Dropdown {
                id: category
                objectName: "launcherCategory"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.maximumWidth: 260
                model: panel.categories
                Accessible.name: "Application category"
            }
            Item { Layout.fillWidth: true }
            Ui.ActionButton { objectName: "launcherFavorites"; iconName: "pin"; description: "Favorites"; checked: panel.favoritesOnly; onClicked: panel.favoritesOnly = !panel.favoritesOnly }
            Ui.ActionButton {
                objectName: "launcherViewMode"
                iconName: panel.gridMode ? "type" : "panels-top-left"
                description: panel.gridMode ? "List view" : "Grid view"
                onClicked: { panel.gridMode = !panel.gridMode; storage.grid = panel.gridMode; storage.setValue("grid", storage.grid); storage.sync(); }
            }
        }
        GridView {
            id: resultsList
            objectName: "launcherResults"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: panel.gridMode ? width / Math.max(1, Math.floor(width / 170)) : width
            cellHeight: panel.gridMode ? 118 : 72
            model: panel.results
            currentIndex: count ? 0 : -1
            keyNavigationEnabled: false
            ScrollBar.vertical: ScrollBar {}
            Keys.onDownPressed: panel.moveSelection(1)
            Keys.onUpPressed: panel.moveSelection(-1)
            Keys.onReturnPressed: panel.launchSelection()
            Keys.onEnterPressed: panel.launchSelection()
            delegate: Item {
                id: appTile
                required property var modelData
                required property int index
                width: resultsList.cellWidth
                height: resultsList.cellHeight
                Ui.ActionButton {
                    id: appButton
                    objectName: "launcherApp_" + appTile.modelData.appId
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    anchors.bottomMargin: 6
                    rightPadding: 40
                    checked: resultsList.currentIndex === appTile.index
                    description: appTile.modelData.name + " / " + appTile.modelData.category
                    onActiveFocusChanged: if (activeFocus) resultsList.currentIndex = appTile.index
                    Keys.onDownPressed: { panel.moveSelection(1); search.forceActiveFocus(); }
                    Keys.onUpPressed: { panel.moveSelection(-1); search.forceActiveFocus(); }
                    Keys.onRightPressed: if (panel.gridMode) panel.moveSelection(1)
                    Keys.onLeftPressed: if (panel.gridMode) panel.moveSelection(-1)
                    onClicked: panel.launch(appTile.modelData.appId)
                    contentItem: GridLayout {
                        columns: panel.gridMode ? 1 : 2
                        columnSpacing: 14
                        rowSpacing: 6
                        IconImage {
                            objectName: "launcherIcon_" + appTile.modelData.appId
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            source: Qt.resolvedUrl("../../Assets/Icons/" + appTile.modelData.icon + ".svg")
                            color: appButton.checked || appButton.down ? Ui.Theme.ink : Ui.Theme.paper
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Ui.Label { text: appTile.modelData.name; Layout.fillWidth: true; color: appButton.checked || appButton.down ? Ui.Theme.ink : Ui.Theme.paper }
                            Ui.Label { text: appTile.modelData.category; Layout.fillWidth: true; font.pixelSize: 11; color: appButton.checked || appButton.down ? Ui.Theme.ink : Ui.Theme.muted }
                        }
                    }
                }
                Ui.ActionButton {
                    objectName: "launcherPin_" + appTile.modelData.appId
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    implicitWidth: 28
                    implicitHeight: 28
                    iconName: "pin"
                    description: (checked ? "Unpin " : "Pin ") + appTile.modelData.name
                    checked: panel.favoriteIds.includes(appTile.modelData.appId)
                    icon.color: checked || down || appButton.checked ? Ui.Theme.ink : Ui.Theme.paper
                    onClicked: panel.toggleFavorite(appTile.modelData.appId)
                }
            }
            Ui.Label {
                objectName: "launcherEmptyState"
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: panel.favoritesOnly && !panel.favoriteIds.length ? "No pinned applications" : "No matching applications"
                color: Ui.Theme.muted
                visible: resultsList.count === 0
            }
        }
        Ui.Label { text: panel.results.length + (panel.results.length === 1 ? " application" : " applications"); color: Ui.Theme.muted; font.pixelSize: 11 }
    }
}