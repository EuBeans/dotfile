import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shell/Modules/ControlCenter" as Home
import "../shell/Components" as Ui
import "../shell/Modules/Settings" as Settings

PanelWindow {
    id: root
    required property var modelData
    required property var service
    readonly property bool requestedOpen: service.homeOpen && service.homeScreen === modelData.name
    screen: modelData
    anchors { left: true; top: true }
    margins { left: Ui.Theme.floatingPanels ? 12 : 0; top: Ui.Theme.floatingPanels ? 60 : 48 }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.min(service.homePage === "Session" ? 280 : 620, modelData.width - 24)
    implicitHeight: Math.min(service.homePage === "Session" ? 340 : 530, modelData.height - 130)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "custom-shell-home"
    WlrLayershell.keyboardFocus: requestedOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: requestedOpen || drawer.progress > 0
    onRequestedOpenChanged: if (!requestedOpen && service.homeScreen === modelData.name) service.shortcuts.recording = ""
    ShortcutInhibitor {
        window: root
        enabled: root.requestedOpen && root.service.shortcuts.recording !== ""
        onCancelled: root.service.shortcuts.recording = ""
    }

    Ui.RetroDrawer {
        id: drawer
        objectName: "hostHomeDrawer"
        anchors.fill: parent
        opened: root.requestedOpen
        reducedMotion: root.service.reducedMotion
        slide: true
        edge: "left"
        onDismissRequested: root.service.closeHome()
        Loader {
            id: panelLoader
            anchors.fill: parent
            active: root.visible
            sourceComponent: root.service.homePage === "Session" ? sessionPanel : homePanel
        }
        Component {
            id: homePanel
            Home.ControlCenter {
                production: true
                settingsContent: Component { Settings.SettingsView { embedded: true; production: true; service: root.service; shortcuts: root.service.shortcuts } }
                color: Ui.Theme.surface
                service: root.service
                shortcuts: root.service.shortcuts
                opened: root.visible
                page: root.service.homePage
                focus: true
                Keys.onEscapePressed: root.service.closeHome()
                onCloseRequested: root.service.closeHome()
                onVolumeRequested: value => root.service.volumeRequested(value)
                onOutputMuteRequested: muted => root.service.outputMuteRequested(muted)
                onWallpaperSelected: index => root.service.setWallpaper(index)
                onWallpaperRequested: root.service.openSidePanel("Wallpaper", root.modelData.name, -1)
                onAudioRequested: root.service.openSidePanel("Audio", root.modelData.name, -1)
                onSettingsRequested: root.service.openHome("Settings", root.modelData.name)
                onToggleRequested: (setting, value) => root.service.toggleRequested(setting, value)
                onProfileRequested: name => root.service.applyProfile(name)
                onPlaybackRequested: root.service.playbackRequested()
                onPreviousRequested: root.service.previousRequested()
                onNextRequested: root.service.nextRequested()
                onSeekRequested: position => root.service.seekRequested(position)
            }
        }
    }
    Component {
        id: sessionPanel
        Home.PowerMenu {
            production: true
            actionsEnabled: root.service.desktopData.controlsEnabled && !root.service.sessionActionBusy
            lastAction: root.service.sessionActionStatus
            onCloseRequested: root.service.closeHome()
            onActionRequested: action => root.service.requestSessionAction(action)
        }
    }
    Connections {
        target: root.service
        function onHomeRequested(page) {
            if (panelLoader.item && panelLoader.item.page !== undefined) panelLoader.item.page = page;
        }
    }
}