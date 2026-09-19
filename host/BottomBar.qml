import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shell/Modules/Bar" as Bars

PanelWindow {
    id: root
    required property var modelData
    required property var service
    screen: modelData
    anchors { bottom: true }
    margins.bottom: 12
    implicitWidth: Math.min(bar.implicitWidth, Math.max(0, modelData.width - 24))
    implicitHeight: 52
    exclusiveZone: implicitHeight
    aboveWindows: true
    WlrLayershell.namespace: "custom-shell-bottom"
    color: "transparent"
    IpcHandler {
        target: "dock-" + root.modelData.name
        function windows(appId: string): bool { return bar.showWindows(appId); }
    }

    Bars.BottomBar {
        id: bar
        anchors.fill: parent
        compact: root.modelData.width < 720
        externalPicker: true
        manager: root.service.windowManager
        applications: root.service.applications
        onFocusRequested: windowId => root.service.windowManager.focus(windowId)
        onWindowCloseRequested: windowId => root.service.windowManager.close(windowId)
        onWindowMinimizeRequested: windowId => root.service.windowManager.minimize(windowId)
        onLauncherRequested: root.service.openLauncher()
        onWorkspaceOverviewRequested: root.service.openWorkspaceOverview()
        onCaptureRequested: root.service.captureRequested()
    }
    PopupWindow {
        id: windowPopup
        anchor.window: root
        anchor.rect.x: bar.pickerAnchor ? bar.pickerAnchor.mapToItem(bar, bar.pickerAnchor.width / 2, 0).x : bar.width / 2
        anchor.rect.y: -6
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.SlideX
        implicitWidth: Math.min(280, root.width)
        implicitHeight: Math.min(218, bar.selectedWindows.length * 34 + 4)
        visible: bar.pickerOpen && bar.selectedWindows.length > 0
        grabFocus: true
        color: "transparent"
        onVisibleChanged: if (!visible) bar.closeWindows()
        Bars.WindowPicker {
            anchors.fill: parent
            windows: bar.selectedWindows
            manager: root.service.windowManager
            onFocusRequested: windowId => { root.service.windowManager.focus(windowId); bar.closeWindows(); }
            onCloseRequested: windowId => root.service.windowManager.close(windowId)
            onMinimizeRequested: windowId => { root.service.windowManager.minimize(windowId); bar.closeWindows(); }
            onDismissRequested: bar.closeWindows()
        }
    }
}