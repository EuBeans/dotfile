import QtQuick
import QtQuick.Window

Window {
    property alias ultrawide: studio.ultrawide
    property alias oneToOne: studio.oneToOne
    property alias specimenVisible: studio.specimenVisible
    width: 1440
    height: 900
    minimumWidth: 880
    minimumHeight: 600
    visible: true
    title: "Quickshell / Preview"

    PreviewStudio {
        id: studio
        anchors.fill: parent
        onScreenshotRequested: studio.fixture.notify("HyprQuickshot", "Unavailable in the native preview", "critical")
        onWorkspaceOverviewRequested: studio.fixture.notify("Workspace overview", "Requires Quickshell and a Hyprland session", "critical")
    }
}