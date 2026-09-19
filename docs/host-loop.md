# Quickshell Host Loop

The repository has two deliberately separate entry points:

- `preview/shell.qml`: safe FloatingWindow preview with fixture services;
- `shell.qml`: Hyprland layer-shell host, composing `host/Host.qml`.

Launch from the repository root, **not** `host/shell.qml`. Quickshell 0.3.1 uses
the entry point directory as its import boundary. The root entry point lets
both `host/` and the shared `shell/` components load correctly.

Run it manually from a Hyprland terminal:

```sh
cd ~/repositories/dotfile
quickshell -n -p shell.qml
```

The user authorized replacing Noctalia. The local Hyprland Lua autostart now
starts this shell and the pinned workspace overview. The host owns desktop
notifications. Original `binds.lua` and `autostart.lua` are backed up beside
the live files with `.before-custom-shell` suffixes. Shortcuts remain in Lua.

## Verified Handoff

Verified on 2026-09-18 with Quickshell 0.3.1 and the current Hyprland Lua session:

- Shared top/bottom bars on DP-2 (5120x1440) and DP-3 (1920x1080), with exclusive zones.
- Some hot reloads leave Quickshell 0.3.1 IPC reporting "Not ready to accept
	queries yet" despite a successful load log. Restart only this host if that
	persists; new component files can also require a clean restart.
- Native Hyprland workspace discovery, window groups, workspace activation and window focus.
	Activation uses native objects, not legacy dispatcher strings rejected by Lua Hyprland.
- Home, Audio, Displays, Network, System, Power, Weather, Notifications and Calendar
	instantiate on both outputs without QML warnings. Native panel captures are in `.artifacts/`.
- The existing live collector supplies Home device data and fresh system telemetry.
	MPRIS is connected; the vLLM models endpoint is polled read-only every five seconds.
- Centered, content-sized dock with desktop-entry app icons and native grouped
	window popups anchored above the selected app. Close buttons request graceful
	closure of individual windows, never process termination.
- GPU, live Audio and Wallpaper right-side panels; Settings uses the same
	shared view/profile engine as the preview. Host profiles save separately to
	`$XDG_CONFIG_HOME/quickshell-host/profiles.ini` (default `~/.config`).
- Saved palettes and wallpaper-derived colors update the live theme. Wallpaper
	color extraction uses `.venv/bin/python tools/wallpaper_palette.py`.
	The focused Hyprland window border uses the theme accent and is reapplied
	after compositor reloads. Live saved and wallpaper-derived border colors match.
	Save/Revert in Settings controls profile drafts, including wallpaper selection.
- Wallpaper > Display targets one connected monitor or All displays. The native
	side picker initially targets the monitor where it was opened. Individual
	choices are profile-specific overrides keyed by connector name; the reset
	button returns that display to the shared default. Choosing an image for All
	displays clears overrides. Save/Revert, profile switching and appearance
	copying include these choices; disconnected monitor overrides remain saved
	for reconnection. Wallpaper-derived colors use the selected palette monitor's
	image; the lock screen still uses the shared default image. Live extraction
	was verified against the helper output, then the saved palette was restored.
- Audio volume, mute and routing use `pactl`; events refresh mixer data promptly.
	A live output change from 86% to 85% was verified and the exact original
	channel volumes restored. Input, mute and routing paths have QtTest coverage.
- Focused dock grouping/close/layout, launcher, Settings, audio and wallpaper
	tests pass. Native screenshots verified the popup above its app.
- The existing suite ran 89 tests: 87 passed. `test_dropdown_content_sizing` and
	`test_home_embedded_settings_and_audio_sync` fail identically against committed HEAD
	in this environment. They are not new host regressions.

Settings > Key bindings now records, clears and resets native Hyprland shell
shortcuts. Production bindings are stored separately from the preview in
`$XDG_CONFIG_HOME/quickshell-host/shortcuts.lua` (default `~/.config`).
The active Hyprland binds file sources this managed file; its original version
was backed up as `binds.lua.before-shortcut-editor`. The editor checks live
Hyprland bindings for conflicts and updates only its own binding handles.
Wayland shortcut inhibition is active only while recording in the Home window.
New presets: Ctrl+Alt+N Network, Ctrl+Alt+D Displays, Ctrl+Alt+V Audio,
Ctrl+Alt+S System, and Ctrl+Alt+A AI status. Existing shell shortcuts, including
Super+L Lock, retain their combinations. Lock now launches `tools/lock.sh`, which
uses the existing custom QML screen through `lock.qml`, `WlSessionLock` and PAM's
installed `/etc/pam.d/hyprlock` stack. The Session menu launches it detached so a
desktop-shell restart cannot terminate the locker. Hyprlock and its local
configuration remain a fallback, not the primary lock UI.
Bare Super launcher aliases and Print screenshot remain in the Hyprland file.

