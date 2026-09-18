import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Components" as Ui

Rectangle {
    id: panel
    objectName: "systemSummary"
    required property var service
    property bool pinned: false
    property bool tiled: false
    property bool embedded: false
    signal pinRequested(bool pinned)
    signal closeRequested()
    signal tileRequested()
    signal floatRequested()
    signal moveRequested(real deltaX, real deltaY)
    implicitWidth: 780
    implicitHeight: 430
    color: embedded ? "transparent" : Ui.Theme.surface
    border.color: embedded ? "transparent" : Ui.Theme.surfaceEdge
    radius: embedded ? 0 : Ui.Theme.panelRadius

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: panel.embedded ? 0 : 20
        spacing: 14
        RowLayout {
            visible: !panel.embedded
            Layout.fillWidth: true
            Ui.Label {
                text: "System"
                font.family: Ui.Theme.displayFont
                font.pixelSize: 18
                Layout.fillWidth: true
                MouseArea {
                    objectName: "summaryDrag"
                    anchors.fill: parent
                    enabled: !panel.tiled
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point previousPoint
                    onPressed: mouse => previousPoint = mapToGlobal(mouse.x, mouse.y)
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        const point = mapToGlobal(mouse.x, mouse.y);
                        panel.moveRequested(point.x - previousPoint.x, point.y - previousPoint.y);
                        previousPoint = point;
                    }
                }
            }
            Ui.ActionButton { objectName: "summaryTile"; iconName: "panels-top-left"; description: panel.tiled ? "Arrange summary tile" : "Place in tiles"; onClicked: panel.tileRequested() }
            Ui.ActionButton { objectName: "summaryFloat"; visible: panel.tiled; iconName: "square"; description: "Return to desktop widget"; onClicked: panel.floatRequested() }
            Ui.ActionButton { objectName: "summaryPin"; visible: !panel.tiled; iconName: "pin"; checked: panel.pinned; description: "Pin system summary"; onClicked: panel.pinRequested(!panel.pinned) }
            Ui.ActionButton { objectName: "closeSummary"; iconName: "x"; description: "Close system summary"; onClicked: panel.closeRequested() }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24
            Image {
                objectName: "summaryArtwork"
                visible: panel.width >= (panel.embedded ? 500 : 620)
                source: panel.service.selectedWallpaper.source
                Layout.preferredWidth: panel.embedded ? 112 : 180
                Layout.fillHeight: true
                fillMode: Image.PreserveAspectCrop
                clip: true
            }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    ColumnLayout {
                        Layout.fillWidth: true
                        Ui.Label { text: "CachyOS"; font.family: Ui.Theme.displayFont; font.pixelSize: 22; Layout.fillWidth: true }
                        Ui.Label { text: "Hyprland / Quickshell"; Layout.fillWidth: true }
                        Ui.Label { text: "Configured target / preview data"; color: Ui.Theme.muted; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    }
                }
                Ui.Label { text: "System / Desktop"; color: Ui.Theme.accent; font.pixelSize: 12 }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                Repeater {
                    model: [
                        {label: "CPU", value: "AMD Ryzen 9 9950X3D"},
                        {label: "Kernel", value: "Unavailable"},
                        {label: "Uptime", value: "Unavailable"},
                        {label: "Memory", value: "Unavailable"},
                        {label: "Disks", value: "Unavailable"},
                        {label: "Primary", value: "1920 x 1080 / 144 Hz (configured)"},
                        {label: "Upper", value: "5120 x 1440 / mode unverified"}
                    ]
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Ui.Label { text: modelData.label; color: Ui.Theme.muted; Layout.preferredWidth: 78; font.pixelSize: 12 }
                        Ui.Label { objectName: "summary" + modelData.label; text: modelData.value; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12 }
                    }
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Ui.Theme.line }
                Ui.Label { text: "Graphics / Preview"; color: Ui.Theme.accent; font.pixelSize: 12 }
                Repeater {
                    model: panel.service.gpus
                    ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Ui.Label { text: modelData.name; Layout.fillWidth: true }
                            Ui.Label { objectName: "summaryGpuUsage" + index; text: panel.service.telemetryAvailable ? modelData.usedGiB.toFixed(1) + " / " + modelData.totalGiB + " GiB" : "Unavailable"; font.pixelSize: 12; color: Ui.Theme.muted }
                        }
                    }
                }
            }
        }
        }
    }
}