#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        output.write(text)
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def project_name(name):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,47}", name):
        raise ValueError("Project names must use 1-48 letters, numbers, underscores or hyphens")
    return name


def project_directory(value):
    directory = Path(value).expanduser().resolve()
    if not directory.is_dir() or any(ord(character) < 32 for character in str(directory)):
        raise ValueError("Project directory must exist and contain no control characters")
    return directory


def load_projects():
    path = config_home() / "sentinel/projects.json"
    projects = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(projects, dict) or any(not isinstance(value, str) for value in projects.values()):
        raise ValueError("Invalid saved projects")
    for name in projects:
        project_name(name)
    return projects


def session_text(name, watch=False):
    project_name(name)
    shell = shutil.which("fish")
    monitor = shutil.which("btop") or shutil.which("top")
    if not shell or not monitor:
        raise ValueError("Fish and either btop or top are required")
    lines = ["new_tab " + name, "layout tall:bias=70", "launch " + shell]
    if not watch:
        journal = shutil.which("journalctl")
        if not journal:
            raise ValueError("journalctl is required for the Logs tab")
        lines += ["new_tab Logs", "launch " + journal + " --user --follow --lines=40",
                  "new_tab Watch", "layout tall:bias=70", "launch " + shell]
    monitor_command = [monitor]
    if Path(monitor).name == "btop":
        monitor_command += ["--config", str(ROOT / "config/btop/sentinel-watch.conf")]
    lines += ["launch " + shlex.join(monitor_command), "focus_matching_window num:0", "focus_tab 0"]
    return "\n".join(lines) + "\n"


def launch(directory, name="Sentinel", watch=False, plain=False):
    directory = project_directory(directory)
    command = ["kitty", "--detach", "--directory", str(directory)]
    if plain:
        subprocess.run(command, check=True)
    else:
        subprocess.run(command + ["--session", "-"], input=session_text(name, watch), text=True, check=True)


