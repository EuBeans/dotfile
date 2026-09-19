import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("clipboard", ROOT / "host/clipboard.py")
clipboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clipboard)


class ClipboardTests(unittest.TestCase):
    def test_sensitive_clipboard_is_not_persisted(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(ROOT / "host/clipboard.py"), "store"],
                                    input=b"synthetic-sensitive-value", capture_output=True,
                                    env=dict(os.environ, XDG_STATE_HOME=directory, CLIPBOARD_STATE="sensitive"), check=True)
            self.assertEqual(result.stdout, b"")
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_real_cliphist_roundtrip_in_isolated_database(self):
        binary = Path.home() / ".local/libexec/cliphist"
        if not binary.exists():
            self.skipTest("User-local cliphist is not installed")
        with tempfile.TemporaryDirectory() as directory:
            history = clipboard.ClipboardHistory(directory, str(binary))
            history.run("store", b"synthetic clipboard integration test")
            entries = history.entries()
            self.assertEqual(len(entries), 1)
            self.assertEqual(history.decode(entries[0]["entryId"]), b"synthetic clipboard integration test")
            history.pin(entries[0]["entryId"])
            history.run("wipe")
            self.assertEqual(history.decode(-1), b"synthetic clipboard integration test")
            history.remove(-1)
            self.assertEqual(history.entries(), [])

    def test_pins_survive_clear_and_unpin_restores_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            history = clipboard.ClipboardHistory(directory)
            entries = {1: b"first", 2: b"second"}

            def execute(action, payload=None):
                if action == "list":
                    return b"\n".join(str(identifier).encode() + b"\t" + value for identifier, value in entries.items())
                if action == "decode":
                    return entries[int(payload)]
                if action == "wipe":
                    entries.clear()
                if action == "store":
                    entries[1] = payload
                if action == "delete":
                    del entries[int(payload)]
                return b""

            history.run = execute
            history.pin(2)
            history.pin(2)
            self.assertEqual(len(history.pins()), 1)
            self.assertEqual(history.decode(-1), b"second")
            history.run("wipe")
            self.assertEqual(len(history.entries()), 1)
            self.assertTrue(history.entries()[0]["pinned"])
            self.assertNotIn("file", history.entries()[0])
            self.assertEqual(history.directory.stat().st_mode & 0o777, 0o700)
            history.remove(-1, unpin=True)
            self.assertEqual(history.pins(), [])
            self.assertEqual(entries, {1: b"second"})
            history.remove(1)
            self.assertEqual(history.entries(), [])


if __name__ == "__main__":
    unittest.main()