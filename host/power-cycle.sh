#!/usr/bin/env bash
set -euo pipefail

current=$(powerprofilesctl get 2>/dev/null || printf 'balanced')
case "$current" in
  performance) next=balanced ;;
  balanced) next=power-saver ;;
  power-saver) next=performance ;;
  *) next=balanced ;;
esac
powerprofilesctl set "$next"
