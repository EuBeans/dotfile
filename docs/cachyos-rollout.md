# CachyOS Rollout Checklist

Updated 2026-09-18. This is the tracked handoff from the WSL preview to the real CachyOS/Hyprland desktop. It consolidates saved project notes and subsequent requests; the original untitled component plan was not available for a line-by-line comparison.

## Current Status

- [x] Shared native QML preview: bars, Home pages, Settings, profiles, launcher, window/clipboard fixtures and lock-screen presentation.
- [x] Third-party wallpaper palette extraction through Material Color Utilities; native tests pass.
- [x] System graphs: CPU, Memory, one graph per GPU, Network. Each GPU retains usage/VRAM/temperature/power, compact icon/value legends and independent history keyed by device ID. Device reorder/removal, duplicate names, missing sensors and stale data are tested.
- [x] Quickshell Overview: pinned upstream submodule, dock action, guarded IPC wrapper and optional Hyprland includes.
- [x] HyprQuickshot handoff replaces the custom screenshot-manager implementation.
- [x] Experimental opt-in Home service collector and selected host controls exist.
- [ ] Production runtime verification. The Quickshell entry point still opens a FloatingWindow preview, not a deployed desktop shell. WSL/PySide tests do not prove Hyprland behavior.

## 1. Prepare The Target

