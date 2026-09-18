import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shell/Components" as Ui
import "../shell/Modules/Hardware"

Item {
    id: scene
    objectName: "tilingScene"
    required property var manager
    property var service: null
    signal arrangeRequested()
    signal summaryFloatRequested()
    property bool shown: false
    property bool reducedMotion: false
    property string layoutMode: "Auto"
    property int gap: 12
    property int outerGap: 12
    property int mainPaneRatio: 56
    property int windowBorderWidth: 2
    property int workspace: 1
    readonly property int focusedIndex: manager.focusedId
    readonly property int floatingIndex: {
        const window = windows.find(entry => entry.windowId === focusedIndex && entry.floating);
        return window ? window.windowId : -1;
    }
    property int maximizedIndex: -1
    readonly property string effectiveLayout: layoutMode === "Auto" ? (width >= 2560 ? "Centered" : "Split") : layoutMode
    readonly property var windows: manager.visibleWindows
    visible: shown
    onWorkspaceChanged: maximizedIndex = -1
    onWindowsChanged: if (!windows.some(window => window.windowId === maximizedIndex)) maximizedIndex = -1
    function focusWindow(index) { manager.focus(index); }
    function promote() {
        manager.place(focusedIndex, 0);
    }
    function toggleFloating() {
        maximizedIndex = -1;
        manager.setFloating(focusedIndex, floatingIndex !== focusedIndex);
    }
    function toggleMaximized() { maximizedIndex = maximizedIndex === focusedIndex ? -1 : focusedIndex; }
    function geometry(index) {
        const inset = Math.min(64, Math.max(0, outerGap));
        const areaWidth = Math.max(1, width - inset * 2);
        const areaHeight = Math.max(1, height - inset * 2);
        if (maximizedIndex === index) return Qt.rect(inset, inset, areaWidth, areaHeight);
        const window = windows.find(entry => entry.windowId === index);
        if (!window) return Qt.rect(0, 0, 0, 0);
        if (window.floating) {
            const windowWidth = Math.min(1000, areaWidth * 0.68);
            return Qt.rect((width - windowWidth) / 2, inset + areaHeight * 0.18, windowWidth, areaHeight * 0.64);
        }
        const tiled = windows.filter(entry => !entry.floating).map(entry => entry.windowId);
        const slot = tiled.indexOf(index);
        const gutter = Math.max(0, Math.min(32, gap, Math.min(areaWidth, areaHeight) / Math.max(1, tiled.length * 2)));
        if (tiled.length === 1) return Qt.rect(inset, inset, areaWidth, areaHeight);
        if (areaWidth < 850) {
            const rowHeight = (areaHeight - gutter * (tiled.length - 1)) / tiled.length;
            return Qt.rect(inset, inset + slot * (rowHeight + gutter), areaWidth, rowHeight);
        }
        if (tiled.length === 2 || effectiveLayout === "Columns") {
            const columnWidth = (areaWidth - gutter * (tiled.length - 1)) / tiled.length;
            return Qt.rect(inset + slot * (columnWidth + gutter), inset, columnWidth, areaHeight);
        }
        if (effectiveLayout === "Centered") {
            const centerWidth = (areaWidth - gutter * 2) * mainPaneRatio / 100;
            const sideWidth = (areaWidth - centerWidth - gutter * 2) / 2;
            if (slot === 0) return Qt.rect(inset + sideWidth + gutter, inset, centerWidth, areaHeight);
            const left = slot % 2 === 1;
            const sideCount = left ? Math.ceil((tiled.length - 1) / 2) : Math.floor((tiled.length - 1) / 2);
            const rowHeight = (areaHeight - gutter * (sideCount - 1)) / sideCount;
            return Qt.rect(left ? inset : inset + sideWidth + centerWidth + gutter * 2, inset + Math.floor((slot - 1) / 2) * (rowHeight + gutter), sideWidth, rowHeight);
        }
        const mainWidth = (areaWidth - gutter) * mainPaneRatio / 100;
        if (slot === 0) return Qt.rect(inset, inset, mainWidth, areaHeight);
        const sideHeight = (areaHeight - gutter * (tiled.length - 2)) / (tiled.length - 1);
        return Qt.rect(inset + mainWidth + gutter, inset + (slot - 1) * (sideHeight + gutter), areaWidth - mainWidth - gutter, sideHeight);
    }
    Repeater {
        model: scene.windows
        Rectangle {
            id: tile
            required property int index
            required property var modelData
            readonly property rect bounds: scene.geometry(modelData.windowId)
            objectName: "tile" + modelData.windowId
            x: bounds.x
            y: bounds.y
            width: bounds.width
            height: bounds.height
            z: modelData.floating ? 2 : 0
            visible: scene.maximizedIndex < 0 || scene.maximizedIndex === modelData.windowId
            color: Ui.Theme.windowSurface
            border.width: scene.windowBorderWidth
            border.color: scene.focusedIndex === modelData.windowId ? Ui.Theme.paper : Ui.Theme.line
            radius: Ui.Theme.windowRadius
            clip: true
            Accessible.name: modelData.title + " / Workspace " + scene.workspace
            MouseArea { anchors.fill: parent; onClicked: scene.focusWindow(tile.modelData.windowId) }
            ColumnLayout {
                visible: tile.modelData.appId !== "system-summary"
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20
                RowLayout {
                    Layout.fillWidth: true
                    Ui.Label { text: tile.modelData.title; font.family: Ui.Theme.displayFont; Layout.fillWidth: true }
                    Ui.Label { text: tile.modelData.subtitle; color: Ui.Theme.muted; font.pixelSize: 11; Layout.maximumWidth: tile.width / 2 }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: sample.implicitHeight
                    contentWidth: width
                    Ui.Label {
                        id: sample
                        width: parent.width
                        text: tile.modelData.body
                        font.pixelSize: 14
                        lineHeight: 1.65
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideNone
                    }
                    TapHandler { onTapped: scene.focusWindow(tile.modelData.windowId) }
                }
            }
            Loader {
                anchors.fill: parent
                anchors.margins: scene.windowBorderWidth
                active: tile.modelData.appId === "system-summary" && scene.service !== null
                sourceComponent: Component {
                    SystemSummary {
                        service: scene.service
                        tiled: true
                        onTileRequested: { scene.manager.focus(tile.modelData.windowId); scene.arrangeRequested(); }
                        onFloatRequested: { scene.summaryFloatRequested(); scene.manager.close(tile.modelData.windowId); }
                        onCloseRequested: scene.manager.close(tile.modelData.windowId)
                    }
                }
            }
        }
    }
}