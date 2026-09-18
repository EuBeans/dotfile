# Workspace Overview

Uses [Shanu-Kumawat/quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview) directly, pinned as a Git submodule at `47f0d402822b26805ed0ecea4a770c38c537b728`. Its live workspace previews, window focus, drag-and-drop and keyboard navigation are provided by upstream, not recreated here. Our integration keeps it in a separate Quickshell process and calls its `overview` IPC target.

## Target Setup

Requires a working Hyprland session and Quickshell with its Qt Quick/Controls/Wayland dependencies. Upstream advertises Quickshell 0.2.0; compatibility must be checked on the target. The native PySide preview cannot run this module. No upstream installer is executed and no existing compositor configuration is replaced.

From the full checkout on the target:

```sh
cd "$HOME/repositories/quickshell"
git submodule update --init --recursive
bash tools/overview.sh start
```

The start command remains in the foreground; keep it running while testing from another terminal:

```sh
cd "$HOME/repositories/quickshell"
bash tools/overview.sh toggle
```

`start` uses Quickshell's `-n` single-instance flag. `toggle`, `open` and `close` use the same explicit config path, so they cannot accidentally target another shell. `close` hides the overlay; it does not stop the process. Ctrl+C in the start terminal stops it. Both `quickshell` and `qs` executable names are supported. Do not also autostart the upstream module as `qs -c overview`; use one launch path consistently.

## Hyprland Bindings

The supplied includes assume this checkout is at `~/repositories/quickshell`. Adjust that path in the include if yours differs. Review existing Super+Tab bindings and remove the conflicting binding before adding this one. Use only the include matching your Hyprland configuration format.

For a traditional Hyprland config, add this to your existing configuration:

```conf
source = ~/repositories/quickshell/config/hypr/overview.conf
```

For Hyprland's Lua configuration, add:

```lua
dofile(os.getenv("HOME") .. "/repositories/quickshell/config/hypr/overview.lua")
```

The includes start only the upstream overview at login and bind **Super+Tab** to toggle it. Reloading configuration does not rerun login startup hooks; use the manual start command for the current session. This does not autostart our experimental FloatingWindow preview.

## Shell Button

The bottom bar's **Workspace overview** icon requests the upstream overview. To enable it in the experimental Quickshell host after starting the overview:

```sh
QUICKSHELL_ENABLE_HOST_OVERVIEW=1 quickshell -p preview/shell.qml
```

Without that flag or outside Hyprland, the action reports unavailable. The native Python preview always reports that Quickshell and Hyprland are required and launches nothing. Settings > Shortcuts also exposes a Workspace overview action with no default local shortcut; the compositor owns Super+Tab. The existing tile manager remains separate.

## Upstream Preferences

Upstream reads `${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/overview/config.json` even when launched by path. It is optional; upstream defaults work without it. To create it without overwriting an existing file:

```sh
overview_config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/overview"
mkdir -p "$overview_config"
cp -n third_party/quickshell-overview/config.example.json "$overview_config/config.json"
```

Edit that JSON for the workspace grid, monitor behavior, animation, glass and preview mode. Upstream includes defaults and README guidance in the submodule. This integration does not yet synchronize our saved profiles or wallpaper palette into the upstream theme. Restart the overview process after changing its JSON. If using chezmoi, track your JSON and compositor include configuration there, not a virtual environment or a second copy of the upstream source.

## Updates And Removal

Normal project updates should use `git submodule update --init --recursive` to retain the reviewed pin. Do not use `--remote` unless deliberately reviewing an upstream upgrade. The submodule is unmodified; the pinned checkout contains no LICENSE/COPYING file, so do not assume redistribution rights or apply this project's asset licenses to it.

To disable the integration, remove the compositor include/binding, stop the overview process you started, and omit `QUICKSHELL_ENABLE_HOST_OVERVIEW`. The button then remains inert. Leave other Quickshell processes alone.

Verified here: dependency checkout, IPC target and methods, wrapper syntax and stubbed command routing, native preview button/shortcut behavior and compact layout. Actual live previews, Hyprland configuration parsing and window dragging require target-machine verification; neither Hyprland nor Quickshell is available in this environment.