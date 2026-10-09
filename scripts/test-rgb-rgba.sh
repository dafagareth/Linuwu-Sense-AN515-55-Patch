#!/usr/bin/env bash
set -euo pipefail

BASE="/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi"
RGB_PATH="$BASE/four_zoned_kb/per_zone_mode"

if [[ ! -w "$RGB_PATH" ]]; then
  echo "RGB path is not writable: $RGB_PATH" >&2
  echo "Run with sudo and make sure linuwu_sense is loaded." >&2
  exit 1
fi

echo "Testing RGBA 8-digit transparency input..."
# zone1: red 100%, zone2: green 25% (0x40), zone3: blue 50% (0x80), zone4: white 12% (0x20)
payload="ff0000ff,00ff0040,0000ff80,ffffff20,100"
expected="ff0000,004000,000080,202020,100"

printf '%s\n' "$payload" > "$RGB_PATH"
actual="$(cat "$RGB_PATH")"

echo "Readback: $actual"
if [[ "$actual" != "$expected" ]]; then
  echo "Assertion failed: expected $expected, but got $actual" >&2
  exit 1
fi

echo "RGBA alpha scaling verified successfully."
