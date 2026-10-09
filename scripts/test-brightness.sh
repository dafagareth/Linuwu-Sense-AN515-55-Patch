#!/usr/bin/env bash
set -euo pipefail

BASE="/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi"
BRIGHTNESS_PATH="$BASE/four_zoned_kb/brightness"

if [[ ! -w "$BRIGHTNESS_PATH" ]]; then
  echo "Brightness path is not writable: $BRIGHTNESS_PATH" >&2
  echo "Run with sudo and make sure linuwu_sense is loaded." >&2
  exit 1
fi

assert_brightness() {
  local target="$1"
  printf '%s\n' "$target" > "$BRIGHTNESS_PATH"
  local actual
  actual="$(cat "$BRIGHTNESS_PATH")"
  if [[ "$actual" != "$target" ]]; then
    echo "Assertion failed: expected ${target}%, but read ${actual}%" >&2
    exit 1
  fi
  echo "Brightness verified: ${actual}%"
}

val="${1:-}"

if [[ -n "$val" ]]; then
  assert_brightness "$val"
else
  echo "Testing brightness adjustments (30% -> 70% -> 100%)..."
  for b in 30 70 100; do
    assert_brightness "$b"
    sleep 1
  done
  echo "All brightness tests passed successfully."
fi
