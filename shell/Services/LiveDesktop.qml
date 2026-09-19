import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import "DisplaySettings.js" as DisplaySettings

Scope {
    id: backend
    required property var data
    property bool enabled: false
    property bool allowChanges: false
    property bool allowDisplayChanges: allowChanges
    property bool notificationsEnabled: false
    property var rollbackCommand: []
    property bool refreshPending: false
    function refreshDevices() {
        if (!enabled) return;
        if (devices.running) refreshPending = true;
        else devices.running = true;
    }
    Timer { id: audioRefresh; interval: 120; onTriggered: backend.refreshDevices() }
    Process {
        running: backend.enabled
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: line => {
                if (/ on (sink|source|sink-input|source-output|server)\b/.test(line)) audioRefresh.restart();
            }
        }
    }
    readonly property string collector: Qt.resolvedUrl("linux-snapshot.sh").toString().replace(/^file:\/\//, "")
    Binding { target: data; property: "live"; value: backend.enabled }
    Binding { target: data; property: "controlsEnabled"; value: backend.enabled && backend.allowChanges }
    Binding { target: data; property: "displayControlsEnabled"; value: backend.enabled && backend.allowChanges && backend.allowDisplayChanges }
    Binding { target: data; property: "busy"; value: action.running || rollback.running }
    Binding { target: data; property: "publicAddressBusy"; value: publicAddress.running }
    Process {
        id: publicAddress
        command: ["curl", "--fail", "--silent", "--show-error", "--max-time", "8", "--max-filesize", "1024", "https://api.ipify.org?format=json"]
        stdout: StdioCollector { id: publicAddressOutput }
        onExited: (exitCode, exitStatus) => {
            let address = "";
            try {
                const result = JSON.parse(publicAddressOutput.text);
                if (exitCode === 0 && exitStatus === 0 && typeof result.ip === "string"
                    && /^(\d{1,3}\.){3}\d{1,3}$/.test(result.ip) && result.ip.split(".").every(part => Number(part) <= 255)) address = result.ip;
            } catch (error) {}
            backend.data.publicAddress = address;
            backend.data.publicAddressStatus = address ? "Checked " + new Date().toLocaleTimeString() : "Unavailable";
        }
    }
    Binding { target: data; property: "mediaPlayers"; value: backend.enabled ? Mpris.players.values : [] }
    Timer { interval: 2000; running: backend.enabled; triggeredOnStart: true; repeat: true; onTriggered: if (!telemetry.running) telemetry.running = true }
    Timer { interval: 10000; running: backend.enabled; triggeredOnStart: true; repeat: true; onTriggered: if (!devices.running) devices.running = true }
    Process {
        id: telemetry
        command: ["bash", backend.collector, "telemetry"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { backend.data.ingest(JSON.parse(text)); }
                catch (error) { backend.data.status = "Telemetry unavailable: check collector dependencies"; }
            }
        }
    }
    Process {
        id: devices
        command: ["bash", backend.collector, "devices"]
        onExited: {
            if (backend.refreshPending) {
                backend.refreshPending = false;
                audioRefresh.restart();
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try { backend.data.devices = JSON.parse(text); backend.data.status = backend.allowChanges ? "Live services" : "Live / read only"; }
                catch (error) { backend.data.status = "Device discovery unavailable"; }
            }
        }
    }
    Process {
        id: action
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionErrors }
        onExited: (exitCode, exitStatus) => {
            const failed = exitCode !== 0 || exitStatus !== 0 || (backend.data.displayPending && /error|invalid|failed/i.test(actionOutput.text + actionErrors.text));
            backend.data.status = failed ? "Action failed: check service availability and permissions" : "Applied";
            if (failed && backend.data.displayPending) backend.revertDisplay();
            backend.refreshDevices();
        }
    }
    Process {
        id: rollback
        stdout: StdioCollector { id: rollbackOutput }
        stderr: StdioCollector { id: rollbackErrors }
        onExited: (exitCode, exitStatus) => {
            const failed = exitCode !== 0 || exitStatus !== 0 || /error|invalid|failed/i.test(rollbackOutput.text + rollbackErrors.text);
            backend.data.status = failed ? "Display rollback failed; restore the mode in Hyprland" : "Display reverted";
            backend.data.displayPending = failed;
            if (!failed) backend.rollbackCommand = [];
            backend.refreshDevices();
        }
    }
    function applyDisplayChange(apply, revert) {
        if (!enabled || !allowChanges || !allowDisplayChanges || action.running || rollback.running || data.displayPending || !apply.length || !revert.length) return;
        rollbackCommand = revert;
        action.command = apply;
        action.running = true;
        data.displayPending = true;
        data.displayCountdown = 15;
        confirmation.start();
    }
    function revertDisplay() {
        confirmation.stop();
        if (rollback.running || !rollbackCommand.length) return;
        rollback.command = rollbackCommand;
        rollback.running = true;
    }
    Timer {
        id: confirmation
        interval: 1000
        repeat: true
        onTriggered: {
            backend.data.displayCountdown--;
            if (backend.data.displayCountdown <= 0) backend.revertDisplay();
        }
    }
    Connections {
        target: backend.data
        function onPublicAddressRequested() {
            if (!backend.enabled || publicAddress.running) return;
            backend.data.publicAddress = "";
            backend.data.publicAddressStatus = "Checking";
            publicAddress.running = true;
        }
        function onCommandRequested(command) {
            if (!backend.enabled || !backend.allowChanges || action.running || backend.data.displayPending) return;
            if (!["pactl", "nmcli", "nm-connection-editor", "powerprofilesctl"].includes(command[0])) return;
            action.command = command[0] === "nm-connection-editor" ? command : ["timeout", "20"].concat(command);
            action.running = true;
        }
        function onMediaRequested(index, operation) {
            const player = Mpris.players.values[index];
            if (!backend.enabled || !player) return;
            if (operation === "toggle" && player.canTogglePlaying) player.togglePlaying();
            if (operation === "next" && player.canGoNext) player.next();
            if (operation === "previous" && player.canGoPrevious) player.previous();
        }
        function onDisplayRequested(monitor, mode, scale, transform) {
            if (!backend.enabled || !backend.allowChanges || !backend.allowDisplayChanges || action.running || rollback.running || backend.data.displayPending) return;
            if (!monitor.availableModes.includes(mode) || scale < 0.5 || scale > 3 || transform < 0 || transform > 3) return;
            const apply = DisplaySettings.command(monitor, mode, scale, transform, Hyprland.usingLua);
            const revert = DisplaySettings.command(monitor, monitor.width + "x" + monitor.height + "@" + monitor.refreshRate, monitor.scale, monitor.transform, Hyprland.usingLua);
            backend.applyDisplayChange(apply, revert);
        }
        function onDisplayArrangementRequested(positions) {
            const monitors = backend.data.devices.monitors;
            const apply = DisplaySettings.arrangementCommand(monitors, positions, Hyprland.usingLua);
            if (!apply.length) return;
            const previous = positions.map(position => {
                const monitor = monitors.find(entry => entry.name === position.name);
                return {name:monitor.name,x:monitor.x,y:monitor.y};
            });
            backend.applyDisplayChange(apply, DisplaySettings.arrangementCommand(monitors, previous, Hyprland.usingLua));
        }
        function onDisplayConfirmed() {
            if (action.running || rollback.running) return;
            confirmation.stop(); backend.rollbackCommand = []; backend.data.displayPending = false;
        }
        function onDisplayReverted() { backend.revertDisplay(); }
    }
    Loader {
        active: backend.enabled && backend.notificationsEnabled
        sourceComponent: Component {
            NotificationServer {
                keepOnReload: true
                bodySupported: true
                onNotification: notification => backend.data.remember(notification.summary, notification.body, notification.appName)
                persistenceSupported: false
            }
        }
    }
}