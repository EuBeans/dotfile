import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    required property var service
    property bool actionsEnabled: true
    property string pendingAction: ""
    property int candidateIndex: managed && manager ? manager.defaultModelIndex : 0
    property bool candidateChosen: false
    property bool settingsOpen: false
    readonly property bool managed: service.aiManaged === true
    readonly property var manager: managed ? service.modelManager : null
    property var loadingProgress: managed ? manager.loadingProgress : service.aiBusy ? {label: service.aiStatus, fraction: null, detail: ""} : null
    readonly property int loadingElapsed: managed ? manager.elapsedSeconds : -1
    signal startRequested(int modelIndex)
    signal stopRequested()
    signal switchRequested(int modelIndex)
    signal adoptRequested(int modelIndex)
    signal configureRequested(int modelIndex)
    signal defaultRequested(int modelIndex)
    signal closeRequested()
    implicitWidth: 460
    implicitHeight: content.implicitHeight + 32
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    onVisibleChanged: {
        pendingAction = "";
        if (visible && managed) {
            candidateChosen = false;
            candidateIndex = manager.defaultModelIndex;
        }
    }
    Connections {
        target: panel.manager
        function onDefaultModelIndexChanged() {
            if (!panel.candidateChosen) panel.candidateIndex = panel.manager.defaultModelIndex;
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: availableWidth
        clip: true
        ColumnLayout {
            id: content
            objectName: "aiContent"
            width: parent.width
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Ui.Label { text: "LOCAL AI"; font.family: Ui.Theme.displayFont; font.pixelSize: 16; Layout.fillWidth: true }
                Ui.ActionButton {
                    objectName: "aiSettings"
                    iconName: "settings"
                    description: "Model settings"
                    checkable: true
                    checked: panel.settingsOpen
                    onClicked: panel.settingsOpen = !panel.settingsOpen
                    Ui.Hint {}
                }
                Ui.ActionButton { iconName: "x"; description: "Close local AI"; onClicked: panel.closeRequested() }
            }
            RowLayout {
                Layout.fillWidth: true
                Ui.Label { text: panel.managed ? panel.service.runtimeLabel : "vLLM"; color: Ui.Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
                Ui.Label { objectName: "aiStatus"; text: panel.service.aiStatus; color: Ui.Theme.muted; Layout.maximumWidth: 220; wrapMode: Text.WordWrap }
            }
            Ui.Label {
                objectName: "loadedModel"
                text: panel.managed ? panel.service.loadedModelName : panel.service.loadedModelIndex >= 0 ? panel.service.models[panel.service.loadedModelIndex] : "No model loaded"
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideNone
                font.pixelSize: 14
                Layout.fillWidth: true
            }
            ColumnLayout {
                visible: !!panel.loadingProgress
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Ui.Label {
                        objectName: "aiLoadingStage"
                        text: panel.loadingProgress ? panel.loadingProgress.label : ""
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                    Ui.Label {
                        objectName: "aiLoadingPercent"
                        text: panel.loadingProgress && Number.isFinite(panel.loadingProgress.fraction) ? Math.round(panel.loadingProgress.fraction * 100) + "%" : ""
                        color: Ui.Theme.muted
                    }
                }
                ProgressBar {
                    id: loadingBar
                    objectName: "aiLoadingProgress"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    padding: 0
                    from: 0
                    to: 1
                    value: panel.loadingProgress && Number.isFinite(panel.loadingProgress.fraction) ? panel.loadingProgress.fraction : 0
                    indeterminate: !panel.loadingProgress || !Number.isFinite(panel.loadingProgress.fraction)
                    Accessible.name: panel.loadingProgress ? panel.loadingProgress.label : "Model loading"
                    background: Rectangle { color: Ui.Theme.groupSurface; border.color: Ui.Theme.line }
                    contentItem: Item {
                        clip: true
                        Rectangle {
                            id: loadingFill
                            height: parent.height
                            width: loadingBar.indeterminate ? parent.width / 4 : parent.width * loadingBar.position
                            color: Ui.Theme.accent
                            SequentialAnimation on x {
                                objectName: "aiLoadingSweep"
                                running: loadingBar.visible && loadingBar.indeterminate && !panel.service.reducedMotion
                                loops: Animation.Infinite
                                onStopped: loadingFill.x = 0
                                NumberAnimation { from: 0; to: loadingFill.parent.width - loadingFill.width; duration: 1100 }
                                NumberAnimation { from: loadingFill.parent.width - loadingFill.width; to: 0; duration: 1100 }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Ui.Label {
                        text: panel.loadingProgress ? panel.loadingProgress.detail || "" : ""
                        color: Ui.Theme.muted
                        Layout.fillWidth: true
                    }
                    Ui.Label {
                        text: panel.loadingElapsed < 0 ? "" : Math.floor(panel.loadingElapsed / 60) + "m " + (panel.loadingElapsed % 60) + "s elapsed"
                        color: Ui.Theme.muted
                    }
                }
            }
            Ui.Dropdown {
                id: modelPicker
                objectName: "modelPicker"
                model: panel.service.models
                Layout.fillWidth: true
                Layout.maximumWidth: content.width
                currentIndex: panel.candidateIndex
                enabled: panel.actionsEnabled && !panel.service.aiBusy && panel.pendingAction === ""
                onActivated: {
                    panel.candidateChosen = true;
                    panel.candidateIndex = currentIndex;
                }
                Accessible.name: "Model to load"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Ui.ActionButton {
                    objectName: "aiStart"
                    iconName: "play"
                    description: "Start selected model and configure OpenCode"
                    enabled: panel.actionsEnabled && !panel.service.aiBusy && panel.service.models.length > 0 && (panel.managed ? panel.manager.canStart : panel.service.loadedModelIndex < 0) && panel.pendingAction === ""
                    onClicked: panel.startRequested(panel.candidateIndex)
                    Ui.Hint {}
                }
                Ui.ActionButton {
                    objectName: "aiStop"
                    iconName: "square"
                    description: "Stop runtime"
                    enabled: panel.actionsEnabled && !panel.service.aiBusy && (panel.managed ? panel.manager.canStop : panel.service.loadedModelIndex >= 0) && panel.pendingAction === ""
                    onClicked: panel.pendingAction = "stop"
                    Ui.Hint {}
                }
                Ui.ActionButton {
                    objectName: "aiSwitch"
                    iconName: "refresh-cw"
                    description: panel.candidateIndex === panel.service.loadedModelIndex ? "Restart selected model" : "Switch model and configure OpenCode"
                    enabled: panel.actionsEnabled && !panel.service.aiBusy && panel.candidateIndex >= 0 && (panel.managed ? panel.manager.canSwitch : panel.service.loadedModelIndex >= 0) && panel.pendingAction === ""
                    onClicked: panel.pendingAction = "switch"
                    Ui.Hint {}
                }
                Ui.ActionButton {
                    objectName: "aiAdopt"
                    iconName: "pin"
                    description: "Adopt runtime for lifecycle control"
                    visible: panel.managed && panel.manager.external
                    enabled: panel.actionsEnabled && panel.manager && panel.manager.canAdopt && panel.manager.canConfigure(panel.candidateIndex) && panel.pendingAction === ""
                    onClicked: panel.pendingAction = "adopt"
                    Ui.Hint {}
                }
                Item { Layout.fillWidth: true }
                Ui.Label { text: panel.service.runningRequests >= 0 ? panel.service.runningRequests + " active" : ""; color: Ui.Theme.muted }
            }
            ColumnLayout {
                visible: panel.pendingAction !== ""
                Layout.fillWidth: true
                spacing: 12
                Ui.Label {
                    text: panel.pendingAction === "stop" ? "Stop model? Active requests will be interrupted."
                        : panel.pendingAction === "adopt" ? "Allow this manager to stop and replace the running model?"
                        : "Restart with " + (panel.service.models[panel.candidateIndex] || "selected model") + "? Active requests will be interrupted."
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    Layout.fillWidth: true
                }
                RowLayout {
                    Ui.ActionButton {
                        objectName: "aiConfirm"
                        text: "Confirm"
                        enabled: panel.actionsEnabled && !panel.service.aiBusy
                        onClicked: {
                            if (panel.pendingAction === "stop") panel.stopRequested();
                            else if (panel.pendingAction === "adopt") panel.adoptRequested(panel.candidateIndex);
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
            StackLayout {
                Layout.fillWidth: true
                currentIndex: panel.settingsOpen ? 0 : 1
                ColumnLayout {
                    objectName: "aiSettingsSection"
                    Layout.alignment: Qt.AlignTop
                    Layout.fillHeight: false
                    spacing: 8
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
                    Ui.Label { text: panel.managed ? "Default for " + panel.manager.profileName : "Default model"; color: Ui.Theme.muted; font.pixelSize: 11 }
                    Ui.Dropdown {
                        objectName: "aiDefaultModel"
                        Layout.fillWidth: true
                        Layout.maximumWidth: content.width
                        model: ["Last loaded"].concat(panel.service.models)
                        currentIndex: panel.managed ? panel.manager.presets.findIndex(preset => preset.id === panel.manager.profileDefaults[panel.manager.profileName]) + 1 : 0
                        enabled: panel.managed
                        Accessible.name: "Default model for current profile"
                        onActivated: panel.defaultRequested(currentIndex - 1)
                    }
                    Ui.Label {
                        objectName: "aiClientStatus"
                        text: panel.manager ? panel.manager.clientStatus : "OpenCode: preview"
                        color: Ui.Theme.muted
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideNone
                        font.pixelSize: 11
                    }
                    Ui.ActionButton {
                        objectName: "aiConfigure"
                        iconName: "arrow-up"
                        iconOnly: false
                        text: "Use in OpenCode"
                        description: "Configure OpenCode for the selected loaded model"
                        enabled: panel.actionsEnabled && panel.manager && panel.manager.canConfigure(panel.candidateIndex) && panel.pendingAction === ""
                        onClicked: panel.configureRequested(panel.candidateIndex)
                        Ui.Hint {}
                    }
                }
                ColumnLayout {
                    objectName: "aiTelemetrySection"
                    Layout.alignment: Qt.AlignTop
                    Layout.fillHeight: false
                    spacing: 12
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.Label { text: "Output"; color: Ui.Theme.muted; Layout.fillWidth: true; font.pixelSize: 12 }
                        Ui.Label {
                            objectName: "tokenRate"
                            text: panel.service.tokensPerSecond >= 0 ? panel.service.tokensPerSecond.toFixed(1) + " tok/s" : "N/A"
                            font.pixelSize: 16
                        }
                    }
                    Repeater {
                        model: panel.service.gpus.length
                        ColumnLayout {
                            required property int index
                            readonly property var gpu: panel.service.gpus[index]
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
                            Ui.Label {
                                Layout.fillWidth: true
                                text: gpu.name
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                elide: Text.ElideNone
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Ui.Label { text: "VRAM"; color: Ui.Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
                                Ui.Label { text: panel.service.telemetryAvailable ? gpu.usedGiB.toFixed(1) + " / " + gpu.totalGiB.toFixed(1) + " GiB" : "N/A"; font.pixelSize: 11 }
                            }
                            Ui.SegmentedMeter {
                                objectName: "vramMeter" + index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                label: gpu.name + " VRAM"
                                value: gpu.usedGiB / gpu.totalGiB
                                reducedMotion: panel.service.reducedMotion
                                available: panel.service.telemetryAvailable
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Ui.Label { text: "GPU"; color: Ui.Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
                                Ui.Label { text: panel.service.telemetryAvailable ? gpu.utilization + "%" : "N/A"; font.pixelSize: 11 }
                            }
                            Ui.SegmentedMeter {
                                objectName: "gpuMeter" + index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                label: gpu.name + " utilization"
                                value: gpu.utilization / 100
                                reducedMotion: panel.service.reducedMotion
                                available: panel.service.telemetryAvailable
                            }
                        }
                    }
                }
            }
        }
    }
}