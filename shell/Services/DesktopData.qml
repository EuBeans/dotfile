import QtQuick

QtObject {
    id: data
    property bool live: false
    property bool controlsEnabled: false
    property bool busy: false
    property string status: "Live services are unavailable in the native preview"
    property var devices: ({monitors:[],sinks:[],sources:[],streams:[],audio:null,drives:[],network:[],accessPoints:[],wifi:false,powerProfiles:[],powerProfile:"",batteries:[],host:"",kernel:"",cpu:""})
    property var snapshot: ({gpus:[],processes:[],memory:{},network:[],load:[]})
    property var previous: null
    property var history: ({})
    property double sampledAt: 0
    property double clock: Date.now()
    readonly property bool fresh: sampledAt > 0 && clock - sampledAt < 8000
    property var metrics: []
    property var mediaPlayers: []
    property var notifications: []
    property var weather: null
    property string weatherStatus: "Location not configured"
    property string latitude: ""
    property string longitude: ""
    property bool displayPending: false
    property int displayCountdown: 0
    signal commandRequested(var command)
    signal weatherRequested(string latitude, string longitude)
    signal mediaRequested(int index, string action)
    signal displayRequested(var monitor, string mode, real scale, int transform)
    signal displayConfirmed()
    signal displayReverted()
    property Timer freshness: Timer { interval: 1000; running: true; repeat: true; onTriggered: data.clock = Date.now() }
    function request(command) {
        if (!controlsEnabled || busy) return;
        commandRequested(command);
    }
    function value(value, suffix, digits) {
        return typeof value === "number" && Number.isFinite(value) ? value.toFixed(digits === undefined ? 0 : digits) + (suffix || "") : "Unavailable";
    }
    function bytes(value) {
        if (typeof value !== "number" || !Number.isFinite(value)) return "Unavailable";
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        const level = Math.max(0, Math.min(4, Math.floor(Math.log(Math.max(1, value)) / Math.log(1024))));
        return (value / Math.pow(1024, level)).toFixed(level ? 1 : 0) + " " + units[level];
    }
    function ingest(sample, timestamp) {
        const now = timestamp || Date.now();
        const elapsed = previous ? (now - sampledAt) / 1000 : 0;
        const total = previous ? sample.cpu.total - previous.cpu.total : 0;
        const idle = previous ? sample.cpu.idle - previous.cpu.idle : 0;
        const cpu = elapsed > 0 && elapsed < 8 && total > 0 && idle >= 0 && idle <= total ? 100 * (1 - idle / total) : null;
        const memory = sample.memory;
        const next = [
            {key:"cpu", title:"CPU usage", value:cpu, unit:"%", maximum:100},
            {key:"cpuTemp", title:"CPU temperature", value:sample.cpu.temperature, unit:" C", maximum:110},
            {key:"memory", title:"Memory", value:memory.MemTotal > 0 ? 100 * (memory.MemTotal-memory.MemAvailable)/memory.MemTotal : null, unit:"%", maximum:100},
            {key:"swap", title:"Swap", value:memory.SwapTotal > 0 ? 100 * (memory.SwapTotal-memory.SwapFree)/memory.SwapTotal : 0, unit:"%", maximum:100}
        ];
        for (const gpu of sample.gpus) {
            next.push({key:gpu.id+"usage",title:gpu.name+" / Usage",value:gpu.utilization,unit:"%",maximum:100});
            next.push({key:gpu.id+"vram",title:gpu.name+" / VRAM",value:gpu.usedMiB,unit:" MiB",maximum:gpu.totalMiB || 1});
            next.push({key:gpu.id+"temp",title:gpu.name+" / Temperature",value:gpu.temperature,unit:" C",maximum:110});
            next.push({key:gpu.id+"power",title:gpu.name+" / Power",value:gpu.power,unit:" W",maximum:Math.max(100,gpu.power || 0)});
        }
        if (!sample.gpus.length) {
            next.push({key:"gpu",title:"GPU usage",value:null,unit:"%",maximum:100});
            next.push({key:"gpuVram",title:"GPU VRAM",value:null,unit:" MiB",maximum:1});
            next.push({key:"gpuTemp",title:"GPU temperature",value:null,unit:" C",maximum:110});
            next.push({key:"gpuPower",title:"GPU power",value:null,unit:" W",maximum:1});
        }
        let download = 0, upload = 0, rateAvailable = elapsed > 0 && elapsed < 8 && sample.network.length > 0;
        for (const device of sample.network) {
            const old = previous ? previous.network.find(entry => entry.name === device.name) : null;
            if (!old || device.rx < old.rx || device.tx < old.tx) { rateAvailable = false; continue; }
            download += (device.rx-old.rx)/elapsed;
            upload += (device.tx-old.tx)/elapsed;
        }
        next.push({key:"download",title:"Network download",value:rateAvailable ? download/1024 : null,unit:" KiB/s",maximum:1});
        next.push({key:"upload",title:"Network upload",value:rateAvailable ? upload/1024 : null,unit:" KiB/s",maximum:1});
        const histories = {};
        for (const metric of next) {
            histories[metric.key] = (history[metric.key] || []).slice(-59).concat([typeof metric.value === "number" && Number.isFinite(metric.value) ? metric.value : null]);
            metric.maximum = Math.max(metric.maximum, ...histories[metric.key].filter(entry => entry !== null));
        }
        previous = sample;
        snapshot = sample;
        history = histories;
        metrics = next;
        sampledAt = now;
        clock = now;
    }
    function configureWeather(latitude, longitude) {
        const north = Number(latitude), east = Number(longitude);
        if (!latitude.trim() || !longitude.trim() || !Number.isFinite(north) || !Number.isFinite(east) || Math.abs(north) > 90 || Math.abs(east) > 180) {
            weatherStatus = "Enter valid latitude (-90 to 90) and longitude (-180 to 180)";
            return;
        }
        data.latitude = latitude;
        data.longitude = longitude;
        weatherStatus = "Location set for this session / Weather provider not connected";
        weatherRequested(latitude, longitude);
    }
    function remember(title, body, app, timestamp) {
        notifications = [{id:Date.now()+"-"+notifications.length,title:title,body:body,app:app || "",time:timestamp || Date.now()}].concat(notifications).slice(0,200);
    }
    function dayGroup(timestamp) {
        const today = new Date(clock); today.setHours(0,0,0,0);
        const yesterday = new Date(today); yesterday.setDate(yesterday.getDate()-1);
        return timestamp >= today.getTime() ? "Today" : timestamp >= yesterday.getTime() ? "Yesterday" : "Older";
    }
}