Super+M minimizes the focused unpinned window from a normal workspace;
Super+Shift+M restores the most recently minimized window. Dock window menus
also provide minimize/restore buttons, and selecting a minimized window restores
it. Hidden windows live on `special:quickshell-minimized-<workspace>` so their
original workspace remains recoverable after a shell restart. Existing special
workspaces and pinned windows are not repurposed by this action.

The overview (Super+Tab) opens only on the invoking monitor and stays there
until closed. The default grid keeps all six numbered workspaces visible,
including empty ones. Arrows, numbers and scrolling browse the grid without
switching the desktop. Tab/Shift+Tab select a window; Enter activates it, or
activates the browsed workspace when empty. A window/workspace click also
activates it. Escape cancels without changing workspaces.
Shift+Arrow moves the selected window to the adjacent overview workspace and
follows its selection inside the overview, without switching the desktop;
Ctrl+Arrow swaps the selected tiled window in that direction. H/J/K/L
alternatives also work. Dragging requires actual pointer movement, suspends
tile position animations, and does not activate a window on drop. Selection
has a visible outline. Outside overview, Super+Arrow focuses and Super+Shift+Arrow
moves windows using the existing Hyprland bindings. `tools/overview.sh start`
applies `tools/overview-keyboard.patch` to the pinned overview checkout when
needed and refuses conflicting local changes instead of overwriting them.
The local workspace-1 `lua:sentinel-zones` override was removed: the ultrawide
now uses the selected global layout instead of class-based 25/50/25 percent
zones. Workspace-to-monitor assignments and app launch rules remain unchanged.

The custom locker disables file watching and has no IPC unlock action. Only
PAM success releases its session lock; preview timers, Escape and the preview
close button cannot dismiss secure mode. The shared UI retains its wallpaper,
clock, media and widgets; production telemetry is real rather than simulated.
Selected wallpapers are converted into a PNG cache for system Qt compatibility.
The launcher serializes attempts and checks PAM prompt availability before
starting the real lock. `QUICKSHELL_LOCK_VALIDATE_ONLY=1 quickshell -p lock.qml`
checks startup without locking or submitting credentials; `visual` additionally
captures a temporary non-locking window in `.artifacts/custom-lock-native.png`.
Normal launches explicitly unset that validation flag. Validation does not
prove real session acquisition, password acceptance, multi-monitor input or
crash recovery; those still require manual lock/unlock acceptance testing.

Appearance window opacity and corner radius now apply to Hyprland through the
native settings queue, including profile switches, Revert and saved startup
appearance. Opacity sets both active and inactive windows (40-100%); fullscreen
opacity remains unchanged. Glass off forces opaque windows without discarding
the selected percentage. Window corners map to `decoration:rounding` (0-24px).
Both controls respect read-only mode; panel and bar appearance stay independent.

