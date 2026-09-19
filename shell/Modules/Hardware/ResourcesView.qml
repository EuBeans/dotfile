import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

ScrollView {
    id: page
    required property var data
    objectName: "homeResourcesPage"
    contentWidth: availableWidth
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    readonly property var emptyMetrics: [
        {key:"cpu",title:"CPU usage",unit:"%",maximum:100}, {key:"cpuTemp",title:"CPU temperature",unit:" C",maximum:110},
        {key:"memory",title:"Memory",unit:"%",maximum:100}, {key:"swap",title:"Swap",unit:"%",maximum:100},
        {key:"gpu",title:"GPU usage",unit:"%",maximum:100}, {key:"gpuVram",title:"GPU VRAM",unit:" MiB",maximum:1},
        {key:"gpuTemp",title:"GPU temperature",unit:" C",maximum:110}, {key:"gpuPower",title:"GPU power",unit:" W",maximum:1},
        {key:"download",title:"Network download",unit:" KiB/s",maximum:1}, {key:"upload",title:"Network upload",unit:" KiB/s",maximum:1}
    ]
    readonly property var graphGroups: {
        const metrics = data.metrics.length ? data.metrics : emptyMetrics;
        const groups = [{key:"cpu",title:"CPU",series:[]}, {key:"memory",title:"Memory",series:[]}];
        for (const metric of metrics) {
            if (metric.gpuId !== undefined && !groups.some(group => group.key === "gpu:" + metric.gpuId))
                groups.push({key:"gpu:" + metric.gpuId,title:(metric.gpuName || "GPU " + metric.gpuId).replace(/^(?:NVIDIA\s+)?GeForce\s+|^NVIDIA\s+/i, ""),series:[]});
        }
        if (groups.length === 2) groups.push({key:"gpu",title:"GPU",series:[]});
        groups.push({key:"network",title:"Network",series:[]});
        const networkMaximum = Math.max(1, ...metrics.filter(metric => ["download","upload"].includes(metric.key)).map(metric => metric.maximum));
        for (const metric of metrics) {
            const groupKey = ["cpu","cpuTemp"].includes(metric.key) ? "cpu" : ["memory","swap"].includes(metric.key) ? "memory" : ["download","upload"].includes(metric.key) ? "network" : metric.gpuId !== undefined ? "gpu:" + metric.gpuId : "gpu";
            const group = groups.find(entry => entry.key === groupKey);
            if (!group) continue;
            const current = data.fresh && typeof metric.value === "number" && Number.isFinite(metric.value);
            group.series.push({
                key:metric.key, title:metric.title, unit:metric.unit, current:current,
                iconName:({cpu:"cpu",memory:"memory-stick",swap:"refresh-cw",download:"download",upload:"chevron-right"})[metric.key]
                    || ({"%":"activity","MiB":"memory-stick","C":"thermometer","W":"zap"})[metric.unit.trim()] || "activity",
                reading:current ? data.value(metric.value,metric.unit,1) : "--",
                samples:data.history[metric.key] || [], maximum:groupKey === "network" ? networkMaximum : metric.maximum
            });
        }
        return groups;
    }
    ColumnLayout {
        width: page.availableWidth
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: page.data.live && page.data.fresh ? Ui.Theme.chartColor(2) : Ui.Theme.muted }
            Ui.Label { text: page.data.live ? (page.data.fresh ? "Live" : "Stale") : "Disconnected"; color: Ui.Theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
            Ui.Label { text: "2 min"; font.pixelSize: 10; color: Ui.Theme.muted }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            columns: page.availableWidth >= 480 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 12
            Repeater {
                model: page.graphGroups
                Rectangle {
                    required property var modelData
                    objectName: "resourceFrame" + modelData.key
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 240
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: chart.implicitHeight + 24
                    color: Ui.Theme.groupSurface
                    border.color: Ui.Theme.surfaceEdge
                    border.width: 1
                    radius: 6
                    Ui.HistoryGraph {
                        id: chart
                        anchors.fill: parent
                        anchors.margins: 12
                        objectName: "resourceGraph" + parent.modelData.key
                        title: parent.modelData.title
                        series: parent.modelData.series
                    }
                }
            }
        }
        ColumnLayout {
            objectName: "systemDetails"
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8
            Repeater {
                model: [
                    {label:"Host",value:page.data.devices.host || "Unavailable"},
                    {label:"Kernel",value:page.data.devices.kernel || "Unavailable"},
                    {label:"CPU",value:page.data.devices.cpu || "Unavailable"},
                    {label:"Uptime",value:page.data.fresh ? page.data.value(page.data.snapshot.uptime/3600," hours",1) : "Unavailable"},
                    {label:"Load / 1, 5, 15 min",value:page.data.fresh ? page.data.snapshot.load.map(value => value.toFixed(2)).join(" / ") : "Unavailable"},
                    {label:"RAM",value:page.data.fresh ? page.data.bytes(page.data.snapshot.memory.MemTotal-page.data.snapshot.memory.MemAvailable)+" / "+page.data.bytes(page.data.snapshot.memory.MemTotal) : "Unavailable"},
                    {label:"Swap",value:page.data.fresh ? page.data.bytes(page.data.snapshot.memory.SwapTotal-page.data.snapshot.memory.SwapFree)+" / "+page.data.bytes(page.data.snapshot.memory.SwapTotal) : "Unavailable"}
                ]
                Ui.SettingRow { required property var modelData; label: modelData.label; rowSpacing: 4; Ui.Label { text: modelData.value; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 } }
            }
            Ui.Label { text: "Compute processes"; Layout.fillWidth: true; Layout.topMargin: 12; font.pixelSize: 12 }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            Ui.Label { visible: !page.data.snapshot.processes.length; text: "None"; Layout.fillWidth: true; font.pixelSize: 11; color: Ui.Theme.muted }
            Repeater {
                model: page.data.snapshot.processes
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 8
                    Ui.Label { text: modelData.pid; color: Ui.Theme.muted; font.pixelSize: 10; Accessible.name: "Process ID " + modelData.pid }
                    Ui.Label { text: modelData.name.split("/").pop(); Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 11; Accessible.name: modelData.name }
                    Ui.Label { text: page.data.value(modelData.memoryMiB," MiB"); Layout.preferredWidth: 88; Layout.minimumWidth: 0; horizontalAlignment: Text.AlignRight; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 }
                }
            }
            Ui.Label { text: "Storage"; Layout.fillWidth: true; Layout.topMargin: 12; font.pixelSize: 12 }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            Ui.Label { visible: !page.data.devices.drives.length; text: "Unavailable"; Layout.fillWidth: true; color: Ui.Theme.muted }
            Repeater {
                model: page.data.devices.drives
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.Label { text: modelData.name; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 12 }
                        Ui.Label { text: page.data.bytes(modelData.size); font.pixelSize: 11 }
                    }
                    Repeater {
                        model: modelData.children && modelData.children.length ? modelData.children : [modelData]
                        ColumnLayout {
                            id: partition
                            required property var modelData
                            readonly property real usedPercent: parseFloat(modelData["fsuse%"])
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Ui.Label { text: (partition.modelData.mountpoints || []).filter(Boolean).join(", ") || partition.modelData.name; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 }
                                Ui.Label { text: Number.isFinite(partition.usedPercent) ? partition.usedPercent + "%" : "--"; color: Ui.Theme.muted; font.pixelSize: 11 }
                            }
                            ProgressBar {
                                id: usageMeter
                                objectName: "storageUsage" + partition.modelData.name
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                from: 0; to: 100
                                value: Number.isFinite(partition.usedPercent) ? Math.max(0, Math.min(100, partition.usedPercent)) : 0
                                Accessible.name: partition.modelData.name + " storage usage"
                                background: Rectangle { radius: 2; color: Ui.Theme.line }
                                contentItem: Item { Rectangle { width: parent.width * usageMeter.visualPosition; height: parent.height; radius: 2; color: Ui.Theme.chartColor(0); visible: Number.isFinite(partition.usedPercent) } }
                            }
                            Ui.Label { text: page.data.bytes(partition.modelData.fsavail) + " free"; Layout.fillWidth: true; color: Ui.Theme.muted; font.pixelSize: 10 }
                        }
                    }
                }
            }
        }
    }
}