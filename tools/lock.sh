#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
exec 9>"${XDG_RUNTIME_DIR:?}/custom-shell-lock.lock"
flock -n 9 || exit 0

if ! env QUICKSHELL_LOCK_VALIDATE_ONLY=1 QT_QUICK_BACKEND=software timeout 12 quickshell -p "$root/lock.qml" --no-color; then
    exec hyprlock
fi

if ! env -u QUICKSHELL_LOCK_VALIDATE_ONLY QT_QUICK_BACKEND=software quickshell -n -p "$root/lock.qml" --no-color; then
    exec hyprlock
fi