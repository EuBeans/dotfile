import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shell/Components" as Ui

Rectangle {
    id: studio
    objectName: "studio"
    property bool ultrawide: false
    property bool oneToOne: false
    property bool specimenVisible: false
    property bool lockPreviewVisible: false
    property int customWidth: 0
    readonly property int canvasWidth: customWidth > 0 ? customWidth : ultrawide ? 5120 : 1920
    readonly property int canvasHeight: ultrawide ? 1440 : 1080
    readonly property bool fontsReady: Ui.Theme.fontsReady
    readonly property alias fixture: fixtures
    readonly property alias desktop: desktop
    signal screenshotRequested()
    color: Ui.Theme.stage

    FixtureState { id: fixtures; objectName: "fixtures" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Ui.Theme.ink
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: studio.width < 1100 ? 6 : 12
                Ui.Label { text: "PREVIEW"; font.family: Ui.Theme.displayFont; font.pixelSize: 16; visible: studio.width >= 1000 }
                Ui.Label { text: "FIXTURE / 01"; color: Ui.Theme.muted; visible: studio.width > 1100 }
                Item { Layout.fillWidth: true }
                Ui.ActionButton {
                    objectName: "primarySize"
                    text: "1920 x 1080"
                    checked: !studio.ultrawide && studio.customWidth === 0
                    onClicked: { studio.customWidth = 0; studio.ultrawide = false; }
                }
                Ui.ActionButton {
                    objectName: "ultrawideSize"
                    text: "5120 x 1440"
                    checked: studio.ultrawide && studio.customWidth === 0
                    onClicked: { studio.customWidth = 0; studio.ultrawide = true; }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: Ui.Theme.line }
                Ui.ActionButton { objectName: "fitMode"; text: "Fit"; checked: !studio.oneToOne; onClicked: studio.oneToOne = false }
                Ui.ActionButton { objectName: "actualMode"; text: "1:1"; checked: studio.oneToOne; onClicked: studio.oneToOne = true }
                Ui.Toggle {
                    objectName: "previewMusicToggle"
                    text: "Music"
                    Layout.preferredWidth: 114
                    checked: fixtures.mediaAvailable && fixtures.playing
                    Accessible.name: "Preview music playback"
                    ToolTip.visible: hovered
                    ToolTip.text: "Simulate music playback on or off"
                    onToggled: {
                        const requestedPlayback = checked;
                        if (requestedPlayback) fixtures.mediaAvailable = true;
                        fixtures.playing = requestedPlayback;
                    }
                }
                Ui.ActionButton {
                    id: notchTestButton
                    objectName: "previewNotchButton"
                    iconName: "bell"
                    description: "Test middle notch"
                    checked: notchTestMenu.visible
                    onClicked: notchTestMenu.open()
                    Menu {
                        id: notchTestMenu
                        objectName: "previewNotchMenu"
                        y: notchTestButton.height
                        width: 240
                        palette.window: Ui.Theme.ink
                        palette.text: Ui.Theme.paper
                        palette.windowText: Ui.Theme.paper
                        palette.light: Ui.Theme.hover
                        palette.midlight: Ui.Theme.hover
                        palette.highlight: Ui.Theme.paper
                        palette.highlightedText: Ui.Theme.ink
                        background: Rectangle { color: Ui.Theme.ink; border.color: Ui.Theme.line; radius: 4 }
                        MenuItem {
                            objectName: "previewNotchNotification"
                            text: enabled ? "Notification" : "Notification (filtered)"
                            enabled: !fixtures.dndEnabled && fixtures.notificationMode !== "Priority"
                            onTriggered: fixtures.notify("Build complete", "Preview notification / All checks passed")
                        }
                        MenuItem {
                            objectName: "previewNotchCritical"
                            text: "Critical notification"
                            enabled: (!fixtures.dndEnabled && fixtures.notificationMode !== "Priority") || fixtures.allowUrgent
                            onTriggered: fixtures.notify("Battery low", "Preview notification / Connect power", "critical")
                        }
                        MenuItem {
                            objectName: "previewNotchTimer"
                            text: "Timer"
                            onTriggered: { fixtures.activities.startTimer(10); fixtures.activities.selectedId = "timer"; }
                        }
                        MenuItem {
                            objectName: "previewNotchAi"
                            text: "AI task"
                            enabled: fixtures.loadedModelIndex >= 0 && !fixtures.aiBusy
                            onTriggered: { fixtures.activities.startAi(); fixtures.activities.selectedId = "ai"; }
                        }
                        MenuItem {
                            objectName: "previewNotchTransfer"
                            text: "Transfer"
                            onTriggered: { fixtures.activities.startTransfer(false); fixtures.activities.selectedId = "transfer"; }
                        }
                        MenuItem {
                            objectName: "previewNotchRecording"
                            text: "Recording"
                            onTriggered: { fixtures.activities.startRecording(false); fixtures.activities.selectedId = "recording"; }
                        }
                        MenuItem {
                            objectName: "previewNotchAlert"
                            text: "Urgent alert"
                            onTriggered: fixtures.activities.alert("Incoming call / Preview")
                        }
                        MenuSeparator {}
                        MenuItem {
                            objectName: "previewNotchClear"
                            text: "Clear notch"
                            onTriggered: { fixtures.notifications.clear(); fixtures.activities.reset(); fixtures.playing = false; }
                        }
                    }
                }
                Ui.ActionButton {
                    id: launcherButton
                    objectName: "launcherButton"
                    iconName: "search"
                    description: "Application launcher preview"
                    checked: desktop.openPanel === "launcher"
                    onClicked: desktop.togglePanel("launcher")
                }
                Ui.ActionButton {
                    id: clipboardButton
                    objectName: "clipboardButton"
                    iconName: "clipboard"
                    description: "Clipboard history preview"
                    checked: desktop.openPanel === "clipboard"
                    onClicked: desktop.togglePanel("clipboard")
                }
                Ui.ActionButton {
                    objectName: "windowSwitcherButton"
                    iconName: "refresh-cw"
                    description: "Switch open windows"
                    onClicked: desktop.cycleWindows(1)
                }
                Ui.ActionButton {
                    id: overviewButton
                    objectName: "windowOverviewButton"
                    iconName: "panels-top-left"
                    description: "Open tile manager"
                    checked: desktop.openPanel === "windows"
                    onClicked: desktop.togglePanel("windows")
                }
                Ui.ActionButton {
                    objectName: "tilingButton"
                    iconName: "square"
                    description: "Window layout preview"
                    checked: desktop.tiling.shown
                    onClicked: desktop.tiling.shown = !desktop.tiling.shown
                }
                Ui.ActionButton {
                    objectName: "specimenButton"
                    iconName: "type"
                    description: "Font specimen"
                    checked: studio.specimenVisible
                    onClicked: studio.specimenVisible = !studio.specimenVisible
                }
                Ui.ActionButton {
                    objectName: "previewLockButton"
                    iconName: "lock-keyhole"
                    description: "Lock screen preview"
                    checked: studio.lockPreviewVisible
                    onClicked: studio.lockPreviewVisible = !studio.lockPreviewVisible
                }
                Ui.ActionButton {
                    objectName: "resetButton"
                    iconName: "rotate-ccw"
                    description: "Reset fixture"
                    onClicked: { studio.lockPreviewVisible = false; fixtures.reset(); desktop.openPanel = ""; desktop.tiling.shown = false; }
                }
            }
        }
        Rectangle {
            visible: desktop.tiling.shown && !studio.lockPreviewVisible
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: Ui.Theme.ink
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12
                Ui.Dropdown {
                    objectName: "tilingMode"
                    model: ["Auto", "Split", "Columns", "Centered"]
                    currentIndex: model.indexOf(desktop.tiling.layoutMode)
                    Accessible.name: "Tiling layout"
                    onActivated: fixtures.profileSettings.setAppearance("tilingLayout", currentText)
                }
                Ui.Label { text: "Gap"; color: Ui.Theme.muted }
                Ui.ValueSlider { objectName: "tilingGap"; Layout.preferredWidth: 120; from: 0; to: 32; stepSize: 2; value: desktop.tiling.gap; Accessible.name: "Window gap"; onMoved: fixtures.profileSettings.setAppearance("tileGap", Math.round(value)) }
                Ui.Label { text: desktop.tiling.gap; Layout.preferredWidth: 24 }
                Item { Layout.fillWidth: true }
                Ui.ActionButton { objectName: "tilePromote"; iconName: "skip-back"; description: "Promote focused window"; onClicked: desktop.tiling.promote() }
                Ui.ActionButton { objectName: "tileFloating"; text: "Floating"; checked: desktop.tiling.floatingIndex === desktop.tiling.focusedIndex; onClicked: desktop.tiling.toggleFloating() }
                Ui.ActionButton { objectName: "tileMaximize"; iconName: "square"; description: "Maximize or restore focused window"; checked: desktop.tiling.maximizedIndex >= 0; onClicked: desktop.tiling.toggleMaximized() }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Flickable {
                id: viewport
                objectName: "viewport"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: Math.max(width, studio.canvasWidth * desktop.scale)
                contentHeight: Math.max(height, studio.canvasHeight * desktop.scale)
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar { policy: studio.oneToOne ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                ScrollBar.vertical: ScrollBar { policy: studio.oneToOne ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                onWidthChanged: returnToBounds()
                onHeightChanged: returnToBounds()
                DesktopPreview {
                    onScreenshotRequested: studio.screenshotRequested()
                    onLockPreviewRequested: studio.lockPreviewVisible = true
                    id: desktop
                    objectName: "desktop"
                    state: fixtures
                    visible: !studio.lockPreviewVisible
                    enabled: !studio.lockPreviewVisible
                    width: studio.canvasWidth
                    height: studio.canvasHeight
                    scale: studio.oneToOne ? 1 : Math.min(viewport.width / width, viewport.height / height)
                    transformOrigin: Item.TopLeft
                    x: Math.max(0, (viewport.width - width * scale) / 2)
                    y: Math.max(0, (viewport.height - height * scale) / 2)
                    onScaleChanged: { viewport.contentX = 0; viewport.contentY = 0; }
                    onLauncherClosed: launcherButton.forceActiveFocus()
                    onOverviewClosed: overviewButton.forceActiveFocus()
                    onClipboardClosed: clipboardButton.forceActiveFocus()
                }
                LockPreview {
                    id: lockView
                    service: fixtures
                    visible: studio.lockPreviewVisible
                    enabled: visible
                    x: desktop.x
                    y: desktop.y
                    width: desktop.width
                    height: desktop.height
                    scale: desktop.scale
                    transformOrigin: Item.TopLeft
                    onDismissed: { studio.lockPreviewVisible = false; studio.desktop.forceActiveFocus(); }
                }
            }
            Rectangle {
                visible: studio.specimenVisible
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                color: Ui.Theme.ink
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 24
                    Ui.Label { text: "TYPE / 01"; color: Ui.Theme.muted; Layout.fillWidth: true }
                    Ui.Label { text: "10:24"; font.family: Ui.Theme.displayFont; font.pixelSize: 42; Layout.fillWidth: true }
                    Ui.Label { text: "Work  1 2 4 7"; font.family: Ui.Theme.displayFont; font.pixelSize: 18; Layout.fillWidth: true }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.line }
                    Ui.Label { text: "Monocraft / Display"; color: Ui.Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
                    Ui.Label { text: "JetBrains Mono / Text"; color: Ui.Theme.muted; font.pixelSize: 12; Layout.fillWidth: true }
                    Ui.Label { text: "Build complete"; font.pixelSize: 16; Layout.fillWidth: true }
                    Ui.Label { text: "18 September 2026\nGPU 5090 / 4.2 GiB\nGPU 3080 / 1.1 GiB\nIl1 O0 {} [] <>"; lineHeight: 1.6; Layout.fillWidth: true }
                    Ui.Label { text: "a-long-wallpaper-filename.png"; font.pixelSize: 12; Layout.fillWidth: true }
                    Item { Layout.fillHeight: true }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Ui.Theme.ink
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                Ui.Label { text: fixtures.profile + " / " + fixtures.selectedWallpaper.name; color: Ui.Theme.muted; font.pixelSize: 11 }
                CheckBox {
                    objectName: "lockRejectAttempt"
                    visible: studio.lockPreviewVisible
                    text: "Reject unlock"
                    palette.windowText: Ui.Theme.paper
                    checked: lockView.rejectAttempt
                    onToggled: lockView.rejectAttempt = checked
                }
                Item { Layout.fillWidth: true }
                Ui.Label { text: "Width"; font.pixelSize: 11; color: Ui.Theme.muted }
                Slider {
                    objectName: "canvasWidthSlider"
                    Layout.preferredWidth: 180
                    from: 640
                    to: 5120
                    stepSize: 80
                    value: studio.canvasWidth
                    Accessible.name: "Simulated screen width"
                    onMoved: studio.customWidth = Math.round(value)
                }
                Ui.Label { text: Math.round(desktop.scale * 100) + "%  /  " + studio.canvasWidth + " x " + studio.canvasHeight; color: Ui.Theme.muted; font.pixelSize: 11 }
            }
        }
    }
}