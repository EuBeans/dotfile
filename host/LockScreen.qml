import QtQuick
import QtCore
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import "../preview" as Preview
import "../shell/Services" as Services
import "../shell/Components" as Ui

Scope {
    id: root
    property bool validationOnly: false
    property bool visualValidation: false
    property bool validationPassed: false
    property bool authenticated: false
    property string authenticationStatus: "Preparing authentication..."
    readonly property bool production: true
    readonly property string userName: Quickshell.env("USER")
    property string keyboardLayout: ""
    readonly property bool reducedMotion: preferences.reducedMotion
    readonly property var calendarDate: clockSource.date
    readonly property string clock: Qt.formatDateTime(clockSource.date, "HH:mm")
    SystemClock { id: clockSource; precision: SystemClock.Seconds }
    Settings {
        id: preferences
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-host/settings.ini"
        property bool reducedMotion: false
        property string wallpaperSource: ""
    }
    Preview.ProfileSettings {
        id: profile
        settingsLocation: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-host/profiles.ini"
    }
    Binding { target: Ui.Theme; property: "palette"; value: profile.palette }
    Binding { target: Ui.Theme; property: "animationStyle"; value: root.reducedMotion ? "Off" : profile.animationStyle }
    Binding { target: Ui.Theme; property: "animationDuration"; value: profile.animationDuration }
    // Match the primary monitor's live wallpaper palette, not just the static fallback palette name.
    readonly property string paletteWallpaperSource: profile.paletteWallpaperSource(wallpaperInput)
    property var paletteCache: ({})
    property string paletteRequest: ""
    function refreshWallpaperPalette() {
        if ((validationOnly && !visualValidation) || profile.currentProfile.source !== "Wallpaper" || !paletteWallpaperSource) return;
        if (paletteCache[paletteWallpaperSource]) { profile.sampledPalette = paletteCache[paletteWallpaperSource]; return; }
        profile.sampledPalette = null;
        if (paletteProcess.running) return;
        paletteRequest = paletteWallpaperSource;
        paletteProcess.command = [Quickshell.shellPath(".venv/bin/python"), Quickshell.shellPath("tools/wallpaper_palette.py"), paletteRequest];
        paletteProcess.running = true;
    }
    onPaletteWallpaperSourceChanged: refreshWallpaperPalette()
    Process {
        id: paletteProcess
        stdout: StdioCollector { id: paletteOutput }
        onExited: (exitCode, exitStatus) => {
            let colors = null;
            try { colors = JSON.parse(paletteOutput.text).palette; } catch (_error) {}
            const valid = exitCode === 0 && exitStatus === 0 && colors &&
                ["paper", "ink", "muted", "line", "hover", "stage", "accent"].every(key => /^#[0-9a-f]{6}$/i.test(colors[key] || ""));
            if (valid) root.paletteCache = Object.assign({}, root.paletteCache, {[root.paletteRequest]: colors});
            if (root.paletteRequest === root.paletteWallpaperSource && root.profile.currentProfile.source === "Wallpaper")
                root.profile.sampledPalette = valid ? colors : null;
            if (root.paletteRequest !== root.paletteWallpaperSource) Qt.callLater(root.refreshWallpaperPalette);
        }
    }
    property string folderWallpaper: ""
    readonly property string wallpaperInput: profile.currentProfile.wallpaperFile || preferences.wallpaperSource || folderWallpaper
    property string wallpaperRequest: ""
    property string renderedWallpaper: ""
    readonly property var selectedWallpaper: ({source:renderedWallpaper})
    onWallpaperInputChanged: prepareWallpaper()
    function prepareWallpaper() {
        if ((validationOnly && !visualValidation) || !wallpaperInput || wallpaperConversion.running) return;
        const source = wallpaperInput.startsWith("file://") ? decodeURIComponent(wallpaperInput.slice(7)) : wallpaperInput;
        if (!source.startsWith("/")) return;
        wallpaperRequest = wallpaperInput;
        wallpaperConversion.command = ["timeout", "8", "magick", source, "-auto-orient", "-resize", "5120x1440>", Quickshell.cachePath("lock-wallpaper.png")];
        wallpaperConversion.running = true;
    }
    Process {
        id: wallpaperConversion
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && exitStatus === 0) root.renderedWallpaper = "file://" + Quickshell.cachePath("lock-wallpaper.png");
            if (root.wallpaperRequest !== root.wallpaperInput) root.prepareWallpaper();
        }
    }
    FolderListModel {
        id: wallpapers
        folder: profile.wallpaperDirectory || Qt.resolvedUrl("../shell/Assets/Wallpapers")
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        onStatusChanged: {
            if (status === FolderListModel.Ready && count > 0)
                root.folderWallpaper = String(get(Math.min(count - 1, profile.currentProfile.wallpaper || 0), "fileUrl"));
        }
    }
    Services.DesktopData { id: desktop }
    Services.LiveDesktop { data: desktop; enabled: !root.validationOnly || root.visualValidation; allowChanges: false; notificationsEnabled: false }
    readonly property bool telemetryAvailable: desktop.fresh
    readonly property var lockSeries: [{name:"CPU",key:"cpu",value:(desktop.metrics.find(metric => metric.key === "cpu") || {}).value,detail:"Utilization"}].concat(
        desktop.snapshot.gpus.slice(0, 2).map(gpu => ({name:gpu.name.replace(/^NVIDIA\s+(?:GeForce\s+)?/, ""),key:gpu.id+"usage",value:gpu.utilization,
            detail:Number.isFinite(gpu.usedMiB) && Number.isFinite(gpu.totalMiB) ? (gpu.usedMiB/1024).toFixed(1)+" / "+(gpu.totalMiB/1024).toFixed(0)+" GiB" : "--"})))
    readonly property var lockHistory: lockSeries.map(series => {
        const values = (desktop.history[series.key] || []).slice(-48);
        return Array(48 - values.length).fill(null).concat(values);
    })
    readonly property var sink: desktop.devices.sinks.find(sink => desktop.devices.audio && sink.name === desktop.devices.audio.default_sink_name) || null
    readonly property int volume: sink && sink.volume ? Math.round(Object.values(sink.volume).reduce((total, channel) => total + channel.value, 0) / Math.max(1, Object.keys(sink.volume).length) / 65536 * 100) : -1
    readonly property var player: Mpris.players.values.find(player => player.isPlaying) || Mpris.players.values[0] || null
    readonly property bool mediaAvailable: player !== null
    readonly property bool playing: player ? player.isPlaying : false
    readonly property string track: player ? (player.trackTitle || player.identity) : "No media"
    readonly property string trackArtwork: player ? player.trackArtUrl : ""
    function playbackRequested() { if (player && player.canTogglePlaying) player.togglePlaying(); }
    Process {
        id: keyboard
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devices = JSON.parse(text).keyboards || [];
                    const main = devices.find(keyboard => keyboard.main) || devices[0];
                    root.keyboardLayout = main ? main.active_keymap || "" : "";
                } catch (error) { root.keyboardLayout = ""; }
            }
        }
    }
    Timer { interval: 3000; running: !root.validationOnly; repeat: true; triggeredOnStart: true; onTriggered: if (!keyboard.running) keyboard.running = true }
    QtObject {
        id: authBridge
        readonly property bool busy: !session.secure || !pam.active || !pam.responseRequired
        readonly property string status: root.authenticationStatus
        function submit(response) {
            if (busy || !session.secure || root.authenticated) return;
            root.authenticationStatus = "Checking...";
            pam.respond(response);
        }
    }
    function startAuthentication() {
        if (authenticated || (!validationOnly && !session.secure)) return;
        if (!pam.start()) {
            if (validationOnly) Qt.exit(1);
            else {
                authenticationStatus = "Authentication unavailable. Retrying...";
                retry.start();
            }
        }
    }
    PamContext {
        id: pam
        config: "hyprlock"
        configDirectory: "/etc/pam.d"
        user: root.userName
        onPamMessage: {
            if (root.validationOnly && responseRequired) {
                root.validationPassed = true;
                abort();
                if (!root.visualValidation) Qt.exit(0);
                return;
            }
            if (responseRequired && root.authenticationStatus === "Preparing authentication...") root.authenticationStatus = "";
            else if (responseRequired && root.authenticationStatus === "Checking...") root.authenticationStatus = message;
            if (messageIsError) root.authenticationStatus = "Authentication failed. Try again.";
        }
        onCompleted: result => {
            if (root.validationOnly) {
                if (!root.visualValidation || !root.validationPassed) Qt.exit(root.validationPassed || result === PamResult.Success ? 0 : 1);
                return;
            }
            if (result === PamResult.Success && session.secure) {
                root.authenticated = true;
                root.authenticationStatus = "Unlocked";
                session.locked = false;
                finish.start();
            } else {
                root.authenticationStatus = "Authentication failed. Try again.";
                retry.start();
            }
        }
        onError: {
            if (root.validationOnly) { Qt.exit(1); return; }
            root.authenticationStatus = "Authentication unavailable. Retrying...";
            retry.start();
        }
    }
    Timer { id: retry; interval: 1500; onTriggered: root.startAuthentication() }
    Timer { id: finish; interval: 100; onTriggered: Qt.quit() }
    Timer {
        interval: 8000
        running: root.validationOnly || !session.secure
        onTriggered: Qt.exit(2)
    }
    Component.onCompleted: {
        Quickshell.watchFiles = false;
        prepareWallpaper();
        refreshWallpaperPalette();
        if (validationOnly) startAuthentication();
    }
    Loader {
        active: root.validationOnly && root.visualValidation
        sourceComponent: Component {
            FloatingWindow {
                title: "Custom lock layout check (not locked)"
                implicitWidth: 1100
                implicitHeight: 900
                color: Ui.Theme.ink
                visible: true
                Preview.LockPreview {
                    id: validationView
                    anchors.fill: parent
                    service: root
                    authenticator: authBridge
                }
                Timer {
                    interval: 2500
                    running: true
                    onTriggered: validationView.grabToImage(result => {
                        const saved = result.saveToFile(Quickshell.shellPath(".artifacts/custom-lock-native.png"));
                        Qt.exit(saved && root.validationPassed ? 0 : 1);
                    })
                }
            }
        }
    }
    WlSessionLock {
        id: session
        locked: !root.validationOnly
        onSecureStateChanged: if (secure) root.startAuthentication()
        WlSessionLockSurface {
            Rectangle { anchors.fill: parent; color: Ui.Theme.ink }
            Preview.LockPreview {
                anchors.fill: parent
                service: root
                authenticator: authBridge
            }
        }
    }
}