def desktop_entry(name, arguments, icon):
    executable = str(ROOT / "tools/sentinel.py")
    def quote(value):
        return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`").replace("$", "\\$").replace("%", "%%") + '"'
    command = "/usr/bin/python3 " + " ".join(quote(value) for value in [executable] + arguments)
    return ("[Desktop Entry]\nType=Application\nName=" + name + "\nExec=" + command +
            "\nIcon=" + str(icon) + "\nTerminal=false\nCategories=System;TerminalEmulator;\n"
            "Keywords=Sentinel;Kitty;Terminal;Project;Watch;\n")


def install_launchers():
    applications = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "applications"
    icon = config_home() / "kitty/sentinel-crest.png"
    entries = {
        "sentinel-terminal.desktop": desktop_entry("Sentinel Terminal", ["terminal"], icon),
        "sentinel-watch.desktop": desktop_entry("Sentinel Watch", ["watch"], icon),
    }
    for name in load_projects():
        entries["sentinel-project-" + name + ".desktop"] = desktop_entry("Sentinel Project: " + name, ["project", "open", name], icon)
    for filename, text in entries.items():
        atomic_write(applications / filename, text)
    return entries


def summary(full=False):
    command = ["fastfetch", "--config", str(config_home() / "fastfetch/config.jsonc")]
    if full:
        command += ["--logo", "none", "--key-width", "0", "--structure", "Title:Separator:OS:Host:Kernel:Uptime:Packages:Shell:Terminal:WM:Display:CPU:GPU:Memory:Disk"]
    os.execvp(command[0], command)


def sync_palette(palette):
    keys = ("paper", "ink", "muted", "line", "hover", "accent")
    if not isinstance(palette, dict) or any(not isinstance(palette.get(key), str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", palette[key]) for key in keys):
        raise ValueError("Palette requires six-digit paper, ink, muted, line, hover and accent colors")
    colors = {
        "foreground": palette["paper"], "background": palette["ink"],
        "selection_foreground": palette["ink"], "selection_background": palette["paper"],
        "cursor": palette["accent"], "cursor_text_color": palette["ink"],
        "cursor_trail_color": palette["muted"], "url_color": palette["accent"],
        "active_border_color": palette["paper"], "inactive_border_color": palette["line"],
        "bell_border_color": palette["muted"], "tab_bar_background": palette["ink"],
        "active_tab_background": palette["paper"], "active_tab_foreground": palette["ink"],
        "inactive_tab_background": palette["hover"], "inactive_tab_foreground": palette["muted"],
    }
    ansi = ["ink", "muted", "paper", "muted", "accent", "muted", "muted", "paper",
            "muted", "paper", "paper", "paper", "accent", "paper", "paper", "paper"]
    colors.update({"color" + str(index): palette[key] for index, key in enumerate(ansi)})
    outputs = {config_home() / "kitty/themes/sentinel-shared.conf": "".join(key + " " + value + "\n" for key, value in colors.items()),
               config_home() / "sentinel/palette.json": json.dumps(palette, indent=2) + "\n"}
    fastfetch = config_home() / "fastfetch/config.jsonc"
    if fastfetch.exists():
        summary_config = json.loads(fastfetch.read_text())
        summary_config.setdefault("display", {})["color"] = {
            "keys": palette["muted"], "title": palette["paper"],
            "output": palette["paper"], "separator": palette["line"]}
        for module in summary_config.get("modules", []):
            if isinstance(module, dict) and module.get("type") == "custom":
                module["outputColor"] = palette["paper"] if "SENTINEL" in module.get("format", "") else palette["muted"]
        outputs[fastfetch] = json.dumps(summary_config, indent=4) + "\n"
    for path, text in outputs.items():
        if not path.exists() or path.read_text() != text:
            atomic_write(path, text)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Sentinel terminal summaries and workspaces")
    parser.add_argument("--full", action="store_true", help="Show the expanded system summary")
    commands = parser.add_subparsers(dest="command")
    terminal = commands.add_parser("terminal", help="Open a plain Kitty terminal")
    terminal.add_argument("directory", nargs="?", default=str(Path.home()))
    watch = commands.add_parser("watch", help="Open a working shell beside a system monitor")
    watch.add_argument("name", nargs="?", help="A saved project; defaults to the current directory")
    project = commands.add_parser("project", help="Save and reopen project sessions")
    actions = project.add_subparsers(dest="action", required=True)
    add = actions.add_parser("add")
    add.add_argument("name", type=project_name)
    add.add_argument("directory")
    opening = actions.add_parser("open")
    opening.add_argument("name", type=project_name)
    actions.add_parser("list")
    commands.add_parser("install-launchers", help="Refresh desktop launcher entries")
    palette = commands.add_parser("sync-palette", help="Apply the active Quickshell palette")
    palette.add_argument("colors", help="JSON palette from the desktop host")
    args = parser.parse_args(argv)
    try:
        if args.command is None:
            return summary(args.full)
        if args.command == "terminal":
            launch(args.directory, plain=True)
        elif args.command == "install-launchers":
            install_launchers()
        elif args.command == "sync-palette":
            sync_palette(json.loads(args.colors))
        elif args.command == "watch":
            projects = load_projects()
            if args.name and args.name not in projects:
                raise ValueError("Unknown project: " + args.name)
            launch(projects[args.name] if args.name else Path.cwd(), args.name or "Watch", watch=True)
        elif args.command == "project":
            projects = load_projects()
            if args.action == "add":
                projects[args.name] = str(project_directory(args.directory))
                atomic_write(config_home() / "sentinel/projects.json", json.dumps(projects, indent=2) + "\n")
                install_launchers()
            elif args.action == "list":
                for name, directory in sorted(projects.items()):
                    print(name + "\t" + directory)
            elif args.name not in projects:
                raise ValueError("Unknown project: " + args.name)
            else:
                launch(projects[args.name], args.name)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print("sentinel: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())