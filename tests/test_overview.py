import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "overview.sh"
OVERVIEW = ROOT / "third_party" / "quickshell-overview" / "shell.qml"


class OverviewCommandTests(unittest.TestCase):
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