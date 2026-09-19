import importlib.util
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location("host_shortcuts", Path(__file__).resolve().parents[1] / "host/shortcuts.py")
shortcuts = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(shortcuts)


class ShortcutTests(unittest.TestCase):
    def test_existing_bindings_gain_minimize_presets(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "shortcuts.lua"
            previous = {key:value for key,value in shortcuts.DEFAULTS.items() if key not in ("minimize", "restore")}
            previous["network"] = "Ctrl+Alt+B"
            path.write_text(shortcuts.PREFIX + json.dumps(previous) + "\n")
            migrated = shortcuts.load(path)
            self.assertEqual(migrated["network"], "Ctrl+Alt+B")
            self.assertEqual(migrated["minimize"], "Meta+M")
            self.assertEqual(migrated["restore"], "Shift+Meta+M")

    def test_sequences_and_rendering(self):
        self.assertEqual(shortcuts.parse_sequence("Ctrl+Alt+N"), (12, "N", 0, "CONTROL + ALT + N"))
        self.assertEqual(shortcuts.parse_sequence("Meta+1"), (64, "1", 10, "SUPER + code:10"))
        for invalid in (None, "N", "Shift+N", "Meta+N;exec", "Alt+Ctrl+N", "Meta+F13"):
            with self.subTest(sequence=invalid), self.assertRaises(ValueError):
                shortcuts.parse_sequence(invalid)
        rendered = shortcuts.render(shortcuts.DEFAULTS)
        self.assertIn('binding:unbind()', rendered)
        self.assertNotIn('hl.unbind(', rendered)
        self.assertIn('description="Quickshell:network"', rendered)

    def test_conflicts(self):
        active = [{"modmask": 64, "key": "Q", "description": "Close window"},
                  {"modmask": 64, "keycode": 10},
                  {"modmask": 12, "key": "n", "description": "Quickshell:network"}]
        with self.assertRaises(ValueError):
            shortcuts.check_conflict("Meta+Q", active, "network")
        with self.assertRaises(ValueError):
            shortcuts.check_conflict("Meta+1", active, "network")
        with self.assertRaises(ValueError):
            shortcuts.check_conflict("Ctrl+Alt+N", active, "summary")
        shortcuts.check_conflict("Ctrl+Alt+N", active, "network")
        shortcuts.check_conflict("", active, "network")

    def test_save_clear_and_failed_update_rollback(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "shortcuts.lua"
            shortcuts.write_atomic(path, shortcuts.render(shortcuts.DEFAULTS))
            with patch.object(shortcuts, "hyprctl", side_effect=["[]", "ok"]):
                saved = shortcuts.save(path, "network", "Ctrl+Alt+B")
            self.assertEqual(saved["network"], "Ctrl+Alt+B")
            self.assertEqual(shortcuts.load(path), saved)
            previous = path.read_text()
            with patch.object(shortcuts, "hyprctl", side_effect=["[]", ValueError("rejected"), "ok"]):
                with self.assertRaises(ValueError):
                    shortcuts.save(path, "network", "Ctrl+Alt+F")
            self.assertEqual(path.read_text(), previous)
            with patch.object(shortcuts, "hyprctl", side_effect=["[]", "ok"]):
                shortcuts.save(path, "network", "")
            self.assertNotIn('description="Quickshell:network"', path.read_text())
            with patch.object(shortcuts, "hyprctl") as native:
                with self.assertRaises(ValueError):
                    shortcuts.save(path, "network", shortcuts.DEFAULTS["settings"])
                native.assert_not_called()


class LockLauncherTests(unittest.TestCase):
    def test_custom_locker_fallback_and_duplicate_guard(self):
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            log = directory / "calls.jsonl"
            stub = f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
mode = os.environ.get("QUICKSHELL_LOCK_VALIDATE_ONLY")
with open(os.environ["LOCK_TEST_LOG"], "a") as output:
    output.write(json.dumps({"name":name,"mode":mode,"arguments":sys.argv[1:]}) + "\\n")
sys.exit(int(os.environ.get("LOCK_TEST_CHECK_EXIT" if mode == "1" else "LOCK_TEST_RUNTIME_EXIT", "0")) if name == "quickshell" else 0)
'''
            for name in ("quickshell", "hyprlock"):
                program = directory / name
                program.write_text(stub)
                program.chmod(0o755)
            environment = dict(os.environ, PATH=str(directory) + os.pathsep + os.defpath,
                               XDG_RUNTIME_DIR=folder, LOCK_TEST_LOG=str(log), QUICKSHELL_LOCK_VALIDATE_ONLY="visual")
            for check_exit, runtime_exit, expected in (("0", "0", ["quickshell", "quickshell"]),
                                                        ("1", "0", ["quickshell", "hyprlock"]),
                                                        ("0", "1", ["quickshell", "quickshell", "hyprlock"])):
                with self.subTest(check_exit=check_exit, runtime_exit=runtime_exit):
                    log.unlink(missing_ok=True)
                    subprocess.run(["bash", str(root / "tools/lock.sh")], env=dict(environment, LOCK_TEST_CHECK_EXIT=check_exit,
                                   LOCK_TEST_RUNTIME_EXIT=runtime_exit), check=True, timeout=5)
                    calls = [json.loads(line) for line in log.read_text().splitlines()]
                    self.assertEqual([call["name"] for call in calls], expected)
                    self.assertEqual(calls[0]["mode"], "1")
                    if check_exit == "0":
                        self.assertIsNone(calls[1]["mode"])
            log.unlink()
            with (directory / "custom-shell-lock.lock").open("a") as held:
                fcntl.flock(held, fcntl.LOCK_EX)
                subprocess.run(["bash", str(root / "tools/lock.sh")], env=environment, check=True, timeout=5)
                self.assertFalse(log.exists())


if __name__ == "__main__":
    unittest.main()