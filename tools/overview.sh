#!/usr/bin/env bash
set -euo pipefail

action="${1:-toggle}"
if (( $# > 1 )) || [[ "$action" != start && "$action" != toggle && "$action" != open && "$action" != close ]]; then
    printf 'Usage: bash tools/overview.sh [start|toggle|open|close]\n' >&2
    exit 2
fi

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    printf 'Workspace overview requires a running Hyprland session.\n' >&2
    exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
overview_path="$repo_root/third_party/quickshell-overview/shell.qml"
if [[ ! -f "$overview_path" ]]; then
    printf 'Overview dependency missing. Run git submodule update --init --recursive in the checkout.\n' >&2
    exit 1
fi

if command -v quickshell >/dev/null 2>&1; then
    executable=quickshell
elif command -v qs >/dev/null 2>&1; then
    executable=qs
else
    printf 'Install Quickshell before starting workspace overview.\n' >&2
    exit 1
fi

if [[ "$action" == start ]]; then
    exec "$executable" -p "$overview_path" -n
fi
exec "$executable" ipc -p "$overview_path" call overview "$action"