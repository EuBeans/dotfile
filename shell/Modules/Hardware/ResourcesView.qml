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
        const groups = [{key:"cpu",title:"CPU",series:[]}, {key:"memory",title:"Memory",series:[]}, {key:"gpu",title:"GPU",series:[]}, {key:"network",title:"Network",series:[]}];
        const networkMaximum = Math.max(1, ...metrics.filter(metric => ["download","upload"].includes(metric.key)).map(metric => metric.maximum));
        for (const metric of metrics) {
            const groupIndex = ["cpu","cpuTemp"].includes(metric.key) ? 0 : ["memory","swap"].includes(metric.key) ? 1 : ["download","upload"].includes(metric.key) ? 3 : 2;
            const current = data.fresh && typeof metric.value === "number" && Number.isFinite(metric.value);
            groups[groupIndex].series.push({
                key:metric.key, title:metric.title, unit:metric.unit, current:current,
                iconName:({cpu:"cpu",memory:"memory-stick",swap:"refresh-cw",download:"download",upload:"chevron-right"})[metric.key]
                    || ({"%":"activity","MiB":"memory-stick","C":"thermometer","W":"zap"})[metric.unit.trim()] || "activity",
                reading:current ? data.value(metric.value,metric.unit,1) : "--",
                samples:data.history[metric.key] || [], maximum:groupIndex === 3 ? networkMaximum : metric.maximum
            });
        }
        return groups;
    }
    ColumnLayout {
        width: page.availableWidth
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Ui.Label { text: page.data.live ? (page.data.fresh ? "LIVE / 2s samples" : "STALE / Waiting for samples") : "LIVE SERVICES DISCONNECTED"; color: Ui.Theme.muted; font.pixelSize: 10; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Ui.Label { text: "120s history"; font.pixelSize: 10; color: Ui.Theme.muted }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            columns: page.availableWidth >= 480 ? 2 : 1
            columnSpacing: 20
            rowSpacing: 20
            Repeater {
                model: page.graphGroups
                Ui.HistoryGraph {
                    required property var modelData
                    objectName: "resourceGraph" + modelData.key
                    Layout.preferredWidth: 240
                    Layout.alignment: Qt.AlignTop
                    title: modelData.title
                    series: modelData.series
                }
            }
        }
        Ui.Label { text: "SYSTEM INFORMATION"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true; Layout.topMargin: 16 }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
        Repeater {
            model: [
                {label:"Host",value:page.data.devices.host || "Unavailable"},
                {label:"Kernel",value:page.data.devices.kernel || "Unavailable"},
                {label:"CPU",value:page.data.devices.cpu || "Unavailable"},
                {label:"Uptime",value:page.data.fresh ? page.data.value(page.data.snapshot.uptime/3600," hours",1) : "Unavailable"}
            ]
            Ui.SettingRow { required property var modelData; label: modelData.label; rowSpacing: 4; Ui.Label { text: modelData.value; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 } }
        }
        Ui.Label { text: "RESOURCES"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true; Layout.topMargin: 16 }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
        Repeater {
            model: [
                {label:"Load / 1, 5, 15 min",value:page.data.fresh ? page.data.snapshot.load.map(value => value.toFixed(2)).join(" / ") : "Unavailable"},
                {label:"RAM used / total",value:page.data.fresh ? page.data.bytes(page.data.snapshot.memory.MemTotal-page.data.snapshot.memory.MemAvailable)+" / "+page.data.bytes(page.data.snapshot.memory.MemTotal) : "Unavailable"},
                {label:"Swap used / total",value:page.data.fresh ? page.data.bytes(page.data.snapshot.memory.SwapTotal-page.data.snapshot.memory.SwapFree)+" / "+page.data.bytes(page.data.snapshot.memory.SwapTotal) : "Unavailable"}
            ]
            Ui.SettingRow { required property var modelData; label: modelData.label; rowSpacing: 4; Ui.Label { text: modelData.value; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 } }
        }
        Ui.Label { text: "NVIDIA compute processes"; Layout.fillWidth: true; Layout.topMargin: 16; wrapMode: Text.WordWrap; font.pixelSize: 12 }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
        Ui.Label { visible: !page.data.snapshot.processes.length; text: "No compute processes reported"; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11 }
        Repeater {
            model: page.data.snapshot.processes
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 4
                    Ui.Label { text: modelData.name; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 }
                    Ui.Label { text: "PID " + modelData.pid; color: Ui.Theme.muted; font.pixelSize: 10 }
                }
                Ui.Label { text: page.data.value(modelData.memoryMiB," MiB"); Layout.preferredWidth: 88; Layout.minimumWidth: 0; Layout.alignment: Qt.AlignTop; horizontalAlignment: Text.AlignRight; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 }
            }
        }
        Ui.Label { text: "Drives and partitions"; Layout.fillWidth: true; Layout.topMargin: 16; font.pixelSize: 12 }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
        Ui.Label { visible: !page.data.devices.drives.length; text: "Storage unavailable"; Layout.fillWidth: true }
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
                    model: [modelData].concat(modelData.children || [])
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 4
                        Ui.Label { text: modelData.name+" / "+(modelData.fstype || modelData.type); Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 }
                        Ui.Label { text: (modelData.mountpoints || []).filter(Boolean).join(", "); visible: text.length > 0; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 10; color: Ui.Theme.muted }
                        Ui.Label { text: (modelData["fsuse%"] || "--")+" used / "+page.data.bytes(modelData.fsavail)+" free"; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 10; color: Ui.Theme.muted }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            }
        }
    }
}