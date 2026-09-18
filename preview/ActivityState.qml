import QtQuick

QtObject {
    id: activities
    required property var service
    property string selectedId: ""
    property string returnId: ""
    property int seenAlert: 0
    property int alertSerial: 0
    property string alertTitle: ""
    property int alertSeconds: 0
    property int timerSeconds: 0
    property int timerDuration: 300
    property bool timerPaused: false
    property bool aiActive: false
    property real aiProgress: -1
    property string aiTask: "Drafting a response"
    property bool transferActive: false
    property bool transferPaused: false
    property bool transferUpload: false
    property int transferSeconds: 120
    property bool recordingActive: false
    property bool sharing: false
    property int recordingSeconds: 0
    readonly property var entries: {
        const result = [];
        if (service.mediaAvailable && service.playing)
            result.push({key: "music", label: "Music"});
        if (timerSeconds > 0)
            result.push({key: "timer", label: "Timer", icon: "timer", title: time(timerSeconds), detail: timerPaused ? "Paused" : "Timer", progress: 1 - timerSeconds / timerDuration, paused: timerPaused, canPause: true});
        if (aiActive)
            result.push({key: "ai", label: "AI task", icon: "bot", title: aiTask, detail: service.loadedModelIndex >= 0 ? service.models[service.loadedModelIndex] : "No model", progress: aiProgress, canPause: false});
        if (transferActive)
            result.push({key: "transfer", label: "Transfer", icon: "download", title: (transferUpload ? "Upload" : "Download") + " / Preview archive", detail: transferPaused ? "Paused" : time(transferSeconds) + " remaining", progress: 1 - transferSeconds / 120, paused: transferPaused, canPause: true});
        if (recordingActive)
            result.push({key: "recording", label: sharing ? "Screen sharing" : "Recording", icon: sharing ? "monitor" : "circle-dot", title: sharing ? "Screen sharing" : "Recording", detail: time(recordingSeconds), progress: -1, canPause: false});
        if (alertSeconds > 0)
            result.push({key: "alert", label: "Alert", icon: "bell", title: alertTitle, detail: "Urgent alert", progress: -1, canPause: false});
        return result;
    }
    readonly property var selected: entries.find(entry => entry.key === selectedId) || null
    readonly property int selectedIndex: entries.findIndex(entry => entry.key === selectedId)
    readonly property string nextLabel: entries.length > 1 ? entries[(selectedIndex + 1) % entries.length].label : ""
    onEntriesChanged: reconcile()
    function reconcile() {
        const keys = entries.map(entry => entry.key);
        if (keys.includes("alert") && alertSerial !== seenAlert) {
            if (selectedId !== "alert") returnId = selectedId;
            seenAlert = alertSerial;
            selectedId = "alert";
        } else if (selectedId === "alert" && !keys.includes("alert")) {
            selectedId = keys.includes(returnId) ? returnId : (keys[0] || "");
            returnId = "";
        } else if (!keys.includes(selectedId)) {
            selectedId = keys[0] || "";
        }
    }
    function cycle() {
        if (entries.length > 1) selectedId = entries[(selectedIndex + 1) % entries.length].key;
    }
    function time(seconds) {
        return Math.floor(seconds / 60) + ":" + String(Math.floor(seconds % 60)).padStart(2, "0");
    }
    function startTimer(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0) return;
        timerDuration = Math.max(1, Math.round(seconds));
        timerPaused = false;
        timerSeconds = timerDuration;
    }
    function startAi() {
        if (aiActive || service.loadedModelIndex < 0 || service.aiBusy) return;
        service.activeRequests += 1;
        aiProgress = -1;
        aiActive = true;
    }
    function startTransfer(upload) {
        transferUpload = Boolean(upload);
        transferSeconds = 120;
        transferPaused = false;
        transferActive = true;
    }
    function startRecording(screenSharing) {
        sharing = screenSharing;
        recordingSeconds = 0;
        recordingActive = true;
    }
    function alert(title) {
        alertTitle = title;
        alertSerial += 1;
        alertSeconds = 8;
        reconcile();
    }
    function pause(key) {
        if (key === "timer") timerPaused = !timerPaused;
        if (key === "transfer") transferPaused = !transferPaused;
    }
    function stop(key) {
        if (key === "timer") timerSeconds = 0;
        if (key === "ai" && aiActive) {
            aiActive = false;
            service.activeRequests = Math.max(0, service.activeRequests - 1);
        }
        if (key === "transfer") transferActive = false;
        if (key === "recording") recordingActive = false;
        if (key === "alert") alertSeconds = 0;
    }
    function advance() {
        if (alertSeconds > 0) alertSeconds -= 1;
        if (timerSeconds > 0 && !timerPaused) {
            timerSeconds -= 1;
            if (timerSeconds === 0) alert("Timer finished");
        }
        if (transferActive && !transferPaused) {
            transferSeconds = Math.max(0, transferSeconds - 1);
            if (transferSeconds === 0) transferActive = false;
        }
        if (recordingActive) recordingSeconds += 1;
    }
    function reset() {
        stop("ai");
        timerSeconds = 0;
        timerPaused = false;
        transferActive = false;
        transferPaused = false;
        recordingActive = false;
        alertSeconds = 0;
        returnId = "";
    }
    property Timer tick: Timer {
        interval: 1000
        repeat: true
        running: activities.timerSeconds > 0 || activities.transferActive || activities.recordingActive || activities.alertSeconds > 0
        onTriggered: activities.advance()
    }
    property Connections aiChanges: Connections {
        target: activities.service
        function onAiStatusChanged() {
            if (activities.service.aiStatus !== "Running") activities.stop("ai");
        }
        function onActiveRequestsChanged() {
            if (activities.service.activeRequests === 0) activities.aiActive = false;
        }
    }
}