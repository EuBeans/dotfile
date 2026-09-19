import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shell/Components" as Ui

FocusScope {
    id: lock
    objectName: "lockPreview"
    required property var service
    property var authenticator: null
    readonly property bool secured: authenticator !== null
    property bool rejectAttempt: false
    property bool capsLock: false
    property string status: ""
    property real reveal: 1
    readonly property bool busy: secured ? authenticator.busy : authentication.running || completion.running
    signal dismissed()
    clip: true

    function reset() {
        authentication.stop();
        completion.stop();
        password.clear();
        status = "";
        capsLock = false;
    }
    function submit() {
        if (busy || !password.text.length) return;
        if (secured) {
            authenticator.submit(password.text);
            password.clear();
            return;
        }
        password.clear();
        status = "Checking...";
        authentication.start();
    }
    onVisibleChanged: {
        reset();
        entrance.stop();
        reveal = 1;
        if (visible) {
            password.forceActiveFocus();
            if (!service.reducedMotion && Ui.Theme.animationStyle !== "Off") entrance.start();
        }
    }
    NumberAnimation { id: entrance; target: lock; property: "reveal"; from: 0; to: 1; duration: Ui.Theme.animationDuration; easing.type: Easing.OutCubic }
    onAuthenticatorChanged: reset()
    onBusyChanged: {
        if (busy && secured) password.clear();
        else if (!busy && visible) password.forceActiveFocus();
    }
    Keys.onEscapePressed: {
        password.clear();
        if (!secured) lock.dismissed();
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_CapsLock) capsLock = !capsLock;
    }
    Timer {
        id: authentication
        interval: 650
        onTriggered: {
            if (lock.secured) return;
            lock.status = lock.rejectAttempt ? "Not recognized. Try again." : "Unlocked";
            if (lock.rejectAttempt) password.forceActiveFocus();
            else completion.start();
        }
    }
    Timer { id: completion; interval: 350; onTriggered: if (!lock.secured) lock.dismissed() }

    Image {
        objectName: "lockWallpaper"
        anchors.fill: parent
        source: lock.service.selectedWallpaper.source
        fillMode: Image.PreserveAspectCrop
    }
    Rectangle { anchors.fill: parent; color: Ui.Theme.ink; opacity: 0.7 }
    MouseArea { anchors.fill: parent; onClicked: password.forceActiveFocus() }

    RowLayout {
        visible: !lock.secured
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24
        Ui.Label { text: "LOCK PREVIEW / NOT SECURED"; font.pixelSize: 10; color: Ui.Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Ui.ActionButton { objectName: "exitLockPreview"; iconName: "x"; description: "Exit lock preview"; onClicked: lock.dismissed() }
    }

    Flickable {
        id: lockScroll
        objectName: "lockScroll"
        anchors.fill: parent
        anchors.topMargin: lock.secured ? 24 : 72
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, clockBlock.height + widgets.height + login.height + 128)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        Item {
            width: lockScroll.width
            height: lockScroll.contentHeight
    ColumnLayout {
        id: clockBlock
        opacity: lock.reveal
        objectName: "lockClockBlock"
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: Math.min(520, parent.width - 48)
        spacing: 12
        Ui.Label { text: "LOCKED"; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; color: Ui.Theme.muted; font.pixelSize: 12 }
        Ui.Label {
            objectName: "lockClock"
            text: lock.service.clock
            Layout.fillWidth: true
            Layout.preferredHeight: lock.height < 700 ? 90 : 136
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Ui.Theme.displayFont
            font.pixelSize: 112
            minimumPixelSize: 44
            fontSizeMode: Text.Fit
        }
        Ui.Label {
            text: Qt.formatDate(lock.service.calendarDate, "dddd, MMMM d")
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
        Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 12; implicitWidth: 32; implicitHeight: 1; color: Ui.Theme.line }
        Ui.Label {
            text: lock.service.volume >= 0 ? "Volume " + lock.service.volume + "%" : "Volume unavailable"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 11
            color: Ui.Theme.muted
        }
    }

    LockWidgets {
        id: widgets
        service: lock.service
        opacity: lock.reveal
        anchors.horizontalCenter: parent.horizontalCenter
        y: clockBlock.y + clockBlock.height + 24
        width: Math.min(760, parent.width - 48)
        height: implicitHeight
    }

    ColumnLayout {
        id: login
        opacity: lock.reveal
        objectName: "lockLogin"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(widgets.y + widgets.height + 28, parent.height - height - 28)
        width: Math.min(560, parent.width - 48)
        spacing: 16

        RowLayout {
            objectName: "lockMedia"
            visible: lock.service.mediaAvailable
            Layout.fillWidth: true
            spacing: 12
            Image {
                source: lock.service.trackArtwork
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                fillMode: Image.PreserveAspectCrop
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 4
                Ui.Label { text: lock.service.playing ? "NOW PLAYING" : "PAUSED"; color: Ui.Theme.muted; font.pixelSize: 10; Layout.fillWidth: true }
                Ui.Label { text: lock.service.track; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0 }
            }
            Ui.ActionButton {
                objectName: "lockPlayback"
                iconName: lock.service.playing ? "pause" : "play"
                description: lock.service.playing ? "Pause music" : "Play music"
                onClicked: lock.secured ? lock.service.playbackRequested() : lock.service.playing = !lock.service.playing
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
        RowLayout {
            Layout.fillWidth: true
            Ui.Label { text: lock.secured ? lock.service.userName : "Preview user"; textFormat: Text.PlainText; font.pixelSize: 13; Layout.fillWidth: true }
            Ui.Label { text: lock.capsLock ? "CAPS LOCK" : lock.secured ? lock.service.keyboardLayout : "US"; color: Ui.Theme.muted; font.pixelSize: 10 }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Ui.TextField {
                id: password
                objectName: "lockPassword"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 44
                placeholderText: lock.secured ? "Password" : "Demo password"
                echoMode: TextInput.Password
                maximumLength: 128
                enabled: !lock.busy
                selectByMouse: false
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                color: Ui.Theme.paper
                placeholderTextColor: Ui.Theme.muted
                font.family: Ui.Theme.textFont
                font.pixelSize: 13
                leftPadding: 14
                Accessible.name: lock.secured ? "Unlock password" : "Demo password, not system authentication"
                onAccepted: lock.submit()
                onActiveFocusChanged: {
                    if (activeFocus && lock.visible)
                        Qt.callLater(() => lockScroll.contentY = Math.max(0, Math.min(lockScroll.contentHeight - lockScroll.height, login.y + login.height - lockScroll.height + 20)));
                }
            }
            Ui.ActionButton {
                objectName: "lockSubmit"
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                iconName: "chevron-right"
                description: lock.secured ? "Unlock session" : "Simulate unlock"
                enabled: password.text.length > 0 && !lock.busy
                onClicked: lock.submit()
            }
        }
        Ui.Label {
            objectName: "lockStatus"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            text: lock.secured ? lock.authenticator.status : lock.status
            textFormat: Text.PlainText
            color: Ui.Theme.muted
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.AlertMessage
        }
    }
        }
    }
}