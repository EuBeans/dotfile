import QtQuick
import Quickshell
import Quickshell.Io
import "../shell/Services"

ShellRoot {
    id: root
    property string pendingPaletteSource: ""
    property string activePaletteSource: ""
    function requestPalette(source) {
        pendingPaletteSource = source;
        if (paletteProcess.running) return;
        activePaletteSource = source;
        paletteProcess.running = true;
    }
    Connections {
        target: studio.desktop.paletteGenerator
        function onGenerationRequested(source) { root.requestPalette(source); }
    }
    Component.onCompleted: Qt.callLater(() => {
        if (studio.desktop.paletteGenerator.extractionEnabled)
            root.requestPalette(String(studio.desktop.paletteGenerator.source));
    })
    Process {
        id: paletteProcess
        command: [decodeURIComponent(Qt.resolvedUrl("../.venv/bin/python").toString().replace(/^file:\/\//, "")),
                  decodeURIComponent(Qt.resolvedUrl("../tools/wallpaper_palette.py").toString().replace(/^file:\/\//, "")), root.activePaletteSource]
        stdout: StdioCollector { id: paletteOutput }
        onExited: (exitCode, exitStatus) => {
            let colors = {};
            if (exitCode === 0 && exitStatus === 0) {
                try { colors = JSON.parse(paletteOutput.text).palette; } catch (_error) {}
            }
            studio.desktop.paletteGenerator.acceptResult(root.activePaletteSource, colors,
                Object.keys(colors || {}).length ? "Ready" : "Wallpaper colors unavailable");
            if (root.pendingPaletteSource !== root.activePaletteSource)
                Qt.callLater(() => root.requestPalette(root.pendingPaletteSource));
        }
    }
    Timer {
        interval: 10000
        running: paletteProcess.running
        onTriggered: paletteProcess.running = false
    }
    LiveDesktop {
        data: studio.fixture.desktopData
        enabled: Quickshell.env("QUICKSHELL_LIVE_SERVICES") === "1"
        allowChanges: Quickshell.env("QUICKSHELL_HOST_CONTROLS") === "1"
        notificationsEnabled: Quickshell.env("QUICKSHELL_NOTIFICATIONS") === "1"
    }
    Process {
        id: hyprquickshot
        command: ["quickshell", "-c", "hyprquickshot", "-n"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                studio.fixture.notify("HyprQuickshot", "Launch failed. Check installation and dependencies.", "critical");
        }
    }
    Process {
        id: workspaceOverview
        command: ["bash", decodeURIComponent(Qt.resolvedUrl("../tools/overview.sh").toString().replace(/^file:\/\//, "")), "toggle"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                studio.fixture.notify("Workspace overview", "Toggle failed. Start tools/overview.sh start in your Hyprland session first.", "critical");
        }
    }
    FloatingWindow {
        implicitWidth: 1440
        implicitHeight: 900
        title: "Quickshell / Preview"
        minimumSize: Qt.size(880, 600)

        PreviewStudio {
            id: studio
            anchors.fill: parent
            onWorkspaceOverviewRequested: {
                if (Quickshell.env("QUICKSHELL_ENABLE_HOST_OVERVIEW") !== "1" || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) {
                    studio.fixture.notify("Workspace overview", "Host overview is disabled or Hyprland is unavailable", "critical");
                    return;
                }
                if (!workspaceOverview.running) workspaceOverview.running = true;
            }
            onScreenshotRequested: {
                if (Quickshell.env("QUICKSHELL_ENABLE_HOST_CAPTURE") !== "1" || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) {
                    studio.fixture.notify("HyprQuickshot", "Host capture is disabled or Hyprland is unavailable", "critical");
                    return;
                }
                if (!hyprquickshot.running) hyprquickshot.running = true;
            }
        }
    }
}