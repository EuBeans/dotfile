import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    required property var gpu
    required property bool telemetryAvailable
    property bool reducedMotion: false
    property var metrics: []
    property var history: ({})
    property var processes: []
    readonly property var topProcesses: telemetryAvailable && gpu.id ? processes
        .filter(entry => entry.gpu === gpu.id)
        .sort((left, right) => {
            const leftMemory = Number.isFinite(left.memoryMiB) && left.memoryMiB >= 0 ? left.memoryMiB : -1;
            const rightMemory = Number.isFinite(right.memoryMiB) && right.memoryMiB >= 0 ? right.memoryMiB : -1;
            return rightMemory - leftMemory || Number(left.pid) - Number(right.pid);
        }).slice(0, 5) : []
    readonly property bool usageAvailable: telemetryAvailable && Number.isFinite(gpu.utilization)
    readonly property bool capacityAvailable: Number.isFinite(gpu.totalGiB) && gpu.totalGiB > 0
    readonly property bool memoryAvailable: telemetryAvailable && capacityAvailable && Number.isFinite(gpu.usedGiB)
    readonly property var details: [
        {label: "Memory type", value: gpu.memoryType},
        {label: "Driver", value: gpu.driver},
        {label: "PCI address", value: gpu.pciAddress},
        {label: "Core clock", value: telemetryAvailable ? gpu.coreClock : null},
        {label: "Fan", value: telemetryAvailable && Number.isFinite(gpu.fanSpeed) ? gpu.fanSpeed + "%" : null},
        {label: "Power limit", value: Number.isFinite(gpu.powerLimit) ? gpu.powerLimit + " W" : null}
    ].filter(entry => entry.value !== null && entry.value !== undefined && entry.value !== "")
    readonly property var historyGraphs: metrics.filter(metric => ["C", "W"].includes(metric.unit.trim())).map((metric, index) => {
        const current = panel.telemetryAvailable && Number.isFinite(metric.value);
        return {
            key: metric.key,
            title: metric.title.split(" / ").pop(),
            colorIndex: index + 2,
            series: [{
                key: metric.key, title: metric.title, unit: metric.unit, current: current,
                reading: current ? metric.value.toFixed(1) + metric.unit : "--",
                iconName: metric.unit.trim() === "C" ? "thermometer" : "zap",
                maximum: metric.maximum,
                samples: panel.history[metric.key] || []
            }]
        };
    })
    signal closeRequested()
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius
    topRightRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    bottomRightRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0

    ScrollView {
        id: scroll
        objectName: "gpuDetailsScroll"
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            width: scroll.availableWidth
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                Ui.Label {
                    objectName: "gpuDetailsName"
                    text: panel.gpu.name
                    font.family: Ui.Theme.displayFont
                    font.pixelSize: 18
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    wrapMode: Text.WrapAnywhere
                }
                Ui.ActionButton { objectName: "closeGpu"; iconName: "x"; description: "Close GPU details"; onClicked: panel.closeRequested() }
            }
            Ui.Label { text: "UTILIZATION"; color: Ui.Theme.muted; font.pixelSize: 11 }
            Ui.SegmentedMeter {
                objectName: "gpuDetailsUtilization"
                Layout.fillWidth: true
                value: panel.gpu.utilization / 100
                available: panel.usageAvailable
                label: panel.gpu.name + " utilization"
                reducedMotion: panel.reducedMotion
            }
            Ui.Label { objectName: "gpuDetailsUsage"; text: panel.usageAvailable ? panel.gpu.utilization + "%" : "Unavailable" }
            Ui.Label { text: "VRAM"; color: Ui.Theme.muted; font.pixelSize: 11 }
            Ui.SegmentedMeter {
                objectName: "gpuDetailsVram"
                Layout.fillWidth: true
                value: panel.gpu.totalGiB > 0 ? panel.gpu.usedGiB / panel.gpu.totalGiB : 0
                available: panel.memoryAvailable
                label: panel.gpu.name + " VRAM"
                reducedMotion: panel.reducedMotion
            }
            Ui.Label {
                objectName: "gpuDetailsMemory"
                text: (panel.memoryAvailable ? panel.gpu.usedGiB.toFixed(1) : "Unavailable") + (panel.capacityAvailable ? " / " + Number(panel.gpu.totalGiB.toFixed(1)) + " GiB" : "")
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            RowLayout {
                visible: panel.historyGraphs.length > 0
                Layout.fillWidth: true
                Ui.Label { text: "History"; color: Ui.Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
                Ui.Label { text: "2 min"; color: Ui.Theme.muted; font.pixelSize: 11 }
            }
            GridLayout {
                visible: panel.historyGraphs.length > 0
                Layout.fillWidth: true
                columns: scroll.availableWidth >= 360 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: panel.historyGraphs
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 220
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: graph.implicitHeight + 24
                        color: Ui.Theme.groupSurface
                        border.color: Ui.Theme.surfaceEdge
                        radius: 6
                        Ui.HistoryGraph {
                            id: graph
                            anchors.fill: parent
                            anchors.margins: 12
                            objectName: "gpuHistory" + parent.modelData.key
                            title: parent.modelData.title
                            series: parent.modelData.series
                            colorOffset: parent.modelData.colorIndex
                        }
                    }
                }
            }
            ColumnLayout {
                objectName: "gpuProcessList"
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    Ui.Label { objectName: "gpuProcessHeading"; text: "Compute processes"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WordWrap }
                    Ui.Label { text: "VRAM"; font.pixelSize: 10; color: Ui.Theme.muted }
                }
                Ui.Label {
                    objectName: "gpuProcessEmpty"
                    visible: panel.topProcesses.length === 0
                    text: panel.telemetryAvailable ? "No compute processes reported" : "Telemetry unavailable"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: Ui.Theme.muted
                }
                Repeater {
                    model: panel.topProcesses
                    RowLayout {
                        required property var modelData
                        required property int index
                        objectName: "gpuProcessRow" + index
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 8
                        Ui.Label { text: modelData.pid; font.pixelSize: 10; color: Ui.Theme.muted; Accessible.name: "Process ID " + modelData.pid }
                        Ui.Label {
                            objectName: "gpuProcessName" + index
                            text: String(modelData.name || "Unknown").trim().split(/\s+/)[0].split("/").pop()
                            Accessible.name: modelData.name || "Unknown process"
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            wrapMode: Text.WrapAnywhere
                            font.pixelSize: 11
                        }
                        Ui.Label {
                            objectName: "gpuProcessMemory" + index
                            text: !Number.isFinite(modelData.memoryMiB) || modelData.memoryMiB < 0 ? "N/A" : modelData.memoryMiB >= 1024 ? (modelData.memoryMiB / 1024).toFixed(1) + " GiB" : modelData.memoryMiB.toFixed(0) + " MiB"
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: 11
                        }
                    }
                }
            }
            ColumnLayout {
                objectName: "gpuDeviceDetails"
                visible: panel.details.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 12
                spacing: 8
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                Ui.Label {
                    objectName: "gpuInfoHeading"
                    text: "GPU info"
                    font.family: Ui.Theme.displayFont
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }
                Repeater {
                    model: panel.details
                    Ui.SettingRow {
                        required property var modelData
                        label: modelData.label
                        Ui.Label { text: modelData.value; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.WrapAnywhere; font.pixelSize: 11 }
                    }
                }
            }
        }
    }
}