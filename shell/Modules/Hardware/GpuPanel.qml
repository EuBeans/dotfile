import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    required property var gpu
    required property bool telemetryAvailable
    property bool reducedMotion: false
    signal closeRequested()
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius
    topRightRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    bottomRightRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0

    ScrollView {
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: parent.width
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                Ui.Label {
                    objectName: "gpuDetailsName"
                    text: panel.gpu.name
                    font.family: Ui.Theme.displayFont
                    font.pixelSize: 20
                    Layout.fillWidth: true
                }
                Ui.ActionButton { objectName: "closeGpu"; iconName: "x"; description: "Close GPU details"; onClicked: panel.closeRequested() }
            }
            Ui.Label { text: "UTILIZATION"; color: Ui.Theme.muted; font.pixelSize: 11 }
            Ui.SegmentedMeter {
                objectName: "gpuDetailsUtilization"
                Layout.fillWidth: true
                value: panel.gpu.utilization / 100
                available: panel.telemetryAvailable
                label: panel.gpu.name + " utilization"
                reducedMotion: panel.reducedMotion
            }
            Ui.Label { objectName: "gpuDetailsUsage"; text: panel.telemetryAvailable ? panel.gpu.utilization + "%" : "Unavailable" }
            Ui.Label { text: "VRAM"; color: Ui.Theme.muted; font.pixelSize: 11 }
            Ui.SegmentedMeter {
                objectName: "gpuDetailsVram"
                Layout.fillWidth: true
                value: panel.gpu.totalGiB > 0 ? panel.gpu.usedGiB / panel.gpu.totalGiB : 0
                available: panel.telemetryAvailable
                label: panel.gpu.name + " VRAM"
                reducedMotion: panel.reducedMotion
            }
            Ui.Label {
                objectName: "gpuDetailsMemory"
                text: panel.telemetryAvailable ? panel.gpu.usedGiB.toFixed(1) + " / " + panel.gpu.totalGiB + " GiB" : "Unavailable / " + panel.gpu.totalGiB + " GiB"
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
            Repeater {
                model: [
                    {label: "Memory capacity", value: panel.gpu.totalGiB + " GiB"},
                    {label: "Memory type", value: panel.gpu.memoryType},
                    {label: "Driver", value: panel.gpu.driver},
                    {label: "PCI address", value: panel.gpu.pciAddress},
                    {label: "Temperature", value: panel.telemetryAvailable ? panel.gpu.temperature : null},
                    {label: "Power draw", value: panel.telemetryAvailable ? panel.gpu.powerDraw : null},
                    {label: "Core clock", value: panel.telemetryAvailable ? panel.gpu.coreClock : null}
                ]
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Ui.Label { text: modelData.label; color: Ui.Theme.muted; Layout.fillWidth: true }
                    Ui.Label { text: modelData.value ?? "Unavailable" }
                }
            }
        }
    }
}