import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

ScrollView {
    id: page
    required property var data
    required property string section
    objectName: "homeDevicePage"
    property int playerIndex: 0
    readonly property var player: data.mediaPlayers[playerIndex] || null
    contentWidth: availableWidth
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    function level(device) {
        const channels = Object.values(device.volume || {});
        return channels.length && channels.every(channel => Number.isFinite(channel.value)) ? Math.round(channels.reduce((total, channel) => total + channel.value, 0) / channels.length * 100 / 65536) : null;
    }
    ColumnLayout {
        width: page.availableWidth
        spacing: 16
        Ui.Label {
            objectName: "homeServiceStatus"
            text: page.section === "Notifications" ? "Session history" : page.data.status
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Ui.Theme.muted
            font.pixelSize: 10
        }
        ColumnLayout {
            visible: page.section === "Media"
            Layout.fillWidth: true
            spacing: 16
            Ui.Dropdown {
                Layout.fillWidth: true
                Layout.maximumWidth: 600
                model: page.data.mediaPlayers.map(player => player.identity)
                currentIndex: page.playerIndex
                enabled: count > 0
                Accessible.name: "Media player"
                onActivated: page.playerIndex = currentIndex
            }
            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(220,page.availableWidth)
                Layout.preferredHeight: width
                source: page.player ? page.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectFit
                visible: source.toString() !== "" && status === Image.Ready
            }
            Ui.Label { text: page.player ? page.player.trackTitle || "Unknown track" : "Nothing playing"; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 18 }
            Ui.Label { text: page.player ? page.player.trackArtist || page.player.identity : "No media player connected"; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Ui.Theme.muted }
            Ui.Label { text: page.player ? page.player.trackAlbum : ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11 }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Ui.ActionButton { iconName: "skip-back"; description: "Previous track"; enabled: !!page.player && page.player.canGoPrevious; onClicked: page.data.mediaRequested(page.playerIndex,"previous") }
                Ui.ActionButton { iconName: page.player && page.player.isPlaying ? "pause" : "play"; description: "Play or pause"; enabled: !!page.player && page.player.canTogglePlaying; onClicked: page.data.mediaRequested(page.playerIndex,"toggle") }
                Ui.ActionButton { iconName: "skip-forward"; description: "Next track"; enabled: !!page.player && page.player.canGoNext; onClicked: page.data.mediaRequested(page.playerIndex,"next") }
            }
        }
        ColumnLayout {
            visible: page.section === "Audio"
            Layout.fillWidth: true
            spacing: 16
            Repeater {
                model: [{title:"Output",kind:"sink",entries:page.data.devices.sinks,selected:page.data.devices.audio ? page.data.devices.audio.default_sink_name : ""}, {title:"Input",kind:"source",entries:page.data.devices.sources.filter(device => !device.monitor_of_sink_name),selected:page.data.devices.audio ? page.data.devices.audio.default_source_name : ""}]
                ColumnLayout {
                    id: audioGroup
                    required property var modelData
                    readonly property var device: modelData.entries.find(entry => entry.name === modelData.selected) || null
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Ui.Label { text: audioGroup.modelData.title.toUpperCase(); font.family: Ui.Theme.displayFont; Layout.fillWidth: true; font.pixelSize: 14 }
                        Ui.Label {
                            objectName: "homeAudio" + audioGroup.modelData.title + "Level"
                            text: !audioGroup.device ? "--" : audioGroup.device.mute ? "Muted" : page.level(audioGroup.device) === null ? "--" : page.level(audioGroup.device) + "%"
                            Layout.preferredWidth: 64
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: 12
                        }
                    }
                    Ui.Dropdown {
                        objectName: "homeAudio" + audioGroup.modelData.title + "Source"
                        Layout.fillWidth: true
                        model: audioGroup.modelData.entries.map(device => device.description || device.name)
                        currentIndex: audioGroup.modelData.entries.findIndex(device => device.name === audioGroup.modelData.selected)
                        displayText: currentIndex < 0 ? (count ? "Default unavailable" : "No devices") : currentText
                        enabled: page.data.controlsEnabled && !page.data.busy && count > 0
                        Accessible.name: audioGroup.modelData.title + " device"
                        onActivated: page.data.request(["pactl","set-default-"+audioGroup.modelData.kind,audioGroup.modelData.entries[currentIndex].name])
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Ui.ValueSlider {
                            objectName: "homeAudio" + audioGroup.modelData.title + "Volume"
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            from: 0; to: 100; stepSize: 1
                            value: audioGroup.device ? page.level(audioGroup.device) ?? 0 : 0
                            enabled: !!audioGroup.device && page.level(audioGroup.device) !== null && page.data.controlsEnabled && !page.data.busy
                            Accessible.name: audioGroup.modelData.title + " volume"
                            onPressedChanged: if (!pressed && enabled) page.data.request(["pactl","set-"+audioGroup.modelData.kind+"-volume",audioGroup.device.name,Math.round(value)+"%"])
                            Keys.onReleased: if (enabled) page.data.request(["pactl","set-"+audioGroup.modelData.kind+"-volume",audioGroup.device.name,Math.round(value)+"%"])
                        }
                        Ui.ActionButton {
                            objectName: "homeAudio" + audioGroup.modelData.title + "Mute"
                            iconName: audioGroup.device && audioGroup.device.mute ? "volume-x" : "volume-2"
                            description: (audioGroup.device && audioGroup.device.mute ? "Unmute " : "Mute ") + audioGroup.modelData.title
                            checked: !!audioGroup.device && audioGroup.device.mute
                            enabled: !!audioGroup.device && page.data.controlsEnabled && !page.data.busy
                            onClicked: page.data.request(["pactl","set-"+audioGroup.modelData.kind+"-mute",audioGroup.device.name,"toggle"])
                        }
                    }
                    Ui.Label { visible: !audioGroup.device || page.level(audioGroup.device) === null; text: !audioGroup.device ? (audioGroup.modelData.entries.length ? "Default device unavailable" : "No " + audioGroup.modelData.title.toLowerCase() + " devices") : "Volume unavailable"; color: Ui.Theme.muted; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11 }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Ui.Label { text: "APPLICATIONS"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
                Ui.Label { text: page.data.devices.streams.length.toString(); color: Ui.Theme.muted; font.pixelSize: 11 }
            }
            Ui.Label { objectName: "homeAudioEmptyState"; visible: !page.data.devices.streams.length; text: "No application streams"; color: Ui.Theme.muted; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11 }
            Repeater {
                model: page.data.devices.streams
                ColumnLayout {
                    id: stream
                    required property var modelData
                    readonly property string appName: (modelData.properties || {})["application.name"] || modelData.name || "Application"
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Ui.Label { text: stream.appName; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap }
                        Ui.Label { objectName: "homeAudioAppLevel" + stream.modelData.index; text: stream.modelData.mute ? "Muted" : page.level(stream.modelData) === null ? "--" : page.level(stream.modelData) + "%"; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight; font.pixelSize: 12 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Ui.ValueSlider {
                            objectName: "homeAudioAppVolume" + stream.modelData.index
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            from: 0; to: 100; stepSize: 1
                            value: page.level(stream.modelData) ?? 0
                            enabled: page.level(stream.modelData) !== null && page.data.controlsEnabled && !page.data.busy
                            Accessible.name: stream.appName + " volume"
                            onPressedChanged: if (!pressed && enabled) page.data.request(["pactl","set-sink-input-volume",String(stream.modelData.index),Math.round(value)+"%"])
                            Keys.onReleased: if (enabled) page.data.request(["pactl","set-sink-input-volume",String(stream.modelData.index),Math.round(value)+"%"])
                        }
                        Ui.ActionButton { objectName: "homeAudioAppMute" + stream.modelData.index; iconName: stream.modelData.mute ? "volume-x" : "volume-2"; checked: !!stream.modelData.mute; description: (stream.modelData.mute ? "Unmute " : "Mute ") + stream.appName; enabled: page.data.controlsEnabled && !page.data.busy; onClicked: page.data.request(["pactl","set-sink-input-mute",String(stream.modelData.index),"toggle"]) }
                    }
                    Ui.Label { text: "OUTPUT"; color: Ui.Theme.muted; font.pixelSize: 10 }
                    Ui.Dropdown {
                        objectName: "homeAudioAppRoute" + stream.modelData.index
                        Layout.fillWidth: true
                        model: page.data.devices.sinks.map(device => device.description || device.name)
                        currentIndex: page.data.devices.sinks.findIndex(device => device.index === stream.modelData.sink)
                        displayText: currentIndex < 0 ? "Output unavailable" : currentText
                        Accessible.name: stream.appName + " output device"
                        enabled: page.data.controlsEnabled && !page.data.busy && count > 0
                        onActivated: page.data.request(["pactl","move-sink-input",String(stream.modelData.index),page.data.devices.sinks[currentIndex].name])
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                }
            }
        }
        ColumnLayout {
            visible: page.section === "Displays"
            Layout.fillWidth: true
            spacing: 16
            Ui.Label { objectName: "homeDisplayEmptyState"; visible: !page.data.devices.monitors.length; text: "No displays reported"; Layout.fillWidth: true; wrapMode: Text.Wrap; font.family: Ui.Theme.displayFont; font.pixelSize: 14 }
            Ui.Label { visible: !page.data.devices.monitors.length; text: "Hyprland monitor service unavailable"; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 11 }
            Repeater {
                model: page.data.devices.monitors
                ColumnLayout {
                    id: output
                    required property var modelData
                    readonly property int activeModeIndex: (modelData.availableModes || []).findIndex(value => value.startsWith(modelData.width+"x"+modelData.height+"@") && Math.abs(parseFloat(value.split("@")[1])-modelData.refreshRate)<0.1)
                    readonly property bool editable: page.data.controlsEnabled && !page.data.busy && !page.data.displayPending && !modelData.disabled
                    readonly property bool validScale: Number.isFinite(modelData.scale) && modelData.scale >= 0.5 && modelData.scale <= 3
                    readonly property bool changed: mode.currentIndex !== activeModeIndex || Math.abs(scale.value / 100 - modelData.scale) > 0.001 || rotation.currentIndex !== (modelData.transform || 0)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Ui.Label { objectName: "homeDisplayName" + output.modelData.name; text: output.modelData.name; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.family: Ui.Theme.displayFont; font.pixelSize: 16 }
                        Ui.Label { text: output.modelData.description || ""; textFormat: Text.PlainText; visible: text.length > 0; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.pixelSize: 11; color: Ui.Theme.muted }
                        Ui.Label {
                            objectName: "homeDisplaySummary" + output.modelData.name
                            text: output.modelData.disabled ? "Display inactive" : (output.modelData.width > 0 && output.modelData.height > 0 ? output.modelData.width+" x "+output.modelData.height : "Resolution unavailable") + " / " + (Number.isFinite(output.modelData.refreshRate) && output.modelData.refreshRate > 0 ? Number(output.modelData.refreshRate).toFixed(2)+" Hz" : "Refresh unavailable")
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            wrapMode: Text.Wrap
                            font.pixelSize: 12
                        }
                        Ui.Label { text: "Position " + (Number.isFinite(output.modelData.x) && Number.isFinite(output.modelData.y) ? output.modelData.x+", "+output.modelData.y : "unavailable") + " / " + (output.modelData.vrr === undefined ? "VRR unavailable" : output.modelData.vrr ? "VRR on" : "VRR off"); Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11; color: Ui.Theme.muted }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Ui.Label { text: "Mode / Hz"; color: Ui.Theme.muted; font.pixelSize: 11 }
                        Ui.Dropdown {
                            id: mode
                            objectName: "homeDisplayMode" + output.modelData.name
                            Layout.fillWidth: true
                            Layout.maximumWidth: 16777215
                            font.pixelSize: 12
                            model: output.modelData.availableModes || []
                            currentIndex: output.activeModeIndex
                            displayText: currentIndex < 0 ? (count ? "Select mode" : "Modes unavailable") : currentText
                            Accessible.name: output.modelData.name + " display mode"
                            enabled: output.editable && count > 0
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: output.width >= 440 ? 2 : 1
                        columnSpacing: 16
                        rowSpacing: 12
                        uniformCellWidths: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4
                            Ui.Label { text: "Scale (%)"; color: Ui.Theme.muted; font.pixelSize: 11 }
                            Ui.ValueControl {
                                id: scale
                                objectName: "homeDisplayScale" + output.modelData.name
                                Layout.fillWidth: true
                                Layout.maximumWidth: 16777215
                                from: 50; to: 300; stepSize: 25
                                value: output.validScale ? output.modelData.scale*100 : 100
                                onValueModified: value => scale.value = value
                                enabled: output.editable && output.validScale
                                opacity: enabled ? 1 : 0.4
                                Accessible.name: output.modelData.name + " display scale"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4
                            Ui.Label { text: "Rotation"; color: Ui.Theme.muted; font.pixelSize: 11 }
                            Ui.Dropdown {
                                id: rotation
                                objectName: "homeDisplayRotation" + output.modelData.name
                                Layout.fillWidth: true
                                Layout.maximumWidth: 16777215
                                font.pixelSize: 12
                                model: ["Normal", "90 degrees", "180 degrees", "270 degrees"]
                                currentIndex: (output.modelData.transform || 0) < count ? (output.modelData.transform || 0) : -1
                                displayText: currentIndex < 0 ? "Unsupported rotation" : currentText
                                enabled: output.editable
                                Accessible.name: output.modelData.name + " display rotation"
                            }
                        }
                    }
                    Ui.Label {
                        objectName: "homeDisplayState" + output.modelData.name
                        text: output.modelData.disabled ? "Display inactive" : !mode.count ? "Modes unavailable" : !output.validScale ? "Scale unavailable" : page.data.displayPending ? "Awaiting confirmation" : page.data.busy ? "Updating displays" : !page.data.controlsEnabled ? "Read-only" : mode.currentIndex < 0 ? "Select a mode" : rotation.currentIndex < 0 ? "Select a rotation" : output.changed ? "Changes not applied" : "Current settings"
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Ui.Theme.muted
                        font.pixelSize: 11
                    }
                    Ui.ActionButton {
                        objectName: "homeDisplayApply" + output.modelData.name
                        text: "Apply display"
                        enabled: output.editable && output.validScale && output.changed && mode.currentIndex >= 0 && rotation.currentIndex >= 0
                        onClicked: if (enabled) page.data.displayRequested(output.modelData,mode.currentText,scale.value/100,rotation.currentIndex)
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                }
            }
        }
        ColumnLayout {
            id: powerPage
            visible: page.section === "Power"
            Layout.fillWidth: true
            spacing: 12
            readonly property var profiles: [{key:"power-saver",name:"Power saver",icon:"leaf"},{key:"balanced",name:"Balanced",icon:"circle-dot"},{key:"performance",name:"Performance",icon:"activity"}]
            readonly property var activeProfile: profiles.find(profile => profile.key === page.data.devices.powerProfile)
            function moveProfile(index, direction) {
                for (let step = 1; step < profiles.length; step++) {
                    const option = profileOptions.itemAt((index + direction * step + profiles.length) % profiles.length).option;
                    if (option.enabled) {
                        option.forceActiveFocus(Qt.TabFocusReason);
                        option.clicked();
                        return;
                    }
                }
            }
            Ui.Label { text: "POWER PROFILE"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
            Ui.Label {
                objectName: "homePowerActiveProfile"
                text: powerPage.activeProfile ? powerPage.activeProfile.name : page.data.devices.powerProfile || "Unavailable"
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                wrapMode: Text.Wrap
                font.pixelSize: 18
            }
            GridLayout {
                Layout.fillWidth: true
                columns: powerPage.width >= 480 ? 3 : 1
                columnSpacing: 8
                rowSpacing: 8
                uniformCellWidths: true
                Accessible.role: Accessible.Grouping
                Accessible.name: "Power profile"
                Repeater {
                    id: profileOptions
                    model: powerPage.profiles
                    ColumnLayout {
                        id: profileChoice
                        required property var modelData
                        required property int index
                        property alias option: profileOption
                        readonly property bool supported: page.data.devices.powerProfiles.includes(modelData.key)
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 4
                        Ui.ActionButton {
                            id: profileOption
                            objectName: "homePowerProfile" + profileChoice.modelData.key
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredHeight: 44
                            text: profileChoice.modelData.name
                            iconName: checked ? "circle-dot" : profileChoice.modelData.icon
                            iconOnly: false
                            grouped: true
                            font.pixelSize: 12
                            checked: page.data.devices.powerProfile === profileChoice.modelData.key
                            enabled: page.data.controlsEnabled && !page.data.busy && profileChoice.supported
                            opacity: enabled ? 1 : 0.7
                            description: text + (checked ? " / Active" : "") + (!profileChoice.supported ? " / Unavailable" : page.data.busy ? " / Action in progress" : !page.data.controlsEnabled ? " / Read-only" : "")
                            Accessible.role: Accessible.RadioButton
                            Accessible.checkable: true
                            Accessible.checked: checked
                            onClicked: if (enabled && !checked) page.data.request(["powerprofilesctl","set",profileChoice.modelData.key])
                            Keys.onLeftPressed: powerPage.moveProfile(profileChoice.index, -1)
                            Keys.onUpPressed: powerPage.moveProfile(profileChoice.index, -1)
                            Keys.onRightPressed: powerPage.moveProfile(profileChoice.index, 1)
                            Keys.onDownPressed: powerPage.moveProfile(profileChoice.index, 1)
                        }
                        Ui.Label {
                            objectName: "homePowerProfileState" + profileChoice.modelData.key
                            text: !profileChoice.supported ? (profileOption.checked ? "Active / Unavailable" : "Unavailable") : profileOption.checked ? "Active" : ""
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.minimumHeight: implicitHeight
                            wrapMode: Text.Wrap
                            color: Ui.Theme.muted
                            font.pixelSize: 11
                        }
                    }
                }
            }
            Ui.Label {
                objectName: "homePowerState"
                text: !page.data.devices.powerProfiles.length ? "Power profile service unavailable" : page.data.busy ? "Action in progress" : !page.data.controlsEnabled ? "Read-only" : !page.data.devices.powerProfile ? "Active profile unavailable" : !powerPage.activeProfile ? "Active profile not in these options" : ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Ui.Theme.muted
                font.pixelSize: 11
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            Ui.Label { text: "DEVICE BATTERIES"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
            Ui.Label { objectName: "homePowerBatteryEmpty"; visible: !page.data.devices.batteries.length; text: "No batteries reported by UPower"; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 11 }
            Repeater {
                model: page.data.devices.batteries
                ColumnLayout {
                    id: batteryRow
                    required property var modelData
                    required property int index
                    readonly property string reportedPercentage: modelData.percentage === undefined || modelData.percentage === null ? "" : String(modelData.percentage).trim().replace(/%$/, "")
                    readonly property real percentage: reportedPercentage === "" ? NaN : Number(reportedPercentage)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4
                            Ui.Label { objectName: "homePowerBatteryName" + batteryRow.index; text: batteryRow.modelData.model || batteryRow.modelData.vendor || "Battery"; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.pixelSize: 12 }
                            Ui.Label { objectName: "homePowerBatteryState" + batteryRow.index; text: batteryRow.modelData.state ? String(batteryRow.modelData.state).replace(/-/g, " ") : "State unknown"; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 11 }
                        }
                        Ui.Label {
                            objectName: "homePowerBatteryPercent" + batteryRow.index
                            text: Number.isFinite(batteryRow.percentage) && batteryRow.percentage >= 0 && batteryRow.percentage <= 100 ? batteryRow.percentage + "%" : "Unknown"
                            Layout.preferredWidth: 64
                            Layout.alignment: Qt.AlignTop
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: 12
                        }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                }
            }
        }
        ColumnLayout {
            id: networkPage
            visible: page.section === "Network"
            Layout.fillWidth: true
            readonly property bool editable: page.data.controlsEnabled && !page.data.busy
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Ui.Toggle { objectName: "homeNetworkWifi"; text: "Wi-Fi"; checked: page.data.devices.wifi; enabled: networkPage.editable; onToggled: if (enabled) page.data.request(["nmcli","radio","wifi",checked ? "on" : "off"]) }
                Item { Layout.fillWidth: true }
                Ui.ActionButton { objectName: "homeNetworkRefresh"; iconName: "rotate-ccw"; description: "Refresh Wi-Fi networks"; enabled: networkPage.editable && page.data.devices.wifi; onClicked: if (enabled) page.data.request(["nmcli","device","wifi","rescan"]) }
                Ui.ActionButton { objectName: "homeNetworkEditor"; iconName: "settings"; description: "Edit connections in NetworkManager"; enabled: networkPage.editable; onClicked: if (enabled) page.data.request(["nm-connection-editor"]) }
            }
            Ui.Label { objectName: "homeNetworkState"; text: page.data.busy ? "Network action in progress" : !page.data.controlsEnabled ? "Read-only" : page.data.devices.wifi ? "Wi-Fi on" : "Wi-Fi off"; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 11 }
            Ui.Label { text: "CONNECTIONS"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
            Repeater {
                model: page.data.devices.network
                ColumnLayout {
                    id: networkDevice
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 8
                    Ui.Label { text: (networkDevice.modelData.type === "wifi" ? "WI-FI" : (networkDevice.modelData.type || "Device").toUpperCase()); textFormat: Text.PlainText; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 10 }
                    Ui.Label { objectName: "homeNetworkName" + networkDevice.modelData.name; text: networkDevice.modelData.connection && networkDevice.modelData.connection !== "--" ? networkDevice.modelData.connection : networkDevice.modelData.name; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.pixelSize: 14 }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 4
                            Ui.Label { objectName: "homeNetworkDeviceState" + networkDevice.modelData.name; text: networkDevice.modelData.state || "Status unavailable"; textFormat: Text.PlainText; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12 }
                            Ui.Label { text: networkDevice.modelData.name; textFormat: Text.PlainText; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11; color: Ui.Theme.muted }
                        }
                        Ui.ActionButton { objectName: "homeNetworkDisconnect" + networkDevice.modelData.name; iconName: "x"; description: "Disconnect " + networkDevice.modelData.name; visible: networkDevice.modelData.state === "connected"; enabled: networkPage.editable && networkDevice.modelData.state === "connected"; onClicked: if (enabled) disconnect.confirm(networkDevice.modelData.name) }
                        Ui.ActionButton { objectName: "homeNetworkConnect" + networkDevice.modelData.name; iconName: "play"; description: "Connect " + networkDevice.modelData.name; visible: networkDevice.modelData.type === "ethernet" && networkDevice.modelData.state === "disconnected"; enabled: networkPage.editable && visible; onClicked: if (enabled) page.data.request(["nmcli","device","connect",networkDevice.modelData.name]) }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                }
            }
            Ui.Label { objectName: "homeNetworkEmpty"; visible: !page.data.devices.network.length; text: page.data.live ? "No network devices reported" : "Network data unavailable"; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 11 }
            Ui.Label { text: "WI-FI NETWORKS"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
            Ui.Label { objectName: "homeNetworkScanState"; visible: !page.data.devices.wifi || !(page.data.devices.accessPoints || []).length; text: !page.data.live || !Array.isArray(page.data.devices.accessPoints) ? "Network scan unavailable" : !page.data.devices.wifi ? "Wi-Fi off" : "No networks reported"; color: Ui.Theme.muted; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11 }
            Repeater {
                model: page.data.devices.wifi ? page.data.devices.accessPoints || [] : []
                ColumnLayout {
                    id: accessPoint
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 4
                    Ui.Label { objectName: "homeNetworkSsid" + accessPoint.index; text: accessPoint.modelData.ssid || "Hidden network"; textFormat: Text.PlainText; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    Ui.Label { text: (accessPoint.modelData.active ? "Connected / " : "") + (Number.isFinite(accessPoint.modelData.signal) ? accessPoint.modelData.signal + "%" : "Signal unavailable"); Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11 }
                    Ui.Label { text: accessPoint.modelData.security === undefined || accessPoint.modelData.security === null ? "Security unavailable" : accessPoint.modelData.security || "Open"; textFormat: Text.PlainText; color: Ui.Theme.muted; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11 }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            Ui.Label { text: "SAVED WI-FI"; font.family: Ui.Theme.displayFont; font.pixelSize: 14; Layout.fillWidth: true }
            Ui.Label { objectName: "homeNetworkSavedState"; visible: !(page.data.devices.savedNetworks || []).length; text: !page.data.live || !Array.isArray(page.data.devices.savedNetworks) ? "Saved connections unavailable" : "No saved connections"; color: Ui.Theme.muted; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11 }
            Repeater {
                model: page.data.devices.savedNetworks || []
                ColumnLayout {
                    id: savedNetwork
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 4
                    Ui.Label { objectName: "homeNetworkSavedName" + savedNetwork.index; text: savedNetwork.modelData.name || "Unnamed connection"; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Ui.Label { text: savedNetwork.modelData.uuid ? "Saved" : "Connection ID unavailable"; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11; color: Ui.Theme.muted }
                        Ui.ActionButton { objectName: "homeNetworkSavedConnect" + savedNetwork.index; iconName: "play"; description: "Connect to " + savedNetwork.modelData.name; enabled: networkPage.editable && page.data.devices.wifi && !!savedNetwork.modelData.uuid; onClicked: if (enabled) page.data.request(["nmcli","connection","up","uuid",savedNetwork.modelData.uuid]) }
                        Ui.ActionButton { objectName: "homeNetworkSavedEdit" + savedNetwork.index; iconName: "settings"; description: "Edit " + savedNetwork.modelData.name + " in NetworkManager"; enabled: networkPage.editable && !!savedNetwork.modelData.uuid; onClicked: if (enabled) page.data.request(["nm-connection-editor","--edit",savedNetwork.modelData.uuid]) }
                    }
                }
            }
        }
        ColumnLayout {
            id: weatherPage
            visible: page.section === "Weather"
            Layout.fillWidth: true
            spacing: 16
            readonly property var current: page.data.weather || ({})
            function reading(value, unit, digits) {
                return typeof value === "number" && Number.isFinite(value) ? page.data.value(value, unit, digits) : "--" + unit;
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Ui.Label { text: "CURRENT"; Layout.fillWidth: true; font.family: Ui.Theme.displayFont; font.pixelSize: 14 }
                Ui.Label { objectName: "homeWeatherPlace"; text: weatherPage.current.location || (page.data.latitude && page.data.longitude ? "Coordinates configured" : "Location not configured"); textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.family: Ui.Theme.displayFont; font.pixelSize: 16 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Ui.Label { objectName: "homeWeatherTemperature"; text: weatherPage.reading(weatherPage.current.temperature, " C"); font.pixelSize: 24 }
                    Ui.Label { objectName: "homeWeatherConditions"; text: weatherPage.current.condition || "Conditions unavailable"; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.pixelSize: 11; color: Ui.Theme.muted }
                }
                Ui.Label { objectName: "homeWeatherStatus"; text: page.data.weatherStatus; textFormat: Text.PlainText; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 11 }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: weatherPage.width >= 480 ? 4 : 2
                uniformCellWidths: true
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: [{key:"feelsLike",label:"Feels like",unit:" C"},{key:"wind",label:"Wind",unit:" km/h"},{key:"minimum",label:"Minimum",unit:" C"},{key:"maximum",label:"Maximum",unit:" C"},{key:"uv",label:"UV index",unit:""},{key:"sunrise",label:"Sunrise"},{key:"sunset",label:"Sunset"}]
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        Ui.Label { text: modelData.label; Layout.fillWidth: true; font.pixelSize: 10; color: Ui.Theme.muted }
                        Ui.Label { objectName: "homeWeatherMetric" + modelData.key; text: modelData.unit !== undefined ? weatherPage.reading(weatherPage.current[modelData.key], modelData.unit, 1) : weatherPage.current[modelData.key] || "--"; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.pixelSize: 12 }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Ui.Label { text: "Timezone"; font.pixelSize: 10; color: Ui.Theme.muted }
                Ui.Label { objectName: "homeWeatherTimezone"; text: weatherPage.current.timezone || "Unavailable"; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.pixelSize: 11 }
            }
            Repeater {
                model: [{title:"HOURLY",key:"hourly",label:"Time",first:"Temp C",second:"Rain %"},{title:"DAILY",key:"daily",label:"Date",first:"Min C",second:"Max C"}]
                ColumnLayout {
                    id: forecast
                    required property var modelData
                    readonly property var entries: weatherPage.current[modelData.key] || []
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                    Ui.Label { text: forecast.modelData.title; font.family: Ui.Theme.displayFont; font.pixelSize: 14 }
                    RowLayout {
                        visible: forecast.entries.length > 0
                        Layout.fillWidth: true
                        spacing: 8
                        Ui.Label { text: forecast.modelData.label; Layout.fillWidth: true; font.pixelSize: 10; color: Ui.Theme.muted }
                        Ui.Label { text: forecast.modelData.first; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Ui.Theme.muted }
                        Ui.Label { text: forecast.modelData.second; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Ui.Theme.muted }
                    }
                    Repeater {
                        model: forecast.entries
                        RowLayout {
                            id: forecastRow
                            required property var modelData
                            required property int index
                            objectName: "homeWeather" + forecast.modelData.key + "Row" + index
                            Layout.fillWidth: true
                            spacing: 8
                            Ui.Label { objectName: forecastRow.objectName + "Time"; text: (forecast.modelData.key === "hourly" ? forecastRow.modelData.time : forecastRow.modelData.date) || "--"; textFormat: Text.PlainText; Layout.fillWidth: true; Layout.minimumWidth: 0; wrapMode: Text.Wrap; font.pixelSize: 11 }
                            Ui.Label { objectName: forecastRow.objectName + "First"; text: weatherPage.reading(forecast.modelData.key === "hourly" ? forecastRow.modelData.temperature : forecastRow.modelData.minimum, ""); Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
                            Ui.Label { objectName: forecastRow.objectName + "Second"; text: weatherPage.reading(forecast.modelData.key === "hourly" ? forecastRow.modelData.rain : forecastRow.modelData.maximum, ""); Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; font.pixelSize: 11 }
                        }
                    }
                    Ui.Label { objectName: "homeWeather" + forecast.modelData.key + "Empty"; visible: !forecast.entries.length; text: "Forecast unavailable"; Layout.fillWidth: true; font.pixelSize: 11; color: Ui.Theme.muted }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Ui.Label { text: "LOCATION"; font.family: Ui.Theme.displayFont; font.pixelSize: 14 }
                GridLayout {
                    Layout.fillWidth: true
                    columns: weatherPage.width >= 360 ? 2 : 1
                    uniformCellWidths: true
                    columnSpacing: 12
                    rowSpacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        Ui.Label { text: "Latitude"; font.pixelSize: 11 }
                        Ui.TextField {
                            id: latitude
                            objectName: "homeWeatherLatitude"
                            property bool touched: false
                            readonly property bool invalid: !text.trim() || !Number.isFinite(Number(text)) || Math.abs(Number(text)) > 90
                            text: page.data.latitude
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            implicitHeight: 44
                            placeholderText: "-90 to 90"
                            Accessible.name: "Latitude"
                            Accessible.description: latitudeHint.text
                            onEditingFinished: touched = true
                        }
                        Ui.Label { id: latitudeHint; objectName: "homeWeatherLatitudeHint"; text: latitude.touched && latitude.invalid ? "Invalid latitude: use -90 to 90." : "Range: -90 to 90"; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 10; font.bold: latitude.touched && latitude.invalid; color: latitude.touched && latitude.invalid ? Ui.Theme.paper : Ui.Theme.muted; Layout.minimumHeight: 28 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        Ui.Label { text: "Longitude"; font.pixelSize: 11 }
                        Ui.TextField {
                            id: longitude
                            objectName: "homeWeatherLongitude"
                            property bool touched: false
                            readonly property bool invalid: !text.trim() || !Number.isFinite(Number(text)) || Math.abs(Number(text)) > 180
                            text: page.data.longitude
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            implicitHeight: 44
                            placeholderText: "-180 to 180"
                            Accessible.name: "Longitude"
                            Accessible.description: longitudeHint.text
                            onEditingFinished: touched = true
                        }
                        Ui.Label { id: longitudeHint; objectName: "homeWeatherLongitudeHint"; text: longitude.touched && longitude.invalid ? "Invalid longitude: use -180 to 180." : "Range: -180 to 180"; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 10; font.bold: longitude.touched && longitude.invalid; color: longitude.touched && longitude.invalid ? Ui.Theme.paper : Ui.Theme.muted; Layout.minimumHeight: 28 }
                    }
                }
                Ui.ActionButton {
                    objectName: "homeWeatherLocation"
                    text: "Set location"
                    implicitHeight: 44
                    onClicked: {
                        latitude.touched = true;
                        longitude.touched = true;
                        page.data.configureWeather(latitude.text, longitude.text);
                    }
                }
            }
        }
        ColumnLayout {
            objectName: "homeNotificationHistory"
            visible: page.section === "Notifications"
            Layout.fillWidth: true
            spacing: 16
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Ui.Label {
                    objectName: "homeNotificationCount"
                    text: page.data.notifications.length + (page.data.notifications.length === 1 ? " notification" : " notifications")
                    Layout.fillWidth: true
                    font.family: Ui.Theme.displayFont
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                }
                Ui.ActionButton {
                    objectName: "homeClearHistory"
                    text: "Clear"
                    description: "Clear notification history"
                    implicitHeight: 44
                    enabled: page.data.notifications.length > 0
                    onClicked: clearHistory.open()
                }
            }
            Ui.Label {
                objectName: "homeNotificationEmpty"
                visible: !page.data.notifications.length
                text: "No saved notifications"
                Layout.fillWidth: true
                topPadding: 16
                bottomPadding: 16
                wrapMode: Text.Wrap
                color: Ui.Theme.muted
                font.pixelSize: 12
            }
            Repeater {
                model: ["Today","Yesterday","Older"]
                ColumnLayout {
                    id: group
                    required property string modelData
                    readonly property var entries: page.data.notifications.filter(entry => page.data.dayGroup(entry.time) === modelData)
                    objectName: "homeNotificationGroup" + modelData
                    visible: entries.length > 0
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.Label { text: group.modelData.toUpperCase(); Layout.fillWidth: true; font.family: Ui.Theme.displayFont; font.pixelSize: 12 }
                        Ui.Label { text: group.entries.length; color: Ui.Theme.muted; font.pixelSize: 11 }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                    Repeater {
                        model: group.entries
                        ColumnLayout {
                            id: notification
                            required property var modelData
                            required property int index
                            objectName: "homeNotification" + group.modelData + index
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Ui.Label {
                                    objectName: notification.objectName + "App"
                                    text: notification.modelData.app
                                    textFormat: Text.PlainText
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 11
                                    color: Ui.Theme.muted
                                }
                                Ui.Label {
                                    objectName: notification.objectName + "Time"
                                    text: Qt.formatDateTime(new Date(notification.modelData.time),"hh:mm")
                                    Layout.preferredWidth: 40
                                    Layout.alignment: Qt.AlignTop
                                    horizontalAlignment: Text.AlignRight
                                    font.pixelSize: 11
                                    color: Ui.Theme.muted
                                }
                            }
                            Ui.Label { objectName: notification.objectName + "Title"; text: notification.modelData.title; textFormat: Text.PlainText; Layout.fillWidth: true; wrapMode: Text.Wrap }
                            Ui.Label { objectName: notification.objectName + "Body"; text: notification.modelData.body; textFormat: Text.PlainText; visible: text.length > 0; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11; color: Ui.Theme.muted }
                            Rectangle { visible: notification.index < group.entries.length - 1; Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 4; implicitHeight: 1; color: Ui.Theme.line }
                        }
                    }
                }
            }
        }
    }
    Dialog {
        id: clearHistory
        objectName: "homeClearHistoryDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        implicitWidth: 360
        width: Math.min(implicitWidth,page.width+24,parent.width-24)
        padding: 16
        title: "Clear history?"
        modal: true
        onOpened: clearHistoryCancel.forceActiveFocus()
        onAccepted: page.data.notifications = []
        background: Rectangle { color: Ui.Theme.ink; radius: Ui.Theme.radius; border.color: Ui.Theme.line }
        header: Ui.Label { text: clearHistory.title; padding: 16; font.family: Ui.Theme.displayFont; font.pixelSize: 16; wrapMode: Text.Wrap }
        contentItem: ColumnLayout {
            spacing: 16
            Ui.Label {
                text: "Remove all saved notifications from this session? This cannot be undone."
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Ui.Theme.muted
                font.pixelSize: 12
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Ui.ActionButton { id: clearHistoryCancel; objectName: "homeClearHistoryCancel"; text: "Cancel"; implicitHeight: 44; onClicked: clearHistory.reject() }
                Item { Layout.fillWidth: true }
                Ui.ActionButton { objectName: "homeClearHistoryConfirm"; text: "Clear"; description: "Clear notification history"; implicitHeight: 44; enabled: page.data.notifications.length > 0; onClicked: clearHistory.accept() }
            }
        }
    }
    Dialog {
        id: disconnect
        objectName: "homeNetworkDisconnectDialog"
        property string device: ""
        readonly property bool canDisconnect: page.data.controlsEnabled && !page.data.busy && page.data.devices.network.some(entry => entry.name === device && entry.state === "connected")
        function confirm(name) { device = name; open(); }
        parent: Overlay.overlay
        anchors.centerIn: parent
        implicitWidth: 360
        width: Math.min(implicitWidth,page.width+24,parent.width-24)
        padding: 16
        title: "Disconnect?"
        modal: true
        onOpened: disconnectCancel.forceActiveFocus()
        onAccepted: if (canDisconnect) page.data.request(["nmcli","device","disconnect",device])
        background: Rectangle { color: Ui.Theme.ink; radius: Ui.Theme.radius; border.color: Ui.Theme.line }
        header: Ui.Label { text: disconnect.title; padding: 16; font.family: Ui.Theme.displayFont; font.pixelSize: 16 }
        contentItem: ColumnLayout {
            spacing: 12
            Ui.Label { objectName: "homeNetworkDisconnectTarget"; text: disconnect.device; textFormat: Text.PlainText; Layout.fillWidth: true; wrapMode: Text.Wrap }
            Ui.Label { text: "Active transfers may be interrupted."; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 11 }
            Ui.Label { visible: !disconnect.canDisconnect; text: page.data.busy ? "Network action in progress" : !page.data.controlsEnabled ? "Read-only" : "Connection no longer active"; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Ui.Theme.muted; font.pixelSize: 11 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Ui.ActionButton { id: disconnectCancel; objectName: "homeNetworkDisconnectCancel"; text: "Cancel"; onClicked: disconnect.reject() }
                Item { Layout.fillWidth: true }
                Ui.ActionButton { objectName: "homeNetworkDisconnectConfirm"; text: "Disconnect"; enabled: disconnect.canDisconnect; onClicked: if (enabled) disconnect.accept() }
            }
        }
    }
}