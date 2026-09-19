import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
PREFIX = "-- quickshell-shortcuts: "
SHELL = "quickshell ipc -p " + shlex.quote(str(ROOT / "shell.qml")) + " call host "
ACTIONS = [
    ("launcher", "App launcher", "Meta+Space", SHELL + "launcher"),
    ("workspaceOverview", "Workspace overview", "Meta+Tab", SHELL + "overview"),
    ("controls", "Home", "Meta+X", SHELL + "home Home"),
    ("settings", "Settings", "Meta+Z", SHELL + "home Settings"),
    ("lock", "Lock screen", "Meta+L", "bash " + shlex.quote(str(ROOT / "tools/lock.sh"))),
    ("power", "Session menu", "Alt+Meta+C", SHELL + "home Session"),
    ("capture", "Screenshot manager", "Shift+Meta+S", "quickshell -c hyprquickshot -n"),
    ("wallpaper", "Wallpaper", "Shift+Meta+W", SHELL + "side Wallpaper '' -1"),
    ("notifications", "Notifications", "Meta+A", SHELL + "home Notifications"),
    ("network", "Network", "Ctrl+Alt+N", SHELL + "home Network"),
    ("displays", "Displays", "Ctrl+Alt+D", SHELL + "home Displays"),
    ("volume", "Audio", "Ctrl+Alt+V", SHELL + "home Audio"),
    ("summary", "System", "Ctrl+Alt+S", SHELL + "home System"),
    ("ai", "Local AI", "Ctrl+Alt+A", SHELL + "side AI '' -1"),
    ("minimize", "Minimize window", "Meta+M", SHELL + "minimize"),
    ("restore", "Restore minimized window", "Shift+Meta+M", SHELL + "restore"),
]
DEFAULTS = {key: sequence for key, label, sequence, command in ACTIONS}
MODIFIERS = {"Ctrl": (4, "CONTROL"), "Alt": (8, "ALT"), "Shift": (1, "SHIFT"), "Meta": (64, "SUPER")}


def parse_sequence(sequence):
    if not isinstance(sequence, str) or not re.fullmatch(
        r"(?:Ctrl\+)?(?:Alt\+)?(?:Shift\+)?(?:Meta\+)?(?:[A-Z0-9]|F(?:[1-9]|1[0-2])|Space|Tab|Print)", sequence
    ):
        raise ValueError("Use Ctrl, Alt or Super with a letter, number, Space or Tab, or F1-F12 / Print.")
    parts = sequence.split("+")
    key = parts[-1]
    modifiers = parts[:-1]
    if not any(modifier in modifiers for modifier in ("Ctrl", "Alt", "Meta")) and not re.fullmatch(r"F\d+|Print", sequence):
        raise ValueError("A modifier is required for this key.")
    keycode = (19 if key == "0" else 9 + int(key)) if key.isdigit() else 0
    mask = sum(MODIFIERS[modifier][0] for modifier in modifiers)
    native = " + ".join([MODIFIERS[modifier][1] for modifier in modifiers] + [f"code:{keycode}" if keycode else key])
    return mask, key, keycode, native


def validate(bindings):
    if not isinstance(bindings, dict) or set(bindings) != set(DEFAULTS):
        raise ValueError("Saved shortcut data is invalid.")
    used = set()
    for sequence in bindings.values():
        if sequence == "":
            continue
        parse_sequence(sequence)
        if sequence in used:
            raise ValueError("This shortcut is already assigned to another shell action.")
        used.add(sequence)


def check_conflict(sequence, active, own_key):
    if not sequence:
        return
    mask, key, code, native = parse_sequence(sequence)
    for binding in active:
        if binding.get("description") == "Quickshell:" + own_key:
            continue
        if binding.get("modmask") != mask and not binding.get("ignore_mods", False):
            continue
        if str(binding.get("key", "")).lower() == key.lower() or (code and binding.get("keycode") == code):
            owner = binding.get("description") or "an existing Hyprland binding"
            raise ValueError(f"{sequence} is already assigned to {owner}.")


def load(path):
    text = path.read_text()
    first = text.splitlines()[0] if text else ""
    if not first.startswith(PREFIX):
        raise ValueError("Shortcut file is not managed by this shell; it was not changed.")
    bindings = json.loads(first[len(PREFIX):])
    if isinstance(bindings, dict):
        for key in ("minimize", "restore"):
            bindings.setdefault(key, DEFAULTS[key])
    validate(bindings)
    return bindings


def render(bindings):
    validate(bindings)
    lines = [PREFIX + json.dumps(bindings, sort_keys=True),
             'if _G.quickshell_shortcuts then',
             '    for _, binding in pairs(_G.quickshell_shortcuts) do binding:unbind() end',
             'end', '_G.quickshell_shortcuts = {}']
    for key, label, default, command in ACTIONS:
        if not bindings[key]:
            continue
        native = parse_sequence(bindings[key])[3]
        lines.append(f'_G.quickshell_shortcuts[{json.dumps(key)}] = hl.bind({json.dumps(native)}, hl.dsp.exec_cmd({json.dumps(command)}), {{description={json.dumps("Quickshell:" + key)}}})')
    return "\n".join(lines) + "\n"


def write_atomic(path, content):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(content)
        os.replace(temporary, path)
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def hyprctl(*arguments):
    result = subprocess.run(["hyprctl", *arguments], text=True, capture_output=True, timeout=8, check=True)
    if arguments[0] == "repl" and re.search(r"error|failed|invalid", result.stdout + result.stderr, re.IGNORECASE):
        raise ValueError("Hyprland rejected the shortcut update: " + (result.stderr or result.stdout).strip())
    return result.stdout


def save(path, key, sequence):
    if key not in DEFAULTS:
        raise ValueError("Unknown shortcut action.")
    bindings = load(path)
    bindings[key] = sequence
    validate(bindings)
    check_conflict(sequence, json.loads(hyprctl("-j", "binds")), key)
    previous = path.read_text()
    write_atomic(path, render(bindings))
    try:
        hyprctl("repl", "dofile(" + json.dumps(str(path)) + ")")
    except (ValueError, subprocess.SubprocessError):
        write_atomic(path, previous)
        try:
            hyprctl("repl", "dofile(" + json.dumps(str(path)) + ")")
        except (ValueError, subprocess.SubprocessError):
            raise ValueError("Shortcut update failed; saved bindings restored but runtime recovery failed. Reload Hyprland.")
        raise
    return bindings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=["list", "init", "save"])
    parser.add_argument("key", nargs="?")
    parser.add_argument("sequence", nargs="?")
    args = parser.parse_args()
    directory = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "quickshell-host"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "shortcuts.lua"
    try:
        with (directory / "shortcuts.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.operation == "init" and not path.exists():
                write_atomic(path, render(DEFAULTS))
            bindings = save(path, args.key, args.sequence) if args.operation == "save" else load(path)
        print(json.dumps({"bindings": bindings, "actions": [dict(key=key, label=label, sequence=sequence) for key, label, sequence, command in ACTIONS]}))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps({"error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())