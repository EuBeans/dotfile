import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var modelData
    required property var service
    screen: modelData
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "custom-shell-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: Quickshell.env("QUICKSHELL_HOST_WALLPAPER") !== "0" && wallpaper.status === Image.Ready
    color: "transparent"

    Image {
        id: wallpaper
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: root.service.wallpaperSourceForMonitor(root.modelData.name)
        asynchronous: true
    }
}