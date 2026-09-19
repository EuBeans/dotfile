import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../../Components" as Ui

Rectangle {
    id: panel
    property bool embedded: false
    property bool showPaletteControls: true
    property string namePrefix: ""
    required property var wallpapers
    required property int selected
    required property var profileSettings
    property bool folderLoading: false
    property int directoryWallpaperCount: 0
    property var monitorNames: []
    property string targetMonitor: ""
    property string paletteStatus: ""
    onMonitorNamesChanged: if (targetMonitor && !monitorNames.includes(targetMonitor)) targetMonitor = ""
    signal selectedRequested(int index)
    signal closeRequested()
    color: embedded ? Ui.Theme.clear : Ui.Theme.surface
    border.color: embedded ? Ui.Theme.clear : Ui.Theme.surfaceEdge
    topLeftRadius: Ui.Theme.panelRadius
    topRightRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    bottomLeftRadius: Ui.Theme.panelRadius
    bottomRightRadius: Ui.Theme.floatingPanels ? Ui.Theme.panelRadius : 0
    implicitWidth: 560
    implicitHeight: 530

    FolderDialog {
        id: folderDialog
        objectName: panel.namePrefix + "wallpaperFolderDialog"
        title: "Choose wallpaper folder"
        onAccepted: panel.profileSettings.setWallpaperDirectory(selectedFolder)
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: panel.embedded ? 0 : 20
        spacing: 12
        RowLayout {
            visible: !panel.embedded
            Ui.Label { text: "Wallpaper"; font.family: Ui.Theme.displayFont; font.pixelSize: 18; Layout.fillWidth: true }
            Ui.ActionButton {
                objectName: panel.namePrefix + "closeWallpaper"
                iconName: "x"
                description: "Close wallpaper picker"
                onClicked: panel.closeRequested()
            }
        }
        RowLayout {
            visible: panel.monitorNames.length > 0
            Layout.fillWidth: true
            spacing: 8
            Ui.Label { text: "Display" }
            Ui.Dropdown {
                objectName: panel.namePrefix + "wallpaperDisplay"
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                model: ["All displays"].concat(panel.monitorNames)
                currentIndex: Math.max(0, panel.monitorNames.indexOf(panel.targetMonitor) + 1)
                Accessible.name: "Wallpaper display"
                onActivated: index => panel.targetMonitor = index > 0 ? panel.monitorNames[index - 1] : ""
            }
            Ui.ActionButton {
                objectName: panel.namePrefix + "resetMonitorWallpaper"
                iconName: "x"
                description: "Use default wallpaper for this display"
                enabled: panel.targetMonitor !== "" && Object.prototype.hasOwnProperty.call(panel.profileSettings.currentProfile.wallpaperFiles || {}, panel.targetMonitor)
                onClicked: panel.profileSettings.selectMonitorWallpaper(panel.targetMonitor, "")
            }
        }
        RowLayout {
            visible: panel.showPaletteControls
            Ui.Label { text: "Palette"; Layout.fillWidth: true }
            Repeater {
                model: ["Saved", "Wallpaper"]
                Ui.ActionButton {
                    required property string modelData
                    objectName: panel.namePrefix + "wallpaperSource" + modelData
                    text: modelData
                    checked: panel.profileSettings.currentProfile.source === modelData
                    onClicked: {
                        if (modelData === "Wallpaper") panel.profileSettings.useWallpaperPalette(panel.targetMonitor);
                        else panel.profileSettings.update("source", modelData);
                    }
                }
            }
        }
        RowLayout {
            visible: panel.showPaletteControls
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: panel.profileSettings.paletteNames
                Ui.ActionButton {
                    id: swatch
                    required property string modelData
                    objectName: panel.namePrefix + "wallpaperPalette" + modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitWidth: 70
                    implicitHeight: 46
                    description: modelData
                    checked: panel.profileSettings.currentProfile.source === "Saved" && panel.profileSettings.currentProfile.palette === modelData
                    contentItem: Column {
                        spacing: 5
                        Rectangle {
                            width: parent.width
                            height: 10
                            radius: 2
                            color: panel.profileSettings.palettes[swatch.modelData].accent
                        }
                        Ui.Label {
                            width: parent.width
                            text: swatch.modelData
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            color: swatch.checked ? Ui.Theme.ink : Ui.Theme.paper
                        }
                    }
                    onClicked: {
                        panel.profileSettings.update("palette", modelData);
                        panel.profileSettings.update("source", "Saved");
                    }
                }
            }
        }
        Ui.Label {
            objectName: panel.namePrefix + "wallpaperPaletteStatus"
            Layout.fillWidth: true
            visible: panel.showPaletteControls && panel.profileSettings.currentProfile.source === "Wallpaper" && panel.paletteStatus !== ""
            text: panel.paletteStatus
            font.pixelSize: 12
            color: Ui.Theme.muted
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.Label {
                objectName: panel.namePrefix + "wallpaperFolderPath"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: panel.profileSettings.wallpaperDirectory ? decodeURIComponent(panel.profileSettings.wallpaperDirectory.substring(7)) : "Bundled wallpapers"
                font.pixelSize: 12
                color: Ui.Theme.muted
            }
            Ui.ActionButton {
                objectName: panel.namePrefix + "chooseWallpaperFolder"
                iconName: "folder-open"
                description: "Choose wallpaper folder"
                onClicked: folderDialog.open()
            }
            Ui.ActionButton {
                objectName: panel.namePrefix + "clearWallpaperFolder"
                iconName: "x"
                description: "Clear wallpaper folder"
                enabled: panel.profileSettings.wallpaperDirectory !== ""
                onClicked: panel.profileSettings.setWallpaperDirectory("")
            }
        }
        Ui.Label {
            objectName: panel.namePrefix + "wallpaperFolderStatus"
            Layout.fillWidth: true
            text: panel.folderLoading ? "Loading folder..." : panel.profileSettings.wallpaperDirectory && panel.directoryWallpaperCount === 0 ? "No supported images found in folder" : panel.wallpapers.length + " wallpapers"
            color: Ui.Theme.muted
            font.pixelSize: 12
        }
        GridView {
            id: grid
            objectName: panel.namePrefix + "wallpaperGrid"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: panel.wallpapers
            cellWidth: width / Math.max(1, Math.floor(width / 150))
            cellHeight: 144
            currentIndex: panel.selected
            keyNavigationEnabled: true
            ScrollBar.vertical: ScrollBar {}
            delegate:
                Button {
                    id: tile
                    required property var modelData
                    required property int index
                    objectName: panel.namePrefix + "wallpaperTile" + index
                    width: grid.cellWidth - 8
                    height: grid.cellHeight - 8
                    padding: 6
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: modelData.name
                    Accessible.role: Accessible.RadioButton
                    Accessible.checkable: true
                    Accessible.checked: panel.selected === index
                    background: Rectangle {
                        color: panel.selected === tile.index ? Ui.Theme.paper : tile.hovered ? Ui.Theme.hover : Ui.Theme.clear
                        border.width: tile.activeFocus ? Ui.Theme.controlBorderWidth(tile) : 0
                        border.pixelAligned: false
                        border.color: Ui.Theme.muted
                        radius: Ui.Theme.radius
                    }
                    contentItem: ColumnLayout {
                        spacing: 10
                        Image {
                            id: thumbnail
                            source: tile.modelData.source
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceSize.width: 320
                            Ui.Label {
                                anchors.centerIn: parent
                                text: "Unavailable"
                                visible: thumbnail.status === Image.Error
                                color: panel.selected === tile.index ? Ui.Theme.ink : Ui.Theme.muted
                            }
                        }
                        Ui.Label {
                            text: tile.modelData.name
                            color: panel.selected === tile.index ? Ui.Theme.ink : Ui.Theme.paper
                            Layout.fillWidth: true
                            font.pixelSize: 12
                        }
                    }
                    onClicked: {
                        if (thumbnail.status !== Image.Ready) return;
                        grid.currentIndex = index;
                        panel.selectedRequested(index);
                    }
                }
        }
    }
}