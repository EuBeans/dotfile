import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications

Scope {
    id: backend
    required property var data
    property bool enabled: false
    property bool allowChanges: false
    property bool notificationsEnabled: false
    property string rollbackRule: ""
    readonly property string collector: Qt.resolvedUrl("linux-snapshot.sh").toString().replace(/^file:\/\//, "")
    Binding { target: data; property: "live"; value: backend.enabled }
    Binding { target: data; property: "controlsEnabled"; value: backend.enabled && backend.allowChanges }
    Binding { target: data; property: "busy"; value: action.running }
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
        stdout: StdioCollector {
            onStreamFinished: {
                try { backend.data.devices = JSON.parse(text); backend.data.status = backend.allowChanges ? "Live services" : "Live / read only"; }
                catch (error) { backend.data.status = "Device discovery unavailable"; }
            }
        }
    }
    Process {
        id: action
        onExited: (exitCode, exitStatus) => {
            backend.data.status = exitCode === 0 && exitStatus === 0 ? "Applied" : "Action failed: check service availability and permissions";
            if (!devices.running) devices.running = true;
        }
    }
    Process {
        id: rollback
        onExited: (exitCode, exitStatus) => backend.data.status = exitCode === 0 && exitStatus === 0 ? "Display reverted" : "Display rollback failed; restore the mode in Hyprland"
    }
    function revertDisplay() {
        confirmation.stop();
        if (rollbackRule) { rollback.command = ["hyprctl", "keyword", "monitor", rollbackRule]; rollback.running = true; }
        data.displayPending = false;
        rollbackRule = "";
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
            if (!backend.enabled || !backend.allowChanges || action.running || backend.data.displayPending) return;
            if (!monitor.availableModes.includes(mode) || scale < 0.5 || scale > 3 || transform < 0 || transform > 3) return;
            backend.rollbackRule = monitor.name + "," + monitor.width + "x" + monitor.height + "@" + monitor.refreshRate + "," + monitor.x + "x" + monitor.y + "," + monitor.scale + ",transform," + monitor.transform;
            action.command = ["hyprctl", "keyword", "monitor", monitor.name + "," + mode + "," + monitor.x + "x" + monitor.y + "," + scale + ",transform," + transform];
            action.running = true;
            backend.data.displayPending = true;
            backend.data.displayCountdown = 15;
            confirmation.start();
        }
        function onDisplayConfirmed() { confirmation.stop(); backend.rollbackRule = ""; backend.data.displayPending = false; }
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