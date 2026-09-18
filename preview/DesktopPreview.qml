import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shell/Components" as Ui
import "../shell/Modules/Bar"
import "../shell/Modules/Audio"
import "../shell/Modules/Launcher"
import "../shell/Modules/Windows"
import "../shell/Modules/Clipboard"
import "../shell/Modules/WallpaperPicker"
import "../shell/Modules/LocalAI"
import "../shell/Modules/Hardware"
import "../shell/Modules/Calendar"
import "../shell/Modules/ControlCenter"
import "../shell/Modules/Settings"

Item {
    id: desktop
    required property var state
    property string openPanel: ""
    signal launcherClosed()
    signal overviewClosed()
    signal clipboardClosed()
    signal screenshotRequested()
    signal lockPreviewRequested()
    property int selectedGpu: 0
    readonly property alias tiling: tiling
    property bool notificationsReady: false
    property bool summaryPinned: false
    ProfileSwitch { id: profileSwitch; service: desktop.state }
    function nextProfile() {
        const profiles = state.profileSettings.profiles;
        profileSwitch.confirm(profiles[(profiles.findIndex(entry => entry.name === state.profile) + 1) % profiles.length].name);
    }
    readonly property var summaryPosition: state.profileSettings.currentProfile.tiling ? state.profileSettings.currentProfile.tiling.summary : ({x: 0, y: 0})
    function moveSummary(deltaX, deltaY) {
        const origin = mapFromGlobal(0, 0);
        const offset = mapFromGlobal(deltaX, deltaY);
        const maxX = Math.max(0, width - summaryDrawer.width - 24);
        const maxY = Math.max(0, bottomBar.y - bar.height - summaryDrawer.height - 28);
        const position = {
            x: maxX ? Math.max(0, Math.min(1, (summaryDrawer.x - 12 + offset.x - origin.x) / maxX)) : 0,
            y: maxY ? Math.max(0, Math.min(1, (summaryDrawer.y - bar.height - 16 + offset.y - origin.y) / maxY)) : 0
        };
        state.profileSettings.setCategory("tiling", Object.assign({}, state.profileSettings.currentProfile.tiling, {summary: position}));
    }
    function tileSummary() {
        const existing = state.windowManager.windows.find(entry => entry.appId === "system-summary");
        if (existing) state.windowManager.focus(existing.windowId);
        else state.windowManager.open("system-summary");
        summaryPinned = false;
        tiling.shown = true;
        openPanel = "overview";
    }
    Component.onCompleted: notificationsReady = true
    Connections {
        target: desktop.state.profileSettings
        function onActiveNameChanged() {
            if (desktop.notificationsReady && desktop.state.initialized) desktop.state.notify("Profile changed", desktop.state.profile);
        }
        function onPaletteChanged() {
            if (desktop.notificationsReady && desktop.state.initialized) desktop.state.notify("Palette changed", desktop.state.profileSettings.currentProfile.source === "Wallpaper" ? "Wallpaper colors" : desktop.state.profileSettings.currentProfile.palette);
        }
    }
    clip: true
    focus: true
    Binding { target: Ui.Theme; property: "palette"; value: desktop.state.profileSettings.palette }
    Binding { target: Ui.Theme; property: "glassEnabled"; value: desktop.state.profileSettings.glassEnabled }
    Binding { target: Ui.Theme; property: "floatingPanels"; value: desktop.state.profileSettings.floatingPanels }
    Binding { target: Ui.Theme; property: "panelRadius"; value: desktop.state.profileSettings.panelRadius }
    Binding { target: Ui.Theme; property: "barRadius"; value: desktop.state.profileSettings.barRadius }
    Binding { target: Ui.Theme; property: "windowRadius"; value: desktop.state.profileSettings.windowRadius }
    Binding { target: Ui.Theme; property: "animationStyle"; value: desktop.state.profileSettings.animationStyle }
    Binding { target: Ui.Theme; property: "animationDuration"; value: desktop.state.profileSettings.animationDuration }
    Binding { target: Ui.Theme; property: "panelOpacity"; value: desktop.state.profileSettings.panelOpacity }
    Binding { target: Ui.Theme; property: "windowOpacity"; value: desktop.state.profileSettings.windowOpacity }
    WallpaperPalette {
        id: wallpaperPalette
        objectName: "wallpaperPalette"
        source: desktop.state.selectedWallpaper.source
    }
    Binding { target: desktop.state.profileSettings; property: "sampledPalette"; value: wallpaperPalette.palette }
    Keys.onEscapePressed: openPanel = ""
    property string lastPanel: ""
    onOpenPanelChanged: {
        shortcuts.recording = "";
        if (openPanel === "") {
            const triggers = {calendar: "clockButton", gpu: "barGpu" + selectedGpu, ai: "aiButton", controls: "controlsButton", wallpaper: "wallpaperButton", volume: "volumeButton", power: "powerButton"};
            if (lastPanel === "launcher") launcherClosed();
            else if (lastPanel === "windows") overviewClosed();
            else if (lastPanel === "clipboard") clipboardClosed();
            else if (lastPanel === "summary") focusTrigger(bottomBar, "bottomLauncher");
            else focusTrigger(bar, triggers[lastPanel] || "controlsButton");
        } else forceActiveFocus();
        lastPanel = openPanel;
    }
    function focusTrigger(item, name) {
        if (item.objectName === name) { item.forceActiveFocus(); return true; }
        for (const child of item.children) {
            if (focusTrigger(child, name)) return true;
        }
        return false;
    }
    function togglePanel(name) { openPanel = openPanel === name ? "" : name; }
    function cycleWindows(direction) { windowSwitcher.cycle(direction); }
    Shortcut {
        sequence: "Alt+Tab"
        context: Qt.WindowShortcut
        enabled: shortcuts.recording === "" && !settingsWindow.visible
        onActivated: windowSwitcher.cycle(1)
    }
    Shortcut {
        sequence: "Alt+Shift+Tab"
        context: Qt.WindowShortcut
        enabled: shortcuts.recording === "" && !settingsWindow.visible
        onActivated: windowSwitcher.cycle(-1)
    }
    WindowSwitcher {
        id: windowSwitcher
        applications: desktop.state.launcherApps
        z: 20
        anchors.centerIn: parent
        width: Math.min(implicitWidth, desktop.width - 24)
        height: Math.min(implicitHeight, desktop.height - 24)
        windows: desktop.state.windowManager.windows
        recentIds: desktop.state.windowManager.recentIds
        focusedId: desktop.state.windowManager.focusedId
        reducedMotion: desktop.state.reducedMotion
        onFocusRequested: windowId => {
            desktop.state.windowManager.focus(windowId);
            tiling.shown = true;
            tiling.maximizedIndex = -1;
            desktop.openPanel = "";
        }
    }
    ShortcutSettings {
        id: shortcuts
        onActivated: action => {
            if (action === "settings") settingsWindow.open();
            else if (action === "profile") desktop.nextProfile();
            else if (action === "playback") { if (desktop.state.mediaAvailable) desktop.state.playing = !desktop.state.playing; }
            else if (action === "previous") desktop.state.skipTrack(-1);
            else if (action === "next") desktop.state.skipTrack(1);
            else if (action.startsWith("workspace")) desktop.state.workspace = Number(action.substring(9));
            else desktop.togglePanel(action);
        }
    }

    SettingsWindow {
        id: settingsWindow
        service: desktop.state
        shortcuts: shortcuts
    }
    Image {
        anchors.fill: parent
        source: desktop.state.selectedWallpaper.source
        fillMode: Image.PreserveAspectCrop
    }
    MouseArea {
        anchors.fill: parent
        onClicked: desktop.openPanel = ""
    }
    TilingPreview {
        id: tiling
        manager: desktop.state.windowManager
        service: desktop.state
        onArrangeRequested: desktop.openPanel = "overview"
        onSummaryFloatRequested: { desktop.summaryPinned = true; desktop.openPanel = ""; }
        reducedMotion: desktop.state.reducedMotion
        gap: desktop.state.profileSettings.tileGap
        outerGap: desktop.state.profileSettings.outerGap
        layoutMode: desktop.state.profileSettings.tilingLayout
        mainPaneRatio: desktop.state.profileSettings.mainPaneRatio
        windowBorderWidth: desktop.state.profileSettings.windowBorderWidth
        anchors.top: bar.bottom
        anchors.bottom: bottomBar.top
        width: parent.width
        workspace: desktop.state.workspace
        enabled: desktop.openPanel === ""
    }
    Bar {
        id: bar
        anchors.top: parent.top
        width: parent.width
        height: implicitHeight
        state: desktop.state
        openPanel: desktop.openPanel
        selectedGpu: desktop.selectedGpu
        settingsOpen: settingsWindow.visible
        onWorkspaceRequested: number => desktop.state.workspace = number
        onPlaybackRequested: desktop.state.playing = !desktop.state.playing
        onPreviousRequested: desktop.state.skipTrack(-1)
        onNextRequested: desktop.state.skipTrack(1)
        onSeekRequested: position => desktop.state.trackPosition = position
        onProfileRequested: desktop.nextProfile()
        onWallpaperRequested: desktop.togglePanel("wallpaper")
        onVolumeRequested: desktop.togglePanel("volume")
        onAiRequested: desktop.togglePanel("ai")
        onGpuRequested: index => {
            const closing = desktop.openPanel === "gpu" && desktop.selectedGpu === index;
            desktop.selectedGpu = index;
            desktop.openPanel = closing ? "" : "gpu";
        }
        onPowerRequested: desktop.togglePanel("power")
        onControlsRequested: desktop.togglePanel("controls")
        onSettingsRequested: settingsWindow.open()
        onCalendarRequested: desktop.togglePanel("calendar")
        onSummaryRequested: { controls.page = "System"; desktop.openPanel = "controls"; }
    }
    BottomBar {
        id: bottomBar
        anchors.alignWhenCentered: false
        compact: desktop.width < 400
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, desktop.width - 24)
        manager: desktop.state.windowManager
        applications: desktop.state.launcherApps
        openPanel: desktop.openPanel
        onLauncherRequested: desktop.togglePanel("launcher")
        onCaptureRequested: { desktop.openPanel = ""; desktop.screenshotRequested(); }
        onFocusRequested: windowId => {
            desktop.state.windowManager.focus(windowId);
            tiling.shown = true;
            tiling.maximizedIndex = -1;
            desktop.openPanel = "";
        }
    }
    Ui.RetroDrawer {
        id: summaryDrawer
        objectName: "summaryDrawer"
        x: 12 + Math.max(0, desktop.width - width - 24) * Math.max(0, Math.min(1, desktop.summaryPosition.x))
        y: bar.height + 16 + Math.max(0, bottomBar.y - bar.height - height - 28) * Math.max(0, Math.min(1, desktop.summaryPosition.y))
        width: Math.min(summary.implicitWidth, desktop.width - 24)
        height: Math.max(80, Math.min(summary.implicitHeight, bottomBar.y - bar.height - 28))
        floating: true
        opened: desktop.openPanel === "summary" || desktop.summaryPinned
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: { desktop.summaryPinned = false; desktop.openPanel = ""; }
        SystemSummary {
            id: summary
            anchors.fill: parent
            service: desktop.state
            pinned: desktop.summaryPinned
            onMoveRequested: (deltaX, deltaY) => desktop.moveSummary(deltaX, deltaY)
            onTileRequested: desktop.tileSummary()
            onPinRequested: pinned => { desktop.summaryPinned = pinned; if (pinned) desktop.openPanel = ""; }
            onCloseRequested: { desktop.summaryPinned = false; if (desktop.openPanel === "summary") desktop.openPanel = ""; }
        }
    }
    Ui.RetroDrawer {
        objectName: "clipboardDrawer"
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.height + 20
        width: Math.min(clipboard.implicitWidth, desktop.width - 24)
        height: Math.min(clipboard.implicitHeight, desktop.height - bar.height - 40)
        floating: true
        opened: desktop.openPanel === "clipboard"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        ClipboardHistory {
            id: clipboard
            anchors.fill: parent
            entries: desktop.state.clipboardEntries
            opened: desktop.openPanel === "clipboard"
            onCloseRequested: desktop.openPanel = ""
            onCopyRequested: entryId => { desktop.state.copyClipboard(entryId); desktop.openPanel = ""; }
            onPinRequested: (entryId, pinned) => desktop.state.pinClipboard(entryId, pinned)
            onRemoveRequested: entryId => desktop.state.removeClipboard(entryId)
            onClearRequested: desktop.state.clearClipboard()
        }
    }
    Ui.RetroDrawer {
        objectName: "windowOverviewDrawer"
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.height + 20
        width: Math.min(overview.implicitWidth, desktop.width - 24)
        height: Math.min(overview.implicitHeight, desktop.height - bar.height - 40)
        floating: true
        opened: desktop.openPanel === "windows"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        WindowOverview {
            id: overview
            anchors.fill: parent
            manager: desktop.state.windowManager
            applications: desktop.state.launcherApps
            preferences: desktop.state.profileSettings
            onCloseRequested: desktop.openPanel = ""
            onFocusRequested: windowId => {
                desktop.state.windowManager.focus(windowId);
                tiling.shown = true;
                tiling.maximizedIndex = -1;
                desktop.openPanel = "";
            }
            onWindowCloseRequested: windowId => desktop.state.windowManager.close(windowId)
            onMoveRequested: (windowId, monitor, workspace) => desktop.state.windowManager.move(windowId, monitor, workspace)
            onPlaceRequested: (windowId, slot) => desktop.state.windowManager.place(windowId, slot)
            onFloatingRequested: (windowId, floating) => desktop.state.windowManager.setFloating(windowId, floating)
            onReserveRequested: (appId, monitor, workspace, slot) => desktop.state.windowManager.reserve(appId, monitor, workspace, slot)
            onRemoveRuleRequested: appId => desktop.state.windowManager.removeRule(appId)
        }
    }
    Ui.RetroDrawer {
        objectName: "launcherDrawer"
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.height + 32
        width: Math.min(launcher.implicitWidth, desktop.width - 24)
        height: Math.min(launcher.implicitHeight, desktop.height - bar.height - 48)
        floating: true
        opened: desktop.openPanel === "launcher"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        Launcher {
            id: launcher
            anchors.fill: parent
            applications: desktop.state.launcherApps
            opened: desktop.openPanel === "launcher"
            onCloseRequested: desktop.openPanel = ""
            onLaunchRequested: appId => {
                desktop.state.launchApp(appId);
                desktop.openPanel = "";
            }
        }
    }
    Ui.RetroDrawer {
        objectName: "calendarDrawer"
        anchors.top: bar.bottom
        anchors.left: parent.left
        anchors.margins: Ui.Theme.floatingPanels ? 12 : 0
        width: Math.min(calendar.implicitWidth, desktop.width - 24)
        height: Math.min(calendar.implicitHeight, desktop.height - bar.height - 24)
        edge: "left"
        opened: desktop.openPanel === "calendar"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        CalendarPanel {
            id: calendar
            objectName: "calendarPanel"
            anchors.fill: parent
            today: desktop.state.calendarDate
            onCloseRequested: desktop.openPanel = ""
        }
    }
    Ui.RetroDrawer {
        id: gpuDrawer
        objectName: "gpuDrawer"
        anchors.top: bar.bottom
        anchors.right: parent.right
        anchors.margins: Ui.Theme.floatingPanels ? 12 : 0
        width: Math.min(440, desktop.width - 24)
        height: Math.min(590, desktop.height - bar.height - 24)
        edge: "right"
        opened: desktop.openPanel === "gpu"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        GpuPanel {
            objectName: "gpuPanelSurface"
            anchors.fill: parent
            gpu: desktop.state.gpus[desktop.selectedGpu]
            telemetryAvailable: desktop.state.telemetryAvailable
            reducedMotion: desktop.state.reducedMotion
            onCloseRequested: desktop.openPanel = ""
        }
    }
    Ui.RetroDrawer {
        objectName: "aiDrawer"
        anchors.top: bar.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: Ui.Theme.floatingPanels ? 16 : 0
        anchors.rightMargin: Ui.Theme.floatingPanels ? 16 : 0
        anchors.bottomMargin: Ui.Theme.floatingPanels ? 16 : 0
        width: aiPanel.implicitWidth
        edge: "right"
        opened: desktop.openPanel === "ai"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        LocalAIPanel {
            id: aiPanel
            objectName: "aiPanel"
            anchors.fill: parent
            service: desktop.state
            onStartRequested: modelIndex => desktop.state.changeModel(modelIndex)
            onStopRequested: desktop.state.changeModel(-1)
            onSwitchRequested: modelIndex => desktop.state.changeModel(modelIndex)
            onCloseRequested: desktop.openPanel = ""
        }
    }
    Ui.RetroDrawer {
        objectName: "wallpaperDrawer"
        edge: "right"
        anchors.top: bar.bottom
        anchors.right: parent.right
        anchors.topMargin: Ui.Theme.floatingPanels ? 16 : 0
        anchors.rightMargin: Ui.Theme.floatingPanels ? 16 : 0
        width: Math.min(wallpaperPanel.implicitWidth, desktop.width - 24)
        height: Math.min(wallpaperPanel.implicitHeight, desktop.height - bar.height - 32)
        opened: desktop.openPanel === "wallpaper"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        WallpaperPicker {
            id: wallpaperPanel
            objectName: "wallpaperPanelSurface"
            anchors.fill: parent
            wallpapers: desktop.state.wallpapers
            selected: desktop.state.wallpaper
            profileSettings: desktop.state.profileSettings
            folderLoading: desktop.state.wallpaperFolderLoading
            onSelectedRequested: index => desktop.state.setWallpaper(index)
            onCloseRequested: desktop.openPanel = ""
        }
    }
    Ui.RetroDrawer {
        objectName: "controlDrawer"
        anchors.top: bar.bottom
        anchors.left: parent.left
        anchors.margins: Ui.Theme.floatingPanels ? 12 : 0
        edge: "left"
        width: Math.min(controls.implicitWidth, desktop.width - 24)
        height: Math.min(controls.implicitHeight, desktop.height - bar.height - 24)
        opened: desktop.openPanel === "controls"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        ControlCenter {
            id: controls
            anchors.fill: parent
            service: desktop.state
            shortcuts: shortcuts
            opened: desktop.openPanel === "controls"
            onCloseRequested: desktop.openPanel = ""
            onVolumeRequested: value => desktop.state.volume = value
            onOutputMuteRequested: muted => desktop.state.outputMuted = muted
            onAppVolumeRequested: (appId, value) => desktop.state.setAppVolume(appId, value)
            onAppMuteRequested: (appId, muted) => desktop.state.setAppMuted(appId, muted)
            onWallpaperSelected: index => desktop.state.setWallpaper(index)
            onToggleRequested: (setting, value) => desktop.state[setting] = value
            onProfileRequested: name => profileSwitch.confirm(name)
            onWallpaperRequested: desktop.openPanel = "wallpaper"
            onAiRequested: desktop.openPanel = "ai"
            onAudioRequested: desktop.openPanel = "volume"
            onGpuRequested: index => { desktop.selectedGpu = index; desktop.openPanel = "gpu"; }
            onSettingsRequested: settingsWindow.open()
            onSeekRequested: position => desktop.state.trackPosition = position
            onWorkspaceRequested: number => desktop.state.workspace = number
            onPlaybackRequested: desktop.state.playing = !desktop.state.playing
            onPreviousRequested: desktop.state.skipTrack(-1)
            onNextRequested: desktop.state.skipTrack(1)
        }
    }
    Ui.RetroDrawer {
        objectName: "powerDrawer"
        anchors.top: bar.bottom
        anchors.left: parent.left
        anchors.margins: Ui.Theme.floatingPanels ? 12 : 0
        width: powerPanel.implicitWidth
        height: powerPanel.implicitHeight
        edge: "left"
        opened: desktop.openPanel === "power"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        PowerMenu {
            id: powerPanel
            objectName: "powerPanelSurface"
            anchors.fill: parent
            lastAction: desktop.state.lastPowerAction
            onActionRequested: action => {
                desktop.state.lastPowerAction = action;
                if (action === "Lock") { desktop.openPanel = ""; desktop.lockPreviewRequested(); }
            }
            onCloseRequested: desktop.openPanel = ""
        }
    }
    Ui.RetroDrawer {
        objectName: "volumeDrawer"
        anchors.top: bar.bottom
        anchors.right: parent.right
        anchors.margins: Ui.Theme.floatingPanels ? 12 : 0
        opened: desktop.openPanel === "volume"
        edge: "right"
        reducedMotion: desktop.state.reducedMotion
        onDismissRequested: desktop.openPanel = ""
        width: Math.min(volumeMixer.implicitWidth, desktop.width - 24)
        height: Math.min(volumeMixer.implicitHeight, desktop.height - bar.height - 24)
        VolumeMixer {
            id: volumeMixer
            objectName: "volumePanelSurface"
            anchors.fill: parent
            previewState: desktop.state.desktopData.live ? null : desktop.state
            volume: desktop.state.volume
            outputMuted: desktop.state.outputMuted
            applications: desktop.state.audioApps
            onVolumeRequested: value => desktop.state.volume = value
            onOutputMuteRequested: muted => desktop.state.outputMuted = muted
            onAppVolumeRequested: (appId, value) => desktop.state.setAppVolume(appId, value)
            onAppMuteRequested: (appId, muted) => desktop.state.setAppMuted(appId, muted)
            onCloseRequested: desktop.openPanel = ""
        }
    }
}