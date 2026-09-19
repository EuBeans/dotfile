import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: manager

    property var snapshot: ({presets: [], runtimes: [], busy: false, operation: null, opencode: {state: "unchanged"}})
    property real receivedAt: 0
    property real clock: Date.now()
    property int sequence: 0
    property string pendingRequest: ""
    property real requestDeadline: 0
    property string requestError: ""
    property string profileName: ""
    property var profileDefaults: ({})
    readonly property var connection: socketLoader.item
    readonly property bool fresh: !!connection && connection.connected && receivedAt > 0 && clock - receivedAt < 15000
        && snapshot.observed_at && clock - snapshot.observed_at * 1000 < 15000 && !snapshot.error
    readonly property bool busy: !!snapshot.busy || pendingRequest !== ""
    readonly property var presets: snapshot.presets || []
    readonly property var models: presets.map(preset => preset.name)
    readonly property var activeRuntimes: (snapshot.runtimes || []).filter(runtime => runtime.running || runtime.online)
    readonly property var runtime: activeRuntimes[0] || (snapshot.runtimes || []).find(runtime => runtime.error) || null
    readonly property bool external: activeRuntimes.some(runtime => !runtime.owned)
    readonly property int loadedModelIndex: runtime ? presets.findIndex(preset => preset.id === runtime.preset_id) : -1
    readonly property int defaultModelIndex: {
        const profileDefault = presets.findIndex(preset => preset.id === profileDefaults[profileName]);
        if (profileDefault >= 0) return profileDefault;
        const remembered = presets.findIndex(preset => preset.id === snapshot.default_preset_id);
        if (remembered >= 0) return remembered;
        const requested = runtime ? presets.findIndex(preset => preset.id === runtime.requested_preset_id) : -1;
        return requested >= 0 ? requested : loadedModelIndex >= 0 ? loadedModelIndex : presets.length ? 0 : -1;
    }
    readonly property var requestedPreset: runtime ? presets.find(preset => preset.id === runtime.requested_preset_id) : null
    readonly property string loadedModelName: runtime && runtime.state === "starting" && requestedPreset ? "Loading " + requestedPreset.name
        : runtime && !runtime.online && runtime.running ? "Model identity unavailable"
        : runtime && runtime.models.length ? runtime.models.join(", ") : "No model loaded"
    readonly property string runtimeLabel: runtime ? (runtime.provider === "vllm" ? "vLLM" : "Ollama") : "Local runtime"
    readonly property bool canStart: fresh && !busy && activeRuntimes.length === 0
    readonly property bool canStop: fresh && !busy && activeRuntimes.length > 0 && !external
    readonly property bool canSwitch: canStop
    readonly property bool canAdopt: fresh && !busy && external && activeRuntimes.length === 1 && !!runtime.container_id && runtime.models.length === 1
    readonly property int runningRequests: fresh && runtime && Number.isFinite(runtime.running_requests) ? runtime.running_requests : -1
    readonly property real tokensPerSecond: fresh && runtime && Number.isFinite(runtime.tokens_per_second) ? runtime.tokens_per_second : -1
    readonly property var loadingProgress: {
        if (!fresh) return null;
        if (runtime && runtime.progress) return runtime.progress;
        if (!snapshot.busy || !snapshot.operation) return null;
        const labels = {checking: "Checking model", stopping: "Stopping runtime", starting: "Starting container",
            "waiting-ready": "Waiting for model readiness", "loading-model": "Loading model weights", "configuring-opencode": "Configuring OpenCode"};
        return {label: labels[snapshot.operation.phase] || "Preparing model", fraction: null, detail: ""};
    }
    readonly property int elapsedSeconds: {
        if (!loadingProgress) return -1;
        const started = snapshot.busy && snapshot.operation ? snapshot.operation.started_at * 1000 : runtime ? Date.parse(runtime.started_at) : NaN;
        return Number.isFinite(started) ? Math.max(0, Math.floor((clock - started) / 1000)) : -1;
    }
    readonly property string status: !connection || !connection.connected ? "Manager disconnected" : !fresh ? "Status stale"
        : snapshot.busy && snapshot.operation ? snapshot.operation.phase
        : external ? "External / read-only" : runtime ? runtime.state === "starting" ? "Starting" : runtime.state : "Stopped"
    readonly property string error: requestError || snapshot.error || (runtime ? runtime.error : "")
        || (snapshot.operation && ["failed", "interrupted"].includes(snapshot.operation.state)
            ? runtime && runtime.state === "starting" && snapshot.operation.state === "interrupted" ? "Startup continues after manager restart" : snapshot.operation.error : "")
    readonly property string clientStatus: snapshot.opencode.state === "configured" ? "OpenCode default saved: " + snapshot.opencode.model + ". Restart required."
        : snapshot.opencode.state === "error" ? "OpenCode configuration failed" : "OpenCode unchanged"

    function canConfigure(index) {
        const preset = presets[index];
        return fresh && !busy && !!preset && activeRuntimes.some(runtime => runtime.provider === preset.provider && runtime.models.length === 1 && runtime.models[0] === preset.model);
    }
    function request(action, index, confirmed) {
        if (!fresh || busy) return;
        const preset = presets[index];
        if (action !== "stop" && !preset) return;
        requestError = "";
        pendingRequest = String(++sequence);
        requestDeadline = Date.now() + 10000;
        connection.write(JSON.stringify({version: 1, id: pendingRequest, action: action, preset_id: preset ? preset.id : null, confirmed: confirmed === true}) + "\n");
        connection.flush();
    }
    function receive(data) {
        try {
            const message = JSON.parse(data);
            if (message.version !== 1) {
                requestError = "Unsupported model-manager protocol";
                receivedAt = 0;
                return;
            }
            if (message.type === "state") {
                snapshot = message;
                receivedAt = Date.now();
                clock = receivedAt;
            } else if (message.type === "reply" && String(message.id) === pendingRequest) {
                pendingRequest = "";
                if (!message.ok) requestError = message.error || "Request rejected";
            }
        } catch (_error) {
            requestError = "Invalid model-manager response";
            receivedAt = 0;
        }
    }
    Loader {
        id: socketLoader
        sourceComponent: Component {
            Socket {
                path: Quickshell.env("XDG_RUNTIME_DIR") + "/model-manager/control.sock"
                connected: true
                parser: SplitParser { onRead: data => manager.receive(data) }
                onConnectionStateChanged: {
                    if (!connected) {
                        manager.receivedAt = 0;
                        if (manager.pendingRequest !== "") manager.requestError = "Connection lost; operation outcome will be reconciled";
                        manager.pendingRequest = "";
                    }
                }
            }
        }
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            manager.clock = Date.now();
            if (!manager.connection || !manager.connection.connected) {
                socketLoader.active = false;
                socketLoader.active = true;
            }
            if (manager.pendingRequest !== "" && manager.clock > manager.requestDeadline) {
                manager.pendingRequest = "";
                manager.requestError = "Request acknowledgement timed out; check observed operation before retrying";
            }
        }
    }
}