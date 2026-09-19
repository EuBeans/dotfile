import QtQuick
import Quickshell.Io
import "../../preview" as Preview

Preview.ShortcutSettings {
    id: shortcuts
    nativeBackend: true
    actions: []
    busy: backend.running
    ready: false
    readonly property string helper: Qt.resolvedUrl("../shortcuts.py").toString().replace(/^file:\/\//, "")
    onBindingRequested: (key, sequence) => {
        if (backend.running) return;
        recording = "";
        backend.command = ["python3", helper, "save", key, sequence];
        backend.running = true;
    }
    Process {
        id: backend
        command: ["python3", shortcuts.helper, "list"]
        running: true
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }
        onExited: (exitCode, exitStatus) => {
            try {
                const result = JSON.parse(output.text);
                if (exitCode !== 0 || exitStatus !== 0 || result.error) {
                    shortcuts.error = result.error || "Shortcut update failed.";
                    return;
                }
                shortcuts.overrides = result.bindings;
                shortcuts.actions = result.actions;
                shortcuts.ready = true;
                shortcuts.error = "";
            } catch (error) { shortcuts.error = errors.text || "Shortcut backend unavailable."; }
        }
    }
}