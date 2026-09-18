import QtQuick

QtObject {
    id: captures
    objectName: "captureState"
    property var entries: []
    property int selectedId: -1
    property int nextId: 1
    property int generation: 0
    property string status: "Idle"
    property string error: ""
    property var pendingFrame: null
    property url pendingSource: ""
    property string mode: "Screen"
    property Component frameFactory: Component {
        QtObject { property var result }
    }
    readonly property bool busy: status === "Capturing" || status === "Selecting" || status === "Exporting"
    signal exportRequested(string path)
    readonly property var selected: entries.find(entry => entry.captureId === selectedId) || null
    function begin(captureMode) {
        if (busy) return -1;
        mode = captureMode;
        error = "";
        status = "Capturing";
        return ++generation;
    }
    function complete(request, frame) {
        if (request !== generation || !busy) return;
        const captureId = nextId++;
        const owner = frameFactory.createObject(captures, {result: frame});
        entries = [{captureId: captureId, name: mode + " " + captureId, source: frame.url, frame: owner, pinned: false}].concat(entries);
        selectedId = captureId;
        pendingFrame = null;
        pendingSource = "";
        status = "Ready";
    }
    function fail(request, message) {
        if (request !== generation) return;
        pendingFrame = null;
        pendingSource = "";
        error = message;
        status = "Error";
    }
    function cancel() { generation++; pendingFrame = null; pendingSource = ""; status = "Idle"; error = ""; }
    function pin(captureId) {
        entries = entries.map(entry => entry.captureId === captureId ? Object.assign({}, entry, {pinned: !entry.pinned}) : entry);
    }
    function remove(captureId) {
        entries = entries.filter(entry => entry.captureId !== captureId);
        if (selectedId === captureId) selectedId = entries.length ? entries[0].captureId : -1;
    }
    function clearUnpinned() {
        entries = entries.filter(entry => entry.pinned);
        if (!selected) selectedId = entries.length ? entries[0].captureId : -1;
    }
    function save(url: url): bool {
        if (!selected || busy) return false;
        const path = String(url);
        if (!path.startsWith("file:///")) { error = "Choose a local PNG file."; return false; }
        status = "Exporting";
        exportRequested(decodeURIComponent(path.substring(7)));
        return true;
    }
    function exportComplete(saved) {
        error = saved ? "" : "Could not save image. Choose another location.";
        status = saved ? "Saved" : "Error";
    }
    function reset() { cancel(); entries = []; selectedId = -1; nextId = 1; }
}