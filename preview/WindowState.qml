import QtQuick
import QtCore

QtObject {
    id: manager
    objectName: "windowManager"
    required property var applications
    property int activeWorkspace: 1
    property string activeMonitor: defaultMonitor
    property int focusedId: 0
    property var recentIds: [0, 1, 2]
    property int nextId: 3
    property var windows: initialWindows()
    property var rules: []
    property var placementRules: []
    signal rulesEdited()
    property string error: ""
    property var screens: Qt.application.screens
    readonly property var monitors: Array.from(screens, (screen, index) => screen.name || "Display " + (index + 1))
    readonly property string defaultMonitor: monitors.length ? monitors[0] : ""
    onMonitorsChanged: {
        if (!windows || !monitors.length) return;
        const destination = monitors[0];
        if (!monitors.includes(activeMonitor)) activeMonitor = destination;
        windows = windows.map(window => monitors.includes(window.monitor) ? window : Object.assign({}, window, {monitor: destination}));
    }
    readonly property var workspaces: [1, 2, 4, 7]
    readonly property var visibleWindows: orderedWindows(activeMonitor, activeWorkspace)
    property Settings storage: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-preview/window-rules.ini"
        property string rulesJson: "[]"
    }
    Component.onCompleted: {
        try {
            const saved = JSON.parse(storage.rulesJson);
            if (!Array.isArray(saved) || saved.length > 64) throw new Error("Invalid rules");
            const apps = new Set();
            const slots = new Set();
            for (const rule of saved) {
                const slotKey = rule.monitor + ":" + rule.workspace + ":" + rule.slot;
                if (!validRule(rule) || apps.has(rule.appId) || slots.has(slotKey)) throw new Error("Invalid rule");
                apps.add(rule.appId);
                slots.add(slotKey);
            }
            rules = saved;
            placementRules = saved.slice();
        } catch (_error) { error = "Saved window rules were invalid; using no rules."; }
    }
    function initialWindows() {
        return [
            {windowId: 0, appId: "editor", title: "Editor", subtitle: "shell.qml", body: "import QtQuick\n\nShellRoot {\n    Bar {}\n}", monitor: defaultMonitor, workspace: 1, floating: false},
            {windowId: 1, appId: "browser", title: "Reference", subtitle: "Workspace notes", body: "QUICKSHELL\n\nWork / development\nGaming / fullscreen", monitor: defaultMonitor, workspace: 1, floating: false},
            {windowId: 2, appId: "terminal", title: "Terminal", subtitle: "Preview session", body: "$ preview --check\nQML loaded\n\n$ _", monitor: defaultMonitor, workspace: 1, floating: false}
        ];
    }
    function validRule(rule) {
        return rule && applications.some(app => app.appId === rule.appId) && typeof rule.monitor === "string" && rule.monitor.trim().length > 0 && workspaces.includes(rule.workspace) && Number.isInteger(rule.slot) && rule.slot >= 0 && rule.slot < 12;
    }
    function orderedWindows(monitor, workspace) {
        const scope = windows.filter(window => window.monitor === monitor && window.workspace === workspace);
        let ordered = scope.filter(window => !window.floating);
        const applicable = placementRules.filter(rule => rule.monitor === monitor && rule.workspace === workspace).slice().sort((first, second) => first.slot - second.slot);
        const reserved = applicable.map(rule => ({rule: rule, window: ordered.find(window => window.appId === rule.appId && !window.floating)})).filter(entry => entry.window);
        const reservedIds = reserved.map(entry => entry.window.windowId);
        ordered = ordered.filter(window => !reservedIds.includes(window.windowId));
        for (const entry of reserved) ordered.splice(Math.min(entry.rule.slot, ordered.length), 0, entry.window);
        return ordered.concat(scope.filter(window => window.floating));
    }
    function focus(windowId) {
        const window = windows.find(entry => entry.windowId === windowId);
        if (!window) return;
        activeMonitor = window.monitor;
        activeWorkspace = window.workspace;
        focusedId = windowId;
        recentIds = [windowId].concat(recentIds.filter(entry => entry !== windowId));
    }
    function open(appId) {
        const app = applications.find(entry => entry.appId === appId);
        if (!app) return -1;
        const rule = rules.find(entry => entry.appId === appId && monitors.includes(entry.monitor));
        if (rule) placementRules = placementRules.filter(entry => entry.appId !== appId).concat([rule]);
        const windowId = nextId++;
        windows = windows.concat([{windowId: windowId, appId: appId, title: app.name, subtitle: app.category, body: app.name + "\n\nPreview window", monitor: rule ? rule.monitor : activeMonitor, workspace: rule ? rule.workspace : activeWorkspace, floating: false}]);
        focus(windowId);
        return windowId;
    }
    function close(windowId) {
        windows = windows.filter(window => window.windowId !== windowId);
        recentIds = recentIds.filter(entry => entry !== windowId);
        if (focusedId === windowId) focusedId = visibleWindows.length ? visibleWindows[0].windowId : -1;
    }
    function move(windowId, monitor, workspace) {
        if (!monitors.includes(monitor) || !workspaces.includes(workspace)) return;
        windows = windows.map(window => window.windowId === windowId ? Object.assign({}, window, {monitor: monitor, workspace: workspace}) : window);
        if (!visibleWindows.some(window => window.windowId === focusedId)) focusedId = visibleWindows.length ? visibleWindows[0].windowId : -1;
    }
    function setFloating(windowId, floating) {
        windows = windows.map(window => window.windowId === windowId ? Object.assign({}, window, {floating: Boolean(floating)}) : window);
    }
    function place(windowId, slot) {
        const window = windows.find(entry => entry.windowId === windowId);
        if (!window || !Number.isInteger(slot)) return;
        const group = windows.filter(entry => entry.monitor === window.monitor && entry.workspace === window.workspace);
        const current = group.findIndex(entry => entry.windowId === windowId);
        group.splice(current, 1);
        group.splice(Math.max(0, Math.min(slot, group.length)), 0, window);
        let cursor = 0;
        windows = windows.map(entry => entry.monitor === window.monitor && entry.workspace === window.workspace ? group[cursor++] : entry);
    }
    function reserve(appId, monitor, workspace, slot) {
        const rule = {appId: appId, monitor: monitor, workspace: workspace, slot: slot};
        if (!validRule(rule) || !monitors.includes(monitor)) { error = "Invalid app or tile destination."; return false; }
        if (rules.some(entry => entry.appId !== appId && entry.monitor === monitor && entry.workspace === workspace && entry.slot === slot)) {
            error = "This tile already has an app rule.";
            return false;
        }
        rules = rules.filter(entry => entry.appId !== appId).concat([rule]);
        placementRules = placementRules.filter(entry => entry.appId !== appId).concat([rule]);
        const existing = windows.find(window => window.appId === appId && !window.floating);
        if (existing) move(existing.windowId, monitor, workspace);
        saveRules();
        return true;
    }
    function removeRule(appId) {
        rules = rules.filter(rule => rule.appId !== appId);
        placementRules = placementRules.filter(rule => rule.appId !== appId);
        saveRules();
    }
    function saveRules() {
        storage.rulesJson = JSON.stringify(rules);
        storage.setValue("rulesJson", storage.rulesJson);
        storage.sync();
        error = "";
        rulesEdited();
    }
    function reset() {
        activeWorkspace = 1;
        activeMonitor = defaultMonitor;
        focusedId = 0;
        recentIds = [0, 1, 2];
        nextId = 3;
        windows = initialWindows();
    }
}