Audio/network/power-profile actions are enabled by default; set
`QUICKSHELL_HOST_CONTROLS=0` for read-only operation. Network groups Ethernet,
Wi-Fi and virtual/VPN adapters separately, with internal IPv4/IPv6 addresses and
the IPv4 default gateway from `ip` JSON output. Public IPv4 lookup is manual,
uses `https://api.ipify.org?format=json` with an eight-second timeout, and shows
when it was checked; opening Network never triggers an external lookup.
Display mode, scale and
rotation controls use `hl.monitor()` through `hyprctl repl` on Lua Hyprland,
with the legacy command retained for older versions. Keep confirms the change;
Revert or the 15-second timeout restores the captured mode, scale, position and
rotation. An unchanged native monitor write was verified; a disruptive mode
change and timed physical rollback still need acceptance testing.
The monitor diagram applies a position change once on drag release, without an
Apply button, and retains the Keep/Revert countdown. Drops attach to the nearest
non-overlapping monitor edge without a gap, using scaled and rotated dimensions.
Pointer tracking stays on the fixed diagram so dragging does not move the page
or feed the tile's own movement back into the drag.
Display choices retain every advertised mode, with the highest current-resolution
refresh rates first and an explicit maximum label. The connected DP-2 reports
5120x1440 at 239.76 Hz (nominal 240 Hz); DP-3 reports 1920x1080 at 143.99 Hz
(nominal 144 Hz). Both were already active; no unsupported 244 Hz mode is added.
Desktop layout, gaps and border controls use validated `hyprctl repl` Lua writes.
Preview layout keys are displayed as Current/default, Dwindle, Master and Centered
in the host. Main-pane sizing applies to Master and Centered. Initial profile
defaults are not pushed over compositor settings on shell startup; edits and
profile changes apply the changed values at runtime. Compositor config reloads
can restore compositor-defined values. Preview service policies and AI actions
remain disabled.

The AI bar button opens the shared Local AI panel with live service and GPU
status. Model lifecycle controls remain disabled until AI setup is completed.
Home has a compact wallpaper header and no duplicate output-volume slider;
volume remains available in the bar and Audio panel.
All Home tabs now share a 530px height (bounded by the screen), and the sidebar
is fixed rather than scrollable. System graphs have distinct series/legend colors
and bordered tiles; detailed inventory is always visible, with storage meters.
The GPU panel keeps utilization and VRAM meters without duplicate history plots.
Temperature and power have separate colored histories, and the five largest
compute processes are listed by VRAM for the selected GPU UUID. This uses
`nvidia-smi --query-compute-apps`, not a complete inventory of graphics clients.
Driver, PCI address, core clock, fan speed and power limit are collected when
supported; unsupported metadata is omitted from the always-visible device details.
DND and profiles are connected to the saved settings, and Caffeine uses Wayland
idle inhibition while the bar is visible. Bluetooth reflects native adapter power;
the local `bluetooth.service` was inactive during validation. Night light manages
`hyprsunset -t 4500`, which is not yet installed. Complete these prerequisites locally:

```sh
sudo pacman -S --needed hyprsunset
sudo systemctl enable --now bluetooth.service
```

Home controls follow `QUICKSHELL_HOST_CONTROLS=0`. DND and Caffeine were toggled
through IPC and restored; Bluetooth radio and night-light effects remain unverified
until their prerequisites are available.

Settings > Desktop > Panel placement controls the edge gap for Home and the
right-side panels: Attached is flush with the edge, Floating adds a 12px gap.
Panels slide in and out using Settings > Motion, including distinct stepped motion.
The power button and Super+Alt+C open the confirmed Session menu; Home > Power
continues to show power profiles. No logout/suspend/reboot/shutdown was executed
during validation. The custom locker uses the installed Hyprlock PAM stack and
retains the Hyprlock executable as a fallback.

Wallpaper rendering is on by default; set `QUICKSHELL_HOST_WALLPAPER=0` to disable
it. `QUICKSHELL_WALLPAPER` supplies an initial image URL.
HyprQuickshot is installed in `~/.config/quickshell/hyprquickshot` at upstream
revision `3b4a039087c34f75f3ba10499b64f22f456c3731`. Its dependencies were already
installed. Local fixes are preserved in `tools/hyprquickshot.patch`; the installed
`capture_screenshot.py` links to `tools/capture_screenshot.py` in this repository.
The toolbar preserves upstream's three modes and Save to disk switch. Its tooltip
shows the destination. Selection retains upstream spring animations and shader,
with a software-rendered fallback for this machine's graphics-context failures.
The process exits after capture and sends one notification with the saved filename
and clipboard status; there is no custom result window. A clipboard failure does
not discard a saved image, and a disk failure still allows clipboard copying.
Processing does not reopen the selection overlay. The helper avoids waiting for
inherited clipboard-owner pipes. Real PNG clipboard transfer, native QML loading,
rapid animated selection, and save/copy failure tests passed. The user confirmed
a physical selection spanning both monitors produces the expected combined image.
The manager captures all connected displays in one frozen desktop image, then
shows the matching viewport and the same toolbar on every monitor. Region drags
can cross monitor boundaries; window mode selects visible windows on either
display, and the screen button captures all displays together. Geometry uses
logical desktop coordinates, including negative origins, with output at the
highest connected scale. Rectangles spanning gaps between displays include blank
pixels. Selection waits for all display images; a monitor hotplug cancels capture.
The current DP-2/DP-3 layout validates as 5120x2520. Cross-monitor mouse geometry,
viewport pixels, and scaled crops pass offscreen tests; a physical cross-monitor
drag under Wayland was confirmed by the user on 2026-09-18.
The scissors button, Print and Super+Shift+S launch it. Super+Print retains direct
full-screen clipboard capture. Set `QUICKSHELL_ENABLE_HOST_CAPTURE=0` to disable
the shell button. The overview button uses `tools/overview.sh toggle`.

