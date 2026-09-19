import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("capture_screenshot", ROOT / "tools/capture_screenshot.py")
capture_screenshot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture_screenshot)


class ScreenshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["QT_QPA_PLATFORM"] = "offscreen"
        os.environ["QT_QUICK_BACKEND"] = "software"
        from PySide6.QtGui import QGuiApplication
        cls.application = QGuiApplication.instance() or QGuiApplication([])

    def test_installed_capture_never_reopens_after_processing(self):
        from PySide6.QtQml import QJSEngine

        shell = Path.home() / ".config/quickshell/hyprquickshot/shell.qml"
        if not shell.exists():
            self.skipTest("HyprQuickshot is not installed")
        engine = QJSEngine()
        source = shell.read_text()
        ready = source.split("function screenReady(name) {", 1)[1].split("\n    }", 1)[0]
        finished = source.split("id: screenshotProcess", 1)[1].split("onExited: (exitCode, exitStatus) => {", 1)[1].split("\n        }", 1)[0]
        result = engine.evaluate('''
            var root = {visible:false,tempPath:"/tmp/test-capture.png"};
            var capturePhase = "capturing";
            var captureScreens = [{name:"left"},{name:"right"}];
            var readyScreens = [];
            var messages = [];
            var stopped = false;
            var Quickshell = {execDetached:function(command) {messages.push(command);}};
            var Qt = {quit:function() {stopped=true;}};
            var console = {warn:function() {}};
            var screenshotOutput = {text:JSON.stringify({success:false,error:"test failure"})};
            var screenshotError = {text:""};
            var imageReady = function(name) {%s};
            var finish = function(exitCode, exitStatus) {%s};
            imageReady("left");
        ''' % (ready, finished))
        self.assertFalse(result.isError(), result.toString())
        self.assertFalse(engine.evaluate('root.visible').toBool())
        engine.evaluate('imageReady("left")')
        self.assertFalse(engine.evaluate('root.visible').toBool())
        engine.evaluate('imageReady("right")')
        self.assertTrue(engine.evaluate('root.visible').toBool())
        engine.evaluate('capturePhase="processing"; root.visible=false; imageReady("left"); finish(1,0); capturePhase=root.capturePhase; imageReady("right")')
        self.assertFalse(engine.evaluate('root.visible').toBool())
        self.assertTrue(engine.evaluate('stopped').toBool())
        self.assertEqual(engine.evaluate('root.capturePhase').toString(), "done")
        self.assertEqual(engine.evaluate('root.captureError').toString(), "test failure")
        self.assertEqual(engine.evaluate('messages.filter(command => command[0]==="notify-send").length').toInt(), 1)
        self.assertIn("Quickshell.watchFiles = false", source)
        for outcome, title, body in (
            ({"success": True, "path": "/tmp/saved.png", "copied": True}, "Screenshot saved and copied", "Saved to /tmp/saved.png\nCopied to clipboard"),
            ({"success": False, "path": "/tmp/saved.png", "copied": False, "clipboard_error": "copy failed"}, "Screenshot saved", "Saved to /tmp/saved.png\nNot copied to clipboard\ncopy failed"),
            ({"success": True, "path": "", "copied": True}, "Screenshot copied", "Copied to clipboard"),
        ):
            engine.evaluate('messages=[]; screenshotOutput.text=' + json.dumps(json.dumps(outcome)) + '; finish(0,0)')
            self.assertEqual(engine.evaluate('messages.filter(command => command[0]==="notify-send")[0]').toVariant(), ["notify-send", title, body])

    def test_toolbar_preserves_upstream_layout(self):
        installed = Path.home() / ".config/quickshell/hyprquickshot"
        if not (installed / ".git").exists():
            self.skipTest("HyprQuickshot is not installed")
        original = subprocess.run(["git", "-C", str(installed), "show", "3b4a039087c34f75f3ba10499b64f22f456c3731:shell.qml"], check=True, capture_output=True, text=True).stdout
        source = (installed / "shell.qml").read_text()

        def toolbar(text):
            text = text.split("    WrapperRectangle {", 1)[1]
            depth = 1
            for position, character in enumerate(text):
                depth += (character == "{") - (character == "}")
                if depth == 0:
                    text = text[:position + 1]
                    break
            text = text.replace("root.targetScreen.width, root.targetScreen.height", "root.width, root.height")
            text = text.replace("root.processScreenshot", "processScreenshot").replace("if(root.mode", "if(mode")
            return [line.strip() for line in text.splitlines() if line.strip() and not line.strip().startswith(("ToolTip.", "CompactHint {"))]

        self.assertEqual(toolbar(source), toolbar(original))
        self.assertNotIn("FloatingWindow", source)
        self.assertNotIn("CaptureResult", source)

    def test_compact_capture_hint(self):
        from PySide6.QtCore import QObject, QUrl
        from PySide6.QtQml import QQmlComponent
        from PySide6.QtQuick import QQuickView
        from PySide6.QtTest import QTest

        installed = Path.home() / ".config/quickshell/hyprquickshot/src"
        if not installed.exists():
            self.skipTest("HyprQuickshot is not installed")
        view = QQuickView()
        component = QQmlComponent(view.engine())
        component.setData(('''import QtQuick
import "%s"
Rectangle {
    width: 360; height: 120; color: "#353535"
    Item {
        x: 150; y: 80; width: 60; height: 30
        CompactHint { objectName: "hint"; visible: true; delay: 0; text: "Save + copy\\n/home/user/Pictures/" + "long-directory/".repeat(20) }
    }
}''' % QUrl.fromLocalFile(str(installed)).toString()).encode(), QUrl())
        self.assertFalse(component.isError(), [error.toString() for error in component.errors()])
        root = component.create()
        self.assertIsNotNone(root)
        view.setContent(QUrl(), component, root)
        view.show()
        QTest.qWait(80)
        hint = root.findChild(QObject, "hint")
        self.assertLessEqual(hint.property("width"), 240)
        self.assertGreater(hint.property("height"), 30)
        self.assertLessEqual(hint.property("height"), 44)
        self.assertEqual(hint.property("timeout"), 4000)
        self.assertEqual(hint.property("background").property("color").name(), "#252525")
        rendered = view.grabWindow()
        self.assertFalse(rendered.isNull())
        artifacts = ROOT / ".artifacts"
        artifacts.mkdir(exist_ok=True)
        rendered.save(str(artifacts / "compact-screenshot-hint.png"))
        view.close()

    def test_scaled_and_clipped_regions(self):
        self.assertEqual(capture_screenshot.pixel_region((10, 20, 40, 30), (100, 100), (200, 150)), (20, 30, 80, 45))
        self.assertEqual(capture_screenshot.pixel_region((-10, -10, 30, 30), (100, 100), (100, 100)), (0, 0, 20, 20))
        for region in ((0, 0, 0, 30), (200, 0, 20, 20), (0, 0, float("nan"), 20)):
            with self.assertRaises(ValueError):
                capture_screenshot.pixel_region(region, (100, 100), (100, 100))

    def test_desktop_geometry_and_visible_windows(self):
        from PySide6.QtQml import QJSEngine

        geometry = Path.home() / ".config/quickshell/hyprquickshot/src/CaptureGeometry.js"
        if not geometry.exists():
            self.skipTest("HyprQuickshot is not installed")
        engine = QJSEngine()
        loaded = engine.evaluate(geometry.read_text())
        self.assertFalse(loaded.isError(), loaded.toString())
        for screens, expected in (
            ([{"x":0,"y":0,"width":5120,"height":1440,"scale":1}, {"x":1600,"y":1440,"width":1920,"height":1080,"scale":1}],
             {"x":0,"y":0,"width":5120,"height":2520,"scale":1}),
            ([{"x":-1280,"y":-180,"width":1280,"height":720,"scale":1}, {"x":0,"y":0,"width":960,"height":540,"scale":2}],
             {"x":-1280,"y":-180,"width":2240,"height":720,"scale":2}),
            ([{"x":0,"y":0,"width":1080,"height":1920,"scale":1}], {"x":0,"y":0,"width":1080,"height":1920,"scale":1}),
        ):
            self.assertEqual(engine.evaluate("desktop(" + json.dumps(screens) + ")").toVariant(), expected)
        self.assertTrue(engine.evaluate("desktop([])").isError())
        self.assertTrue(engine.evaluate("desktop([{x:0,y:0,width:0,height:10,scale:1}])").isError())
        result = engine.evaluate('''visibleWindows([
            {address:"left",monitor:0,workspace:{id:1}},
            {address:"right",monitor:1,workspace:{id:4}},
            {address:"inactive",monitor:1,workspace:{id:5}},
            {address:"special",monitor:1,workspace:{id:-98}},
            {address:"pinned",monitor:0,pinned:true,workspace:{id:9}},
            {address:"hidden",monitor:0,hidden:true,workspace:{id:1}}
        ], [{monitorId:0,workspaceId:1},{monitorId:1,workspaceId:4,specialWorkspaceId:-98}]).map(window => window.address)''')
        self.assertCountEqual(result.toVariant(), ["left", "right", "special", "pinned"])

    def test_capture_waits_for_all_monitor_metadata(self):
        from PySide6.QtQml import QJSEngine

        installed = Path.home() / ".config/quickshell/hyprquickshot"
        if not installed.exists():
            self.skipTest("HyprQuickshot is not installed")
        source = (installed / "shell.qml").read_text()
        start = source.split("function startCapture() {", 1)[1].split("\n    }", 1)[0]
        engine = QJSEngine()
        engine.evaluate((installed / "src/CaptureGeometry.js").read_text())
        result = engine.evaluate('''
            var Geometry = {desktop:desktop,visibleWindows:visibleWindows};
            var root = {failCapture:function(message) {throw Error(message);}};
            var capturePhase = "starting";
            var activeScreen = null;
            var freeze = {running:false};
            var startupTimeout = {stop:function() {}};
            var first = {id:0,name:"left",scale:1,activeWorkspace:{id:1},lastIpcObject:{x:-100,y:0}};
            var second = {id:1,name:"right",scale:2,activeWorkspace:{id:4}};
            var Hyprland = {focusedMonitor:first,toplevels:{values:[]},monitorFor:function(screen) {return screen.name==="left" ? first : second;}};
            var Quickshell = {screens:[{name:"left",width:100,height:100},{name:"right",width:200,height:100}],
                env:function() {return "";},cachePath:function(filename) {return "/tmp/"+filename;}};
            var Qt = {rect:function(x,y,width,height) {return {x:x,y:y,width:width,height:height};}};
            var start = function() {%s};
            start();
        ''' % start)
        self.assertFalse(result.isError(), result.toString())
        self.assertFalse(engine.evaluate("freeze.running").toBool())
        self.assertEqual(engine.evaluate("capturePhase").toString(), "starting")
        result = engine.evaluate("second.lastIpcObject={x:0,y:0}; start()")
        self.assertFalse(result.isError(), result.toString())
        self.assertTrue(engine.evaluate("freeze.running").toBool())
        self.assertEqual(engine.evaluate("captureScreens.length").toInt(), 2)
        self.assertEqual(engine.evaluate("freeze.command.slice(0,9)").toVariant(), ["timeout", "15", "grim", "-g", "-100,0 300x100", "-s", "2", "-l", "1"])
        self.assertEqual(engine.evaluate("desktopGeometry").toVariant(), {"x":-100,"y":0,"width":300,"height":100})
        self.assertIn('running: root.capturePhase === "starting"', source)

    def test_crop_crosses_scaled_monitor_boundary(self):
        run = subprocess.run

        def execute(command, **arguments):
            if command[0] == "wl-copy":
                self.assertTrue(arguments["stdin"].read().startswith(b"\x89PNG"))
                return subprocess.CompletedProcess(command, 0)
            return run(command, **arguments)

        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "desktop.png"
            desktop = Image.new("RGB", (384, 192), "red")
            desktop.paste("blue", (192, 0, 384, 192))
            desktop.save(source)
            with patch.object(capture_screenshot.subprocess, "run", side_effect=execute):
                result = capture_screenshot.capture(source, (72, 24, 48, 48), (192, 96), Path(directory) / "saved")
            self.assertTrue(result["success"])
            with Image.open(result["path"]) as cropped:
                self.assertEqual(cropped.size, (96, 96))
                self.assertEqual(cropped.convert("RGB").getpixel((47, 50)), (255, 0, 0))
                self.assertEqual(cropped.convert("RGB").getpixel((48, 50)), (0, 0, 255))

    def test_animated_selectors_capture_exact_release_geometry(self):
        from PySide6.QtCore import QPoint, Qt, QUrl
        from PySide6.QtGui import QColor
        from PySide6.QtQuick import QQuickView
        from PySide6.QtTest import QTest

        installed = Path.home() / ".config/quickshell/hyprquickshot/src"
        if not installed.exists():
            self.skipTest("HyprQuickshot is not installed")
        for name in ("RegionSelector", "WindowSelector"):
            view = QQuickView()
            view.setColor(QColor("white"))
            view.setResizeMode(QQuickView.SizeRootObjectToView)
            view.setSource(QUrl.fromLocalFile(str(installed / (name + ".qml"))))
            self.assertEqual(view.status(), QQuickView.Ready, [error.toString() for error in view.errors()])
            root = view.rootObject()
            selections = []
            root.regionSelected.connect(lambda *region: selections.append(region))
            view.resize(300, 200)
            view.show()
            QTest.qWait(30)
            if name == "RegionSelector":
                QTest.mousePress(view, Qt.LeftButton, Qt.NoModifier, QPoint(30, 40))
                QTest.mouseMove(view, QPoint(140, 120))
                QTest.mouseRelease(view, Qt.LeftButton, Qt.NoModifier, QPoint(170, 150))
                self.assertEqual(selections, [(30, 40, 140, 110)])
            else:
                root.setProperty("monitorX", 1600)
                root.setProperty("monitorY", 1440)
                root.setProperty("windows", [{"at": [1620, 1480], "size": [100, 80]}])
                QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, QPoint(60, 60))
                self.assertEqual(selections, [(20, 40, 100, 80)])
                QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, QPoint(250, 150))
                self.assertEqual(len(selections), 1)
            view.close()

    def test_shared_region_spans_monitor_viewports(self):
        from PySide6.QtCore import QPoint, Qt, QUrl
        from PySide6.QtQml import QQmlComponent
        from PySide6.QtQuick import QQuickView
        from PySide6.QtTest import QTest

        installed = Path.home() / ".config/quickshell/hyprquickshot/src"
        if not installed.exists():
            self.skipTest("HyprQuickshot is not installed")
        view = QQuickView()
        component = QQmlComponent(view.engine())
        component.setData(('''import QtQuick
import "%s"
Item {
    width: 600; height: 200
    property rect selectionRect: Qt.rect(0,0,0,0)
    property rect captured: Qt.rect(0,0,0,0)
    id: state
    Item {
        width: 300; height: 200; clip: true
        RegionSelector {
            width: 600; height: 200; selectionState: state
            onRegionSelected: (x,y,width,height) => state.captured = Qt.rect(x,y,width,height)
        }
    }
    Item {
        x: 300; width: 300; height: 200; clip: true
        RegionSelector {
            x: -300; width: 600; height: 200; selectionState: state
            onRegionSelected: (x,y,width,height) => state.captured = Qt.rect(x,y,width,height)
        }
    }
}''' % QUrl.fromLocalFile(str(installed)).toString()).encode(), QUrl())
        self.assertFalse(component.isError(), [error.toString() for error in component.errors()])
        root = component.create()
        self.assertIsNotNone(root)
        view.setContent(QUrl(), component, root)
        view.show()
        QTest.qWait(30)
        for start, end in ((QPoint(100, 30), QPoint(420, 160)), (QPoint(420, 160), QPoint(100, 30))):
            QTest.mousePress(view, Qt.LeftButton, Qt.NoModifier, start)
            QTest.mouseMove(view, end)
            QTest.mouseRelease(view, Qt.LeftButton, Qt.NoModifier, end)
            self.assertEqual(root.property("captured").getRect(), (100, 30, 320, 130))
            self.assertEqual(root.property("selectionRect").getRect(), (100, 30, 320, 130))
        view.close()

    def test_frozen_image_matches_each_monitor_viewport(self):
        from PySide6.QtCore import QUrl
        from PySide6.QtQml import QQmlComponent
        from PySide6.QtQuick import QQuickView
        from PySide6.QtTest import QTest

        installed = Path.home() / ".config/quickshell/hyprquickshot/src/FreezeScreen.qml"
        if not installed.exists():
            self.skipTest("HyprQuickshot is not installed")
        source = installed.read_text()
        image_block = source[source.index("    Image {"):source.rfind("}")]
        with tempfile.TemporaryDirectory() as directory:
            image_path = Path(directory) / "desktop.png"
            image = Image.new("RGB", (600, 200), "red")
            image.paste("blue", (300, 0, 600, 200))
            image.save(image_path)
            view = QQuickView()
            component = QQmlComponent(view.engine())
            component.setData(('''import QtQuick
Item {
    width: 600; height: 200
    component Monitor: Item {
        id: root
        width: 300; height: 200; clip: true
        property url screenshotSource: %s
        property rect captureGeometry: Qt.rect(-200,-100,600,200)
        property point viewportOrigin
        signal captureReady()
        signal captureFailed()
        %s
    }
    Monitor { viewportOrigin: Qt.point(-200,-100) }
    Monitor { x: 300; viewportOrigin: Qt.point(100,-100) }
}''' % (json.dumps(QUrl.fromLocalFile(str(image_path)).toString()), image_block)).encode(), QUrl())
            self.assertFalse(component.isError(), [error.toString() for error in component.errors()])
            root = component.create()
            self.assertIsNotNone(root)
            view.setContent(QUrl(), component, root)
            view.show()
            QTest.qWait(40)
            rendered = view.grabWindow()
            self.assertFalse(rendered.isNull())
            self.assertEqual(rendered.pixelColor(rendered.width() // 4, rendered.height() // 2).name(), "#ff0000")
            self.assertEqual(rendered.pixelColor(rendered.width() * 3 // 4, rendered.height() // 2).name(), "#0000ff")
            artifacts = ROOT / ".artifacts"
            artifacts.mkdir(exist_ok=True)
            rendered.save(str(artifacts / "multi-monitor-viewports.png"))
            view.close()

    def test_patch_reproduces_installed_capture(self):
        installed = Path.home() / ".config/quickshell/hyprquickshot"
        if not (installed / ".git").exists():
            self.skipTest("HyprQuickshot checkout is not installed")
        archive = subprocess.run(["git", "-C", str(installed), "archive", "3b4a039087c34f75f3ba10499b64f22f456c3731"],
                                 check=True, capture_output=True).stdout
        with tempfile.TemporaryDirectory() as directory:
            with tarfile.open(fileobj=io.BytesIO(archive)) as contents:
                contents.extractall(directory, filter="data")
            subprocess.run(["git", "-C", directory, "apply", str(ROOT / "tools/hyprquickshot.patch")], check=True, capture_output=True)
            for filename in ("shell.qml", "src/FreezeScreen.qml", "src/RegionSelector.qml", "src/WindowSelector.qml", "src/SelectionOverlay.qml", "src/CaptureGeometry.js", "src/CompactHint.qml"):
                self.assertEqual((Path(directory) / filename).read_bytes(), (installed / filename).read_bytes(), filename)

    def test_save_clipboard_only_repeat_and_failure(self):
        run = subprocess.run
        copied = []

        def execute(command, **arguments):
            if command[0] == "wl-copy":
                copied.append(arguments["stdin"].read())
                return subprocess.CompletedProcess(command, 0)
            return run(command, **arguments)

        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source "quoted".png'
            output = Path(directory) / 'new folder "quoted"'
            Image.new("RGB", (200, 100), "red").save(source)
            with patch.object(capture_screenshot.subprocess, "run", side_effect=execute):
                result = capture_screenshot.capture(source, (10, 10, 30, 20), (100, 50), output)
                self.assertTrue(result["success"])
                saved = Path(result["path"])
                with Image.open(saved) as image:
                    self.assertEqual(image.size, (60, 40))
                again = capture_screenshot.capture(source, (0, 0, 100, 50), (100, 50), output)
                self.assertNotEqual(str(saved), again["path"])
                self.assertEqual(capture_screenshot.capture(source, (0, 0, 100, 50), (100, 50))["path"], "")
                self.assertEqual(len(list(output.glob("*.png"))), 2)
                self.assertTrue(all(payload.startswith(b"\x89PNG") for payload in copied))
            self.assertTrue(source.exists())

            def fail_clipboard(command, **arguments):
                if command[0] == "wl-copy":
                    raise subprocess.CalledProcessError(1, command)
                return run(command, **arguments)

            with patch.object(capture_screenshot.subprocess, "run", side_effect=fail_clipboard):
                result = capture_screenshot.capture(source, (0, 0, 100, 50), (100, 50), output)
                self.assertFalse(result["success"])
                self.assertFalse(result["copied"])
                self.assertTrue(Path(result["path"]).is_file())
                self.assertTrue(result["clipboard_error"])
            self.assertEqual(len(list(output.glob("*.png"))), 3)
            self.assertTrue(source.exists())
            with patch.object(capture_screenshot.subprocess, "run", side_effect=execute):
                result = capture_screenshot.capture(source, (0, 0, 100, 50), (100, 50), source / "invalid")
                self.assertFalse(result["success"])
                self.assertTrue(result["copied"])
                self.assertTrue(result["save_error"])
                self.assertEqual(result["path"], "")

    def test_clipboard_owner_does_not_hold_processing_open(self):
        run = subprocess.run
        release_read, release_write = os.pipe()

        def execute(command, **arguments):
            if command[0] == "wl-copy":
                command = [sys.executable, "-c", "import os; child = os.fork(); os.read(%d, 1) if child == 0 else None; os._exit(0)" % release_read]
                arguments["pass_fds"] = (release_read,)
                arguments["timeout"] = 1
            return run(command, **arguments)

        try:
            with tempfile.TemporaryDirectory() as directory:
                source = Path(directory) / "source.png"
                Image.new("RGB", (20, 20), "red").save(source)
                with patch.object(capture_screenshot.subprocess, "run", side_effect=execute):
                    result = capture_screenshot.capture(source, (0, 0, 20, 20), (20, 20))
                self.assertTrue(result["copied"], result["clipboard_error"])
        finally:
            os.close(release_write)
            os.close(release_read)


if __name__ == "__main__":
    unittest.main()