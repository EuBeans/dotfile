import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: mixer
    property bool embedded: false
    property string namePrefix: ""
    property var previewState: null
    required property int volume
    required property bool outputMuted
    required property var applications
    signal volumeRequested(int value)
    signal outputMuteRequested(bool muted)
    signal appVolumeRequested(string appId, int value)
    signal appMuteRequested(string appId, bool muted)
    signal closeRequested()
    implicitWidth: 440
    implicitHeight: 650
    color: embedded ? Ui.Theme.clear : Ui.Theme.surface
    radius: Ui.Theme.panelRadius
    topRightRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    bottomRightRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: mixer.embedded ? 0 : 20
        spacing: 12
        RowLayout {
            visible: !mixer.embedded
            Layout.fillWidth: true
            Ui.Label { text: "AUDIO MIXER"; font.family: Ui.Theme.displayFont; Layout.fillWidth: true }
            Ui.ActionButton {
                objectName: mixer.namePrefix + "closeVolume"
                iconName: "x"
                description: "Close volume mixer"
                onClicked: mixer.closeRequested()
            }
        }
        Ui.Label {
            objectName: mixer.namePrefix + "audioMode"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: mixer.previewState ? "Preview audio / no host changes" : "Device controls unavailable"
            color: Ui.Theme.muted
            font.pixelSize: 11
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Ui.Label { text: "OUTPUT"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
            Ui.Label { text: mixer.outputMuted ? "Muted" : mixer.volume + "%"; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight; font.pixelSize: 12 }
        }
        Ui.Dropdown {
            objectName: mixer.namePrefix + "outputSource"
            Layout.fillWidth: true
            enabled: mixer.previewState !== null && count > 0
            model: mixer.previewState ? mixer.previewState.audioOutputs : []
            currentIndex: mixer.previewState ? model.indexOf(mixer.previewState.outputDevice) : -1
            displayText: currentIndex >= 0 ? currentText : count ? "Device unavailable" : "No devices"
            Accessible.name: "Preview output device"
            onActivated: index => mixer.previewState.outputDevice = model[index]
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Ui.ValueSlider {
                objectName: mixer.namePrefix + "volumeSlider"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                from: 0
                to: 100
                stepSize: 1
                value: mixer.volume
                Accessible.name: "Output volume"
                onMoved: mixer.volumeRequested(Math.round(value))
            }
            Ui.ActionButton {
                objectName: mixer.namePrefix + "outputMute"
                iconName: mixer.outputMuted ? "volume-x" : "volume-2"
                checked: mixer.outputMuted
                description: mixer.outputMuted ? "Unmute output" : "Mute output"
                onClicked: mixer.outputMuteRequested(!mixer.outputMuted)
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Ui.Label { text: "INPUT"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
            Ui.Label {
                text: !mixer.previewState ? "--" : !mixer.previewState.microphoneEnabled ? "Muted" : mixer.previewState.inputVolume + "%"
                Layout.preferredWidth: 64
                horizontalAlignment: Text.AlignRight
                font.pixelSize: 12
            }
        }
        Ui.Dropdown {
            objectName: mixer.namePrefix + "inputSource"
            Layout.fillWidth: true
            enabled: mixer.previewState !== null && count > 0
            model: mixer.previewState ? mixer.previewState.audioInputs : []
            currentIndex: mixer.previewState ? model.indexOf(mixer.previewState.inputDevice) : -1
            displayText: currentIndex >= 0 ? currentText : count ? "Device unavailable" : "No devices"
            Accessible.name: "Preview input device"
            onActivated: index => mixer.previewState.inputDevice = model[index]
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Ui.ValueSlider {
                objectName: mixer.namePrefix + "inputVolumeSlider"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                enabled: mixer.previewState !== null
                from: 0
                to: 100
                stepSize: 1
                value: mixer.previewState ? mixer.previewState.inputVolume : 0
                Accessible.name: "Preview input volume"
                onMoved: mixer.previewState.inputVolume = Math.round(value)
            }
            Ui.ActionButton {
                objectName: mixer.namePrefix + "inputMute"
                enabled: mixer.previewState !== null
                checked: mixer.previewState !== null && !mixer.previewState.microphoneEnabled
                iconName: checked ? "volume-x" : "mic"
                description: checked ? "Unmute input" : "Mute input"
                onClicked: mixer.previewState.microphoneEnabled = !mixer.previewState.microphoneEnabled
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
        RowLayout {
            Layout.fillWidth: true
            Ui.Label { text: "APPLICATIONS"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
            Ui.Label { text: appList.count.toString(); color: Ui.Theme.muted; font.pixelSize: 11 }
        }
        ListView {
            id: appList
            objectName: mixer.namePrefix + "audioAppList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            model: mixer.applications
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: ColumnLayout {
                required property string appId
                required property string appName
                required property string streamName
                required property int level
                required property bool muted
                id: appRow
                width: appList.width - 12
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 4
                        Ui.Label { text: appRow.appName; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap }
                        Ui.Label { text: appRow.streamName; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; color: Ui.Theme.muted; font.pixelSize: 11 }
                    }
                    Ui.Label {
                        text: appRow.muted ? "Muted" : appRow.level + "%"
                        Layout.preferredWidth: 64
                        horizontalAlignment: Text.AlignRight
                        font.pixelSize: 12
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Ui.ValueSlider {
                        objectName: mixer.namePrefix + "appVolume_" + appRow.appId
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        from: 0
                        to: 100
                        stepSize: 1
                        value: appRow.level
                        Accessible.name: appRow.appName + " volume"
                        onMoved: mixer.appVolumeRequested(appRow.appId, Math.round(value))
                    }
                    Ui.ActionButton {
                        objectName: mixer.namePrefix + "appMute_" + appRow.appId
                        iconName: appRow.muted ? "volume-x" : "volume-2"
                        checked: appRow.muted
                        description: (appRow.muted ? "Unmute " : "Mute ") + appRow.appName
                        onClicked: mixer.appMuteRequested(appRow.appId, !appRow.muted)
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            }
            Ui.Label {
                objectName: mixer.namePrefix + "audioEmptyState"
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No apps playing audio"
                color: Ui.Theme.muted
                visible: appList.count === 0
            }
        }
    }
}