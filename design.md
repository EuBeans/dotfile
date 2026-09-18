# Quickshell Design

Hallmark pre-emit critique: Philosophy 5, Hierarchy 4, Execution 4, Specificity 5, Restraint 5, Variety 4.

## Direction

Confirmed with the user on 2026-09-18: a personal CachyOS/Hyprland control panel, compact, technical and utilitarian. Preserve the existing theme. Genre: modern-minimal with pixel typography. App structure: Workbench. Native QML, not a website; no marketing sections, decorative illustrations, CSS exports, or fake browser chrome.

## Tokens

The authoritative runtime tokens live in shell/Components/Theme.qml. All views use its named paper, ink, muted, line, hover, accent, surface and groupSurface colors and displayFont/textFont. Monocraft is the display face; JetBrains Mono is the text face. Do not introduce new fonts or per-tab themes. Graph series may use named visualization tokens for distinction; do not use those colors decoratively.

Use the existing 4-point spacing rhythm (4, 8, 12, 16, 24). Headings inside panels are compact, generally 14-18px; data and controls are 11-13px. Letter spacing is zero. Existing six-pixel control radii and scale-aware focus outlines remain. No nested cards or floating section containers.

## Structure

Keep the Home icon-only rail: Home, Audio, Displays, Network, System, Power, Weather, Notifications, and anchored Settings. Displays uses the monitor icon formerly used by Workspaces. Do not restore Workspace, Personalize, Calendar, or Media tabs. Existing standalone panels remain available.

Use unframed sections, restrained separators, clear primary readings, aligned controls and compact supporting detail. Tool actions use bundled Lucide icons with accessible names and tooltips. Real commands may use short text. Do not fill the UI with feature explanations, development notes, or decorative section numbering.

System has exactly four shared multi-series graphs: CPU, Memory, GPU, Network. All GPUs contribute lines to the one GPU graph. All four legends use one bounded, horizontally scrollable row of icons with visible short values and units (`--` when unavailable); names and scales belong in tooltips and accessibility text. Chart and legend tones derive only from the active palette, monochrome for neutral themes, with dash patterns for series distinction; network directions share a scale. Preserve freshness checks and missing-sensor gaps. System Information, Resources, processes and storage follow the graphs.

## States And Safety

Retain keyboard focus, hover, pressed, selected, disabled, pending, error and empty states where applicable. Success is quiet. No fabricated live data or optimistic claims of unavailable services. Native preview stays non-destructive; changes to host services require existing explicit opt-ins. Weather provider is not connected. Passwords stay outside the shell in NetworkManager's editor.

Respect existing reduced-motion settings. Do not add decorative motion. Preserve public signals, object names used by tests and existing action guards unless a focused defect requires repair.

## Verification

Use native QtTest and screenshots, not browser Playwright. Check widths 320, 375, 414 and 768, plus desktop where relevant. No horizontal overflow, overlapping labels, unstable button dimensions, clipped focus borders or QML warnings. Test populated and unavailable states. Capture actual native output; never substitute mock HTML. The Quickshell/Hyprland runtime is not installed in this WSL environment and remains unverified.