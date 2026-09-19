import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


class ClipboardHistory:
    def __init__(self, directory=None, binary=None):
        self.directory = Path(directory or Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell-host/clipboard")
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.directory.chmod(0o700)
        self.binary = binary or shutil.which("cliphist") or str(Path.home() / ".local/libexec/cliphist")
        self.database = self.directory / "history.db"

    def run(self, action, payload=None):
        return subprocess.run([self.binary, "-db-path", str(self.database), "-max-items", "500", action],
                              input=payload, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              check=True, timeout=10).stdout

    def pins(self):
        filename = self.directory / "pins.json"
        return json.loads(filename.read_text()) if filename.exists() else []

    def write_pins(self, pins):
        descriptor, filename = tempfile.mkstemp(dir=self.directory)
        with os.fdopen(descriptor, "w") as stream:
            json.dump(pins, stream)
        os.replace(filename, self.directory / "pins.json")

    def entries(self):
        entries = []
        for line in self.run("list").decode("utf-8", errors="replace").splitlines()[:100]:
            identifier, separator, text = line.partition("\t")
            if separator and identifier.isdigit():
                entries.append({"entryId": int(identifier), "text": text, "kind": "image" if "[[ binary data" in text else "text", "image": "", "pinned": False})
        return [{key: value for key, value in pin.items() if key != "file"} for pin in self.pins()] + entries

    def decode(self, identifier):
        if identifier < 0:
            pin = next(entry for entry in self.pins() if entry["entryId"] == identifier)
            return (self.directory / pin["file"]).read_bytes()
        return self.run("decode", str(identifier).encode())

    def pin(self, identifier):
        if identifier < 0:
            return
        pins = self.pins()
        payload = self.decode(identifier)
        digest = hashlib.sha256(payload).hexdigest()
        if any(entry["file"] == digest for entry in pins):
            return
        entry = next(entry for entry in self.entries() if entry["entryId"] == identifier)
        entry.update(entryId=min([0] + [pin["entryId"] for pin in pins]) - 1, pinned=True, file=digest)
        descriptor = os.open(self.directory / digest, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
        self.write_pins(pins + [entry])

    def remove(self, identifier, unpin=False):
        if identifier >= 0:
            self.run("delete", str(identifier).encode())
            return
        pins = self.pins()
        pin = next(entry for entry in pins if entry["entryId"] == identifier)
        if unpin:
            self.run("store", self.decode(identifier))
        self.write_pins([entry for entry in pins if entry["entryId"] != identifier])
        (self.directory / pin["file"]).unlink(missing_ok=True)

    def copy(self, identifier):
        payload = self.decode(identifier)
        mime = subprocess.run(["file", "--brief", "--mime-type", "-"], input=payload,
                              capture_output=True, check=True, timeout=5).stdout.decode().strip()
        if mime.startswith("text/"):
            mime = "text/plain;charset=utf-8"
        with tempfile.TemporaryFile() as stream:
            stream.write(payload)
            stream.seek(0)
            subprocess.run(["wl-copy", "--type", mime], stdin=stream, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, check=True, timeout=10)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("list", "store", "copy", "pin", "unpin", "delete", "clear"))
    parser.add_argument("identifier", type=int, nargs="?")
    arguments = parser.parse_args()
    try:
        if arguments.action == "store" and os.environ.get("CLIPBOARD_STATE") in ("sensitive", "nil", "clear"):
            return 0
        history = ClipboardHistory()
        with (history.directory / "lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if arguments.action == "store":
                payload = sys.stdin.buffer.read(20 * 1024 * 1024 + 1)
                if payload and len(payload) <= 20 * 1024 * 1024:
                    history.run("store", payload)
                return 0
            if arguments.action in ("copy", "pin", "delete", "unpin") and arguments.identifier is None:
                raise ValueError("Missing entry identifier")
            if arguments.action == "copy":
                history.copy(arguments.identifier)
            elif arguments.action == "pin":
                history.pin(arguments.identifier)
            elif arguments.action in ("delete", "unpin"):
                history.remove(arguments.identifier, arguments.action == "unpin")
            elif arguments.action == "clear":
                history.run("wipe")
            print(json.dumps({"success": True, "entries": history.entries()}))
        return 0
    except (OSError, subprocess.SubprocessError, ValueError, StopIteration):
        print(json.dumps({"success": False, "error": "Clipboard provider unavailable or entry expired"}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())