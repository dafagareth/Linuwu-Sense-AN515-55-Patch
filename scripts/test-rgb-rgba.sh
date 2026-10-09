#!/usr/bin/env bash
set -euo pipefail

BASE="/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi"
RGB_PATH="$BASE/four_zoned_kb/per_zone_mode"

if [[ ! -w "$RGB_PATH" ]]; then
  echo "RGB path is not writable: $RGB_PATH" >&2
  echo "Run with sudo and make sure linuwu_sense is loaded." >&2
  exit 1
fi

# zone1: red 100%, zone2: green 25%, zone3: blue 50%, zone4: white 12%
printf '%s\n' 'ff0000ff,00ff0040,0000ff80,ffffff20,100' > "$RGB_PATH"
cat "$RGB_PATH"