Super release opens the launcher (Super+Space remains available); Super+Z opens
Settings, Super+Shift+W opens Wallpaper, and Super+Tab opens workspace overview.
Lua bindings pass `hyprctl configerrors`; physical modifier-only key behavior
still needs user acceptance testing.

## Verified Services

Super+V now opens real clipboard history backed by `cliphist` and a shell-owned
`wl-paste --watch` process. The installed user-local cliphist v0.7.0 binary is
`~/.local/libexec/cliphist`, verified against upstream SHA-256
`d21ca6846bd25f7bd2dabb157912e2e07226db76be32885bc53d7f27db98d08a`.
A system `cliphist` install takes precedence. History lives under
`$XDG_STATE_HOME/quickshell-host/clipboard` (default `~/.local/state`), with a
private directory and files. It retains up to 500 ordinary entries and displays
the latest 100 plus pins. Pins survive clearing ordinary history. Copy, pin,
unpin, delete, clear, and an isolated real-provider roundtrip pass tests.
Selections marked sensitive by the source application are excluded; unmarked
secrets can still be stored. Set `QUICKSHELL_CLIPBOARD_HISTORY=0` before launching
the shell to stop recording; existing history remains until explicitly cleared.

Caffeine now owns both per-monitor Wayland idle inhibitors and a logind
`sleep:idle` block. Acquisition and release were verified with `systemd-inhibit`;
no actual suspend was attempted. Night light is installed and verified through
hyprsunset IPC at 4500 K; it was turned off after the check. Bluetooth is enabled
at boot but its service is skipped because `/sys/class/bluetooth` and a detected
Bluetooth controller are absent. Hardware/firmware/driver diagnosis is required.

The overview selection now has a themed frame, contrasting inner edge, title
strip, full opacity, and raised stacking. Its rendering and selection-preserving
movement tests pass. Secure lock validation reached PAM's password prompt without
locking. The user then confirmed a real secure lock and password unlock on
2026-09-18. Password entry remains confined to the lock screen, never chat.

## Remaining Work

Idle policy, profile
service policies and AI lifecycle controls remain unconfigured. AI setup is
explicitly deferred. Weather needs a user-selected location. Optional packages:
`hypridle network-manager-applet`; installation alone does not
configure idle policy. Fullscreen/input behavior,
monitor hotplug and suspend/resume need acceptance tests.

To roll back, stop only the custom host and overview, restore the two local
`.before-custom-shell` Lua backups, reload Hyprland, and start Noctalia. Do not run
two notification servers; disable the custom receiver with
`QUICKSHELL_NOTIFICATIONS=0` if running both shells during comparison.

The older `host/status.sh` and `host/power-cycle.sh` POC helpers are retained but
not used by the modular host; live collection uses `shell/Services/linux-snapshot.sh`.

Inspect this host without touching other shell processes:

```sh
quickshell ipc -p shell.qml call host status
quickshell ipc -p shell.qml call host openHome System DP-2
quickshell ipc -p shell.qml call host closeHome
quickshell ipc -p shell.qml call host side Audio DP-2 -1
quickshell ipc -p shell.qml call dock-DP-2 windows firefox
quickshell log -p shell.qml -t 40
```

Use the actual output name from `status` instead of assuming DP-2 on another machine.

## Preview And Shutdown

The development feedback loop remains separate:

```sh
uv run tools/preview.py --watch
```

The host process can be stopped with `Ctrl+C`. It must not be killed using a
global `pkill quickshell`, because other Quickshell configurations may be
running.
