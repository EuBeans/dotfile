import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shell/Components" as Ui
import "../shell/Modules/Hardware" as Hardware
import "../shell/Modules/ControlCenter" as Home
import "../shell/Modules/WallpaperPicker" as Wallpaper
import "../shell/Modules/LocalAI" as AI
import "../shell/Modules/Clipboard" as Clipboard

PanelWindow {
    id: root
    required property var modelData
    required property var service
    readonly property bool requestedOpen: service.sidePage !== "" && service.sideScreen === modelData.name
    property string displayedPage: ""
    onRequestedOpenChanged: if (requestedOpen) displayedPage = service.sidePage
    Connections {
        target: root.service
        function onSidePageChanged() { if (root.requestedOpen) root.displayedPage = root.service.sidePage; }
    }
    screen: modelData
    anchors { right: true; top: true }
    margins { top: Ui.Theme.floatingPanels ? 60 : 48; right: Ui.Theme.floatingPanels ? 12 : 0 }
    implicitWidth: Math.min(560, modelData.width - 24)
    implicitHeight: Math.min(displayedPage === "AI" && sideLoader.item ? sideLoader.item.implicitHeight : 650, modelData.height - 120)
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "custom-shell-side"
    WlrLayershell.keyboardFocus: requestedOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    visible: requestedOpen || drawer.progress > 0
    color: "transparent"

    Ui.RetroDrawer {
        id: drawer
        objectName: "hostSideDrawer"
        anchors.fill: parent
        opened: root.requestedOpen
        reducedMotion: root.service.reducedMotion
        slide: true
        edge: "right"
        onDismissRequested: root.service.sidePage = ""
        Loader {
            id: sideLoader
            anchors.fill: parent
            active: root.visible
            sourceComponent: root.displayedPage === "GPU" ? gpuPanel : root.displayedPage === "Audio" ? audioPanel : root.displayedPage === "AI" ? aiPanel : root.displayedPage === "Clipboard" ? clipboardPanel : wallpaperPanel
        }
    }
    Component {
        id: clipboardPanel
        Clipboard.ClipboardHistory {
            entries: root.service.clipboardEntries
            status: root.service.clipboardStatus
            opened: root.requestedOpen
            onCopyRequested: entryId => root.service.clipboardAction("copy", entryId)
            onPinRequested: (entryId, pinned) => root.service.clipboardAction(pinned ? "pin" : "unpin", entryId)
            onRemoveRequested: entryId => root.service.clipboardAction("delete", entryId)
            onClearRequested: root.service.clipboardAction("clear")
            onCloseRequested: root.service.sidePage = ""
        }
    }
    Component {
        id: aiPanel
        AI.LocalAIPanel {
            service: root.service
            actionsEnabled: root.service.desktopData.controlsEnabled && root.service.modelManager.fresh
            onStartRequested: modelIndex => root.service.modelManager.request("start", modelIndex, false)
            onStopRequested: root.service.modelManager.request("stop", -1, true)
            onSwitchRequested: modelIndex => root.service.modelManager.request("switch", modelIndex, true)
            onAdoptRequested: modelIndex => root.service.modelManager.request("adopt", modelIndex, true)
            onConfigureRequested: modelIndex => root.service.modelManager.request("configure", modelIndex, false)
            onDefaultRequested: modelIndex => root.service.setAiProfileDefault(modelIndex)
            onCloseRequested: root.service.sidePage = ""
        }
    }
    Component {
        id: gpuPanel
        Hardware.GpuPanel {
            gpu: root.service.selectedGpu
            telemetryAvailable: root.service.telemetryAvailable
            metrics: root.service.desktopData.metrics.filter(metric => metric.gpuId === root.service.selectedGpuId)
            history: root.service.desktopData.history
            processes: root.service.desktopData.snapshot.processes
            reducedMotion: root.service.reducedMotion
            color: Ui.Theme.surface
            onCloseRequested: root.service.sidePage = ""
        }
    }
    Component {
        id: wallpaperPanel
        Wallpaper.WallpaperPicker {
            id: wallpaperPicker
            color: Ui.Theme.surface
            showPaletteControls: true
            wallpapers: root.service.wallpapers
            monitorNames: root.service.wallpaperMonitors
            targetMonitor: root.modelData.name
            selected: root.service.wallpaperIndexForMonitor(targetMonitor)
            profileSettings: root.service.profileSettings
            paletteStatus: root.service.wallpaperColorStatus
            folderLoading: root.service.wallpaperFolderLoading
            directoryWallpaperCount: root.service.directoryWallpapers.length
            onSelectedRequested: index => root.service.setWallpaper(index, wallpaperPicker.targetMonitor)
            onCloseRequested: root.service.sidePage = ""
        }
    }
    Component {
        id: audioPanel
        Rectangle {
            color: Ui.Theme.surface
            radius: Ui.Theme.panelRadius
            border.color: Ui.Theme.line
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Ui.Label { text: "Audio"; font.family: Ui.Theme.displayFont; font.pixelSize: 18; Layout.fillWidth: true }
                    Ui.ActionButton { iconName: "x"; description: "Close audio"; onClicked: root.service.sidePage = "" }
                }
                Home.DevicePages { Layout.fillWidth: true; Layout.fillHeight: true; data: root.service.desktopData; section: "Audio" }
            }
        }
    }
}