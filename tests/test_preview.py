import os
import sys
import tempfile
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QEvent, QObject, QPointF, QProcess, Qt, QUrl
from PySide6.QtGui import QAccessible, QColor, QGuiApplication, QImage, QKeyEvent
from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
from tools.wallpaper_palette import attach_palette_backend


ROOT = Path(__file__).resolve().parents[1]


class PreviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.app.setOrganizationName("CustomQuickshellTests")
        cls.app.setApplicationName("PreviewTests")

    def setUp(self):
        self.config = tempfile.TemporaryDirectory()
        self.previous_config = os.environ.get("XDG_CONFIG_HOME")
        os.environ["XDG_CONFIG_HOME"] = self.config.name
        self.warnings = []
        self.engine = QQmlApplicationEngine()
        self.engine.warnings.connect(lambda messages: self.warnings.extend(str(message) for message in messages))
        self.engine.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        self.assertTrue(self.engine.rootObjects(), "QML host failed to load")
        self.window = self.engine.rootObjects()[0]
        self.palette_backend = attach_palette_backend(self.engine)
        self.settings_window = self.window.findChild(QObject, "settingsWindow")
        QTest.qWait(100)
        self.studio = self.item("studio")
        self.fixtures = self.window.findChild(QObject, "fixtures")

    def tearDown(self):
        self.palette_backend.stop()
        self.settings_window.close()
        self.window.close()
        self.engine.deleteLater()
        self.app.processEvents()
        if self.previous_config is None:
            os.environ.pop("XDG_CONFIG_HOME", None)
        else:
            os.environ["XDG_CONFIG_HOME"] = self.previous_config
        self.config.cleanup()
        self.assertEqual(self.warnings, [])

    def item(self, name, root=None):
        if root is not None:
            ancestor = root
            while ancestor.parentItem() is not None:
                ancestor = ancestor.parentItem()
            window = self.settings_window if ancestor == self.settings_window.contentItem() else self.window
            pending = [(window, root)]
        else:
            pending = [(self.window, self.window.contentItem()), (self.settings_window, self.settings_window.contentItem())]
        while pending:
            window, item = pending.pop()
            if item.objectName() == name:
                self.item_window = window
                return item
            pending.extend((window, child) for child in item.childItems())
        self.fail(f"Missing visual item: {name}")

    def click(self, name, root=None):
        item = self.item(name, root)
        self.assertTrue(item.isVisible())
        point = item.mapToScene(QPointF(item.width() / 2, item.height() / 2)).toPoint()
        QTest.mouseClick(self.item_window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, point)
        QTest.qWait(30)

    def home_action(self, name):
        if self.item("desktop").property("openPanel") != "controls":
            self.click("controlsButton")
            QTest.qWait(280)
        if name in ("homeWallpaper", "homeProfilesTab", "homeColorsTab"):
            if not self.item("homePanel").property("personalizing"):
                self.item("homePanel").setProperty("page", "Appearance")
                QTest.qWait(30)
        self.click(name)

    def cycle_profile(self):
        QTest.keyClick(self.window, Qt.Key.Key_G, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.AltModifier)
        QTest.qWait(30)
        self.confirm_profile()

    def confirm_profile(self):
        QTest.qWait(180)
        if any(dialog.property("visible") for dialog in self.window.findChildren(QObject, "profileSwitchDialog")):
            self.click("profileApplyKeep", self.window.contentItem())
        QTest.qWait(180)

    def open_settings(self):
        self.item("desktop").setProperty("openPanel", "")
        QTest.keyClick(self.window, Qt.Key.Key_S, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.AltModifier)
        QTest.qWait(280)
        self.assertTrue(self.settings_window.isVisible())

    def capture(self, name, window=None):
        folder = ROOT / ".artifacts"
        folder.mkdir(exist_ok=True)
        image = (window or self.window).grabWindow()
        self.assertFalse(image.isNull())
        colors = {image.pixelColor(column, row).name()
                  for column in range(0, image.width(), 25)
                  for row in range(0, image.height(), 25)}
        self.assertGreater(len(colors), 3, "Rendered window is unexpectedly blank")
        self.assertTrue(image.save(str(folder / f"{name}.png")))

    def set_test_monitors(self):
        manager = self.window.findChild(QObject, "windowManager")
        manager.setProperty("screens", [{"name": "DP-1"}, {"name": "HDMI-A-1"}])
        self.app.processEvents()

    def test_bottom_bar_groups_and_focus(self):
        self.set_test_monitors()
        self.fixtures.setProperty("reducedMotion", True)
        bar = self.item("bottomBar")
        initial_width = bar.width()
        self.assertLess(initial_width, 720)
        self.assertEqual(bar.width(), bar.implicitWidth())
        for name in ("bottomModeApps", "bottomModeWorkspaces", "bottomScope", "summaryButton"):
            self.assertIsNone(self.window.findChild(QObject, name))
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("testManager", self.engine.newQObject(manager))
        self.click("bottomWorkspace4")
        self.assertEqual(self.fixtures.property("workspace"), 4)
        self.assertTrue(self.item("bottomWorkspace4").property("checked"))
        self.assertFalse(self.item("bottomWorkspace1").property("checked"))
        self.assertEqual(self.item("bottomEntries").property("count"), 3)
        self.assertEqual(bar.width(), bar.implicitWidth())
        self.click("bottomApp_browser")
        self.assertEqual(manager.property("focusedId"), 1)
        self.assertEqual(self.fixtures.property("workspace"), 1)
        self.assertTrue(self.item("bottomWorkspace1").property("checked"))
        self.engine.evaluate('testManager.open("browser")')
        QTest.qWait(50)
        self.assertEqual(self.item("bottomEntries").property("count"), 3)
        self.assertIn("(2)", self.item("bottomApp_browser").property("text"))
        self.click("bottomApp_browser")
        self.click("bottomWindow1")
        self.assertEqual(manager.property("focusedId"), 1)
        self.engine.evaluate('testManager.move(1, "HDMI-A-1", 4); testManager.move(3, "DP-1", 2)')
        QTest.qWait(50)
        self.assertEqual(self.item("bottomEntries").property("count"), 3)
        self.click("bottomApp_browser")
        self.assertIn("WS 4 / HDMI-A-1", self.item("bottomWindow1").property("text"))
        self.click("bottomWindow1")
        self.assertEqual(manager.property("activeMonitor"), "HDMI-A-1")
        self.assertEqual(manager.property("activeWorkspace"), 4)
        self.assertTrue(self.item("bottomApp_browser").property("checked"))
        self.engine.evaluate('testManager.open("terminal")')
        QTest.qWait(50)
        self.assertEqual(self.item("bottomEntries").property("count"), 3)
        self.assertIn("(2)", self.item("bottomApp_terminal").property("text"))
        self.click("bottomApp_terminal")
        self.click("bottomWindow2")
        self.assertEqual(manager.property("focusedId"), 2)
        self.assertEqual(manager.property("activeMonitor"), "DP-1")
        for width in (320, 375, 414, 768, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(40)
            bar = self.item("bottomBar")
            self.assertGreaterEqual(bar.x(), 0)
            self.assertLessEqual(bar.x() + bar.width(), width)
            for name in ("bottomLauncher", "bottomWorkspace1", "bottomWorkspace2", "bottomWorkspace4", "bottomWorkspace7", "captureButton"):
                button = self.item(name)
                self.assertGreaterEqual(button.mapToItem(bar, QPointF(0, 0)).x(), 0)
                self.assertLessEqual(button.mapToItem(bar, QPointF(button.width(), 0)).x(), bar.width())
            self.item("bottomWorkspace2").forceActiveFocus()
            QTest.keyClick(self.window, Qt.Key.Key_Space)
            self.assertEqual(manager.property("activeWorkspace"), 2)
            self.assertTrue(self.item("bottomWorkspace2").property("checked"))
            self.item("bottomEntries").positionViewAtEnd()
            QTest.qWait(30)
            self.click("bottomApp_terminal")
            surface = self.item("bottomPickerSurface")
            self.assertLessEqual(surface.width(), 280)
            self.assertEqual(surface.height(), 72)
            self.assertLess(surface.mapToScene(QPointF(0, surface.height())).y(), bar.mapToScene(QPointF(0, 0)).y())
            self.assertGreaterEqual(surface.mapToScene(QPointF(0, 0)).x(), bar.mapToScene(QPointF(0, 0)).x() - 1)
            self.assertLessEqual(surface.mapToScene(QPointF(surface.width(), 0)).x(), bar.mapToScene(QPointF(bar.width(), 0)).x() + 1)
            self.assertEqual(self.item("bottomWindow2").height(), 30)
            self.assertEqual(self.item("bottomWindow4").y() - self.item("bottomWindow2").y(), 34)
            self.capture("bottom-picker-" + str(width))
            QTest.keyClick(self.window, Qt.Key.Key_Escape)
            self.assertTrue(self.item("bottomApp_terminal").hasActiveFocus())
            self.capture("bottom-apps-" + str(width))
        self.engine.evaluate('for (const window of testManager.windows.slice()) testManager.close(window.windowId)')
        QTest.qWait(30)
        self.assertEqual(self.item("bottomEntries").property("count"), 0)
        self.assertLess(bar.width(), initial_width)
        self.click("bottomLauncher")
        self.assertEqual(self.item("desktop").property("openPanel"), "launcher")

    def test_bottom_bar_close_windows(self):
        self.fixtures.setProperty("reducedMotion", True)
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("testManager", self.engine.newQObject(manager))
        self.engine.evaluate('testManager.open("browser")')
        QTest.qWait(50)
        self.click("bottomApp_browser")
        self.click("bottomWindowClose1")
        self.assertFalse(self.engine.evaluate('testManager.windows.some(window => window.windowId === 1)').toBool())
        self.assertEqual(self.engine.evaluate('testManager.windows.filter(window => window.appId === "browser").length').toInt(), 1)
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.click("bottomClose_browser")
        self.assertEqual(self.engine.evaluate('testManager.windows.filter(window => window.appId === "browser").length').toInt(), 0)
        self.assertEqual(self.item("bottomEntries").property("count"), 2)

    def test_bottom_bar_minimize_and_restore_controls(self):
        self.fixtures.setProperty("reducedMotion", True)
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("minimizeManager", self.engine.newQObject(manager))
        self.engine.evaluate('minimizeManager.open("browser")')
        QTest.qWait(30)
        self.click("bottomApp_browser")
        picker = self.item("bottomPickerSurface")
        self.engine.globalObject().setProperty("minimizePicker", self.engine.newQObject(picker))
        self.engine.evaluate('minimizePicker.manager = Object.assign({}, minimizePicker.manager, {controlsEnabled:true,busy:false,minimize:function() {}});')
        QTest.qWait(30)
        requested = []
        restored = []
        picker.minimizeRequested.connect(requested.append)
        picker.focusRequested.connect(restored.append)
        button = self.item("bottomWindowMinimize1")
        self.assertTrue(button.isVisible())
        self.click("bottomWindowMinimize1")
        self.assertEqual(requested, [1])
        self.engine.evaluate('minimizePicker.windows = [{windowId:1,title:"Hidden browser",workspace:-99,monitor:"Primary",minimized:true}];')
        QTest.qWait(30)
        self.assertIn("Minimized", self.item("bottomWindow1").property("text"))
        self.assertEqual(self.item("bottomWindowMinimize1").property("description"), "Restore Hidden browser")
        self.engine.evaluate('minimizePicker.manager = Object.assign({}, minimizePicker.manager, {busy:true});')
        QTest.qWait(30)
        self.assertFalse(self.item("bottomWindowMinimize1").isEnabled())
        self.engine.evaluate('minimizePicker.manager = Object.assign({}, minimizePicker.manager, {busy:false});')
        QTest.qWait(30)
        self.capture("dock-minimized-window")
        self.click("bottomWindowMinimize1")
        self.assertEqual(restored, [1])
        self.assertEqual(requested, [1])

    def test_bottom_bar_width_and_overflow(self):
        self.fixtures.setProperty("reducedMotion", True)
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("testManager", self.engine.newQObject(manager))
        self.engine.evaluate('for (const app of testManager.applications) testManager.open(app.appId)')
        for width in (320, 375, 414, 640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(40)
            bar = self.item("bottomBar")
            self.assertAlmostEqual(bar.width(), min(bar.implicitWidth(), width - 24))
            self.assertAlmostEqual(bar.x() + bar.width() / 2, width / 2, delta=0.5)
            self.assertEqual(bar.property("entryWidth"), 64 if bar.property("compact") else 152)
            entries = self.item("bottomEntries")
            self.engine.evaluate('testManager.focus(2)')
            entries.positionViewAtEnd()
            QTest.qWait(30)
            self.item("bottomApp_system-summary").forceActiveFocus()
            QTest.qWait(30)
            last = self.item("bottomApp_system-summary")
            position = last.mapToItem(entries, QPointF(0, 0))
            self.assertGreaterEqual(position.x(), -1)
            self.assertLessEqual(position.x() + last.width(), entries.width() + 1)
            self.capture("bars-content-width-" + str(width))
            self.item("controlsButton").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertEqual(self.item("desktop").property("openPanel"), "controls")

    def test_system_summary_pin_and_unavailable(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.item("desktop").setProperty("openPanel", "summary")
        self.assertTrue(self.item("summaryDrawer").isVisible())
        self.assertEqual(self.item("summaryCPU").property("text"), "AMD Ryzen 9 9950X3D")
        self.assertEqual(self.item("summaryMemory").property("text"), "Unavailable")
        self.assertIn("32 GiB", self.item("summaryGpuUsage0").property("text"))
        self.fixtures.setProperty("telemetryAvailable", False)
        self.assertEqual(self.item("summaryGpuUsage0").property("text"), "Unavailable")
        self.click("summaryPin")
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.click("controlsButton")
        self.assertTrue(self.item("summaryDrawer").isVisible())
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertTrue(self.item("summaryDrawer").isVisible())
        self.capture("system-summary-pinned")
        self.click("closeSummary")
        self.assertFalse(self.item("summaryDrawer").isVisible())
        self.item("desktop").setProperty("openPanel", "summary")
        self.capture("system-summary")
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertTrue(self.item("bottomLauncher").hasActiveFocus())

    def test_system_summary_drag_tile_and_profile_placement(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.item("desktop").setProperty("openPanel", "summary")
        drawer = self.item("summaryDrawer")
        drag = self.item("summaryDrag", drawer)
        start = drag.mapToScene(QPointF(30, drag.height() / 2)).toPoint()
        before = drawer.x()
        QTest.mousePress(self.window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, start)
        QTest.mouseMove(self.window, start + QPointF(110, 60).toPoint(), 40)
        QTest.mouseRelease(self.window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, start + QPointF(110, 60).toPoint())
        self.assertGreater(drawer.x(), before)
        profiles = self.window.findChild(QObject, "profileSettings")
        position = profiles.property("currentProfile").toVariant()["tiling"]["summary"]
        profiles.save()
        profiles.setProperty("activeName", "Gaming")
        self.assertEqual(drawer.x(), 12)
        profiles.setProperty("activeName", "Work")
        self.assertEqual(profiles.property("currentProfile").toVariant()["tiling"]["summary"], position)
        self.click("summaryTile", drawer)
        self.assertEqual(self.item("desktop").property("openPanel"), "overview")
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        tile = self.item("tile3")
        self.assertTrue(self.item("summaryCPU", tile).isVisible())
        self.capture("system-summary-tiled")
        self.click("summaryFloat", tile)
        self.assertTrue(drawer.isVisible())
        self.assertTrue(self.item("desktop").property("summaryPinned"))
        for width in (320, 375, 414, 768, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(30)
            self.assertGreaterEqual(drawer.x(), 12)
            self.assertLessEqual(drawer.x() + drawer.width(), width - 12)

    def assert_outline_visible(self, control):
        image = self.window.grabWindow()
        ratio = image.devicePixelRatio()
        edges = (QPointF(control.width() / 2, 0),
                 QPointF(control.width() / 2, control.height()),
                 QPointF(0, control.height() / 2),
                 QPointF(control.width(), control.height() / 2))
        for edge in edges:
            scene = control.mapToScene(edge)
            column = round(scene.x() * ratio)
            row = round(scene.y() * ratio)
            self.assertGreaterEqual(column - 1, 0)
            self.assertGreaterEqual(row - 1, 0)
            self.assertLess(column + 1, image.width())
            self.assertLess(row + 1, image.height())
            lightness = max(image.pixelColor(column + offset_x, row + offset_y).lightness()
                            for offset_x in (-1, 0, 1) for offset_y in (-1, 0, 1))
            self.assertGreater(lightness, 180, f"Missing {control.objectName()} focus edge at {edge}")

    def test_search_borders_at_fractional_scale(self):
        self.fixtures.setProperty("reducedMotion", True)
        desktop = self.item("desktop")
        for panel, name, drawer_name in (("launcher", "launcherSearch", "launcherDrawer"),
                                         ("clipboard", "clipboardSearch", "clipboardDrawer"),
                                         ("windows", "windowSearch", "windowOverviewDrawer")):
            desktop.setProperty("openPanel", panel)
            drawer = self.item(drawer_name)
            drawer.setProperty("x", 100)
            drawer.setProperty("y", 80)
            for scale in (0.28, 0.4, 0.5, 0.65, 0.75, 1.0):
                with self.subTest(panel=panel, scale=scale):
                    desktop.setProperty("scale", scale)
                    desktop.setProperty("x", 20.35)
                    desktop.setProperty("y", 70.35)
                    field = self.item(name)
                    field.forceActiveFocus()
                    QTest.qWait(40)
                    self.assert_outline_visible(field)

    def test_focus_borders_at_fractional_scale(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.click("previewLockButton")
        lock = self.item("lockPreview")
        lock.setProperty("x", 0.35)
        for scale in (0.28, 0.4, 0.5, 0.65, 0.75, 1.0):
            lock.setProperty("scale", scale)
            lock.setProperty("y", -250.35 if scale >= 0.5 else 0.35)
            for name in ("lockPassword", "lockPlayback"):
                control = self.item(name)
                control.forceActiveFocus()
                for hovered in (False, True):
                    with self.subTest(scale=scale, control=name, hovered=hovered):
                        target = control if hovered else self.item("lockStatus")
                        position = target.mapToScene(QPointF(target.width() / 2, target.height() / 2))
                        QTest.mouseMove(self.window, position.toPoint())
                        QTest.qWait(30)
                        self.assertTrue(control.hasActiveFocus())
                        self.assertEqual(control.property("hovered"), hovered)
                        self.assert_outline_visible(control)

    def test_secure_lock_view_has_no_preview_unlock_paths(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.click("previewLockButton")
        lock = self.item("lockPreview")
        self.engine.globalObject().setProperty("secureLockView", self.engine.newQObject(lock))
        result = self.engine.evaluate('''
            var lockAuth = Qt.createQmlObject('import QtQuick; QtObject { property bool busy: false; property string status: ""; property int requests: 0; function submit(response) { requests++; busy = true; } }', secureLockView);
            secureLockView.service = Object.assign({}, secureLockView.service, {userName:"Test user",keyboardLayout:"French",production:true,
                lockSeries:[{name:"CPU",value:12,detail:"Utilization"}],lockHistory:[Array(48).fill(12)]});
            secureLockView.authenticator = lockAuth;
        ''')
        self.assertFalse(result.isError(), result.toString())
        QTest.qWait(30)
        dismissed = []
        lock.dismissed.connect(lambda: dismissed.append(True))
        self.assertFalse(self.item("exitLockPreview").isVisible())
        field = self.item("lockPassword")
        field.setProperty("text", "test-only-placeholder")
        field.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(field.property("text"), "")
        self.assertTrue(lock.isVisible())
        field.setProperty("text", "test-only-placeholder")
        self.click("lockSubmit")
        self.assertEqual(field.property("text"), "")
        self.assertTrue(lock.property("busy"))
        self.assertEqual(self.engine.evaluate("lockAuth.requests").toInt(), 1)
        QTest.qWait(1150)
        self.assertEqual(dismissed, [])
        self.assertTrue(lock.isVisible())
        self.engine.evaluate('lockAuth.status = "Authentication failed. Try again."; lockAuth.busy = false;')
        QTest.qWait(30)
        self.assertTrue(field.isEnabled())
        self.assertIn("Authentication failed", self.item("lockStatus").property("text"))
        self.assertEqual(self.item("lockWidgets").property("sample"), 48)

    def test_lock_preview_states_and_layout(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.click("previewLockButton")
        lock = self.item("lockPreview")
        field = self.item("lockPassword")
        self.assertTrue(lock.isVisible())
        self.assertFalse(self.item("desktop").isVisible())
        self.assertTrue(field.hasActiveFocus())
        self.assertFalse(self.item("lockSubmit").isEnabled())
        self.engine.globalObject().setProperty("lockField", self.engine.newQObject(field))
        self.assertEqual(self.engine.evaluate("lockField.echoMode").toInt(), 2)
        was_playing = self.fixtures.property("playing")
        self.click("lockPlayback")
        self.assertEqual(self.fixtures.property("playing"), not was_playing)
        self.click("lockRejectAttempt")
        field.setProperty("text", "demo")
        self.click("lockSubmit")
        self.assertEqual(field.property("text"), "")
        self.assertTrue(lock.property("busy"))
        self.assertFalse(field.isEnabled())
        QTest.qWait(700)
        self.assertEqual(self.item("lockStatus").property("text"), "Not recognized. Try again.")
        self.assertTrue(field.hasActiveFocus())
        self.capture("lock-preview-error")
        self.click("lockRejectAttempt")
        field.setProperty("text", "demo")
        field.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        QTest.qWait(700)
        self.assertEqual(self.item("lockStatus").property("text"), "Unlocked")
        QTest.qWait(400)
        self.assertFalse(self.studio.property("lockPreviewVisible"))
        self.assertTrue(self.item("desktop").isVisible())
        self.click("powerButton")
        self.click("powerLock")
        self.click("powerConfirm")
        self.assertTrue(lock.isVisible())
        self.assertEqual(field.property("text"), "")
        widgets = self.item("lockWidgets")
        history = widgets.property("history").toVariant()
        self.assertEqual([len(series) for series in history], [48, 48, 48])
        sample = widgets.property("sample")
        QTest.qWait(1100)
        self.assertGreater(widgets.property("sample"), sample)
        self.assertNotEqual(widgets.property("history").toVariant(), history)
        self.fixtures.setProperty("telemetryAvailable", False)
        sample = widgets.property("sample")
        QTest.qWait(1100)
        self.assertEqual(widgets.property("sample"), sample)
        self.assertFalse(self.item("lockSystemGraph").property("available"))
        self.fixtures.setProperty("telemetryAvailable", True)
        self.assertEqual(self.item("lockWeatherStatus").property("text"), "Location not configured")
        for width, height in ((320, 600), (375, 700), (414, 800), (768, 1080), (1920, 1080), (5120, 1440)):
            self.studio.setProperty("customWidth", width)
            self.item("desktop").setHeight(height)
            QTest.qWait(60)
            clock = self.item("lockClockBlock")
            login = self.item("lockLogin")
            scroll = self.item("lockScroll")
            self.assertLess(clock.y() + clock.height(), widgets.y())
            self.assertLess(widgets.y() + widgets.height(), login.y())
            for item in (clock, widgets, login):
                self.assertGreaterEqual(item.x(), 0)
                self.assertLessEqual(item.x() + item.width(), width)
                self.assertLessEqual(item.y() + item.height(), scroll.property("contentHeight"))
            scroll.setProperty("contentY", 0)
            self.capture("lock-preview-" + str(width))
            scroll.setProperty("contentY", max(0, scroll.property("contentHeight") - scroll.height()))
            QTest.qWait(20)
            self.assertLessEqual(field.mapToItem(scroll, QPointF(0, field.height())).y(), scroll.height())
            self.assertGreaterEqual(field.mapToItem(scroll, QPointF(0, 0)).y(), 0)
            self.capture("lock-preview-login-" + str(width))
        self.fixtures.setProperty("mediaAvailable", False)
        self.assertFalse(self.item("lockMedia").isVisible())
        field.setProperty("text", "discard")
        self.click("exitLockPreview")
        self.assertFalse(lock.isVisible())
        self.assertEqual(field.property("text"), "")
        sample = widgets.property("sample")
        QTest.qWait(1100)
        self.assertEqual(widgets.property("sample"), sample)

    def test_workspace_overview_handoff_is_inert_in_preview(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", False)
        requests = []
        self.studio.workspaceOverviewRequested.connect(lambda: requests.append(True))
        manager = self.window.findChild(QObject, "windowManager")
        windows_before = manager.property("windows").toVariant()
        self.item("desktop").setProperty("openPanel", "launcher")
        self.click("bottomOverview")
        self.assertEqual(requests, [True])
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        notification = self.fixtures.property("currentNotification").toVariant()
        self.assertEqual(notification["title"], "Workspace overview")
        self.assertEqual(notification["message"], "Requires Quickshell and a Hyprland session")
        shortcuts = self.window.findChild(QObject, "shortcutSettings")
        shortcuts.activated.emit("workspaceOverview")
        QTest.qWait(30)
        self.assertEqual(requests, [True, True])
        self.assertEqual(manager.property("windows").toVariant(), windows_before)
        for width in (320, 375, 414, 768):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            bar = self.item("bottomBar")
            button = self.item("bottomOverview")
            self.assertGreaterEqual(button.mapToItem(bar, QPointF()).x(), 0)
            self.assertLessEqual(button.mapToItem(bar, QPointF(button.width(), 0)).x(), bar.width())
        self.capture("workspace-overview-preview-unavailable")

    def test_capture_hyprquickshot_handoff_is_inert_in_preview(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", False)
        state = self.window.findChild(QObject, "captureState")
        requests = []
        self.studio.screenshotRequested.connect(lambda: requests.append(True))
        clipboard_before = self.fixtures.property("clipboardEntries").toVariant()
        self.assertEqual(self.item("captureButton").property("description"), "HyprQuickshot")
        self.assertIsNone(self.window.findChild(QObject, "captureDrawer"))
        self.click("captureButton")
        self.assertEqual(requests, [True])
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.assertFalse(state.property("busy"))
        self.assertEqual(state.property("entries").toVariant(), [])
        self.assertEqual(self.fixtures.property("clipboardEntries").toVariant(), clipboard_before)
        notification = self.fixtures.property("currentNotification").toVariant()
        self.assertEqual(notification["title"], "HyprQuickshot")
        self.assertEqual(notification["message"], "Unavailable in the native preview")
        self.capture("hyprquickshot-preview-unavailable")

    def test_bar_album_art_and_dynamic_notch(self):
        QTest.qWait(80)
        notch = self.item("barCenter")
        left = self.item("barLeft")
        home = self.item("controlsButton")
        clock = self.item("clockButton")
        home_position = home.mapToItem(left, QPointF(0, 0))
        clock_position = clock.mapToItem(left, QPointF(0, 0))
        self.assertLess(home_position.x(), clock_position.x())
        self.assertIn(self.fixtures.property("date"), clock.property("text"))
        self.assertIn(self.fixtures.property("clock"), clock.property("text"))
        self.assertIsNone(self.window.findChild(QObject, "topSummaryButton"))
        artwork = self.item("barAlbumArt")
        self.assertTrue(artwork.isVisible())
        self.assertFalse(self.item("barArtworkFallback").isVisible())
        first_source = artwork.property("source")
        self.click("nextButton")
        QTest.qWait(80)
        self.assertNotEqual(artwork.property("source"), first_source)
        self.fixtures.setProperty("trackArtwork", QUrl())
        QTest.qWait(30)
        self.assertTrue(self.item("barArtworkFallback").isVisible())
        self.click("playbackButton")
        self.assertTrue(notch.property("animating"))
        QTest.qWait(60)
        self.assertGreater(notch.property("progress"), 0)
        self.assertLess(notch.property("progress"), 1)
        self.fixtures.setProperty("playing", True)
        QTest.qWait(280)
        self.assertEqual(notch.property("progress"), 1)
        self.fixtures.setProperty("playing", False)
        QTest.qWait(280)
        self.assertFalse(notch.isVisible())
        self.assertEqual(notch.property("progress"), 0)
        self.capture("top-bar-idle")
        self.click("controlsButton")
        QTest.qWait(280)
        self.click("controlPlayback")
        QTest.qWait(280)
        self.assertTrue(notch.isVisible())
        self.assertEqual(notch.property("progress"), 1)
        self.click("homeSystemSummary")
        QTest.qWait(280)
        self.assertEqual(self.item("desktop").property("openPanel"), "controls")
        self.assertEqual(self.item("homePanel").property("page"), "System")
        self.click("closeControls")
        self.fixtures.setProperty("mediaAvailable", False)
        QTest.qWait(280)
        self.assertFalse(artwork.isVisible())
        self.assertFalse(notch.isVisible())
        self.assertFalse(self.item("playbackButton").isVisible())
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("mediaAvailable", True)
        self.assertEqual(notch.property("progress"), 1)
        self.assertTrue(self.item("playbackButton").isVisible())
        self.capture("top-bar-media")
        self.fixtures.setProperty("playing", False)
        self.assertEqual(notch.property("progress"), 0)
        for width in (320, 375, 414, 768, 1920, 5120):
            self.item("desktop").setWidth(width)
            QTest.qWait(30)
            right = self.item("barRight")
            if width < 640:
                self.assertGreaterEqual(right.y(), left.y() + left.height())
            else:
                self.assertLessEqual(left.x() + left.width() + 8, right.x())
            self.assertFalse(notch.isVisible())
            self.assertTrue(home.isVisible())
            self.assertTrue(clock.isVisible())

    def test_notch_activity_cycle_and_controls(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        activities = self.window.findChild(QObject, "activities")
        notch = self.item("barCenter")
        self.assertEqual(activities.property("selectedId"), "music")
        self.assertFalse(self.item("notchNextActivity").isVisible())
        self.home_action("homeActivities")
        self.click("activityStartTimer")
        self.assertGreater(activities.property("timerSeconds"), 0)
        activities.startAi()
        self.click("closeControls")
        self.assertEqual(activities.property("selectedId"), "music")
        self.assertEqual(self.item("notchActivityCount").property("text"), "1/3")
        self.assertEqual(self.item("notchNextActivity").property("description"), "Next: Timer")
        self.fixtures.setProperty("reducedMotion", False)
        navigation = [self.item(name) for name in ("notchActivitySelector", "notchActivityCount", "notchNextActivity")]
        positions = [control.mapToScene(QPointF(0, 0)) for control in navigation]
        self.assertEqual(navigation[0].parentItem(), notch)
        self.click("notchNextActivity")
        self.assertEqual(activities.property("selectedId"), "timer")
        self.assertEqual(notch.property("progress"), 1)
        self.assertFalse(notch.property("animating"))
        self.assertLess(notch.property("pageProgress"), 1)
        offset = notch.property("pageOffset")
        QTest.qWait(60)
        self.assertNotEqual(notch.property("pageOffset"), offset)
        self.assertEqual([control.mapToScene(QPointF(0, 0)) for control in navigation], positions)
        content = self.item("notchPageContent").parentItem()
        self.assertTrue(content.property("clip"))
        self.assertLessEqual(content.mapToScene(QPointF(content.width(), 0)).x(), positions[0].x())
        self.capture("notch-fixed-navigation")
        QTest.qWait(280)
        self.assertFalse(self.item("mediaSeek").isVisible())
        self.click("notchActivityPause")
        self.assertTrue(activities.property("timerPaused"))
        remaining = activities.property("timerSeconds")
        activities.advance()
        self.assertEqual(activities.property("timerSeconds"), remaining)
        self.capture("notch-timer")
        self.click("notchNextActivity")
        self.assertEqual(activities.property("selectedId"), "ai")
        QTest.qWait(280)
        self.assertFalse(self.item("notchActivityProgress").isVisible())
        activities.setProperty("aiProgress", 0.5)
        self.assertTrue(self.item("notchActivityProgress").isVisible())
        QTest.qWait(280)
        self.capture("notch-ai")
        self.click("notchActivityStop")
        self.assertFalse(activities.property("aiActive"))
        self.assertEqual(self.fixtures.property("activeRequests"), 1)
        self.assertEqual(activities.property("selectedId"), "music")
        self.fixtures.setProperty("playing", False)
        self.assertEqual(activities.property("selectedId"), "timer")
        self.assertTrue(notch.isVisible())
        self.assertFalse(self.item("notchNextActivity").isVisible())
        QTest.qWait(520)
        self.click("notchActivityStop")
        QTest.qWait(280)
        self.assertFalse(notch.isVisible())

    def test_notch_urgent_return_and_recording(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("playing", False)
        activities = self.window.findChild(QObject, "activities")
        self.engine.globalObject().setProperty("activities", self.engine.newQObject(activities))
        self.engine.evaluate("activities.startTimer(120)")
        activities.setProperty("timerPaused", True)
        activities.startTransfer(False)
        activities.startRecording(True)
        self.assertEqual(activities.property("selectedId"), "timer")
        self.assertTrue(self.item("recordingIndicator").isVisible())
        activities.alert("Incoming call")
        self.assertEqual(activities.property("selectedId"), "alert")
        self.assertEqual(activities.property("returnId"), "timer")
        activities.startAi()
        self.assertEqual(activities.property("selectedId"), "alert")
        self.capture("notch-alert")
        for tick in range(8):
            activities.advance()
        self.assertEqual(activities.property("selectedId"), "timer")
        activities.alert("Critical battery")
        self.click("notchActivityStop")
        self.assertEqual(activities.property("selectedId"), "timer")
        activities.setProperty("selectedId", "transfer")
        self.click("notchActivityPause")
        self.assertTrue(activities.property("transferPaused"))
        for width in (640, 768, 800, 1024, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(40)
            page = self.item("notchActivityPage")
            selector = self.item("notchActivitySelector")
            if self.item("barCenter").isVisible():
                self.assertLessEqual(page.x() + page.width(), selector.x())
                self.assertLessEqual(selector.x() + selector.width(), self.item("barCenter").width())
            self.assertTrue(self.item("recordingIndicator").isVisible())
        self.capture("notch-transfer")
        self.click("recordingIndicator")
        self.assertFalse(activities.property("recordingActive"))
        self.assertFalse(self.item("recordingIndicator").isVisible())
        activities.reset()
        self.assertFalse(self.item("barCenter").isVisible())
        self.engine.evaluate("activities.startTimer(1)")
        activities.advance()
        self.assertEqual(activities.property("selectedId"), "alert")
        self.assertEqual(activities.property("alertTitle"), "Timer finished")
        for tick in range(8):
            activities.advance()
        self.assertFalse(self.item("barCenter").isVisible())

    def test_notch_slide_animation(self):
        QTest.qWait(280)
        self.fixtures.setProperty("dndEnabled", True)
        profile = self.window.findChild(QObject, "profileSettings")
        notch = self.item("barCenter")
        content = self.item("notchPageContent")
        outgoing = self.item("outgoing-notchPageContent")
        activities = self.window.findChild(QObject, "activities")
        profile.setProperty("animationDuration", 600)
        for style in ("Smooth", "Stepped"):
            profile.setProperty("animationStyle", style)
            self.fixtures.notify("Slide " + style, "Animation preview", "critical")
            QTest.qWait(100)
            self.assertTrue(notch.property("pageAnimating"))
            self.assertEqual(outgoing.property("displayedKey"), "music")
            self.assertTrue(notch.property("displayedKey").startswith("notification:"))
            self.assertLess(notch.property("pageOffset"), 0)
            self.assertGreaterEqual(outgoing.x(), -14)
            self.assertEqual(notch.property("progress"), 1)
            self.assertFalse(content.isEnabled())
            self.assertTrue(content.parentItem().clip())
            self.assertEqual(content.opacity(), 1)
            self.assertEqual(outgoing.opacity(), 1)
            previous_offset = notch.property("pageOffset")
            QTest.qWait(40)
            if style == "Stepped":
                self.assertGreaterEqual(notch.property("pageOffset"), previous_offset)
                self.assertAlmostEqual(notch.property("pageRevealProgress") * 6, round(notch.property("pageRevealProgress") * 6))
            else:
                self.assertGreater(notch.property("pageOffset"), previous_offset)
            self.capture("notch-slide-out-" + style.lower())
            QTest.qWait(160)
            self.assertLess(notch.property("pageOffset"), 0)
            self.assertTrue(outgoing.isVisible())
            self.assertAlmostEqual(outgoing.x() - content.x(), notch.width() - 28)
            self.capture("notch-slide-in-" + style.lower())
            QTest.qWait(400)
            self.assertFalse(notch.property("pageAnimating"))
            self.assertEqual(notch.property("pageOffset"), 0)
            self.assertTrue(content.isEnabled())
            self.assertFalse(outgoing.isVisible())
            self.fixtures.notify("Newer " + style, "Stacked notification", "critical")
            QTest.qWait(100)
            self.assertTrue(notch.property("pageAnimating"))
            self.assertEqual(notch.property("slideDirection"), 1)
            self.assertEqual(self.item("notchNotificationTitle").property("text"), "Newer " + style)
            self.assertEqual(self.item("outgoing-notchNotificationTitle").property("text"), "Slide " + style)
            self.assertGreaterEqual(outgoing.x(), -14)
            self.assertLess(notch.property("pageOffset"), 0)
            QTest.qWait(200)
            self.capture("notch-notification-stack-" + style.lower())
            QTest.qWait(400)
            self.click("dismissNotchNotification")
            QTest.qWait(700)
            self.assertEqual(self.item("notchNotificationTitle").property("text"), "Slide " + style)
            self.click("dismissNotchNotification")
            QTest.qWait(70)
            self.assertEqual(notch.property("slideDirection"), -1)
            self.assertLessEqual(outgoing.x(), -14)
            self.assertGreater(notch.property("pageOffset"), 0)
            QTest.qWait(210)
            self.assertGreater(notch.property("pageOffset"), 0)
            QTest.qWait(400)
            self.assertEqual(notch.property("displayedKey"), "music")
            self.assertEqual(activities.property("selectedId"), "music")
        self.fixtures.notify("Interrupted", "Motion setting changed", "critical")
        QTest.qWait(70)
        self.fixtures.setProperty("reducedMotion", True)
        self.assertFalse(notch.property("pageAnimating"))
        self.assertEqual(notch.property("pageOffset"), 0)
        self.assertEqual(notch.property("pageOpacity"), 1)
        self.assertEqual(self.item("notchNotificationTitle").property("text"), "Interrupted")
        self.click("dismissNotchNotification")
        self.fixtures.setProperty("reducedMotion", False)
        profile.setProperty("animationStyle", "Off")
        self.fixtures.notify("Instant", "Motion disabled", "critical")
        self.assertFalse(notch.property("pageAnimating"))
        self.assertEqual(notch.property("pageOffset"), 0)

    def test_preview_notch_menu(self):
        self.fixtures.setProperty("reducedMotion", True)
        activities = self.window.findChild(QObject, "activities")
        self.click("previewNotchButton")
        QTest.qWait(150)
        notification_label = self.item("previewNotchNotification").property("contentItem")
        self.assertGreater(notification_label.property("color").lightness(), 150)
        self.capture("preview-notch-menu")
        self.click("previewNotchNotification")
        self.assertTrue(self.item("notchNotificationPage").isVisible())
        self.assertEqual(self.item("notchNotificationTitle").property("text"), "Build complete")
        self.assertEqual(activities.property("selectedId"), "music")
        self.capture("preview-notch-notification")
        QTest.qWait(4200)
        self.assertTrue(self.item("notchMusicPage").isVisible())
        for action, selected in (("Timer", "timer"), ("Ai", "ai"), ("Transfer", "transfer"), ("Recording", "recording"), ("Alert", "alert")):
            self.click("previewNotchButton")
            QTest.qWait(150)
            self.click("previewNotch" + action)
            self.assertEqual(activities.property("selectedId"), selected)
            self.assertTrue(self.item("notchActivityPage").isVisible())
            self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.assertTrue(self.item("recordingIndicator").isVisible())
        self.fixtures.setProperty("dndEnabled", True)
        self.click("previewNotchButton")
        QTest.qWait(150)
        self.assertFalse(self.item("previewNotchNotification").isEnabled())
        self.click("previewNotchCritical")
        self.assertEqual(self.item("notchNotificationTitle").property("text"), "Battery low")
        self.click("previewNotchButton")
        QTest.qWait(150)
        self.click("previewNotchClear")
        self.assertFalse(self.item("barCenter").isVisible())
        self.assertFalse(self.item("recordingIndicator").isVisible())
        self.assertFalse(self.fixtures.property("playing"))
        self.assertFalse(activities.property("aiActive"))
        self.assertTrue(self.fixtures.property("dndEnabled"))

    def test_preview_music_toggle(self):
        toggle = self.item("previewMusicToggle")
        notch = self.item("barCenter")
        self.assertTrue(toggle.property("checked"))
        self.click("previewMusicToggle")
        self.assertFalse(self.fixtures.property("playing"))
        self.assertTrue(notch.property("animating"))
        QTest.qWait(280)
        self.assertFalse(notch.isVisible())
        self.capture("preview-music-off")
        self.click("previewMusicToggle")
        self.assertTrue(self.fixtures.property("playing"))
        QTest.qWait(280)
        self.assertTrue(notch.isVisible())
        self.capture("preview-music-on")
        self.home_action("controlPlayback")
        self.assertFalse(toggle.property("checked"))
        self.click("closeControls")
        self.fixtures.setProperty("mediaAvailable", False)
        self.click("previewMusicToggle")
        self.assertTrue(self.fixtures.property("mediaAvailable"))
        self.assertTrue(self.fixtures.property("playing"))
        for width in (880, 1100, 1440):
            self.window.setWidth(width)
            QTest.qWait(50)
            previous_right = 0
            for name in ("primarySize", "ultrawideSize", "fitMode", "actualMode", "previewMusicToggle", "previewNotchButton", "launcherButton", "clipboardButton", "windowSwitcherButton", "windowOverviewButton", "tilingButton", "specimenButton", "resetButton"):
                control = self.item(name)
                position = control.mapToScene(QPointF(0, 0))
                self.assertGreaterEqual(position.x(), previous_right, (width, name))
                previous_right = position.x() + control.width()
                self.assertLessEqual(previous_right, width, (width, name))

    def test_home_side_placement(self):
        self.fixtures.setProperty("reducedMotion", True)
        for name in ("homePower", "profileButton", "settingsButton"):
            self.assertIsNone(self.window.findChild(QObject, name))
        power = self.item("powerButton")
        left = self.item("barLeft")
        position = power.mapToItem(left, QPointF(0, 0))
        self.assertGreaterEqual(position.x(), 0)
        self.assertLessEqual(position.x() + power.width(), left.width())
        self.click("powerButton")
        self.assertEqual(self.item("desktop").property("openPanel"), "power")
        self.assertTrue(power.property("checked"))
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.assertTrue(power.hasActiveFocus())
        self.assertTrue(self.item("wallpaperButton").isVisible())
        self.click("controlsButton")
        profiles = self.window.findChild(QObject, "profileSettings")
        for width in (640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            desktop = self.item("desktop")
            center = self.item("barCenter")
            self.assertAlmostEqual(center.x() + center.width() / 2, width / 2)
            drawer = self.item("controlDrawer")
            for floating in (False, True):
                profiles.setProperty("floatingPanels", floating)
                QTest.qWait(30)
                margin = 12 if floating else 0
                self.assertEqual(drawer.x(), margin)
                self.assertEqual(drawer.property("floating"), floating)
                self.assertEqual(drawer.property("edge"), "left")
                top_bar = self.item("barLeft").parentItem()
                self.assertEqual(drawer.y(), top_bar.y() + top_bar.height() + margin)
                self.assertLessEqual(drawer.x() + drawer.width(), width)
                self.assertEqual(self.item("homePanel").property("topLeftRadius"), profiles.property("panelRadius") if floating else 0)
                if width == 1920:
                    self.capture("home-side-" + ("floating" if floating else "attached"))
        self.click("homeSettings")
        self.assertFalse(self.settings_window.isVisible())
        self.assertEqual(self.item("homePanel").property("page"), "Settings")
        self.home_action("homeWallpaper")
        self.assertEqual(self.item("desktop").property("openPanel"), "controls")
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertTrue(self.item("controlsButton").hasActiveFocus())
        self.click("wallpaperButton")
        self.assertEqual(self.item("desktop").property("openPanel"), "wallpaper")
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertTrue(self.item("wallpaperButton").hasActiveFocus())

    def test_home_navigation_and_bar_tools(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        self.click("controlsButton")
        self.assertEqual(self.item("controlsButton").property("description"), "Open Home")
        self.assertEqual(self.item("homePanel").property("page"), "Home")
        home = self.item("homePanel")
        for removed in ("homeWorkspaceTab", "homeMediaTab", "homeAppearanceTab", "homeCalendarTab"):
            self.assertIsNone(home.findChild(QObject, removed))
        self.assertEqual(self.item("homeTab").property("iconName"), "house")
        self.assertEqual(self.item("homeDisplayTab").property("iconName"), "monitor")
        self.capture("home-dashboard")
        self.click("homeSystemSummary")
        self.assertEqual(self.item("desktop").property("openPanel"), "controls")
        self.assertEqual(self.item("homePanel").property("page"), "System")
        page = self.item("homeSystemPage")
        self.assertFalse(self.item("systemSummary").isVisible())
        self.assertFalse(self.item("resourceGraphcpu", page).property("current"))
        self.assertEqual(self.item("resourceGraphcpu", page).property("reading"), "Unavailable")
        self.capture("home-system-summary")
        self.click("homeTab")
        for trigger, bar_trigger, page in (("homeAudio", "volumeButton", "Audio"), ("homeWallpaper", "wallpaperButton", "Wallpaper")):
            self.assertTrue(self.item(bar_trigger).isVisible())
            self.home_action(trigger)
            self.assertEqual(self.item("desktop").property("openPanel"), "controls")
            self.assertEqual(self.item("homePanel").property("page"), page)
            self.assertTrue(self.item(trigger).property("checked"))
            self.capture("home-" + page.lower())
        self.click("home_wallpaperTile2")
        self.assertEqual(self.fixtures.property("wallpaper"), 2)
        self.assertFalse(self.item("home_wallpaperSourceSaved").isVisible())
        self.assertFalse(self.item("home_wallpaperPaletteRose").isVisible())
        self.click("homeAudio")
        self.click("home_outputMute")
        self.assertTrue(self.fixtures.property("outputMuted"))
        self.item("home_volumeSlider").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(self.fixtures.property("volume"), 65)
        self.home_action("homeColorsTab")
        self.click("controlThemeRose")
        self.assertTrue(self.item("controlThemeRose").property("checked"))
        self.capture("home-appearance")
        self.click("homeProfilesTab")
        profiles_page = self.item("homeProfilesPage")
        self.assertEqual(self.item("homePanel").property("page"), "Profiles")
        self.assertEqual(self.item("desktop").property("openPanel"), "controls")
        self.assertTrue(self.item("profileSelect", profiles_page).isVisible())
        self.assertTrue(self.item("saveProfile", profiles_page).isVisible())
        self.assertFalse(self.item("paletteSection", profiles_page).isVisible())
        self.assertFalse(self.item("wallpaperSection", profiles_page).isVisible())
        self.assertFalse(self.item("homeSettingsCategory", profiles_page).isVisible())
        self.click("saveProfile", profiles_page)
        self.assertFalse(self.item("saveProfile", profiles_page).isEnabled())
        self.capture("home-profiles")
        self.item("homePanel").setProperty("page", "Workspaces")
        self.click("controlWorkspace4")
        self.assertEqual(self.fixtures.property("workspace"), 4)
        self.click("homeSettings")
        self.assertFalse(self.settings_window.isVisible())
        self.assertEqual(self.item("desktop").property("openPanel"), "controls")
        self.assertTrue(self.item("homeSettingsCategory").isVisible())
        self.capture("home-settings")
        self.click("homeTab")
        self.click("homeNetworkTab")
        self.assertEqual(self.item("homePanel").property("page"), "Network")
        self.assertIn("unavailable", self.item("homeServiceStatus").property("text"))
        self.click("homeTab")
        for width in (320, 375, 414, 640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            drawer = self.item("controlDrawer")
            self.assertGreaterEqual(drawer.x(), 0)
            self.assertLessEqual(drawer.x() + drawer.width(), width)
            for key in ("wifiEnabled", "bluetoothEnabled", "caffeineEnabled", "nightLightEnabled", "dndEnabled", "powerSaverEnabled"):
                toggle = self.item(key + "Switch")
                icon = self.item(key + "SwitchIcon")
                label = self.item(key + "SwitchLabel")
                icon_center = icon.mapToItem(toggle, QPointF(icon.width() / 2, icon.height() / 2))
                self.assertAlmostEqual(icon_center.x(), toggle.width() / 2, delta=1)
                label_top = label.mapToItem(toggle, QPointF(0, 0)).y()
                self.assertGreater(label_top, icon_center.y() + icon.height() / 2)
                self.assertTrue(toggle.property("checkable"))
            self.capture("home-" + str(width))

    def test_home_workspace_details_and_settings_search(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.set_test_monitors()
        manager = self.window.findChild(QObject, "windowManager")
        self.home_action("homeTab")
        self.item("homePanel").setProperty("page", "Workspaces")
        self.assertEqual(len(self.item("controlWorkspace1").property("members").toVariant()), 3)
        monitor = self.item("homeWorkspaceMonitor")
        monitor.setProperty("currentIndex", 1)
        monitor.activated.emit(1)
        QTest.qWait(30)
        self.click("controlWorkspace4")
        self.assertEqual(manager.property("activeMonitor"), "HDMI-A-1")
        self.assertEqual(manager.property("activeWorkspace"), 4)
        self.assertTrue(self.item("homeWorkspaceEmpty").isVisible())
        manager.move(1, "HDMI-A-1", 4)
        QTest.qWait(30)
        self.click("homeWorkspaceWindow1")
        self.assertEqual(manager.property("focusedId"), 1)
        manager.setProperty("screens", [{"name": "DP-1"}])
        QTest.qWait(30)
        self.assertEqual(monitor.property("currentText"), "DP-1")
        self.home_action("homeSettings")
        home = self.item("homePanel")
        search = self.item("settingsSearch", home)
        search.setProperty("text", "opacity")
        QTest.qWait(30)
        self.assertEqual(self.item("settingsSearchResults", home).property("count"), 1)
        self.click("settingsResultappearance", home)
        self.assertEqual(self.item("settingsSurface", self.item("homePanel")).property("section"), 0)
        search.setProperty("text", "hotkeys")
        search.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(self.item("settingsSurface", self.item("homePanel")).property("section"), 4)
        search.setProperty("text", "does-not-exist")
        QTest.qWait(30)
        self.assertTrue(self.item("settingsSearchEmpty", home).isVisible())
        self.click("clearSettingsSearch", home)
        self.assertEqual(search.property("text"), "")

    def test_home_tabs_and_settings_control_bounds(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.home_action("homeTab")
        home = self.item("homePanel")

        def assert_controls_fit():
            pending = [home]
            while pending:
                control = pending.pop()
                pending.extend(control.childItems())
                if not control.isVisible() or not control.inherits("QQuickControl"):
                    continue
                ancestor = control.parentItem()
                while ancestor:
                    if ancestor.objectName().startswith("resourceGraph") and ancestor.objectName().endswith("Legend"):
                        self.assertTrue(ancestor.clip())
                        control = ancestor
                    if ancestor.clip():
                        start = control.mapToItem(ancestor, QPointF(0, 0))
                        end = control.mapToItem(ancestor, QPointF(control.width(), 0))
                        self.assertGreaterEqual(start.x(), -1, control.objectName())
                        self.assertLessEqual(end.x(), ancestor.width() + 1, control.objectName())
                    ancestor = ancestor.parentItem()

        for width in (320, 375, 414, 768, 1920):
            self.studio.setProperty("customWidth", width)
            for trigger in ("homeTab", "homeAudio", "homeDisplayTab", "homeNetworkTab", "homeSystemSummary", "homePowerTab", "homeWeatherTab", "homeNotificationsTab", "homeSettings"):
                with self.subTest(width=width, page=trigger):
                    self.home_action(trigger)
                    self.assertTrue(self.item(trigger).property("iconOnly"))
                    assert_controls_fit()
                    if trigger == "homeSettings":
                        settings = self.item("settingsSurface", home)
                        for section in range(9):
                            settings.setProperty("section", section)
                            QTest.qWait(30)
                            with self.subTest(section=section):
                                assert_controls_fit()
                        settings.setProperty("section", 0)
                    if width in (320, 768, 1920):
                        self.capture("polished-" + trigger + "-" + str(width))

    def test_home_live_data_and_populated_pages(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("fixture", self.engine.newQObject(self.fixtures))
        result = self.engine.evaluate('''
            var data = fixture.desktopData;
            var sample = {cpu:{total:1000,idle:500,temperature:52},memory:{MemTotal:8192,MemAvailable:4096,SwapTotal:0,SwapFree:0},network:[{name:"eth0",rx:1024,tx:1024}],gpus:[{id:"gpu0",name:"Test GPU",utilization:40,usedMiB:512,totalMiB:8192,temperature:60,power:null}],processes:[],load:[1,2,3],uptime:3600};
            var start = Date.now();
            data.ingest(sample,start);
            var firstCpu = data.metrics.find(metric => metric.key === "cpu").value;
            sample = JSON.parse(JSON.stringify(sample));
            sample.cpu.total += 200; sample.cpu.idle += 50;
            sample.network[0].rx += 4096; sample.network[0].tx += 2048;
            data.ingest(sample,start+2000);
            var measured = [firstCpu,data.metrics[0].value,data.metrics.find(metric => metric.key === "download").value,data.metrics.find(metric => metric.key === "upload").value];
            data.live = true;
            data.status = "Test records / no host actions";
            var devices = data.devices;
            devices.host = "test-host"; devices.kernel = "test-kernel"; devices.cpu = "Test CPU";
            devices.monitors = [{name:"DP-1",description:"Test monitor",width:1920,height:1080,refreshRate:144,availableModes:["1920x1080@144.00Hz","1920x1080@60.00Hz"],scale:1,transform:0,x:0,y:0,vrr:false}];
            devices.audio = {default_sink_name:"speakers",default_source_name:"mic"};
            devices.sinks = [{index:1,name:"speakers",description:"Speakers",mute:false,volume:{left:{value:32768},right:{value:32768}}}];
            devices.sources = [{index:2,name:"mic",description:"Microphone",mute:false,volume:{mono:{value:32768}}}];
            devices.streams = [{index:3,sink:1,mute:false,properties:{"application.name":"Music"},volume:{left:{value:32768}}}];
            devices.network = [{name:"eth0",type:"ethernet",state:"connected",connection:"Wired"}];
            devices.batteries = [{model:"Headphones",percentage:"75%",state:"discharging"}];
            devices.drives = [{name:"nvme0n1",size:1000000000,type:"disk",children:[{name:"nvme0n1p1",size:900000000,type:"part",fstype:"ext4",mountpoints:["/"],fsavail:100000000,"fsuse%":"88%"}]}];
            data.devices = devices;
            data.remember("Today title","Body","Application",start);
            data.remember("Older title","Body","Application",start-3*86400000);
            measured;
        ''')
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(result.toVariant(), [None, 75, 2, 1])
        self.home_action("homeSystemSummary")
        groups = self.item("homeSystemPage").property("graphGroups").toVariant()
        self.assertEqual([group["key"] for group in groups], ["cpu", "memory", "gpu:gpu0", "network"])
        self.assertEqual([len(group["series"]) for group in groups], [2, 2, 4, 2])
        self.assertEqual(groups[3]["series"][0]["maximum"], groups[3]["series"][1]["maximum"])
        result = self.engine.evaluate('''
            sample = JSON.parse(JSON.stringify(sample));
            sample.gpus.push({id:"gpu1",name:"Second GPU",utilization:25,usedMiB:256,totalMiB:4096,temperature:45,power:65});
            data.ingest(sample,start+3000);
        ''')
        self.assertFalse(result.isError(), result.toString())
        groups = self.item("homeSystemPage").property("graphGroups").toVariant()
        self.assertEqual([group["key"] for group in groups], ["cpu", "memory", "gpu:gpu0", "gpu:gpu1", "network"])
        self.assertEqual([len(group["series"]) for group in groups], [2, 2, 4, 4, 2])
        self.assertEqual(groups[2]["title"], "GPU 0 / Test GPU")
        self.assertEqual(groups[3]["title"], "GPU 1 / Second GPU")
        self.assertTrue(all(entry["key"].startswith("gpu0") for entry in groups[2]["series"]))
        self.assertTrue(all(entry["key"].startswith("gpu1") for entry in groups[3]["series"]))
        result = self.engine.evaluate('''
            var reordered = JSON.parse(JSON.stringify(sample));
            reordered.gpus.reverse();
            reordered.gpus.forEach(gpu => gpu.name = "Identical GPU");
            data.ingest(reordered,start+3100);
        ''')
        self.assertFalse(result.isError(), result.toString())
        groups = self.item("homeSystemPage").property("graphGroups").toVariant()
        self.assertEqual([group["key"] for group in groups[2:4]], ["gpu:gpu1", "gpu:gpu0"])
        self.assertEqual(groups[2]["series"][0]["samples"], [25, 25])
        self.assertEqual(groups[3]["series"][0]["samples"], [40, 40, 40, 40])
        self.engine.evaluate('reordered.gpus = reordered.gpus.slice(0,1); data.ingest(reordered,start+3200)')
        groups = self.item("homeSystemPage").property("graphGroups").toVariant()
        self.assertEqual([group["key"] for group in groups], ["cpu", "memory", "gpu:gpu1", "network"])
        self.engine.evaluate('reordered.gpus = []; data.ingest(reordered,start+3300)')
        groups = self.item("homeSystemPage").property("graphGroups").toVariant()
        self.assertEqual(groups[2]["key"], "gpu")
        self.assertEqual(len(groups[2]["series"]), 4)
        self.assertTrue(all(not entry["current"] for entry in groups[2]["series"]))
        self.engine.evaluate('data.ingest(sample,start+3400)')
        for width in (320, 768):
            self.studio.setProperty("customWidth", width)
            for trigger in ("homeAudio", "homeDisplayTab", "homeSystemSummary", "homePowerTab", "homeNetworkTab", "homeNotificationsTab"):
                self.home_action(trigger)
                self.capture("populated-" + trigger + "-" + str(width))
                self.assertEqual(self.warnings, [])
        self.home_action("homeAudio")
        output = self.item("homeAudioOutputSource")
        self.assertEqual(output.property("currentText"), "Speakers")
        self.assertFalse(output.isEnabled())
        self.engine.evaluate('var capturedCommand = ""; data.controlsEnabled = true; data.commandRequested.connect(command => { capturedCommand = JSON.stringify(command); });')
        output.activated.emit(0)
        self.assertEqual(self.engine.evaluate("capturedCommand").toString(), '["pactl","set-default-sink","speakers"]')
        result = self.engine.evaluate('''
            for (let index=0;index<65;index++) data.ingest(sample,start+4000+index*2000);
            var length = data.history.cpu.length;
            sample = JSON.parse(JSON.stringify(sample)); sample.cpu.total = 0; sample.network[0].rx = 0;
            data.ingest(sample,start+134000);
            [length,data.metrics[0].value,data.metrics.find(metric => metric.key === "download").value,data.dayGroup(start),data.dayGroup(start-3*86400000)];
        ''')
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(result.toVariant(), [60, None, None, "Today", "Older"])
        self.home_action("homeSystemSummary")
        self.engine.evaluate('data.clock = data.sampledAt + 9000;')
        self.assertFalse(self.item("resourceGraphmemory").property("current"))

    def test_notifications_history_polish_bounds_and_confirmation(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("notificationFixture", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            QTest.qWait(30)
            return result

        evaluate('''
            var notificationData = notificationFixture.desktopData;
            var notificationCommands = [];
            notificationData.commandRequested.connect(command => notificationCommands.push(command));
            var notificationNow = new Date();
            notificationNow.setHours(12, 0, 0, 0);
            var notificationYesterday = new Date(notificationNow);
            notificationYesterday.setDate(notificationYesterday.getDate() - 1);
            var notificationOlder = new Date(notificationNow);
            notificationOlder.setDate(notificationOlder.getDate() - 3);
            var notificationRecords = [
                {id:"fixture-today-1",app:"Preview test",title:"Capture ready",body:"Native preview fixture only.",time:notificationNow.getTime()},
                {id:"fixture-today-2",app:"Test runner",title:"Checks complete",body:"",time:notificationNow.getTime()-60000},
                {id:"fixture-yesterday",app:"Preview test",title:"Previous session entry",body:"Yesterday fixture.",time:notificationYesterday.getTime()},
                {id:"fixture-older",app:"Test runner",title:"Earlier entry",body:"Older fixture.",time:notificationOlder.getTime()}
            ];
        ''')
        self.home_action("homeNotificationsTab")

        def assert_bounds(root):
            pending = [root]
            while pending:
                control = pending.pop()
                pending.extend(control.childItems())
                if not control.isVisible() or not (control.inherits("QQuickControl") or control.inherits("QQuickText")):
                    continue
                start = control.mapToItem(root, QPointF(0, 0))
                end = control.mapToItem(root, QPointF(control.width(), 0))
                self.assertGreaterEqual(start.x(), -1, control.objectName())
                self.assertLessEqual(end.x(), root.width() + 1, control.objectName())
                if control.inherits("QQuickText"):
                    self.assertLessEqual(control.property("contentWidth"), control.width() + 1, control.objectName())

        for width in (320, 375, 414, 768):
            with self.subTest(width=width):
                self.studio.setProperty("customWidth", width)
                evaluate('notificationData.notifications = notificationRecords.slice();')
                page = self.item("homeDevicePage")
                flickable = page.property("contentItem")
                flickable.setProperty("contentY", 0)
                self.assertEqual(self.item("homeServiceStatus").property("text"), "Session history")
                self.assertEqual(self.item("homeNotificationCount").property("text"), "4 notifications")
                self.assertFalse(self.item("homeNotificationEmpty").isVisible())
                for group, count in (("Today", 2), ("Yesterday", 1), ("Older", 1)):
                    self.assertEqual(len(self.item("homeNotificationGroup" + group).property("entries").toVariant()), count)
                self.assertEqual(self.item("homeNotificationToday0Title").property("text"), "Capture ready")
                self.assertFalse(self.item("homeNotificationToday1Body").isVisible())
                assert_bounds(page)
                self.capture(f"notifications-populated-{width}")

                self.click("homeClearHistory")
                dialog = self.window.findChild(QObject, "homeClearHistoryDialog")
                self.assertTrue(dialog.property("visible"))
                self.assertTrue(self.item("homeClearHistoryCancel").hasActiveFocus())
                assert_bounds(dialog.property("contentItem"))
                self.capture(f"notifications-confirm-{width}")
                self.click("homeClearHistoryCancel")
                self.assertFalse(dialog.property("visible"))
                self.assertEqual(evaluate("notificationData.notifications.length").toInt(), 4)
                self.click("homeClearHistory")
                QTest.keyClick(self.window, Qt.Key.Key_Escape)
                QTest.qWait(30)
                self.assertFalse(dialog.property("visible"))
                self.assertEqual(evaluate("notificationData.notifications.length").toInt(), 4)
                self.click("homeClearHistory")
                self.click("homeClearHistoryConfirm")
                self.assertEqual(evaluate("notificationData.notifications.length").toInt(), 0)
                self.assertTrue(self.item("homeNotificationEmpty").isVisible())
                self.assertFalse(self.item("homeClearHistory").isEnabled())
                for group in ("Today", "Yesterday", "Older"):
                    self.assertFalse(self.item("homeNotificationGroup" + group).isVisible())
                assert_bounds(page)
                self.capture(f"notifications-empty-{width}")

                evaluate('''
                    notificationData.notifications = [{id:"fixture-long",app:"<b>" + "Application".repeat(8) + "</b>",
                        title:"<b>" + "LongTitle".repeat(12) + "</b>",
                        body:"<img src='not-a-resource'> Literal markup. " + "UnbrokenBody".repeat(24) + "\\nLast line.",
                        time:notificationNow.getTime()}];
                ''')
                self.assertEqual(self.item("homeNotificationCount").property("text"), "1 notification")
                for suffix in ("App", "Title", "Body"):
                    label = self.item("homeNotificationToday0" + suffix)
                    self.engine.globalObject().setProperty("notificationLabel", self.engine.newQObject(label))
                    self.assertEqual(evaluate("notificationLabel.textFormat").toInt(), 0)
                    self.assertGreater(label.property("lineCount"), 1)
                app_label = self.item("homeNotificationToday0App")
                time_label = self.item("homeNotificationToday0Time")
                self.assertLessEqual(app_label.mapToScene(QPointF(app_label.width(), 0)).x(), time_label.mapToScene(QPointF(0, 0)).x())
                assert_bounds(page)
                flickable.setProperty("contentY", 0)
                QTest.qWait(30)
                self.capture(f"notifications-long-{width}")
                flickable.setProperty("contentY", max(0, flickable.property("contentHeight") - flickable.height()))
                QTest.qWait(30)
                body = self.item("homeNotificationToday0Body")
                self.assertLessEqual(body.mapToItem(flickable, QPointF(0, body.height())).y(), flickable.height() + 1)
                self.capture(f"notifications-long-end-{width}")
                self.assertEqual(evaluate("notificationCommands.length").toInt(), 0)

        evaluate('notificationData.live = true; notificationData.status = "Live desktop services";')
        self.assertEqual(self.item("homeServiceStatus").property("text"), "Session history")

    def test_system_graph_colors_gaps_and_responsive_details(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("systemFixture", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            return result

        evaluate('''
            var systemData = systemFixture.desktopData;
            systemData.freshness.stop();
            systemData.live = true;
            systemData.sampledAt = Date.now();
            systemData.clock = systemData.sampledAt;
            systemData.metrics = [
                {key:"cpu",title:"CPU usage",value:30,unit:"%",maximum:100},
                {key:"cpuTemp",title:"CPU temperature",value:55,unit:" C",maximum:110},
                {key:"memory",title:"Memory",value:40,unit:"%",maximum:100},
                {key:"swap",title:"Swap",value:20,unit:"%",maximum:100}
            ];
            for (let gpu=0;gpu<2;gpu++) {
                for (const [suffix,title,unit,maximum] of [["usage","Usage","%",100],["vram","VRAM"," MiB",32768],["temp","Temperature"," C",110],["power","Power"," W",450]]) {
                    systemData.metrics = systemData.metrics.concat([{
                        key:"gpu"+gpu+suffix,
                        gpuId:"gpu"+gpu,
                        gpuName:"NVIDIA workstation accelerator with a very long device name "+gpu,
                        title:"NVIDIA workstation accelerator with a very long device name "+gpu+" / "+title,
                        value:maximum/2,unit:unit,maximum:maximum
                    }]);
                }
            }
            systemData.metrics = systemData.metrics.concat([
                {key:"download",title:"Network download",value:768,unit:" KiB/s",maximum:1024},
                {key:"upload",title:"Network upload",value:128,unit:" KiB/s",maximum:256}
            ]);
            systemData.snapshot = {processes:[{pid:4312,name:"/opt/compute/long-running-model-worker-with-an-unbroken-name",memoryMiB:16384}],load:[1.25,2.5,3.75],uptime:3600,memory:{MemTotal:34359738368,MemAvailable:17179869184,SwapTotal:1073741824,SwapFree:536870912}};
            systemData.devices = Object.assign({},systemData.devices,{
                host:"workstation-with-a-long-unbroken-hostname",kernel:"Linux-test-kernel",cpu:"Multi-core workstation CPU",
                drives:[{name:"nvme0n1",size:2000000000000,type:"disk",children:[{name:"nvme0n1p1",type:"part",fstype:"btrfs",mountpoints:["/mnt/long-storage-mountpoint-for-models-and-checkpoints"],fsavail:500000000000,"fsuse%":"75%"}]}]
            });
        ''')
        self.home_action("homeSystemSummary")
        page = self.item("homeSystemPage")
        self.assertIsNone(self.window.findChild(QObject, "systemDetailsToggle"))
        self.assertTrue(self.item("systemDetails").isVisible())
        self.assertEqual(self.item("storageUsagenvme0n1p1").property("value"), 75)
        self.engine.globalObject().setProperty("systemPage", self.engine.newQObject(page))
        evaluate('''
            var systemHistory = {};
            for (const group of systemPage.graphGroups) {
                group.series.forEach((entry,index) => {
                    systemHistory[entry.key] = Array.from({length:60},(_,sampleIndex) =>
                        sampleIndex >= 27 && sampleIndex <= 32 ? null :
                        entry.maximum * (0.1 + index * 0.1 + 0.015 * Math.sin(sampleIndex / 4)));
                });
            }
            systemData.history = systemHistory;
        ''')

        def reveal(item):
            flickable = page.property("contentItem")
            content = flickable.property("contentItem")
            position = item.mapToItem(content, QPointF(0, 0)).y()
            maximum = max(0, flickable.property("contentHeight") - flickable.height())
            flickable.setProperty("contentY", min(maximum, max(0, position - 8)))
            QTest.qWait(60)

        def graph_image(graph):
            plot = self.item(graph.objectName() + "Plot", page)
            reveal(plot)
            grab = plot.grabToImage()
            self.assertIsNotNone(grab)
            QTest.qWait(100)
            image = grab.image()
            self.assertFalse(image.isNull())
            return image

        def color_pixels(image, color, series_index, left=0, right=None):
            center = image.height() - 2 - (0.1 + series_index * 0.1) * (image.height() - 4)
            return sum(
                pixel.alpha() > 100 and max(abs(pixel.red() - color.red()), abs(pixel.green() - color.green()), abs(pixel.blue() - color.blue())) < 12
                for column in range(left, image.width() if right is None else right)
                for row in range(max(0, round(center) - 4), min(image.height(), round(center) + 5))
                for pixel in [image.pixelColor(column, row)]
            )

        profiles = self.window.findChild(QObject, "profileSettings")
        self.engine.globalObject().setProperty("systemProfiles", self.engine.newQObject(profiles))
        previous_colors = {}
        for palette, width in [(palette, width) for palette in ("Chalk", "Phosphor") for width in (320, 375, 414, 768)]:
            with self.subTest(palette=palette, width=width):
                evaluate(f'systemProfiles.update("palette", "{palette}")')
                self.studio.setProperty("customWidth", width)
                QTest.qWait(60)
                groups = page.property("graphGroups").toVariant()
                self.assertEqual([group["key"] for group in groups], ["cpu", "memory", "gpu:gpu0", "gpu:gpu1", "network"])
                self.assertEqual([len(group["series"]) for group in groups], [2, 2, 4, 4, 2])
                self.assertEqual([entry["maximum"] for entry in groups[4]["series"]], [1024, 1024])
                pending = [page]
                plots = []
                while pending:
                    item = pending.pop()
                    pending.extend(item.childItems())
                    if item.objectName().startswith("resourceGraph") and item.objectName().endswith("Plot"):
                        plots.append(item)
                    if not item.isVisible() or not item.inherits("QQuickText"):
                        continue
                    self.assertLessEqual(item.property("contentWidth"), item.width() + 1, item.property("text"))
                    self.assertLessEqual(item.property("contentHeight"), item.height() + 1, item.property("text"))
                    ancestor = item.parentItem()
                    while ancestor and not ancestor.objectName().endswith("Legend"):
                        ancestor = ancestor.parentItem()
                    if ancestor:
                        continue
                    self.assertGreaterEqual(item.mapToItem(page, QPointF(0, 0)).x(), -1)
                    self.assertLessEqual(item.mapToItem(page, QPointF(item.width(), 0)).x(), page.width() + 1)
                self.assertEqual(len(plots), 5)
                for group in groups:
                    graph = self.item("resourceGraph" + group["key"], page)
                    self.engine.globalObject().setProperty("systemGraph", self.engine.newQObject(graph))
                    image = graph_image(graph)
                    colors = evaluate("systemGraph.series.map((entry,index) => String(systemGraph.lineColor(index)))").toVariant()
                    self.assertEqual(len(set(colors)), min(4, len(colors)))
                    if palette == "Chalk":
                        previous_colors[group["key"]] = colors
                        self.assertTrue(all(max(QColor(color).getRgb()[:3]) - min(QColor(color).getRgb()[:3]) > 40 for color in colors))
                    else:
                        self.assertEqual(colors, previous_colors[group["key"]])
                    frame = self.item("resourceFrame" + group["key"], page)
                    self.assertGreater(evaluate("systemGraph.parent.border.width").toNumber(), 0)
                    self.assertLessEqual(frame.property("radius"), 8)
                    for index, color in enumerate(colors):
                        self.assertGreater(color_pixels(image, QColor(color), index), 12, (palette, width, group["key"], index, color))
                        self.assertEqual(color_pixels(image, QColor(color), index, round(image.width() * 28 / 59), round(image.width() * 31 / 59)), 0)
                    self.assertGreater(color_pixels(image, QColor(colors[0]), 0), color_pixels(image, QColor(colors[1]), 1))
                    reveal(graph)
                    self.capture(f"system-compact-{palette}-{group['key']}-{width}")
                    self.assertTrue(image.save(str(ROOT / ".artifacts" / f"system-plot-{palette}-{group['key']}-{width}.png")))
                    if group["series"]:
                        legend = self.item(graph.objectName() + "Legend", page)
                        icons = [self.item(graph.objectName() + f"LegendIcon{index}", page) for index in range(len(group["series"]))]
                        self.assertEqual(legend.height(), 36)
                        self.assertLessEqual(legend.width(), graph.width())
                        self.assertEqual(len({icon.y() for icon in icons}), 1)
                        self.assertTrue(all(icon.width() > 32 and icon.height() == 32 for icon in icons))
                        self.assertTrue(all(left.x() + left.width() < right.x() for left, right in zip(icons, icons[1:])))
                        pending = list(legend.childItems())
                        readouts = []
                        while pending:
                            child = pending.pop()
                            pending.extend(child.childItems())
                            if child.isVisible() and child.inherits("QQuickText"):
                                if child.property("text"):
                                    self.assertFalse(child.property("truncated"), child.property("text"))
                                    readouts.append(child.property("text"))
                        self.assertCountEqual(readouts, [entry["reading"] for entry in group["series"]])
                        for index, icon in enumerate(icons):
                            entry = group["series"][index]
                            self.engine.globalObject().setProperty("systemLegendIcon", self.engine.newQObject(icon))
                            self.assertEqual(evaluate("String(systemLegendIcon.icon.color)").toString(), colors[index])
                            source = QUrl(evaluate("String(systemLegendIcon.icon.source)").toString()).toLocalFile()
                            self.assertTrue(Path(source).is_file(), source)
                            self.assertEqual(Path(source).stem, entry["iconName"])
                            self.assertFalse(icon.property("checkable"))
                            self.assertEqual(icon.property("text"), entry["reading"])
                            description = QAccessible.queryAccessibleInterface(icon).text(QAccessible.Text.Name)
                            self.assertIn(entry["title"], description)
                            self.assertIn(entry["reading"], description)
                            self.assertIn(f"scale 0 - {entry['maximum']}{entry['unit']}", description)
                        reveal(graph)
                        icons[0].forceActiveFocus()
                        for index, icon in enumerate(icons):
                            if index:
                                QTest.keyClick(self.window, Qt.Key.Key_Tab)
                            QTest.qWait(30)
                            self.assertTrue(icon.hasActiveFocus())
                            self.assertGreaterEqual(icon.x(), legend.property("contentX") - 1)
                            self.assertLessEqual(icon.x() + icon.width(), legend.property("contentX") + legend.width() + 1)
                            tooltip = icon.findChild(QObject, icon.objectName() + "Details")
                            self.assertIsNone(tooltip)
                        QTest.keyClick(self.window, Qt.Key.Key_Space)
                        self.assertEqual(len(graph.property("series")), len(group["series"]))
                        self.assertFalse(icons[-1].property("checked"))
                        self.engine.globalObject().setProperty("systemLegendIcon", self.engine.newQObject(icons[-1]))
                        expected_text_color = QColor(evaluate("String(systemLegendIcon.palette.buttonText)").toString())
                        pending = list(icons[-1].childItems())
                        while pending:
                            child = pending.pop()
                            pending.extend(child.childItems())
                            if child.isVisible() and child.inherits("QQuickText") and child.property("text"):
                                self.assertEqual(child.property("color"), expected_text_color)
                        self.capture(f"system-compact-focus-{palette}-{group['key']}-{width}")
                        self.item("homeSystemSummary").forceActiveFocus()
                        legend.setProperty("contentX", 0)
                        reveal(legend)
                        QTest.mouseMove(self.window, icons[0].mapToScene(QPointF(16, 16)).toPoint())
                        QTest.qWait(500)
                        self.assertTrue(icons[0].property("hovered"))
                        self.assertIsNone(icons[0].findChild(QObject, icons[0].objectName() + "Details"))
                        QTest.mouseMove(self.window, QPointF(0, 0).toPoint())
                        QTest.qWait(150)
                        self.assertTrue(all(not icon.hasActiveFocus() for icon in icons))
                        self.assertTrue(all(icon.findChild(QObject, icon.objectName() + "Details") is None for icon in icons))
                        reveal(graph)
                        self.capture(f"system-compact-{palette}-{group['key']}-{width}")
                    if group["key"] == "gpu:gpu1":
                        evaluate('systemData.metrics = systemData.metrics.map(entry => entry.key === "gpu1power" ? Object.assign({},entry,{value:null}) : entry)')
                        QTest.qWait(30)
                        graph = self.item("resourceGraphgpu:gpu1", page)
                        image = graph_image(graph)
                        self.assertTrue(graph.property("current"))
                        self.assertEqual(graph.property("series")[-1]["reading"], "--")
                        self.assertEqual(self.item("resourceGraphgpu:gpu1LegendIcon3", page).property("text"), "--")
                        self.assertIn("Unavailable", self.item("resourceGraphgpu:gpu1LegendIcon3", page).property("description"))
                        self.assertEqual(color_pixels(image, QColor(colors[-1]), 3), 0)
                        for index, color in enumerate(colors[:-1]):
                            self.assertGreater(color_pixels(image, QColor(color), index), 12)
                        evaluate('systemData.metrics = systemData.metrics.map(entry => entry.key === "gpu1power" ? Object.assign({},entry,{value:225}) : entry)')
                flickable = page.property("contentItem")
                flickable.setProperty("contentY", max(0, flickable.property("contentHeight") - flickable.height()))
                QTest.qWait(60)
                self.capture(f"system-compact-details-{palette}-{width}")
                evaluate("systemData.clock = systemData.sampledAt + 9000")
                for group in groups:
                    graph = self.item("resourceGraph" + group["key"], page)
                    self.assertFalse(graph.property("current"))
                    self.engine.globalObject().setProperty("systemGraph", self.engine.newQObject(graph))
                    image = graph_image(graph)
                    self.assertTrue(all(entry["reading"] == "--" for entry in graph.property("series")))
                    for index, color in enumerate(evaluate("systemGraph.lineColors.map(String)").toVariant()):
                        self.assertEqual(color_pixels(image, QColor(color), index), 0)
                reveal(self.item("resourceGraphcpu", page))
                self.capture(f"system-compact-unavailable-{palette}-{width}")
                evaluate("systemData.clock = systemData.sampledAt")

    def test_network_polish_states_bounds_and_intents(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("networkFixture", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            QTest.qWait(30)
            return result

        def activate(name):
            self.item(name).forceActiveFocus()
            QTest.keyClick(self.window, Qt.Key.Key_Space)
            QTest.qWait(30)

        def check_bounds(root):
            pending = [root]
            while pending:
                control = pending.pop()
                pending.extend(control.childItems())
                if not control.isVisible() or not (control.inherits("QQuickControl") or control.inherits("QQuickText")):
                    continue
                ancestor = control.parentItem()
                while ancestor:
                    if ancestor.clip():
                        start = control.mapToItem(ancestor, QPointF(0, 0))
                        end = control.mapToItem(ancestor, QPointF(control.width(), 0))
                        self.assertGreaterEqual(start.x(), -1, control.objectName())
                        self.assertLessEqual(end.x(), ancestor.width() + 1, control.objectName())
                    ancestor = ancestor.parentItem()
                if control.inherits("QQuickText"):
                    self.assertLessEqual(control.property("contentWidth"), control.width() + 1, control.property("text"))
                    self.assertLessEqual(control.property("contentHeight"), control.height() + 1, control.property("text"))

        def check_widths(state):
            for width in (320, 375, 414, 768):
                with self.subTest(state=state, width=width):
                    self.studio.setProperty("customWidth", width)
                    QTest.qWait(50)
                    page = self.item("homeDevicePage")
                    flickable = page.property("contentItem")
                    flickable.setProperty("contentY", 0)
                    QTest.qWait(30)
                    check_bounds(page)
                    self.capture(f"network-{state}-{width}")
                    flickable.setProperty("contentY", max(0, flickable.property("contentHeight") - flickable.height()))
                    QTest.qWait(30)
                    self.capture(f"network-{state}-lower-{width}")
                    flickable.setProperty("contentY", 0)

        evaluate('''
            var networkData = networkFixture.desktopData;
            networkData.live = true;
            networkData.status = "Test records / no host actions";
            var networkDevices = networkData.devices;
            networkDevices.wifi = true;
            networkDevices.network = [
                {name:"enp1s0",type:"ethernet",state:"connected",connection:"Studio wired connection",ipv4:["192.0.2.10/24"],ipv6:["2001:db8:1234:5678:90ab:cdef:1234:5678/64"],gateway:"192.0.2.1"},
                {name:"wlan0",type:"wifi",state:"connected",connection:"StudioNetworkWithAnUnbrokenLongSSID0123456789"},
                {name:"enp2s0",type:"ethernet",state:"disconnected",connection:"--"},
                {name:"tun0",type:"tun",state:"connected",connection:"Work VPN"}
            ];
            networkDevices.accessPoints = [
                {ssid:"StudioNetworkWithAnUnbrokenLongSSID0123456789",signal:87,security:"WPA2",active:true},
                {ssid:"<b>Guest network</b>",signal:0,security:""},
                {ssid:"",signal:null}
            ];
            networkDevices.savedNetworks = [{name:"StudioNetworkWithAnUnbrokenLongSSID0123456789",uuid:"fixture-uuid"}];
            networkData.devices = networkDevices;
            var networkCommands = [];
            networkData.commandRequested.connect(command => networkCommands.push(command));
            var publicLookups = 0;
            networkData.publicAddressRequested.connect(() => publicLookups++);
        ''')
        self.home_action("homeNetworkTab")
        for group in ("Ethernet", "Wi-Fi", "Virtual / VPN"):
            self.assertTrue(self.item("homeNetworkGroup" + group).isVisible())
        self.assertEqual(self.item("homeNetworkAddressenp1s0ipv4").property("text"), "192.0.2.10/24")
        self.assertEqual(self.item("homeNetworkAddressenp1s0gateway").property("text"), "192.0.2.1")
        self.assertEqual(self.item("homeNetworkPublicAddress").property("text"), "Not checked")
        self.assertEqual(evaluate("publicLookups").toInt(), 0)
        activate("homeNetworkPublicLookup")
        self.assertEqual(evaluate("publicLookups").toInt(), 1)
        evaluate('networkData.publicAddressBusy = true; networkData.publicAddressStatus = "Checking";')
        self.assertFalse(self.item("homeNetworkPublicLookup").isEnabled())
        activate("homeNetworkPublicLookup")
        self.assertEqual(evaluate("publicLookups").toInt(), 1)
        evaluate('networkData.publicAddressBusy = false; networkData.publicAddress = "198.51.100.7"; networkData.publicAddressStatus = "Checked";')
        self.assertEqual(self.item("homeNetworkPublicAddress").property("text"), "198.51.100.7")
        controls = ("homeNetworkWifi", "homeNetworkRefresh", "homeNetworkEditor", "homeNetworkDisconnectenp1s0", "homeNetworkDisconnectwlan0", "homeNetworkConnectenp2s0", "homeNetworkSavedConnect0", "homeNetworkSavedEdit0")
        for name in controls:
            self.assertFalse(self.item(name).isEnabled(), name)
            activate(name)
        self.assertEqual(evaluate("networkCommands.length").toInt(), 0)
        self.assertEqual(self.item("homeNetworkState").property("text"), "Read-only")
        self.assertEqual(self.item("homeNetworkSsid1").property("text"), "<b>Guest network</b>")
        check_widths("readonly")
        evaluate("networkData.controlsEnabled = true;")
        check_widths("populated")
        for name, expected in (
            ("homeNetworkRefresh", ["nmcli", "device", "wifi", "rescan"]),
            ("homeNetworkEditor", ["nm-connection-editor"]),
            ("homeNetworkConnectenp2s0", ["nmcli", "device", "connect", "enp2s0"]),
            ("homeNetworkSavedConnect0", ["nmcli", "connection", "up", "uuid", "fixture-uuid"]),
            ("homeNetworkSavedEdit0", ["nm-connection-editor", "--edit", "fixture-uuid"]),
            ("homeNetworkWifi", ["nmcli", "radio", "wifi", "off"]),
        ):
            activate(name)
            self.assertEqual(evaluate("networkCommands.pop()").toVariant(), expected)

        long_device = "enpLongUnbrokenNetworkDeviceIdentifier0123456789"
        evaluate(f'networkDevices.network[0].name = "{long_device}"; networkData.devices = networkDevices;')
        for width in (320, 375, 414, 768):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            activate("homeNetworkDisconnect" + long_device)
            dialog = self.window.findChild(QObject, "homeNetworkDisconnectDialog")
            self.assertTrue(dialog.property("visible"))
            self.assertTrue(self.item("homeNetworkDisconnectCancel").hasActiveFocus())
            self.assertEqual(self.item("homeNetworkDisconnectTarget").property("text"), long_device)
            check_bounds(dialog.property("contentItem"))
            self.capture(f"network-disconnect-{width}")
            activate("homeNetworkDisconnectCancel")
            self.assertFalse(dialog.property("visible"))
            self.assertEqual(evaluate("networkCommands.length").toInt(), 0)
            activate("homeNetworkDisconnect" + long_device)
            activate("homeNetworkDisconnectConfirm")
            self.assertEqual(evaluate("networkCommands.pop()").toVariant(), ["nmcli", "device", "disconnect", long_device])

        for guard, setup, reset in (
            ("busy", "networkData.busy = true", "networkData.busy = false"),
            ("readonly", "networkData.controlsEnabled = false", "networkData.controlsEnabled = true"),
            ("inactive", 'networkDevices.network[0].state = "disconnected"; networkData.devices = networkDevices', 'networkDevices.network[0].state = "connected"; networkData.devices = networkDevices'),
        ):
            activate("homeNetworkDisconnect" + long_device)
            evaluate(setup)
            self.assertFalse(self.item("homeNetworkDisconnectConfirm").isEnabled(), guard)
            activate("homeNetworkDisconnectConfirm")
            self.assertEqual(evaluate("networkCommands.length").toInt(), 0)
            dialog.accept()
            self.assertEqual(evaluate("networkCommands.length").toInt(), 0)
            evaluate(reset)

        evaluate("networkData.busy = true;")
        for name in controls:
            if name == "homeNetworkDisconnectenp1s0":
                name = "homeNetworkDisconnect" + long_device
            self.assertFalse(self.item(name).isEnabled(), name)
            activate(name)
        evaluate('networkData.request(["nmcli","device","wifi","rescan"]);')
        self.assertEqual(evaluate("networkCommands.length").toInt(), 0)
        check_widths("busy")
        evaluate('networkData.busy = false; networkData.status = "Network action failed";')
        self.assertEqual(self.item("homeServiceStatus").property("text"), "Network action failed")
        check_widths("error")
        evaluate('networkData.status = "Test records / no host actions"; networkDevices.wifi = false; networkData.devices = networkDevices;')
        self.assertFalse(self.item("homeNetworkRefresh").isEnabled())
        self.assertFalse(self.item("homeNetworkSavedConnect0").isEnabled())
        self.assertTrue(self.item("homeNetworkEditor").isEnabled())
        self.assertEqual(self.item("homeNetworkScanState").property("text"), "Wi-Fi off")
        check_widths("radio-off")
        evaluate('networkDevices.wifi = true; networkDevices.savedNetworks[0].uuid = ""; networkData.devices = networkDevices;')
        self.assertFalse(self.item("homeNetworkSavedConnect0").isEnabled())
        self.assertFalse(self.item("homeNetworkSavedEdit0").isEnabled())
        evaluate('networkDevices.network = []; networkDevices.accessPoints = []; networkDevices.savedNetworks = []; networkData.devices = networkDevices;')
        self.assertEqual(self.item("homeNetworkEmpty").property("text"), "No network devices reported")
        self.assertEqual(self.item("homeNetworkScanState").property("text"), "No networks reported")
        self.assertEqual(self.item("homeNetworkSavedState").property("text"), "No saved connections")
        check_widths("empty")
        evaluate('delete networkDevices.accessPoints; delete networkDevices.savedNetworks; networkData.devices = networkDevices;')
        self.assertEqual(self.item("homeNetworkScanState").property("text"), "Network scan unavailable")
        self.assertEqual(self.item("homeNetworkSavedState").property("text"), "Saved connections unavailable")
        check_widths("unavailable")
        evaluate('networkData.live = false; networkData.controlsEnabled = false; networkData.request(["nm-connection-editor"]);')
        self.assertEqual(evaluate("networkCommands.length").toInt(), 0)
        self.assertEqual(self.item("homeNetworkEmpty").property("text"), "Network data unavailable")
        check_widths("preview")

    def test_monitor_drag_stable_and_applies_on_release(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.studio.setProperty("customWidth", 768)
        self.engine.globalObject().setProperty("dragFixture", self.engine.newQObject(self.fixtures))
        result = self.engine.evaluate('''
            var dragData = dragFixture.desktopData;
            dragData.controlsEnabled = true;
            dragData.devices = Object.assign({},dragData.devices,{monitors:[
                {name:"DP-1",width:1920,height:1080,refreshRate:144,availableModes:["1920x1080@144Hz"],scale:1,transform:0,x:0,y:0},
                {name:"DP-2",width:1920,height:1080,refreshRate:144,availableModes:["1920x1080@144Hz"],scale:1,transform:0,x:1920,y:0}
            ]});
            var dragRequests = [];
            dragData.displayArrangementRequested.connect(positions => dragRequests.push(positions));
        ''')
        self.assertFalse(result.isError(), result.toString())
        self.home_action("homeDisplayTab")
        QTest.qWait(50)
        tile = self.item("monitorTileDP-2")
        page = self.item("homeDevicePage")
        flickable = page.property("contentItem")
        initial_scroll = flickable.property("contentY")
        initial_position = tile.position()
        start = tile.mapToScene(QPointF(tile.width() / 2, tile.height() / 2)).toPoint()
        end = start + QPointF(20, 30).toPoint()
        board = self.item("monitorArrangementBoard")
        delta = board.mapFromScene(QPointF(end)) - board.mapFromScene(QPointF(start))
        QTest.mousePress(self.window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, start)
        QTest.mouseMove(self.window, end, 20)
        QTest.qWait(80)
        self.assertAlmostEqual(tile.x(), initial_position.x() + delta.x(), delta=1)
        self.assertAlmostEqual(tile.y(), initial_position.y() + delta.y(), delta=1)
        self.assertEqual(flickable.property("contentY"), initial_scroll)
        self.assertEqual(self.engine.evaluate("dragRequests.length").toInt(), 0)
        QTest.mouseMove(self.window, end, 20)
        QTest.qWait(80)
        self.assertAlmostEqual(tile.x(), initial_position.x() + delta.x(), delta=1)
        self.assertAlmostEqual(tile.y(), initial_position.y() + delta.y(), delta=1)
        QTest.mouseRelease(self.window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, end)
        QTest.qWait(30)
        requests = self.engine.evaluate("dragRequests").toVariant()
        self.assertEqual(len(requests), 1)
        self.assertEqual(requests[0][0]["name"], "DP-2")
        self.assertGreater(requests[0][0]["y"], 0)
        tile = self.item("monitorTileDP-1")
        point = tile.mapToScene(QPointF(tile.width() / 2, tile.height() / 2)).toPoint()
        QTest.mouseClick(self.window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, point)
        self.assertEqual(self.engine.evaluate("dragRequests.length").toInt(), 1)
        self.engine.evaluate("dragData.displayPending = true;")
        QTest.qWait(30)
        self.assertFalse(self.item("monitorArrangementDragArea").property("enabled"))

    def test_monitor_edge_snapping_has_no_gaps(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("snapFixture", self.engine.newQObject(self.fixtures))
        result = self.engine.evaluate('''
            var snapData = snapFixture.desktopData;
            snapData.controlsEnabled = true;
            snapData.devices = Object.assign({},snapData.devices,{monitors:[
                {name:"DP-1",width:5120,height:1440,scale:1,transform:0,x:0,y:0},
                {name:"DP-2",width:1920,height:1080,scale:1,transform:0,x:1600,y:1440}
            ]});
            var snapRequests = [];
            snapData.displayArrangementRequested.connect(positions => snapRequests.push(positions));
        ''')
        self.assertFalse(result.isError(), result.toString())
        self.home_action("homeDisplayTab")
        self.engine.globalObject().setProperty("snapMap", self.engine.newQObject(self.item("homeMonitorArrangement")))
        for horizontal, vertical, expected_x, expected_y in (
            (1200, 1900, 1200, 1440),
            (1200, -1500, 1200, -1080),
            (5600, 350, 5120, 360),
            (-2400, 350, -1920, 360),
        ):
            with self.subTest(horizontal=horizontal, vertical=vertical):
                result = self.engine.evaluate(f'snapMap.reload(); snapMap.moveOutput("DP-2",{horizontal},{vertical},true); snapRequests.pop();')
                self.assertFalse(result.isError(), result.toString())
                self.assertEqual(result.toVariant(), [{"name":"DP-2","x":expected_x,"y":expected_y}])
        result = self.engine.evaluate('''
            snapData.devices = Object.assign({},snapData.devices,{monitors:snapData.devices.monitors.map(output =>
                output.name === "DP-1" ? Object.assign({},output,{scale:2,transform:1}) : output)});
            snapMap.reload(); snapMap.moveOutput("DP-2",0,3000,true); snapRequests.pop();
        ''')
        self.assertEqual(result.toVariant(), [{"name":"DP-2","x":0,"y":2560}])

    def test_display_polish_states_bounds_and_keyboard(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("displayFixture", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            QTest.qWait(30)
            return result

        def check_widths(state):
            for width in (320, 375, 414, 768):
                with self.subTest(state=state, width=width):
                    self.studio.setProperty("customWidth", width)
                    QTest.qWait(50)
                    pending = [self.item("homeDevicePage")]
                    while pending:
                        control = pending.pop()
                        pending.extend(control.childItems())
                        if not control.isVisible() or not (control.inherits("QQuickControl") or control.inherits("QQuickText")):
                            continue
                        ancestor = control.parentItem()
                        while ancestor:
                            if ancestor.clip():
                                start = control.mapToItem(ancestor, QPointF(0, 0))
                                end = control.mapToItem(ancestor, QPointF(control.width(), 0))
                                self.assertGreaterEqual(start.x(), -1, control.objectName())
                                self.assertLessEqual(end.x(), ancestor.width() + 1, control.objectName())
                            ancestor = ancestor.parentItem()
                        if control.inherits("QQuickText") and control.objectName().startswith("homeDisplay"):
                            self.assertLessEqual(control.property("contentWidth"), control.width() + 1)
                            self.assertLessEqual(control.property("contentHeight"), control.height() + 1)
                    for monitor in evaluate("displayData.devices.monitors.map(monitor => monitor.name)").toVariant():
                        mode_control = self.item("homeDisplayMode" + monitor)
                        scale_control = self.item("homeDisplayScale" + monitor)
                        rotation_control = self.item("homeDisplayRotation" + monitor)
                        self.assertAlmostEqual(mode_control.width(), self.item("homeDisplaySummary" + monitor).width(), delta=1)
                        self.assertGreaterEqual(rotation_control.width(), 160)
                        self.assertAlmostEqual(scale_control.width(), rotation_control.width(), delta=1)
                        scale_start = scale_control.mapToItem(self.item("homeDevicePage"), QPointF(0, 0))
                        rotation_start = rotation_control.mapToItem(self.item("homeDevicePage"), QPointF(0, 0))
                        if abs(scale_start.y() - rotation_start.y()) < 1:
                            self.assertGreaterEqual(rotation_start.x(), scale_start.x() + scale_control.width() + 15)
                        else:
                            self.assertGreaterEqual(rotation_start.y(), scale_start.y() + scale_control.height() + 12)
                    self.capture(f"displays-{state}-{width}")

        evaluate('''
            var displayData = displayFixture.desktopData;
            displayData.live = true;
            displayData.status = "Test records / no host actions";
            var displayDevices = displayData.devices;
            var displayPrimary = {name:"DP-1",description:"Studio monitor / USB-C display",width:1920,height:1080,refreshRate:144,availableModes:["1920x1080@60.00Hz","1920x1080@144.00Hz"],scale:1,transform:0,x:0,y:0,vrr:true};
            var displaySecondary = {name:"HDMI-A-LongUnbrokenMonitorConnectorName",description:"UltraWideMonitorWithAnUnbrokenLongManufacturerAndModelName",width:3440,height:1440,refreshRate:59.97,availableModes:["3440x1440@59.97Hz"],scale:1.25,transform:0,x:1920,y:0,vrr:false};
            displayDevices.monitors = [displayPrimary];
            displayData.devices = displayDevices;
            var displayRequests = [];
            displayData.displayRequested.connect((monitor, mode, scale, transform) => displayRequests.push([monitor.name, mode, scale, transform]));
        ''')
        self.home_action("homeDisplayTab")
        self.assertEqual(self.item("homeDisplayTab").property("iconName"), "monitor")
        self.assertEqual(self.item("homeDisplayModeDP-1").property("currentIndex"), 0)
        self.assertEqual(self.item("homeDisplayMaximumDP-1").property("text"), "Up to 144 Hz")
        self.assertEqual(self.item("homeDisplaySummaryDP-1").property("text"), "1920 x 1080 / 144.00 Hz")
        controls = ("homeDisplayModeDP-1", "homeDisplayScaleDP-1", "homeDisplayRotationDP-1", "homeDisplayApplyDP-1")
        for name in controls:
            self.assertFalse(self.item(name).isEnabled(), name)
        check_widths("readonly")
        evaluate("displayData.controlsEnabled = true;")
        self.assertFalse(self.item("homeDisplayApplyDP-1").isEnabled())
        self.assertEqual(self.item("homeDisplayStateDP-1").property("text"), "Current settings")
        check_widths("populated")

        mode = self.item("homeDisplayModeDP-1")
        mode.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(mode.property("currentIndex"), 1)
        self.assertTrue(self.item("homeDisplayApplyDP-1").isEnabled())
        self.assertEqual(self.item("homeDisplayStateDP-1").property("text"), "Changes not applied")
        self.item("homeDisplayApplyDP-1").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertEqual(evaluate("displayRequests.pop()").toVariant(), ["DP-1", "1920x1080@60.00Hz", 1, 0])
        mode.setProperty("currentIndex", 0)
        self.assertFalse(self.item("homeDisplayApplyDP-1").isEnabled())
        self.item("homeDisplayScaleDP-1Number").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Up)
        self.assertEqual(self.item("homeDisplayScaleDP-1").property("value"), 125)
        rotation = self.item("homeDisplayRotationDP-1")
        rotation.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.item("homeDisplayApplyDP-1").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertEqual(evaluate("displayRequests.pop()").toVariant(), ["DP-1", "1920x1080@144.00Hz", 1.25, 1])
        self.capture("displays-edited-768")

        for guard in ("busy", "displayPending"):
            evaluate(f"displayData.{guard} = true; displayData.displayCountdown = 12;")
            for name in controls:
                self.assertFalse(self.item(name).isEnabled(), name)
                self.item(name).forceActiveFocus()
                QTest.keyClick(self.window, Qt.Key.Key_Space)
            self.assertEqual(evaluate("displayRequests.length").toInt(), 0)
            self.capture(f"displays-{guard}-768")
            evaluate(f"displayData.{guard} = false;")

        evaluate("displayDevices.monitors = [displayPrimary, displaySecondary]; displayData.devices = displayDevices;")
        check_widths("multiple")
        secondary_name = "HDMI-A-LongUnbrokenMonitorConnectorName"
        self.assertEqual(self.item("homeDisplaySummary" + secondary_name).property("text"), "3440 x 1440 / 59.97 Hz")
        page = self.item("homeDevicePage")
        flickable = page.property("contentItem")
        for width in (320, 375, 414, 768):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            flickable.setProperty("contentY", max(0, flickable.property("contentHeight") - flickable.height()))
            QTest.qWait(30)
            self.capture(f"displays-multiple-bottom-{width}")
        evaluate("displayPrimary.availableModes = ['1280x720@60.00Hz']; displayDevices.monitors = [displayPrimary]; displayData.devices = displayDevices;")
        self.assertEqual(self.item("homeDisplayModeDP-1").property("currentIndex"), -1)
        self.assertEqual(self.item("homeDisplayModeDP-1").property("displayText"), "Select mode")
        self.assertFalse(self.item("homeDisplayApplyDP-1").isEnabled())
        self.item("homeDisplayModeDP-1").setProperty("currentIndex", 0)
        self.assertTrue(self.item("homeDisplayApplyDP-1").isEnabled())
        evaluate("displayPrimary.availableModes = []; displayPrimary.scale = null; displayPrimary.refreshRate = null; displayDevices.monitors = [displayPrimary]; displayData.devices = displayDevices;")
        self.assertEqual(self.item("homeDisplayModeDP-1").property("displayText"), "Modes unavailable")
        self.assertIn("Refresh unavailable", self.item("homeDisplaySummaryDP-1").property("text"))
        self.assertFalse(self.item("homeDisplayScaleDP-1").isEnabled())
        self.assertFalse(self.item("homeDisplayApplyDP-1").isEnabled())
        check_widths("unavailable")
        evaluate("displayDevices.monitors = []; displayData.devices = displayDevices;")
        self.assertTrue(self.item("homeDisplayEmptyState").isVisible())
        self.assertEqual(evaluate("displayRequests.length").toInt(), 0)
        check_widths("disconnected")

    def test_weather_polish_states_bounds_validation_and_forecasts(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("weatherFixture", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            QTest.qWait(30)
            return result

        def check_widths(state):
            for width in (320, 375, 414, 768):
                with self.subTest(state=state, width=width):
                    self.studio.setProperty("customWidth", width)
                    QTest.qWait(50)
                    pending = [self.item("homePageLoader")]
                    while pending:
                        control = pending.pop()
                        pending.extend(control.childItems())
                        if not control.isVisible() or not (control.inherits("QQuickControl") or control.inherits("QQuickText")):
                            continue
                        ancestor = control.parentItem()
                        while ancestor:
                            if ancestor.clip():
                                start = control.mapToItem(ancestor, QPointF(0, 0))
                                end = control.mapToItem(ancestor, QPointF(control.width(), 0))
                                self.assertGreaterEqual(start.x(), -1, control.objectName())
                                self.assertLessEqual(end.x(), ancestor.width() + 1, control.objectName())
                            ancestor = ancestor.parentItem()
                        if control.inherits("QQuickText"):
                            self.assertLessEqual(control.property("contentWidth"), control.width() + 1, control.objectName())
                    flickable = self.item("homeDevicePage").property("contentItem")
                    flickable.setProperty("contentY", 0)
                    QTest.qWait(30)
                    self.capture(f"weather-{state}-{width}")
                    if state == "populated":
                        for kind, count in (("hourly", 3), ("daily", 2)):
                            for index in range(count):
                                prefix = f"homeWeather{kind}Row{index}"
                                time = self.item(prefix + "Time")
                                first = self.item(prefix + "First")
                                second = self.item(prefix + "Second")
                                self.assertLessEqual(time.mapToScene(QPointF(time.width(), 0)).x(), first.mapToScene(QPointF(0, 0)).x())
                                self.assertLessEqual(first.mapToScene(QPointF(first.width(), 0)).x(), second.mapToScene(QPointF(0, 0)).x())
                        forecast = self.item("homeWeatherhourlyRow0")
                        content = flickable.property("contentItem")
                        maximum = max(0, flickable.property("contentHeight") - flickable.height())
                        flickable.setProperty("contentY", min(maximum, max(0, forecast.mapToItem(content, QPointF(0, 0)).y() - 56)))
                        QTest.qWait(30)
                        self.capture(f"weather-{state}-forecast-{width}")
                    flickable.setProperty("contentY", max(0, flickable.property("contentHeight") - flickable.height()))
                    QTest.qWait(30)
                    button = self.item("homeWeatherLocation")
                    self.assertGreaterEqual(button.mapToItem(flickable, QPointF(0, 0)).y(), 0)
                    self.assertLessEqual(button.mapToItem(flickable, QPointF(0, button.height())).y(), flickable.height() + 1)
                    self.assertEqual(button.height(), 44)
                    self.capture(f"weather-{state}-location-{width}")

        evaluate('''
            var weatherData = weatherFixture.desktopData;
            var weatherRequests = [];
            var weatherCommands = [];
            weatherData.weatherRequested.connect((latitude, longitude) => weatherRequests.push([latitude, longitude]));
            weatherData.commandRequested.connect(command => weatherCommands.push(command));
        ''')
        self.home_action("homeWeatherTab")
        self.assertEqual(self.item("homeWeatherTemperature").property("text"), "-- C")
        self.assertEqual(self.item("homeWeatherStatus").property("text"), "Location not configured")
        self.assertTrue(self.item("homeWeatherhourlyEmpty").isVisible())
        self.assertTrue(self.item("homeWeatherdailyEmpty").isVisible())
        check_widths("empty")

        latitude = self.item("homeWeatherLatitude")
        longitude = self.item("homeWeatherLongitude")
        latitude.setProperty("text", "91")
        longitude.setProperty("text", "not-a-number")
        self.click("homeWeatherLocation")
        self.assertTrue(self.item("homeWeatherLatitudeHint").property("text").startswith("Invalid latitude"))
        self.assertTrue(self.item("homeWeatherLongitudeHint").property("text").startswith("Invalid longitude"))
        self.assertEqual(evaluate("weatherRequests.length").toInt(), 0)
        check_widths("invalid")
        for north, east in (("", "0"), ("0", "181"), ("Infinity", "0")):
            latitude.setProperty("text", north)
            longitude.setProperty("text", east)
            self.click("homeWeatherLocation")
            self.assertEqual(evaluate("weatherRequests.length").toInt(), 0)
        latitude.setProperty("text", "0")
        longitude.setProperty("text", "0")
        button = self.item("homeWeatherLocation")
        button.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        QTest.qWait(30)
        self.assertEqual(evaluate("weatherRequests").toVariant(), [["0", "0"]])
        self.assertIn("provider not connected", self.item("homeWeatherStatus").property("text"))
        self.assertEqual(self.item("homeWeatherPlace").property("text"), "Coordinates configured")
        self.assertFalse(latitude.property("invalid"))
        self.assertFalse(longitude.property("invalid"))
        self.assertEqual(self.item("homeWeatherTemperature").property("text"), "-- C")
        check_widths("configured")

        evaluate('''
            weatherData.status = "Test records / no host actions";
            weatherData.weatherStatus = "Test fixture / Weather provider not connected";
            weatherData.weather = {
                location:"TestLocationWithAnUnbrokenLongName / Northern observation station",
                temperature:-12,condition:"Light snow",feelsLike:-18,minimum:-20,maximum:0,
                wind:12.5,uv:0,sunrise:"07:32",sunset:"18:04",
                timezone:"TestRegion/AnUnbrokenLongTimezoneIdentifier",
                hourly:[{time:"09:00",temperature:-12,rain:0},{time:"10:00",temperature:0,rain:45},{time:"11:00",temperature:null,rain:null}],
                daily:[{date:"2026-09-18",minimum:-20,maximum:0},{date:"2026-09-19",minimum:-10,maximum:2}]
            };
        ''')
        self.assertEqual(self.item("homeWeatherTemperature").property("text"), "-12 C")
        self.assertEqual(self.item("homeWeatherMetricwind").property("text"), "12.5 km/h")
        self.assertEqual(self.item("homeWeatherMetricuv").property("text"), "0.0")
        self.assertEqual(self.item("homeWeatherhourlyRow0Second").property("text"), "0")
        self.assertEqual(self.item("homeWeatherhourlyRow2First").property("text"), "--")
        self.assertFalse(self.item("homeWeatherhourlyEmpty").isVisible())
        self.assertFalse(self.item("homeWeatherdailyEmpty").isVisible())
        check_widths("populated")
        evaluate('weatherData.weather = {location:"Test station",temperature:0,hourly:[],daily:[]};')
        self.assertEqual(self.item("homeWeatherTemperature").property("text"), "0 C")
        self.assertEqual(self.item("homeWeatherMetricwind").property("text"), "-- km/h")
        self.assertTrue(self.item("homeWeatherhourlyEmpty").isVisible())
        self.assertTrue(self.item("homeWeatherdailyEmpty").isVisible())
        check_widths("partial")
        self.assertEqual(evaluate("weatherCommands.length").toInt(), 0)
        self.assertEqual(self.warnings, [])

    def test_power_polish_states_batteries_bounds_and_keyboard(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("powerFixture", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            QTest.qWait(30)
            return result

        def check_widths(state):
            for width in (320, 375, 414, 768):
                with self.subTest(state=state, width=width):
                    self.studio.setProperty("customWidth", width)
                    QTest.qWait(50)
                    pending = [self.item("homePageLoader")]
                    while pending:
                        control = pending.pop()
                        pending.extend(control.childItems())
                        if not control.isVisible() or not (control.inherits("QQuickControl") or control.inherits("QQuickText")):
                            continue
                        ancestor = control.parentItem()
                        while ancestor:
                            if ancestor.clip():
                                start = control.mapToItem(ancestor, QPointF(0, 0))
                                end = control.mapToItem(ancestor, QPointF(control.width(), 0))
                                self.assertGreaterEqual(start.x(), -1, control.objectName())
                                self.assertLessEqual(end.x(), ancestor.width() + 1, control.objectName())
                            ancestor = ancestor.parentItem()
                        if control.inherits("QQuickText"):
                            self.assertLessEqual(control.property("contentWidth"), control.width() + 1, control.objectName())
                    for key in ("power-saver", "balanced", "performance"):
                        option = self.item("homePowerProfile" + key)
                        self.assertEqual(option.height(), 44)
                        labels = list(option.childItems())
                        while labels:
                            label = labels.pop()
                            labels.extend(label.childItems())
                            if label.inherits("QQuickText"):
                                self.assertEqual(label.property("lineCount"), 1)
                                self.assertFalse(label.property("truncated"))
                    for index in range(evaluate("powerDevices.batteries.length").toInt()):
                        name = self.item("homePowerBatteryName" + str(index))
                        percent = self.item("homePowerBatteryPercent" + str(index))
                        state_label = self.item("homePowerBatteryState" + str(index))
                        self.assertLessEqual(name.mapToScene(QPointF(name.width(), 0)).x(), percent.mapToScene(QPointF(0, 0)).x())
                        self.assertLessEqual(name.mapToScene(QPointF(0, name.height())).y(), state_label.mapToScene(QPointF(0, 0)).y())
                    self.capture(f"power-{state}-{width}")
                    if evaluate("powerDevices.batteries.length").toInt():
                        flickable = self.item("homeDevicePage").property("contentItem")
                        flickable.setProperty("contentY", max(0, flickable.property("contentHeight") - flickable.height()))
                        QTest.qWait(30)
                        last_index = evaluate("powerDevices.batteries.length - 1").toInt()
                        last_state = self.item("homePowerBatteryState" + str(last_index))
                        bottom = last_state.mapToItem(flickable, QPointF(0, last_state.height())).y()
                        self.assertLessEqual(bottom, flickable.height() + 1)
                        self.assertGreaterEqual(last_state.mapToItem(flickable, QPointF(0, 0)).y(), 0)
                        self.capture(f"power-{state}-batteries-{width}")
                        flickable.setProperty("contentY", 0)
                        QTest.qWait(30)

        evaluate('''
            var powerData = powerFixture.desktopData;
            powerData.status = "Test records / no host actions";
            var powerDevices = powerData.devices;
            powerDevices.powerProfiles = ["power-saver", "balanced", "performance"];
            powerDevices.powerProfile = "balanced";
            powerDevices.batteries = [
                {model:"Wireless studio headphones / a very long device name",percentage:"75%",state:"discharging"},
                {model:"KeyboardWithAnUnbrokenLongDeviceNameAndIdentifier",percentage:0,state:"pending-charge"}
            ];
            powerData.devices = powerDevices;
            var powerCommands = [];
            powerData.commandRequested.connect(command => powerCommands.push(command));
        ''')
        self.home_action("homePowerTab")
        keys = ("power-saver", "balanced", "performance")
        self.assertEqual(self.item("homePowerActiveProfile").property("text"), "Balanced")
        self.assertEqual(self.item("homePowerBatteryPercent0").property("text"), "75%")
        self.assertEqual(self.item("homePowerBatteryPercent1").property("text"), "0%")
        self.assertEqual(self.item("homePowerBatteryState1").property("text"), "pending charge")
        self.assertFalse(self.item("homePowerBatteryEmpty").isVisible())
        self.assertEqual(self.item("homePowerState").property("text"), "Read-only")
        for key in keys:
            option = self.item("homePowerProfile" + key)
            self.assertFalse(option.isEnabled())
            accessible = QAccessible.queryAccessibleInterface(option)
            self.assertIsNotNone(accessible)
            self.assertEqual(accessible.role(), QAccessible.Role.RadioButton)
            self.assertTrue(accessible.state().checkable)
            self.assertEqual(bool(accessible.state().checked), key == "balanced")
            option.clicked.emit()
        self.assertEqual(evaluate("powerCommands.length").toInt(), 0)
        check_widths("read-only")

        evaluate("powerData.controlsEnabled = true")
        self.item("homePowerProfilebalanced").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertTrue(self.item("homePowerProfileperformance").hasActiveFocus())
        self.assertEqual(evaluate("powerCommands.pop()").toVariant(), ["powerprofilesctl", "set", "performance"])
        self.assertTrue(self.item("homePowerProfilebalanced").property("checked"))
        self.assertFalse(self.item("homePowerProfileperformance").property("checked"))
        check_widths("populated")
        evaluate("powerData.busy = true")
        self.assertEqual(self.item("homePowerState").property("text"), "Action in progress")
        for key in keys:
            option = self.item("homePowerProfile" + key)
            self.assertFalse(option.isEnabled())
            option.clicked.emit()
        self.assertEqual(evaluate("powerCommands.length").toInt(), 0)
        check_widths("busy")

        evaluate('powerData.busy = false; powerDevices.powerProfile = "performance"; powerData.devices = powerDevices;')
        self.assertTrue(self.item("homePowerProfileperformance").property("checked"))
        self.assertFalse(self.item("homePowerProfilebalanced").property("checked"))
        self.item("homePowerProfileperformance").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertEqual(evaluate("powerCommands.length").toInt(), 0)
        evaluate('powerDevices.powerProfiles = ["power-saver", "balanced"]; powerData.devices = powerDevices;')
        self.assertEqual(self.item("homePowerProfileStateperformance").property("text"), "Active / Unavailable")
        self.item("homePowerProfileperformance").clicked.emit()
        self.assertEqual(evaluate("powerCommands.length").toInt(), 0)
        self.item("homePowerProfilebalanced").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertTrue(self.item("homePowerProfilepower-saver").hasActiveFocus())
        self.assertEqual(evaluate("powerCommands.pop()").toVariant(), ["powerprofilesctl", "set", "power-saver"])
        evaluate('powerDevices.powerProfile = "balanced"; powerData.devices = powerDevices;')
        self.item("homePowerProfilepower-saver").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertEqual(evaluate("powerCommands.pop()").toVariant(), ["powerprofilesctl", "set", "power-saver"])
        evaluate('powerData.status = "Action failed: check service availability and permissions";')
        self.assertTrue(self.item("homePowerProfilebalanced").property("checked"))
        self.assertIn("Action failed", self.item("homeServiceStatus").property("text"))
        check_widths("unsupported-error")

        evaluate('powerDevices.powerProfile = "vendor-custom"; powerData.devices = powerDevices;')
        self.assertEqual(self.item("homePowerActiveProfile").property("text"), "vendor-custom")
        self.assertEqual(self.item("homePowerState").property("text"), "Active profile not in these options")
        for key in keys:
            self.assertFalse(self.item("homePowerProfile" + key).property("checked"))
        for value, expected in (("null", "Unknown"), ('""', "Unknown"), ('"n/a"', "Unknown"), ("-1", "Unknown"), ("101", "Unknown"), ('"0%"', "0%"), ('"42.5%"', "42.5%"), ("100", "100%")):
            with self.subTest(percentage=value):
                evaluate(f"powerDevices.batteries[0].percentage = {value}; powerData.devices = powerDevices;")
                self.assertEqual(self.item("homePowerBatteryPercent0").property("text"), expected)
        evaluate('powerDevices.batteries = [{vendor:"Reported vendor",state:"",percentage:null},{}]; powerData.devices = powerDevices;')
        self.assertEqual(self.item("homePowerBatteryName0").property("text"), "Reported vendor")
        self.assertEqual(self.item("homePowerBatteryName1").property("text"), "Battery")
        self.assertEqual(self.item("homePowerBatteryState0").property("text"), "State unknown")
        self.assertEqual(self.item("homePowerBatteryPercent1").property("text"), "Unknown")
        check_widths("unknown")
        evaluate('powerDevices.powerProfile = ""; powerData.devices = powerDevices;')
        self.assertEqual(self.item("homePowerState").property("text"), "Active profile unavailable")
        evaluate('powerDevices.powerProfiles = []; powerDevices.batteries = []; powerData.devices = powerDevices; powerData.status = "Live services are unavailable in the native preview";')
        self.assertEqual(self.item("homePowerState").property("text"), "Power profile service unavailable")
        self.assertTrue(self.item("homePowerBatteryEmpty").isVisible())
        for key in keys:
            self.assertFalse(self.item("homePowerProfile" + key).isEnabled())
            self.assertFalse(self.item("homePowerProfile" + key).property("checked"))
        self.assertEqual(evaluate("powerCommands.length").toInt(), 0)
        check_widths("empty")

    def test_audio_polish_states_bounds_and_keyboard(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("audioFixture", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            QTest.qWait(30)
            return result

        def check_widths(state):
            for width in (320, 375, 414, 768):
                with self.subTest(state=state, width=width):
                    self.studio.setProperty("customWidth", width)
                    QTest.qWait(50)
                    pending = [self.item("homePageLoader")]
                    while pending:
                        control = pending.pop()
                        pending.extend(control.childItems())
                        if not control.isVisible() or not (control.inherits("QQuickControl") or control.inherits("QQuickText")):
                            continue
                        ancestor = control.parentItem()
                        while ancestor:
                            if ancestor.clip():
                                start = control.mapToItem(ancestor, QPointF(0, 0))
                                end = control.mapToItem(ancestor, QPointF(control.width(), 0))
                                self.assertGreaterEqual(start.x(), -1, control.objectName())
                                self.assertLessEqual(end.x(), ancestor.width() + 1, control.objectName())
                            ancestor = ancestor.parentItem()
                    self.capture(f"audio-{state}-{width}")
                    if state == "live":
                        for name in ("homeAudioOutputSource", "homeAudioInputSource"):
                            dropdown = self.item(name, self.item("homePageLoader"))
                            initial_width = dropdown.width()
                            dropdown.forceActiveFocus()
                            QTest.keyClick(self.window, Qt.Key.Key_Space)
                            QTest.qWait(30)
                            self.engine.globalObject().setProperty("testDropdown", self.engine.newQObject(dropdown))
                            popup_content = self.engine.evaluate("testDropdown.popup.contentItem").toQObject()
                            popup_item = popup_content.parentItem()
                            start = popup_item.mapToItem(dropdown, QPointF(0, 0))
                            end = popup_item.mapToItem(dropdown, QPointF(popup_item.width(), 0))
                            self.assertAlmostEqual(start.x(), 0, delta=1)
                            self.assertLessEqual(end.x(), dropdown.width() + 1)
                            self.assertAlmostEqual(dropdown.width(), initial_width)
                            self.capture(f"audio-live-{name}-{width}-open")
                            QTest.keyClick(self.window, Qt.Key.Key_Escape)

        evaluate('''
            audioFixture.audioApps.setProperty(0, "appName", "Music workstation / a very long application session name");
            audioFixture.audioApps.setProperty(0, "streamName", "Playback from a long project and track label");
        ''')
        self.home_action("homeAudio")
        check_widths("preview")
        self.item("home_outputMute").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertTrue(self.fixtures.property("outputMuted"))
        self.item("home_volumeSlider").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(self.fixtures.property("volume"), 65)
        evaluate("audioFixture.audioApps.clear()")
        self.assertTrue(self.item("home_audioEmptyState").isVisible())
        check_widths("preview-empty")

        evaluate('''
            var audioData = audioFixture.desktopData;
            audioData.live = true;
            audioData.status = "Test records / read-only";
            var audioDevices = audioData.devices;
            audioDevices.audio = {default_sink_name:"speakers",default_source_name:"mic"};
            audioDevices.sinks = [
                {index:1,name:"speakers",description:"USB studio interface / a very long output device label",mute:false,volume:{left:{value:32768}}},
                {index:4,name:"headphones",description:"Headphones",mute:false,volume:{left:{value:32768}}}
            ];
            audioDevices.sources = [
                {index:2,name:"mic",description:"Microphone / a very long input device label",mute:false,volume:{mono:{value:32768}}},
                {index:5,name:"headset",description:"Headset microphone",mute:false,volume:{mono:{value:32768}}},
                {index:6,name:"monitor",description:"Output monitor",monitor_of_sink_name:"speakers"}
            ];
            audioDevices.streams = [{index:3,sink:1,mute:true,properties:{"application.name":"MusicWorkstationWithAnUnbrokenLongApplicationName"},volume:{left:{value:32768}}}];
            audioData.devices = audioDevices;
            var audioCommands = [];
            audioData.commandRequested.connect(command => audioCommands.push(command));
        ''')
        controls = ("homeAudioOutputSource", "homeAudioInputSource", "homeAudioOutputVolume", "homeAudioInputVolume", "homeAudioOutputMute", "homeAudioInputMute", "homeAudioAppVolume3", "homeAudioAppMute3", "homeAudioAppRoute3")
        self.assertEqual(self.item("homeAudioInputSource").property("count"), 2)
        self.assertEqual(self.item("homeAudioAppLevel3").property("text"), "Muted")
        self.assertTrue(self.item("homeAudioAppMute3").property("checked"))
        for name in controls:
            self.assertFalse(self.item(name).isEnabled(), name)
        check_widths("live-readonly")
        evaluate('audioData.controlsEnabled = true; audioData.status = "Test records / commands captured";')
        check_widths("live")
        for name, expected in (
            ("homeAudioOutputVolume", ["pactl", "set-sink-volume", "speakers", "51%"]),
            ("homeAudioInputVolume", ["pactl", "set-source-volume", "mic", "51%"]),
            ("homeAudioAppVolume3", ["pactl", "set-sink-input-volume", "3", "51%"]),
        ):
            self.item(name).forceActiveFocus()
            QTest.keyClick(self.window, Qt.Key.Key_Right)
            self.assertEqual(evaluate("audioCommands.pop()").toVariant(), expected)
        for name, expected in (
            ("homeAudioOutputMute", ["pactl", "set-sink-mute", "speakers", "toggle"]),
            ("homeAudioInputMute", ["pactl", "set-source-mute", "mic", "toggle"]),
            ("homeAudioAppMute3", ["pactl", "set-sink-input-mute", "3", "toggle"]),
        ):
            self.item(name).forceActiveFocus()
            QTest.keyClick(self.window, Qt.Key.Key_Space)
            self.assertEqual(evaluate("audioCommands.pop()").toVariant(), expected)
        for name, expected in (
            ("homeAudioOutputSource", ["pactl", "set-default-sink", "headphones"]),
            ("homeAudioInputSource", ["pactl", "set-default-source", "headset"]),
            ("homeAudioAppRoute3", ["pactl", "move-sink-input", "3", "headphones"]),
        ):
            self.item(name).forceActiveFocus()
            QTest.keyClick(self.window, Qt.Key.Key_Space)
            QTest.keyClick(self.window, Qt.Key.Key_Down)
            QTest.keyClick(self.window, Qt.Key.Key_Return)
            self.assertEqual(evaluate("audioCommands.pop()").toVariant(), expected)
        evaluate('audioData.busy = true; audioData.status = "Updating audio"; audioCommands = [];')
        for name in controls:
            self.assertFalse(self.item(name).isEnabled(), name)
            self.item(name).forceActiveFocus()
            QTest.keyClick(self.window, Qt.Key.Key_Right)
            QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertEqual(evaluate("audioCommands.length").toInt(), 0)
        evaluate('audioData.busy = false; audioDevices.sinks[0].volume = {}; audioData.devices = audioDevices;')
        self.assertEqual(self.item("homeAudioOutputLevel").property("text"), "--")
        self.assertFalse(self.item("homeAudioOutputVolume").isEnabled())
        evaluate('audioDevices.audio.default_sink_name = "missing"; audioData.devices = audioDevices;')
        self.assertEqual(self.item("homeAudioOutputSource").property("displayText"), "Default unavailable")
        self.assertFalse(self.item("homeAudioOutputMute").isEnabled())
        evaluate('audioDevices.sinks = []; audioDevices.sources = []; audioDevices.streams = []; audioData.devices = audioDevices; audioData.status = "Audio service unavailable";')
        self.assertTrue(self.item("homeAudioEmptyState").isVisible())
        self.assertEqual(self.item("homeAudioOutputSource").property("displayText"), "No devices")
        for name in controls[:6]:
            self.assertFalse(self.item(name).isEnabled(), name)
        check_widths("unavailable")

    def test_audio_default_preview_devices(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("audioFixture", self.engine.newQObject(self.fixtures))
        result = self.engine.evaluate('''
            var fixtureAudioCommands = [];
            audioFixture.desktopData.commandRequested.connect(command => fixtureAudioCommands.push(command));
        ''')
        self.assertFalse(result.isError(), result.toString())
        self.home_action("homeAudio")
        self.capture("audio-default-devices")
        self.assertEqual(self.item("home_outputSource").property("count"), 3)
        self.assertEqual(self.item("home_inputSource").property("count"), 2)
        self.assertIn("no host changes", self.item("home_audioMode").property("text"))
        for name, state, expected in (("outputSource", "outputDevice", "Speakers"),
                                      ("inputSource", "inputDevice", "Headset microphone")):
            self.item("home_" + name).forceActiveFocus()
            QTest.keyClick(self.window, Qt.Key.Key_Space)
            QTest.keyClick(self.window, Qt.Key.Key_Down)
            QTest.keyClick(self.window, Qt.Key.Key_Return)
            self.assertEqual(self.fixtures.property(state), expected)
            self.assertEqual(self.item(name).property("currentText"), expected)
        self.item("home_inputVolumeSlider").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(self.fixtures.property("inputVolume"), 61)
        self.assertEqual(self.item("inputVolumeSlider").property("value"), 61)
        self.click("home_inputMute")
        self.assertFalse(self.fixtures.property("microphoneEnabled"))
        self.assertTrue(self.item("inputMute").property("checked"))
        self.click("volumeButton")
        self.click("inputMute")
        self.item("volumeSlider").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.home_action("homeAudio")
        self.assertFalse(self.item("home_inputMute").property("checked"))
        self.assertEqual(self.item("home_volumeSlider").property("value"), 65)
        self.assertEqual(self.item("volumeButton").property("text"), "65%")
        self.home_action("homeTab")
        self.assertIsNone(self.window.findChild(QObject, "controlVolume"))
        self.home_action("homeAudio")
        for width in (320, 375, 414, 768):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            for prefix, surface in (("home_", "homePageLoader"), ("", "volumePanelSurface")):
                if not prefix:
                    self.click("volumeButton")
                container = self.item(surface)
                for name in ("outputSource", "inputSource", "volumeSlider", "inputVolumeSlider", "outputMute", "inputMute", "audioAppList"):
                    control = self.item(prefix + name)
                    self.assertTrue(control.isVisible(), prefix + name)
                    self.assertGreater(control.height(), 0)
                    position = control.mapToItem(container, QPointF(0, 0))
                    self.assertGreaterEqual(position.x(), -1, prefix + name)
                    self.assertGreaterEqual(position.y(), -1, prefix + name)
                    self.assertLessEqual(position.x() + control.width(), container.width() + 1, prefix + name)
                    self.assertLessEqual(position.y() + control.height(), container.height() + 1, prefix + name)
                self.capture(f"audio-default-{'home' if prefix else 'bar'}-{width}")
            self.home_action("homeAudio")
        self.click("resetButton")
        self.assertEqual(self.fixtures.property("outputDevice"), "Default")
        self.assertEqual(self.fixtures.property("inputDevice"), "Default")
        self.assertEqual(self.fixtures.property("inputVolume"), 60)
        self.assertEqual(self.fixtures.property("volume"), 64)
        self.assertTrue(self.fixtures.property("microphoneEnabled"))
        self.assertEqual(self.engine.evaluate("fixtureAudioCommands.length").toInt(), 0)

    def test_native_monitor_arrangement_commands(self):
        result = self.engine.evaluate((ROOT / "shell/Services/DisplaySettings.js").read_text())
        self.assertFalse(result.isError(), result.toString())
        result = self.engine.evaluate('''
            var arrangementMonitors = [{name:"DP-1",width:1920,height:1080,refreshRate:144,scale:1,transform:0,x:0,y:0}];
            arrangementCommand(arrangementMonitors,[{name:"DP-1",x:-1920,y:100}],true);
        ''')
        self.assertEqual(result.toVariant(), ["hyprctl", "repl", 'hl.monitor({output="DP-1",mode="1920x1080@144",position="-1920x100",scale=1,transform=0})'])
        self.assertEqual(self.engine.evaluate('arrangementCommand(arrangementMonitors,[{name:"DP-1",x:0,y:0}],false)').toVariant(),
                         ["hyprctl", "--batch", "keyword monitor DP-1,1920x1080@144,0x0,1,transform,0"])
        for positions in ('[]', '[{name:"unknown",x:0,y:0}]', '[{name:"DP-1",x:0.5,y:0}]',
                          '[{name:"DP-1",x:32769,y:0}]', '[{name:"DP-1",x:0,y:0},{name:"DP-1",x:1,y:0}]'):
            self.assertEqual(self.engine.evaluate(f'arrangementCommand(arrangementMonitors,{positions},true)').toVariant(), [])

    def test_native_display_setting_commands(self):
        import json

        result = self.engine.evaluate((ROOT / "shell/Services/DisplaySettings.js").read_text())
        self.assertFalse(result.isError(), result.toString())
        for width, height, modes, expected in (
            (5120, 1440, ["3840x1080@119.97Hz", "5120x1440@59.98Hz", "5120x1440@239.76Hz", "5120x1440@120.00Hz"], "5120x1440@239.76Hz"),
            (1920, 1080, ["1920x1080@60.00Hz", "1920x1080@143.99Hz", "1920x1080@119.98Hz"], "1920x1080@143.99Hz"),
        ):
            result = self.engine.evaluate(f'sortedModes({{width:{width},height:{height},availableModes:{json.dumps(modes)}}})').toVariant()
            self.assertEqual(result[0], expected)
            self.assertCountEqual(result, modes)
        result = self.engine.evaluate('var displayMonitor = {name:"DP-2",x:-1920,y:0}; command(displayMonitor,"1920x1080@144.00Hz",1.25,1,true)')
        self.assertEqual(result.toVariant(), ["hyprctl", "repl", 'hl.monitor({output="DP-2",mode="1920x1080@144.00",position="-1920x0",scale=1.25,transform=1})'])
        self.assertEqual(self.engine.evaluate('command(displayMonitor,"1920x1080@144",1,0,false)').toVariant(),
                         ["hyprctl", "keyword", "monitor", "DP-2,1920x1080@144,-1920x0,1,transform,0"])
        for expression in ('command(displayMonitor,"bad mode",1,0,true)',
                           'command(displayMonitor,"1920x1080@144",NaN,0,true)',
                           'command(displayMonitor,"1920x1080@144",4,0,true)',
                           'command(displayMonitor,"1920x1080@144",1,1.5,true)',
                           'command({name:"bad\\\" lua",x:0,y:0},"1920x1080@144",1,0,true)'):
            self.assertEqual(self.engine.evaluate(expression).toVariant(), [])

    def test_overview_keyboard_window_actions(self):
        result = self.engine.evaluate((ROOT / "third_party/quickshell-overview/modules/overview/OverviewKeyboard.js").read_text())
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(self.engine.evaluate('selection([{address:"0xa"},{address:"0xb"}],"0xb","0xa")').toString(), "0xb")
        self.assertEqual(self.engine.evaluate('selection([{address:"0xa"},{address:"0xb"}],"0xc","0xb")').toString(), "0xb")
        self.assertEqual(self.engine.evaluate('selection([{address:"0xa"}],"0xb","0xc")').toString(), "0xa")
        self.assertEqual(self.engine.evaluate('selection([],"0xb","0xc")').toString(), "")
        self.assertEqual(self.engine.evaluate('selection([{},null],"",undefined)').toString(), "")
        self.assertEqual(self.engine.evaluate('selection([{}, {address:"0xa"}],"",undefined)').toString(), "0xa")
        self.assertEqual(self.engine.evaluate('cycle([{},null,{address:"0xa"}],"",false)').toString(), "0xa")
        self.assertEqual(self.engine.evaluate('cycle([{address:"0xa"},{address:"0xb"}],"0xa",false)').toString(), "0xb")
        self.assertEqual(self.engine.evaluate('cycle([{address:"0xa"},{address:"0xb"}],"0xa",true)').toString(), "0xb")
        self.assertEqual(self.engine.evaluate('cycle([],"",false)').toString(), "")
        self.assertEqual(self.engine.evaluate('command("move",{address:"0xabc"},3,true)').toVariant(),
                         ["hyprctl", "repl", 'hl.dispatch(hl.dsp.window.move({workspace="3",follow=true,window="address:0xabc"}));hl.dispatch(hl.dsp.focus({window="address:0xabc"}))'])
        self.assertEqual(self.engine.evaluate('command("move",{address:"0xabc"},"special:scratch",false)').toVariant(),
                         ["hyprctl", "--batch", "dispatch movetoworkspace special:scratch,address:0xabc;dispatch focuswindow address:0xabc"])
        self.assertEqual(self.engine.evaluate('command("swap",{address:"0xabc"},"left",true)').toVariant(),
                         ["hyprctl", "repl", 'hl.dispatch(hl.dsp.window.swap({direction="left",window="address:0xabc"}))'])
        for expression in ('command("swap",{address:"0xabc",floating:true},"left",true)',
                           'command("move",{address:"bad"},2,true)', 'command("move",{address:"0xabc"},-1,true)',
                           'command("swap",{address:"0xabc"},"bad lua",true)'):
            self.assertEqual(self.engine.evaluate(expression).toVariant(), [])

    def test_overview_keyboard_monitor_ownership(self):
        import json

        source = (ROOT / "third_party/quickshell-overview/modules/overview/Overview.qml").read_text()
        handler = source.split("Keys.onPressed: event => {", 1)[1].split("\n            ColumnLayout {", 1)[0]
        handler = handler.rsplit("\n                }", 1)[0]
        navigation = source.split("function navigateWorkspace(target) {", 1)[1].split("\n            }", 1)[0]
        activation = source.split("function activateWorkspace(target) {", 1)[1].split("\n            }", 1)[0]
        movement = source.split("function moveWindow(window, destination) {", 1)[1].split("\n            }", 1)[0]
        constants = {name: int(getattr(Qt.Key, name)) for name in (
            "Key_Tab", "Key_Backtab", "Key_Left", "Key_Right", "Key_Up", "Key_Down",
            "Key_H", "Key_J", "Key_K", "Key_L", "Key_Return", "Key_Enter", "Key_Escape",
            "Key_0", "Key_1", "Key_9")}
        constants.update(ShiftModifier=Qt.ShiftModifier.value, ControlModifier=Qt.ControlModifier.value)
        result = self.engine.evaluate('''
            var Qt = %s;
            var dispatched = [];
            var root = {monitorIsFocused:false,monitor:{id:1,activeWorkspace:{id:12}},keyboardWorkspaceId:12,
                syncKeyboardSelection:function() {}};
            var Hyprland = {usingLua:true,focusedMonitor:{id:0,activeWorkspace:{id:1}},
                dispatch:function(command) {dispatched.push(command);}};
            var Config = {options:{overview:{rows:2,columns:3,useWorkspaceMap:true,
                workspaceMap:[0,10],orderRightLeft:false,orderBottomUp:false}}};
            var GlobalStates = {overviewSelectedAddress:"0xa"};
            var handleOverviewKey = function(event) {%s};
            root.navigateWorkspace = function(target) {%s};
            root.activateWorkspace = function(target) {%s};
            root.moveWindow = function(window, destination) {%s};
        ''' % (json.dumps(constants), handler, navigation, activation, movement))
        self.assertFalse(result.isError(), result.toString())
        self.engine.evaluate('handleOverviewKey({key:Qt.Key_Right,modifiers:0})')
        self.assertEqual(self.engine.evaluate('dispatched').toVariant(), [])
        self.engine.evaluate('root.monitorIsFocused=true; handleOverviewKey({key:Qt.Key_Right,modifiers:0})')
        self.assertEqual(self.engine.evaluate('dispatched').toVariant(), [])
        self.assertEqual(self.engine.evaluate('GlobalStates.overviewSelectedAddress').toString(), "")
        self.assertEqual(self.engine.evaluate('root.keyboardWorkspaceId').toInt(), 13)
        self.engine.evaluate('handleOverviewKey({key:Qt.Key_Right,modifiers:0})')
        self.assertEqual(self.engine.evaluate('root.keyboardWorkspaceId').toInt(), 11)
        self.assertEqual(self.engine.evaluate('dispatched').toVariant(), [])
        self.engine.evaluate('root.keyboardChanging=true')
        for key, modifiers in (("Key_Return", 0), ("Key_Tab", 0), ("Key_Right", Qt.ShiftModifier.value),
                               ("Key_Left", Qt.ControlModifier.value)):
            result = self.engine.evaluate(f'var event = {{key:Qt.{key},modifiers:{modifiers},accepted:false}}; handleOverviewKey(event); event.accepted')
            self.assertFalse(result.isError(), result.toString())
            self.assertTrue(result.toBool())
        self.assertEqual(self.engine.evaluate('dispatched').toVariant(), [])
        self.engine.evaluate('root.keyboardChanging=false; handleOverviewKey({key:Qt.Key_Return,modifiers:0})')
        self.assertEqual(self.engine.evaluate('dispatched').toVariant(), ["hl.dsp.focus({workspace = '11'})"])
        self.engine.evaluate((ROOT / "third_party/quickshell-overview/modules/overview/OverviewKeyboard.js").read_text())
        result = self.engine.evaluate('''
            var Keyboard = {command:command};
            var moves = [];
            root.selectedWindow = {address:"0xabc",workspace:{id:11}};
            root.runWindowCommand = function(command, destination) {moves.push({command:command,destination:destination});};
            handleOverviewKey({key:Qt.Key_Right,modifiers:Qt.ShiftModifier});
            moves;
        ''')
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(result.toVariant(), [{"command":["hyprctl", "repl", 'hl.dispatch(hl.dsp.window.move({workspace="12",follow=true,window="address:0xabc"}));hl.dispatch(hl.dsp.focus({window="address:0xabc"}))'], "destination":12}])
        self.assertEqual(self.engine.evaluate('dispatched').toVariant(), ["hl.dsp.focus({workspace = '11'})"])
        result = self.engine.evaluate('''
            root.selectedWindow = {address:"0xabc",class:"kitty",workspace:{id:14}};
            handleOverviewKey({key:Qt.Key_Right,modifiers:Qt.ShiftModifier});
            moves[moves.length-1];
        ''')
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(result.toVariant()["destination"], 15)
        self.assertIn('window="address:0xabc"', result.toVariant()["command"][2])
        result = self.engine.evaluate('handleOverviewKey({key:Qt.Key_Left,modifiers:Qt.ControlModifier}); moves[moves.length-1].command')
        self.assertFalse(result.isError(), result.toString())
        self.assertIn('window="address:0xabc"', result.toVariant()[2])
        result = self.engine.evaluate('handleOverviewKey({key:Qt.Key_Return,modifiers:0}); dispatched[dispatched.length-1]')
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(result.toString(), "hl.dsp.focus({window = 'address:0xabc'})")
        self.assertIn('keyboardWindows: HyprlandData.windowList.filter', source)
        self.assertIn('selectedWindow: HyprlandData.windowByAddress[', source)
        self.engine.evaluate('GlobalStates.overviewOpen=true; handleOverviewKey({key:Qt.Key_Escape,modifiers:0})')
        self.assertFalse(self.engine.evaluate('GlobalStates.overviewOpen').toBool())

    def test_overview_move_keeps_manager_and_selection(self):
        source = (ROOT / "third_party/quickshell-overview/modules/overview/Overview.qml").read_text()
        completed = source.split("onExited: (exitCode, exitStatus) => {", 1)[1].split("\n            Timer {", 1)[0]
        completed = completed.rsplit("\n                }", 1)[0]
        sync = source.split("function syncKeyboardSelection() {", 1)[1].split("\n            }", 1)[0]
        result = self.engine.evaluate('''
            var root = {keyboardWorkspaceId:1,monitorIsFocused:true,keyboardChanging:true,selectedWindow:{address:"0xabc"}};
            var GlobalStates = {overviewOpen:true,overviewSelectedAddress:"0xold"};
            var destination = 4;
            var selectedAddress = "0xabc";
            var keyboardOutput = {text:""};
            var keyboardErrors = {text:""};
            var regrabbed = false;
            var keyboardRegrab = {restart:function() {regrabbed=true;}};
            var finishMove = function(exitCode, exitStatus) {%s};
            var syncSelection = function() {%s};
            finishMove(0,0);
            syncSelection();
        ''' % (completed, sync))
        self.assertFalse(result.isError(), result.toString())
        self.assertTrue(self.engine.evaluate('GlobalStates.overviewOpen').toBool())
        self.assertTrue(self.engine.evaluate('regrabbed').toBool())
        self.assertEqual(self.engine.evaluate('root.keyboardWorkspaceId').toInt(), 4)
        self.assertEqual(self.engine.evaluate('GlobalStates.overviewSelectedAddress').toString(), "0xabc")
        result = self.engine.evaluate('root.keyboardChanging=false; syncSelection(); destination="special:scratch"; finishMove(0,0)')
        self.assertFalse(result.isError(), result.toString())
        self.assertTrue(self.engine.evaluate('GlobalStates.overviewOpen').toBool())
        self.assertEqual(self.engine.evaluate('GlobalStates.overviewSelectedAddress').toString(), "0xabc")

    def test_overview_drag_requires_real_movement(self):
        import json

        source = (ROOT / "third_party/quickshell-overview/modules/overview/OverviewWidget.qml").read_text()
        area = source.split("id: dragArea", 1)[1].split("StyledToolTip {", 1)[0]
        released = area.split("onReleased: {", 1)[1].split("\n                        onCanceled:", 1)[0]
        released = released.rsplit("}", 1)[0]
        clicked = area.split("onClicked: (event) => {", 1)[1].rsplit("}", 1)[0]
        result = self.engine.evaluate('''
            var dispatched = [];
            var dragged = false;
            var root = {draggingTargetWorkspace:2,draggingTargetSpecialWorkspace:"",draggingFromWorkspace:1};
            var panelWindow = {moveWindow:function(window, destination) {dispatched.push({address:window.address,destination:destination});}};
            var windowData = {address:"0xabc",workspace:{id:1}};
            var window = {windowData:windowData,Drag:{active:true},dragInProgress:true,pressed:true,initX:10,initY:20};
            var updateWindowPosition = {restart:function() {}};
            var Hyprland = {usingLua:true,dispatch:function(command) {dispatched.push(command);}};
            var GlobalStates = {overviewOpen:true};
            var Qt = {LeftButton:%s};
            var releaseDrag = function() {%s};
            var clickWindow = function(event) {%s};
        ''' % (json.dumps(Qt.LeftButton.value), released, clicked))
        self.assertFalse(result.isError(), result.toString())
        result = self.engine.evaluate('releaseDrag(); dispatched')
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(result.toVariant(), [])
        self.assertFalse(self.engine.evaluate('window.dragInProgress').toBool())
        result = self.engine.evaluate('dragged=true; root.draggingTargetWorkspace=2; releaseDrag(); clickWindow({button:Qt.LeftButton}); dispatched')
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(result.toVariant(), [{"address":"0xabc","destination":2}])
        self.assertTrue(self.engine.evaluate('GlobalStates.overviewOpen').toBool())

    def test_native_minimize_restore_commands(self):
        result = self.engine.evaluate((ROOT / "host/Services/WindowActions.js").read_text())
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(self.engine.evaluate('command("minimize",{address:"0xabc123",workspace:3})').toString(),
                         'hl.dispatch(hl.dsp.window.move({workspace="special:quickshell-minimized-3",follow=false,window="address:0xabc123"}))')
        self.assertEqual(self.engine.evaluate('command("restore",{address:"0xabc123",workspaceName:"special:quickshell-minimized-3"})').toString(),
                         'hl.dispatch(hl.dsp.window.move({workspace="3",follow=true,window="address:0xabc123"}))')
        for expression in ('command("minimize",{address:"bad",workspace:1})',
                           'command("minimize",{address:"0xabc",workspace:-99})',
                           'command("minimize",{address:"0xabc",workspace:1,pinned:true})',
                           'command("restore",{address:"0xabc",workspaceName:"special:scratchpad"})',
                           'command("restore",{address:"0xabc",workspaceName:"special:quickshell-minimized-0"})',
                           'command("unknown",{address:"0xabc",workspace:1})'):
            self.assertEqual(self.engine.evaluate(expression).toString(), "")

    def test_native_desktop_setting_commands(self):
        result = self.engine.evaluate((ROOT / "host/Services/DesktopSettings.js").read_text())
        self.assertFalse(result.isError(), result.toString())
        for key, value, expected in (
            ("tileGap", 12, "hl.config({general={gaps_in=12}})"),
            ("outerGap", 24, "hl.config({general={gaps_out=24}})"),
            ("windowBorderWidth", 3, "hl.config({general={border_size=3}})"),
            ("windowRadius", 0, "hl.config({decoration={rounding=0}})"),
            ("windowRadius", 24, "hl.config({decoration={rounding=24}})"),
            ("windowOpacity", 40, "hl.config({decoration={active_opacity=0.4,inactive_opacity=0.4}})"),
            ("windowOpacity", 92, "hl.config({decoration={active_opacity=0.92,inactive_opacity=0.92}})"),
            ("windowOpacity", 100, "hl.config({decoration={active_opacity=1,inactive_opacity=1}})"),
            ("mainPaneRatio", 56, "hl.config({master={mfact=0.56}})"),
            ("tilingLayout", '"Split"', 'hl.config({general={layout="dwindle"}})'),
            ("tilingLayout", '"Columns"', 'hl.config({general={layout="master"},master={orientation="left"}})'),
            ("tilingLayout", '"Centered"', 'hl.config({general={layout="master"},master={orientation="center"}})'),
        ):
            self.assertEqual(self.engine.evaluate(f'command("{key}", {value})').toString(), expected)
        for expression in ('command("tileGap", -1)', 'command("outerGap", 65)',
                           'command("windowBorderWidth", 9)', 'command("mainPaneRatio", 29)',
                           'command("tileGap", 1.5)', 'command("unknown", 1)',
                           'command("windowRadius", -1)', 'command("windowRadius", 25)',
                           'command("windowRadius", 1.5)', 'command("windowOpacity", 39)',
                           'command("windowOpacity", 101)', 'command("windowOpacity", 90.5)',
                           'command("windowOpacity", NaN)', 'command("windowOpacity", "92")',
                           'command("tilingLayout", "Auto")', 'command("tilingLayout", "bad lua")'):
            self.assertEqual(self.engine.evaluate(expression).toString(), "")

    def test_focus_border_tracks_theme_accent(self):
        source = (ROOT / "host/Services/ProductionDesktopData.qml").read_text()
        sync = source.split("function syncDesktopSettings() {", 1)[1].split("\n    }", 1)[0]
        self.engine.evaluate((ROOT / "host/Services/DesktopSettings.js").read_text())
        result = self.engine.evaluate('''
            var DesktopSettings = {command:command};
            var Ui = {Theme:{palette:{accent:"#65e5bf"}}};
            var profileSettings = {ready:true,applying:false,glassEnabled:true,tilingKeys:[],snapshot:function() {return {windowOpacity:92,windowRadius:8};}};
            var desktopControlsEnabled = true;
            var desktopSettingsObserved = null;
            var desktopSettingsQueue = {};
            var desktopSettingsTimer = {restart:function() {}};
            var syncBorder = function() {%s};
            syncBorder();
        ''' % sync)
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(self.engine.evaluate('desktopSettingsQueue.focusBorderColor').toString(), 'hl.config({general={col={active_border="rgba(65e5bfff)"}}})')
        self.engine.evaluate('desktopSettingsQueue={}; Ui.Theme.palette.accent="#ABCDEF"; syncBorder()')
        self.assertEqual(self.engine.evaluate('Object.keys(desktopSettingsQueue)').toVariant(), ["focusBorderColor"])
        self.assertEqual(self.engine.evaluate('desktopSettingsQueue.focusBorderColor').toString(), 'hl.config({general={col={active_border="rgba(ABCDEFff)"}}})')
        self.engine.evaluate('desktopSettingsQueue={}; syncBorder()')
        self.assertEqual(self.engine.evaluate('Object.keys(desktopSettingsQueue)').toVariant(), [])
        for value in ('"red"', '"#abcd"', '"#12345678"', '"#ffffff);bad"', 'null', '12'):
            self.assertEqual(self.engine.evaluate('command("focusBorderColor",' + value + ')').toString(), "")
        self.assertIn('function onPaletteChanged() { terminalPaletteTimer.restart(); root.syncDesktopSettings(); }', source)
        reload_sync = source.split("function syncFocusBorder() {", 1)[1].split("\n    }", 1)[0]
        result = self.engine.evaluate('var resyncBorder = function() {' + reload_sync + '}; resyncBorder()')
        self.assertFalse(result.isError(), result.toString())
        self.assertEqual(self.engine.evaluate('Object.keys(desktopSettingsQueue)').toVariant(), ["focusBorderColor"])
        self.engine.evaluate('desktopSettingsQueue={}; desktopControlsEnabled=false; resyncBorder()')
        self.assertEqual(self.engine.evaluate('Object.keys(desktopSettingsQueue)').toVariant(), [])
        self.assertIn('if (event.name === "configreloaded") root.syncFocusBorder();', source)

    def test_panel_slide_and_volume_animation_modes(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        drawer = self.item("volumeDrawer")
        control = self.item("barVolumeControl")
        desktop = self.item("desktop")
        drawer.setProperty("slide", True)
        profiles.setProperty("animationDuration", 600)
        for style in ("Smooth", "Stepped"):
            profiles.setProperty("animationStyle", style)
            control.setProperty("hoverExpanded", True)
            desktop.setProperty("openPanel", "volume")
            QTest.qWait(160)
            for animated, rendered_name in ((drawer, "steppedProgress"), (control, "revealProgress")):
                progress = animated.property("progress")
                rendered = animated.property(rendered_name)
                self.assertGreater(progress, 0)
                self.assertLess(progress, 1)
                if style == "Stepped":
                    self.assertAlmostEqual(rendered * 6, round(rendered * 6))
                    self.assertLessEqual(rendered, progress)
                else:
                    self.assertAlmostEqual(rendered, progress)
            surface = self.item("volumeDrawerSurface")
            self.assertAlmostEqual(surface.x(), drawer.width() * (1 - drawer.property("steppedProgress")))
            self.assertGreater(surface.x(), 0)
            self.capture("panel-slide-" + style.lower())
            QTest.qWait(500)
            self.assertEqual(surface.x(), 0)
            desktop.setProperty("openPanel", "")
            desktop.forceActiveFocus()
            control.setProperty("hoverExpanded", False)
            QTest.qWait(160)
            self.assertTrue(drawer.isVisible())
            self.assertGreater(surface.x(), 0)
            QTest.qWait(500)
            self.assertFalse(drawer.isVisible())
            self.assertEqual(control.property("progress"), 0)
        for instant_mode in ("Off", "Reduced"):
            profiles.setProperty("animationStyle", "Off" if instant_mode == "Off" else "Smooth")
            self.fixtures.setProperty("reducedMotion", instant_mode == "Reduced")
            desktop.setProperty("openPanel", "volume")
            self.assertEqual(drawer.property("progress"), 1)
            desktop.setProperty("openPanel", "")
            self.assertEqual(drawer.property("progress"), 0)

    def test_compact_hint_follows_theme(self):
        component = QQmlComponent(self.engine)
        component.setData(b'''import QtQuick
import "../shell/Components" as Ui
Item {
    property var palette: Ui.Theme.palette
    function setPalette(value) { Ui.Theme.palette = value; }
    Ui.Hint { objectName: "testHint"; visible: false; text: "A very long component hint ".repeat(30) }
}''', QUrl.fromLocalFile(str(ROOT / "tests" / "hint-test.qml")))
        self.assertFalse(component.isError(), [error.toString() for error in component.errors()])
        holder = component.create()
        self.assertIsNotNone(holder)
        hint = holder.findChild(QObject, "testHint")
        original = holder.property("palette")
        try:
            self.app.processEvents()
            self.assertLessEqual(hint.property("implicitWidth"), 240)
            self.assertLessEqual(hint.property("implicitHeight"), 44)
            self.assertEqual(hint.property("delay"), 650)
            self.assertEqual(hint.property("timeout"), 4000)
            for ink, paper in (("#fafafa", "#202020"), ("#202020", "#fafafa")):
                holder.setPalette({"ink": ink, "paper": paper, "line": "#777777", "muted": "#888888", "hover": "#444444", "stage": "#333333", "accent": paper})
                self.assertEqual(hint.property("background").property("color"), QColor(ink))
                self.assertEqual(hint.property("contentItem").property("color"), QColor(paper))
        finally:
            holder.setPalette(original)
            holder.deleteLater()

    def test_bar_hover_volume_and_no_hints(self):
        self.fixtures.setProperty("reducedMotion", True)
        for width in (320, 640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.mouseMove(self.window, QPointF(0, 0).toPoint())
            self.item("desktop").forceActiveFocus()
            QTest.qWait(50)
            button = self.item("volumeButton")
            control = self.item("barVolumeControl")
            slider = self.item("barVolumeSlider")
            self.assertFalse(control.property("expanded"))
            original_center = button.mapToScene(QPointF(button.width() / 2, button.height() / 2))
            QTest.mouseMove(self.window, original_center.toPoint())
            QTest.qWait(150)
            self.assertTrue(control.property("expanded"))
            self.assertTrue(slider.isVisible())
            self.assertGreater(slider.width(), 0)
            value_label = self.item("barVolumeValue")
            self.assertGreaterEqual(slider.x(), button.x() + button.width())
            self.assertGreaterEqual(value_label.x(), slider.x() + slider.width())
            QTest.mouseMove(self.window, slider.mapToScene(QPointF(slider.width() / 2, slider.height() / 2)).toPoint())
            QTest.qWait(30)
            self.assertTrue(control.property("expanded"))
            before = self.fixtures.property("volume")
            slider.forceActiveFocus(Qt.FocusReason.TabFocusReason)
            QTest.keyClick(self.window, Qt.Key.Key_Right)
            self.assertEqual(self.fixtures.property("volume"), before + 1)
            self.item("desktop").forceActiveFocus()
            QTest.mouseMove(self.window, QPointF(0, 0).toPoint())
            QTest.qWait(30)
            self.assertFalse(control.property("expanded"))
            self.assertLessEqual(self.item("barCenter").width(), 374)
        button = self.item("volumeButton")
        QTest.mouseMove(self.window, button.mapToScene(QPointF(button.width() / 2, button.height() / 2)).toPoint())
        QTest.qWait(30)
        self.click("volumeButton")
        self.assertEqual(self.item("desktop").property("openPanel"), "volume")
        for folder in ("shell", "host", "preview"):
            for path in (ROOT / folder).rglob("*.qml"):
                if path == ROOT / "shell/Components/Hint.qml":
                    continue
                self.assertNotIn("ToolTip", path.read_text(), str(path))

    def test_bar_network_action(self):
        bar = self.item("barLeft").parentItem()
        bar.setProperty("showNetworkButton", True)
        self.engine.globalObject().setProperty("testNetworkBar", self.engine.newQObject(bar))
        self.engine.evaluate("var networkRequests = 0; testNetworkBar.networkRequested.connect(function() { networkRequests++; });")
        QTest.qWait(30)
        self.assertEqual(self.item("barNetwork").property("iconName"), "wifi")
        self.click("barNetwork")
        self.assertEqual(self.engine.evaluate("networkRequests").toInt(), 1)

    def test_production_home_disables_preview_only_controls(self):
        self.home_action("homeTab")
        self.item("homePanel").setProperty("production", True)
        QTest.qWait(30)
        for name in ("homeSettings", "homeProfile",
                     "wifiEnabledSwitch", "bluetoothEnabledSwitch", "caffeineEnabledSwitch",
                     "nightLightEnabledSwitch", "dndEnabledSwitch", "powerSaverEnabledSwitch"):
            with self.subTest(control=name):
                self.assertFalse(self.item(name).isEnabled())
        self.assertFalse(self.item("homeActivities").isVisible())
        self.engine.globalObject().setProperty("homeService", self.engine.newQObject(self.fixtures))
        self.engine.evaluate("homeService.desktopData.controlsEnabled = true;")
        QTest.qWait(30)
        for name in ("homeProfile", "wifiEnabledSwitch", "bluetoothEnabledSwitch", "caffeineEnabledSwitch",
                     "nightLightEnabledSwitch", "dndEnabledSwitch", "powerSaverEnabledSwitch"):
            self.assertTrue(self.item(name).isEnabled(), name)
        navigation = self.item("homeNavigation")
        self.assertFalse(navigation.inherits("QQuickScrollView"))
        for name in ("homeTab", "homeAudio", "homeDisplayTab", "homeNetworkTab", "homeSystemSummary",
                     "homePowerTab", "homeWeatherTab", "homeNotificationsTab"):
            button = self.item(name)
            self.assertGreaterEqual(button.mapToItem(navigation, QPointF(0, 0)).y(), 0)
            self.assertLessEqual(button.mapToItem(navigation, QPointF(0, button.height())).y(), navigation.height())
        self.item("homePanel").setProperty("production", False)
        QTest.qWait(30)
        self.assertTrue(self.item("homeSettings").isEnabled())
        self.assertTrue(self.item("homeActivities").isVisible())

    def test_audio_dropdown_long_labels_bounds(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.home_action("homeAudio")
        for width in (320, 375, 414, 768):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            for prefix, surface in (("home_", "homePageLoader"), ("", "volumePanelSurface")):
                if not prefix:
                    self.click("volumeButton")
                container = self.item(surface)
                for name in ("outputSource", "inputSource"):
                    with self.subTest(width=width, prefix=prefix, name=name):
                        dropdown = self.item(prefix + name, container)
                        initial_width = dropdown.width()
                        dropdown.setProperty("model", ["USB studio device / " * 16, "Short device"])
                        dropdown.setProperty("currentIndex", 0)
                        QTest.qWait(30)
                        self.assertAlmostEqual(dropdown.width(), initial_width)
                        label = dropdown.property("contentItem")
                        self.assertTrue(label.property("truncated"))
                        self.assertLessEqual(label.width(), dropdown.width())
                        position = dropdown.mapToItem(container, QPointF(0, 0))
                        self.assertGreaterEqual(position.x(), 0)
                        self.assertLessEqual(position.x() + dropdown.width(), container.width() + 1)
                        self.capture(f"audio-dropdown-{prefix}{name}-{width}-closed")
                        dropdown.forceActiveFocus()
                        QTest.keyClick(self.window, Qt.Key.Key_Space)
                        QTest.qWait(50)
                        self.engine.globalObject().setProperty("testDropdown", self.engine.newQObject(dropdown))
                        self.assertTrue(self.engine.evaluate("testDropdown.popup.visible").toBool())
                        popup_content = self.engine.evaluate("testDropdown.popup.contentItem").toQObject()
                        popup_item = popup_content.parentItem()
                        row = self.engine.evaluate("testDropdown.popup.contentItem.itemAtIndex(0)").toQObject()
                        self.assertLessEqual(row.width(), popup_content.width())
                        self.assertTrue(row.property("contentItem").property("truncated"))
                        self.capture(f"audio-dropdown-{prefix}{name}-{width}-open")
                        start = popup_item.mapToScene(QPointF(0, 0))
                        end = popup_item.mapToScene(QPointF(popup_item.width(), popup_item.height()))
                        control_start = dropdown.mapToScene(QPointF(0, 0))
                        control_end = dropdown.mapToScene(QPointF(dropdown.width(), 0))
                        self.assertAlmostEqual(start.x(), control_start.x(), delta=1)
                        self.assertLessEqual(end.x() - start.x(), control_end.x() - control_start.x() + 1)
                        self.assertGreaterEqual(start.x(), 0)
                        self.assertGreaterEqual(start.y(), 0)
                        self.assertLessEqual(end.x(), self.window.width())
                        self.assertLessEqual(end.y(), self.window.height())
                        self.assertAlmostEqual(dropdown.width(), initial_width)
                        QTest.keyClick(self.window, Qt.Key.Key_Escape)
            self.home_action("homeAudio")

    def test_home_embedded_settings_and_audio_sync(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        self.home_action("homeAudio")
        self.click("home_appMute_music")
        self.assertTrue(self.item("appMute_music").property("checked"))
        self.item("home_appVolume_music").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(self.item("appVolume_music").property("value"), 81)
        self.click("volumeButton")
        self.assertEqual(self.item("desktop").property("openPanel"), "volume")
        self.click("appMute_music")
        self.home_action("homeAudio")
        self.assertFalse(self.item("home_appMute_music").property("checked"))
        self.click("homeSettings")
        home = self.item("homePanel")
        profiles = self.window.findChild(QObject, "profileSettings")
        self.click("glassSwitch", home)
        self.assertFalse(profiles.property("glassEnabled"))
        self.click("glassSwitch", home)
        self.item("homeSettingsCategory").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(self.item("settingsSurface", home).property("section"), 1)
        self.click("paletteIce", home)
        self.assertEqual(profiles.property("currentProfile").toVariant()["palette"], "Ice")
        self.assertFalse(self.settings_window.isVisible())
        for width in (640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            for tab in ("homeAudio", "homeWallpaper", "homeSettings"):
                self.home_action(tab)
                loader = self.item("homePageLoader")
                self.assertTrue(loader.isVisible())
                self.assertGreater(loader.width(), 350)
                self.assertGreater(loader.height(), 300)
                self.assertLessEqual(loader.mapToItem(home, QPointF(loader.width(), 0)).x(), home.width())
                self.assertEqual(self.item("desktop").property("openPanel"), "controls")
                self.capture(tab + "-" + str(width))
        settings = self.item("settingsSurface", home)
        settings.setProperty("section", 4)
        QTest.qWait(30)
        self.item("settingsPageScroll", home).property("contentItem").setProperty("contentY", 160)
        self.click("bind_ai", home)
        self.assertEqual(self.item("shortcutSettings").property("recording"), "ai")
        self.click("homeTab")
        self.assertEqual(self.item("shortcutSettings").property("recording"), "")
        self.open_settings()
        self.assertTrue(self.item("glassSwitch").property("checked"))

    def test_fixture_actions_and_reset(self):
        self.fixtures.setProperty("dndEnabled", True)
        self.assertTrue(self.studio.property("fontsReady"))
        labels = []
        pending = [self.item("primarySize")]
        while pending:
            child = pending.pop()
            labels.append(child)
            pending.extend(child.childItems())
        selected_text = [child for child in labels if child.property("text") == "1920 x 1080" and child.property("color") is not None]
        self.assertTrue(selected_text)
        self.assertEqual(selected_text[0].property("color"), QColor("#1c1c1c"))
        self.window.findChild(QObject, "windowManager").setProperty("activeWorkspace", 4)
        self.assertEqual(self.fixtures.property("workspace"), 4)
        self.cycle_profile()
        self.assertEqual(self.fixtures.property("profile"), "Gaming")
        self.click("playbackButton")
        self.assertFalse(self.fixtures.property("playing"))
        self.click("wallpaperButton")
        QTest.qWait(280)
        self.click("wallpaperTile2")
        self.assertEqual(self.fixtures.property("wallpaper"), 2)
        self.capture("wallpaper-panel")
        self.click("resetButton")
        self.assertEqual(self.fixtures.property("workspace"), 1)
        self.assertEqual(self.fixtures.property("wallpaper"), 0)
        self.assertTrue(self.fixtures.property("playing"))

    def test_monitor_wallpaper_picker(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("displayWallpapers", self.engine.newQObject(self.fixtures))
        self.engine.evaluate('displayWallpapers.wallpaperMonitors = ["DP-2", "DP-3"]')
        original = self.fixtures.property("wallpaper")
        self.click("wallpaperButton")
        QTest.qWait(100)
        picker = self.item("wallpaperPanelSurface")
        self.engine.globalObject().setProperty("displayPicker", self.engine.newQObject(picker))
        self.click("wallpaperDisplay")
        QTest.keyClick(self.window, Qt.Key_Down)
        QTest.keyClick(self.window, Qt.Key_Return)
        QTest.qWait(30)
        self.assertEqual(picker.property("targetMonitor"), "DP-2")
        self.click("wallpaperTile1")
        self.assertEqual(self.fixtures.property("wallpaper"), original)
        self.assertEqual(self.engine.evaluate('displayWallpapers.profileSettings.currentProfile.wallpaperFiles["DP-2"]').toString(),
                         self.engine.evaluate('String(displayWallpapers.wallpapers[1].source)').toString())
        self.assertEqual(self.engine.evaluate('displayWallpapers.wallpaperIndexForMonitor("DP-3")').toInt(), original)
        self.assertEqual(picker.property("selected"), 1)
        self.click("wallpaperSourceWallpaper")
        self.assertEqual(self.engine.evaluate('displayWallpapers.profileSettings.currentProfile.paletteMonitor').toString(), "DP-2")
        sampler = self.window.findChild(QObject, "wallpaperPalette")
        self.assertEqual(sampler.property("source").toString(), self.engine.evaluate('String(displayWallpapers.wallpapers[1].source)').toString())
        self.click("resetMonitorWallpaper")
        self.assertEqual(picker.property("selected"), original)
        self.click("wallpaperTile2")
        self.engine.evaluate('displayPicker.targetMonitor = "DP-3"')
        QTest.qWait(30)
        self.click("wallpaperTile1")
        self.assertEqual(self.engine.evaluate('displayWallpapers.wallpaperIndexForMonitor("DP-2")').toInt(), 2)
        self.assertEqual(self.engine.evaluate('displayWallpapers.wallpaperIndexForMonitor("DP-3")').toInt(), 1)
        self.capture("wallpaper-per-monitor")
        self.engine.evaluate('displayPicker.targetMonitor = ""')
        QTest.qWait(30)
        self.click("wallpaperTile0")
        self.assertEqual(self.engine.evaluate('displayWallpapers.profileSettings.currentProfile.wallpaperFiles').toVariant(), {})
        self.engine.evaluate('displayPicker.targetMonitor = "DP-3"; displayWallpapers.wallpaperMonitors = ["DP-2"]')
        QTest.qWait(30)
        self.assertEqual(picker.property("targetMonitor"), "")

    def test_monitor_wallpaper_palette_source(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        self.engine.globalObject().setProperty("paletteProfiles", self.engine.newQObject(profiles))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            return result

        evaluate('paletteProfiles.selectMonitorWallpaper("DP-2","file:///wide.png"); paletteProfiles.useWallpaperPalette("DP-2")')
        self.assertEqual(evaluate('paletteProfiles.paletteWallpaperSource("file:///default.png")').toString(), "file:///wide.png")
        evaluate('paletteProfiles.selectMonitorWallpaper("DP-3","file:///small.png"); paletteProfiles.save()')
        self.assertEqual(evaluate('paletteProfiles.paletteWallpaperSource("file:///default.png")').toString(), "file:///small.png")
        evaluate('paletteProfiles.selectMonitorWallpaper("DP-3","")')
        self.assertEqual(evaluate('paletteProfiles.paletteWallpaperSource("file:///default.png")').toString(), "file:///default.png")
        profiles.revert()
        self.assertEqual(evaluate('paletteProfiles.currentProfile.paletteMonitor').toString(), "DP-3")
        evaluate('paletteProfiles.useWallpaperPalette("")')
        self.assertEqual(evaluate('paletteProfiles.paletteWallpaperSource("file:///default.png")').toString(), "file:///default.png")

    def test_monitor_wallpaper_profiles(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        self.engine.globalObject().setProperty("monitorProfiles", self.engine.newQObject(profiles))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            return result

        evaluate('monitorProfiles.selectWallpaper(0,"file:///default.png"); monitorProfiles.selectMonitorWallpaper("DP-2","file:///wide.png")')
        self.assertEqual(evaluate('monitorProfiles.wallpaperForMonitor("DP-2","file:///default.png")').toString(), "file:///wide.png")
        self.assertEqual(evaluate('monitorProfiles.wallpaperForMonitor("DP-3","file:///default.png")').toString(), "file:///default.png")
        evaluate('monitorProfiles.selectMonitorWallpaper("DP-3","file:///other.png"); monitorProfiles.save()')
        evaluate('monitorProfiles.selectMonitorWallpaper("DP-2","")')
        self.assertEqual(evaluate('monitorProfiles.wallpaperForMonitor("DP-2","file:///default.png")').toString(), "file:///default.png")
        profiles.revert()
        self.assertEqual(evaluate('monitorProfiles.currentProfile.wallpaperFiles').toVariant(), {"DP-2":"file:///wide.png", "DP-3":"file:///other.png"})
        evaluate('monitorProfiles.selectMonitorWallpaper("DP-2","https://invalid/image.png"); monitorProfiles.selectMonitorWallpaper("__proto__","file:///bad.png")')
        self.assertEqual(evaluate('monitorProfiles.currentProfile.wallpaperFiles').toVariant(), {"DP-2":"file:///wide.png", "DP-3":"file:///other.png"})
        profiles.setProperty("activeName", "Gaming")
        self.assertEqual(evaluate('monitorProfiles.wallpaperForMonitor("DP-2","default")').toString(), "default")
        evaluate('monitorProfiles.copyFrom("Work",["appearance"])')
        self.assertEqual(evaluate('monitorProfiles.currentProfile.wallpaperFiles["DP-2"]').toString(), "file:///wide.png")
        evaluate('monitorProfiles.selectWallpaper(0,"file:///all.png")')
        self.assertEqual(evaluate('monitorProfiles.currentProfile.wallpaperFiles').toVariant(), {})
        profiles.setProperty("activeName", "Work")
        restored_engine = QQmlApplicationEngine()
        restored_engine.warnings.connect(lambda messages: self.warnings.extend(str(message) for message in messages))
        restored_engine.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        restored_window = restored_engine.rootObjects()[0]
        try:
            restored = restored_window.findChild(QObject, "profileSettings")
            self.assertEqual(restored.property("currentProfile").toVariant()["wallpaperFiles"], {"DP-2":"file:///wide.png", "DP-3":"file:///other.png"})
        finally:
            restored_window.close()
            restored_engine.deleteLater()

    def test_wallpaper_folders_and_palettes(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        profiles = self.window.findChild(QObject, "profileSettings")
        self.engine.globalObject().setProperty("wallpaperFixtures", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            QTest.qWait(100)
            return result

        def names():
            return evaluate("wallpaperFixtures.wallpapers.map(entry => entry.name).join('|')").toString()

        def await_names(expected):
            for attempt in range(30):
                if names() == expected:
                    return
                QTest.qWait(50)
            self.assertEqual(names(), expected)

        bundled = evaluate("wallpaperFixtures.bundledWallpapers.map(entry => entry.name).join('|')").toString()
        bundled_count = len(bundled.split("|"))
        self.assertEqual(bundled_count, 22)
        sources = evaluate("wallpaperFixtures.bundledWallpapers.map(entry => String(entry.source))").toVariant()
        for source in sources:
            self.assertFalse(QImage(QUrl(source).toLocalFile()).isNull(), source)
        self.click("wallpaperButton")
        grid = self.item("wallpaperGrid")
        self.engine.globalObject().setProperty("wallpaperTestGrid", self.engine.newQObject(grid))
        self.engine.globalObject().setProperty("wallpaperTestImage", self.engine.newQObject(self.item("desktopWallpaper")))
        for index in range(3, bundled_count):
            evaluate(f"wallpaperTestGrid.positionViewAtIndex({index}, 1)")
            QTest.qWait(100)
            self.click("wallpaperTile" + str(index))
            self.assertEqual(self.fixtures.property("wallpaper"), index)
            self.assertEqual(profiles.property("currentProfile").toVariant()["wallpaperFile"], sources[index])
            self.assertEqual(self.item("desktopWallpaper").property("source"), QUrl(sources[index]))
            self.assertTrue(evaluate("wallpaperTestImage.status === 1").toBool())
        profiles.save()
        restored_engine = QQmlApplicationEngine()
        restored_engine.warnings.connect(lambda messages: self.warnings.extend(str(message) for message in messages))
        restored_engine.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        restored_window = restored_engine.rootObjects()[0]
        try:
            QTest.qWait(150)
            self.assertEqual(restored_window.findChild(QObject, "fixtures").property("wallpaper"), bundled_count - 1)
        finally:
            restored_window.close()
            restored_engine.deleteLater()
        self.window.requestActivate()
        evaluate("wallpaperFixtures.setWallpaper(0)")
        self.item("desktop").setProperty("openPanel", "")
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first folder"
            second = Path(directory) / "second folder"
            first.mkdir()
            second.mkdir()
            image = QImage(160, 90, QImage.Format.Format_RGB32)
            image.fill(QColor("#a3d9e3"))
            for path in (first / "zeta.png", first / "alpha.JPG", second / "other.png", second / "second.png"):
                self.assertTrue(image.save(str(path)))
            (first / "ignored.txt").write_text("not an image")
            self.click("wallpaperButton")
            profiles.setWallpaperDirectory(QUrl.fromLocalFile(str(first)).toString())
            await_names(bundled + "|alpha.JPG|zeta.png")
            grid = self.item("wallpaperGrid")
            self.engine.globalObject().setProperty("wallpaperTestGrid", self.engine.newQObject(grid))
            evaluate(f"wallpaperTestGrid.positionViewAtIndex({bundled_count + 1}, 1)")
            self.click("wallpaperTile" + str(bundled_count + 1))
            self.assertEqual(self.fixtures.property("wallpaper"), bundled_count + 1)
            selected_url = QUrl.fromLocalFile(str(first / "zeta.png")).toString()
            self.assertEqual(profiles.property("currentProfile").toVariant()["wallpaperFile"], selected_url)
            self.assertTrue(image.save(str(first / "beta.png")))
            await_names(bundled + "|alpha.JPG|beta.png|zeta.png")
            self.assertEqual(self.fixtures.property("wallpaper"), bundled_count + 2)
            self.click("wallpaperPaletteRose")
            self.assertEqual(profiles.property("currentProfile").toVariant()["palette"], "Rose")
            self.click("wallpaperSourceWallpaper")
            self.assertEqual(profiles.property("currentProfile").toVariant()["source"], "Wallpaper")
            profiles.setProperty("activeName", "Gaming")
            self.assertEqual(self.fixtures.property("wallpaper"), 1)
            profiles.setProperty("activeName", "Work")
            self.assertEqual(self.fixtures.property("wallpaper"), bundled_count + 2)
            (first / "beta.png").unlink()
            await_names(bundled + "|alpha.JPG|zeta.png")
            profiles.setWallpaperDirectory(QUrl.fromLocalFile(str(second)).toString())
            await_names(bundled + "|other.png|second.png")
            self.assertEqual(self.fixtures.property("wallpaper"), 0)
            profiles.setWallpaperDirectory(QUrl.fromLocalFile(str(first)).toString())
            await_names(bundled + "|alpha.JPG|zeta.png")
            profiles.save()
            second_engine = QQmlApplicationEngine()
            second_engine.warnings.connect(lambda messages: self.warnings.extend(str(message) for message in messages))
            second_engine.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
            second_window = second_engine.rootObjects()[0]
            try:
                QTest.qWait(250)
                restored = second_window.findChild(QObject, "profileSettings")
                self.assertEqual(restored.property("wallpaperDirectory"), QUrl.fromLocalFile(str(first)).toString())
                self.assertEqual(restored.property("currentProfile").toVariant()["wallpaperFile"], selected_url)
                self.assertEqual(second_window.findChild(QObject, "fixtures").property("wallpaper"), bundled_count + 1)
            finally:
                second_window.close()
                second_engine.deleteLater()
            self.window.requestActivate()
            self.click("wallpaperPaletteChalk")
            self.capture("wallpaper-folder")
            self.click("clearWallpaperFolder")
            await_names(bundled)
            self.assertEqual(self.fixtures.property("wallpaper"), 0)
            self.assertFalse(self.item("clearWallpaperFolder").property("enabled"))
            profiles.setWallpaperDirectory(QUrl.fromLocalFile(str(first / "missing")).toString())
            await_names(bundled)
            self.assertEqual(self.item("wallpaperFolderStatus").property("text"), "No supported images found in folder")
            profiles.setWallpaperDirectory("")

    def test_launcher_tabs_actions_and_empty_states(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        desktop = self.item("desktop")
        desktop.setProperty("openPanel", "launcher")
        QTest.qWait(30)
        panel = self.item("launcherPanel")
        search = self.item("launcherSearch")
        results = self.item("launcherResults")
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("launcherTest", self.engine.newQObject(panel))
        self.engine.evaluate('var launcherCommand = ""; var launcherFile = ""; launcherTest.runRequested.connect(command => launcherCommand = command); launcherTest.fileRequested.connect(path => launcherFile = path);')

        self.click("launcherTab_Windows")
        self.assertTrue(search.hasActiveFocus())
        self.assertEqual(results.property("count"), 3)
        search.setProperty("text", "preview session")
        QTest.qWait(30)
        self.assertEqual(results.property("count"), 1)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(manager.property("focusedId"), 2)
        self.assertEqual(desktop.property("openPanel"), "")

        desktop.setProperty("openPanel", "launcher")
        QTest.qWait(30)
        self.assertEqual(panel.property("mode"), "Apps")
        QTest.keyClick(self.window, Qt.Key.Key_Tab, Qt.KeyboardModifier.ControlModifier)
        self.assertEqual(panel.property("mode"), "Run")
        self.assertEqual(results.property("count"), 0)
        self.assertEqual(self.item("launcherEmptyState").property("text"), "No command entered")
        search.setProperty("text", "   printf launcher-preview   ")
        QTest.qWait(30)
        self.assertEqual(results.property("count"), 1)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(self.engine.evaluate("launcherCommand").toString(), "printf launcher-preview")
        self.assertEqual(self.fixtures.property("lastLaunchedApp"), "")
        self.assertEqual(desktop.property("openPanel"), "")

        desktop.setProperty("openPanel", "launcher")
        QTest.qWait(30)
        self.click("launcherTab_Files")
        self.assertEqual(results.property("count"), 0)
        self.assertEqual(self.item("launcherEmptyState").property("text"), "File search unavailable")
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(desktop.property("openPanel"), "launcher")
        self.engine.evaluate('launcherTest.files = Array.from({length: 24}, (_, index) => ({name: "Document " + index, path: "/preview/document-" + index})); launcherTest.fileSearchAvailable = true;')
        QTest.qWait(30)
        self.assertEqual(results.property("count"), 24)
        self.engine.evaluate("launcherTest.moveSelection(23)")
        QTest.qWait(30)
        self.assertEqual(results.property("currentIndex"), 23)
        self.assertGreater(results.property("contentY"), 0)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(self.engine.evaluate("launcherFile").toString(), "/preview/document-23")
        self.assertEqual(desktop.property("openPanel"), "")

        desktop.setProperty("openPanel", "launcher")
        QTest.qWait(30)
        self.engine.evaluate('launcherTest.toggleFavorite("browser")')
        self.assertIn("browser", panel.property("favoriteIds").toVariant())
        self.item("launcherTab_Apps").forceActiveFocus(Qt.FocusReason.TabFocusReason)
        QTest.keyClick(self.window, Qt.Key.Key_Left)
        self.assertEqual(panel.property("mode"), "Windows")
        self.assertTrue(self.item("launcherTab_Windows").hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(panel.property("mode"), "Apps")
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(desktop.property("openPanel"), "")

    def test_launcher_reference_layout_responsive(self):
        self.fixtures.setProperty("reducedMotion", True)
        desktop = self.item("desktop")
        desktop.setProperty("openPanel", "launcher")
        QTest.qWait(30)
        panel = self.item("launcherPanel")
        search = self.item("launcherSearch")
        self.engine.globalObject().setProperty("launcherTest", self.engine.newQObject(panel))
        for width in (320, 375, 414, 768):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(40)
            frame = self.item("launcherResultFrame")
            tab_strip = self.item("launcherTabs")
            self.assertLess(search.mapToItem(panel, QPointF(0, search.height())).y(), tab_strip.mapToItem(panel, QPointF(0, 0)).y())
            tab_widths = []
            for mode in ("Apps", "Run", "Files", "Windows"):
                self.click("launcherTab_" + mode)
                tab = self.item("launcherTab_" + mode)
                tab_widths.append(tab.width())
                self.assertTrue(tab.property("checked"))
                for control in (search, frame, tab, self.item("launcherResults")):
                    position = control.mapToItem(panel, QPointF(0, 0))
                    self.assertGreaterEqual(position.x(), 0)
                    self.assertGreaterEqual(position.y(), 0)
                    self.assertLessEqual(position.x() + control.width(), panel.width() + 0.5)
                    self.assertLessEqual(position.y() + control.height(), panel.height() + 0.5)
                content = tab.property("contentItem")
                pending = [content]
                while pending:
                    child = pending.pop()
                    pending.extend(child.childItems())
                    if child.property("text") == mode:
                        self.assertFalse(child.property("truncated"), mode)
                        self.assertEqual(child.property("color"), search.property("color"))
                grab = panel.grabToImage()
                QTest.qWait(60)
                image = grab.image()
                self.assertFalse(image.isNull())
                folder = ROOT / ".artifacts"
                folder.mkdir(exist_ok=True)
                self.assertTrue(image.save(str(folder / f"launcher-tabs-{mode.lower()}-{width}.png")))
            self.assertLess(max(tab_widths) - min(tab_widths), 0.5)
            self.click("launcherTab_Run")
            search.setProperty("text", "very-long-command-" * 20)
            QTest.qWait(30)
            label = self.item("launcherResultLabel_0")
            self.assertEqual(label.property("maximumLineCount"), 1)
            self.assertTrue(label.property("truncated"))
            self.assertGreater(label.width(), 0)
            self.click("clearLauncherSearch")
            self.click("launcherTab_Apps")

    def test_launcher_search_activation_and_shortcut(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        self.click("launcherButton")
        search = self.item("launcherSearch")
        results = self.item("launcherResults")
        self.assertTrue(search.hasActiveFocus())
        self.assertEqual(results.property("count"), 7)
        search.setProperty("text", "  WEB  ")
        QTest.qWait(30)
        self.assertEqual(results.property("count"), 1)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(self.fixtures.property("lastLaunchedApp"), "browser")
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.assertTrue(self.item("launcherButton").hasActiveFocus())
        self.click("launcherButton")
        self.assertEqual(search.property("text"), "")
        search.setProperty("text", "development")
        QTest.qWait(30)
        self.assertEqual(results.property("count"), 2)
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        self.assertEqual(results.property("currentIndex"), 1)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(self.fixtures.property("lastLaunchedApp"), "terminal")
        self.click("launcherButton")
        search.setProperty("text", "no such app")
        QTest.qWait(30)
        self.assertTrue(self.item("launcherEmptyState").isVisible())
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(self.item("desktop").property("openPanel"), "launcher")
        self.assertEqual(self.fixtures.property("lastLaunchedApp"), "terminal")
        self.click("clearLauncherSearch")
        self.assertTrue(search.hasActiveFocus())
        search.setProperty("text", "files")
        QTest.qWait(30)
        self.click("launcherApp_files")
        self.assertEqual(self.fixtures.property("lastLaunchedApp"), "files")
        self.click("launcherButton")
        for width in (640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            drawer = self.item("launcherDrawer")
            self.assertAlmostEqual(drawer.x() + drawer.width() / 2, width / 2)
            self.assertGreaterEqual(drawer.x(), 0)
            self.assertLessEqual(drawer.x() + drawer.width(), width)
            self.capture("launcher-" + str(width))
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        shortcuts = self.window.findChild(QObject, "shortcutSettings")
        self.engine.globalObject().setProperty("launcherShortcuts", self.engine.newQObject(shortcuts))
        self.assertEqual(self.engine.evaluate('launcherShortcuts.binding("launcher")').toString(), "")
        self.assertTrue(self.engine.evaluate('launcherShortcuts.saveBinding("launcher", "Ctrl+Alt+L")').toBool())
        QTest.mouseMove(self.window, QPointF(10, 70).toPoint())
        QTest.qWait(30)
        QTest.keyClick(self.window, Qt.Key.Key_L, Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.AltModifier)
        QTest.qWait(30)
        self.assertEqual(self.item("desktop").property("openPanel"), "launcher")
        self.assertTrue(search.hasActiveFocus())
        self.click("closeLauncher")
        self.assertTrue(self.item("launcherButton").hasActiveFocus())

    def test_window_detected_monitors(self):
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("windowState", self.engine.newQObject(manager))
        expected = [screen.name() or f"Display {index + 1}" for index, screen in enumerate(self.app.screens())]
        self.assertEqual(manager.property("monitors").toVariant(), expected)
        self.assertEqual(manager.property("activeMonitor"), expected[0])
        self.assertTrue(all(window["monitor"] == expected[0] for window in manager.property("windows").toVariant()))
        self.fixtures.setProperty("reducedMotion", True)
        self.click("windowOverviewButton")
        self.assertEqual(self.item("windowMonitor0").property("currentText"), expected[0])
        self.set_test_monitors()
        self.assertEqual(self.item("windowMonitor0").property("currentText"), "DP-1")
        self.assertEqual(self.item("ruleMonitor").property("count"), 2)
        self.assertTrue(self.engine.evaluate('windowState.reserve("browser", "HDMI-A-1", 4, 0)').toBool())
        self.engine.evaluate('windowState.focus(1)')
        manager.setProperty("screens", [{"name": "DP-1"}])
        QTest.qWait(30)
        self.assertEqual(manager.property("activeMonitor"), "DP-1")
        self.assertTrue(all(window["monitor"] == "DP-1" for window in manager.property("windows").toVariant()))
        self.assertEqual(self.item("ruleMonitor").property("count"), 1)
        self.assertEqual(manager.property("rules").toVariant()[0]["monitor"], "HDMI-A-1")
        self.assertFalse(self.engine.evaluate('windowState.reserve("editor", "HDMI-A-1", 1, 1)').toBool())
        self.engine.evaluate('windowState.open("browser")')
        self.assertEqual(manager.property("activeMonitor"), "DP-1")
        self.set_test_monitors()
        self.engine.evaluate('windowState.open("browser")')
        self.assertEqual(manager.property("activeMonitor"), "HDMI-A-1")
        manager.reset()
        self.assertEqual(manager.property("activeMonitor"), "DP-1")
        self.capture("window-detected-monitors")

    def test_window_rules_reclaim_and_release(self):
        self.set_test_monitors()
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("windowState", self.engine.newQObject(manager))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            return result

        self.assertTrue(evaluate('windowState.reserve("browser", "DP-1", 1, 0)').toBool())
        self.assertEqual(evaluate('windowState.visibleWindows.map(window => window.appId).join(",")').toString(), "browser,editor,terminal")
        evaluate('windowState.close(1)')
        self.assertEqual(evaluate('windowState.visibleWindows.map(window => window.appId).join(",")').toString(), "editor,terminal")
        reopened = evaluate('windowState.open("browser")').toInt()
        self.assertEqual(evaluate('windowState.visibleWindows[0].windowId').toInt(), reopened)
        self.assertFalse(evaluate('windowState.reserve("editor", "DP-1", 1, 0)').toBool())
        evaluate('windowState.move(' + str(reopened) + ', "HDMI-A-1", 2)')
        self.assertEqual(evaluate('windowState.visibleWindows.length').toInt(), 2)
        evaluate('windowState.focus(' + str(reopened) + ')')
        self.assertEqual(manager.property("activeMonitor"), "HDMI-A-1")
        self.assertEqual(self.fixtures.property("workspace"), 2)
        evaluate('windowState.close(' + str(reopened) + ')')
        self.assertEqual(evaluate('windowState.visibleWindows.length').toInt(), 0)
        self.assertEqual(manager.property("focusedId"), -1)
        evaluate('windowState.open("browser")')
        self.assertEqual(manager.property("activeMonitor"), "DP-1")
        self.assertEqual(self.fixtures.property("workspace"), 1)
        evaluate('windowState.removeRule("browser")')
        self.assertEqual(evaluate('windowState.rules.length').toInt(), 0)

    def test_window_overview_interactions_and_saved_rules(self):
        self.set_test_monitors()
        self.fixtures.setProperty("reducedMotion", True)
        self.click("windowOverviewButton")
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("windowState", self.engine.newQObject(manager))
        self.assertEqual(self.item("overviewWindowList").property("count"), 3)
        self.click("reserveWindow0")
        self.assertTrue(self.item("reserveWindow0").property("checked"))
        self.click("closeWindow0")
        self.assertEqual(self.item("overviewWindowList").property("count"), 2)
        self.click("overviewRulesTab")
        self.assertEqual(self.item("windowRulesList").property("count"), 1)
        self.capture("window-overview-rules")
        second = QQmlApplicationEngine()
        second.warnings.connect(lambda messages: self.warnings.extend(str(message) for message in messages))
        second.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        second_window = second.rootObjects()[0]
        try:
            saved = second_window.findChild(QObject, "windowManager")
            self.assertEqual(saved.property("rules").toVariant()[0]["appId"], "editor")
        finally:
            second_window.close()
            second.deleteLater()
        self.window.requestActivate()
        self.engine.evaluate('windowState.open("editor")')
        QTest.qWait(30)
        self.click("overviewWindowsTab")
        self.item("windowSearch").setProperty("text", "terminal")
        QTest.qWait(30)
        self.assertEqual(self.item("overviewWindowList").property("count"), 1)
        self.click("floatWindow2")
        self.assertTrue(self.item("floatWindow2").property("checked"))
        self.click("floatWindow2")
        self.item("windowMonitor2").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_End)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        QTest.qWait(30)
        self.assertEqual(self.engine.evaluate('windowState.windows.find(window => window.windowId === 2).monitor').toString(), "HDMI-A-1")
        self.item("windowWorkspace2").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_End)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        QTest.qWait(30)
        self.click("focusWindow2")
        self.assertEqual(manager.property("activeMonitor"), "HDMI-A-1")
        self.assertEqual(self.fixtures.property("workspace"), 7)
        self.assertTrue(self.item("tilingScene").isVisible())
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.click("windowOverviewButton")
        self.item("windowSearch").setProperty("text", "")
        for width in (640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            drawer = self.item("windowOverviewDrawer")
            self.assertGreaterEqual(drawer.x(), 0)
            self.assertLessEqual(drawer.x() + drawer.width(), width)
            for name in ("windowMonitor1", "windowSlot1", "reserveWindow1"):
                control = self.item(name)
                self.assertLessEqual(control.mapToItem(drawer, QPointF(control.width(), 0)).x(), drawer.width())
            self.capture("window-overview-" + str(width))
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertTrue(self.item("windowOverviewButton").hasActiveFocus())

    def test_dynamic_window_tiling_counts(self):
        self.click("tilingButton")
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("windowState", self.engine.newQObject(manager))
        scene = self.item("tilingScene")
        profiles = self.window.findChild(QObject, "profileSettings")
        self.engine.evaluate('windowState.close(1); windowState.close(2)')
        QTest.qWait(30)
        only = self.item("tile0")
        self.assertAlmostEqual(only.width(), scene.width() - 2 * scene.property("outerGap"))
        self.engine.evaluate('for (let index = 0; index < 6; index++) windowState.open("browser")')
        for mode in ("Split", "Columns", "Centered"):
            profiles.setProperty("tilingLayout", mode)
            for width in (640, 1920, 5120):
                self.studio.setProperty("customWidth", width)
                QTest.qWait(30)
                windows = manager.property("visibleWindows").toVariant()
                tiles = [self.item("tile" + str(window["windowId"])) for window in windows]
                for tile in tiles:
                    self.assertGreater(tile.width(), 0)
                    self.assertGreater(tile.height(), 0)
                    self.assertLessEqual(tile.x() + tile.width(), scene.width())
                    self.assertLessEqual(tile.y() + tile.height(), scene.height())
                for index, first in enumerate(tiles):
                    for other in tiles[index + 1:]:
                        self.assertTrue(first.x() + first.width() <= other.x() + 0.01 or other.x() + other.width() <= first.x() + 0.01 or first.y() + first.height() <= other.y() + 0.01 or other.y() + other.height() <= first.y() + 0.01)

    def test_clipboard_history_search_pin_clear_copy(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        self.click("clipboardButton")
        self.assertTrue(self.item("clipboardSearch").hasActiveFocus())
        self.assertEqual(self.item("clipboardEntries").property("count"), 3)
        self.click("pinClip2")
        self.assertTrue(self.item("pinClip2").property("checked"))
        self.capture("clipboard-history")
        self.item("clipboardSearch").setProperty("text", "quickshell")
        QTest.qWait(30)
        self.assertEqual(self.item("clipboardEntries").property("count"), 1)
        self.item("clipboardSearch").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(self.fixtures.property("copiedClipboardId"), 0)
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.assertTrue(self.item("clipboardButton").hasActiveFocus())
        self.click("clipboardButton")
        self.item("clipboardSearch").setProperty("text", "")
        self.click("clearClipboard")
        self.click("cancelClipboardClear")
        self.assertEqual(self.item("clipboardEntries").property("count"), 3)
        self.click("clearClipboard")
        self.click("confirmClipboardClear")
        self.assertEqual(self.item("clipboardEntries").property("count"), 1)
        self.click("copyClip2")
        self.assertEqual(self.fixtures.property("copiedClipboardId"), 2)
        self.click("clipboardButton")
        self.click("removeClip2")
        self.assertTrue(self.item("clipboardEmptyState").isVisible())
        self.assertFalse(self.item("clearClipboard").isEnabled())
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertTrue(self.item("clipboardButton").hasActiveFocus())

    def test_alt_tab_is_separate_from_tile_manager(self):
        self.fixtures.setProperty("reducedMotion", True)
        manager = self.window.findChild(QObject, "windowManager")
        self.engine.globalObject().setProperty("windowState", self.engine.newQObject(manager))
        self.engine.evaluate('windowState.reserve("editor", windowState.defaultMonitor, 1, 0)')
        initial_windows = manager.property("windows").toVariant()
        initial_rules = manager.property("rules").toVariant()
        self.assertFalse(self.item("tilingScene").isVisible())
        alt = Qt.KeyboardModifier.AltModifier
        def cycle(reverse=False):
            modifiers = alt | Qt.KeyboardModifier.ShiftModifier if reverse else alt
            QTest.keyPress(self.window, Qt.Key.Key_Tab, modifiers)
            self.app.sendEvent(self.window, QKeyEvent(QEvent.Type.KeyRelease, Qt.Key.Key_Tab, modifiers))

        QTest.keyPress(self.window, Qt.Key.Key_Alt)
        cycle()
        QTest.qWait(30)
        switcher = self.item("windowSwitcher")
        self.assertTrue(switcher.property("opened"))
        self.assertEqual(switcher.property("selectedId"), 1)
        self.assertEqual(manager.property("focusedId"), 0)
        self.assertFalse(self.item("windowOverviewDrawer").property("opened"))
        cycle()
        self.assertEqual(switcher.property("selectedId"), 2)
        self.capture("alt-tab-switcher")
        QTest.keyRelease(self.window, Qt.Key.Key_Alt)
        QTest.qWait(30)
        self.assertFalse(switcher.property("opened"))
        self.assertEqual(manager.property("focusedId"), 2)
        self.assertEqual(manager.property("windows").toVariant(), initial_windows)
        self.assertEqual(manager.property("rules").toVariant(), initial_rules)
        QTest.keyPress(self.window, Qt.Key.Key_Alt)
        cycle()
        self.assertEqual(switcher.property("selectedId"), 0)
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        QTest.keyRelease(self.window, Qt.Key.Key_Alt)
        self.assertEqual(manager.property("focusedId"), 2)
        self.assertFalse(switcher.property("opened"))
        QTest.keyPress(self.window, Qt.Key.Key_Alt)
        cycle(reverse=True)
        self.assertEqual(switcher.property("selectedId"), 1)
        QTest.keyRelease(self.window, Qt.Key.Key_Alt)
        self.assertEqual(manager.property("focusedId"), 1)
        self.click("windowOverviewButton")
        self.assertTrue(self.item("windowOverviewDrawer").property("opened"))
        self.assertFalse(switcher.property("opened"))
        QTest.keyPress(self.window, Qt.Key.Key_Alt)
        cycle()
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        QTest.keyRelease(self.window, Qt.Key.Key_Alt)
        self.assertTrue(self.item("windowOverviewDrawer").property("opened"))
        self.assertEqual(manager.property("focusedId"), 1)
        self.click("closeWindowOverview")
        QTest.keyPress(self.window, Qt.Key.Key_Alt)
        cycle()
        selected = switcher.property("selectedId")
        self.engine.evaluate('windowState.close(' + str(selected) + ')')
        QTest.qWait(30)
        self.assertNotEqual(switcher.property("selectedId"), selected)
        QTest.keyRelease(self.window, Qt.Key.Key_Alt)
        self.assertNotEqual(manager.property("focusedId"), selected)
        self.engine.evaluate('for (const window of windowState.windows.slice()) windowState.close(window.windowId)')
        QTest.keyPress(self.window, Qt.Key.Key_Alt)
        cycle()
        QTest.keyRelease(self.window, Qt.Key.Key_Alt)
        self.assertFalse(switcher.property("opened"))

    def test_volume_and_keyboard(self):
        self.click("volumeButton")
        slider = self.item("volumeSlider")
        slider.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(self.fixtures.property("volume"), 65)
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.item("bottomApp_terminal").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertEqual(self.window.findChild(QObject, "windowManager").property("focusedId"), 2)

    def test_volume_mixer_independent_apps(self):
        self.click("volumeButton")
        QTest.qWait(280)
        music = self.item("appVolume_music")
        music.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Left)
        self.assertEqual(music.property("value"), 79)
        self.assertEqual(self.item("appVolume_browser").property("value"), 45)
        self.assertEqual(self.item("appVolume_chat").property("value"), 70)
        self.assertEqual(self.fixtures.property("volume"), 64)
        self.click("appMute_music")
        self.assertTrue(self.item("appMute_music").property("checked"))
        self.assertFalse(self.item("appMute_browser").property("checked"))
        self.assertEqual(music.property("value"), 79)
        self.click("appMute_music")
        self.assertFalse(self.item("appMute_music").property("checked"))
        self.assertEqual(music.property("value"), 79)
        self.click("outputMute")
        self.assertTrue(self.fixtures.property("outputMuted"))
        self.assertEqual(self.item("volumeButton").property("text"), "Muted")
        self.assertEqual(self.item("volumeButton").property("iconName"), "volume-x")
        self.assertEqual(self.fixtures.property("volume"), 64)
        self.assertFalse(self.item("appMute_music").property("checked"))
        self.capture("volume-mixer")
        self.click("closeVolume")
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.click("volumeButton")
        QTest.qWait(280)
        self.assertEqual(self.item("appVolume_music").property("value"), 79)
        self.assertTrue(self.item("outputMute").property("checked"))
        self.click("resetButton")
        self.assertFalse(self.fixtures.property("outputMuted"))
        self.assertEqual(self.item("appVolume_music").property("value"), 80)

    def test_volume_mixer_dynamic_apps_and_bounds(self):
        self.click("volumeButton")
        QTest.qWait(280)
        self.engine.globalObject().setProperty("audioFixtures", self.engine.newQObject(self.fixtures))

        def evaluate(script):
            result = self.engine.evaluate(script)
            self.assertFalse(result.isError(), result.toString())
            QTest.qWait(30)
            return result

        evaluate('audioFixtures.setAppVolume("music", 250)')
        self.assertEqual(self.item("appVolume_music").property("value"), 100)
        evaluate('audioFixtures.setAppVolume("music", -20)')
        self.assertEqual(self.item("appVolume_music").property("value"), 0)
        evaluate('audioFixtures.setAppVolume("music", NaN)')
        self.assertEqual(self.item("appVolume_music").property("value"), 0)
        evaluate('audioFixtures.audioApps.remove(0)')
        evaluate('audioFixtures.setAppVolume("music", 90)')
        self.assertEqual(self.item("appVolume_browser").property("value"), 45)
        evaluate('audioFixtures.setAppVolume("browser", 32)')
        self.assertEqual(self.item("appVolume_browser").property("value"), 32)
        evaluate('audioFixtures.audioApps.clear()')
        self.assertTrue(self.item("audioEmptyState").isVisible())
        evaluate('audioFixtures.audioApps.append({appId: "new", appName: "New player", streamName: "Playback", level: 55, muted: false})')
        self.assertFalse(self.item("audioEmptyState").isVisible())
        self.assertEqual(self.item("appVolume_new").property("value"), 55)
        self.click("appMute_new")
        self.assertTrue(self.item("appMute_new").property("checked"))
        evaluate('for (let index = 0; index < 12; index++) audioFixtures.audioApps.append({appId: "extra" + index, appName: "Player " + index, streamName: "Playback", level: 50, muted: false})')
        app_list = self.item("audioAppList")
        self.assertGreater(app_list.property("contentHeight"), app_list.height())
        app_list.setProperty("contentY", app_list.property("contentHeight") - app_list.height())
        QTest.qWait(50)
        self.click("appMute_extra11")
        self.assertTrue(self.item("appMute_extra11").property("checked"))
        self.capture("volume-mixer-scrolled")

    def test_layouts_and_specimen(self):
        self.capture("primary-fit")
        self.click("specimenButton")
        self.assertTrue(self.studio.property("specimenVisible"))
        self.capture("font-specimen")
        self.click("specimenButton")
        self.click("ultrawideSize")
        self.assertEqual(self.item("desktop").width(), 5120)
        self.capture("ultrawide-fit")
        self.click("actualMode")
        self.assertEqual(self.item("desktop").scale(), 1)
        self.assertGreater(self.item("viewport").property("contentWidth"), self.window.width())
        self.capture("ultrawide-actual")
        self.click("fitMode")
        self.window.setWidth(960)
        self.window.setHeight(640)
        QTest.qWait(100)
        self.assertLess(self.item("desktop").scale(), 1)
        self.capture("compact-fit")
        self.item("canvasWidthSlider").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Left)
        self.assertEqual(self.item("desktop").width(), 5040)

    def test_repeated_hot_reload(self):
        process = QProcess()
        process.setWorkingDirectory(str(ROOT))
        process.start(sys.executable, [str(ROOT / "tools" / "preview.py"), "--watch"])
        try:
            self.assertTrue(process.waitForStarted(5000))
            self.assertTrue(process.waitForReadyRead(5000))
            self.assertIn(b"Watching QML sources", bytes(process.readAllStandardOutput()))
            for _attempt in range(2):
                os.utime(ROOT / "preview" / "FixtureState.qml", None)
                self.assertTrue(process.waitForReadyRead(5000))
                self.assertIn(b"Preview reloaded", bytes(process.readAllStandardOutput()))
            self.assertEqual(bytes(process.readAllStandardError()), b"")
        finally:
            process.terminate()
            process.waitForFinished(5000)

    def test_ai_panel_lifecycle_and_meters(self):
        self.click("aiButton")
        QTest.qWait(280)
        self.assertEqual(self.item("desktop").property("openPanel"), "ai")
        self.assertEqual(self.item("vramMeter0").property("filledSegments"), 15)
        self.assertEqual(self.item("vramMeter1").property("filledSegments"), 3)
        self.assertEqual(self.item("tokenRate").property("text"), "42.6 tok/s")
        self.capture("local-ai-panel")
        self.click("aiStop")
        self.click("aiCancel")
        self.assertEqual(self.fixtures.property("aiStatus"), "Running")
        self.click("aiStop")
        self.click("aiConfirm")
        self.assertEqual(self.fixtures.property("aiStatus"), "Stopping")
        self.assertFalse(self.item("aiStart").isEnabled())
        QTest.qWait(400)
        self.assertEqual(self.fixtures.property("loadedModelIndex"), -1)
        self.assertEqual(self.item("tokenRate").property("text"), "N/A")
        self.click("aiStart")
        QTest.qWait(400)
        self.assertEqual(self.fixtures.property("aiStatus"), "Running")
        self.item("aiPanel").setProperty("candidateIndex", 1)
        self.click("aiSwitch")
        self.assertEqual(self.fixtures.property("loadedModelIndex"), 0)
        self.click("aiConfirm")
        QTest.qWait(400)
        self.assertEqual(self.fixtures.property("loadedModelIndex"), 1)
        self.fixtures.setProperty("telemetryAvailable", False)
        self.assertEqual(self.item("vramMeter0").property("filledSegments"), 0)
        self.capture("local-ai-unavailable")
        self.click("aiStop")
        self.click("aiConfirm")
        QTest.qWait(400)
        self.fixtures.setProperty("failNextStart", True)
        self.click("aiStart")
        QTest.qWait(400)
        self.assertEqual(self.fixtures.property("aiStatus"), "Error")
        self.assertEqual(self.fixtures.property("loadedModelIndex"), -1)
        self.assertTrue(self.item("aiStart").isEnabled())
        self.item("aiPanel").setProperty("actionsEnabled", False)
        for name in ("modelPicker", "aiStart", "aiStop", "aiSwitch", "aiConfirm"):
            self.assertFalse(self.item(name).isEnabled(), name)
        self.fixtures.setProperty("runningRequests", -1)
        self.item("aiPanel").setProperty("pendingAction", "stop")
        self.assertFalse(self.item("aiConfirm").isEnabled())

    def test_ai_panel_uses_preloaded_nonfirst_default(self):
        component = QQmlComponent(self.engine)
        component.setData(b'''import QtQuick
import "../shell/Modules/LocalAI"
LocalAIPanel {
    service: QtObject {
        property bool aiManaged: true
        property var models: ["Gemma", "Qwen3.8"]
        property int loadedModelIndex: 1
        property string loadedModelName: "qwen3.8-27b"
        property string runtimeLabel: "vLLM"
        property string aiStatus: "ready"
        property bool aiBusy: false
        property int runningRequests: 0
        property string aiError: ""
        property real tokensPerSecond: 0
        property bool reducedMotion: true
        property bool telemetryAvailable: false
        property var gpus: []
        property QtObject modelManager: QtObject {
            property int defaultModelIndex: 1
            property var loadingProgress: null
            property int elapsedSeconds: -1
            property bool external: false
            property bool canStart: false
            property bool canStop: true
            property bool canSwitch: true
            property bool canAdopt: false
            property string profileName: "Work"
            property var profileDefaults: ({})
            property var presets: [{id: "vllm/gemma"}, {id: "vllm/qwen38"}]
            property string clientStatus: "OpenCode configured"
            function canConfigure(index) { return index === 1; }
        }
    }
}''', QUrl.fromLocalFile(str(ROOT / "tests/ai-panel-test.qml")))
        panel = component.create()
        self.assertIsNotNone(panel, str(component.errors()))
        panel.setParentItem(self.window.contentItem())
        try:
            self.assertEqual(panel.property("candidateIndex"), 1)
            picker = panel.findChild(QObject, "modelPicker")
            self.assertEqual(picker.property("currentIndex"), 1)
            manager = panel.property("service").property("modelManager")
            picker.setProperty("currentIndex", 0)
            picker.activated.emit(0)
            manager.setProperty("defaultModelIndex", 0)
            manager.setProperty("defaultModelIndex", 1)
            self.assertEqual(panel.property("candidateIndex"), 0)
            panel.setVisible(False)
            panel.setVisible(True)
            self.assertEqual(panel.property("candidateIndex"), 1)
        finally:
            panel.deleteLater()

    def test_ai_settings_restart_and_compact_layout(self):
        self.click("aiButton")
        QTest.qWait(280)
        panel = self.item("aiPanel")
        self.assertEqual(panel.property("candidateIndex"), self.fixtures.property("loadedModelIndex"))
        self.assertTrue(self.item("aiSwitch").isEnabled())
        self.click("aiSwitch")
        self.assertEqual(panel.property("pendingAction"), "switch")
        self.click("aiCancel")
        original_height = panel.height()
        settings_button = self.item("aiSettings")
        original_position = settings_button.mapToScene(QPointF(0, 0))
        self.click("aiSettings")
        self.assertTrue(self.item("aiSettingsSection").isVisible())
        self.assertEqual(panel.height(), original_height)
        self.assertEqual(settings_button.mapToScene(QPointF(0, 0)), original_position)
        self.assertTrue(self.item("aiConfigure").isVisible())
        self.assertEqual(self.item("aiDefaultModel").property("currentIndex"), 0)
        panel.setProperty("actionsEnabled", False)
        self.assertTrue(self.item("aiSettings").isEnabled())
        self.assertFalse(self.item("aiSwitch").isEnabled())
        self.click("aiSettings")
        self.assertFalse(self.item("aiSettingsSection").isVisible())
        self.assertEqual(panel.height(), original_height)
        for width in (320, 375, 414, 768):
            panel.setImplicitWidth(width)
            QTest.qWait(50)
            self.assertEqual(panel.width(), width)
            original_height = panel.height()
            original_position = settings_button.mapToScene(QPointF(0, 0))
            for opened in (True, False, True, False):
                self.click("aiSettings")
                self.assertEqual(panel.property("settingsOpen"), opened)
                self.assertEqual(settings_button.property("checked"), opened)
                self.assertEqual(self.item("aiTelemetrySection").isVisible(), not opened)
                self.assertEqual(panel.height(), original_height, width)
                self.assertEqual(settings_button.mapToScene(QPointF(0, 0)), original_position, width)
                if opened:
                    configure = self.item("aiConfigure")
                    position = configure.mapToItem(panel, QPointF(0, 0))
                    self.assertLessEqual(position.y() + configure.height(), panel.height(), width)
                    self.assertLessEqual(position.x() + configure.width(), panel.width(), width)
                    self.capture(f"local-ai-settings-{width}")
            for name in ("loadedModel", "modelPicker", "tokenRate", "vramMeter0", "gpuMeter1", "aiSettings"):
                child = self.item(name)
                left = child.mapToItem(panel, QPointF(0, 0)).x()
                self.assertGreaterEqual(left, 0, (width, name))
                self.assertLessEqual(left + child.width(), panel.width(), (width, name))
            self.capture(f"local-ai-compact-{width}")
        self.assertLess(panel.implicitHeight(), 650)

    def test_ai_loading_progress_measured_and_indeterminate(self):
        self.click("aiButton")
        QTest.qWait(280)
        panel = self.item("aiPanel")
        panel.setProperty("loadingProgress", {"label": "Loading model weights", "fraction": 0.5, "detail": "1 / 2 shards"})
        self.assertTrue(self.item("aiLoadingProgress").isVisible())
        self.assertEqual(self.item("aiLoadingProgress").property("value"), 0.5)
        self.assertFalse(self.item("aiLoadingProgress").property("indeterminate"))
        self.assertEqual(self.item("aiLoadingPercent").property("text"), "50%")
        self.capture("local-ai-loading-measured")
        panel.setProperty("loadingProgress", {"label": "Compiling model kernels", "fraction": None, "detail": ""})
        self.assertTrue(self.item("aiLoadingProgress").property("indeterminate"))
        self.assertEqual(self.item("aiLoadingPercent").property("text"), "")
        self.assertEqual(self.item("aiLoadingStage").property("text"), "Compiling model kernels")
        self.capture("local-ai-loading-indeterminate")
        panel.setProperty("loadingProgress", None)
        self.assertFalse(self.item("aiLoadingProgress").isVisible())

    def test_meter_bounds(self):
        meter = self.item("vramMeter0")
        for value, expected in ((-0.2, 0), (0, 0), (0.5, 10), (1, 20), (1.2, 20), (float("nan"), 0)):
            meter.setProperty("value", value)
            self.assertEqual(meter.property("filledSegments"), expected)

    def test_toggle_and_volume_colors(self):
        self.click("controlsButton")
        QTest.qWait(280)
        self.assertEqual(self.item("wifiEnabledSwitchBackground").property("color"), QColor("#efefeb"))
        self.assertEqual(self.item("bluetoothEnabledSwitchBackground").property("color"), QColor("#1c1c1c").lighter(150))
        self.click("wifiEnabledSwitch")
        QTest.mouseMove(self.window, QPointF(10, 70).toPoint())
        QTest.qWait(30)
        self.assertEqual(self.item("wifiEnabledSwitchBackground").property("color"), QColor("#1c1c1c").lighter(150))
        self.item("wifiEnabledSwitch").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertTrue(self.fixtures.property("wifiEnabled"))
        self.assertEqual(self.item("wifiEnabledSwitchBackground").property("color"), QColor("#efefeb"))
        for volume in (0, 35, 100):
            self.fixtures.setProperty("volume", volume)
            for name in ("volumeSlider",):
                track = self.item(name + "Track")
                fill = self.item(name + "Fill")
                self.assertEqual(track.property("color"), QColor("#1c1c1c"))
                self.assertEqual(fill.property("color"), QColor("#efefeb"))
                self.assertAlmostEqual(fill.width(), track.width() * volume / 100)
                self.assertEqual(fill.x(), 0)
        self.fixtures.setProperty("volume", 64)
        self.capture("monochrome-controls")
        self.open_settings()
        self.assertEqual(self.item("glassSwitchTrack").property("color"), QColor("#efefeb"))
        self.assertEqual(self.item("reducedMotionSwitchTrack").property("color"), QColor("#1c1c1c"))

    def test_meter_frame_at_fractional_scales(self):
        self.click("aiButton")
        QTest.qWait(280)
        for width, height in ((1440, 900), (960, 640), (1920, 1200)):
            self.window.setWidth(width)
            self.window.setHeight(height)
            QTest.qWait(100)
            image = self.window.grabWindow()
            ratio = image.devicePixelRatio()
            for name in ("vramMeter0", "gpuMeter0", "vramMeter1", "gpuMeter1"):
                meter = self.item(name)
                self.assertEqual(meter.height(), 38)
                for horizontal, vertical in ((0.85, 0), (0.85, 1), (0, 0.5), (1, 0.5)):
                    point = meter.mapToScene(QPointF(meter.width() * horizontal, meter.height() * vertical))
                    pixel_x = round(point.x() * ratio)
                    pixel_y = round(point.y() * ratio)
                    values = [image.pixelColor(pixel_x + delta_x, pixel_y + delta_y).lightness()
                              for delta_x in range(-1, 2) for delta_y in range(-1, 2)]
                    self.assertGreater(max(values), 110, (width, name, horizontal, vertical))
            self.capture("ai-meter-" + str(width))

    def test_drawers_power_and_controls(self):
        self.click("controlsButton")
        drawer = self.item("controlDrawer")
        self.assertTrue(drawer.property("animating"))
        QTest.qWait(80)
        self.assertGreater(drawer.property("progress"), 0)
        self.assertLess(drawer.property("progress"), 1)
        self.capture("controls-opening")
        QTest.qWait(240)
        self.assertEqual(drawer.property("progress"), 1)
        self.assertEqual(drawer.property("edge"), "left")
        self.click("wifiEnabledSwitch")
        self.assertFalse(self.fixtures.property("wifiEnabled"))
        self.home_action("homeProfilesTab")
        self.item("profileSelect", self.item("homeProfilesPage")).forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        self.confirm_profile()
        self.assertEqual(self.fixtures.property("profile"), "Gaming")
        self.capture("control-area")
        self.click("homeTab")
        self.click("controlNext")
        self.assertEqual(self.fixtures.property("trackIndex"), 1)
        self.item("homePanel").setProperty("page", "Workspaces")
        self.click("controlWorkspace4")
        self.assertEqual(self.fixtures.property("workspace"), 4)
        self.open_settings()
        self.assertTrue(self.settings_window.isVisible())
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.click("motionTab")
        self.capture("shortcut-settings", self.settings_window)
        self.click("reducedMotionSwitch")
        self.settings_window.close()
        self.window.requestActivate()
        self.click("wallpaperButton")
        self.assertEqual(self.item("wallpaperDrawer").property("progress"), 1)
        self.assertEqual(drawer.property("progress"), 0)
        self.click("wallpaperTile1")
        self.assertEqual(self.fixtures.property("wallpaper"), 1)
        self.capture("wallpaper-drawer")
        self.click("aiButton")
        self.assertEqual(self.item("aiDrawer").property("edge"), "right")
        self.assertEqual(self.item("aiDrawer").property("progress"), 1)
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.assertTrue(self.item("aiButton").hasActiveFocus())
        self.click("powerButton")
        self.click("powerShutdown")
        self.click("powerCancel")
        self.assertEqual(self.fixtures.property("lastPowerAction"), "")
        self.click("powerShutdown")
        self.click("powerConfirm")
        self.assertEqual(self.fixtures.property("lastPowerAction"), "Shut down")
        self.capture("power-menu")

    def test_media_strip_and_shortcuts(self):
        self.click("nextButton")
        self.assertEqual(self.fixtures.property("trackIndex"), 1)
        self.click("previousButton")
        self.assertEqual(self.fixtures.property("trackIndex"), 0)
        self.item("mediaSeek").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(self.fixtures.property("trackPosition"), 1)
        modifiers = Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.AltModifier
        QTest.keyClick(self.window, Qt.Key.Key_K, modifiers)
        self.assertEqual(self.fixtures.property("trackIndex"), 1)
        QTest.keyClick(self.window, Qt.Key.Key_M, modifiers)
        self.assertFalse(self.fixtures.property("playing"))
        self.fixtures.setProperty("mediaAvailable", False)
        self.assertFalse(self.item("playbackButton").isEnabled())
        self.assertFalse(self.item("mediaSeek").isEnabled())
        self.assertEqual(self.item("barTrackTitle").property("text"), "No media")
        QTest.keyClick(self.window, Qt.Key.Key_K, modifiers)
        self.assertEqual(self.fixtures.property("trackIndex"), 1)

    def test_native_shortcut_recorder_delegates_without_local_activation(self):
        modifiers = Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.AltModifier
        QTest.keyClick(self.window, Qt.Key.Key_S, modifiers)
        QTest.qWait(280)
        self.click("shortcutsTab")
        shortcuts = self.item("shortcutSettings")
        shortcuts.setProperty("nativeBackend", True)
        shortcuts.setProperty("ready", True)
        requested = []
        activated = []
        shortcuts.bindingRequested.connect(lambda key, sequence: requested.append((key, sequence)))
        shortcuts.activated.connect(activated.append)
        self.click("bind_ai")
        QTest.keyClick(self.settings_window, Qt.Key.Key_Space, Qt.KeyboardModifier.MetaModifier)
        self.assertEqual(requested, [("ai", "Meta+Space")])
        self.assertEqual(self.item("bind_ai").property("text"), "Press keys...")
        self.assertEqual(shortcuts.property("overrides").toVariant(), {})
        shortcuts.setProperty("recording", "")
        QTest.keyClick(self.settings_window, Qt.Key.Key_W, modifiers)
        self.assertEqual(activated, [])
        shortcuts.setProperty("busy", True)
        self.engine.globalObject().setProperty("nativeRecorder", self.engine.newQObject(shortcuts))
        self.assertFalse(self.engine.evaluate('nativeRecorder.saveBinding("ai", "Meta+Tab")').toBool())
        self.assertEqual(len(requested), 1)

    def test_shortcut_recording_conflict_and_persistence(self):
        modifiers = Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.AltModifier
        QTest.keyClick(self.window, Qt.Key.Key_S, modifiers)
        QTest.qWait(280)
        self.assertTrue(self.settings_window.isVisible())
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        self.click("shortcutsTab")
        self.click("bind_ai")
        QTest.keyClick(self.settings_window, Qt.Key.Key_W, modifiers)
        settings = self.item("shortcutSettings")
        self.assertIn("Already assigned", settings.property("error"))
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        QTest.keyClick(self.settings_window, Qt.Key.Key_L, modifiers)
        self.assertEqual(settings.property("recording"), "")
        self.assertEqual(self.item("bind_ai").property("text"), "Ctrl+Alt+L")
        QTest.keyClick(self.settings_window, Qt.Key.Key_Escape)
        self.assertFalse(self.settings_window.isVisible())
        self.window.requestActivate()
        QTest.qWait(280)
        QTest.keyClick(self.window, Qt.Key.Key_A, modifiers)
        self.assertEqual(self.item("desktop").property("openPanel"), "")
        QTest.keyClick(self.window, Qt.Key.Key_L, modifiers)
        self.assertEqual(self.item("desktop").property("openPanel"), "ai")
        QTest.qWait(280)
        self.capture("local-ai-drawer")
        second = QQmlApplicationEngine()
        second.warnings.connect(lambda messages: self.warnings.extend(str(message) for message in messages))
        second.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        second_window = second.rootObjects()[0]
        try:
            saved = second_window.findChild(QObject, "shortcutSettings")
            overrides = saved.property("overrides").toVariant()
            self.assertEqual(overrides["ai"], "Ctrl+Alt+L")
        finally:
            second_window.close()
            second.deleteLater()
        self.window.requestActivate()
        QTest.qWait(50)
        QTest.keyClick(self.window, Qt.Key.Key_S, modifiers)
        QTest.qWait(280)
        self.click("clear_ai")
        self.assertEqual(self.item("bind_ai").property("text"), "Unassigned")
        self.click("reset_ai")
        self.assertEqual(self.item("bind_ai").property("text"), "Ctrl+Alt+A")

    def test_animation_reversal(self):
        for button, drawer in (("controlsButton", "controlDrawer"), ("aiButton", "aiDrawer"), ("clockButton", "calendarDrawer"), ("launcherButton", "launcherDrawer")):
            self.click(button)
            QTest.qWait(60)
            self.assertTrue(self.item(drawer).property("animating"))
            self.click(button)
            QTest.qWait(280)
            self.assertEqual(self.item(drawer).property("progress"), 0)
            self.assertFalse(self.item(drawer).isVisible())
        self.click("wallpaperButton")
        QTest.qWait(60)
        self.assertTrue(self.item("wallpaperDrawer").property("animating"))
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        QTest.qWait(280)
        self.assertFalse(self.item("wallpaperDrawer").isVisible())

    def test_bar_independent_placement(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        self.studio.setProperty("customWidth", 1920)
        profile = self.window.findChild(QObject, "profileSettings")
        self.open_settings()
        self.item("settingsSurface").setProperty("section", 2)
        QTest.qWait(40)
        self.click("floatingLeftBarAttached")
        self.click("floatingMiddleBarFloating")
        self.click("floatingRightBarAttached")
        self.assertFalse(profile.property("floatingLeftBar"))
        self.assertTrue(profile.property("floatingMiddleBar"))
        self.assertFalse(profile.property("floatingRightBar"))
        profile.save()
        self.settings_window.close()
        for width in (320, 640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(40)
            left = self.item("barLeft")
            middle = self.item("barCenter")
            right = self.item("barRight")
            self.assertEqual(left.x(), 0)
            self.assertEqual(left.y(), 0)
            self.assertEqual(left.property("topLeftRadius"), 0)
            self.assertEqual(left.property("bottomLeftRadius"), 0)
            self.assertEqual(right.x() + right.width(), width)
            self.assertEqual(right.property("topRightRadius"), 0)
            self.assertEqual(right.property("bottomRightRadius"), 0)
            if width >= 640:
                self.assertEqual(right.y(), 0)
            if middle.isVisible():
                self.assertEqual(middle.y(), 4)
                self.assertTrue(middle.property("floating"))
            if width in (320, 1920):
                self.capture("bar-placement-" + str(width))
        profile.setProperty("floatingLeftBar", True)
        QTest.qWait(30)
        self.assertEqual(self.item("barLeft").x(), 12)
        self.assertEqual(self.item("barLeft").y(), 4)
        self.assertFalse(profile.property("floatingRightBar"))
        self.assertTrue(profile.property("dirty"))
        profile.revert()
        self.assertFalse(profile.property("floatingLeftBar"))
        profile.setProperty("activeName", "Gaming")
        self.assertTrue(profile.property("floatingLeftBar"))
        self.assertFalse(profile.property("floatingMiddleBar"))
        self.assertTrue(profile.property("floatingRightBar"))
        profile.setProperty("activeName", "Work")
        self.assertFalse(profile.property("floatingLeftBar"))
        self.assertTrue(profile.property("floatingMiddleBar"))
        self.assertFalse(profile.property("floatingRightBar"))
        restored = QQmlApplicationEngine()
        restored.load(QUrl.fromLocalFile(str(ROOT / "preview" / "ProfileSettings.qml")))
        self.assertTrue(restored.rootObjects())
        saved = restored.rootObjects()[0]
        self.assertFalse(saved.property("floatingLeftBar"))
        self.assertTrue(saved.property("floatingMiddleBar"))
        self.assertFalse(saved.property("floatingRightBar"))
        restored.deleteLater()
        self.app.processEvents()

    def test_bar_hardware_icons_and_metrics(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        for width in (320, 375, 414, 640, 800, 1024, 1920, 2560, 5120):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(40)
            left = self.item("barLeft")
            right = self.item("barRight")
            self.assertGreaterEqual(right.x(), 0)
            self.assertLessEqual(right.x() + right.width(), width)
            if width < 640:
                self.assertGreaterEqual(right.y(), left.y() + left.height())
            else:
                self.assertLessEqual(left.x() + left.width() + 8, right.x())
            for name, icon in (("barCpu", "cpu"), ("barGpu0", "circuit-board"), ("barGpu1", "circuit-board")):
                button = self.item(name)
                self.assertTrue(button.isVisible())
                self.assertEqual(button.property("iconName"), icon)
                self.assertFalse(button.property("iconOnly"))
                self.assertIn("%", button.property("text"))
                position = button.mapToItem(right, QPointF(0, 0))
                self.assertGreaterEqual(position.x(), 0)
                self.assertLessEqual(position.x() + button.width(), right.width())
                content = button.property("contentItem")
                self.assertLessEqual(content.implicitWidth(), content.width() + 1)
            for name in ("aiButton", "volumeButton", "wallpaperButton"):
                self.assertTrue(self.item(name).isVisible())
                self.assertTrue(self.item(name).property("iconName"))
                if width < 1600:
                    self.assertTrue(self.item(name).property("iconOnly"))
            if width in (320, 800, 1920, 5120):
                self.capture("bar-hardware-" + str(width))
        self.studio.setProperty("customWidth", 320)
        activities = self.window.findChild(QObject, "activities")
        activities.startRecording(False)
        QTest.qWait(40)
        right = self.item("barRight")
        self.assertGreaterEqual(right.x(), 0)
        self.assertLessEqual(right.x() + right.width(), 320)
        self.assertTrue(self.item("recordingIndicator").isVisible())
        self.fixtures.setProperty("telemetryAvailable", False)
        QTest.qWait(40)
        for name in ("barCpu", "barGpu0", "barGpu1"):
            self.assertEqual(self.item(name).property("text"), "N/A")
        self.click("barGpu1")
        self.assertEqual(self.item("desktop").property("openPanel"), "gpu")
        self.assertEqual(self.item("desktop").property("selectedGpu"), 1)
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.click("barCpu")
        self.assertEqual(self.item("homePanel").property("page"), "System")
        self.assertEqual(self.item("desktop").property("openPanel"), "controls")

    def test_bar_progressive_width(self):
        desktop = self.item("desktop")
        gpu_button = self.item("barGpu0")
        self.engine.globalObject().setProperty("gpuButton", self.engine.newQObject(gpu_button))
        result = self.engine.evaluate('gpuButton.gpu.name = "NVIDIA GeForce RTX 5090"; gpuButton.gpuChanged();')
        self.assertFalse(result.isError(), result.toString())
        for width in (640, 800, 878, 880, 958, 960, 1024, 1078, 1080, 1158, 1160, 1218, 1220, 1280, 1298, 1300, 1398, 1400, 1518, 1520, 1678, 1680, 1758, 1760, 1918, 1920, 1998, 2000, 2478, 2480, 2560, 3078, 3080, 3158, 3160, 3440, 3678, 3680, 5120):
            with self.subTest(width=width):
                desktop.setWidth(width)
                QTest.qWait(20)
                if width >= 1600:
                    self.assertTrue(gpu_button.property("text").startswith("RTX 5090 "))
                    self.assertIn("%", gpu_button.property("text"))
                    self.assertIn("NVIDIA GeForce RTX 5090", gpu_button.property("description"))
                    content = gpu_button.property("contentItem")
                    self.assertLessEqual(content.implicitWidth(), content.width() + 1)
                left = self.item("barLeft")
                center = self.item("barCenter")
                right = self.item("barRight")
                controls = self.item("controlsButton")
                if center.isVisible():
                    self.assertLessEqual(left.x() + left.width() + 8, center.x())
                    self.assertLessEqual(center.x() + center.width() + 8, right.x())
                else:
                    self.assertLessEqual(left.x() + left.width() + 8, right.x())
                controls_position = controls.mapToItem(left, QPointF(0, 0))
                self.assertGreaterEqual(controls_position.x(), 0)
                self.assertGreaterEqual(controls_position.y(), 0)
                self.assertLessEqual(controls_position.x() + controls.width(), left.width())
                self.assertLessEqual(controls_position.y() + controls.height(), left.height())
                self.assertAlmostEqual(center.x() + center.width() / 2, width / 2)
                settings = self.item("wallpaperButton")
                settings_position = settings.mapToItem(right, QPointF(0, 0))
                self.assertGreaterEqual(settings_position.x(), 0)
                self.assertGreaterEqual(settings_position.y(), 0)
                self.assertAlmostEqual(settings_position.x() + settings.width(), right.width() - 8)
                self.assertLessEqual(settings_position.y() + settings.height(), right.height())
                self.assertGreaterEqual(left.x(), 0)
                self.assertLessEqual(right.x() + right.width(), width)
                for name in ("controlsButton", "clockButton", "powerButton", "barCpu", "barGpu0", "barGpu1", "bottomApp_editor", "aiButton", "volumeButton", "wallpaperButton"):
                    self.assertTrue(self.item(name).isVisible(), name)
                self.assertEqual(self.item("playbackButton").isVisible(), center.isVisible())
        self.assertTrue(self.item("barAiDetails").isVisible())
        self.assertIn("GiB", self.item("barGpu0").property("text"))
        self.assertTrue(self.item("barTrackTime").isVisible())
        desktop.setWidth(800)
        QTest.qWait(20)
        self.assertFalse(self.item("barAiDetails").isVisible())
        self.assertTrue(self.item("barGpu0").isVisible())
        self.assertFalse(self.item("barTrackTitle").isVisible())
        self.capture("bar-compact")

    def test_calendar_navigation_and_selection(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.click("clockButton")
        desktop = self.item("desktop")
        panel = self.item("calendarPanel")
        self.assertEqual(desktop.property("openPanel"), "calendar")
        self.assertTrue(self.item("clockButton").property("checked"))
        self.assertEqual(self.item("calendarMonth").property("text"), "September 2026")
        self.assertTrue(self.item("calendarDay20260918").property("checked"))
        self.click("calendarNext")
        self.assertEqual(self.item("calendarMonth").property("text"), "October 2026")
        self.click("calendarPrevious")
        self.click("calendarDay20260930")
        self.assertTrue(self.item("calendarDay20260930").property("checked"))
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(self.item("calendarMonth").property("text"), "October 2026")
        self.assertTrue(self.item("calendarDay20261001").property("checked"))
        panel.setProperty("year", 2024)
        panel.setProperty("month", 1)
        QTest.qWait(30)
        self.click("calendarDay20240229")
        self.assertIn("29 February 2024", self.item("calendarSelectedDate").property("text"))
        self.click("calendarNext")
        self.assertTrue(self.item("calendarDay20240329").property("checked"))
        panel.setProperty("month", 11)
        QTest.qWait(30)
        self.click("calendarDay20241231")
        self.click("calendarNext")
        self.assertTrue(self.item("calendarDay20250131").property("checked"))
        self.click("calendarNext")
        self.assertTrue(self.item("calendarDay20250228").property("checked"))
        self.click("calendarToday")
        self.assertTrue(self.item("calendarDay20260918").property("checked"))
        self.capture("calendar-panel")
        for width in (640, 1920, 5120):
            desktop.setWidth(width)
            QTest.qWait(30)
            drawer = self.item("calendarDrawer")
            self.assertGreaterEqual(drawer.x(), 0)
            self.assertLessEqual(drawer.x() + drawer.width(), desktop.width())
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(desktop.property("openPanel"), "")
        self.assertTrue(self.item("clockButton").hasActiveFocus())
        desktop.setWidth(1920)
        self.click("clockButton")
        self.click("clockButton")
        self.assertEqual(desktop.property("openPanel"), "")
        self.click("clockButton")
        self.click("controlsButton")
        self.assertEqual(desktop.property("openPanel"), "controls")
        self.assertFalse(self.item("calendarDrawer").property("opened"))

    def test_gpu_history_and_partial_telemetry(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.click("barGpu0")
        panel = self.item("gpuPanelSurface")
        self.engine.globalObject().setProperty("gpuPanel", self.engine.newQObject(panel))
        result = self.engine.evaluate('''
            gpuPanel.gpu = {id:"test",name:"NVIDIA GeForce RTX 5090",utilization:null,
                usedGiB:4,totalGiB:8,memoryType:null,driver:"615.71.09",pciAddress:"00000000:01:00.0",
                coreClock:"1207 MHz",fanSpeed:0,powerLimit:320};
            gpuPanel.metrics = [
                {key:"testusage",title:"Test / Utilization",unit:"%",value:null,maximum:100},
                {key:"testvram",title:"Test / VRAM",unit:" MiB",value:4096,maximum:8192},
                {key:"testtemp",title:"Test / Temperature",unit:" C",value:54,maximum:110},
                {key:"testpower",title:"Test / Power",unit:" W",value:80,maximum:320}
            ];
            var gpuHistory = {};
            gpuPanel.metrics.forEach(metric => gpuHistory[metric.key] = Array.from({length:60}, (_,index) => index === 20 ? null : metric.maximum / 2));
            gpuPanel.history = gpuHistory;
            gpuPanel.processes = Array.from({length:7}, (_,index) => ({gpu:"test",pid:index+1,name:"/opt/compute/long-running-model-worker-with-an-unbroken-name",memoryMiB:(index+1)*1024})).concat([
                {gpu:"other",pid:99,name:"other-gpu-worker",memoryMiB:32768},
                {gpu:"test",pid:8,name:"unknown-memory",memoryMiB:null}
            ]);
            gpuPanel.processes = gpuPanel.processes.map(entry => entry.pid === 7 ? Object.assign({},entry,{name:"/usr/lib/electron42/electron --type=gpu-process --user-data-dir=/home/test/config"}) : entry);
        ''')
        self.assertFalse(result.isError(), result.toString())
        self.assertFalse(self.item("gpuDetailsUtilization").property("available"))
        self.assertTrue(self.item("gpuDetailsVram").property("available"))
        self.assertEqual(self.item("gpuDetailsMemory").property("text"), "4.0 / 8 GiB")
        details = panel.property("details").toVariant()
        self.assertNotIn("Memory type", [entry["label"] for entry in details])
        self.assertIn({"label": "Fan", "value": "0%"}, details)
        self.assertIsNone(self.window.findChild(QObject, "gpuDetailsToggle"))
        self.assertTrue(self.item("gpuDeviceDetails").isVisible())
        self.assertEqual([entry["pid"] for entry in panel.property("topProcesses").toVariant()], [7, 6, 5, 4, 3])
        self.assertEqual(len(panel.property("processes").toVariant()), 9)
        self.assertEqual(self.item("gpuProcessMemory0").property("text"), "7.0 GiB")
        self.assertEqual(self.item("gpuProcessName0").property("text"), "electron")
        self.assertIsNone(self.window.findChild(QObject, "gpuHistorytestusage"))
        self.assertIsNone(self.window.findChild(QObject, "gpuHistorytestvram"))
        colors = []
        for key in ("temp", "power"):
            graph = self.item("gpuHistorytest" + key)
            self.engine.globalObject().setProperty("gpuGraph", self.engine.newQObject(graph))
            colors.append(self.engine.evaluate("String(gpuGraph.lineColor(0))").toString())
            series = graph.property("series")[0]
            self.assertIsNone(series["samples"][20])
            self.assertTrue(graph.property("current"))
        self.assertEqual(len(set(colors)), 2)
        for width in (320, 414, 768):
            self.studio.setProperty("customWidth", width)
            QTest.qWait(50)
            pending = [panel]
            while pending:
                child = pending.pop()
                pending.extend(child.childItems())
                if child.isVisible() and child.inherits("QQuickText"):
                    self.assertLessEqual(child.property("contentWidth"), child.width() + 1, child.property("text"))
                    self.assertLessEqual(child.property("contentHeight"), child.height() + 1, child.property("text"))
            self.capture("gpu-history-" + str(width))
            processes = self.item("gpuProcessList")
            info = self.item("gpuDeviceDetails")
            gap = info.mapToItem(panel, QPointF(0, 0)).y() - processes.mapToItem(panel, QPointF(0, processes.height())).y()
            self.assertGreaterEqual(gap, 28)
            self.assertEqual(self.item("gpuInfoHeading").property("text"), "GPU info")
            self.assertEqual(self.item("gpuProcessHeading").property("text"), "Compute processes")
            content = self.item("gpuDetailsScroll").property("contentItem")
            content.setProperty("contentY", max(0, content.property("contentHeight") - content.height()))
            QTest.qWait(30)
            self.capture("gpu-sections-" + str(width))
            content.setProperty("contentY", 0)
        panel.setProperty("telemetryAvailable", False)
        self.assertEqual(panel.property("topProcesses").toVariant(), [])
        self.assertEqual(self.item("gpuProcessEmpty").property("text"), "Telemetry unavailable")
        for key in ("temp", "power"):
            self.assertFalse(self.item("gpuHistorytest" + key).property("current"))
        self.engine.evaluate("gpuPanel.gpu = Object.assign({}, gpuPanel.gpu, {utilization:42,usedGiB:NaN,totalGiB:NaN}); gpuPanel.telemetryAvailable = true;")
        self.assertTrue(self.item("gpuDetailsUtilization").property("available"))
        self.assertFalse(self.item("gpuDetailsVram").property("available"))
        self.assertEqual(self.item("gpuDetailsMemory").property("text"), "Unavailable")
        self.engine.evaluate('gpuPanel.gpu = Object.assign({}, gpuPanel.gpu, {id:"other"});')
        self.assertEqual([entry["pid"] for entry in panel.property("topProcesses").toVariant()], [99])
        self.engine.evaluate('gpuPanel.gpu = Object.assign({}, gpuPanel.gpu, {id:"empty"});')
        self.assertEqual(panel.property("topProcesses").toVariant(), [])
        self.assertEqual(self.item("gpuProcessEmpty").property("text"), "No compute processes reported")

    def test_gpu_inspector_and_compact_controls(self):
        self.fixtures.setProperty("reducedMotion", True)
        desktop = self.item("desktop")
        for index, name, memory, utilization in ((0, "RTX 5090", "24.8 / 32 GiB", 0.76),
                                                 (1, "RTX 3080", "1.8 / 10 GiB", 0.03)):
            self.click("barGpu" + str(index))
            self.assertEqual(desktop.property("openPanel"), "gpu")
            self.assertFalse(self.item("aiDrawer").property("opened"))
            self.assertEqual(self.item("gpuDetailsName").property("text"), name)
            self.assertEqual(self.item("gpuDetailsMemory").property("text"), memory)
            self.assertAlmostEqual(self.item("gpuDetailsUtilization").property("boundedValue"), utilization)
            self.assertTrue(self.item("barGpu" + str(index)).property("checked"))
            self.assertFalse(self.item("barGpu" + str(1 - index)).property("checked"))
            self.capture("gpu-details-" + str(index))
        self.fixtures.setProperty("telemetryAvailable", False)
        self.assertEqual(self.item("gpuDetailsUsage").property("text"), "Unavailable")
        self.assertFalse(self.item("gpuDetailsUtilization").property("available"))
        self.assertEqual(self.item("gpuDetailsVram").property("filledSegments"), 0)
        self.click("barGpu1")
        self.assertEqual(desktop.property("openPanel"), "")
        self.assertTrue(self.item("barGpu1").hasActiveFocus())
        self.click("barGpu0")
        self.click("aiButton")
        self.assertEqual(desktop.property("openPanel"), "ai")
        self.assertFalse(self.item("gpuDrawer").property("opened"))
        self.assertTrue(self.item("aiButton").property("checked"))
        self.click("barGpu0")
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(desktop.property("openPanel"), "")
        self.assertTrue(self.item("barGpu0").hasActiveFocus())
        self.click("controlsButton")
        drawer = self.item("controlDrawer")
        self.assertEqual(drawer.width(), 620)
        self.assertLess(drawer.height(), 620)
        self.assertTrue(self.item("controlsButton").property("checked"))
        self.capture("compact-quick-controls")
        desktop.setWidth(640)
        QTest.qWait(30)
        self.assertGreaterEqual(drawer.x(), 0)
        self.assertLessEqual(drawer.x() + drawer.width(), desktop.width())
        self.home_action("homeColorsTab")
        self.click("controlThemeButter")
        self.click("aiButton")
        self.assertEqual(desktop.property("openPanel"), "ai")

    def test_dropdown_content_sizing(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.click("aiButton")
        picker = self.item("modelPicker")
        self.assertLess(picker.width(), picker.parentItem().width())
        self.assertAlmostEqual(picker.width(), picker.implicitWidth())
        initial_width = picker.width()
        self.click("modelPicker")
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        QTest.keyClick(self.window, Qt.Key.Key_Return)
        self.assertEqual(picker.property("currentIndex"), 1)
        self.assertAlmostEqual(picker.width(), initial_width)
        picker.setProperty("model", ["Short", "A long model name " * 12])
        QTest.qWait(30)
        self.assertAlmostEqual(picker.width(), 320)
        self.click("modelPicker")
        self.capture("compact-model-dropdown")
        QTest.keyClick(self.window, Qt.Key.Key_Escape)
        self.assertEqual(self.item("desktop").property("openPanel"), "ai")
        self.open_settings()
        self.click("profilesTab")
        for width in (760, 660):
            self.settings_window.setWidth(width)
            QTest.qWait(30)
            for name in ("profileSelect", "profileWallpaper"):
                dropdown = self.item(name)
                self.assertAlmostEqual(dropdown.width(), dropdown.implicitWidth())
                self.assertGreaterEqual(dropdown.width(), 120)
                self.assertLessEqual(dropdown.width(), 320)
                self.assertLess(dropdown.width(), dropdown.parentItem().width() / 2)
        self.capture("compact-settings-dropdowns", self.settings_window)

    def test_explicit_controls_and_theme_switching(self):
        self.fixtures.setProperty("reducedMotion", True)
        desktop = self.item("desktop")
        profiles = self.window.findChild(QObject, "profileSettings")
        self.click("clockButton")
        self.assertEqual(desktop.property("openPanel"), "calendar")
        self.click("closeCalendar")
        self.assertEqual(self.item("aiButton").property("iconName"), "bot")
        self.assertEqual(self.item("homeSettings").property("iconName"), "settings")
        self.assertEqual(self.item("controlsButton").property("iconName"), "house")
        self.open_settings()
        self.click("profilesTab")
        self.click("sourceWallpaper")
        self.settings_window.close()
        self.window.requestActivate()
        self.home_action("homeColorsTab")
        self.assertEqual(desktop.property("openPanel"), "controls")
        drawer = self.item("controlDrawer")
        geometry = (drawer.width(), drawer.height())
        self.home_action("homeColorsTab")
        for palette in ("Chalk", "Phosphor", "Ice", "Butter", "Rose"):
            self.click("controlTheme" + palette)
            current = profiles.property("currentProfile").toVariant()
            self.assertEqual(current["palette"], palette)
            self.assertEqual(current["source"], "Saved")
            self.assertTrue(self.item("controlTheme" + palette).property("checked"))
            expected = QColor(profiles.property("palettes").toVariant()[palette]["ink"])
            actual = self.item("barLeft").property("color")
            self.assertEqual(actual.name(), expected.name())
            self.assertEqual((drawer.width(), drawer.height()), geometry)
        self.capture("control-theme-switcher")
        self.click("closeControls")
        self.assertTrue(self.item("controlsButton").hasActiveFocus())
        QTest.keyClick(self.window, Qt.Key.Key_Space)
        self.assertEqual(desktop.property("openPanel"), "controls")
        self.click("homeProfilesTab")
        self.item("profileSelect", self.item("homeProfilesPage")).forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        self.confirm_profile()
        self.home_action("homeColorsTab")
        self.assertTrue(self.item("controlThemeChalk").property("checked"))
        self.click("homeProfilesTab")
        self.item("profileSelect", self.item("homeProfilesPage")).forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Up)
        self.confirm_profile()
        self.home_action("homeColorsTab")
        self.assertTrue(self.item("controlThemeRose").property("checked"))
        profiles.save()
        second = QQmlApplicationEngine()
        second.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        second_window = second.rootObjects()[0]
        try:
            saved = second_window.findChild(QObject, "profileSettings")
            self.assertEqual(saved.property("currentProfile").toVariant()["palette"], "Rose")
        finally:
            second_window.close()
            second.deleteLater()

    def test_profile_switch_only_confirms_ai_interruptions(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("activeRequests", 0)
        self.home_action("homeProfilesTab")
        selector = self.item("profileSelect", self.item("homeProfilesPage"))
        selector.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        QTest.qWait(450)
        self.assertEqual(self.fixtures.property("profile"), "Gaming")
        self.assertEqual(self.fixtures.property("loadedModelIndex"), -1)
        self.assertFalse(any(dialog.property("visible") for dialog in self.window.findChildren(QObject, "profileSwitchDialog")))
        self.fixtures.setProperty("loadedModelIndex", 0)
        self.fixtures.setProperty("aiStatus", "Running")
        self.fixtures.setProperty("activeRequests", 2)
        selector.forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Up)
        self.assertEqual(self.fixtures.property("profile"), "Work")
        self.assertEqual(self.fixtures.property("activeRequests"), 2)
        self.assertFalse(any(dialog.property("visible") for dialog in self.window.findChildren(QObject, "profileSwitchDialog")))
        QTest.keyClick(self.window, Qt.Key.Key_Down)
        QTest.qWait(180)
        self.assertEqual(self.fixtures.property("profile"), "Work")
        self.assertTrue(self.item("profileApplyWait", self.window.contentItem()).isVisible())
        QTest.keyClick(self.window, Qt.Key.Key_Escape)

    def test_home_quick_tile_geometry(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.home_action("homeTab")
        desktop = self.item("desktop")
        desktop.setProperty("x", 20.35)
        desktop.setProperty("y", 70.35)
        grid = self.item("homeQuickTiles")
        scroll = grid.parentItem()
        while not scroll.inherits("QQuickScrollView"):
            scroll = scroll.parentItem()
        flickable = scroll.property("contentItem")
        keys = ("wifiEnabled", "bluetoothEnabled", "caffeineEnabled", "nightLightEnabled", "dndEnabled", "powerSaverEnabled")
        tiles = [self.item(key + "Switch") for key in keys]
        for width in (320, 375, 414, 768):
            self.studio.setProperty("customWidth", width)
            for scale in (0.28, 0.5, 0.75, 1.0):
                desktop.setProperty("scale", scale)
                QTest.qWait(30)
                size = (tiles[0].width(), tiles[0].height())
                flickable.setProperty("contentY", max(0, flickable.property("contentHeight") - flickable.height()))
                for checked in (False, True):
                    with self.subTest(width=width, scale=scale, checked=checked):
                        for key, tile in zip(keys, tiles):
                            self.fixtures.setProperty(key, checked)
                            tile.forceActiveFocus(Qt.FocusReason.TabFocusReason)
                            QTest.qWait(10)
                            for candidate in tiles:
                                self.assertEqual((candidate.width(), candidate.height()), size, candidate.objectName())
                                self.assertEqual(candidate.height(), 64)
                                self.assertGreater(candidate.width(), 0)
                                self.assertGreaterEqual(candidate.x(), 0)
                                self.assertLessEqual(candidate.x() + candidate.width(), grid.width())
                            label = self.item(key + "SwitchLabel")
                            self.assertFalse(label.property("truncated"))
                            self.assertEqual(label.property("lineCount"), 1)
                        self.capture(f"home-quick-equal-{width}-{scale}-{checked}")

    def test_home_quick_tile_styling(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.home_action("homeTab")
        desktop = self.item("desktop")
        desktop.setProperty("x", 20.35)
        desktop.setProperty("y", 70.35)
        keys = ("wifiEnabled", "bluetoothEnabled", "caffeineEnabled", "nightLightEnabled", "dndEnabled", "powerSaverEnabled")
        for scale in (0.28, 0.5, 0.75, 1.0):
            desktop.setProperty("scale", scale)
            for key in keys:
                tile = self.item(key + "Switch")
                background = self.item(key + "SwitchBackground")
                focus = self.item(key + "SwitchFocus")
                size = (tile.width(), tile.height())
                for checked in (False, True):
                    with self.subTest(scale=scale, key=key, checked=checked):
                        self.fixtures.setProperty(key, checked)
                        self.item("closeControls").forceActiveFocus(Qt.FocusReason.MouseFocusReason)
                        tile.forceActiveFocus(Qt.FocusReason.TabFocusReason)
                        QTest.qWait(30)
                        self.assertTrue(focus.isVisible())
                        self.assertGreater(background.property("radius"), 0)
                        self.assertTrue(background.property("antialiasing"))
                        self.assertEqual((tile.width(), tile.height()), size)
                        if not checked:
                            self.assert_outline_visible(focus)
                        self.item("closeControls").forceActiveFocus(Qt.FocusReason.MouseFocusReason)
                        tile.forceActiveFocus(Qt.FocusReason.MouseFocusReason)
                        center = tile.mapToScene(QPointF(tile.width() / 2, tile.height() / 2))
                        QTest.mouseMove(self.window, center.toPoint())
                        QTest.qWait(30)
                        self.assertTrue(tile.property("hovered"))
                        self.assertFalse(focus.isVisible())
                        self.assertEqual((tile.width(), tile.height()), size)
            grid = self.item("homeQuickTiles")
            start = grid.mapToScene(QPointF(0, 0))
            end = grid.mapToScene(QPointF(grid.width(), grid.height()))
            image = self.window.grabWindow()
            ratio = image.devicePixelRatio()
            crop = image.copy(round(start.x() * ratio), round(start.y() * ratio),
                              round((end.x() - start.x()) * ratio), round((end.y() - start.y()) * ratio))
            self.assertTrue(crop.save(str(ROOT / ".artifacts" / f"quick-tiles-{scale}.png")))

    def test_home_quick_dashboard_states(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        self.home_action("homeTab")
        self.assertIsNone(self.window.findChild(QObject, "controlVolume"))
        scroll = self.item("homeProfileHeader").parentItem()
        def visual_text(root):
            pending = [root]
            texts = []
            while pending:
                child = pending.pop()
                pending.extend(child.childItems())
                if child.inherits("QQuickText"):
                    texts.append(child.property("text"))
            return texts

        while not scroll.inherits("QQuickScrollView"):
            scroll = scroll.parentItem()
        flickable = scroll.property("contentItem")
        keys = ("wifiEnabled", "bluetoothEnabled", "caffeineEnabled", "nightLightEnabled", "dndEnabled", "powerSaverEnabled")
        for width in (320, 375, 414, 768):
            self.studio.setProperty("customWidth", width)
            for available in (True, False):
                with self.subTest(width=width, available=available):
                    self.fixtures.setProperty("mediaAvailable", available)
                    self.fixtures.setProperty("outputMuted", not available)
                    flickable.setProperty("contentY", 0)
                    QTest.qWait(50)
                    header = self.item("homeProfileHeader")
                    wallpaper = self.item("homeWallpaperBackground")
                    self.assertEqual(wallpaper.size(), header.size())
                    self.assertEqual(wallpaper.position(), QPointF(0, 0))
                    self.assertAlmostEqual(header.width(), scroll.property("availableWidth"), delta=1)
                    self.assertEqual(header.height(), 72)
                    self.engine.globalObject().setProperty("homeWallpaperImage", self.engine.newQObject(wallpaper))
                    self.assertTrue(self.engine.evaluate("homeWallpaperImage.status === 1").toBool())
                    start = wallpaper.mapToScene(QPointF(0, 0))
                    end = wallpaper.mapToScene(QPointF(wallpaper.width(), 20))
                    image = self.window.grabWindow()
                    ratio = image.devicePixelRatio()
                    colors = {image.pixelColor(column, row).name()
                              for column in range(round(start.x() * ratio), round(end.x() * ratio), 2)
                              for row in range(round(start.y() * ratio), round(end.y() * ratio), 2)}
                    self.assertGreater(len(colors), 3, "Home wallpaper background is blank")
                    for name in ("controlPrevious", "controlPlayback", "controlNext", "homeMediaSeek"):
                        self.assertEqual(self.item(name).isEnabled(), available)
                    media_text = visual_text(self.item("homeMediaColumn"))
                    self.assertIn(self.fixtures.property("track") if available else "Nothing playing", media_text)
                    if not available:
                        self.assertIn("No player connected", media_text)
                    for key in keys:
                        tile = self.item(key + "Switch")
                        label = self.item(key + "SwitchLabel")
                        self.assertFalse(label.property("truncated"))
                        self.assertEqual(label.property("lineCount"), 1)
                        self.assertGreaterEqual(tile.mapToItem(scroll, QPointF(0, 0)).x(), -1)
                        self.assertLessEqual(tile.mapToItem(scroll, QPointF(tile.width(), 0)).x(), scroll.width() + 1)
                    state = "playing" if available else "unavailable"
                    self.capture(f"home-polish-{state}-{width}")
                    flickable.setProperty("contentY", max(0, flickable.property("contentHeight") - flickable.height()))
                    QTest.qWait(30)
                    for name in ("homeProfile", "homeActivities", "powerSaverEnabledSwitch"):
                        control = self.item(name)
                        self.assertGreaterEqual(control.mapToItem(scroll, QPointF(0, 0)).y(), -1)
                        self.assertLessEqual(control.mapToItem(scroll, QPointF(control.width(), control.height())).y(), scroll.height() + 1)
                    self.capture(f"home-polish-{state}-{width}-lower")

    def test_home_quick_tiles_and_sidebar(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", True)
        self.home_action("homeTab")
        for key in ("wifiEnabled", "bluetoothEnabled", "caffeineEnabled", "nightLightEnabled", "dndEnabled", "powerSaverEnabled"):
            tile = self.item(key + "Switch")
            before = self.fixtures.property(key)
            self.click(key + "Switch")
            self.assertEqual(self.fixtures.property(key), not before)
            self.assertEqual(tile.property("checked"), not before)
            tile.forceActiveFocus()
            QTest.keyClick(self.window, Qt.Key.Key_Space)
            self.assertEqual(self.fixtures.property(key), before)
        self.item("homePanel").setProperty("page", "Calendar")
        QTest.qWait(30)
        home = self.item("homePanel")
        self.assertTrue(self.item("calendarGrid", home).isVisible())
        self.assertFalse(self.item("closeCalendar", home).isVisible())
        self.assertIn("Offline", self.item("homeWeatherStatus").property("text"))
        self.click("homeSettings")
        self.item("settingsSearch", home).setProperty("text", "notifications")
        QTest.qWait(30)
        self.click("settingsResultnotifications", home)
        self.assertEqual(home.property("page"), "Settings")
        self.assertEqual(self.item("settingsSurface", home).property("section"), 6)
        self.assertEqual(self.item("desktop").property("openPanel"), "controls")
        self.click("homeTab")
        self.capture("home-tiles")

    def test_profile_switch_dialog_theme(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.home_action("homeProfilesTab")
        for window, root, name in ((self.window, self.item("homeProfilesPage"), "home"),
                                   (self.settings_window, self.settings_window.contentItem(), "settings")):
            if name == "settings":
                self.open_settings()
                self.click("profilesTab", root)
            self.item("profileSelect", root).forceActiveFocus()
            QTest.keyClick(window, Qt.Key.Key_Down)
            QTest.qWait(180)
            background = self.item("profileSwitchBackground", window.contentItem())
            details = self.item("profileSwitchDetails", window.contentItem())
            self.assertTrue(background.isVisible())
            self.assertEqual(background.property("color"), self.item("barLeft").property("color"))
            foreground = details.property("color")
            surface = background.property("color")
            self.assertGreater(abs(foreground.lightnessF() - surface.lightnessF()), 0.5)
            image = window.grabWindow()
            sample = background.mapToScene(QPointF(4, background.height() / 2))
            ratio = image.devicePixelRatio()
            self.assertEqual(image.pixelColor(round(sample.x() * ratio), round(sample.y() * ratio)).name(), surface.name())
            self.capture("profile-switch-" + name, window)
            QTest.keyClick(window, Qt.Key.Key_Escape)
            QTest.qWait(180)
            self.assertEqual(self.fixtures.property("profile"), "Work")

    def test_profiles_palette_and_persistence(self):
        self.open_settings()
        self.click("profilesTab")
        self.item("profileName").setProperty("text", "Focus")
        self.click("addProfile")
        self.assertEqual(self.fixtures.property("profile"), "Focus")
        profiles = self.window.findChild(QObject, "profileSettings")
        self.item("profileName").setProperty("text", "focus")
        self.click("addProfile")
        self.assertIn("unique", profiles.property("error"))
        self.click("paletteIce")
        self.assertEqual(profiles.property("currentProfile").toVariant()["palette"], "Ice")
        bar_height = self.item("clockButton").height()
        self.click("sourceWallpaper")
        QTest.qWait(150)
        sampled = self.item("wallpaperPalette").property("palette")
        self.assertIsNotNone(sampled)
        self.assertTrue(sampled.toVariant())
        self.assertEqual(self.item("clockButton").height(), bar_height)
        self.assertTrue(profiles.property("dirty"))
        profiles.save()
        self.assertFalse(profiles.property("dirty"))
        self.capture("profile-settings", self.settings_window)
        self.settings_window.close()
        self.window.requestActivate()
        self.cycle_profile()
        self.assertEqual(self.fixtures.property("profile"), "Work")
        self.cycle_profile()
        self.assertEqual(self.fixtures.property("profile"), "Gaming")
        self.cycle_profile()
        self.assertEqual(self.fixtures.property("profile"), "Focus")
        second = QQmlApplicationEngine()
        second.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        second_window = second.rootObjects()[0]
        try:
            saved = second_window.findChild(QObject, "profileSettings")
            self.assertEqual(saved.property("activeName"), "Focus")
            self.assertEqual(saved.property("currentProfile").toVariant()["source"], "Wallpaper")
            self.assertEqual(len(saved.property("profiles").toVariant()), 3)
        finally:
            second_window.close()
            second.deleteLater()

    def test_profiles_copy_editor_confirmation(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        profiles.update("palette", "Ice")
        profiles.save()
        profiles.setProperty("activeName", "Gaming")
        self.open_settings()
        self.click("profilesTab")
        root = self.settings_window.contentItem()
        scroll = self.item("settingsPageScroll", root).property("contentItem")

        def reveal(name):
            control = self.item(name, root)
            position = control.mapToItem(scroll, QPointF(0, 0)).y()
            maximum = max(0, scroll.property("contentHeight") - scroll.height())
            scroll.setProperty("contentY", min(maximum, max(0, scroll.property("contentY") + position - 32)))
            QTest.qWait(40)

        reveal("profilePoliciesToggle")
        self.click("profilePoliciesToggle", root)
        reveal("previewProfileCopy")
        self.click("previewProfileCopy", root)
        dialog = self.settings_window.findChild(QObject, "profileCopyDialog")
        self.assertTrue(dialog.property("visible"))
        self.assertEqual(profiles.property("currentProfile").toVariant()["palette"], "Chalk")
        self.capture("profile-copy-preview", self.settings_window)
        dialog.accept()
        QTest.qWait(200)
        self.assertEqual(profiles.property("currentProfile").toVariant()["palette"], "Ice")
        self.assertTrue(profiles.property("dirty"))
        reveal("undoProfileCopy")
        self.click("undoProfileCopy", root)
        self.assertEqual(profiles.property("currentProfile").toVariant()["palette"], "Chalk")
        reveal("profileAiAction")
        self.capture("profile-policies", self.settings_window)

    def test_profiles_safe_apply_and_rules(self):
        self.set_test_monitors()
        profiles = self.window.findChild(QObject, "profileSettings")
        self.engine.globalObject().setProperty("profiles", self.engine.newQObject(profiles))
        self.engine.globalObject().setProperty("state", self.engine.newQObject(self.fixtures))
        evaluate = self.engine.evaluate
        evaluate('state.applyProfile("Gaming", "Wait")')
        self.assertEqual(self.fixtures.property("profile"), "Work")
        self.assertEqual(self.fixtures.property("waitingProfile"), "Gaming")
        self.fixtures.setProperty("activeRequests", 0)
        self.app.processEvents()
        QTest.qWait(600)
        self.assertEqual(self.fixtures.property("profile"), "Gaming")
        self.assertEqual(self.fixtures.property("loadedModelIndex"), -1)
        self.assertTrue(self.fixtures.property("dndEnabled"))
        evaluate('state.notifications.clear()')
        evaluate('state.notify("Quiet", "Suppressed")')
        notifications = self.window.findChild(QObject, "notifications")
        self.assertEqual(notifications.property("count"), 0)
        evaluate('state.notify("Critical", "Allowed", "critical")')
        self.assertEqual(notifications.property("count"), 1)
        evaluate('profiles.setPolicy("ai", "action", "Load")')
        self.fixtures.setProperty("failNextStart", True)
        evaluate('state.applyProfile("Gaming", "Cancel")')
        QTest.qWait(400)
        self.assertIn("Partially applied", self.fixtures.property("profileSwitchStatus"))
        evaluate('profiles.setPolicy("ai", "gpu", 1)')
        evaluate('state.applyProfile("Gaming", "Cancel")')
        self.assertIn("memory budget", self.fixtures.property("profileSwitchStatus"))
        self.assertTrue(evaluate('state.windowManager.reserve("browser", "HDMI-A-1", 4, 0)').toBool())
        before = evaluate('JSON.stringify(state.windowManager.windows)').toString()
        evaluate('state.applyProfile("Work", "Keep")')
        self.assertEqual(evaluate('state.windowManager.rules.length').toInt(), 0)
        self.assertEqual(evaluate('JSON.stringify(state.windowManager.windows)').toString(), before)

    def test_profiles_drafts_copy_and_independence(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        self.engine.globalObject().setProperty("profiles", self.engine.newQObject(profiles))
        evaluate = self.engine.evaluate
        profiles.setAppearance("tileGap", 24)
        profiles.setProperty("glassEnabled", False)
        self.assertTrue(profiles.property("dirty"))
        profiles.setProperty("activeName", "Gaming")
        self.assertEqual(profiles.property("tileGap"), 12)
        self.assertTrue(profiles.property("glassEnabled"))
        self.assertTrue(evaluate('profiles.copyFrom("Work", ["tiling"])').toBool())
        self.assertEqual(profiles.property("tileGap"), 24)
        self.assertTrue(profiles.property("glassEnabled"))
        self.assertEqual(profiles.property("activeName"), "Gaming")
        profiles.undoCopy()
        self.assertEqual(profiles.property("tileGap"), 12)
        profiles.setProperty("activeName", "Work")
        self.assertEqual(profiles.property("tileGap"), 24)
        profiles.save()
        profiles.setAppearance("tileGap", 8)
        profiles.revert()
        self.assertEqual(profiles.property("tileGap"), 24)
        self.assertFalse(profiles.property("dirty"))
        self.assertTrue(evaluate('profiles.add("Focus", "Defaults")').toBool())
        self.assertEqual(profiles.property("tileGap"), 12)
        evaluate('profiles.setPolicy("notifications", "mode", "DND")')
        profiles.setProperty("activeName", "Work")
        self.assertEqual(profiles.property("currentProfile").toVariant()["notifications"]["mode"], "Normal")

    def test_side_panel_attachment_and_reveal(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        desktop = self.item("desktop")
        self.fixtures.setProperty("reducedMotion", True)
        profiles.setProperty("animationStyle", "Smooth")
        panels = (("gpu", "gpuDrawer", "gpuPanelSurface", "right"),
                  ("volume", "volumeDrawer", "volumePanelSurface", "right"),
                  ("wallpaper", "wallpaperDrawer", "wallpaperPanelSurface", "right"),
                  ("ai", "aiDrawer", "aiPanel", "right"),
                  ("power", "powerDrawer", "powerPanelSurface", "left"),
                  ("calendar", "calendarDrawer", "calendarPanel", "left"))
        for floating in (False, True):
            profiles.setProperty("floatingPanels", floating)
            for panel, name, surface_name, edge in panels:
                with self.subTest(floating=floating, panel=panel):
                    desktop.setProperty("openPanel", panel)
                    QTest.qWait(30)
                    drawer = self.item(name)
                    self.assertEqual(drawer.property("edge"), edge)
                    self.assertEqual(drawer.property("floating"), floating)
                    gap = drawer.x() if edge == "left" else desktop.width() - drawer.x() - drawer.width()
                    self.assertGreater(gap, 0) if floating else self.assertEqual(gap, 0)
                    surface = self.item(surface_name)
                    for corner in (("topLeftRadius", "bottomLeftRadius") if edge == "left" else ("topRightRadius", "bottomRightRadius")):
                        self.assertEqual(surface.property(corner), profiles.property("panelRadius") if floating else 0)
                    drawer.setProperty("progress", 0.5)
                    reveal = self.item(name + "Reveal")
                    self.assertAlmostEqual(reveal.width(), drawer.width() if floating else drawer.width() / 2)
                    self.assertAlmostEqual(reveal.height(), drawer.height())
                    drawer.setProperty("progress", 1)
                    self.capture(panel + ("-side-floating" if floating else "-side-attached"))
                    desktop.setProperty("openPanel", "")

    def test_bar_theme_state_consistency(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        desktop = self.item("desktop")
        self.fixtures.setProperty("reducedMotion", True)
        self.engine.globalObject().setProperty("themeProfiles", self.engine.newQObject(profiles))
        for palette_name in ("Chalk", "Phosphor", "Ice", "Butter", "Rose"):
            self.engine.evaluate('themeProfiles.update("palette", "' + palette_name + '")')
            palette = profiles.property("palette").toVariant()
            for group in ("barLeft", "barRight"):
                self.assertEqual(self.item(group).property("color"), QColor(palette["ink"]))
            for name in ("barGpu0", "barGpu1", "volumeButton", "aiButton", "clockButton", "controlsButton", "bottomApp_terminal"):
                button = self.item(name)
                background = button.property("background")
                QTest.mouseMove(self.window, self.item("desktop").mapToScene(QPointF(20, 600)).toPoint())
                QTest.qWait(10)
                self.assertEqual(background.property("color").alpha(), 0, name)
                point = button.mapToScene(QPointF(button.width() / 2, button.height() / 2)).toPoint()
                QTest.mouseMove(self.window, point)
                QTest.qWait(10)
                self.assertTrue(button.property("hovered"), name)
                self.assertEqual(background.property("color"), QColor(palette["hover"]), name)
                button.setProperty("down", True)
                self.assertEqual(background.property("color"), QColor(palette["paper"]), name)
                button.setProperty("down", False)
            desktop.setProperty("openPanel", "gpu")
            self.assertEqual(self.item("barGpu0").property("background").property("color"), QColor(palette["paper"]))
            self.engine.globalObject().setProperty("activeBarButton", self.engine.newQObject(self.item("barGpu0")))
            self.assertEqual(QColor(self.engine.evaluate("activeBarButton.palette.buttonText").toString()), QColor(palette["ink"]))
            desktop.setProperty("openPanel", "")
        self.engine.evaluate('themeProfiles.update("palette", "Chalk")')
        self.click("barGpu1")
        self.capture("bar-monochrome-active")
        desktop.setProperty("openPanel", "")
        self.open_settings()
        self.assertTrue(self.settings_window.isVisible())
        self.settings_window.close()
        self.assertFalse(self.settings_window.isVisible())

    def test_wallpaper_palette_live_cached_and_transparent(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        sampler = self.item("wallpaperPalette")
        self.engine.globalObject().setProperty("themeProfiles", self.engine.newQObject(profiles))
        self.engine.evaluate('themeProfiles.update("source", "Wallpaper")')

        def sample(path):
            sampler.setProperty("source", QUrl.fromLocalFile(str(path)))
            for attempt in range(100):
                QTest.qWait(30)
                palette = sampler.property("palette")
                if palette is not None and palette.toVariant():
                    return palette.toVariant()
            self.fail("Wallpaper palette did not update")

        with tempfile.TemporaryDirectory() as directory:
            paths = {name: Path(directory) / (name + ".png") for name in ("red", "blue", "transparent")}
            for name in ("red", "blue"):
                image = QImage(32, 32, QImage.Format.Format_ARGB32)
                image.fill(QColor(name))
                self.assertTrue(image.save(str(paths[name])))
            image.fill(QColor("transparent"))
            for column in range(16):
                for row in range(32):
                    image.setPixelColor(column, row, QColor("red"))
            self.assertTrue(image.save(str(paths["transparent"])))
            red = sample(paths["red"])
            blue = sample(paths["blue"])
            self.assertGreater(QColor(red["accent"]).red(), QColor(red["accent"]).blue())
            self.assertGreater(QColor(blue["accent"]).blue(), QColor(blue["accent"]).red())
            again = sample(paths["red"])
            self.assertEqual(QColor(again["accent"]), QColor(red["accent"]))
            transparent = sample(paths["transparent"])
            self.assertEqual(QColor(transparent["accent"]), QColor(red["accent"]))
            self.assertEqual(self.item("barCenter").property("fillColor"), QColor(transparent["ink"]))
            self.assertEqual(self.item("barLeft").property("color"), self.item("barRight").property("color"))
            from material_color_utilities import Hct, get_contrast_ratio
            for palette in (red, blue, transparent):
                self.assertGreaterEqual(get_contrast_ratio(palette["paper"], palette["ink"]), 7)
                self.assertGreaterEqual(get_contrast_ratio(palette["muted"], palette["hover"]), 4.5)
                self.assertTrue(all(Hct(value).chroma < 20 for value in palette.values()))
            neutral_path = Path(directory) / "neutral.png"
            image.fill(QColor("#808080"))
            self.assertTrue(image.save(str(neutral_path)))
            neutral = sample(neutral_path)
            for token in neutral.values():
                channels = QColor(token).getRgb()[:3]
                self.assertLessEqual(max(channels) - min(channels), 2)
            sampler.setProperty("source", QUrl.fromLocalFile(str(paths["blue"])))
            sampler.setProperty("source", QUrl.fromLocalFile(str(paths["red"])))
            QTest.qWait(500)
            self.assertEqual(sampler.property("palette").toVariant(), red)
            sampler.setProperty("source", QUrl.fromLocalFile(str(Path(directory) / "missing.png")))
            for attempt in range(100):
                QTest.qWait(30)
                if sampler.property("status") == "Wallpaper colors unavailable":
                    break
            self.assertEqual(sampler.property("status"), "Wallpaper colors unavailable")
            self.assertIsNone(sampler.property("palette"))
            self.assertEqual(self.item("barCenter").property("fillColor"), QColor("#1c1c1c"))
            self.engine.evaluate('themeProfiles.update("source", "Saved")')
            self.assertEqual(self.item("barCenter").property("fillColor"), QColor("#1c1c1c"))

    def test_default_profiles_are_monochrome(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        for name in ("Work", "Gaming"):
            profiles.setProperty("activeName", name)
            self.assertEqual(profiles.property("currentProfile").toVariant()["palette"], "Chalk")
            palette = profiles.property("palette").toVariant()
            self.assertEqual(palette["paper"], "#efefeb")
            self.assertEqual(palette["accent"], palette["paper"])
            self.assertEqual(palette["ink"], "#1c1c1c")
            for token in ("ink", "muted", "line", "hover", "stage"):
                color = QColor(palette[token])
                self.assertEqual(color.red(), color.green(), token)
                self.assertEqual(color.green(), color.blue(), token)

    def test_reference_palettes_and_panel_modes(self):
        self.open_settings()
        self.click("profilesTab")
        profiles = self.window.findChild(QObject, "profileSettings")
        for palette in ("Butter", "Rose"):
            self.click("palette" + palette)
            self.assertEqual(profiles.property("currentProfile").toVariant()["palette"], palette)
            self.settings_window.close()
            self.window.requestActivate()
            self.click("controlsButton")
            QTest.qWait(280)
            for floating in (False, True):
                profiles.setProperty("floatingPanels", floating)
                QTest.qWait(30)
                drawer = self.item("controlDrawer")
                expected_top = self.item("barCenter").height() + (12 if floating else 0)
                self.assertEqual(drawer.y(), expected_top)
                self.capture(palette.lower() + ("-floating" if floating else "-attached"))
            self.click("aiButton")
            QTest.qWait(280)
            ai_drawer = self.item("aiDrawer")
            self.assertEqual(ai_drawer.x() + ai_drawer.width(), self.item("desktop").width() - 16)
            self.capture(palette.lower() + "-ai-floating")
            profiles.setProperty("floatingPanels", False)
            self.assertEqual(ai_drawer.x() + ai_drawer.width(), self.item("desktop").width())
            self.capture(palette.lower() + "-ai-attached")
            self.item("desktop").setProperty("openPanel", "")
            self.open_settings()
        self.capture("reference-palette-settings", self.settings_window)

    def test_notifications_dismiss_expire_and_dnd(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.fixtures.setProperty("dndEnabled", False)
        self.engine.globalObject().setProperty("state", self.engine.newQObject(self.fixtures))
        activities = self.window.findChild(QObject, "activities")
        notifications = self.window.findChild(QObject, "notifications")
        self.assertEqual(notifications.property("count"), 0)
        selected = activities.property("selectedId")
        self.engine.evaluate('state.notify("New message", "A notification in the notch")')
        QTest.qWait(50)
        self.assertIsNone(self.window.findChild(QObject, "toastStack"))
        self.assertTrue(self.item("notchNotificationPage").isVisible())
        self.assertFalse(self.item("notchMusicPage").isVisible())
        self.assertFalse(self.item("notchActivitySelector").isVisible())
        self.assertEqual(self.item("notchNotificationTitle").property("text"), "New message")
        self.assertEqual(self.item("notchNotificationMessage").property("text"), "A notification in the notch")
        self.capture("preview-notch-notification")
        QTest.qWait(3000)
        self.assertTrue(self.item("notchNotificationPage").isVisible())
        QTest.qWait(1150)
        self.assertEqual(notifications.property("count"), 0)
        self.assertEqual(activities.property("selectedId"), selected)
        self.assertTrue(self.item("notchMusicPage").isVisible())
        self.engine.evaluate('state.notify("First", "One"); state.notify("Second", "Two")')
        QTest.qWait(50)
        self.assertEqual(self.item("notchNotificationTitle").property("text"), "Second")
        self.click("dismissNotchNotification")
        self.assertEqual(self.item("notchNotificationTitle").property("text"), "First")
        QTest.qWait(3000)
        self.assertEqual(notifications.property("count"), 1)
        QTest.qWait(1150)
        self.assertEqual(notifications.property("count"), 0)
        self.fixtures.setProperty("playing", False)
        self.engine.evaluate('state.notify("Only notification", "No ongoing activity")')
        QTest.qWait(50)
        self.assertTrue(self.item("barCenter").isVisible())
        self.click("dismissNotchNotification")
        self.assertFalse(self.item("barCenter").isVisible())
        self.fixtures.setProperty("dndEnabled", True)
        next_id = self.fixtures.property("nextNotificationId")
        self.engine.evaluate('state.notify("Quiet", "Suppressed")')
        self.assertEqual(self.fixtures.property("nextNotificationId"), next_id)
        self.fixtures.setProperty("allowUrgent", True)
        self.engine.evaluate('state.notify("Urgent", "Allowed", "critical")')
        QTest.qWait(50)
        self.assertTrue(self.item("notchNotificationPage").isVisible())
        self.click("dismissNotchNotification")
        self.assertEqual(notifications.property("count"), 0)
        self.fixtures.setProperty("dndEnabled", False)
        for width in (320, 640, 800, 1024, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            self.engine.evaluate('state.notify("Preview notification", "Message received")')
            QTest.qWait(50)
            notch = self.item("barCenter")
            self.assertTrue(notch.isVisible())
            self.assertGreaterEqual(notch.x(), 0)
            self.assertLessEqual(notch.x() + notch.width(), width)
            for name in ("barLeft", "barRight"):
                group = self.item(name)
                self.assertTrue(notch.y() >= group.y() + group.height()
                                or notch.x() >= group.x() + group.width()
                                or notch.x() + notch.width() <= group.x())
            self.assertTrue(self.item("barCpu").isVisible())
            self.assertTrue(self.item("barGpu0").isVisible())
            self.assertTrue(self.item("barGpu1").isVisible())
            if width == 320:
                self.capture("preview-notch-notification-compact")
            self.click("dismissNotchNotification")
        self.engine.evaluate('for (let index = 0; index < 5; index++) state.notify("Burst", String(index))')
        self.assertEqual(notifications.property("count"), 3)
        for message in ("4", "3", "2"):
            self.assertEqual(self.item("notchNotificationMessage").property("text"), message)
            self.click("dismissNotchNotification")
        self.assertEqual(notifications.property("count"), 0)
        self.engine.evaluate('state.notifications.clear()')
        self.assertFalse(self.item("barCenter").isVisible())


    def test_settings_polish_responsive_search_and_drafts(self):
        self.fixtures.setProperty("reducedMotion", True)
        profiles = self.window.findChild(QObject, "profileSettings")
        self.engine.globalObject().setProperty("polishProfiles", self.engine.newQObject(profiles))
        long_name = "Workstation with long profile"
        self.assertTrue(self.engine.evaluate(f'polishProfiles.add("{long_name}", "Defaults")').toBool())

        def check_bounds(surface):
            pending = [surface]
            while pending:
                control = pending.pop()
                pending.extend(control.childItems())
                if not control.isVisible() or not control.inherits("QQuickControl"):
                    continue
                start = control.mapToItem(surface, QPointF(0, 0))
                end = control.mapToItem(surface, QPointF(control.width(), 0))
                self.assertGreaterEqual(start.x(), -1, control.objectName())
                self.assertLessEqual(end.x(), surface.width() + 1, control.objectName())
            footer = self.item("settingsProfileActions", surface)
            self.assertLessEqual(footer.mapToItem(surface, QPointF(0, footer.height())).y(), surface.height())
            self.assertFalse(self.item("settingsProfileStatus", surface).property("truncated"))
            for name in ("settingsPageScroll", "settingsSearchResults"):
                body = self.item(name, surface)
                if body.isVisible():
                    bottom = body.mapToItem(surface, QPointF(0, body.height())).y()
                    self.assertLess(bottom, footer.mapToItem(surface, QPointF(0, 0)).y())

        for host in ("home", "standalone"):
            if host == "home":
                self.home_action("homeSettings")
                surface = self.item("settingsSurface", self.item("homePanel"))
                window = self.window
            else:
                self.open_settings()
                self.settings_window.setMinimumWidth(0)
                self.settings_window.setHeight(640)
                surface = self.item("settingsSurface", self.settings_window.contentItem())
                window = self.settings_window
            search = self.item("settingsSearch", surface)
            clear = self.item("clearSettingsSearch", surface)
            status = self.item("settingsProfileStatus", surface)
            for width in (320, 375, 414, 768):
                with self.subTest(host=host, width=width):
                    if host == "home":
                        self.studio.setProperty("customWidth", width)
                    else:
                        window.setWidth(width)
                    surface.setProperty("section", 0)
                    QTest.qWait(40)
                    category = self.item("homeSettingsCategory" if host == "home" else "settingsCategory", surface)
                    self.assertEqual(category.isVisible(), host == "home" or width < 600)
                    if category.isVisible():
                        category.setProperty("currentIndex", 2)
                        category.activated.emit(2)
                        self.assertEqual(surface.property("section"), 2)
                    for section in range(9):
                        surface.setProperty("section", section)
                        QTest.qWait(20)
                        check_bounds(surface)
                    surface.setProperty("section", 0)
                    row = self.item("panelOpacitySetting", surface).parentItem().parentItem()
                    row.setProperty("label", "Panel opacity for the active workstation profile")
                    QTest.qWait(30)
                    search_width = search.width()
                    self.assertFalse(clear.isEnabled())
                    profiles.setAppearance("panelRadius", 17)
                    QTest.qWait(30)
                    self.assertEqual(status.property("text"), "Unsaved")
                    self.assertEqual(self.item("settingsProfileName", surface).property("text"), long_name)
                    self.assertTrue(self.item("saveProfile", surface).isEnabled())
                    check_bounds(surface)
                    self.capture(f"settings-polish-{host}-{width}-unsaved", window)
                    search.setProperty("text", "personalize")
                    search.forceActiveFocus()
                    QTest.qWait(30)
                    self.assertEqual(self.item("settingsSearchResults", surface).property("count"), 4)
                    self.assertAlmostEqual(search.width(), search_width)
                    self.assertTrue(clear.isEnabled())
                    check_bounds(surface)
                    self.capture(f"settings-polish-{host}-{width}-matches", window)
                    search.setProperty("text", "no-such-setting")
                    QTest.qWait(30)
                    self.assertTrue(self.item("settingsSearchEmpty", surface).isVisible())
                    check_bounds(surface)
                    self.capture(f"settings-polish-{host}-{width}-empty", window)
                    self.click("saveProfile", surface)
                    self.assertFalse(profiles.property("dirty"))
                    self.assertEqual(status.property("text"), "Saved")
                    self.assertFalse(self.item("saveProfile", surface).isEnabled())
                    self.assertFalse(self.item("revertProfile", surface).isEnabled())
                    search.setProperty("text", "hotkeys")
                    search.forceActiveFocus()
                    QTest.keyClick(window, Qt.Key.Key_Return)
                    self.assertEqual(surface.property("section"), 4)
                    self.assertEqual(search.property("text"), "")
                    profiles.setAppearance("panelRadius", 9)
                    QTest.qWait(20)
                    self.click("revertProfile", surface)
                    self.assertEqual(profiles.property("panelRadius"), 17)
                    self.assertEqual(status.property("text"), "Saved")
                    check_bounds(surface)
                    self.capture(f"settings-polish-{host}-{width}-saved", window)
                    profiles.setAppearance("panelRadius", 9)
                    profiles.save()
                    row.setProperty("label", "Panel opacity")

    def test_settings_categories_and_collapsible_sections(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.open_settings()
        self.assertEqual(self.item("settingsPageTitle").property("text"), "Appearance")
        glass_section = self.item("glassSection")
        original_height = glass_section.height()
        self.click("glassSectionToggle")
        self.assertFalse(glass_section.property("expanded"))
        self.assertFalse(self.item("glassSwitch").isVisible())
        self.assertLess(glass_section.height(), original_height)
        self.item("glassSectionToggle").forceActiveFocus()
        QTest.keyClick(self.settings_window, Qt.Key.Key_Space)
        QTest.qWait(30)
        self.assertTrue(glass_section.property("expanded"))
        self.assertTrue(self.item("glassSwitch").isVisible())
        self.assertEqual(self.item("panelOpacitySetting").property("value"), 84)
        self.capture("settings-appearance", self.settings_window)
        categories = ("appearance", "profiles", "desktop", "motion", "shortcuts", "audio", "notifications", "ai", "system")
        for width, height in ((920, 760), (660, 540)):
            self.settings_window.setWidth(width)
            self.settings_window.setHeight(height)
            QTest.qWait(50)
            previous_y = -1
            for index, category in enumerate(categories):
                with self.subTest(width=width, category=category):
                    self.click(category + "Tab")
                    tab = self.item(category + "Tab")
                    self.assertTrue(tab.property("checked"))
                    self.assertEqual(self.item("settingsSurface").property("section"), index)
                    position = tab.mapToScene(QPointF(0, 0))
                    self.assertGreater(position.y(), previous_y)
                    self.assertLessEqual(position.y() + tab.height(), height)
                    previous_y = position.y()
                    scroll = self.item("settingsPageScroll")
                    self.assertLessEqual(scroll.property("contentWidth"), scroll.width())
                    self.capture("settings-" + category + "-" + str(width), self.settings_window)
        self.click("appearanceTab")
        self.click("cornersSectionToggle")
        self.click("desktopTab")
        self.click("appearanceTab")
        self.assertFalse(self.item("cornersSection").property("expanded"))
        self.click("shortcutsTab")
        scroll = self.item("settingsPageScroll")
        content = scroll.property("contentItem")
        target = self.item("bind_ai").mapToItem(content, QPointF(0, 0)).y()
        content.setProperty("contentY", max(0, min(target, content.property("contentHeight") - scroll.height())))
        self.click("bind_ai")
        self.assertEqual(self.item("shortcutSettings").property("recording"), "ai")
        self.click("audioTab")
        self.assertEqual(self.item("shortcutSettings").property("recording"), "")

    def test_settings_audio_notifications_and_motion(self):
        self.open_settings()
        self.click("audioTab")
        self.item("settingsVolume").forceActiveFocus()
        QTest.keyClick(self.settings_window, Qt.Key.Key_Right)
        self.assertEqual(self.fixtures.property("volume"), 65)
        self.click("settingsOutputMute")
        self.assertTrue(self.fixtures.property("outputMuted"))
        self.assertEqual(self.item("volumeButton").property("text"), "Muted")
        self.click("notificationsTab")
        self.click("settingsDnd")
        self.assertTrue(self.fixtures.property("dndEnabled"))
        self.click("motionTab")
        self.click("reducedMotionSwitch")
        self.assertTrue(self.fixtures.property("reducedMotion"))
        self.assertFalse(self.item("animationSmooth").isEnabled())
        self.click("reducedMotionSwitch")
        self.click("animationSmooth")
        self.assertTrue(self.item("animationSmooth").property("checked"))
        self.click("desktopTab")
        self.click("panelsFloating")
        self.assertTrue(self.window.findChild(QObject, "profileSettings").property("floatingPanels"))

    def test_production_window_appearance_controls(self):
        self.open_settings()
        view = self.item("settingsSurface")
        self.engine.globalObject().setProperty("nativeAppearance", self.engine.newQObject(view))
        result = self.engine.evaluate('''
            nativeAppearance.service = Object.assign({}, nativeAppearance.service, {
                desktopControlsEnabled:true, wallpaperColorsAvailable:true, preferences:{notificationsEnabled:true}
            });
            nativeAppearance.production = true;
        ''')
        self.assertFalse(result.isError(), result.toString())
        QTest.qWait(30)
        profiles = self.window.findChild(QObject, "profileSettings")
        profiles.setProperty("glassEnabled", True)
        profiles.save()
        original = {name: profiles.property(name) for name in ("windowOpacity", "windowRadius")}
        for name in ("windowOpacity", "windowRadius"):
            control = self.item(name + "Setting")
            self.assertTrue(control.isEnabled(), name)
            slider = self.item(name + "SettingSlider")
            slider.forceActiveFocus()
            before = profiles.property(name)
            QTest.keyClick(self.settings_window, Qt.Key.Key_Right)
            self.assertEqual(profiles.property(name), before + 1)
        profiles.revert()
        for name, value in original.items():
            self.assertEqual(profiles.property(name), value)
            self.assertEqual(self.item(name + "Setting").property("value"), value)
        profiles.setProperty("glassEnabled", False)
        self.assertFalse(self.item("windowOpacitySetting").isEnabled())
        self.assertTrue(self.item("windowRadiusSetting").isEnabled())
        profiles.setProperty("glassEnabled", True)
        self.engine.evaluate('nativeAppearance.service = Object.assign({}, nativeAppearance.service, {desktopControlsEnabled:false});')
        QTest.qWait(30)
        self.assertFalse(self.item("windowOpacitySetting").isEnabled())
        self.assertFalse(self.item("windowRadiusSetting").isEnabled())
        self.assertTrue(self.item("panelOpacitySetting").isEnabled())

    def test_settings_drag_values_and_window_layout(self):
        self.fixtures.setProperty("reducedMotion", True)
        self.click("tilingButton")
        self.open_settings()
        profiles = self.window.findChild(QObject, "profileSettings")

        def reveal(name):
            item = self.item(name)
            scroll = self.item("settingsPageScroll")
            content = scroll.property("contentItem")
            top = item.mapToItem(scroll, QPointF(0, 0)).y()
            content.setProperty("contentY", max(0, min(content.property("contentHeight") - scroll.height(), content.property("contentY") + top - 30)))
            QTest.qWait(30)
            return item

        def drag(name):
            slider = reveal(name + "SettingSlider")
            start = slider.mapToScene(QPointF(slider.width() * 0.25, slider.height() / 2)).toPoint()
            finish = slider.mapToScene(QPointF(slider.width() * 0.75, slider.height() / 2)).toPoint()
            QTest.mousePress(self.settings_window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, start)
            before = profiles.property(name)
            QTest.mouseMove(self.settings_window, finish, 30)
            QTest.mouseRelease(self.settings_window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, finish)
            QTest.qWait(30)
            self.assertGreater(profiles.property(name), before, name)
            self.assertEqual(self.item(name + "SettingNumber").property("value"), profiles.property(name))

        for category, names in (("appearance", ("panelOpacity", "windowOpacity", "panelRadius", "barRadius", "windowRadius")),
                                ("desktop", ("mainPaneRatio", "windowBorderWidth", "tileGap", "outerGap")),
                                ("motion", ("animationDuration",))):
            self.click(category + "Tab")
            if category == "motion":
                self.click("reducedMotionSwitch")
            for name in names:
                drag(name)
        self.click("desktopTab")
        field = reveal("tileGapSettingInput")
        field.forceActiveFocus()
        QTest.keyClick(self.settings_window, Qt.Key.Key_A, Qt.KeyboardModifier.ControlModifier)
        QTest.keyClick(self.settings_window, Qt.Key.Key_2)
        QTest.keyClick(self.settings_window, Qt.Key.Key_4)
        QTest.keyClick(self.settings_window, Qt.Key.Key_Return)
        self.assertEqual(profiles.property("tileGap"), 24)
        reveal("settingsTilingLayout").forceActiveFocus()
        QTest.keyClick(self.settings_window, Qt.Key.Key_End)
        QTest.keyClick(self.settings_window, Qt.Key.Key_Return)
        self.assertEqual(profiles.property("tilingLayout"), "Centered")
        scene = self.item("tilingScene")
        self.assertEqual(scene.property("layoutMode"), "Centered")
        first = self.item("tile0")
        area = scene.width() - 2 * profiles.property("outerGap") - 2 * profiles.property("tileGap")
        self.assertAlmostEqual(first.width(), area * profiles.property("mainPaneRatio") / 100)
        self.assertEqual(scene.property("windowBorderWidth"), profiles.property("windowBorderWidth"))
        self.settings_window.setWidth(660)
        self.settings_window.setHeight(540)
        for category, names in (("appearance", ("panelOpacity", "windowRadius")), ("desktop", ("mainPaneRatio", "tileGap")), ("motion", ("animationDuration",))):
            self.click(category + "Tab")
            for name in names:
                control = reveal(name + "Setting")
                right = control.mapToScene(QPointF(control.width(), 0)).x()
                self.assertLessEqual(right, self.settings_window.width() - 24)
                self.assertGreaterEqual(self.item(name + "SettingSlider").width(), 40)
            self.capture("settings-drag-" + category + "-660", self.settings_window)
        profiles.save()
        second = QQmlApplicationEngine()
        second.warnings.connect(lambda messages: self.warnings.extend(str(message) for message in messages))
        second.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        second_window = second.rootObjects()[0]
        try:
            restored = second_window.findChild(QObject, "profileSettings")
            for key in ("tilingLayout", "mainPaneRatio", "windowBorderWidth", "tileGap"):
                self.assertEqual(restored.property(key), profiles.property(key))
        finally:
            second_window.close()
            second.deleteLater()

    def test_glass_off_panel_corners(self):
        profiles = self.window.findChild(QObject, "profileSettings")
        self.fixtures.setProperty("reducedMotion", True)
        profiles.setProperty("panelRadius", 24)
        panel = self.item("homePanel")
        panel.setProperty("page", "Settings")
        for floating in (False, True):
            profiles.setProperty("floatingPanels", floating)
            self.item("desktop").setProperty("openPanel", "")
            QTest.qWait(100)
            backdrop = self.window.grabWindow()
            self.click("controlsButton")
            for glass in (True, False, True, False):
                profiles.setProperty("glassEnabled", glass)
                QTest.qWait(100)
                rendered = self.window.grabWindow()
                self.assertEqual(panel.property("radius"), 24)
                self.assertTrue(panel.property("antialiasing"))
                for corner in (QPointF(panel.width() - 2, 2),
                               QPointF(panel.width() - 2, panel.height() - 2)):
                    point = panel.mapToScene(corner).toPoint()
                    self.assertEqual(rendered.pixelColor(point), backdrop.pixelColor(point))
                if not glass:
                    point = panel.mapToScene(QPointF(panel.width() - 8, panel.height() / 2)).toPoint()
                    self.assertEqual(rendered.pixelColor(point), panel.property("color"))
            self.capture("glass-off-corners-" + ("floating" if floating else "attached"))

    def test_gap_and_glass_preferences(self):
        self.click("tilingButton")
        self.open_settings()
        self.click("appearanceTab")
        profiles = self.window.findChild(QObject, "profileSettings")
        for name, key, expected in (("tileGap", Qt.Key.Key_Up, 13), ("outerGap", Qt.Key.Key_Up, 13),
                                    ("panelOpacity", Qt.Key.Key_Down, 83), ("windowOpacity", Qt.Key.Key_Down, 91)):
            self.click("desktopTab" if name in ("tileGap", "outerGap") else "appearanceTab")
            self.item(name + "Setting").forceActiveFocus()
            QTest.keyClick(self.settings_window, key)
            self.assertEqual(profiles.property(name), expected)
        QTest.qWait(50)
        first = self.item("tile0")
        second_tile = self.item("tile1")
        self.assertAlmostEqual(first.x(), 13)
        self.assertAlmostEqual(second_tile.x() - first.x() - first.width(), 13)
        self.assertAlmostEqual(first.property("color").alphaF(), 0.91, places=3)
        self.assertEqual(first.opacity(), 1)
        self.click("glassSwitch")
        self.assertEqual(first.property("color").alphaF(), 1)
        self.assertEqual(profiles.property("windowOpacity"), 91)
        self.click("glassSwitch")
        self.assertAlmostEqual(first.property("color").alphaF(), 0.91, places=3)
        self.capture("gap-glass-settings", self.settings_window)
        self.settings_window.close()
        self.window.requestActivate()
        self.capture("tiling-glass")
        self.item("tilingGap").forceActiveFocus()
        QTest.keyClick(self.window, Qt.Key.Key_Right)
        self.assertEqual(profiles.property("tileGap"), 15)
        self.assertEqual(self.item("tileGapSetting").property("value"), 15)
        profiles.save()
        second = QQmlApplicationEngine()
        second.load(QUrl.fromLocalFile(str(ROOT / "preview" / "QtHost.qml")))
        second_window = second.rootObjects()[0]
        try:
            saved = second_window.findChild(QObject, "profileSettings")
            for key, value in (("tileGap", 15), ("outerGap", 13), ("panelOpacity", 83), ("windowOpacity", 91)):
                self.assertEqual(saved.property(key), value)
        finally:
            second_window.close()
            second.deleteLater()

    def test_tiling_geometry_with_configured_gaps(self):
        self.click("tilingButton")
        scene = self.item("tilingScene")
        profiles = self.window.findChild(QObject, "profileSettings")
        for width in (640, 1920, 5120):
            self.studio.setProperty("customWidth", width)
            for mode in ("Split", "Columns", "Centered"):
                scene.setProperty("layoutMode", mode)
                for gap in (0, 12, 32):
                    profiles.setProperty("tileGap", gap)
                    profiles.setProperty("outerGap", gap)
                    QTest.qWait(10)
                    rectangles = []
                    for index in range(3):
                        tile = self.item("tile" + str(index))
                        self.assertGreater(tile.width(), 0)
                        self.assertGreater(tile.height(), 0)
                        self.assertGreaterEqual(tile.x(), gap)
                        self.assertGreaterEqual(tile.y(), gap)
                        self.assertLessEqual(tile.x() + tile.width(), scene.width() - gap + 0.01)
                        self.assertLessEqual(tile.y() + tile.height(), scene.height() - gap + 0.01)
                        rectangles.append((tile.x(), tile.y(), tile.width(), tile.height()))
                    for first_index, first_rect in enumerate(rectangles):
                        for second_rect in rectangles[first_index + 1:]:
                            self.assertTrue(first_rect[0] + first_rect[2] <= second_rect[0] + 0.01 or
                                            second_rect[0] + second_rect[2] <= first_rect[0] + 0.01 or
                                            first_rect[1] + first_rect[3] <= second_rect[1] + 0.01 or
                                            second_rect[1] + second_rect[3] <= first_rect[1] + 0.01)
                self.capture("tiling-" + mode.lower() + "-" + str(width))


if __name__ == "__main__":
    unittest.main()