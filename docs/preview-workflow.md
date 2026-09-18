# WSL Preview Workflow

Implementation started: 2026-09-18. This is a development preview, not an installed desktop shell.

Current status: contextual-media top bar, content-sized workspace/app bottom bar, Home dashboard, profile-owned settings and safe switching, movable/tileable System Summary, wallpaper/calendar/launcher, independent Alt-Tab, Tile Manager, clipboard/audio fixtures and preview-only Screenshot Manager. The latest suite result is 49 passing out of 50 native Qt tests; screenshot-library retention remains broken. The Qt-only runner loads in WSLg; Quickshell and real Hyprland integrations remain unverified. See [launch instructions](../README.md), [terminal summary](terminal-summary.md) and [local AI specification](local-ai.md).

## First Milestone

The initial milestone was one native window containing a top bar, wallpaper picker, and font specimen. Later approved work adds a separate content-sized bottom bar. Use actual shared QML views, not an HTML imitation. Preview controls sit outside the simulated desktop.

The bottom bar shows a compact numbered workspace strip beside app groups, with the current workspace highlighted. The numbers come from the window manager (currently fixture IDs 1, 2, 4 and 7). Open windows are grouped by application across all workspaces and monitors. A single-window app focuses immediately; a multi-window app opens a compact picker above the bar, with 4px row gaps and workspace labels; tooltips include monitor destinations. Desktop labels include group counts; compact layouts use icons with counts in tooltips. The launcher and screenshot controls remain. There are no mode switches, workspace-scope toggle or System shortcut. System information remains available through the top CPU button and Home.

The visual direction remains off-white/black, selective Monocraft accents, and one readable companion font. Font pairing and bar geometry are proposals for review, not final selections.

### Additional Minimalist Reference

https://dotfiles.lol/rices/reddit-y89dho : "[ Hyprland ] Any minimalists here?", u/sarveshrulz, 2022-10-19. Gallery metadata lists Waybar, dunst, foot, pfetch and Rofi; source link: https://github.com/sarveshrulz/nixos . The supplied screenshot suggests compact separated bar groups, small anchored menus, pale inverted selection rows and restrained decoration. Its lower collage shows separate interaction states, not additional desktop bars. These are density/interaction references, not an approved replacement for the earlier notched bar. Do not copy its artwork, purple palette, red accent or laptop-specific widgets. Fonts, motion, maintenance and source licensing have not been audited.

## Architecture

- `shell/Components` and `shell/Modules`: presentation receiving state and emitting intents.
- `preview`: deterministic fixtures and host composition. No system service imports or process execution.
- `preview/shell.qml`: Quickshell `FloatingWindow` host.
- `preview/QtHost.qml`: temporary Qt-only development host for machines without Quickshell. It loads exactly the same views; it does not replace the Quickshell production architecture.
- Production layer-shell windows and real service adapters will be added separately after visual review.

Mock service actions change in-memory fixture state only. Profiles, appearance, tiling preferences, wallpaper folder and shortcut overrides persist in XDG configuration storage. The folder picker reads user-selected local images. Never connect preview controls to shutdown, locking, network changes, authentication, host clipboard capture, application execution, or desktop wallpaper-setting commands.

Home has separate Wallpaper, Appearance, and Profiles pages. Wallpaper selects images and folders; Appearance selects saved palettes or wallpaper-derived colors. The gamepad icon opens Profiles for switching, creating, saving/reverting, and policy/category copying. These pages stay inside Home. The standalone wallpaper drawer and full Settings window retain their existing controls. Home quick controls are checkable icon tiles: Wi-Fi, Bluetooth, caffeine, night light, DND and power saver. All affect fixture state only; caffeine, night light and power saver reset with the preview. Weather is explicitly unavailable. Calendar and notification settings also have sidebar entries.

Home sits at the far left of the top bar followed by date/time. Its panel opens from the left below the bar, attached or floating with a 12-pixel inset according to panel placement, and includes an embedded System Summary page. The center notch shows ongoing activities and closes when none remain. Music resume is available from Home or the preview toolbar's Music switch. Reveal and page-change motion follow the shared stepped/smooth/off and reduced-motion settings. Workspace/app controls live only in the bottom bar. Audio, Wallpaper and Settings load inside Home without closing its sidebar. Settings uses a compact category selector; Ctrl+Alt+S still opens the standalone native window. Power and profile selection are accessed inside Home. GPU, AI, audio and Wallpaper remain on the right bar; standalone audio and wallpaper panels share state with Home. Network and Bluetooth views expose fixture radio state and explicitly unavailable backend/device information. The clock opens the calendar; calendar clicks normalize date-only Qt values to local noon before keyboard navigation, avoiding UTC/local date shifts.

