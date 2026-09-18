import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    required property var service
    property string pendingAction: ""
    property int candidateIndex: 0
    signal startRequested(int modelIndex)
    signal stopRequested()
    signal switchRequested(int modelIndex)
    signal closeRequested()
    implicitWidth: 460
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    onVisibleChanged: pendingAction = ""

    ScrollView {
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            width: parent.width
            spacing: 22
            RowLayout {
                Layout.fillWidth: true
                Ui.Label { text: "LOCAL AI"; font.family: Ui.Theme.displayFont; font.pixelSize: 20; Layout.fillWidth: true }
                Ui.ActionButton { iconName: "x"; description: "Close local AI"; onClicked: panel.closeRequested() }
            }
            RowLayout {
                Ui.Label { text: "vLLM"; font.pixelSize: 16; Layout.fillWidth: true }
                Ui.Label { objectName: "aiStatus"; text: panel.service.aiStatus; color: Ui.Theme.muted }
            }
            Ui.Label { text: "LOADED MODEL"; color: Ui.Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
            Ui.Label {
                objectName: "loadedModel"
                text: panel.service.loadedModelIndex >= 0 ? panel.service.models[panel.service.loadedModelIndex] : "No model loaded"
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideNone
                Layout.fillWidth: true
            }
            Ui.Dropdown {
                id: modelPicker
                objectName: "modelPicker"
                model: panel.service.models
                currentIndex: panel.candidateIndex
                enabled: !panel.service.aiBusy && panel.pendingAction === ""
                onActivated: panel.candidateIndex = currentIndex
                Accessible.name: "Model to load"
            }
            RowLayout {
                Ui.ActionButton {
                    objectName: "aiStart"
                    iconName: "play"
                    description: "Start vLLM with selected model"
                    enabled: !panel.service.aiBusy && panel.service.loadedModelIndex < 0 && panel.pendingAction === ""
                    onClicked: panel.startRequested(panel.candidateIndex)
                }
                Ui.ActionButton {
                    objectName: "aiStop"
                    iconName: "square"
                    description: "Stop vLLM"
                    enabled: !panel.service.aiBusy && panel.service.loadedModelIndex >= 0 && panel.pendingAction === ""
                    onClicked: panel.pendingAction = "stop"
                }
                Ui.ActionButton {
                    objectName: "aiSwitch"
                    iconName: "refresh-cw"
                    description: "Switch model"
                    enabled: !panel.service.aiBusy && panel.service.loadedModelIndex >= 0 && panel.candidateIndex !== panel.service.loadedModelIndex && panel.pendingAction === ""
                    onClicked: panel.pendingAction = "switch"
                }
                Item { Layout.fillWidth: true }
                Ui.Label { text: panel.service.aiBusy ? "Please wait" : panel.service.runningRequests + " active"; color: Ui.Theme.muted }
            }
            ColumnLayout {
                visible: panel.pendingAction !== ""
                Layout.fillWidth: true
                spacing: 12
                Ui.Label {
                    text: panel.pendingAction === "stop" ? "Stop vLLM? Active requests may be interrupted." : "Restart with the selected model? Active requests may be interrupted."
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    Layout.fillWidth: true
                }
                RowLayout {
                    Ui.ActionButton {
                        objectName: "aiConfirm"
                        text: "Confirm"
                        onClicked: {
                            if (panel.pendingAction === "stop") panel.stopRequested();
                            else panel.switchRequested(panel.candidateIndex);
                            panel.pendingAction = "";
                        }
                    }
                    Ui.ActionButton { objectName: "aiCancel"; text: "Cancel"; onClicked: panel.pendingAction = "" }
                }
            }
            Ui.Label {
                visible: panel.service.aiError !== ""
                text: panel.service.aiError
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
            RowLayout {
                Ui.Label { text: "OUTPUT / SERVER"; color: Ui.Theme.muted; Layout.fillWidth: true; font.pixelSize: 11 }
                Ui.Label {
                    objectName: "tokenRate"
                    text: panel.service.tokensPerSecond >= 0 ? panel.service.tokensPerSecond.toFixed(1) + " tok/s" : "N/A"
                    font.pixelSize: 20
                }
            }
            Ui.Label { text: "Whole-device GPU telemetry"; color: Ui.Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
            Repeater {
                model: panel.service.gpus.length
                ColumnLayout {
                    required property int index
                    readonly property var gpu: panel.service.gpus[index]
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: Ui.Theme.groupSurface
                        radius: 4
                        Ui.Label { text: gpu.name; font.pixelSize: 16; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    RowLayout {
                        Ui.Label { text: "[ VRAM ]"; font.family: Ui.Theme.displayFont; Layout.fillWidth: true }
                        Ui.Label { text: panel.service.telemetryAvailable ? gpu.usedGiB.toFixed(1) + " / " + gpu.totalGiB.toFixed(1) + " GiB" : "N/A" }
                    }
                    Ui.SegmentedMeter {
                        objectName: "vramMeter" + index
                        Layout.fillWidth: true
                        label: gpu.name + " VRAM"
                        value: gpu.usedGiB / gpu.totalGiB
                        reducedMotion: panel.service.reducedMotion
                        available: panel.service.telemetryAvailable
                    }
                    RowLayout {
                        Ui.Label { text: "[ GPU ]"; font.family: Ui.Theme.displayFont; Layout.fillWidth: true }
                        Ui.Label { text: panel.service.telemetryAvailable ? gpu.utilization + "%" : "N/A" }
                    }
                    Ui.SegmentedMeter {
                        objectName: "gpuMeter" + index
                        Layout.fillWidth: true
                        label: gpu.name + " utilization"
                        value: gpu.utilization / 100
                        reducedMotion: panel.service.reducedMotion
                        available: panel.service.telemetryAvailable
                    }
                }
            }
            Item { Layout.preferredHeight: 8 }
        }
    }
}