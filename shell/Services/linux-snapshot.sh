#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
command -v jq >/dev/null

mode=${1:-telemetry}
optional_json() {
    local result
    if result=$(timeout 3 "$@" 2>/dev/null) && jq -e . >/dev/null 2>&1 <<<"$result"; then
        printf '%s' "$result"
    else
        printf 'null'
    fi
}
if [[ "$mode" == telemetry ]]; then
    cpu=$(awk '/^cpu / {total=0; for(column=2;column<=9;column++)total+=$column; print total, $5+$6}' /proc/stat)
    memory=$(awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/ {gsub(":","",$1); print $1, $2*1024}' /proc/meminfo | jq -Rn '[inputs | split(" ") | {(.[0]): (.[1]|tonumber)}] | add')
    network=$(awk 'NR>2 {gsub(":"," "); if($1!="lo") print $1, $2, $10}' /proc/net/dev | jq -Rn '[inputs | split(" ") | {name:.[0], rx:(.[1]|tonumber), tx:(.[2]|tonumber)}]')
    temps='[]'
    for sensor in /sys/class/hwmon/hwmon*; do
        [[ -r "$sensor/name" ]] || continue
        name=$(<"$sensor/name")
        [[ "$name" == k10temp || "$name" == coretemp || "$name" == zenpower ]] || continue
        for input in "$sensor"/temp*_input; do
            [[ -r "$input" ]] || continue
            value=$(<"$input")
            [[ "$value" =~ ^[0-9]+$ ]] || continue
            temps=$(jq --argjson value "$value" '. + [$value/1000]' <<<"$temps")
        done
    done
    gpus='[]'
    processes='[]'
    if command -v nvidia-smi >/dev/null; then
        if raw=$(timeout 3 nvidia-smi --query-gpu=uuid,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null); then
            gpus=$(jq -Rn '[inputs | select(length>0) | split(",") | map(gsub("^ +| +$";"")) | {id:.[0], name:.[1:-5]|join(","), utilization:(.[-5]|tonumber? // null), usedMiB:(.[-4]|tonumber? // null), totalMiB:(.[-3]|tonumber? // null), temperature:(.[-2]|tonumber? // null), power:(.[-1]|tonumber? // null)}]' <<<"$raw")
        fi
        if raw=$(timeout 3 nvidia-smi --query-compute-apps=gpu_uuid,pid,process_name,used_gpu_memory --format=csv,noheader,nounits 2>/dev/null); then
            processes=$(jq -Rn '[inputs | select(length>0) | split(",") | map(gsub("^ +| +$";"")) | {gpu:.[0], pid:.[1], name:.[2:-1]|join(","), memoryMiB:(.[-1]|tonumber? // null)}]' <<<"$raw")
        fi
    fi
    read -r total idle <<<"$cpu"
    read -r uptime _ </proc/uptime
    read -r load1 load5 load15 _ </proc/loadavg
    jq -n --argjson total "$total" --argjson idle "$idle" --argjson memory "$memory" --argjson network "$network" --argjson temps "$temps" --argjson gpus "$gpus" --argjson processes "$processes" --argjson uptime "$uptime" --argjson load "[$load1,$load5,$load15]" '{cpu:{total:$total,idle:$idle,temperature:($temps|max)}, memory:$memory, network:$network, gpus:$gpus, processes:$processes, uptime:$uptime, load:$load}'
elif [[ "$mode" == devices ]]; then
    monitors=$(optional_json hyprctl -j monitors all)
    sinks=$(optional_json pactl -f json list sinks)
    sources=$(optional_json pactl -f json list sources)
    streams=$(optional_json pactl -f json list sink-inputs)
    audio=$(optional_json pactl -f json info)
    drives=$(optional_json lsblk --json --bytes --output NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,FSAVAIL,FSUSE%)
    devices=$(timeout 3 nmcli -t --escape no -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | jq -Rn '[inputs | split(":") | {name:.[0],type:.[1],state:.[2],connection:(.[3:]|join(":"))}]' || printf '[]')
    wifi=$(timeout 3 nmcli radio wifi 2>/dev/null || true)
    profile=$(timeout 3 powerprofilesctl get 2>/dev/null || true)
    profiles=$(timeout 3 powerprofilesctl list 2>/dev/null | awk '/^[ *]+[a-z-]+:/ {gsub("[* : ]", ""); print}' | jq -Rn '[inputs]' || printf '[]')
    batteries='[]'
    while IFS= read -r device; do
        [[ -n "$device" && "$device" != *DisplayDevice ]] || continue
        detail=$(timeout 3 upower -i "$device" 2>/dev/null || true)
        entry=$(jq -Rn --arg detail "$detail" '$detail | split("\n") | map(try capture("^ +(?<key>model|percentage|state|vendor|type): +(?<value>.*)$") catch empty) | map({(.key):.value}) | add // {}')
        if jq -e '.percentage' >/dev/null <<<"$entry"; then batteries=$(jq --argjson entry "$entry" '. + [$entry]' <<<"$batteries"); fi
    done < <(timeout 3 upower -e 2>/dev/null || true)
    cpu=$(awk -F ': ' '/model name/ {print $2; exit}' /proc/cpuinfo)
    jq -n --argjson monitors "$monitors" --argjson sinks "$sinks" --argjson sources "$sources" --argjson streams "$streams" --argjson audio "$audio" --argjson drives "$drives" --argjson devices "$devices" --arg wifi "$wifi" --arg profile "$profile" --argjson profiles "$profiles" --argjson batteries "$batteries" --arg kernel "$(uname -r)" --arg host "$(uname -n)" --arg cpu "$cpu" '{monitors:($monitors//[]), sinks:($sinks//[]),sources:($sources//[]),streams:($streams//[]), audio:$audio, drives:($drives.blockdevices//[]), network:$devices,wifi:($wifi=="enabled"),powerProfile:$profile,powerProfiles:$profiles,batteries:$batteries,kernel:$kernel,host:$host,cpu:$cpu}'
else
    printf 'Unknown snapshot type\n' >&2
    exit 2
fi