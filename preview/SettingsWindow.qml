import QtQuick
import QtQuick.Window
import "../shell/Modules/Settings"
import "../shell/Components" as Ui

Window {
    id: window
    objectName: "settingsWindow"
    required property var service
    required property var shortcuts
    width: 920
    height: 760
    minimumWidth: 660
    minimumHeight: 540
    title: "Quickshell / Settings"
    color: Ui.Theme.clear
    visible: false
    function open() { show(); raise(); requestActivate(); }
    onVisibleChanged: if (!visible) shortcuts.recording = ""
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: window.visible && window.shortcuts.recording === ""
        onActivated: window.close()
    }
    Ui.RetroDrawer {
        objectName: "settingsDrawer"
        anchors.fill: parent
        opened: window.visible
        floating: true
        reducedMotion: window.service.reducedMotion
        onDismissRequested: window.close()
        SettingsView {
            anchors.fill: parent
            service: window.service
            shortcuts: window.shortcuts
        }
    }
}