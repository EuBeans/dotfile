import Quickshell
import Quickshell.Io
import "../shell/Services"

ShellRoot {
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
    FloatingWindow {
        implicitWidth: 1440
        implicitHeight: 900
        title: "Quickshell / Preview"
        minimumSize: Qt.size(880, 600)

        PreviewStudio {
            id: studio
            anchors.fill: parent
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