Home's timer icon beside the profile selector opens Activities. Start a countdown, simulate an AI task, transfer, recording or screen share, or trigger an urgent alert. The notch's right chevron cycles only active entries, with a position count and next-activity tooltip. Background additions preserve selection; completion chooses another activity or closes the notch. Urgent alerts temporarily select themselves and return after dismissal or eight seconds; timer completion also produces an alert. Paused timers/transfers remain active. AI progress is hidden until explicitly available. Simulated AI tasks contribute to the preview request count and cancel when that model stops. Recording/sharing stays indicated on the right while another notch page is selected. Below 640px, the notch is hidden and Home retains controls. All lifecycle data is fixture-only, with no capture, upload, download, calling or AI process execution. Ordinary notifications do not enter the notch.

Bar controls use icons, with optional labels appearing as space permits. CPU and both GPUs always retain their percentages (or `N/A` when telemetry is unavailable); CPU opens Home's System page and each GPU opens its own details. Below 640px the right group moves to a second row. The notch also hides whenever the remaining centered space is under 160px; Home retains activity controls and the recording indicator remains visible. Compact bottom-bar apps show icons instead of names. All metrics remain preview fixtures.

Settings > Desktop > Top bar placement has independent Attached/Floating choices for Left, Middle and Right. Attached side sections meet the top and their respective screen edge, with square edge corners; the middle uses the attached notch shape or a floating rounded surface. At narrow stacked widths, an attached right section connects to the top along the right edge. Bar placement is separate from drawer placement and belongs to the active profile's appearance, including Save/Revert, copying and persistence. Existing defaults remain floating sides and an attached middle. The bottom bar is unchanged.

The bar's audio button opens a scrollable mixer with master output volume/mute and independent application volume/mute. Muting preserves the stored level. Application rows use stable IDs, support live additions/removals, and show an empty state when no audio apps exist. The current Music, Firefox, and Discord rows are fixtures; reset/reload restores their defaults. Real application discovery and audio changes require a production PipeWire adapter on CachyOS. Only apps exposing audio streams can be mixed, not every open window.

## Feedback Loop

1. Launch the native preview through WSLg.
2. Edit shared QML and reload.
3. Interact with workspace, profile, media, volume, and wallpaper fixtures.
4. Inspect both 1920 x 1080 and 5120 x 1440 logical layouts. Fit mode checks composition; 1:1 mode with scrolling checks legibility.
5. Capture deterministic screenshots and retain approved baselines outside source control until an intentional visual-test policy is chosen.

## Settings Organization

Settings opens in its own native window, with Appearance selected initially. The sidebar order is Appearance, Themes / Profiles, Desktop, Motion, Shortcuts, Audio, Notifications, Local AI, and System. Each page has independently collapsible sections; collapse state survives category changes within the current window instance. Section headers support pointer and keyboard activation. Navigation cancels any active shortcut recording.

Appearance contains glass, opacity, and corners. Desktop contains panel placement, tiling mode (Auto, Split, Columns, Centered), main-pane width, window-border width, and inner/outer gaps. Numeric controls pair draggable sliders with editable number fields and increment/decrement buttons. Changes update the active profile draft immediately and persist on Save; they do not change real Hyprland windows. Auto chooses Split on ordinary widths and Centered on ultrawide layouts; narrow previews stack windows vertically. Main-pane width is disabled for Columns.

Motion contains reduced motion and animation preferences. Themes / Profiles retains profile creation, named palettes, wallpaper-derived colors, and wallpaper selection. Audio and Notifications share the preview's master audio and DND state. Local AI and System expose current runtime/status information; unconnected device and service integrations are labelled as such, not presented as functioning settings.

Profiles use versioned local storage with independent appearance, tiling, AI, notifications and optional audio groups. Save commits a draft; Revert restores the saved version. Drafts survive profile switches within a session but not reloads. Copying requires preview/confirmation and supports one-level undo; appearance copying includes palette and wallpaper. Switching is immediate unless active requests would be affected by an AI policy change, when wait, cancel requests, or keep AI unchanged are offered. In-progress AI transitions block application. Policies apply on switching, not simply on Save. Master audio, DND and reduced-motion runtime overrides remain session-only; profile policies can set audio/notification state when applied. Shortcut overrides remain global. The default settings window is 920 x 760, with a supported minimum of 660 x 540; navigation and page content scroll independently.

