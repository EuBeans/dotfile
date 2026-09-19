import QtQuick
import QtCore

QtObject {
    id: settings
    objectName: "profileSettings"
    property url settingsLocation: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-preview/profiles.ini"
    property alias glassEnabled: storage.glassEnabled
    property alias floatingPanels: storage.floatingPanels
    property alias floatingLeftBar: storage.floatingLeftBar
    property alias floatingMiddleBar: storage.floatingMiddleBar
    property alias floatingRightBar: storage.floatingRightBar
    property alias panelRadius: storage.panelRadius
    property alias barRadius: storage.barRadius
    property alias windowRadius: storage.windowRadius
    property alias animationStyle: storage.animationStyle
    property alias animationDuration: storage.animationDuration
    property alias tileGap: storage.tileGap
    property alias outerGap: storage.outerGap
    property alias tilingLayout: storage.tilingLayout
    property alias mainPaneRatio: storage.mainPaneRatio
    property alias windowBorderWidth: storage.windowBorderWidth
    property alias panelOpacity: storage.panelOpacity
    property alias windowOpacity: storage.windowOpacity
    property alias wallpaperDirectory: storage.wallpaperDirectory
    property string activeName: "Work"
    property var profiles: [
        {name: "Work", palette: "Chalk", source: "Saved", wallpaper: 0},
        {name: "Gaming", palette: "Chalk", source: "Saved", wallpaper: 1}
    ]
    readonly property var paletteNames: ["Chalk", "Phosphor", "Ice", "Butter", "Rose"]
    readonly property var palettes: ({
        Chalk: {paper: "#efefeb", ink: "#1c1c1c", muted: "#aaaaaa", line: "#525252", hover: "#353535", stage: "#d4d4d4", accent: "#efefeb"},
        Phosphor: {paper: "#e5efe9", ink: "#141a18", muted: "#a0b3a7", line: "#4b6257", hover: "#2b4035", stage: "#cbd7ce", accent: "#a2d9b2"},
        Ice: {paper: "#e8edf0", ink: "#161a1c", muted: "#a3b0b5", line: "#4a5f66", hover: "#303d42", stage: "#ccd7db", accent: "#a3d9e3"},
        Butter: {paper: "#f6f1cb", ink: "#29291f", muted: "#c4c2a6", line: "#686853", hover: "#454536", stage: "#f7f3ce", accent: "#e5dc98"},
        Rose: {paper: "#eee2e6", ink: "#222228", muted: "#b8acbb", line: "#625662", hover: "#39333e", stage: "#282735", accent: "#cf91af"}
    })
    readonly property var currentProfile: profiles.find(entry => entry.name === activeName) || profiles[0]
    readonly property var palette: currentProfile.source === "Wallpaper" && sampledPalette ? sampledPalette : palettes[currentProfile.palette]
    property var sampledPalette: null
    property string error: ""
    property bool ready: false
    property bool applying: false
    property var savedProfiles: []
    property bool legacyRulesPending: false
    property var copyUndo: null
    readonly property bool dirty: JSON.stringify(currentProfile) !== JSON.stringify(savedProfiles.find(entry => entry.name === activeName))
    readonly property var categories: ["appearance", "tiling", "ai", "notifications", "audio"]
    readonly property var appearanceKeys: ["glassEnabled", "floatingPanels", "floatingLeftBar", "floatingMiddleBar", "floatingRightBar", "panelRadius", "barRadius", "windowRadius", "animationStyle", "animationDuration", "panelOpacity", "windowOpacity"]
    readonly property var tilingKeys: ["tileGap", "outerGap", "tilingLayout", "mainPaneRatio", "windowBorderWidth"]
    property Connections storageChanges: Connections {
        target: storage
        function onGlassEnabledChanged() { settings.captureSettings(); }
        function onFloatingPanelsChanged() { settings.captureSettings(); }
        function onFloatingLeftBarChanged() { settings.captureSettings(); }
        function onFloatingMiddleBarChanged() { settings.captureSettings(); }
        function onFloatingRightBarChanged() { settings.captureSettings(); }
        function onPanelRadiusChanged() { settings.captureSettings(); }
        function onBarRadiusChanged() { settings.captureSettings(); }
        function onWindowRadiusChanged() { settings.captureSettings(); }
        function onAnimationStyleChanged() { settings.captureSettings(); }
        function onAnimationDurationChanged() { settings.captureSettings(); }
        function onPanelOpacityChanged() { settings.captureSettings(); }
        function onWindowOpacityChanged() { settings.captureSettings(); }
        function onTileGapChanged() { settings.captureSettings(); }
        function onOuterGapChanged() { settings.captureSettings(); }
        function onTilingLayoutChanged() { settings.captureSettings(); }
        function onMainPaneRatioChanged() { settings.captureSettings(); }
        function onWindowBorderWidthChanged() { settings.captureSettings(); }
    }
    property Settings storage: Settings {
        id: storage
        location: settings.settingsLocation
        property string records: ""
        property int schemaVersion: 1
        property string selected: "Work"
        property bool glassEnabled: true
        property bool floatingPanels: false
        property bool floatingLeftBar: true
        property bool floatingMiddleBar: false
        property bool floatingRightBar: true
        property int panelRadius: 8
        property int barRadius: 8
        property int windowRadius: 8
        property string animationStyle: "Stepped"
        property int animationDuration: 240
        property int tileGap: 12
        property int outerGap: 12
        property string tilingLayout: "Auto"
        property int mainPaneRatio: 56
        property int windowBorderWidth: 2
        property int panelOpacity: 84
        property int windowOpacity: 92
        property string wallpaperDirectory: ""
    }
    Component.onCompleted: {
        legacyRulesPending = storage.schemaVersion < 2;
        for (const key of ["panelRadius", "barRadius", "windowRadius"]) storage[key] = Math.max(0, Math.min(24, storage[key]));
        storage.animationDuration = Math.max(0, Math.min(800, storage.animationDuration));
        storage.tileGap = Math.max(0, Math.min(32, storage.tileGap));
        storage.outerGap = Math.max(0, Math.min(64, storage.outerGap));
        storage.mainPaneRatio = Math.max(30, Math.min(70, storage.mainPaneRatio));
        storage.windowBorderWidth = Math.max(0, Math.min(8, storage.windowBorderWidth));
        if (!["Auto", "Split", "Columns", "Centered"].includes(storage.tilingLayout)) storage.tilingLayout = "Auto";
        for (const key of ["panelOpacity", "windowOpacity"]) storage[key] = Math.max(40, Math.min(100, storage[key]));
        if (!["Stepped", "Smooth", "Off"].includes(storage.animationStyle)) storage.animationStyle = "Stepped";
        if (storage.records) {
            try {
                const saved = JSON.parse(storage.records);
                const names = new Set();
                if (!Array.isArray(saved) || !saved.length || saved.length > 32) throw new Error("Invalid profiles");
                for (const entry of saved) {
                    if (typeof entry.name !== "string" || !entry.name.trim() || entry.name.length > 32 || names.has(entry.name.toLowerCase()) ||
                        !paletteNames.includes(entry.palette) || !["Saved", "Wallpaper"].includes(entry.source) ||
                        !Number.isInteger(entry.wallpaper) || entry.wallpaper < 0 || entry.wallpaper > 2 ||
                        (entry.wallpaperFile !== undefined && (typeof entry.wallpaperFile !== "string" || (entry.wallpaperFile !== "" && !entry.wallpaperFile.startsWith("file:///"))))) throw new Error("Invalid profile");
                    names.add(entry.name.toLowerCase());
                    if (entry.paletteMonitor !== undefined && entry.paletteMonitor !== "" && !validWallpaperMonitor(entry.paletteMonitor)) throw new Error("Invalid palette monitor");
                    if (entry.wallpaperFiles !== undefined && (!entry.wallpaperFiles || typeof entry.wallpaperFiles !== "object" || Array.isArray(entry.wallpaperFiles) ||
                        Object.entries(entry.wallpaperFiles).some(([monitor, file]) => !validWallpaperMonitor(monitor) || typeof file !== "string" || !file.startsWith("file:///")))) throw new Error("Invalid monitor wallpapers");
                    for (const category of categories) {
                        if (entry[category] !== undefined && (!entry[category] || typeof entry[category] !== "object" || Array.isArray(entry[category]))) throw new Error("Invalid profile category");
                    }
                    if (entry.ai && (!["Keep", "Load", "Unload", "Stop"].includes(entry.ai.action) || ![0, 1].includes(entry.ai.model) || ![0, 1].includes(entry.ai.gpu) || !Number.isInteger(entry.ai.budget) || entry.ai.budget < 1 || entry.ai.budget > 32)) throw new Error("Invalid AI policy");
                    if (entry.notifications && (!["Normal", "Priority", "DND"].includes(entry.notifications.mode) || typeof entry.notifications.urgent !== "boolean")) throw new Error("Invalid notification policy");
                    if (entry.audio && (typeof entry.audio.enabled !== "boolean" || !["Default", "Headphones", "Speakers"].includes(entry.audio.device) || !Number.isInteger(entry.audio.volume) || entry.audio.volume < 0 || entry.audio.volume > 100)) throw new Error("Invalid audio policy");
                    if (entry.tiling && ((entry.tiling.rules !== undefined && !Array.isArray(entry.tiling.rules)) || (entry.tiling.summary !== undefined && (!entry.tiling.summary || !Number.isFinite(entry.tiling.summary.x) || !Number.isFinite(entry.tiling.summary.y))))) throw new Error("Invalid layout policy");
                }
                if (!saved.some(entry => entry.name === "Work") || !saved.some(entry => entry.name === "Gaming")) throw new Error("Missing base profiles");
                profiles = saved;
                activeName = saved.some(entry => entry.name === storage.selected) ? storage.selected : "Work";
            } catch (_error) { error = "Saved profiles were invalid; using defaults."; }
        }
        profiles = profiles.map(entry => Object.assign({}, entry, {
            appearance: Object.assign(snapshot(appearanceKeys), entry.appearance || {}),
            tiling: Object.assign(snapshot(tilingKeys), {rules: [], summary: {x: 0, y: 0}}, entry.tiling || {}),
            ai: Object.assign({action: entry.name === "Gaming" ? "Unload" : "Keep", model: 0, gpu: 0, budget: 28}, entry.ai || {}),
            notifications: Object.assign({mode: entry.name === "Gaming" ? "DND" : "Normal", urgent: true}, entry.notifications || {}),
            audio: Object.assign({enabled: false, volume: 64, device: "Default"}, entry.audio || {})
        }));
        savedProfiles = clone(profiles);
        restoreSettings();
        ready = true;
        persist();
    }
    onActiveNameChanged: {
        if (ready) {
            if (!profiles.some(entry => entry.name === activeName)) { activeName = profiles[0].name; return; }
            restoreSettings();
            persist();
        }
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function snapshot(keys) {
        const result = {};
        for (const key of keys) result[key] = storage[key];
        return result;
    }
    function captureSettings() {
        if (!ready || applying) return;
        profiles = profiles.map(entry => entry.name === activeName ? Object.assign({}, entry, {
            appearance: snapshot(appearanceKeys), tiling: Object.assign({}, entry.tiling, snapshot(tilingKeys))
        }) : entry);
    }
    function restoreSettings() {
        const selected = profiles.find(entry => entry.name === activeName) || profiles[0];
        applying = true;
        for (const key of appearanceKeys.concat(tilingKeys)) {
            const group = appearanceKeys.includes(key) ? selected.appearance : selected.tiling;
            if (["glassEnabled", "floatingPanels", "floatingLeftBar", "floatingMiddleBar", "floatingRightBar"].includes(key)) storage[key] = typeof group[key] === "boolean" ? group[key] : !["floatingPanels", "floatingMiddleBar"].includes(key);
            else setAppearance(key, group[key]);
        }
        applying = false;
    }
    function save() {
        const selected = profiles.find(entry => entry.name === activeName);
        savedProfiles = savedProfiles.some(entry => entry.name === activeName)
            ? savedProfiles.map(entry => entry.name === activeName ? clone(selected) : entry)
            : savedProfiles.concat([clone(selected)]);
        persist();
    }
    function persist() {
        storage.schemaVersion = 2;
        storage.setValue("schemaVersion", 2);
        storage.records = JSON.stringify(savedProfiles);
        storage.selected = activeName;
        storage.setValue("records", storage.records);
        storage.setValue("selected", storage.selected);
        storage.sync();
    }
    function revert() {
        const saved = savedProfiles.find(entry => entry.name === activeName);
        if (!saved) return;
        profiles = profiles.map(entry => entry.name === activeName ? clone(saved) : entry);
        restoreSettings();
    }
    function setPolicy(category, key, value) {
        const allowed = {
            ai: {action: ["Keep", "Load", "Unload", "Stop"], model: [0, 1], gpu: [0, 1]},
            notifications: {mode: ["Normal", "Priority", "DND"], urgent: [true, false]},
            audio: {enabled: [true, false], device: ["Default", "Headphones", "Speakers"]}
        };
        if (category === "ai" && key === "budget") {
            if (!Number.isInteger(value) || value < 1 || value > 32) return;
        } else if (category === "audio" && key === "volume") {
            if (!Number.isInteger(value) || value < 0 || value > 100) return;
        } else if (!allowed[category] || !allowed[category][key] || !allowed[category][key].includes(value)) return;
        setCategory(category, Object.assign({}, currentProfile[category], {[key]: value}));
    }
    function setCategory(category, value) {
        if (!categories.includes(category)) return;
        profiles = profiles.map(entry => entry.name === activeName ? Object.assign({}, entry, {[category]: clone(value)}) : entry);
    }
    function copyFrom(sourceName, selectedCategories) {
        const source = profiles.find(entry => entry.name === sourceName);
        if (!source || sourceName === activeName || !selectedCategories.length || selectedCategories.some(category => !categories.includes(category))) return false;
        copyUndo = clone(currentProfile);
        let destination = clone(currentProfile);
        for (const category of selectedCategories) destination[category] = clone(source[category]);
        if (selectedCategories.includes("appearance")) {
            for (const key of ["palette", "source", "wallpaper", "wallpaperFile", "wallpaperFiles", "paletteMonitor"]) {
                if (source[key] !== undefined) destination[key] = clone(source[key]);
                else delete destination[key];
            }
        }
        profiles = profiles.map(entry => entry.name === activeName ? destination : entry);
        restoreSettings();
        return true;
    }
    function undoCopy() {
        if (!copyUndo || copyUndo.name !== activeName) return;
        profiles = profiles.map(entry => entry.name === activeName ? clone(copyUndo) : entry);
        copyUndo = null;
        restoreSettings();
    }
    function setAppearance(key, value) {
        if (["panelRadius", "barRadius", "windowRadius"].includes(key)) {
            if (!Number.isInteger(value) || value < 0 || value > 24) return;
        } else if (key === "animationDuration") {
            if (!Number.isInteger(value) || value < 0 || value > 800) return;
        } else if (key === "animationStyle") {
            if (!["Stepped", "Smooth", "Off"].includes(value)) return;
        } else if (key === "tileGap" || key === "outerGap") {
            if (!Number.isInteger(value) || value < 0 || value > (key === "tileGap" ? 32 : 64)) return;
        } else if (key === "tilingLayout") {
            if (!["Auto", "Split", "Columns", "Centered"].includes(value)) return;
        } else if (key === "mainPaneRatio") {
            if (!Number.isInteger(value) || value < 30 || value > 70) return;
        } else if (key === "windowBorderWidth") {
            if (!Number.isInteger(value) || value < 0 || value > 8) return;
        } else if (key === "panelOpacity" || key === "windowOpacity") {
            if (!Number.isInteger(value) || value < 40 || value > 100) return;
        } else return;
        storage[key] = value;
        storage.setValue(key, value);
        storage.sync();
    }
    function update(field, value) {
        if (field === "palette" && !paletteNames.includes(value)) return;
        if (field === "source" && !["Saved", "Wallpaper"].includes(value)) return;
        if (field === "wallpaper" && (!Number.isInteger(value) || value < 0 || value > 2)) return;
        if (!["palette", "source", "wallpaper"].includes(field)) return;
        profiles = profiles.map(entry => entry.name === activeName ? Object.assign({}, entry, {[field]: value}) : entry);
    }
    function setWallpaperDirectory(directory) {
        const location = String(directory);
        if (location !== "" && !location.startsWith("file:///")) return;
        storage.wallpaperDirectory = location;
        storage.setValue("wallpaperDirectory", location);
        storage.sync();
    }
    function selectWallpaper(index, file) {
        if (!Number.isInteger(index) || index < 0 || index > 2) return;
        if (typeof file !== "string" || (file !== "" && !file.startsWith("file:///"))) return;
        profiles = profiles.map(entry => entry.name === activeName ? Object.assign({}, entry, {wallpaper: index, wallpaperFile: file, wallpaperFiles: {}, paletteMonitor: ""}) : entry);
    }
    function validWallpaperMonitor(monitor) {
        return typeof monitor === "string" && /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/.test(monitor) && !["constructor", "prototype"].includes(monitor);
    }
    function wallpaperForMonitor(monitor, fallback) {
        const files = currentProfile.wallpaperFiles || {};
        return Object.prototype.hasOwnProperty.call(files, monitor) ? files[monitor] : fallback;
    }
    function useWallpaperPalette(monitor) {
        if (monitor !== "" && !validWallpaperMonitor(monitor)) return;
        profiles = profiles.map(entry => entry.name === activeName ? Object.assign({}, entry, {source: "Wallpaper", paletteMonitor: monitor}) : entry);
    }
    function paletteWallpaperSource(fallback) {
        return wallpaperForMonitor(currentProfile.paletteMonitor || "", fallback);
    }
    function selectMonitorWallpaper(monitor, file) {
        if (!validWallpaperMonitor(monitor) || typeof file !== "string" || (file !== "" && !file.startsWith("file:///"))) return;
        const files = Object.assign({}, currentProfile.wallpaperFiles || {});
        if (file) files[monitor] = file;
        else delete files[monitor];
        const paletteTarget = file && currentProfile.source === "Wallpaper" ? {paletteMonitor: monitor} : {};
        profiles = profiles.map(entry => entry.name === activeName ? Object.assign({}, entry, {wallpaperFiles: files}, paletteTarget) : entry);
    }
    function add(name, sourceName) {
        const clean = name.trim();
        if (!clean || clean.length > 32 || profiles.length >= 32 || profiles.some(entry => entry.name.toLowerCase() === clean.toLowerCase())) {
            error = "Use a unique name of 1-32 characters (maximum 32 profiles).";
            return false;
        }
        let source = profiles.find(entry => entry.name === sourceName) || currentProfile;
        if (sourceName === "Defaults") source = {
            palette: "Chalk", source: "Saved", wallpaper: 0,
            appearance: {glassEnabled: true, floatingPanels: false, floatingLeftBar: true, floatingMiddleBar: false, floatingRightBar: true, panelRadius: 8, barRadius: 8, windowRadius: 8, animationStyle: "Stepped", animationDuration: 240, panelOpacity: 84, windowOpacity: 92},
            tiling: {tileGap: 12, outerGap: 12, tilingLayout: "Auto", mainPaneRatio: 56, windowBorderWidth: 2, rules: [], summary: {x: 0, y: 0}},
            ai: {action: "Keep", model: 0, gpu: 0, budget: 28},
            notifications: {mode: "Normal", urgent: true}, audio: {enabled: false, volume: 64, device: "Default"}
        };
        profiles = profiles.concat([Object.assign(clone(source), {name: clean})]);
        activeName = clean;
        error = "";
        save();
        return true;
    }
    function next() {
        activeName = profiles[(profiles.findIndex(entry => entry.name === activeName) + 1) % profiles.length].name;
    }
}