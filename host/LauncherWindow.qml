import QtQuick
import QtCore
import Quickshell
import Quickshell.Wayland
import "../shell/Modules/Launcher" as Apps
import "../shell/Components" as Ui

PanelWindow {
    id: root
    required property var modelData
    required property var service
    screen: modelData
    anchors { top: true }
    margins.top: 80
    implicitWidth: Math.min(668, modelData.width - 24)
    implicitHeight: Math.min(460, modelData.height - 160)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "custom-shell-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: service.launcherOpen && service.launcherScreen === modelData.name
    color: "transparent"

    Loader {
        anchors.fill: parent
        active: root.visible
        sourceComponent: Apps.Launcher {
            applications: root.service.launcherApplications
            windows: root.service.windowManager.windows
            modes: ["Apps", "Windows"]
            settingsLocation: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/quickshell-host/launcher.ini"
            color: Ui.Theme.ink
            opened: root.visible
            onLaunchRequested: appId => root.service.launchApplication(appId)
            onWindowRequested: windowId => {
                root.service.windowManager.focus(windowId);
                root.service.launcherOpen = false;
            }
            onCloseRequested: root.service.launcherOpen = false
        }
    }
}