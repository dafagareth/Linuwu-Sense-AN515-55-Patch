#!/usr/bin/env bash
set -euo pipefail

BASE="/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi"
BRIGHTNESS_PATH="$BASE/four_zoned_kb/brightness"

if [[ ! -w "$BRIGHTNESS_PATH" ]]; then
  echo "Brightness path is not writable: $BRIGHTNESS_PATH" >&2
  echo "Run with sudo and make sure linuwu_sense is loaded." >&2
  exit 1
fi

val="${1:-}"

if [[ -n "$val" ]]; then
  printf '%s\n' "$val" > "$BRIGHTNESS_PATH"
  echo "Brightness set to: $(cat "$BRIGHTNESS_PATH")%"
else
  echo "Testing brightness adjustments (30% -> 70% -> 100%)..."
  for b in 30 70 100; do
    printf '%s\n' "$b" > "$BRIGHTNESS_PATH"
    echo "Current brightness: $(cat "$BRIGHTNESS_PATH")%"
    sleep 1
  done
fi
