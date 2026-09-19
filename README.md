# Custom Quickshell

An original Quickshell/QML shell for Hyprland on CachyOS. Current status: an isolated native WSL preview, not a deployed desktop shell.

Track remaining implementation and real-machine verification in the [CachyOS rollout checklist](docs/cachyos-rollout.md).

## New Machine Setup

**Start with the native preview. Chezmoi is optional.** This repository is application source plus a few optional dotfiles, not a ready-to-apply chezmoi repository. It does not install Hyprland, configure your monitors, replace your bar, provide a secure lock screen, or create a login session. Even the Quickshell entry point currently opens a `FloatingWindow` preview, not desktop layer-shell panels.

| Goal | What you need |
| --- | --- |
| Try or develop the UI safely | Linux graphical session, Git, Python 3.10+, uv; pinned PySide6 is installed by uv |
| Try the experimental target host | Working CachyOS/Arch Hyprland session, compatible Quickshell and its Qt dependencies |
| Collect live Home data | Bash, jq, coreutils (`timeout`), awk, util-linux (`lsblk`); optional services below |
| Manage dotfiles across machines | Optional chezmoi and a separate dotfiles repository |
| Terminal appearance | Optional Kitty, Fastfetch and system-installed JetBrains Mono |

The UI fonts and icons are bundled. Node.js, npm, Docker, vLLM and a system-wide PySide6 installation are **not required**. Python/uv run the development preview and the optional wallpaper-color helper. The Quickshell host can use saved themes without that helper. There is no validated minimum Quickshell version yet; target-machine compatibility remains to be checked.

### 1. Get The Source

Keep the whole repository together: [preview/shell.qml](preview/shell.qml) imports sibling files under [shell](shell). Copying only the entry point will not work.

```sh
mkdir -p "$HOME/repositories"
read -r -p 'Repository clone URL: ' REPO_URL
git clone "$REPO_URL" "$HOME/repositories/quickshell"
cd "$HOME/repositories/quickshell"
```

Use the actual URL of your repository; no public clone URL is assumed here. If this source has not been published to Git, transfer the project directory instead, excluding `.venv`, `.artifacts` and `__pycache__`. The examples below assume the destination above.

### 2. Install Preview Requirements

On CachyOS/Arch, review and run:

```sh
sudo pacman -Syu
sudo pacman -S --needed git python uv
cd "$HOME/repositories/quickshell"
uv sync --locked
uv run tools/preview.py --watch
```

