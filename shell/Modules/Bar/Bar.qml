import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.impl
import "../../Components" as Ui

Item {
    id: bar
    required property var state
    property string openPanel: ""
    property int selectedGpu: 0
    property bool settingsOpen: false
    readonly property var activities: state.activities
    readonly property var notification: state.currentNotification
    readonly property bool notificationRow: !!notification && (stacked || notchSpace < 160)
    readonly property bool stacked: width < 640
    readonly property bool dense: width < 400
    readonly property bool hardwareLabels: width >= 1600
    readonly property bool commandLabels: width >= 2200
    readonly property real notchSpace: width - 2 * Math.max(leftGroup.implicitWidth + 44, rightGroup.implicitWidth + 36)
    readonly property real sideBudget: Math.max(0, (width - notch.width) / 2 - 24)
    readonly property real leftBudget: Math.max(0, sideBudget - 40)
    readonly property real rightBudget: Math.max(0, sideBudget - 60)
    readonly property real clockX: leftSurface.x + leftGroup.x + clockControl.x
    signal workspaceRequested(int number)
    signal playbackRequested()
    signal previousRequested()
    signal nextRequested()
    signal seekRequested(real position)
    signal profileRequested(string name)
    signal wallpaperRequested()
    signal volumeRequested()
    signal aiRequested()
    signal gpuRequested(int index)
    signal powerRequested()
    signal controlsRequested()
    signal settingsRequested()
    signal calendarRequested()
    signal summaryRequested()
    implicitHeight: Ui.Theme.barHeight * ((stacked ? 2 : 1) + (notificationRow ? 1 : 0))
    clip: true

    Rectangle {
        id: leftSurface
        objectName: "barLeft"
        readonly property bool floating: bar.state.profileSettings.floatingLeftBar
        height: Ui.Theme.barHeight - (floating ? 8 : 4)
        y: floating ? 4 : 0
        x: floating ? 12 : 0
        width: leftGroup.implicitWidth + 24
        color: Ui.Theme.ink
        radius: Ui.Theme.barRadius
        topLeftRadius: floating ? radius : 0
        topRightRadius: floating ? radius : 0
        bottomLeftRadius: floating ? radius : 0
        RowLayout {
            id: leftGroup
            anchors.centerIn: parent
            spacing: 4
            Ui.ActionButton {
                objectName: "controlsButton"
                iconName: "house"
                iconOnly: !bar.commandLabels
                text: "Home"
                checked: bar.openPanel === "controls"
                description: "Open Home"
                onClicked: bar.controlsRequested()
            }
            Ui.ActionButton {
                id: clockControl
                objectName: "clockButton"
                iconName: "calendar-days"
                Layout.preferredWidth: bar.width >= 960 ? 214 : 112
                text: bar.state.date + "   " + bar.state.clock
                contentItem: RowLayout {
                    spacing: 6
                    IconImage {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        source: "../../Assets/Icons/calendar-days.svg"
                        color: clockControl.checked || clockControl.down ? Ui.Theme.ink : Ui.Theme.paper
                    }
                    Ui.Label {
                        Layout.fillWidth: true
                        text: bar.width >= 960 ? clockControl.text : bar.state.date + "\n" + bar.state.clock
                        font.pixelSize: bar.width >= 960 ? 12 : 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: clockControl.checked || clockControl.down ? Ui.Theme.ink : Ui.Theme.paper
                    }
                }
                description: "Open calendar"
                checked: bar.openPanel === "calendar"
                onClicked: bar.calendarRequested()
            }
            Ui.ActionButton {
                objectName: "powerButton"
                iconName: "power"
                iconOnly: !bar.commandLabels
                text: "Power"
                description: "Power and session"
                checked: bar.openPanel === "power"
                onClicked: bar.powerRequested()
            }
        }
    }

    Ui.NotchSurface {
        id: notch
        objectName: "barCenter"
        floating: bar.state.profileSettings.floatingMiddleBar
        readonly property bool opened: !!bar.notification || bar.activities.entries.length > 0
        readonly property string requestedKey: bar.notification ? "notification:" + bar.notification.notificationId : bar.activities.selectedId
        property string displayedKey: ""
        property var displayedNotification: null
        property var displayedActivity: null
        property var outgoingPage: null
        readonly property bool musicSelected: displayedKey === "music"
        readonly property bool navigationVisible: !bar.notification && !displayedNotification && bar.activities.entries.length > 1
        readonly property real contentWidth: Math.max(0, width - 48 - (!displayedNotification && bar.activities.entries.length > 1 ? 68 : 0))
        property real pageProgress: 1
        property int slideDirection: 1
        readonly property real pageOpacity: 1
        readonly property real pageOffset: slideDirection * (pageProgress - 1) * (width - 28)
        readonly property bool pageAnimating: pageMotion.running
        readonly property bool instant: bar.state.reducedMotion || Ui.Theme.animationStyle === "Off" || Ui.Theme.animationDuration === 0
        property real progress: 0
        readonly property real revealProgress: Ui.Theme.animationStyle === "Stepped" ? Math.floor(progress * 12) / 12 : progress
        readonly property bool animating: motion.running
        function syncPage() {
            displayedKey = requestedKey;
            displayedNotification = bar.notification;
            displayedActivity = bar.activities.selected;
        }
        function changePage() {
            if (pageMotion.running && !instant && requestedKey) return;
            pageMotion.stop();
            slideDirection = displayedKey.startsWith("notification:") && !bar.notification ? -1 : 1;
            if (instant || !visible || !requestedKey) {
                syncPage();
                outgoingPage = null;
                pageProgress = 1;
                return;
            }
            outgoingPage = {key: displayedKey, notification: displayedNotification, activity: displayedActivity,
                contentWidth: contentWidth, track: bar.state.track, artwork: bar.state.trackArtwork};
            syncPage();
            pageProgress = 0;
            pageMotion.start();
        }
        onRequestedKeyChanged: changePage()
        Component.onCompleted: { syncPage(); progress = opened ? 1 : 0; }
        onOpenedChanged: {
            motion.stop();
            if (instant) progress = opened ? 1 : 0;
            else { motion.to = opened ? 1 : 0; motion.start(); }
        }
        onInstantChanged: {
            if (instant) { motion.stop(); progress = opened ? 1 : 0; pageMotion.stop(); syncPage(); outgoingPage = null; pageProgress = 1; }
        }
        Connections {
            target: bar.activities
            function onSelectedChanged() {
                if (notch.displayedKey === bar.activities.selectedId)
                    notch.displayedActivity = bar.activities.selected;
            }
        }
        NumberAnimation {
            id: pageMotion
            target: notch
            property: "pageProgress"
            to: 1
            duration: Ui.Theme.animationDuration
            easing.type: Easing.InOutCubic
            onFinished: {
                notch.outgoingPage = null;
                if (notch.requestedKey !== notch.displayedKey) notch.changePage();
            }
        }
        NumberAnimation { id: motion; target: notch; property: "progress"; duration: Ui.Theme.animationDuration; easing.type: Easing.OutCubic }
        anchors.horizontalCenter: parent.horizontalCenter
        width: bar.notificationRow ? Math.min(560, bar.width - 24) : !bar.stacked && bar.notchSpace >= 160 ? Math.min(560, bar.notchSpace) : 0
        height: Ui.Theme.barHeight - (floating ? 8 : 0)
        y: (bar.notificationRow ? Ui.Theme.barHeight * (bar.stacked ? 2 : 1) : 0) + (floating ? 4 : 0) - (1 - revealProgress) * (height + (floating ? 4 : 0))
        visible: progress > 0 && width > 0
        enabled: opened
        Item {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: notch.navigationVisible ? 92 : 14
            clip: true
        Repeater {
            model: 2
        Item {
            id: pageContent
            required property int index
            readonly property bool outgoing: index === 0
            readonly property var snapshot: outgoing ? notch.outgoingPage : null
            readonly property string displayedKey: outgoing ? (snapshot ? snapshot.key : "") : notch.displayedKey
            readonly property var displayedNotification: outgoing ? (snapshot ? snapshot.notification : null) : notch.displayedNotification
            readonly property var displayedActivity: outgoing ? (snapshot ? snapshot.activity : null) : notch.displayedActivity
            readonly property bool musicSelected: displayedKey === "music"
            readonly property real contentWidth: outgoing && snapshot ? snapshot.contentWidth : notch.contentWidth
            readonly property string namePrefix: outgoing ? "outgoing-" : ""
            objectName: namePrefix + "notchPageContent"
            visible: !outgoing || !!snapshot
            x: -14 + (outgoing ? notch.slideDirection * notch.pageProgress * (notch.width - 28) : notch.pageOffset)
            width: notch.width
            height: parent.height
            opacity: notch.pageOpacity
            enabled: !outgoing && !notch.pageAnimating
        RowLayout {
            objectName: pageContent.namePrefix + "notchNotificationPage"
            visible: !!pageContent.displayedNotification
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: pageContent.contentWidth
            spacing: 8
            Accessible.role: Accessible.AlertMessage
            Accessible.ignored: pageContent.outgoing
            Accessible.name: pageContent.displayedNotification ? pageContent.displayedNotification.title + ". " + pageContent.displayedNotification.message : ""
            IconImage {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: "../../Assets/Icons/bell.svg"
                color: Ui.Theme.paper
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0
                Ui.Label { objectName: pageContent.namePrefix + "notchNotificationTitle"; Layout.fillWidth: true; text: pageContent.displayedNotification ? pageContent.displayedNotification.title : ""; font.pixelSize: 12 }
                Ui.Label { objectName: pageContent.namePrefix + "notchNotificationMessage"; Layout.fillWidth: true; text: pageContent.displayedNotification ? pageContent.displayedNotification.message : ""; color: Ui.Theme.muted; font.pixelSize: 10 }
            }
            Ui.ActionButton {
                objectName: pageContent.namePrefix + "dismissNotchNotification"
                implicitWidth: 28
                iconName: "x"
                description: "Dismiss notification"
                onClicked: {
                    if (notch.displayedNotification) bar.state.dismissNotification(notch.displayedNotification.notificationId);
                }
            }
        }
        RowLayout {
            objectName: pageContent.namePrefix + "notchMusicPage"
            visible: pageContent.musicSelected
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: pageContent.contentWidth
            spacing: 4
            Rectangle {
                objectName: pageContent.namePrefix + "barArtworkFrame"
                visible: bar.state.mediaAvailable && notch.width >= 300
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                color: Ui.Theme.groupSurface
                radius: 3
                clip: true
                Image {
                    id: artwork
                    objectName: pageContent.namePrefix + "barAlbumArt"
                    anchors.fill: parent
                    source: pageContent.outgoing && pageContent.snapshot ? pageContent.snapshot.artwork : bar.state.mediaAvailable ? bar.state.trackArtwork : ""
                    sourceSize: Qt.size(56, 56)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                IconImage {
                    objectName: pageContent.namePrefix + "barArtworkFallback"
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "../../Assets/Icons/image.svg"
                    color: Ui.Theme.muted
                    visible: artwork.status !== Image.Ready
                }
            }
            Slider {
                id: seek
                parent: pageContent
                objectName: pageContent.namePrefix + "mediaSeek"
                visible: pageContent.musicSelected && bar.state.mediaAvailable && notch.width >= 300
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                width: parent.width - 64
                height: 8
                from: 0
                to: Math.max(1, bar.state.trackDuration)
                value: bar.state.trackPosition
                stepSize: 1
                enabled: bar.state.mediaAvailable && bar.state.trackDuration > 0
                Accessible.name: "Track position"
                onMoved: bar.seekRequested(value)
                background: Rectangle {
                    x: seek.leftPadding
                    y: seek.topPadding + (seek.availableHeight - height) / 2
                    width: seek.availableWidth
                    height: 3
                    color: Ui.Theme.line
                    Rectangle { width: parent.width * seek.visualPosition; height: parent.height; color: Ui.Theme.paper }
                }
                handle: Rectangle {
                    x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                    y: seek.topPadding + (seek.availableHeight - height) / 2
                    width: 5; height: seek.activeFocus || seek.hovered || seek.pressed ? 12 : 3
                    color: Ui.Theme.paper
                }
                ToolTip.visible: hovered
                ToolTip.text: Math.floor(value / 60) + ":" + String(Math.floor(value % 60)).padStart(2, "0")
            }
            Ui.ActionButton { objectName: pageContent.namePrefix + "previousButton"; visible: bar.state.mediaAvailable && notch.width >= 300; implicitWidth: 28; iconName: "skip-back"; description: "Previous track"; enabled: bar.state.mediaAvailable; onClicked: bar.previousRequested() }
            Ui.ActionButton {
                objectName: pageContent.namePrefix + "playbackButton"
                visible: bar.state.mediaAvailable
                implicitWidth: 28
                iconName: bar.state.playing ? "circle-pause" : "circle-play"
                enabled: bar.state.mediaAvailable
                description: (bar.state.playing ? "Pause " : "Play ") + bar.state.track
                onClicked: bar.playbackRequested()
            }
            Ui.ActionButton { objectName: pageContent.namePrefix + "nextButton"; visible: bar.state.mediaAvailable && notch.width >= 300; implicitWidth: 28; iconName: "skip-forward"; description: "Next track"; enabled: bar.state.mediaAvailable; onClicked: bar.nextRequested() }
            Ui.Label {
                id: trackTitle
                objectName: pageContent.namePrefix + "barTrackTitle"
                visible: bar.state.mediaAvailable && notch.width >= 300
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: pageContent.outgoing && pageContent.snapshot ? pageContent.snapshot.track : bar.state.mediaAvailable ? bar.state.track : "No media"
                font.pixelSize: 12
                MouseArea {
                    id: trackHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
                ToolTip.visible: trackHover.containsMouse
                ToolTip.text: trackTitle.text
            }
            Ui.Label {
                objectName: pageContent.namePrefix + "barTrackTime"
                visible: bar.width >= 3000 && bar.state.mediaAvailable
                Layout.preferredWidth: 112
                font.pixelSize: 11
                color: Ui.Theme.muted
                text: Math.floor(bar.state.trackPosition / 60) + ":" + String(Math.floor(bar.state.trackPosition % 60)).padStart(2, "0") + " / " + Math.floor(bar.state.trackDuration / 60) + ":" + String(bar.state.trackDuration % 60).padStart(2, "0")
            }
        }
        RowLayout {
            objectName: pageContent.namePrefix + "notchActivityPage"
            visible: !pageContent.displayedNotification && !pageContent.musicSelected && pageContent.displayedActivity !== null
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: pageContent.contentWidth
            spacing: 6
            IconImage {
                visible: notch.width >= 300
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                source: pageContent.displayedActivity && pageContent.displayedActivity.icon ? "../../Assets/Icons/" + pageContent.displayedActivity.icon + ".svg" : ""
                color: Ui.Theme.paper
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0
                Ui.Label { objectName: pageContent.namePrefix + "notchActivityTitle"; Layout.fillWidth: true; text: pageContent.displayedActivity ? (pageContent.displayedActivity.title || "") : ""; font.pixelSize: 12 }
                Ui.Label { objectName: pageContent.namePrefix + "notchActivityDetail"; visible: notch.width >= 360; Layout.fillWidth: true; text: pageContent.displayedActivity ? (pageContent.displayedActivity.detail || "") : ""; color: Ui.Theme.muted; font.pixelSize: 10 }
            }
            Ui.ActionButton {
                objectName: pageContent.namePrefix + "notchActivityPause"
                visible: notch.width >= 240 && !!pageContent.displayedActivity && !!pageContent.displayedActivity.canPause
                implicitWidth: 28
                iconName: pageContent.displayedActivity && pageContent.displayedActivity.paused ? "play" : "pause"
                description: (notch.displayedActivity && notch.displayedActivity.paused ? "Resume " : "Pause ") + (notch.displayedActivity ? notch.displayedActivity.label : "activity")
                onClicked: bar.activities.pause(notch.displayedKey)
            }
            Ui.ActionButton {
                objectName: pageContent.namePrefix + "notchActivityStop"
                implicitWidth: 28
                iconName: "x"
                description: (notch.displayedKey === "alert" ? "Dismiss " : "Stop ") + (notch.displayedActivity ? notch.displayedActivity.label : "activity")
                onClicked: bar.activities.stop(notch.displayedKey)
            }
        }
        Rectangle {
            objectName: pageContent.namePrefix + "notchActivityProgress"
            visible: !pageContent.displayedNotification && !pageContent.musicSelected && !!pageContent.displayedActivity && pageContent.displayedActivity.progress >= 0
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            width: pageContent.contentWidth
            height: 3
            color: Ui.Theme.line
            Rectangle {
                width: parent.width * (pageContent.displayedActivity && pageContent.displayedActivity.progress >= 0 ? Math.max(0, Math.min(1, pageContent.displayedActivity.progress)) : 0)
                height: parent.height
                color: Ui.Theme.paper
            }
        }
        }
        }
        }
        RowLayout {
            objectName: "notchActivitySelector"
            visible: notch.navigationVisible
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Ui.Label { objectName: "notchActivityCount"; Layout.preferredWidth: 30; text: (bar.activities.selectedIndex + 1) + "/" + bar.activities.entries.length; color: Ui.Theme.muted; font.pixelSize: 10 }
            Ui.ActionButton {
                objectName: "notchNextActivity"
                implicitWidth: 28
                iconName: "chevron-right"
                description: "Next: " + bar.activities.nextLabel
                onClicked: bar.activities.cycle()
            }
        }
    }

    Rectangle {
        objectName: "barRight"
        readonly property bool floating: bar.state.profileSettings.floatingRightBar
        anchors.right: parent.right
        anchors.rightMargin: floating ? 12 : 0
        width: rightGroup.implicitWidth + 16
        height: Ui.Theme.barHeight - (floating ? 8 : 4)
        y: (bar.stacked ? Ui.Theme.barHeight : 0) + (floating ? 4 : 0)
        radius: Ui.Theme.barRadius
        topLeftRadius: floating ? radius : 0
        topRightRadius: floating ? radius : 0
        bottomRightRadius: floating ? radius : 0
        color: Ui.Theme.ink
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.top
            width: 8
            height: bar.stacked && !parent.floating ? Ui.Theme.barHeight : 0
            color: Ui.Theme.ink
        }
        RowLayout {
            id: rightGroup
            anchors.centerIn: parent
            spacing: bar.dense ? 2 : 4
            Ui.ActionButton {
                objectName: "barCpu"
                iconName: "cpu"
                iconOnly: false
                padding: bar.dense ? 4 : 8
                font.pixelSize: bar.dense ? 10 : 11
                Layout.preferredWidth: bar.hardwareLabels ? 96 : bar.dense ? 54 : 68
                text: (bar.hardwareLabels ? "CPU " : "") + (bar.state.telemetryAvailable ? "8%" : "N/A")
                description: "CPU / AMD Ryzen 9 9950X3D / " + (bar.state.telemetryAvailable ? "8% / Preview telemetry" : "Telemetry unavailable")
                onClicked: bar.summaryRequested()
            }
            Repeater {
                model: bar.state.gpus.length
                Ui.ActionButton {
                    required property int index
                    readonly property var gpu: bar.state.gpus[index]
                    objectName: "barGpu" + index
                    iconName: "circuit-board"
                    iconOnly: false
                    padding: bar.dense ? 4 : 8
                    font.pixelSize: bar.dense ? 10 : 11
                    Layout.preferredWidth: bar.width >= 3000 ? 260 : bar.hardwareLabels ? 144 : bar.dense ? 54 : 68
                    text: (bar.hardwareLabels ? gpu.name.replace("RTX ", "") + " " : "") + (bar.state.telemetryAvailable ? gpu.utilization + "%" + (bar.width >= 3000 ? "  " + gpu.usedGiB.toFixed(1) + "/" + gpu.totalGiB + " GiB" : "") : "N/A")
                    checked: bar.openPanel === "gpu" && bar.selectedGpu === index
                    description: gpu.name + " / " + (bar.state.telemetryAvailable ? gpu.usedGiB.toFixed(1) + " / " + gpu.totalGiB + " GiB VRAM" : "Telemetry unavailable")
                    onClicked: bar.gpuRequested(index)
                }
            }
            Ui.ActionButton {
                objectName: "aiButton"
                iconName: "bot"
                iconOnly: !bar.commandLabels
                padding: bar.dense ? 4 : 8
                Layout.preferredWidth: bar.commandLabels ? 144 : bar.dense ? 24 : 36
                checked: bar.openPanel === "ai"
                text: "AI " + bar.state.aiStatus
                description: "Local AI / vLLM " + bar.state.aiStatus
                onClicked: bar.aiRequested()
            }
            Ui.Label {
                objectName: "barAiDetails"
                visible: bar.width >= 4000
                Layout.preferredWidth: 300
                text: (bar.state.loadedModelIndex >= 0 ? bar.state.models[bar.state.loadedModelIndex] : "No model") + " / " + (bar.state.tokensPerSecond >= 0 ? bar.state.tokensPerSecond.toFixed(1) + " tok/s" : "N/A")
                color: Ui.Theme.muted
                font.pixelSize: 11
            }
            Rectangle { visible: bar.hardwareLabels; Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: Ui.Theme.line }
            Ui.ActionButton {
                objectName: "volumeButton"
                iconName: bar.state.outputMuted ? "volume-x" : "volume-2"
                iconOnly: !bar.hardwareLabels
                checked: bar.openPanel === "volume"
                padding: bar.dense ? 4 : 8
                Layout.preferredWidth: bar.hardwareLabels ? 100 : bar.dense ? 24 : 36
                text: bar.state.outputMuted ? "Muted" : bar.state.volume + "%"
                description: "Audio mixer / " + (bar.state.outputMuted ? "Output muted" : "Volume " + bar.state.volume + "%")
                onClicked: bar.volumeRequested()
            }
            Ui.ActionButton {
                objectName: "recordingIndicator"
                Layout.preferredWidth: bar.dense ? 24 : 36
                padding: bar.dense ? 4 : 8
                visible: bar.activities.recordingActive
                iconName: "circle-dot"
                checked: true
                description: (bar.activities.sharing ? "Screen sharing" : "Recording") + " / " + bar.activities.time(bar.activities.recordingSeconds) + " / Stop"
                onClicked: bar.activities.stop("recording")
            }
            Ui.ActionButton {
                objectName: "wallpaperButton"
                iconName: "image"
                iconOnly: !bar.commandLabels
                text: "Wallpaper"
                Layout.preferredWidth: bar.commandLabels ? 126 : bar.dense ? 24 : 36
                padding: bar.dense ? 4 : 8
                checked: bar.openPanel === "wallpaper"
                description: "Wallpaper"
                onClicked: bar.wallpaperRequested()
            }
        }
    }
}