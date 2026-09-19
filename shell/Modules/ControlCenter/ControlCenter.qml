import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts
import "../../Components" as Ui
import "../Audio"
import "../WallpaperPicker"
import "../Settings"
import "../Hardware"
import "../Calendar"

Rectangle {
    id: panel
    objectName: "homePanel"
    required property var service
    required property var shortcuts
    property bool opened: false
    property bool production: false
    property Component settingsContent: null
    property string page: "Home"
    readonly property bool personalizing: ["Appearance", "Wallpaper", "Profiles"].includes(page)
    property int timerDraftSeconds: 300
    property bool shareScreen: false
    signal closeRequested()
    signal volumeRequested(int value)
    signal outputMuteRequested(bool muted)
    signal appVolumeRequested(string appId, int value)
    signal appMuteRequested(string appId, bool muted)
    signal wallpaperSelected(int index)
    signal toggleRequested(string setting, bool value)
    signal profileRequested(string name)
    signal wallpaperRequested()
    signal aiRequested()
    signal audioRequested()
    signal gpuRequested(int index)
    signal settingsRequested()
    signal workspaceRequested(int number)
    signal playbackRequested()
    signal previousRequested()
    signal nextRequested()
    signal seekRequested(real position)
    implicitWidth: 620
    implicitHeight: 530
    color: Ui.Theme.surface
    border.color: Ui.Theme.surfaceEdge
    radius: Ui.Theme.panelRadius
    antialiasing: true
    topLeftRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    topRightRadius: Ui.Theme.panelRadius
    bottomLeftRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    bottomRightRadius: Ui.Theme.panelRadius

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        Rectangle {
            Layout.preferredWidth: 42
            Layout.fillHeight: true
            color: Ui.Theme.clear
            ColumnLayout {
                anchors.fill: parent
                spacing: 8
                Item {
                    id: navigation
                    objectName: "homeNavigation"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        width: navigation.width
                        spacing: 6
                        Repeater {
                            model: [
                                {name: "homeTab", page: "Home", icon: "house", label: "Home"},
                                {name: "homeAudio", page: "Audio", icon: "volume-2", label: "Audio"},
                                {name: "homeDisplayTab", page: "Displays", icon: "monitor", label: "Displays"},
                                {name: "homeNetworkTab", page: "Network", icon: "wifi", label: "Network"},
                                {name: "homeSystemSummary", page: "System", icon: "activity", label: "System"},
                                {name: "homePowerTab", page: "Power", icon: "leaf", label: "Power"},
                                {name: "homeWeatherTab", page: "Weather", icon: "cloud-sun", label: "Weather"},
                                {name: "homeNotificationsTab", page: "Notifications", icon: "bell", label: "Notifications"}
                            ]
                            Ui.ActionButton {
                                required property var modelData
                                objectName: modelData.name
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.minimumHeight: 0
                                Layout.preferredHeight: Math.max(0, Math.min(42, (navigation.height - 42) / 8))
                                iconName: modelData.icon
                                iconOnly: true
                                text: modelData.label
                                font.pixelSize: 11
                                description: modelData.label
                                checked: modelData.page === "Appearance" ? panel.personalizing : panel.page === modelData.page
                                Accessible.role: Accessible.PageTab
                                onClicked: panel.page = modelData.page
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                Ui.ActionButton {
                    objectName: "homeSettings"
                    enabled: !panel.production || panel.settingsContent !== null
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: 42
                    iconName: "settings"
                    iconOnly: true
                    text: "Settings"
                    font.pixelSize: 11
                    description: "Settings"
                    checked: panel.page === "Settings"
                    onClicked: panel.page = "Settings"
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Ui.Label { text: panel.personalizing ? "Personalize" : panel.page; font.family: Ui.Theme.displayFont; font.pixelSize: 18; Layout.fillWidth: true; Layout.minimumWidth: 0 }
                Ui.ActionButton { objectName: "closeControls"; iconName: "x"; description: "Close Home"; onClicked: panel.closeRequested() }
            }
            RowLayout {
                visible: panel.personalizing
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [{name: "homeColorsTab", page: "Appearance", icon: "eye", label: "Colors"}, {name: "homeWallpaper", page: "Wallpaper", icon: "image", label: "Wallpaper"}, {name: "homeProfilesTab", page: "Profiles", icon: "gamepad-2", label: "Profiles"}]
                    Ui.ActionButton {
                        required property var modelData
                        objectName: modelData.name
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 38
                        iconName: modelData.icon
                        iconOnly: true
                        text: modelData.label
                        font.pixelSize: 11
                        description: modelData.label
                        checked: panel.page === modelData.page
                        Accessible.role: Accessible.PageTab
                        onClicked: panel.page = modelData.page
                    }
                }
            }
            ScrollView {
                id: scroll
                visible: !["Media", "Displays", "Power", "Weather", "Network", "Audio", "Wallpaper", "Settings", "System", "Profiles", "Calendar", "Notifications"].includes(panel.page)
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: scroll.availableWidth
                    spacing: 12
                    ColumnLayout {
                        visible: panel.page === "Activities"
                        Layout.fillWidth: true
                        spacing: 12
                        Ui.Label { text: "Preview activities"; color: Ui.Theme.muted }
                        Ui.SettingsSection {
                            title: "Timer"
                            Ui.ValueControl { objectName: "activityTimerDuration"; from: 1; to: 3600; value: panel.timerDraftSeconds; Accessible.name: "Timer duration in seconds"; onValueModified: value => panel.timerDraftSeconds = value }
                            Ui.Label { text: panel.service.activities.time(panel.service.activities.timerSeconds) + (panel.service.activities.timerPaused ? " / Paused" : ""); Layout.fillWidth: true }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Ui.ActionButton { objectName: "activityStartTimer"; text: "Start timer"; onClicked: panel.service.activities.startTimer(panel.timerDraftSeconds) }
                                Ui.ActionButton { objectName: "activityPauseTimer"; iconName: panel.service.activities.timerPaused ? "play" : "pause"; description: "Pause or resume timer"; enabled: panel.service.activities.timerSeconds > 0; onClicked: panel.service.activities.pause("timer") }
                                Ui.ActionButton { objectName: "activityCancelTimer"; iconName: "x"; description: "Cancel timer"; enabled: panel.service.activities.timerSeconds > 0; onClicked: panel.service.activities.stop("timer") }
                            }
                        }
                        Ui.SettingsSection {
                            title: "AI task"
                            Ui.Label { text: panel.service.loadedModelIndex >= 0 ? panel.service.models[panel.service.loadedModelIndex] : "No model loaded"; Layout.fillWidth: true }
                            Ui.Label { text: panel.service.activities.aiActive ? panel.service.activities.aiTask : "Idle"; Layout.fillWidth: true }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Ui.ActionButton { objectName: "activityStartAi"; text: "Start task"; enabled: !panel.service.activities.aiActive && panel.service.loadedModelIndex >= 0 && !panel.service.aiBusy; onClicked: panel.service.activities.startAi() }
                                Ui.ActionButton { objectName: "activityFinishAi"; text: "Finish task"; enabled: panel.service.activities.aiActive; onClicked: panel.service.activities.stop("ai") }
                                Ui.ActionButton { objectName: "activityCancelAi"; iconName: "x"; description: "Cancel task"; enabled: panel.service.activities.aiActive; onClicked: panel.service.activities.stop("ai") }
                            }
                            Ui.Toggle { objectName: "activityAiProgressKnown"; text: "Progress available"; checked: panel.service.activities.aiProgress >= 0; onToggled: panel.service.activities.aiProgress = checked ? 0.5 : -1 }
                            Ui.ValueControl { objectName: "activityAiProgress"; from: 0; to: 100; enabled: panel.service.activities.aiProgress >= 0; value: Math.max(0, panel.service.activities.aiProgress * 100); Accessible.name: "AI task progress"; onValueModified: value => panel.service.activities.aiProgress = value / 100 }
                        }
                        Ui.SettingsSection {
                            title: "Transfer"
                            Ui.Toggle { text: "Upload"; checked: panel.service.activities.transferUpload; enabled: !panel.service.activities.transferActive; onToggled: panel.service.activities.transferUpload = checked }
                            Ui.Label { text: panel.service.activities.transferActive ? panel.service.activities.time(panel.service.activities.transferSeconds) + " remaining" : "Idle"; Layout.fillWidth: true }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Ui.ActionButton { objectName: "activityStartTransfer"; text: "Start transfer"; enabled: !panel.service.activities.transferActive; onClicked: panel.service.activities.startTransfer(panel.service.activities.transferUpload) }
                                Ui.ActionButton { iconName: panel.service.activities.transferPaused ? "play" : "pause"; description: "Pause or resume transfer"; enabled: panel.service.activities.transferActive; onClicked: panel.service.activities.pause("transfer") }
                                Ui.ActionButton { iconName: "x"; description: "Cancel transfer"; enabled: panel.service.activities.transferActive; onClicked: panel.service.activities.stop("transfer") }
                            }
                        }
                        Ui.SettingsSection {
                            title: "Recording"
                            Ui.Toggle { text: "Screen sharing"; checked: panel.shareScreen; enabled: !panel.service.activities.recordingActive; onToggled: panel.shareScreen = checked }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Ui.ActionButton { objectName: "activityStartRecording"; text: "Start"; enabled: !panel.service.activities.recordingActive; onClicked: panel.service.activities.startRecording(panel.shareScreen) }
                                Ui.ActionButton { iconName: "square"; description: "Stop recording or sharing"; enabled: panel.service.activities.recordingActive; onClicked: panel.service.activities.stop("recording") }
                            }
                        }
                        Ui.SettingsSection {
                            title: "Urgent alert"
                            Ui.Dropdown { id: alertType; Layout.fillWidth: true; model: ["Incoming call", "Timer finished", "Critical battery"]; Accessible.name: "Alert type" }
                            Ui.ActionButton { objectName: "activityTriggerAlert"; text: "Trigger alert"; onClicked: panel.service.activities.alert(alertType.currentText) }
                        }
                    }
                    Item {
                        objectName: "homeProfileHeader"
                        visible: panel.page === "Home"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        Image {
                            objectName: "homeWallpaperBackground"
                            anchors.fill: parent
                            source: panel.service.selectedWallpaper.source
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: profileText.implicitHeight + 16
                            color: Ui.Theme.ink
                            opacity: 0.88
                        }
                        ColumnLayout {
                            id: profileText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.bottomMargin: 8
                            spacing: 4
                            Ui.Label { text: panel.service.profile; font.family: Ui.Theme.displayFont; font.pixelSize: 16; Layout.fillWidth: true }
                            Ui.Label { text: panel.service.selectedWallpaper.name; color: Ui.Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Ui.Theme.line }
                    }
                    GridLayout {
                        visible: panel.page === "Home"
                        Layout.fillWidth: true
                        columns: panel.width >= 550 ? 2 : 1
                        columnSpacing: 12
                        rowSpacing: 12
                        ColumnLayout {
                            objectName: "homeMediaColumn"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 300
                            Layout.minimumWidth: 0
                            spacing: 8
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 124
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 8
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                IconImage { Layout.preferredWidth: 24; Layout.preferredHeight: 24; source: "../../Assets/Icons/circle-play.svg"; color: Ui.Theme.muted }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 4
                                    Ui.Label { text: panel.service.mediaAvailable ? panel.service.track : "Nothing playing"; Layout.fillWidth: true; font.pixelSize: 12 }
                                    Ui.Label { text: panel.service.mediaAvailable ? (panel.service.playing ? "Playing" : "Paused") : "No player connected"; color: Ui.Theme.muted; font.pixelSize: 11; Layout.fillWidth: true }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Ui.ActionButton { objectName: "controlPrevious"; iconName: "skip-back"; description: "Previous track"; enabled: panel.service.mediaAvailable; onClicked: panel.previousRequested() }
                                Ui.ActionButton { objectName: "controlPlayback"; iconName: panel.service.playing ? "circle-pause" : "circle-play"; description: "Play or pause"; enabled: panel.service.mediaAvailable; onClicked: panel.playbackRequested() }
                                Ui.ActionButton { objectName: "controlNext"; iconName: "skip-forward"; description: "Next track"; enabled: panel.service.mediaAvailable; onClicked: panel.nextRequested() }
                                Item { Layout.fillWidth: true }
                            }
                            Ui.ValueSlider {
                                objectName: "homeMediaSeek"
                                Layout.fillWidth: true
                                from: 0; to: Math.max(1, panel.service.trackDuration); stepSize: 1
                                value: panel.service.trackPosition
                                enabled: panel.service.mediaAvailable && panel.service.trackDuration > 0
                                Accessible.name: "Track position"
                                onMoved: panel.seekRequested(value)
                            }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8
                                Ui.Label { text: panel.service.clock; font.family: Ui.Theme.displayFont; font.pixelSize: 18 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 4
                                    Ui.Label { text: panel.service.date; Layout.fillWidth: true; color: Ui.Theme.muted; font.pixelSize: 11 }
                                    Ui.Label { text: "Weather unavailable"; Layout.fillWidth: true; color: Ui.Theme.muted; font.pixelSize: 10 }
                                }
                            }
                            }
                        }
                        Grid {
                            id: quickTiles
                            objectName: "homeQuickTiles"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 220
                            Layout.minimumWidth: 0
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 8
                            Repeater {
                                model: [{label: "Wi-Fi", key: "wifiEnabled", icon: "wifi"}, {label: "Bluetooth", key: "bluetoothEnabled", icon: "bluetooth"}, {label: "Caffeine", key: "caffeineEnabled", icon: "coffee"}, {label: "Night light", key: "nightLightEnabled", icon: "moon"}, {label: "DND", key: "dndEnabled", icon: "bell-off"}, {label: "Power saver", key: "powerSaverEnabled", icon: "leaf"}]
                                Ui.ActionButton {
                                    id: quickTile
                                    required property var modelData
                                    objectName: modelData.key + "Switch"
                                    width: Math.max(0, Math.floor((quickTiles.width - quickTiles.columnSpacing * (quickTiles.columns - 1)) / quickTiles.columns))
                                    height: 64
                                    text: modelData.label
                                    enabled: !panel.production || (panel.service.desktopData.controlsEnabled && !panel.service.desktopData.busy)
                                    description: modelData.label + (checked ? ": on" : ": off") + (panel.production ? (enabled ? "" : " / Unavailable or read only") : " / Preview only")
                                    checkable: true
                                    checked: panel.service[modelData.key]
                                    Accessible.role: Accessible.CheckBox
                                    background: Rectangle {
                                        objectName: quickTile.objectName + "Background"
                                        radius: Ui.Theme.radius
                                        antialiasing: true
                                        color: quickTile.checked || quickTile.down ? Ui.Theme.paper : quickTile.hovered ? Ui.Theme.hover : Ui.Theme.groupSurface
                                        border.width: Ui.Theme.controlBorderWidth(quickTile)
                                        border.pixelAligned: false
                                        border.color: quickTile.checked || quickTile.down ? Ui.Theme.paper : Ui.Theme.line
                                        Rectangle {
                                            objectName: quickTile.objectName + "Focus"
                                            anchors.fill: parent
                                            anchors.margins: 5
                                            radius: Math.max(0, Ui.Theme.radius - 2)
                                            antialiasing: true
                                            color: Ui.Theme.clear
                                            visible: quickTile.visualFocus
                                            border.width: Ui.Theme.controlBorderWidth(quickTile)
                                            border.pixelAligned: false
                                            border.color: quickTile.checked || quickTile.down ? Ui.Theme.ink : Ui.Theme.paper
                                        }
                                    }
                                    contentItem: ColumnLayout {
                                        spacing: 6
                                        IconImage {
                                            objectName: quickTile.objectName + "Icon"
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            source: "../../Assets/Icons/" + quickTile.modelData.icon + ".svg"
                                            color: quickTile.checked || quickTile.down ? Ui.Theme.ink : Ui.Theme.paper
                                        }
                                        Ui.Label {
                                            objectName: quickTile.objectName + "Label"
                                            text: quickTile.text
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            font.pixelSize: 10
                                            color: quickTile.checked || quickTile.down ? Ui.Theme.ink : Ui.Theme.paper
                                        }
                                    }
                                    onToggled: {
                                        panel.toggleRequested(modelData.key, checked);
                                        checked = Qt.binding(() => panel.service[modelData.key]);
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        visible: panel.page === "Home"
                        Layout.fillWidth: true
                        spacing: 8
                        Ui.Label { text: "Profile"; color: Ui.Theme.muted; font.pixelSize: 11 }
                        Ui.Dropdown {
                            objectName: "homeProfile"
                            enabled: !panel.production || panel.service.desktopData.controlsEnabled
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.maximumWidth: 200
                            font.pixelSize: 11
                            model: panel.service.profileSettings.profiles.map(entry => entry.name)
                            currentIndex: model.indexOf(panel.service.profile)
                            Accessible.name: "Profile"
                            onActivated: panel.profileRequested(currentText)
                        }
                        Ui.ActionButton { objectName: "homeActivities"; visible: !panel.production; iconName: "timer"; description: "Activities"; onClicked: panel.page = "Activities" }
                    }
                    ColumnLayout {
                        visible: panel.page === "Connections"
                        Layout.fillWidth: true
                        spacing: 16
                        Repeater {
                            model: [{key: "wifiEnabled", label: "Wi-Fi", detail: "Networks unavailable"}, {key: "bluetoothEnabled", label: "Bluetooth", detail: "Paired devices unavailable"}]
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 10
                                RowLayout {
                                    Layout.fillWidth: true
                                    Ui.Toggle {
                                        objectName: "homeRadio_" + modelData.key
                                        text: modelData.label
                                        checked: panel.service[modelData.key]
                                        onToggled: panel.toggleRequested(modelData.key, checked)
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                                Ui.Label { text: modelData.detail; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Ui.Theme.muted; font.pixelSize: 11 }
                                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                            }
                        }
                        Ui.Label { text: "Ethernet"; Layout.fillWidth: true }
                        Ui.Label { text: "Service not connected"; Layout.fillWidth: true; color: Ui.Theme.muted; font.pixelSize: 11 }
                    }
                    ColumnLayout {
                        visible: panel.page === "Appearance"
                        Layout.fillWidth: true
                        spacing: 16
                        Ui.Label { text: panel.service.profile; color: Ui.Theme.muted }
                        Ui.Dropdown {
                            objectName: "homePaletteSource"
                            Layout.fillWidth: true
                            model: ["Saved", "Wallpaper"]
                            currentIndex: model.indexOf(panel.service.profileSettings.currentProfile.source)
                            Accessible.name: "Palette source"
                            onActivated: panel.service.profileSettings.update("source", currentText)
                        }
                        Ui.Label { text: "Palette"; color: Ui.Theme.muted }
                        Flow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            spacing: 8
                            Repeater {
                                model: panel.service.profileSettings.paletteNames
                                Ui.ActionButton {
                                    id: swatch
                                    required property string modelData
                                    objectName: "controlTheme" + modelData
                                    width: 78; height: 60
                                    description: modelData + " theme"
                                    checked: panel.service.profileSettings.currentProfile.source === "Saved" && panel.service.profileSettings.currentProfile.palette === modelData
                                    onClicked: { panel.service.profileSettings.update("palette", modelData); panel.service.profileSettings.update("source", "Saved"); }
                                    contentItem: ColumnLayout {
                                        Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 40; Layout.preferredHeight: 16; color: panel.service.profileSettings.palettes[swatch.modelData].ink; Rectangle { anchors.right: parent.right; width: parent.width / 2; height: parent.height; color: panel.service.profileSettings.palettes[swatch.modelData].accent } }
                                        Ui.Label { text: swatch.modelData; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; color: swatch.checked || swatch.down ? Ui.Theme.ink : Ui.Theme.paper }
                                    }
                                }
                            }
                        }
                    }
                    WorkspaceView {
                        visible: panel.page === "Workspaces"
                        Layout.fillWidth: true
                        manager: panel.service.windowManager
                        onWorkspaceRequested: (monitor, number) => {
                            panel.service.windowManager.activeMonitor = monitor;
                            panel.workspaceRequested(number);
                        }
                        onFocusRequested: windowId => panel.service.windowManager.focus(windowId)
                    }
                }
            }
            Loader {
                objectName: "homePageLoader"
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: ["Media", "Displays", "Power", "Weather", "Network", "Audio", "Wallpaper", "Settings", "System", "Profiles", "Calendar", "Notifications"].includes(panel.page)
                active: panel.opened && visible
                sourceComponent: ["Media","Displays","Power","Weather","Network","Notifications"].includes(panel.page) ? devicePage : panel.page === "Audio" ? audioPage : panel.page === "Wallpaper" ? wallpaperPage : panel.page === "Settings" ? settingsPage : panel.page === "System" ? systemPage : panel.page === "Profiles" ? profilesPage : panel.page === "Calendar" ? calendarPage : null
            }
        }
    }
    onPageChanged: {
        scroll.contentItem.contentY = 0;
        shortcuts.recording = "";
    }
    Dialog {
        id: displayConfirmation
        objectName: "homeDisplayConfirmation"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(360, parent ? parent.width - 24 : 360)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: panel.service.desktopData.displayPending
        background: Rectangle { color: Ui.Theme.surface; radius: Ui.Theme.radius; border.color: Ui.Theme.line }
        contentItem: ColumnLayout {
            spacing: 16
            Ui.Label { text: "Keep display changes?"; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Ui.Label { text: "Reverting in " + panel.service.desktopData.displayCountdown + " seconds"; Layout.fillWidth: true; color: Ui.Theme.muted }
            RowLayout {
                Layout.fillWidth: true
                Ui.ActionButton { objectName: "homeDisplayRevert"; text: "Revert"; enabled: !panel.service.desktopData.busy; onClicked: panel.service.desktopData.displayReverted() }
                Item { Layout.fillWidth: true }
                Ui.ActionButton { objectName: "homeDisplayKeep"; text: "Keep"; enabled: !panel.service.desktopData.busy; onClicked: panel.service.desktopData.displayConfirmed() }
            }
        }
    }
    Component {
        id: devicePage
        DevicePages { data: panel.service.desktopData; section: panel.page }
    }
    Component {
        id: audioPage
        Loader {
            sourceComponent: panel.service.desktopData.live ? liveAudioPage : previewAudioPage
        }
    }
    Component {
        id: liveAudioPage
        DevicePages { data: panel.service.desktopData; section: "Audio" }
    }
    Component {
        id: previewAudioPage
        VolumeMixer {
            embedded: true
            namePrefix: "home_"
            previewState: panel.service
            volume: panel.service.volume
            outputMuted: panel.service.outputMuted
            applications: panel.service.audioApps
            onVolumeRequested: value => panel.volumeRequested(value)
            onOutputMuteRequested: muted => panel.outputMuteRequested(muted)
            onAppVolumeRequested: (appId, value) => panel.appVolumeRequested(appId, value)
            onAppMuteRequested: (appId, muted) => panel.appMuteRequested(appId, muted)
        }
    }
    Component {
        id: systemPage
        ResourcesView {
            objectName: "homeSystemPage"
            data: panel.service.desktopData
        }
    }
    Component {
        id: wallpaperPage
        WallpaperPicker {
            id: embeddedWallpaperPicker
            embedded: true
            showPaletteControls: false
            namePrefix: "home_"
            wallpapers: panel.service.wallpapers
            monitorNames: panel.production ? panel.service.wallpaperMonitors : []
            targetMonitor: panel.production ? panel.service.homeScreen : ""
            selected: panel.production ? panel.service.wallpaperIndexForMonitor(targetMonitor) : panel.service.wallpaper
            profileSettings: panel.service.profileSettings
            folderLoading: panel.service.wallpaperFolderLoading
            directoryWallpaperCount: panel.service.directoryWallpapers.length
            onSelectedRequested: index => {
                if (panel.production) panel.service.setWallpaper(index, embeddedWallpaperPicker.targetMonitor);
                else panel.wallpaperSelected(index);
            }
        }
    }
    Component {
        id: profilesPage
        SettingsView {
            objectName: "homeProfilesPage"
            embedded: true
            singleSection: true
            section: 1
            service: panel.service
            shortcuts: panel.shortcuts
        }
    }
    Component {
        id: calendarPage
        ColumnLayout {
            spacing: 12
            CalendarPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                embedded: true
                today: panel.service.calendarDate
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
            RowLayout {
                Layout.fillWidth: true
                IconImage { Layout.preferredWidth: 28; Layout.preferredHeight: 28; source: "../../Assets/Icons/cloud-sun.svg"; color: Ui.Theme.muted }
                ColumnLayout {
                    Layout.fillWidth: true
                    Ui.Label { text: "Weather"; Layout.fillWidth: true }
                    Ui.Label { objectName: "homeWeatherStatus"; text: "Offline / Location not configured"; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 10; color: Ui.Theme.muted }
                }
            }
        }
    }
    Component {
        id: notificationsPage
        SettingsView {
            embedded: true
            singleSection: true
            section: 6
            service: panel.service
            shortcuts: panel.shortcuts
        }
    }
    Component {
        id: settingsPage
        Loader { sourceComponent: panel.settingsContent || defaultSettingsPage }
    }
    Component {
        id: defaultSettingsPage
        SettingsView {
            embedded: true
            service: panel.service
            shortcuts: panel.shortcuts
        }
    }
}