Run as your normal user in a graphical session, never with `sudo`. WSL needs WSLg; other Linux systems need a working Wayland or X11 display. uv reads [pyproject.toml](pyproject.toml) and [uv.lock](uv.lock), creates `.venv`, and installs PySide6 6.8.3. If your distribution does not package uv, use its [official installation instructions](https://docs.astral.sh/uv/getting-started/installation/).

This mode is safe for UI exploration: audio and window controls are fixtures, power actions are simulated, and it does not change host displays or networks. QML saves reload the preview. Close it or press Ctrl+C to stop. Do not launch a second watcher if one is already running.

### 3. Prepare The Target Services

Only do this on the actual CachyOS/Hyprland machine. First ensure Hyprland itself, graphics drivers, sound, networking and your session's D-Bus/polkit agent work independently. Preserve your existing desktop configuration.

| Feature | Arch/CachyOS packages or provider | Notes |
| --- | --- | --- |
| Quickshell host | `quickshell` | Use the [upstream installation guide](https://quickshell.org/docs/guide/install-setup/) if absent from your enabled repositories; let the package manager resolve Qt modules |
| Basic collection | `bash jq coreutils gawk util-linux` | procfs supplies CPU, RAM, load and network counters |
| Audio | `pipewire pipewire-pulse wireplumber libpulse` | `pactl` comes from libpulse; an existing PulseAudio server also works with this adapter |
| Network | `networkmanager nm-connection-editor` | Uses `nmcli`; passwords are handled by the external editor |
| Power profiles | `power-profiles-daemon` | Provides `powerprofilesctl`; do not run competing power managers blindly |
| Batteries | `upower` | Device batteries appear only when the hardware/service exposes them |
| NVIDIA metrics | Matching NVIDIA driver/userspace tools providing `nvidia-smi` | Follow CachyOS guidance for your GPU and kernel; do not substitute a generic driver command |
| Screenshots | `grim imagemagick wl-clipboard`, plus separate HyprQuickshot configuration | See [HyprQuickshot](#hyprquickshot) below |
| Workspace overview | Hyprland, Quickshell and the pinned `quickshell-overview` submodule | Live previews and drag-and-drop; see [setup and Super+Tab bindings](docs/overview.md) |

Example collector packages, after deciding which services you use:

```sh
sudo pacman -S --needed quickshell jq coreutils gawk util-linux
```

Install optional rows separately. Do not replace an existing audio/network stack just to run the preview. For a fresh NetworkManager-based machine, enabling `NetworkManager.service` is a system setup decision: migrate from any existing network manager first, especially over SSH. PipeWire/WirePlumber use user services; do not launch them as root. UPower and power-profiles-daemon may be D-Bus activated, depending on packaging. A service can be installed yet unavailable in the current session.

These checks are read-only; missing optional tools identify which features will be unavailable:

```sh
quickshell --version
hyprctl -j monitors
pactl info
nmcli general status
powerprofilesctl get
upower -e
nvidia-smi
```

AMD/Intel GPU metrics are not implemented by this collector. Unsupported CPU temperature sensors remain unavailable. Installing `lm_sensors` does not add support automatically: the collector currently reads selected hwmon drivers directly. GPU process rows currently report NVIDIA compute processes, not all graphics applications.

### 4. Launch In Stages

From the complete checkout, first launch without integrations:

```sh
cd "$HOME/repositories/quickshell"
quickshell -p preview/shell.qml
```

Close that instance before launching another mode. Enable collection next, leaving service-changing controls disabled:

```sh
QUICKSHELL_LIVE_SERVICES=1 quickshell -p preview/shell.qml
```

Only after checking the data and service permissions, opt into audio, network, power-profile and display commands:

```sh
QUICKSHELL_LIVE_SERVICES=1 QUICKSHELL_HOST_CONTROLS=1 quickshell -p preview/shell.qml
```

The flags apply to this process only. They do not enable live integration in the Python preview. Live Home data does not make every other bar/widget live: several surfaces still use fixtures.

**Display warning:** mode changes use a 15-second confirmation/revert timer inside the shell process. It cannot recover from a crash or reload. Keep a working terminal/TTY and a copy of your known-good Hyprland monitor configuration; do not test risky modes over a remote-only connection.

Do not add this preview to Hyprland autostart yet. Once a real desktop host is implemented and validated, add its launch command through your existing Hyprland/session configuration, avoiding duplicate instances. This repository provides no ready-made systemd user service or session installer.

Notification-server ownership is a separate opt-in, `QUICKSHELL_NOTIFICATIONS=1`, used with live services. Leave it off if mako, dunst, swaync or another daemon owns notifications. This is not an automatic history importer; existing daemon history is not copied.

### 5. Optional Chezmoi

**Recommended split:** Git manages this application checkout; chezmoi manages selected user configuration. Chezmoi does not install Quickshell or run the UI. No `.chezmoi` bootstrap, package installer or machine templates are supplied here. Do not point `chezmoi init` at this application repository and expect a desktop installation.

Install chezmoi only if you want reproducible dotfiles:

```sh
sudo pacman -S --needed chezmoi
```

For a new, separate dotfiles repository:

```sh
chezmoi init
chezmoi source-path
```

Deploy and test the optional files using [Terminal System Summary](docs/terminal-summary.md), then add only the files you actually installed. For example, if you installed the Fastfetch preset:

```sh
chezmoi add "$HOME/.config/fastfetch/quickshell.jsonc"
chezmoi diff
```

Commit and push the resulting chezmoi source repository to your own dotfiles remote. On another machine, initialize from that **dotfiles** remote, review changes, then apply:

```sh
read -r -p 'Your chezmoi dotfiles repository URL: ' DOTFILES_URL
chezmoi init "$DOTFILES_URL"
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
```

Review the source repository's scripts before applying, too: chezmoi can run install hooks supplied by that repository. If you already use chezmoi, add selected files to your existing source instead of reinitializing it. Examples assume the default `~/.config`; adapt paths if `XDG_CONFIG_HOME` differs.

Do not track `.venv`, `.artifacts`, caches, Wi-Fi passwords, API tokens or device-specific credentials. Keep monitor names, GPU identifiers and absolute wallpaper paths machine-specific; chezmoi templates can help, but none are included. Do not overwrite an entire existing Kitty, shell or Hyprland configuration just to add a small include.

### 6. Preferences, Updates And Removal

Preview preferences live under `${XDG_CONFIG_HOME:-$HOME/.config}`, including the `quickshell-preview` directory. Back up your saved profiles/shortcuts/window rules before moving or resetting machines. Save profile drafts in the UI first, close the app, and inspect generated preference files before choosing to track them with chezmoi; local wallpaper paths may need adjustment. Notification history and configured weather coordinates are session-only.

For a Git checkout, close the running instance before an update:

```sh
cd "$HOME/repositories/quickshell"
git status --short
git pull --ff-only
git submodule update --init --recursive
uv sync --locked
```

Preserve local edits before pulling. `uv sync` is needed for the Python preview and optional wallpaper-color extraction. Never copy a virtual environment between machines; rebuild it from the lockfile.

The bottom bar's workspace-overview button uses the real [Shanu-Kumawat/quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview) module, pinned under [third_party/quickshell-overview](third_party/quickshell-overview). Follow [Workspace Overview](docs/overview.md) to enable its standalone Hyprland process, Super+Tab binding and optional `QUICKSHELL_ENABLE_HOST_OVERVIEW=1` shell action. It is unavailable in the native preview; the tile manager remains separate.

To roll back, close the preview and restore your backed-up preferences or optional config includes. Stopping the process does **not** undo explicit live audio/network/power actions, or a display mode you confirmed; restore those through their owning tools. There is no installed desktop session to remove. Remove any autostart/include entries you added yourself before removing the checkout. With chezmoi, stop managing a file using `chezmoi forget PATH` before deleting the local file, otherwise a later apply can recreate it.

### Troubleshooting

| Symptom | Check |
| --- | --- |
| UI cannot open | Launch inside a graphical session; verify `WAYLAND_DISPLAY` or `DISPLAY`. For headless verification, use the test command below, not an interactive window |
| Certificate errors during uv install | Fix system trust or use `uv --system-certs sync --locked` for a managed certificate environment; never disable TLS verification |
| Missing QML import on Quickshell | Install matching Quickshell/Qt dependencies and retain the full checkout layout; target compatibility is still unverified |
| Home audio changes only affect preview | Python host is intentionally inert; use the Quickshell host and explicit live/control flags on the target machine |
| Missing metrics, devices or power profiles | Run the corresponding read-only checks above; unsupported hardware remains unavailable |
| Service action fails or stays busy | Check session permissions/polkit and service health. The current adapter may remain busy while the external connection editor is open |
| No weather forecast or Wi-Fi scan list | Weather provider and Wi-Fi scan/saved-network collection are unfinished, not solved by adding chezmoi |

The lock screen is a visual simulation, **not authentication**. Continue using a real locker such as hyprlock independently. Clipboard history, window management and AI controls also remain largely preview functionality. Do not remove your working desktop services on the assumption this replaces them.

## Run

Requires WSL2/WSLg or another Linux graphical session, Python 3.10+ and [uv](https://docs.astral.sh/uv/).

```sh
uv run tools/preview.py --watch
```

Dependencies are pinned and installed in `.venv`. For this environment's certificate trust configuration, use `uv --system-certs run tools/preview.py --watch`. Never disable TLS verification. The runner defaults to software rendering following WSLg EGL/Mesa warnings; it is not a performance benchmark.

QML saves reload the window and reset fixtures. Close the window or press Ctrl+C in the launching terminal to stop.

## Preview Controls

- The top bar places Home at the far left followed by date/time, with GPU/AI/audio/Wallpaper controls right. The center activity notch cycles through playing music, timers, AI tasks, transfers, recording/sharing and urgent alerts using its right chevron. It closes when nothing is active, preserves selection for new background work and returns after urgent alerts. Motion respects shared preferences. Home's timer icon opens Activities for fixture controls; the preview toolbar's Music switch tests playback. Recording has a persistent stop indicator on the right. These activities are simulated; no real transfers, recording or AI execution occurs.
- The bottom bar fits its contents, with workspace/app modes, grouped app windows and current/all-workspace scope. It scrolls when space is limited.
- Home opens from the left like Calendar, using Settings > Desktop > panel placement for attached or floating mode. Its icon-only rail contains Home, Audio, Displays, Network, System, Power, Weather, Notifications and Settings. Home uses a house icon, a wallpaper-backed header and six equal-sized quick controls. Workspace, Media, Personalize and Calendar tabs are omitted; existing standalone panels remain. Ctrl+Alt+S opens the separate native Settings window.
- Profiles own appearance, layout/rules/summary position, AI, notification and optional audio policies. Changes are drafts until Save; Revert restores saved values. Create from defaults or duplicate, Save as new, and selective category copying with preview/confirmation/undo are available in Themes / Profiles.
- Profile switching is immediate when AI is idle or the destination keeps AI unchanged. Active requests affected by an AI policy change still offer wait/cancel-request/leave-AI-unchanged choices; an in-progress AI transition blocks application. Existing windows are not relocated by switching rules. AI transitions, failures and VRAM changes are simulated, not measured.
- System Summary supports dragging, pinning and tiling through Tile Manager. Its artwork/facts layout separates configured hardware from unavailable or synthetic telemetry.
- Home Audio and the standalone mixer share preview output/input selection, volume/mute and application mixing. These controls are inert fixtures in the native host. GPU and AI retain their dedicated bar controls.
- System uses CPU, Memory, one multi-series plot per GPU, and Network graphs. Each GPU is identified independently and shows usage, VRAM, temperature and power; no detected GPUs produces one unavailable placeholder. Every legend is a compact horizontal row of icons and values, with full details in keyboard-accessible tooltips. Lines use active-theme tones and dash patterns, not a fixed rainbow palette. Missing/stale measurements remain unavailable. System information, resources, GPU compute processes and storage follow the plots.
- Displays, Network and Power distinguish unavailable, read-only and pending states. Weather includes current/hourly/daily layouts and coordinate validation, but its provider is not connected. Notification history is session-only and grouped Today, Yesterday and Older, with confirmation before clearing.
- Settings > Desktop includes tiling mode, main-pane width, window borders, and inner/outer gaps. Numeric appearance and layout controls support slider dragging, keyboard steps, and typed values.
- Settings includes category/keyword search, grouped navigation, responsive label/control rows and a persistent profile Save/Revert strip. Shared control outlines account for ancestor scaling so borders remain visible in the fit-to-window preview.
- Volume and Wallpaper remain on the right bar, opening standalone panels that share state with Home. Wallpaper includes palette controls, bundled images, and a native folder chooser for local images.
- Choose **Wallpaper** as the color source in the wallpaper panel to generate a monochrome-style theme from the selected image. Extraction uses the pinned third-party `material-color-utilities` Python binding (0.2.4), not average-RGB sampling. Its dominant-color quantizer and HCT tonal palettes produce one restrained hue across the theme; grayscale wallpapers stay neutral. Processing is local, asynchronous and does not modify the image, terminal colors or other apps. Choose **Saved** to return to the named palette. Run `uv sync --locked` on the target to provide `.venv/bin/python` for the Quickshell helper; missing/invalid images fall back to the saved palette. Restart an already-running preview once after this backend update. The native preview integration is tested; the Quickshell process adapter remains unverified here.
- The clock opens the calendar. The bot icon opens local AI: mock vLLM status, model selection, start/stop/switch, per-GPU VRAM/utilization and output tok/s. Stop/switch require confirmation.
- The preview toolbar's search icon opens the fixture app launcher. Its shortcut is initially unassigned and can be configured in Settings > Shortcuts.
- The launcher uses a search-first layout with attached Apps, Run, Files and Windows tabs, inspired by the [4rtemis-4rrow Rofi reference](https://github.com/4rtemis-4rrow/dotfiles). Compact rows, pinned/recent apps and selection highlights follow the active shell theme. Arrow keys select results; Enter activates; Escape closes; Ctrl+Tab cycles modes. Apps and Windows operate on preview fixtures. Run only reports the command without executing it; Files shows an unavailable state until a file provider is connected.
- Alt-Tab opens a focus-only switcher: repeat Tab to cycle, Shift-Tab to reverse, release Alt to focus, Escape to cancel. The circular-arrows toolbar icon opens the same switcher if the host desktop intercepts Alt-Tab.
- The separate panels icon opens Tile Manager: search windows, focus/close, move between fixture displays/workspaces, choose tile order, float, and save conditional app-slot rules. Closed apps reserve no empty space.
- The clipboard icon opens separate text/image history fixtures with search, pinning, simulated copy, deletion and confirmed clear-unpinned.
- The bottom scissors icon hands off to [HyprQuickshot](https://github.com/JamDon2/hyprquickshot), not a custom screenshot manager. Native preview reports it as unavailable and never captures the host desktop. The Quickshell host supports opt-in launch on Hyprland; see setup below.
- Escape, clicking the wallpaper or the panel close control dismisses panels.
- Display buttons select 1920 x 1080 or 5120 x 1440 logical layouts. Fit checks composition; 1:1 plus scrolling checks readability.
- The type icon opens the paired-font specimen. Reset restores fixture state.
- The lock icon opens a visual lock-screen preview, also available through Power > Lock > Confirm. It uses the current wallpaper, a large clock/date and a bottom media/demo-password area. Enter any dummy text to simulate unlocking; the footer's Reject unlock checkbox exercises the failure state. Escape or the close icon exits. Never enter a real password: this is not a secure lock, uses no PAM authentication, and does not start hyprlock. Text is cleared on submission and exit. Actual hyprlock integration remains a separate target-machine step.
- Lock-screen widgets include a 48-sample CPU/dual-GPU demo graph with VRAM figures and a weather/three-day forecast layout. Graph samples are synthetic, not nvtop output; sampling pauses when hidden or telemetry is unavailable. Weather stays offline with placeholders until a location and provider are configured. No weather requests or location detection occur. The widget stack scrolls on narrow or short screens to keep the demo password accessible.

Telemetry and service actions are synthetic; the launcher does not start host applications. Local image folders are read and preferences are saved under the XDG configuration directory. No desktop services are changed. Monocraft is paired with provisional JetBrains Mono; geometry, wallpaper art and companion font remain review candidates.

## Verify

```sh
uv run python -m unittest discover -s tests -v
uv run tools/preview.py --capture .artifacts/wsl-preview.png
uv run tools/preview.py --ultrawide --one-to-one --specimen
```

QtTest coverage includes bars/media, profile drafts/copy/confirmation, movable/tiled summary, native and embedded Settings, all nine Home tabs, window management, clipboard fixtures, wallpapers, launcher/calendar/audio, AI lifecycle failures, inert HyprQuickshot handoff, lock preview, display layouts and nonblank captures. Tab polish is checked at 320/375/414/768px with populated/unavailable states; rendered-edge checks cover search and focus outlines at 28%-100% scale. Graph tests cover theme changes, compact values, multiple GPUs and missing-data gaps. Screenshots in `.artifacts/` are inspection artifacts, not approved pixel-diff baselines. Native QML is tested with QtTest rather than browser-only Playwright; production Hyprland/Quickshell behavior still requires target validation. The shared UI direction is recorded in [design.md](design.md).

Optional [Kitty/Fastfetch terminal summary setup](docs/terminal-summary.md) is provided under `config/`. It is not installed automatically or synchronized with preview profiles. Fastfetch schema and Bash syntax checks pass; target runtime validation remains pending.

## Quickshell

On a compatible Quickshell installation, the same views can be loaded through the separate `FloatingWindow` host:

```sh
quickshell -p preview/shell.qml
```

Quickshell is not installed here, so that host is unverified. The UI remains Quickshell; Python/PySide6 support the native preview and optional wallpaper-color helper. No desktop configuration is installed or replaced.

The experimental Home adapter is opt-in: `QUICKSHELL_LIVE_SERVICES=1` enables collection; `QUICKSHELL_HOST_CONTROLS=1` also permits explicit service actions. It uses Bash/jq, procfs, optional NVIDIA tools, Hyprland, pactl, NetworkManager, powerprofilesctl and UPower. Native PySide preview never loads this adapter. Display confirmation has a 15-second in-process rollback timer, not crash-safe recovery. Wi-Fi scan/saved-network collection and weather-provider integration remain unfinished. `QUICKSHELL_NOTIFICATIONS=1` additionally enables a notification server; do not enable it alongside another notification daemon. These target integrations require CachyOS/Hyprland validation before everyday use.

### HyprQuickshot

On CachyOS/Hyprland, install the upstream dependencies: Quickshell, `grim`, ImageMagick and `wl-clipboard`. Install [HyprQuickshot](https://github.com/JamDon2/hyprquickshot) as the separate `hyprquickshot` Quickshell configuration using its upstream instructions. Nothing is automatically installed into your live configuration by this project.

Enable the screenshot handoff only in the target Hyprland session:

```sh
QUICKSHELL_ENABLE_HOST_CAPTURE=1 quickshell -p preview/shell.qml
```

Clicking the scissors button then runs `quickshell -c hyprquickshot -n`. HyprQuickshot owns selection, editing, saving and clipboard operations. Its `HQS_DIR` environment variable selects the screenshot directory. Without the opt-in or a Hyprland session, no process is launched. PySide6 preview always remains inert, even with that environment variable set. No Print Screen bindings or compositor settings are modified. Real capture and dependency-failure handling still require target validation.

The local screenshot fixes target upstream revision `3b4a039087c34f75f3ba10499b64f22f456c3731`. From this repository root, apply them to a clean installation at that revision:

```sh
git -C "$HOME/.config/quickshell/hyprquickshot" apply --check "$PWD/tools/hyprquickshot.patch"
git -C "$HOME/.config/quickshell/hyprquickshot" apply "$PWD/tools/hyprquickshot.patch"
ln -s "$PWD/tools/capture_screenshot.py" "$HOME/.config/quickshell/hyprquickshot/capture_screenshot.py"
```

The patched configuration also requires Python 3. It preserves upstream's compact toolbar, selection animations, and capture-and-exit workflow. It opens on all connected monitors: drag a region across display boundaries, select a visible window on either display, or use the screen button to capture the entire desktop. Mixed-scale monitors share logical selection coordinates; output uses the highest display scale. Hover over Save to disk for the destination; one completion notification reports the filename and clipboard result. There is no separate result manager. Saving and clipboard copying are independent. The destination is `HQS_DIR`, `XDG_SCREENSHOTS_DIR`, `XDG_PICTURES_DIR`, or `$HOME/Pictures`, in that order. With Save to disk disabled, only the PNG clipboard is updated. The installed configuration uses a software-rendered selection fallback for local graphics-context failures. `HQS_VALIDATE_ONLY=1 quickshell -c hyprquickshot -n` validates native loading and reports combined display geometry without taking a screenshot.

See [preview architecture](docs/preview-workflow.md), [local AI spec and plan](docs/local-ai.md) and [asset provenance](docs/assets.md). The comprehensive component plan remains in the existing untitled planning document. Project-wide licensing is still undecided.