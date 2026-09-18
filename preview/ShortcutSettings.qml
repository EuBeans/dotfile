import QtQuick
import QtCore

Item {
    id: shortcuts
    objectName: "shortcutSettings"
    property string recording: ""
    property string error: ""
    property var overrides: ({})
    readonly property var actions: [
        {key: "launcher", label: "App launcher", sequence: ""},
        {key: "windows", label: "Tile manager", sequence: ""},
        {key: "clipboard", label: "Clipboard history", sequence: ""},
        {key: "capture", label: "Screenshot manager", sequence: ""},
        {key: "summary", label: "System summary", sequence: ""},
        {key: "controls", label: "Home", sequence: "Ctrl+Alt+C"},
        {key: "settings", label: "Settings", sequence: "Ctrl+Alt+S"},
        {key: "ai", label: "Local AI", sequence: "Ctrl+Alt+A"},
        {key: "wallpaper", label: "Wallpaper", sequence: "Ctrl+Alt+W"},
        {key: "power", label: "Power menu", sequence: "Ctrl+Alt+P"},
        {key: "volume", label: "Volume", sequence: "Ctrl+Alt+V"},
        {key: "profile", label: "Switch profile", sequence: "Ctrl+Alt+G"},
        {key: "playback", label: "Play / pause", sequence: "Ctrl+Alt+M"},
        {key: "previous", label: "Previous track", sequence: "Ctrl+Alt+J"},
        {key: "next", label: "Next track", sequence: "Ctrl+Alt+K"},
        {key: "workspace1", label: "Workspace 1", sequence: "Ctrl+Alt+1"},
        {key: "workspace2", label: "Workspace 2", sequence: "Ctrl+Alt+2"},
        {key: "workspace4", label: "Workspace 4", sequence: "Ctrl+Alt+4"},
        {key: "workspace7", label: "Workspace 7", sequence: "Ctrl+Alt+7"}
    ]
    signal activated(string action)
    Settings {
        id: storage
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-preview/shortcuts.ini"
        category: "Shortcuts"
        property string bindingsJson: "{}"
    }
    Component.onCompleted: {
        try {
            const saved = JSON.parse(storage.bindingsJson);
            if (saved && typeof saved === "object" && !Array.isArray(saved)) {
                const valid = {};
                for (const action of actions) {
                    if (Object.prototype.hasOwnProperty.call(saved, action.key) && validSequence(saved[action.key]))
                        valid[action.key] = saved[action.key];
                }
                overrides = valid;
                const used = {};
                const clean = Object.assign({}, overrides);
                for (const action of actions) {
                    const sequence = binding(action.key);
                    if (sequence && used[sequence]) clean[action.key] = "";
                    else if (sequence) used[sequence] = true;
                }
                overrides = clean;
            }
        } catch (_error) { error = "Saved shortcuts could not be read. Defaults restored."; }
    }
    function validSequence(sequence) {
        return typeof sequence === "string" && (sequence === "" ||
            (/^(Ctrl\+)?(Alt\+)?(Shift\+)?(Meta\+)?([A-Z0-9]|F(?:[1-9]|1[0-2]))$/.test(sequence) &&
             (/Ctrl\+|Alt\+|Meta\+/.test(sequence) || /^F\d+$/.test(sequence))));
    }
    function binding(key) {
        if (Object.prototype.hasOwnProperty.call(overrides, key)) return overrides[key];
        const action = actions.find(entry => entry.key === key);
        return action ? action.sequence : "";
    }
    function saveBinding(key, sequence) {
        if (!actions.some(action => action.key === key) || !validSequence(sequence)) {
            error = "Use Ctrl, Alt or Meta with a letter/number, or F1-F12.";
            return false;
        }
        const conflict = actions.find(action => action.key !== key && sequence !== "" && binding(action.key) === sequence);
        if (conflict) { error = "Already assigned to " + conflict.label + "."; return false; }
        overrides = Object.assign({}, overrides, {[key]: sequence});
        storage.bindingsJson = JSON.stringify(overrides);
        storage.sync();
        error = "";
        recording = "";
        return true;
    }
    function recordKey(event) {
        event.accepted = true;
        if (event.key === Qt.Key_Escape) { recording = ""; error = ""; return; }
        if (event.isAutoRepeat || [Qt.Key_Control, Qt.Key_Alt, Qt.Key_Shift, Qt.Key_Meta].includes(event.key)) return;
        let key = "";
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z || event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
            key = String.fromCharCode(event.key);
        else if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F12) key = "F" + (event.key - Qt.Key_F1 + 1);
        let sequence = "";
        if (event.modifiers & Qt.ControlModifier) sequence += "Ctrl+";
        if (event.modifiers & Qt.AltModifier) sequence += "Alt+";
        if (event.modifiers & Qt.ShiftModifier) sequence += "Shift+";
        if (event.modifiers & Qt.MetaModifier) sequence += "Meta+";
        saveBinding(recording, key ? sequence + key : "invalid");
    }
    Repeater {
        model: shortcuts.actions
        Item {
            required property var modelData
            Shortcut {
                sequence: shortcuts.binding(modelData.key)
                enabled: shortcuts.recording === "" && sequence.toString() !== ""
                context: Qt.ApplicationShortcut
                onActivated: shortcuts.activated(modelData.key)
            }
        }
    }
}