- [ ] Back up existing Hyprland configuration, bar/notification/locker startup entries and shell profile preferences. Keep a working terminal/TTY and known-good session available.
- [ ] Record CachyOS, Hyprland, Quickshell, Qt and NVIDIA driver versions. Confirm the Hyprland config format before choosing a supplied include.
- [ ] Record monitor names, modes/scales, GPU UUIDs and actual VRAM totals. Do not hardcode WSL display names or fixture GPU identities.
- [ ] Transfer or clone the complete checkout, including reviewed uncommitted work if it has not yet been published. Preserve existing edits before updating. Initialize the pinned dependency with `git submodule update --init --recursive`.
- [ ] Follow [New Machine Setup](../README.md#new-machine-setup). Run `uv sync --locked` for the native preview and optional palette helper; do not transfer `.venv` between machines.
- [ ] Check providers independently: Hyprland, Quickshell, PipeWire/WirePlumber, NetworkManager, power profiles, UPower and NVIDIA tooling as applicable.

Gate: the existing desktop and required providers work before replacing any of them. Missing hardware/services must remain unavailable, not look like zero activity.

## 2. Establish The Real Shell Host

- [ ] Keep the isolated native preview, and add a separate production entry point with real layer-shell panels and desktop wallpaper surfaces.
- [ ] Handle each output's placement, scaling, exclusive zones, panel focus and popup input correctly. Verify ultrawide and multi-monitor behavior, output removal/reconnection and shell reloads.
- [ ] Wire actual application discovery/launch, dock groups, workspace/window state and Hyprland focus/move/close operations. Launcher Run/Files providers still need implementation and explicit command behavior.
- [ ] Connect compositor-level shortcuts without conflicting with existing bindings. Settings shortcuts in the preview are not proof of global shortcut ownership.
- [ ] Add reviewed startup/deployment configuration only after the production host is usable. Do not autostart the FloatingWindow preview as the desktop shell.

## 3. Connect Services Incrementally

- [ ] Validate existing live audio, display, network, power, battery and telemetry adapters read-only first. Enable service-changing controls separately and test failure/pending states.
- [ ] Complete Wi-Fi scan/saved-network collection and remaining Bluetooth/device and quick-control backends. Keep credentials in the external system editor.
- [ ] Connect a weather provider and persist approved location settings.
- [ ] Connect real media and activity-notch state. Clearly separate timers from externally observed inference, transfers and recording/sharing.
- [ ] Select/connect a clipboard-history backend with persistence, retention limits, exclusions and privacy controls. Preview history must not silently become host clipboard capture.
- [ ] Validate notification-server ownership and actions before replacing another daemon. Decide whether history persistence is wanted.
- [ ] Apply wallpaper/profile changes to the real desktop; validate missing files and extraction failures. Synchronizing the upstream overview and optional terminal theme remains separate work.
- [ ] Implement real profile policies only after each owning backend is verified; saving a draft must not imply a successful host action.

Safety: display rollback currently uses an in-process timer, not crash-safe recovery. Do not rely on it as the only protection during target display testing.

## 4. Validate Third-Party Tools

- [ ] Follow [Workspace Overview](overview.md): start the pinned module, test toggle/open/close, Super+Tab, window focus/dragging and both monitors. Test missing process/dependency handling; avoid duplicate overview instances.
- [ ] Enable the dock overview action with `QUICKSHELL_ENABLE_HOST_OVERVIEW=1` only in the target Quickshell session. WSL's native preview intentionally does not launch it.
- [ ] Install HyprQuickshot and its providers using the [setup guide](../README.md#hyprquickshot). Test selection, editing, saving and clipboard behavior with explicit `QUICKSHELL_ENABLE_HOST_CAPTURE=1` opt-in.
- [ ] Verify Material Color Utilities extraction through the Quickshell process adapter, not just PySide tests. Check rapid wallpaper changes and fallback with missing/unreadable images.

## 5. Locking, Idle And Local AI

- [ ] Accept the custom locker's real lock/unlock, multi-monitor and recovery behavior. The production entry uses Wayland session locking and PAM; the standalone preview remains a simulation and must never receive a real password. Idle/suspend integration remains pending.
- [ ] Decide vLLM version, endpoint, supervisor, model presets, GPU assignments and stop/drain policy using [Local AI](local-ai.md).
- [ ] Add read-only runtime observations, measured per-GPU telemetry and validated output tokens/sec before enabling lifecycle actions.
- [ ] Implement start/stop/model switching for explicitly owned instances, including readiness mismatch, timeout, OOM, stale metrics and shell-restart handling.
- [ ] Connect verified active inference to idle inhibitors. A loaded but idle model must not automatically block suspend; locking remains allowed.

## 6. Remaining UI And Assets

- [ ] Implement the visual tiling/zone editor with drag handles and production app matching/placement. Current layout presets, ratios and app rules are not a freeform editor. Verify native Hyprland layout support before choosing a plugin.
- [ ] Import the remaining 12 requested wallpaper originals once local files or direct URLs are available. Nineteen requested imports are already registered alongside three original fixtures.
- [ ] Reconcile older [preview workflow notes](preview-workflow.md) with current behavior; its old suite counts, palette sampler description and some UI descriptions are historical, not current status.
- [ ] Review asset redistribution rights and project licensing before publication. The pinned overview has no LICENSE/COPYING file; public availability does not establish a redistribution license.

## 7. Acceptance And Deployment

- [ ] Run `uv run python -m unittest discover -s tests -v` after final integration changes. Recent focused tests do not replace a fresh complete run.
- [ ] Test login, restart, crash/relaunch, unavailable providers, suspend/resume, secure locking, monitor hotplug and fractional scaling on CachyOS.
- [ ] Verify both GPUs by stable identity, sensor gaps, process data and measured usage during gaming/inference. Measure polling/rendering overhead; WSL software rendering is not a performance benchmark.
- [ ] Check overview and shell behavior with ordinary apps and fullscreen games. Confirm input focus, keyboard navigation and no duplicate bars/notification servers.
- [ ] Deploy selected dotfiles with reviewed includes or optional chezmoi. Validate Kitty/Fastfetch and shell configuration on target; do not overwrite whole existing configurations.
- [ ] Document the final startup command and rollback steps. Remove only this shell's startup/includes when rolling back; do not kill unrelated Quickshell processes.

Recommended sequence: target inventory, real shell host, read-only services, explicit controls, security/AI, then daily-use acceptance and deployment. Live desktop acceptance must be recorded here as it is actually completed.