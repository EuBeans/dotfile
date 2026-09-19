import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "overview.sh"
OVERVIEW = ROOT / "third_party" / "quickshell-overview" / "shell.qml"


class OverviewCommandTests(unittest.TestCase):
    def test_large_remote_monitor_preview_reaches_drop_target(self):
        from PySide6.QtCore import QPoint, Qt, QUrl
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtQml import QQmlComponent
        from PySide6.QtQuick import QQuickView
        from PySide6.QtTest import QTest

        os.environ["QT_QPA_PLATFORM"] = "offscreen"
        os.environ["QT_QUICK_BACKEND"] = "software"
        application = QGuiApplication.instance() or QGuiApplication([])
        source = (OVERVIEW.parent / "modules/overview/OverviewWidget.qml").read_text()
        area = source.split("id: dragArea", 1)[1].split("StyledToolTip {", 1)[0]
        area = area.replace("GlobalStates", "states").replace("Hyprland", "compositor")
        drop = source.split("                            DropArea {", 1)[1].split("\n                            }", 1)[0]
        view = QQuickView()
        component = QQmlComponent(view.engine())
        component.setData(('''import QtQuick
Item {
    id: root
    width: 640; height: 340
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingTargetSpecialWorkspace: ""
    property string createSpecialWorkspaceTarget: "__create_special_workspace__"
    property var moves: []
    property alias windowData: window.windowData
    property alias hovered: window.hovered
    property alias workspaceValue: targetWorkspace.workspaceValue
    property alias hoveredWhileDragging: targetWorkspace.hoveredWhileDragging
    QtObject { id: states; property string overviewSelectedAddress: ""; property bool overviewOpen: true }
    QtObject { id: compositor; property bool usingLua: true; function dispatch(command) { throw Error("Unexpected activation"); } }
    QtObject { id: panelWindow; function moveWindow(data, destination) { root.moves = root.moves.concat([{address:data.address,destination:destination}]); } }
    Rectangle {
        id: targetWorkspace
        x: 320; y: 0; width: 300; height: 150
        property int workspaceValue: 2
        property bool hoveredWhileDragging: false
        DropArea { %s }
    }
    Rectangle {
        id: window
        x: initX; y: initY; width: 295; height: 140
        property real initX: 0
        property real initY: 180
        property bool dragInProgress: false
        property bool pressed: false
        property bool hovered: false
        property var windowData: ({address:"0xabc",class:"kitty",monitor:1,workspace:{id:4}})
        z: dragInProgress || states.overviewSelectedAddress === windowData.address ? 100 : 1
        Timer { id: updateWindowPosition; interval: 1 }
        MouseArea { id: dragArea %s }
    }
}''' % (drop, area)).encode(), QUrl())
        self.assertFalse(component.isError(), [error.toString() for error in component.errors()])
        root = component.create()
        self.assertIsNotNone(root)
        view.setContent(QUrl(), component, root)
        view.show()
        QTest.qWait(30)
        QTest.mousePress(view, Qt.LeftButton, Qt.NoModifier, QPoint(150, 240))
        QTest.mouseMove(view, QPoint(180, 230))
        QTest.mouseMove(view, QPoint(400, 60))
        QTest.mouseRelease(view, Qt.LeftButton, Qt.NoModifier, QPoint(400, 60))
        self.assertEqual(root.property("moves").toVariant(), [{"address": "0xabc", "destination": 2}])
        view.close()
        application.processEvents()

    def test_selected_window_frame_is_visible_and_bounded(self):
        from PySide6.QtCore import QObject, QUrl
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtQml import QQmlComponent
        from PySide6.QtQuick import QQuickView
        from PySide6.QtTest import QTest

        os.environ["QT_QPA_PLATFORM"] = "offscreen"
        os.environ["QT_QUICK_BACKEND"] = "software"
        application = QGuiApplication.instance() or QGuiApplication([])
        view = QQuickView()
        view.engine().rootContext().setContextProperty("Appearance", {"colors": {"colSecondary": "#65e5bf"}, "m3colors": {"m3onSecondary": "#101817"}})
        source = (OVERVIEW.parent / "modules/overview/OverviewWindow.qml").read_text()
        frame = source.split('    Rectangle {\n        id: selectionFrame', 1)[1].split('    Item {\n        id: previewMask', 1)[0]
        component = QQmlComponent(view.engine())
        component.setData(('''import QtQuick
Rectangle {
    id: root
    width: 300; height: 150; color: "#252525"
    property bool selected: true
    property var windowData: ({title:"A very long selected window title ".repeat(10)})
    Rectangle { id: selectionFrame %s
}''' % frame).encode(), QUrl())
        self.assertFalse(component.isError(), [error.toString() for error in component.errors()])
        root = component.create()
        self.assertIsNotNone(root)
        view.setContent(QUrl(), component, root)
        view.show()
        QTest.qWait(30)
        image = view.grabWindow()
        self.assertEqual(image.pixelColor(2, 50).name(), "#65e5bf")
        title = root.findChild(QObject, "overviewSelectedTitle")
        self.assertLessEqual(title.property("width"), 300)
        root.setProperty("selected", False)
        self.assertFalse(root.findChild(QObject, "overviewSelectionFrame").property("visible"))
        artifacts = ROOT / ".artifacts"
        artifacts.mkdir(exist_ok=True)
        image.save(str(artifacts / "overview-selection-frame.png"))
        view.close()
        application.processEvents()

    def test_tooltip_is_compact_and_theme_colored(self):
        from PySide6.QtCore import QUrl
        from PySide6.QtGui import QGuiApplication
        from PySide6.QtQml import QQmlComponent, QQmlEngine

        os.environ["QT_QPA_PLATFORM"] = "offscreen"
        application = QGuiApplication.instance() or QGuiApplication([])
        engine = QQmlEngine()
        source = (OVERVIEW.parent / "common/widgets/StyledToolTipContent.qml").read_text()
        source = source.replace('import "."', '').replace('import "../"', '').replace('StyledText {', 'Text {')
        source = source.replace('Appearance?.colors.colTooltip ?? "#3C4043"', '"#202421"')
        source = source.replace('Appearance?.colors.colOnTooltip ?? "#FFFFFF"', '"#efefeb"')
        component = QQmlComponent(engine)
        component.setData(source.encode(), QUrl())
        self.assertFalse(component.isError(), [error.toString() for error in component.errors()])
        item = component.createWithInitialProperties({"text": "A very long window title " * 40, "shown": True})
        self.assertIsNotNone(item)
        application.processEvents()
        self.assertLessEqual(item.property("implicitWidth"), 240)
        self.assertLessEqual(item.property("implicitHeight"), 44)
        self.assertIn('Appearance?.colors.colTooltip', (OVERVIEW.parent / "common/widgets/StyledToolTipContent.qml").read_text())
        item.deleteLater()
        application.processEvents()

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.bin = Path(self.directory.name)
        self.executable = self.bin / "quickshell"
        self.executable.write_text('#!/bin/bash\nprintf "%s\\n" "$@"\n', encoding="utf-8")
        self.executable.chmod(0o755)
        self.environment = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.defpath,
                                HYPRLAND_INSTANCE_SIGNATURE="test-session")

    def run_action(self, *arguments):
        return subprocess.run(["/bin/bash", str(SCRIPT), *arguments], env=self.environment,
                              capture_output=True, text=True, check=False)

    def test_start_is_single_instance_and_uses_pinned_checkout(self):
        result = self.run_action("start")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["-p", str(OVERVIEW), "-n"])

    def test_keyboard_patch_applies_to_pinned_checkout(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = subprocess.Popen(["git", "-C", str(OVERVIEW.parent), "archive", "HEAD"], stdout=subprocess.PIPE)
            try:
                subprocess.run(["tar", "-x", "-C", folder], stdin=archive.stdout, check=True)
            finally:
                archive.stdout.close()
                self.assertEqual(archive.wait(), 0)
            patch = str(ROOT / "tools/overview-keyboard.patch")
            subprocess.run(["git", "-C", folder, "apply", "--check", patch], check=True)
            subprocess.run(["git", "-C", folder, "apply", patch], check=True)
            for name in ("modules/overview/OverviewKeyboard.js", "modules/overview/Overview.qml",
                         "modules/overview/OverviewWindow.qml", "modules/overview/OverviewWidget.qml",
                         "common/Config.qml", "services/GlobalStates.qml",
                         "common/widgets/StyledToolTip.qml", "common/widgets/StyledToolTipContent.qml"):
                self.assertEqual((Path(folder) / name).read_text(), (OVERVIEW.parent / name).read_text())

    def test_actions_use_same_ipc_config(self):
        for action in ("toggle", "open", "close"):
            with self.subTest(action=action):
                result = self.run_action(action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(),
                                 ["ipc", "-p", str(OVERVIEW), "call", "overview", action])
        self.assertEqual(self.run_action().stdout, self.run_action("toggle").stdout)

    def test_native_session_cannot_launch_overview(self):
        self.environment.pop("HYPRLAND_INSTANCE_SIGNATURE")
        result = self.run_action("start")
        self.assertEqual(result.returncode, 1)
        self.assertIn("requires a running Hyprland session", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_unrecognized_commands_are_rejected(self):
        for arguments in (("invalid",), ("toggle", "extra")):
            result = self.run_action(*arguments)
            self.assertEqual(result.returncode, 2)
            self.assertIn("Usage:", result.stderr)
            self.assertEqual(result.stdout, "")

    def test_child_failure_is_returned(self):
        self.executable.write_text("#!/bin/bash\nexit 7\n", encoding="utf-8")
        self.assertEqual(self.run_action("toggle").returncode, 7)


if __name__ == "__main__":
    unittest.main()