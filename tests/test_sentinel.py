import importlib.util
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("sentinel", ROOT / "tools/sentinel.py")
sentinel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sentinel)
WATCH_SPEC = importlib.util.spec_from_file_location("sentinel_watch", ROOT / "config/kitty/sentinel_watch.py")
watcher = importlib.util.module_from_spec(WATCH_SPEC)
WATCH_SPEC.loader.exec_module(watcher)


class SentinelTests(unittest.TestCase):
    def test_names_and_paths_cannot_inject_session_commands(self):
        for name in ("../bad", "project\nlaunch rm", "", "a" * 49):
            with self.subTest(name=name), self.assertRaises(ValueError):
                sentinel.project_name(name)
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "project with spaces"
            target.mkdir()
            self.assertEqual(sentinel.project_directory(target), target)
            with self.assertRaises(ValueError):
                sentinel.project_directory(target / "missing")

    def test_layouts_and_missing_dependency(self):
        with patch.object(sentinel.shutil, "which", side_effect=lambda name: "/usr/bin/" + name):
            project = sentinel.session_text("dotfile")
            watch = sentinel.session_text("dotfile", watch=True)
        self.assertEqual(project.count("new_tab"), 3)
        self.assertEqual(watch.count("new_tab"), 1)
        self.assertIn("layout tall:bias=70", watch)
        self.assertIn("btop --config ", watch)
        self.assertIn("config/btop/sentinel-watch.conf", watch)
        self.assertIn("config/btop/sentinel-watch.conf", project)
        self.assertIn("focus_tab 0", project)
        self.assertIn("journalctl --user --follow --lines=40", project)
        with patch.object(sentinel.shutil, "which", return_value=None), self.assertRaises(ValueError):
            sentinel.session_text("dotfile")

    def test_watch_top_fallback_has_no_btop_options(self):
        with patch.object(sentinel.shutil, "which", side_effect=lambda name: None if name == "btop" else "/usr/bin/" + name):
            watch = sentinel.session_text("dotfile", watch=True)
        self.assertIn("launch /usr/bin/top\n", watch)
        self.assertNotIn("--config", watch)

    def test_registration_and_desktop_entries(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {
            "XDG_CONFIG_HOME": directory + "/config", "XDG_DATA_HOME": directory + "/data"
        }):
            self.assertEqual(sentinel.main(["project", "add", "dotfile", directory]), 0)
            self.assertEqual(sentinel.load_projects(), {"dotfile": directory})
            applications = Path(directory) / "data/applications"
            self.assertEqual(len(list(applications.glob("sentinel-*.desktop"))), 3)
            self.assertIn('"project" "open" "dotfile"', (applications / "sentinel-project-dotfile.desktop").read_text())
            self.assertEqual(sentinel.main(["project", "open", "missing"]), 1)

    def test_launch_preserves_directory_as_single_argument(self):
        with tempfile.TemporaryDirectory(prefix="sentinel project ") as directory, patch.object(sentinel.subprocess, "run") as run:
            with patch.object(sentinel.shutil, "which", side_effect=lambda name: "/usr/bin/" + name):
                sentinel.launch(directory, "test")
            self.assertEqual(run.call_args.args[0], ["kitty", "--detach", "--directory", directory, "--session", "-"])
            self.assertNotIn("shell", run.call_args.kwargs)

    def test_full_summary_has_unrestricted_keys(self):
        with patch.object(sentinel.os, "execvp") as run:
            sentinel.summary(full=True)
        command = run.call_args.args[1]
        self.assertEqual(command[command.index("--key-width") + 1], "0")
        self.assertEqual(command[command.index("--logo") + 1], "none")

    def test_palette_validation_and_generation(self):
        palette = dict(paper="#efefeb", ink="#1c1c1c", muted="#aaaaaa", line="#525252", hover="#353535", accent="#efefeb")
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, XDG_CONFIG_HOME=directory):
            fastfetch = Path(directory) / "fastfetch/config.jsonc"
            sentinel.atomic_write(fastfetch, json.dumps({"modules": [{"type": "custom", "format": "SENTINEL"}, "cpu"]}))
            sentinel.sync_palette(palette)
            generated = Path(directory) / "kitty/themes/sentinel-shared.conf"
            self.assertIn("color7 #efefeb\n", generated.read_text())
            self.assertEqual(json.loads(fastfetch.read_text())["display"]["color"]["output"], palette["paper"])
            modified = generated.stat().st_mtime_ns
            sentinel.sync_palette(palette)
            self.assertEqual(generated.stat().st_mtime_ns, modified)
            with self.assertRaises(ValueError):
                sentinel.sync_palette(dict(palette, paper="bad\ninclude evil.conf"))
            self.assertEqual(generated.stat().st_mtime_ns, modified)

    def test_completion_redacts_arguments_and_times_commands(self):
        self.assertEqual(watcher.completion("TOKEN=secret curl --header secret", 0, 25), ("Sentinel | Complete", "curl | 25s"))
        self.assertEqual(watcher.completion("make build", 2, 125), ("Sentinel | Failed (exit 2)", "make | 2m 05s"))

    def test_notification_threshold_visibility_and_cleanup(self):
        watcher.started.clear()
        watcher.notices.clear()
        manager = MagicMock()
        manager.is_notification_allowed.return_value = True
        manager.notify_with_command.return_value = "notice"
        boss = SimpleNamespace(notification_manager=manager)
        window = SimpleNamespace(id=7)
        module = SimpleNamespace(OnlyWhen=SimpleNamespace(invisible="invisible"))
        with patch.dict("sys.modules", {"kitty.notifications": module}):
            watcher.on_cmd_startstop(boss, window, dict(is_start=True, time=10))
            watcher.on_cmd_startstop(boss, window, dict(is_start=False, time=11))
            manager.notify_with_command.assert_not_called()
            watcher.on_cmd_startstop(boss, window, dict(is_start=True, time=20))
            watcher.on_cmd_startstop(boss, window, dict(is_start=False, time=45, cmdline="make", exit_status=0))
            manager.notify_with_command.assert_called_once()
            watcher.on_focus_change(boss, window, {"focused": True})
            manager.close_notification.assert_called_with("notice")
            manager.is_notification_allowed.return_value = False
            watcher.on_cmd_startstop(boss, window, dict(is_start=True, time=50))
            watcher.on_cmd_startstop(boss, window, dict(is_start=False, time=80))
            self.assertEqual(manager.notify_with_command.call_count, 1)
            watcher.on_close(boss, window, {})
            self.assertFalse(watcher.started)
            self.assertFalse(watcher.notices)


if __name__ == "__main__":
    unittest.main()