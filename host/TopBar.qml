import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shell/Modules/Bar" as Bars

PanelWindow {
    id: root
    required property var modelData
    required property var service
    screen: modelData
    anchors { left: true; right: true; top: true }
    implicitHeight: bar.implicitHeight
    exclusiveZone: implicitHeight
    aboveWindows: true
    WlrLayershell.namespace: "custom-shell-top"
    color: "transparent"

    IdleInhibitor {
        window: root
        enabled: root.service.caffeineEnabled
    }

    Bars.Bar {
        id: bar
        anchors.fill: parent
        state: root.service
        showNetworkButton: true
        onNetworkRequested: root.service.openHome("Network", root.modelData.name)
        onControlsRequested: root.service.openHome("Home", root.modelData.name)
        onCalendarRequested: root.service.openHome("Calendar", root.modelData.name)
        onSummaryRequested: root.service.openHome("System", root.modelData.name)
        onWallpaperRequested: root.service.openSidePanel("Wallpaper", root.modelData.name, -1)
        onVolumeRequested: root.service.openSidePanel("Audio", root.modelData.name, -1)
        onOutputVolumeRequested: value => root.service.volumeRequested(value)
        onAiRequested: root.service.openSidePanel("AI", root.modelData.name, -1)
        onGpuRequested: index => root.service.openSidePanel("GPU", root.modelData.name, index)
        onSettingsRequested: root.service.openHome("Settings", root.modelData.name)
        onPowerRequested: root.service.openHome("Session", root.modelData.name)
        onPlaybackRequested: root.service.playbackRequested()
        onPreviousRequested: root.service.previousRequested()
        onNextRequested: root.service.nextRequested()
        onSeekRequested: position => root.service.seekRequested(position)
    }
}