import QtQuick
import Qt.labs.folderlistmodel
import "../shell/Services"

QtObject {
    id: fixtures
    property bool initialized: false
    property DesktopData desktopData: DesktopData {}
    property alias workspace: windows.activeWorkspace
    property WindowState windowManager: WindowState {
        id: windows
        applications: fixtures.launcherApps
        onRulesEdited: profiles.setCategory("tiling", Object.assign({}, profiles.currentProfile.tiling, {rules: windows.rules}))
    }
    property CaptureState captures: CaptureState {}
    property ActivityState activities: ActivityState { service: fixtures; objectName: "activities" }
    function copyCapture(captureId) {
        const capture = captures.entries.find(entry => entry.captureId === captureId);
        if (!capture || captures.busy) return;
        const entryId = clipboardEntries.reduce((maximum, entry) => Math.max(maximum, entry.entryId), -1) + 1;
        clipboardEntries = [{entryId: entryId, kind: "image", text: capture.name, image: capture.source, frame: capture.frame, pinned: false}].concat(clipboardEntries);
        copiedClipboardId = entryId;
        notify("Preview clipboard", "Screenshot copied");
    }
    readonly property var workspaces: [1, 2, 4, 7]
    property ProfileSettings profileSettings: ProfileSettings { id: profiles }
    property alias profile: profiles.activeName
    property Connections profileChanges: Connections {
        target: profiles
        function onCurrentProfileChanged() {
            if (profiles.ready && profiles.currentProfile.tiling) windows.rules = profiles.clone(profiles.currentProfile.tiling.rules).filter(rule => windows.validRule(rule));
        }
    }
    Component.onCompleted: Qt.callLater(function() {
        if (profiles.legacyRulesPending && windows.rules.length && profiles.profiles.every(entry => !entry.tiling.rules.length)) {
            profiles.setCategory("tiling", Object.assign({}, profiles.currentProfile.tiling, {rules: windows.rules}));
            profiles.save();
        }
        windows.rules = profiles.clone(profiles.currentProfile.tiling.rules).filter(rule => windows.validRule(rule));
        profiles.legacyRulesPending = false;
        initialized = true;
    })
    property bool playing: true
    property int volume: 64
    property bool outputMuted: false
    readonly property var audioOutputs: ["Default", "Speakers", "Headphones"]
    readonly property var audioInputs: ["Default", "Headset microphone"]
    property string inputDevice: "Default"
    property int inputVolume: 60
    property ListModel audioApps: ListModel {
        objectName: "audioApps"
        ListElement { appId: "music"; appName: "Music"; streamName: "Still Life"; level: 80; muted: false }
        ListElement { appId: "browser"; appName: "Firefox"; streamName: "Video playback"; level: 45; muted: false }
        ListElement { appId: "chat"; appName: "Discord"; streamName: "Voice chat"; level: 70; muted: false }
    }
    function setAppVolume(appId, value) {
        if (!Number.isFinite(value)) return;
        for (let index = 0; index < audioApps.count; index++) {
            if (audioApps.get(index).appId === appId) {
                audioApps.setProperty(index, "level", Math.round(Math.max(0, Math.min(100, value))));
                return;
            }
        }
    }
    function setAppMuted(appId, muted) {
        for (let index = 0; index < audioApps.count; index++) {
            if (audioApps.get(index).appId === appId) {
                audioApps.setProperty(index, "muted", Boolean(muted));
                return;
            }
        }
    }
    readonly property int wallpaper: {
        const file = profileSettings.currentProfile.wallpaperFile;
        const index = file ? wallpapers.findIndex(entry => String(entry.source) === file) : -1;
        return index >= 0 ? index : profileSettings.currentProfile.wallpaper;
    }
    readonly property var selectedWallpaper: wallpapers[wallpaper] || bundledWallpapers[profileSettings.currentProfile.wallpaper]
    function setWallpaper(index) {
        if (!Number.isInteger(index) || index < 0 || index >= wallpapers.length) return;
        const legacyWallpaper = index < 3;
        profileSettings.selectWallpaper(legacyWallpaper ? index : profileSettings.currentProfile.wallpaper,
                        legacyWallpaper ? "" : String(wallpapers[index].source));
        notify("Wallpaper changed", wallpapers[index].name);
    }
    property ListModel notifications: ListModel { objectName: "notifications" }
    readonly property var currentNotification: {
        if (notifications.count === 0) return null;
        const entry = notifications.get(notifications.count - 1);
        return {notificationId: entry.notificationId, title: entry.title, message: entry.message};
    }
    onCurrentNotificationChanged: {
        notificationExpiry.stop();
        if (currentNotification) notificationExpiry.start();
    }
    property Timer notificationExpiry: Timer {
        interval: 4000
        onTriggered: {
            if (fixtures.currentNotification)
                fixtures.dismissNotification(fixtures.currentNotification.notificationId);
        }
    }
    property int nextNotificationId: 0
    function notify(title, message, urgency) {
        desktopData.remember(title, message, "Preview");
        if ((dndEnabled || notificationMode === "Priority") && !(allowUrgent && urgency === "critical")) return;
        if (notifications.count >= 3) notifications.remove(0);
        notifications.append({notificationId: nextNotificationId++, title: title, message: message});
    }
    function dismissNotification(notificationId) {
        for (let index = 0; index < notifications.count; index++) {
            if (notifications.get(index).notificationId === notificationId) { notifications.remove(index); return; }
        }
    }
    property bool wifiEnabled: true
    property bool bluetoothEnabled: false
    property bool microphoneEnabled: true
    property bool dndEnabled: false
    property bool caffeineEnabled: false
    property bool nightLightEnabled: false
    property bool powerSaverEnabled: false
    property string notificationMode: "Normal"
    property bool allowUrgent: true
    property string outputDevice: "Default"
    property string waitingProfile: ""
    property string profileSwitchStatus: "Preview services only"
    property bool profileAiPending: false
    property int activeRequests: 1
    property int modelGpu: 0
    function applyProfile(name, requestPolicy) {
        const selected = profiles.profiles.find(entry => entry.name === name);
        if (!selected || aiBusy) { profileSwitchStatus = "AI transition in progress; retry when it finishes."; return false; }
        if (requestPolicy === "Wait" && runningRequests > 0 && selected.ai.action !== "Keep") {
            waitingProfile = name;
            profileSwitchStatus = "Waiting for active requests; profile unchanged.";
            return false;
        }
        waitingProfile = "";
        if (requestPolicy === "Cancel") activeRequests = 0;
        profile = name;
        notificationMode = selected.notifications.mode;
        dndEnabled = notificationMode === "DND";
        allowUrgent = selected.notifications.urgent;
        if (selected.audio.enabled) { volume = selected.audio.volume; outputDevice = selected.audio.device; }
        profileSwitchStatus = "Applied to preview. Existing windows unchanged.";
        if (requestPolicy === "Keep" || selected.ai.action === "Keep") return true;
        if (selected.ai.action === "Load") {
            const requiredGiB = selected.ai.model === 0 ? 22.7 : 6;
            if (requiredGiB > selected.ai.budget || requiredGiB + 2 > gpus[selected.ai.gpu].totalGiB) {
                profileSwitchStatus = "Partially applied: AI model exceeds the selected GPU or memory budget. AI unchanged.";
                return false;
            }
            modelGpu = selected.ai.gpu;
        }
        changeModel(selected.ai.action === "Load" ? selected.ai.model : -1);
        profileAiPending = aiBusy;
        profileSwitchStatus = aiBusy ? "Applying preview AI policy; waiting for completion." : "Applied to preview; AI already in requested state.";
        return true;
    }
    onRunningRequestsChanged: Qt.callLater(function() { if (runningRequests === 0 && waitingProfile) applyProfile(waitingProfile, "Wait"); })
    property bool reducedMotion: false
    property var clipboardEntries: initialClipboard()
    property int copiedClipboardId: -1
    function initialClipboard() {
        return [
            {entryId: 0, kind: "text", text: "quickshell -p preview/shell.qml", pinned: false},
            {entryId: 1, kind: "text", text: "Workspace notes / Work and Gaming", pinned: false},
            {entryId: 2, kind: "image", text: "Fold / image fixture", image: Qt.resolvedUrl("../shell/Assets/Wallpapers/fold.png"), pinned: false}
        ];
    }
    function copyClipboard(entryId) {
        if (!clipboardEntries.some(entry => entry.entryId === entryId)) return;
        copiedClipboardId = entryId;
        notify("Preview clipboard", "Entry copied in fixture state");
    }
    function pinClipboard(entryId, pinned) {
        clipboardEntries = clipboardEntries.map(entry => entry.entryId === entryId ? Object.assign({}, entry, {pinned: pinned}) : entry);
    }
    function removeClipboard(entryId) {
        clipboardEntries = clipboardEntries.filter(entry => entry.entryId !== entryId);
    }
    function clearClipboard() { clipboardEntries = clipboardEntries.filter(entry => entry.pinned); }
    readonly property var launcherApps: [
        {appId: "browser", name: "Firefox", category: "Internet", keywords: "browser web", icon: "search"},
        {appId: "editor", name: "Code", category: "Development", keywords: "editor programming", icon: "type"},
        {appId: "files", name: "Files", category: "Utilities", keywords: "folders documents", icon: "folder-open"},
        {appId: "terminal", name: "Terminal", category: "Development", keywords: "shell command", icon: "square"},
        {appId: "music", name: "Music", category: "Media", keywords: "audio player", icon: "play"},
        {appId: "system-summary", name: "System Summary", category: "Utilities", keywords: "hardware fastfetch system", icon: "cpu"},
        {appId: "chat", name: "Discord", category: "Communication", keywords: "chat voice", icon: "bot"}
    ]
    property string lastLaunchedApp: ""
    function launchApp(appId) {
        const app = launcherApps.find(entry => entry.appId === appId);
        if (!app) return;
        lastLaunchedApp = appId;
        windowManager.open(appId);
        notify("Preview launch", app.name);
    }
    property string lastPowerAction: ""
    property string scannedWallpaperDirectory: ""
    property var scannedWallpapers: []
    readonly property var directoryWallpapers: profiles.wallpaperDirectory && scannedWallpaperDirectory === profiles.wallpaperDirectory ? scannedWallpapers : []
    readonly property var wallpapers: bundledWallpapers.concat(directoryWallpapers)
    readonly property bool wallpaperFolderLoading: wallpaperFiles.status === FolderListModel.Loading
    property FolderListModel wallpaperFiles: FolderListModel {
        id: wallpaperFiles
        objectName: "wallpaperFiles"
        folder: profiles.wallpaperDirectory
        showDirs: false
        showHidden: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP", "*.BMP"]
        sortField: FolderListModel.Name
        onStatusChanged: fixtures.refreshWallpapers()
        onCountChanged: fixtures.refreshWallpapers()
        onFolderChanged: {
            fixtures.scannedWallpapers = [];
            fixtures.refreshWallpapers();
        }
    }
    function refreshWallpapers() {
        if (!profiles.wallpaperDirectory || String(wallpaperFiles.folder) !== profiles.wallpaperDirectory || wallpaperFiles.status !== FolderListModel.Ready) return;
        const images = [];
        for (let index = 0; index < wallpaperFiles.count; index++) {
            images.push({name: wallpaperFiles.get(index, "fileName"), source: wallpaperFiles.get(index, "fileUrl")});
        }
        scannedWallpapers = images;
        scannedWallpaperDirectory = profiles.wallpaperDirectory;
    }
    readonly property var bundledWallpapers: [
        {name: "01 - Fold", source: Qt.resolvedUrl("../shell/Assets/Wallpapers/fold.png")},
        {name: "02 - Orbit", source: Qt.resolvedUrl("../shell/Assets/Wallpapers/orbit.png")},
        {name: "03 - Steps", source: Qt.resolvedUrl("../shell/Assets/Wallpapers/steps.png")}
    ].concat([
        "Abstract Fold - Amber - original.jpg",
        "Abstract Fold - Teal - original.jpg",
        "Butter - Golden Shore - normal.jpg",
        "Butter - Golden Shore - superwide.jpg",
        "Butter - Golden Shore - wide.jpg",
        "Chalk - Moonlit Mountains - normal.jpg",
        "Chalk - Moonlit Mountains - superwide.jpg",
        "Chalk - Moonlit Mountains - wide.jpg",
        "Ice - Blue Layers - normal.jpg",
        "Ice - Blue Layers - superwide.jpg",
        "Ice - Blue Layers - wide.jpg",
        "Phosphor - Green Valley - normal.jpg",
        "Phosphor - Green Valley - superwide.jpg",
        "Phosphor - Green Valley - wide.jpg",
        "Rose - Rose Dunes - normal.jpg",
        "Rose - Rose Dunes - superwide.jpg",
        "Rose - Rose Dunes - wide.jpg",
        "Moonlit Mountains - original.jpg",
        "Pixel Planet - original.jpg"
    ].map(file => ({name: file.replace(/\.jpg$/, ""), source: Qt.resolvedUrl("../shell/Assets/Wallpapers/" + file)})))
    readonly property date calendarDate: new Date(2026, 8, 18, 10, 24)
    readonly property string clock: Qt.formatDateTime(calendarDate, "HH:mm")
    readonly property string date: Qt.formatDateTime(calendarDate, "ddd dd MMM").toUpperCase()
    property bool mediaAvailable: true
    property int trackIndex: 0
    property real trackPosition: 90
    readonly property int trackDuration: mediaAvailable ? 240 : 0
    readonly property var tracks: ["Still Life / Preview track", "Night Transit / Preview track", "Soft Signal / Preview track"]
    readonly property string track: tracks[trackIndex]
    property url trackArtwork: bundledWallpapers[trackIndex].source
    function skipTrack(direction) {
        if (!mediaAvailable) return;
        trackIndex = (trackIndex + direction + tracks.length) % tracks.length;
        trackPosition = 0;
    }
    readonly property string metrics: telemetryAvailable ? "CPU 08%   5090 " + gpus[0].utilization + "%   3080 " + gpus[1].utilization + "%" : "CPU 08%   GPUs N/A"
    readonly property var models: ["Preview / Model A", "Preview / Model B"]
    property int loadedModelIndex: 0
    property string aiStatus: "Running"
    readonly property bool aiBusy: aiStatus === "Starting" || aiStatus === "Stopping" || aiStatus === "Switching"
    property string aiError: ""
    property bool failNextStart: false
    property bool telemetryAvailable: true
    readonly property int runningRequests: aiStatus === "Running" ? activeRequests : 0
    readonly property real tokensPerSecond: aiStatus === "Running" ? 42.6 : -1
    readonly property var gpus: [
        {name: "RTX 5090", totalGiB: 32, usedGiB: 2.1 + (loadedModelIndex >= 0 && modelGpu === 0 ? (loadedModelIndex === 0 ? 22.7 : 6) : 0), utilization: aiStatus === "Running" && modelGpu === 0 ? 76 : 4},
        {name: "RTX 3080", totalGiB: 10, usedGiB: 1.8 + (loadedModelIndex >= 0 && modelGpu === 1 ? (loadedModelIndex === 0 ? 22.7 : 6) : 0), utilization: aiStatus === "Running" && modelGpu === 1 ? 76 : 3}
    ]
    property int nextModelIndex: -1
    property Timer aiTransition: Timer {
        interval: 350
        onTriggered: {
            if (nextModelIndex >= 0 && failNextStart) {
                loadedModelIndex = -1;
                aiStatus = "Error";
                aiError = "Preview launch failed. No model loaded.";
                failNextStart = false;
            } else {
                loadedModelIndex = nextModelIndex;
                aiStatus = loadedModelIndex >= 0 ? "Running" : "Stopped";
            }
            if (profileAiPending) {
                profileSwitchStatus = aiStatus === "Error" ? "Partially applied: " + aiError : "Applied to preview. VRAM change is simulated, not measured.";
                profileAiPending = false;
            }
        }
    }

    function changeModel(modelIndex) {
        if (aiBusy || modelIndex < -1 || modelIndex >= models.length) return;
        if (modelIndex === loadedModelIndex) return;
        nextModelIndex = modelIndex;
        aiError = "";
        aiStatus = modelIndex < 0 ? "Stopping" : loadedModelIndex < 0 ? "Starting" : "Switching";
        aiTransition.start();
    }

    function reset() {
        activities.reset();
        mediaAvailable = true;
        trackIndex = 0;
        trackPosition = 90;
        wifiEnabled = true;
        bluetoothEnabled = false;
        microphoneEnabled = true;
        dndEnabled = false;
        caffeineEnabled = false;
        nightLightEnabled = false;
        powerSaverEnabled = false;
        reducedMotion = false;
        lastPowerAction = "";
        lastLaunchedApp = "";
        clipboardEntries = initialClipboard();
        copiedClipboardId = -1;
        windowManager.reset();
        captures.reset();
        aiTransition.stop();
        loadedModelIndex = 0;
        nextModelIndex = -1;
        aiStatus = "Running";
        aiError = "";
        failNextStart = false;
        telemetryAvailable = true;
        workspace = 1;
        profile = "Work";
        playing = true;
        volume = 64;
        outputMuted = false;
        outputDevice = "Default";
        inputDevice = "Default";
        inputVolume = 60;
        audioApps.clear();
        audioApps.append({appId: "music", appName: "Music", streamName: "Still Life", level: 80, muted: false});
        audioApps.append({appId: "browser", appName: "Firefox", streamName: "Video playback", level: 45, muted: false});
        audioApps.append({appId: "chat", appName: "Discord", streamName: "Voice chat", level: 70, muted: false});
        setWallpaper(0);
        notifications.clear();
    }
}