## Wallpaper Folders

The wallpaper panel includes saved palette swatches, wallpaper-derived colors, a native folder chooser, the current folder path, and a clear-folder action. A clipped, virtualized thumbnail grid combines the three bundled images with PNG, JPEG, WebP and BMP files from the selected folder. Loading and empty-folder states are visible; unreadable thumbnails show an unavailable state and cannot be selected.

Wallpaper-derived colors use an in-process, alpha-weighted image average with restrained light/dark tints. Cached image reselection explicitly repaints the sampler; transparent pixels do not dilute its colors. Tests verify red/blue image changes, repeated selection, transparency and switching back to saved colors. This is not a dominant-color or Material You generator. [Matugen](https://github.com/InioX/matugen) supports image-derived palettes and JSON export and is a production integration candidate, but is not installed or invoked by the preview.

Settings > Desktop > panel placement controls all side panels: Home, calendar and power attach left; GPU, audio, wallpaper and AI attach right. Attached panels reveal horizontally with flush edge corners; floating mode restores margins and rounded corners. Bar groups use the same opaque theme ink surface, with transparent idle buttons, theme hover fill, and paper fill/ink foreground for pressed or selected buttons. Glass opacity still applies to panels and windows.

The folder is global; wallpaper file URLs and palettes belong to the active profile. Selection uses the file URL rather than its changing sort index. Clearing the folder or losing a selected file falls back to the profile's bundled wallpaper without discarding the stored custom URL. Tests exercise sorting, file additions/removals, equal-sized folder changes, missing folders, profile isolation and reload persistence. Native operating-system folder-dialog interaction and corrupt-image behavior still require manual verification.

## Launcher Preview

The search icon in the preview toolbar opens seven fixture apps, including System Summary. Search is case-insensitive across names, categories and keywords; multiple words must all match. Arrow keys select results, Enter activates, and Escape closes with focus returned to the toolbar trigger. Pointer activation, empty results, search clearing and animated open/close are supported.

Activation records the fixture app ID, opens a synthetic window in the window model, and emits a preview notification. No processes execute. The configurable launcher shortcut starts unassigned; the final production shortcut, placement and search providers remain undecided. Real app discovery and execution need a separate production adapter.

## Switching Versus Tiling

These are separate tools, not two views of one manager:

- Alt-Tab is for focus only. It snapshots recent-window order while cycling; repeated Tab advances, Shift-Tab reverses, releasing Alt commits, and Escape cancels. It works even when tiling fixtures are hidden. It never edits window order, placement, floating state or app rules. Closed candidates are removed safely. Clicking the circular-arrows toolbar button also opens the switcher; click a window or press Enter to commit in that mode.
- Tile Manager is for arranging windows. Its separate panels toolbar icon opens a searchable list grouped by fixture monitor and workspace. Rows provide focus, close, monitor/workspace destinations, tile position, floating and app-rule pinning. A second tab edits saved app-slot rules. Its optional shortcut starts unassigned.

Window IDs are stable while open. The model distinguishes all windows from the current monitor/workspace's windows. The preview launcher creates windows; closing them removes only fixtures, never real applications. Layouts support changing window counts, with single-window expansion and gap-free reflow. Tile Manager reads monitor names from `Qt.application.screens` and updates destinations when screens change. Unnamed screens use `Display N`. WSLg may expose virtual display names instead of physical connectors. Disconnecting a display moves its fixture windows to the first remaining screen; saved app rules stay dormant until their destination reconnects. Old `primary`/`upper` rules are retained but must be reassigned to a detected display. Detection is read-only and never changes compositor configuration.

App rules belong to the active profile draft as app ID, monitor, workspace and preferred tile index. Legacy global rules migrate once; save the profile to persist later edits. Switching rules leaves existing windows in place. Rules reclaim the slot when a matching app opens and release space when it closes; no placeholder is created for an absent app. Pinning an existing app applies its destination immediately. The first non-floating matching window takes the preferred tile; additional windows use remaining positions. Conflicting app rules for one tile are rejected. Missing higher-numbered slots clamp to the available range. Manual moves can temporarily override the destination until a new matching window opens. Tile numbers refer to the selected layout's positions, not arbitrary pixel rectangles.

The native tests verify switching without changing rules/order, cancellation while Tile Manager stays open, reverse/MRU cycling, disappearing candidates, empty state, cross-workspace focus, saved-rule reload and one-to-seven-window geometry. WSLg or the host desktop may intercept physical Alt-Tab before Qt receives it. Production requires compositor-level bindings and input handling; offscreen tests do not establish global shortcut ownership.

### Production Layout Direction

Keep Hyprland as the window manager and Quickshell as its UI. First verify the installed Hyprland/Quickshell versions and actual output identities. Prefer native window operations and the compositor's layout engine over moving tiled windows with arbitrary floating-window coordinates.

The current [Hyprland custom-layout documentation](https://wiki.hypr.land/Configuring/Layouts/Custom-Layouts/) describes Lua layout registration with `hl.layout.register`, target placement, and row/column/grid/split helpers. Investigate that native capability for saved custom zones and conditional app assignment on a supported target version. It is not evidence that the uninspected target installation supports those APIs. Use a separate layout plugin only if required capabilities are missing and its version compatibility, source and stability have been checked. No plugin has been selected or installed.

Still pending: a visual split/zone editor with drag handles, stable production app matching, output hotplug/scaling behavior, grouping/transient-window policy, and the production event-driven placement adapter. Current custom arrangements are layout choice, main-pane ratio, tile ordering and app rules, not a freeform zone editor.

## Clipboard And Capture

The user confirmed two separate tools. Clipboard History currently previews text and image entries, search, pin/unpin, copy intents, deletion and confirmed clear-unpinned. Pinning protects entries from bulk clearing. Entries and copy results are session-only fixtures; no host clipboard reads/writes or background collection occur. Production needs a verified history backend (an existing tool such as cliphist remains a candidate), reboot persistence, retention limits, exclusions and privacy controls before enabling capture of real clipboard contents.

[HyprQuickshot](https://github.com/JamDon2/hyprquickshot) is the screenshot implementation, not merely a reference and not a clipboard-history implementation. The bottom scissors action forwards to the host; the separate custom capture drawer, region selector and export pipeline are no longer instantiated by the desktop. Legacy capture component/state files remain unused by this action. No upstream code has been copied or installed.

The Quickshell host launches the upstream command `quickshell -c hyprquickshot -n` only on an explicit click when `QUICKSHELL_ENABLE_HOST_CAPTURE=1` and `HYPRLAND_INSTANCE_SIGNATURE` is present. HyprQuickshot must already be installed as a separate Quickshell configuration with `grim`, ImageMagick and `wl-clipboard`. It owns capture, editing, saving and clipboard operations; `HQS_DIR` configures its output folder. Native PySide6 preview instead reports unavailability and never starts the tool or captures the host. Tests verify the signal handoff, absence of the custom drawer, and unchanged capture/clipboard state. Real Hyprland execution remains unverified here; see the README setup section. The old temporary-image retention issue is not repaired and no longer lies on the screenshot action path.

## Verification Boundaries

WSL preview can validate layout, fonts, clipping, focus, keyboard/pointer interactions, and presentation state changes. It cannot prove layer-shell placement, Hyprland IPC, PAM security, GPU telemetry accuracy, recording, idle inhibitors, suspend, or gaming/inference overhead.

Validate compositor behavior in real Hyprland. Validate dual-GPU behavior, both physical outputs, performance, locking, login, and suspend on the CachyOS workstation. A nested compositor or VM is optional later, not a first-milestone dependency.

## Environment Evidence

Checked 2026-09-18: Ubuntu 24.04 under WSL2, WSLg display variables and Wayland/X11 sockets available. No Qt or Quickshell executable on PATH. `uv` is available. The local runner uses pinned PySide6 wheels in a project virtual environment, without changing system packages. Quickshell-host validation remains a separate gate.

PySide6 6.8.3 is now installed in the local virtual environment. WSLg initially emitted EGL/Mesa warnings, so the runner defaults to software rendering. Package downloads required the system certificate store (`uv --system-certs`). No privileged commands, system package changes or target deployment were performed. Watch mode recreates the engine and resets transient fixtures; QtCore.Settings preferences survive reload. External preference-file live watching is not implemented.

## Next Milestones

1. Review the completed preview geometry, font roles, settings, launcher placement and shortcut choices.
2. Verify a supported Quickshell runtime and its host; introduce real services individually on Hyprland, including PipeWire and application discovery.
3. Target-machine integration, hardware, security, performance and chezmoi deployment validation.

The broader component plan remains in the existing untitled planning document; this file records the implementation workflow without superseding its unresolved decisions.