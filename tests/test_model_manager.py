import asyncio
import json
import os
from pathlib import Path
import shutil
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("quickshell"), "Quickshell is required for the socket integration test")
class ModelManagerConnectionTests(unittest.IsolatedAsyncioTestCase):
    async def test_late_daemon_reply_and_reconnection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runtime = root / "runtime"
            runtime.mkdir(mode=0o700)
            socket_directory = runtime / "model-manager"
            socket_directory.mkdir(mode=0o700)
            shutil.copyfile(ROOT / "host/Services/ModelManager.qml", root / "ModelManager.qml")
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
ShellRoot {
    id: test
    property bool sent: false
    property bool replied: false
    property bool lost: false
    ModelManager {
        id: manager
        profileName: "Work"
        profileDefaults: ({Work: "vllm/other"})
        onFreshChanged: {
            if (test.replied && !fresh) test.lost = true;
        }
    }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            if (manager.fresh && !test.sent) {
                if (!manager.external || manager.canStop || manager.loadedModelName !== "test-model" || manager.defaultModelIndex !== 0) {
                    console.error("BAD_INITIAL_STATE"); Qt.quit(); return;
                }
                test.sent = true;
                manager.profileDefaults = ({});
                manager.request("configure", manager.defaultModelIndex, false);
            }
            if (manager.requestError === "Rejected by test" && !test.replied) {
                test.replied = true;
                console.log("REQUEST_OK");
            }
            if (test.lost && manager.fresh) {
                if (manager.busy || manager.canStop || manager.models.length !== 2 || manager.defaultModelIndex !== 1) {
                    console.error("BAD_RECONNECT_STATE"); Qt.quit(); return;
                }
                console.log("RECONNECTED_OK"); Qt.quit();
            }
        }
    }
}''')
            environment = os.environ | {"XDG_RUNTIME_DIR": str(runtime), "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                                        "QT_QPA_PLATFORMTHEME": "generic", "QT_STYLE_OVERRIDE": "Fusion", "QT_QUICK_CONTROLS_STYLE": "Basic"}
            process = await asyncio.create_subprocess_exec("quickshell", "-p", str(root / "shell.qml"), "--no-color",
                                                           env=environment, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
            messages = []
            writers = []
            requests = []

            async def until(marker):
                while True:
                    line = await asyncio.wait_for(process.stdout.readline(), 8)
                    self.assertTrue(line, "Quickshell exited early: " + "".join(messages))
                    text = line.decode()
                    messages.append(text)
                    if marker in text:
                        return

            async def client(reader, writer):
                writers.append(writer)
                state = {"version": 1, "type": "state", "observed_at": time.time(), "busy": False, "error": "", "operation": None,
                         "opencode": {"state": "unchanged"}, "default_preset_id": "vllm/test",
                         "presets": [{"id": "vllm/other", "name": "Other", "provider": "vllm", "model": "other-model"},
                                     {"id": "vllm/test", "name": "Test", "provider": "vllm", "model": "test-model"}],
                         "runtimes": [{"provider": "vllm", "preset_id": "vllm/test", "container_id": "external-id", "owned": False,
                                       "online": True, "running": True, "models": ["test-model"], "state": "ready", "error": "",
                                       "tokens_per_second": None, "running_requests": 0}]}
                try:
                    writer.write((json.dumps(state) + "\n").encode())
                    await writer.drain()
                    while line := await reader.readline():
                        message = json.loads(line)
                        requests.append(message)
                        writer.write((json.dumps({"version": 1, "type": "reply", "id": message["id"], "ok": False, "error": "Rejected by test"}) + "\n").encode())
                        await writer.drain()
                finally:
                    writer.close()

            server = None
            try:
                await until("ServerNotFoundError")
                server = await asyncio.start_unix_server(client, socket_directory / "control.sock")
                await until("REQUEST_OK")
                self.assertEqual(requests[0]["action"], "configure")
                self.assertEqual(requests[0]["preset_id"], "vllm/test")
                writers[0].close()
                await writers[0].wait_closed()
                await until("RECONNECTED_OK")
                self.assertEqual(await asyncio.wait_for(process.wait(), 5), 0)
                self.assertFalse(any("TypeError" in message or "ReferenceError" in message or "Unable to assign" in message for message in messages), messages)
            finally:
                if server:
                    server.close()
                    await server.wait_closed()
                for writer in writers:
                    writer.close()
                if process.returncode is None:
                    process.terminate()
                    await asyncio.wait_for(process.wait(), 5)