import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import "../../shell/Services" as Services
import "../../shell/Components" as Ui
import "../../preview" as Preview
import "DesktopSettings.js" as DesktopSettings
import "WindowActions.js" as WindowActions

Scope {
    id: root

    readonly property bool production: true
    property bool homeOpen: false
    property string homeScreen: ""
    property string homePage: "Home"
    signal homeRequested(string page)
    property bool launcherOpen: false
    property string launcherScreen: ""
    property string sidePage: ""
    property string sideScreen: ""
    property var clipboardEntries: []
    property string clipboardStatus: "Starting clipboard history"
    readonly property bool clipboardWatching: clipboardWatcher.running
    function clipboardAction(action, identifier) {
        if (clipboardProcess.running) return;
        const command = ["python3", Quickshell.shellPath("host/clipboard.py"), action];
        if (identifier !== undefined) command.push(String(identifier));
        clipboardProcess.action = action;
        clipboardProcess.command = command;
        clipboardProcess.running = true;
    }
    Process {
        id: clipboardWatcher
        command: ["wl-paste", "--watch", "python3", Quickshell.shellPath("host/clipboard.py"), "store"]
        running: Quickshell.env("QUICKSHELL_CLIPBOARD_HISTORY") !== "0"
        onExited: root.clipboardStatus = "Clipboard watcher stopped"
    }
    Process {
        id: clipboardProcess
        property string action: "list"
        stdout: StdioCollector { id: clipboardOutput }
        onExited: (exitCode, exitStatus) => {
            let result = {};
            try { result = JSON.parse(clipboardOutput.text); } catch (_error) {}
            if (exitCode === 0 && exitStatus === 0 && result.success) {
                root.clipboardEntries = result.entries;
                root.clipboardStatus = root.clipboardWatching ? "" : "History recording is off";
                if (action === "copy") root.sidePage = "";
            } else {
                root.clipboardStatus = result.error || "Clipboard provider unavailable";
                if (action !== "list") root.notify("Clipboard", root.clipboardStatus);
            }
        }
    }
    Timer {
        interval: 1000
        running: root.sidePage === "Clipboard"
        repeat: true
        triggeredOnStart: true
        onTriggered: root.clipboardAction("list")
    }
    property string selectedGpuId: ""
    readonly property var selectedGpu: gpus.find(entry => entry.id === selectedGpuId) || {name: "GPU unavailable", utilization: NaN, usedGiB: NaN, totalGiB: NaN}
    readonly property var availablePages: ["Home", "Audio", "Displays", "Network", "System", "Power", "Weather", "Notifications", "Calendar", "Settings", "Wallpaper", "Session"]
    property alias preferences: storage
    Settings {
        id: storage
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-host/settings.ini"
        property bool floatingLeftBar: true
        property bool floatingMiddleBar: false
        property bool floatingRightBar: true
        property int barRadius: 8
        property int panelRadius: 8
        property bool reducedMotion: false
        property bool dndEnabled: false
        property bool controlsEnabled: true
        property bool notificationsEnabled: true
        property string wallpaperDirectory: ""
        property string wallpaperSource: ""
        property string aiProfileDefaultsJson: "{}"
    }
    Binding { target: Ui.Theme; property: "palette"; value: root.profileSettings.palette }
    Binding { target: Ui.Theme; property: "glassEnabled"; value: root.profileSettings.glassEnabled }
    Binding { target: Ui.Theme; property: "floatingPanels"; value: root.profileSettings.floatingPanels }
    Binding { target: Ui.Theme; property: "barRadius"; value: root.profileSettings.barRadius }
    Binding { target: Ui.Theme; property: "panelRadius"; value: root.profileSettings.panelRadius }
    Binding { target: Ui.Theme; property: "windowRadius"; value: root.profileSettings.windowRadius }
    Binding { target: Ui.Theme; property: "panelOpacity"; value: root.profileSettings.panelOpacity }
    Binding { target: Ui.Theme; property: "windowOpacity"; value: root.profileSettings.windowOpacity }
    Binding { target: Ui.Theme; property: "animationStyle"; value: root.reducedMotion ? "Off" : root.profileSettings.animationStyle }
    Binding { target: Ui.Theme; property: "animationDuration"; value: root.reducedMotion ? 0 : root.profileSettings.animationDuration }
    readonly property var desktopData: Services.DesktopData {}
    Services.LiveDesktop {
        data: root.desktopData
        enabled: true
        allowChanges: storage.controlsEnabled && Quickshell.env("QUICKSHELL_HOST_CONTROLS") !== "0"
        allowDisplayChanges: true
        notificationsEnabled: storage.notificationsEnabled && Quickshell.env("QUICKSHELL_NOTIFICATIONS") !== "0"
    }

    readonly property var shortcuts: ShortcutSettings {}
    readonly property string profile: profileSettings.activeName
    readonly property bool desktopControlsEnabled: Hyprland.usingLua && desktopData.controlsEnabled
    property var desktopSettingsObserved: null
    property var desktopSettingsQueue: ({})
    function syncFocusBorder() {
        if (!desktopControlsEnabled || !profileSettings.ready || profileSettings.applying) return;
        const command = DesktopSettings.command("focusBorderColor", Ui.Theme.palette.accent);
        if (!command) return;
        desktopSettingsQueue = Object.assign({}, desktopSettingsQueue, {focusBorderColor: command});
        desktopSettingsTimer.restart();
    }
    onDesktopControlsEnabledChanged: if (desktopControlsEnabled) syncFocusBorder()
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.syncFocusBorder();
        }
    }
    function syncDesktopSettings() {
        if (!profileSettings.ready || profileSettings.applying) return;
        const keys = profileSettings.tilingKeys.concat(["windowOpacity", "windowRadius", "focusBorderColor"]);
        const current = profileSettings.snapshot(keys);
        current.focusBorderColor = Ui.Theme.palette.accent;
        if (!profileSettings.glassEnabled) current.windowOpacity = 100;
        if (desktopControlsEnabled) {
            const pending = Object.assign({}, desktopSettingsQueue);
            for (const key of keys) {
                if (desktopSettingsObserved ? current[key] !== desktopSettingsObserved[key] : ["windowOpacity", "windowRadius", "focusBorderColor"].includes(key)) {
                    const command = DesktopSettings.command(key, current[key]);
                    if (command) pending[key] = command;
                }
            }
            desktopSettingsQueue = pending;
            desktopSettingsTimer.restart();
        }
        desktopSettingsObserved = current;
    }
    Component.onCompleted: {
        syncDesktopSettings();
        terminalPaletteTimer.restart();
    }
    property string terminalPaletteApplied: ""
    Connections {
        target: Ui.Theme
        function onPaletteChanged() { terminalPaletteTimer.restart(); root.syncDesktopSettings(); }
    }
    Timer {
        id: terminalPaletteTimer
        interval: 150
        onTriggered: {
            if (!root.desktopData.controlsEnabled || !root.profileSettings.ready || terminalPaletteProcess.running) return;
            const colors = JSON.stringify(Ui.Theme.palette);
            if (colors === root.terminalPaletteApplied) return;
            terminalPaletteProcess.command = ["/usr/bin/python3", Quickshell.shellPath("tools/sentinel.py"), "sync-palette", colors];
            terminalPaletteProcess.running = true;
        }
    }
    Process {
        id: terminalPaletteProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.terminalPaletteApplied = command[command.length - 1];
            else console.warn("Sentinel palette export failed:", exitCode);
            if (command[command.length - 1] !== JSON.stringify(Ui.Theme.palette)) terminalPaletteTimer.restart();
        }
    }
    Timer {
        id: desktopSettingsTimer
        interval: 100
        onTriggered: {
            if (desktopSettingsProcess.running || !root.desktopControlsEnabled) return;
            const commands = Object.values(root.desktopSettingsQueue);
            if (!commands.length) return;
            root.desktopSettingsQueue = ({});
            desktopSettingsProcess.command = ["hyprctl", "repl", commands.join("; ")];
            desktopSettingsProcess.running = true;
        }
    }
    Process {
        id: desktopSettingsProcess
        stdout: StdioCollector { id: desktopSettingsOutput }
        stderr: StdioCollector { id: desktopSettingsErrors }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0 || /error|invalid|failed/i.test(desktopSettingsOutput.text + desktopSettingsErrors.text))
                root.notify("Desktop settings", "Hyprland rejected the change: " + (desktopSettingsErrors.text || desktopSettingsOutput.text));
            if (Object.keys(root.desktopSettingsQueue).length) desktopSettingsTimer.restart();
        }
    }
    readonly property var profileSettings: Preview.ProfileSettings {
        settingsLocation: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-host/profiles.ini"
    }
    readonly property bool wallpaperColorsAvailable: true
    readonly property string paletteWallpaperSource: profileSettings.paletteWallpaperSource(wallpaperSource)
    property string paletteRequest: ""
    property var paletteCache: ({})
    property string wallpaperColorStatus: "Saved palette"
    function refreshWallpaperPalette() {
        if (profileSettings.currentProfile.source !== "Wallpaper") { wallpaperColorStatus = "Saved palette"; return; }
        if (paletteCache[paletteWallpaperSource]) {
            profileSettings.sampledPalette = paletteCache[paletteWallpaperSource];
            wallpaperColorStatus = "Wallpaper colors ready";
            return;
        }
        profileSettings.sampledPalette = null;
        wallpaperColorStatus = "Generating wallpaper colors...";
        if (paletteProcess.running) return;
        paletteRequest = paletteWallpaperSource;
        paletteProcess.command = [Quickshell.shellPath(".venv/bin/python"), Quickshell.shellPath("tools/wallpaper_palette.py"), paletteRequest];
        paletteProcess.running = true;
    }
    Connections {
        target: root.profileSettings
        function onCurrentProfileChanged() { root.refreshWallpaperPalette(); root.syncDesktopSettings(); }
        function onReadyChanged() { root.syncDesktopSettings(); }
        function onApplyingChanged() { if (!root.profileSettings.applying) root.syncDesktopSettings(); }
    }
    onPaletteWallpaperSourceChanged: refreshWallpaperPalette()
    Process {
        id: paletteProcess
        stdout: StdioCollector { id: paletteOutput }
        onRunningChanged: if (running) paletteTimeout.restart()
        onExited: (exitCode, exitStatus) => {
            paletteTimeout.stop();
            let colors = null;
            try { colors = JSON.parse(paletteOutput.text).palette; } catch (_error) {}
            const valid = exitCode === 0 && exitStatus === 0 && colors &&
                ["paper", "ink", "muted", "line", "hover", "stage", "accent"].every(key => /^#[0-9a-f]{6}$/i.test(colors[key] || ""));
            if (valid) root.paletteCache = Object.assign({}, root.paletteCache, {[root.paletteRequest]: colors});
            if (root.paletteRequest === root.paletteWallpaperSource && root.profileSettings.currentProfile.source === "Wallpaper") {
                root.profileSettings.sampledPalette = valid ? colors : null;
                root.wallpaperColorStatus = valid ? "Wallpaper colors ready" : "Wallpaper colors unavailable";
                if (!valid) root.notify("Wallpaper colors", "Palette extraction unavailable; keeping saved colors");
            }
            if (root.paletteRequest !== root.paletteWallpaperSource) Qt.callLater(root.refreshWallpaperPalette);
        }
    }
    Timer { id: paletteTimeout; interval: 10000; onTriggered: paletteProcess.running = false }
    function applyProfile(name) {
        if (!desktopData.controlsEnabled) return;
        if (profileSettings.profiles.some(entry => entry.name === name)) profileSettings.activeName = name;
    }
    property var bundledWallpapers: []
    property var directoryWallpapers: []
    readonly property var wallpapers: bundledWallpapers.concat(directoryWallpapers)
    readonly property string wallpaperSource: profileSettings.currentProfile.wallpaperFile || storage.wallpaperSource || Quickshell.env("QUICKSHELL_WALLPAPER") || Qt.resolvedUrl("../../shell/Assets/Wallpapers/fold.png").toString()
    readonly property int wallpaper: wallpapers.findIndex(entry => entry.source === wallpaperSource)
    readonly property var selectedWallpaper: wallpapers[wallpaper] || {name: "Desktop", source: wallpaperSource}
    readonly property var wallpaperMonitors: Quickshell.screens.map(screen => screen.name)
    function wallpaperSourceForMonitor(monitor) {
        return profileSettings.wallpaperForMonitor(monitor, wallpaperSource);
    }
    function wallpaperIndexForMonitor(monitor) {
        const source = wallpaperSourceForMonitor(monitor);
        return wallpapers.findIndex(entry => entry.source === source);
    }
    readonly property bool wallpaperFolderLoading: localImages.status === FolderListModel.Loading
    property alias reducedMotion: storage.reducedMotion
    function readWallpapers(model) {
        const result = [];
        for (let index = 0; index < model.count; index++)
            result.push({name: model.get(index, "fileName"), source: String(model.get(index, "fileUrl"))});
        return result;
    }
    function setWallpaper(index, monitor) {
        if (!Number.isInteger(index) || index < 0 || index >= wallpapers.length) return;
        if (monitor) {
            if (wallpaperMonitors.includes(monitor)) profileSettings.selectMonitorWallpaper(monitor, wallpapers[index].source);
        } else {
            profileSettings.selectWallpaper(0, wallpapers[index].source);
        }
    }
    FolderListModel {
        id: bundledImages
        folder: Qt.resolvedUrl("../../shell/Assets/Wallpapers")
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        onCountChanged: root.bundledWallpapers = root.readWallpapers(bundledImages)
        onStatusChanged: if (status === FolderListModel.Ready) root.bundledWallpapers = root.readWallpapers(bundledImages)
    }
    FolderListModel {
        id: localImages
        folder: root.profileSettings.wallpaperDirectory || bundledImages.folder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        onCountChanged: root.directoryWallpapers = root.profileSettings.wallpaperDirectory ? root.readWallpapers(localImages) : []
        onStatusChanged: if (status === FolderListModel.Ready) root.directoryWallpapers = root.profileSettings.wallpaperDirectory ? root.readWallpapers(localImages) : []
    }
    readonly property var calendarDate: systemClock.date
    readonly property string date: Qt.formatDateTime(systemClock.date, "ddd, MMM d")
    readonly property string clock: Qt.formatDateTime(systemClock.date, "HH:mm")
    SystemClock { id: systemClock; precision: SystemClock.Seconds }

    property var currentNotification: null
    function notify(title, message) {
        currentNotification = {notificationId: Date.now(), title: title, message: message};
        noticeTimer.restart();
    }
    function dismissNotification(notificationId) {
        if (currentNotification && currentNotification.notificationId === notificationId)
            currentNotification = null;
    }
    Timer { id: noticeTimer; interval: 5000; onTriggered: root.currentNotification = null }
    Connections {
        target: root.desktopData
        function onNotificationsChanged() {
            const latest = root.desktopData.notifications[0];
            if (latest && !root.dndEnabled) root.notify(latest.title, latest.body);
        }
    }

    readonly property var player: Mpris.players.values.find(entry => entry.isPlaying) || Mpris.players.values[0] || null
    readonly property bool mediaAvailable: player !== null
    readonly property bool playing: player ? player.isPlaying : false
    readonly property string track: player ? (player.trackTitle || player.identity) : "No media"
    readonly property string trackArtwork: player ? player.trackArtUrl : ""
    readonly property real trackPosition: player && player.positionSupported ? Math.max(0, player.position) : 0
    readonly property real trackDuration: player && player.lengthSupported ? Math.max(0, player.length) : 0
    function playbackRequested() { if (player && player.canTogglePlaying) player.togglePlaying(); }
    function previousRequested() { if (player && player.canGoPrevious) player.previous(); }
    function nextRequested() { if (player && player.canGoNext) player.next(); }
    function seekRequested(position) {
        if (player && player.canSeek && Number.isFinite(position))
            player.position = Math.max(0, Math.min(trackDuration, position));
    }

    readonly property var activities: QtObject {
        readonly property var entries: root.playing ? [{key: "music", label: "Music"}] : []
        readonly property string selectedId: entries.length ? "music" : ""
        readonly property var selected: entries.length ? entries[0] : null
        readonly property string nextLabel: ""
        readonly property bool recordingActive: false
        readonly property bool sharing: false
        readonly property int recordingSeconds: 0
        readonly property int timerSeconds: 0
        readonly property bool timerPaused: false
        readonly property bool aiActive: false
        readonly property string aiTask: ""
        readonly property real aiProgress: -1
        readonly property bool transferActive: false
        readonly property bool transferUpload: false
        readonly property bool transferPaused: false
        readonly property int transferSeconds: 0
        function time(seconds) { return Math.floor(seconds / 60) + ":" + String(Math.floor(seconds % 60)).padStart(2, "0"); }
    }

    property var minimizedOrder: []
    function performWindowAction(operation, window) {
        if (!desktopControlsEnabled || windowAction.running) return;
        const command = WindowActions.command(operation, window);
        if (!command) { notify("Window action", "Only unpinned windows on normal workspaces can be minimized"); return; }
        windowAction.operation = operation;
        windowAction.address = window.address;
        windowAction.command = ["hyprctl", "repl", command];
        windowAction.running = true;
    }
    Process {
        id: windowAction
        property string operation
        property string address
        stdout: StdioCollector { id: windowActionOutput }
        stderr: StdioCollector { id: windowActionError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0 || /error|invalid|failed/i.test(windowActionOutput.text + windowActionError.text)) {
                root.notify("Window action", windowActionError.text || windowActionOutput.text || "Hyprland rejected the window action");
                return;
            }
            root.minimizedOrder = root.minimizedOrder.filter(address => address !== windowAction.address);
            if (operation === "minimize") root.minimizedOrder = root.minimizedOrder.concat([address]);
            else {
                const entry = root.windowManager.nativeWindows.find(entry => root.windowManager.addressOf(entry) === windowAction.address);
                if (entry && entry.wayland) entry.wayland.activate();
            }
        }
    }
    readonly property var windowManager: QtObject {
        readonly property bool controlsEnabled: root.desktopControlsEnabled
        readonly property bool busy: windowAction.running
        readonly property var nativeWindows: Hyprland.toplevels.values
        function addressOf(entry) { return entry.lastIpcObject.address || "0x" + entry.address.replace(/^0x/, ""); }
        readonly property var windows: nativeWindows.map((entry, index) => ({
            windowId: index, address: addressOf(entry), title: entry.title,
            appId: root.desktopEntryFor(entry.lastIpcObject.class)?.id || entry.lastIpcObject.class || "application",
            workspace: entry.workspace ? entry.workspace.id : 0,
            workspaceName: entry.workspace ? entry.workspace.name : "",
            minimized: !!WindowActions.restoreWorkspace(entry.workspace ? entry.workspace.name : ""),
            pinned: !!entry.lastIpcObject.pinned,
            monitor: entry.monitor ? entry.monitor.name : ""
        }))
        readonly property var workspaces: Hyprland.workspaces.values.filter(entry => entry.id > 0).map(entry => entry.id).sort((left, right) => left - right)
        readonly property var monitors: Hyprland.monitors.values.map(entry => entry.name)
        readonly property string defaultMonitor: monitors[0] || ""
        readonly property string activeMonitor: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        readonly property int observedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
        property int activeWorkspace: observedWorkspace
        readonly property int focusedId: nativeWindows.indexOf(Hyprland.activeToplevel)
        onObservedWorkspaceChanged: activeWorkspace = observedWorkspace
        onActiveWorkspaceChanged: {
            if (activeWorkspace > 0 && activeWorkspace !== observedWorkspace) {
                const workspace = Hyprland.workspaces.values.find(entry => entry.id === activeWorkspace);
                if (workspace) workspace.activate();
                activeWorkspace = observedWorkspace;
            }
        }
        function focus(windowId) {
            const window = windows.find(window => window.windowId === windowId);
            if (window && window.minimized) { root.performWindowAction("restore", window); return; }
            const entry = nativeWindows[windowId];
            if (entry && entry.wayland) entry.wayland.activate();
            else root.notify("Window focus", "Window activation is unavailable");
        }
        function close(windowId) {
            const entry = nativeWindows[windowId];
            if (entry && entry.wayland) entry.wayland.close();
            else root.notify("Close window", "Window is no longer available");
        }
        function minimize(windowId) {
            root.performWindowAction("minimize", windows.find(window => window.windowId === windowId));
        }
        function restoreLast() {
            const minimized = windows.filter(window => window.minimized);
            const recent = root.minimizedOrder.slice().reverse().map(address => minimized.find(window => window.address === address)).find(window => !!window);
            const window = recent || minimized[minimized.length - 1];
            if (window) root.performWindowAction("restore", window);
        }
        function orderedWindows(monitor, workspace) {
            return windows.filter(entry => entry.monitor === monitor && entry.workspace === workspace);
        }
    }
    function desktopEntryFor(appClass) {
        return appClass ? DesktopEntries.heuristicLookup(appClass) : null;
    }
    function applicationIcon(iconName) {
        return iconName ? Quickshell.iconPath(iconName, true) : "";
    }
    readonly property var launcherApplications: DesktopEntries.applications.values.map(entry => ({
        appId: entry.id, name: entry.name, icon: "panels-top-left",
        iconSource: root.applicationIcon(entry.icon),
        category: (entry.categories || []).join(" "), keywords: (entry.keywords || []).join(" ")
    }))
    readonly property var applications: launcherApplications.concat(
        [...new Set(windowManager.windows.map(entry => entry.appId))]
        .filter(appId => !launcherApplications.some(entry => entry.appId === appId))
        .map(appId => ({appId: appId, name: appId, icon: "panels-top-left", iconSource: root.applicationIcon(appId)})))

    readonly property var audioApps: []
    readonly property var defaultSink: desktopData.devices.sinks.find(entry => entry.name === (desktopData.devices.audio || {}).default_sink_name) || null
    readonly property int volume: defaultSink ? Math.round(Object.values(defaultSink.volume || {}).reduce((total, channel) => total + parseFloat(channel.value_percent || "0"), 0) / Math.max(1, Object.keys(defaultSink.volume || {}).length)) : 0
    readonly property bool outputMuted: defaultSink ? defaultSink.mute : false
    readonly property bool wifiEnabled: desktopData.devices.wifi
    readonly property bool bluetoothEnabled: Bluetooth.adapters.values.some(adapter => adapter.enabled)
    property bool caffeineEnabled: false
    readonly property bool caffeineSleepInhibitor: caffeineInhibitor.running
    onCaffeineEnabledChanged: {
        if (caffeineEnabled && !caffeineInhibitor.running) caffeineInhibitor.running = true;
        else if (!caffeineEnabled && caffeineInhibitor.running) caffeineInhibitor.write("release\n");
    }
    Process {
        id: caffeineInhibitor
        command: ["systemd-inhibit", "--no-ask-password", "--what=idle:sleep", "--mode=block",
            "--who=Quickshell Caffeine", "--why=Caffeine is enabled", "python3", "-c", "import sys; sys.stdin.readline()"]
        stdinEnabled: true
        stderr: StdioCollector { id: caffeineError }
        onExited: (exitCode, exitStatus) => {
            if (root.caffeineEnabled) {
                if (exitCode === 0 && exitStatus === 0) Qt.callLater(() => caffeineInhibitor.running = root.caffeineEnabled);
                else {
                    root.caffeineEnabled = false;
                    root.notify("Caffeine", caffeineError.text.trim() || "Could not inhibit system sleep");
                }
            }
        }
    }
    property bool nightLightRequested: false
    readonly property bool nightLightEnabled: nightLight.running
    Process {
        id: nightLight
        command: ["bash", "-c", "exec hyprsunset -t 4500"]
        running: root.nightLightRequested
        stderr: StdioCollector { id: nightLightErrors }
        onExited: (exitCode, exitStatus) => {
            if (!root.nightLightRequested) return;
            root.nightLightRequested = false;
            root.notify("Night light", exitCode === 127 ? "Install hyprsunset to enable night light." : nightLightErrors.text.trim() || "Night-light service stopped.");
        }
    }
    property alias dndEnabled: storage.dndEnabled
    readonly property bool powerSaverEnabled: desktopData.devices.powerProfile === "power-saver"
    readonly property bool telemetryAvailable: desktopData.fresh
    readonly property var gpus: desktopData.snapshot.gpus.map(entry => ({
        id: entry.id, name: entry.name, utilization: entry.utilization,
        temperature: Number.isFinite(entry.temperature) ? entry.temperature + " C" : null,
        powerDraw: Number.isFinite(entry.power) ? entry.power + " W" : null,
        memoryType: null, driver: entry.driver ?? null, pciAddress: entry.pciAddress ?? null,
        coreClock: Number.isFinite(entry.coreClock) ? entry.coreClock + " MHz" : null,
        fanSpeed: entry.fanSpeed ?? null, powerLimit: entry.powerLimit ?? null,
        usedGiB: Number.isFinite(entry.usedMiB) ? entry.usedMiB / 1024 : NaN,
        totalGiB: Number.isFinite(entry.totalMiB) ? entry.totalMiB / 1024 : NaN
    }))
    readonly property var aiProfileDefaults: {
        try { return JSON.parse(storage.aiProfileDefaultsJson); } catch (_error) { return {}; }
    }
    function setAiProfileDefault(modelIndex) {
        const defaults = Object.assign({}, aiProfileDefaults);
        const preset = modelManager.presets[modelIndex];
        if (preset) defaults[profile] = preset.id;
        else delete defaults[profile];
        storage.aiProfileDefaultsJson = JSON.stringify(defaults);
    }
    readonly property var modelManager: ModelManager {
        profileName: root.profile
        profileDefaults: root.aiProfileDefaults
    }
    readonly property bool aiManaged: true
    readonly property string aiStatus: modelManager.status
    readonly property var models: modelManager.models
    readonly property int loadedModelIndex: modelManager.loadedModelIndex
    readonly property string loadedModelName: modelManager.loadedModelName
    readonly property string runtimeLabel: modelManager.runtimeLabel
    readonly property bool aiBusy: modelManager.busy
    readonly property int runningRequests: modelManager.runningRequests
    readonly property string aiError: modelManager.error
    readonly property real tokensPerSecond: modelManager.tokensPerSecond

    function openHome(page, screenName) {
        if (!availablePages.includes(page)) {
            notify(page || "Home", "Not connected in the production host yet");
            return;
        }
        homePage = page;
        sidePage = "";
        launcherOpen = false;
        homeScreen = screenName || windowManager.activeMonitor;
        homeOpen = true;
        homeRequested(page);
    }
    function closeHome() { homeOpen = false; }
    property string sessionActionStatus: ""
    readonly property bool sessionActionBusy: sessionAction.running
    function requestSessionAction(action) {
        const commands = {
            "Lock": ["bash", Quickshell.shellPath("tools/lock.sh")],
            "Log out": ["loginctl", "terminate-session", Quickshell.env("XDG_SESSION_ID")],
            "Suspend": ["systemctl", "suspend"],
            "Restart": ["systemctl", "reboot"],
            "Shut down": ["systemctl", "poweroff"]
        };
        if (!Object.prototype.hasOwnProperty.call(commands, action) || sessionAction.running || !desktopData.controlsEnabled) return;
        if (action === "Log out" && !Quickshell.env("XDG_SESSION_ID")) {
            sessionActionStatus = "Current session ID is unavailable";
            return;
        }
        sessionActionStatus = action + " requested";
        if (action === "Lock") {
            closeHome();
            Quickshell.execDetached(commands[action]);
            return;
        }
        sessionAction.command = ["bash", "-c", 'exec "$@"', "--"].concat(commands[action]);
        sessionAction.running = true;
        closeHome();
    }
    Process {
        id: sessionAction
        stderr: StdioCollector { id: sessionError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0) root.sessionActionStatus = "Session request completed";
            else {
                root.sessionActionStatus = sessionError.text.trim() || "Session action failed; check service availability and permissions";
                root.notify("Session", root.sessionActionStatus);
            }
        }
    }
    function openSidePanel(page, screenName, gpuIndex) {
        if (!["GPU", "Audio", "Wallpaper", "AI", "Clipboard"].includes(page)) return;
        const screen = screenName || windowManager.activeMonitor;
        const gpuId = page === "GPU" && gpus[gpuIndex] ? gpus[gpuIndex].id : "";
        const closing = sidePage === page && sideScreen === screen && (page !== "GPU" || selectedGpuId === gpuId);
        homeOpen = false;
        launcherOpen = false;
        selectedGpuId = gpuId;
        sideScreen = screen;
        sidePage = closing ? "" : page;
    }
    function volumeRequested(value) {
        if (Number.isFinite(value)) desktopData.request(["pactl", "set-sink-volume", "@DEFAULT_SINK@", Math.round(Math.max(0, Math.min(100, value))) + "%"]);
    }
    function outputMuteRequested(muted) { desktopData.request(["pactl", "set-sink-mute", "@DEFAULT_SINK@", muted ? "1" : "0"]); }
    function toggleRequested(setting, value) {
        if (!desktopData.controlsEnabled) return;
        if (setting === "wifiEnabled") desktopData.request(["nmcli", "radio", "wifi", value ? "on" : "off"]);
        else if (setting === "powerSaverEnabled") desktopData.request(["powerprofilesctl", "set", value ? "power-saver" : "balanced"]);
        else if (setting === "dndEnabled") dndEnabled = value;
        else if (setting === "caffeineEnabled") caffeineEnabled = value;
        else if (setting === "nightLightEnabled") nightLightRequested = value;
        else if (setting === "bluetoothEnabled") {
            if (!Bluetooth.adapters.values.length) {
                notify("Bluetooth", "No adapter is available. Start bluetooth.service and check the adapter is connected.");
                return;
            }
            for (const adapter of Bluetooth.adapters.values) {
                if (value && adapter.state === BluetoothAdapterState.Blocked)
                    notify("Bluetooth", adapter.name + " is blocked. Check the hardware switch or rfkill.");
                else adapter.enabled = value;
            }
        }
    }
    function openLauncher() {
        homeOpen = false;
        sidePage = "";
        launcherScreen = windowManager.activeMonitor;
        launcherOpen = !launcherOpen;
    }
    function launchApplication(appId) {
        const entry = DesktopEntries.applications.values.find(candidate => candidate.id === appId);
        if (!entry) { notify("Applications", "Application is no longer available"); return; }
        entry.execute();
        launcherOpen = false;
    }
    function openWorkspaceOverview() {
        if (!overview.running) overview.running = true;
    }
    Process {
        id: overview
        command: ["bash", Quickshell.shellPath("tools/overview.sh"), "toggle"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) root.notify("Workspace overview", "Start tools/overview.sh start in your Hyprland session first");
        }
    }
    function captureRequested() {
        if (Quickshell.env("QUICKSHELL_ENABLE_HOST_CAPTURE") === "0") {
            notify("HyprQuickshot", "Host capture is disabled");
            return;
        }
        if (!capture.running) capture.running = true;
    }
    Process {
        id: capture
        command: ["quickshell", "-c", "hyprquickshot", "-n"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) root.notify("HyprQuickshot", "Launch failed; check installation");
        }
    }
}