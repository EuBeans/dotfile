# Terminal System Summary

These optional files are not installed automatically. Fastfetch supplies detected system facts; Kitty supplies fonts, colors and background alpha. The desktop widget uses configured target facts and clearly marked preview telemetry instead. Neither source claims the upper display's refresh rate without detection.

## Target Setup

Install Kitty, Fastfetch and JetBrains Mono using the target CachyOS package manager. Preserve your existing configuration. Deploy `config/fastfetch/quickshell.jsonc` to `$XDG_CONFIG_HOME/fastfetch/quickshell.jsonc` (default `~/.config/fastfetch/quickshell.jsonc`). Test it manually with `fastfetch --config ~/.config/fastfetch/quickshell.jsonc`.

Include the repository's `config/kitty/quickshell.conf` from your Kitty configuration using an absolute `include` path, or deploy it alongside your Kitty configuration and use `include quickshell.conf`. This is the static Chalk palette, not a live link to preview profiles. No remote-control socket is enabled.

For Bash or Zsh, source `config/shell/summary.sh` from the interactive startup file using its absolute deployed path. For Fish, place `config/shell/summary.fish` in the Fish `conf.d` directory, or source it from the interactive configuration. Choose only the snippet for your shell. They require a Kitty window, an interactive shell, an available Fastfetch binary and a readable config. Noninteractive shells remain silent. The guard is shell-local, so each newly opened terminal gets its own summary.

The built-in CachyOS logo is supplied by Fastfetch; no third-party character art is copied. For matching bitmap artwork, Fastfetch also supports `logo.type: "kitty"` with an absolute image path and character-cell width/height. This requires verification inside Kitty and is not enabled by default.

## Verification Limits

The Fastfetch JSON is checked against the upstream schema and the Bash snippet is syntax-checked. Kitty, Zsh and Fish are not installed in the WSL preview environment; their runtime behavior and the target GPU/display detection remain unverified. No live startup files or compositor settings have been modified.