#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

read -r total available < <(awk '
  /^MemTotal:/ { total=$2 }
  /^MemAvailable:/ { available=$2 }
  END { print total, available }
' /proc/meminfo)

ram_used=$((total - available))
ram_percent=$(( total > 0 ? ram_used * 100 / total : 0 ))

gpu_usage="null"
gpu_temp="null"
if command -v nvidia-smi >/dev/null 2>&1; then
  read -r gpu_usage gpu_temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
    --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)
  [[ "$gpu_usage" =~ ^[0-9]+$ ]] || gpu_usage="null"
  [[ "$gpu_temp" =~ ^[0-9]+$ ]] || gpu_temp="null"
fi

volume="null"
muted="false"
if command -v pactl >/dev/null 2>&1; then
  volume=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk 'NR==1 {gsub("%", "", $5); print $5}')
  pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q yes && muted="true"
fi
[[ "$volume" =~ ^[0-9]+$ ]] || volume="null"

network="offline"
if command -v nmcli >/dev/null 2>&1; then
  network=$(nmcli -t -f STATE general 2>/dev/null | cut -d: -f1 || true)
  [[ -n "$network" ]] || network="offline"
fi

battery="N/A"
if command -v upower >/dev/null 2>&1; then
  if upower -e 2>/dev/null | grep -q '/battery_'; then
    battery_info=$(upower -i /org/freedesktop/UPower/devices/DisplayDevice 2>/dev/null || true)
    battery=$(awk -F: '/percentage/ {gsub(/[ %]/, "", $2); print $2; exit}' <<<"$battery_info")
  fi
fi
[[ "$battery" =~ ^[0-9]+$ ]] || battery="N/A"

power_profile="N/A"
if command -v powerprofilesctl >/dev/null 2>&1; then
  power_profile=$(powerprofilesctl get 2>/dev/null || true)
  [[ -n "$power_profile" ]] || power_profile="N/A"
fi

jq -n \
  --argjson ramPercent "$ram_percent" \
  --argjson ramUsedMiB "$((ram_used / 1024))" \
  --argjson ramTotalMiB "$((total / 1024))" \
  --argjson gpuUsage "$gpu_usage" \
  --argjson gpuTemp "$gpu_temp" \
  --argjson volume "$volume" \
  --argjson muted "$muted" \
  --arg network "$network" \
  --arg battery "$battery" \
  --arg powerProfile "$power_profile" \
  '{ramPercent:$ramPercent,ramUsedMiB:$ramUsedMiB,ramTotalMiB:$ramTotalMiB,gpuUsage:$gpuUsage,gpuTemp:$gpuTemp,volume:$volume,muted:$muted,network:$network,battery:$battery,powerProfile:$powerProfile}'
