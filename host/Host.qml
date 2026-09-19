import QtQuick
import Quickshell
import Quickshell.Io
import "../shell/Components" as Ui
import "Services"

ProductionDesktopData {
    id: shell

    IpcHandler {
        target: "host"
        function openHome(page: string, screenName: string): void { shell.openHome(page, screenName); }
        function closeHome(): void { shell.closeHome(); }
        function home(page: string): void { shell.openHome(page, ""); }
        function side(page: string, screenName: string, gpuIndex: int): void { shell.openSidePanel(page, screenName, gpuIndex); }
        function closeSide(): void { shell.sidePage = ""; }
        function launcher(): void { shell.openLauncher(); }
        function clipboard(): void { shell.openSidePanel("Clipboard", "", 0); }
        function unavailable(feature: string): void { shell.notify(feature, "Provider is not configured yet"); }
        function activateWorkspace(number: int): void { shell.windowManager.activeWorkspace = number; }
        function focusWindow(windowId: int): void { shell.windowManager.focus(windowId); }
        function minimize(): void { shell.windowManager.minimize(shell.windowManager.focusedId); }
        function restore(): void { shell.windowManager.restoreLast(); }
        function media(action: string): void {
            if (action === "toggle") shell.playbackRequested();
            else if (action === "next") shell.nextRequested();
            else if (action === "previous") shell.previousRequested();
        }
        function overview(): void { shell.openWorkspaceOverview(); }
        function volume(value: int): void { shell.volumeRequested(value); }
        function toggle(setting: string, enabled: bool): void { shell.toggleRequested(setting, enabled); }
        function profile(name: string): void { shell.applyProfile(name); }
        function theme(name: string): void {
            if (name === "Wallpaper") shell.profileSettings.update("source", name);
            else if (shell.profileSettings.paletteNames.includes(name)) {
                shell.profileSettings.update("source", "Saved");
                shell.profileSettings.update("palette", name);
            }
        }
        function status(): string {
            return JSON.stringify({screens: Quickshell.screens.map(screen => screen.name),
                homeOpen: shell.homeOpen, homePage: shell.homePage, homeScreen: shell.homeScreen,
                sidePage: shell.sidePage, sideScreen: shell.sideScreen, wallpapers: shell.wallpapers.length,
                profile: shell.profile, palette: shell.profileSettings.currentProfile.palette,
                paletteSource: shell.profileSettings.currentProfile.source, themeColors: Ui.Theme.palette,
                wallpaperColorStatus: shell.wallpaperColorStatus, paletteWallpaperSource: shell.paletteWallpaperSource,
                workspaces: shell.windowManager.workspaces, windows: shell.windowManager.windows.length,
                activeWorkspace: shell.windowManager.observedWorkspace, focusedId: shell.windowManager.focusedId,
                live: shell.desktopData.live, fresh: shell.desktopData.fresh,
                controlsEnabled: shell.desktopData.controlsEnabled,
                dndEnabled: shell.dndEnabled, caffeineEnabled: shell.caffeineEnabled,
                caffeineSleepInhibitor: shell.caffeineSleepInhibitor,
                bluetoothEnabled: shell.bluetoothEnabled, nightLightEnabled: shell.nightLightEnabled,
                displayControlsEnabled: shell.desktopData.displayControlsEnabled,
                notificationCount: shell.desktopData.notifications.length,
                clipboardWatching: shell.clipboardWatching, clipboardCount: shell.clipboardEntries.length,
                clipboardStatus: shell.clipboardStatus,
                applications: shell.launcherApplications.length, launcherOpen: shell.launcherOpen,
                audioOutputs: shell.desktopData.devices.sinks.length,
                volume: shell.volume, muted: shell.outputMuted, audioStreams: shell.desktopData.devices.streams.length,
                networks: shell.desktopData.devices.network.length,
                powerProfile: shell.desktopData.devices.powerProfile, ai: shell.aiStatus});
        }
    }

    Variants {
        model: Quickshell.screens
        TopBar { service: shell }
    }
    Variants {
        model: Quickshell.screens
        BottomBar { service: shell }
    }
    Variants {
        model: Quickshell.screens
        WallpaperSurface { service: shell }
    }
    Variants {
        model: Quickshell.screens
        HomeDrawer { service: shell }
    }
    Variants {
        model: Quickshell.screens
        LauncherWindow { service: shell }
    }
    Variants {
        model: Quickshell.screens
        SidePanel { service: shell }
    }
}