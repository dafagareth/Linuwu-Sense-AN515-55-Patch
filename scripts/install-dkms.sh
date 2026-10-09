#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODNAME="linuwu_sense"
MODULE_VERSION="$(awk -F'"' '/^PACKAGE_VERSION=/{print $2}' dkms.conf)"
REAL_USER="${SUDO_USER:-$(whoami)}"

if [[ -z "$MODULE_VERSION" ]]; then
  echo "Error: could not read PACKAGE_VERSION from dkms.conf" >&2
  exit 1
fi

if ! command -v dkms >/dev/null 2>&1; then
  echo "Error: dkms is not installed. Install it first, e.g.:" >&2
  echo "  sudo pacman -S dkms        # Arch / CachyOS" >&2
  echo "  sudo apt install dkms      # Debian / Ubuntu" >&2
  echo "  sudo dnf install dkms      # Fedora" >&2
  exit 1
fi

echo "==> DKMS: registering $MODNAME v$MODULE_VERSION (clean/replace if present)"
sudo dkms remove -m "$MODNAME" -v "$MODULE_VERSION" --all 2>/dev/null || true
sudo dkms add "$ROOT_DIR"

echo "==> DKMS: building for kernel $(uname -r)"
sudo dkms build -m "$MODNAME" -v "$MODULE_VERSION"

echo "==> DKMS: installing"
sudo dkms install -m "$MODNAME" -v "$MODULE_VERSION"

echo "==> Blacklisting stock acer_wmi (conflicts with this driver)"
sudo rmmod acer_wmi 2>/dev/null || true
echo "blacklist acer_wmi" | sudo tee /etc/modprobe.d/blacklist-acer_wmi.conf > /dev/null

echo "==> Enabling module auto-load at boot"
echo "$MODNAME" | sudo tee /etc/modules-load.d/$MODNAME.conf > /dev/null

echo "==> Installing systemd service (unloads module on shutdown)"
sudo cp "$ROOT_DIR/linuwu_sense.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable linuwu_sense.service

echo "==> Loading module"
sudo modprobe "$MODNAME"
sudo systemctl start linuwu_sense.service 2>/dev/null || true

echo "==> Setting up group and permissions"
if ! getent group "$MODNAME" >/dev/null 2>&1; then
  sudo groupadd "$MODNAME"
fi
sudo usermod -aG "$MODNAME" "$REAL_USER"
echo "Group linuwu_sense ready; user '$REAL_USER' added (re-login may be needed)."

echo "==> Setting permissions via tmpfiles.d"
model_path="$(ls /sys/module/$MODNAME/drivers/platform:acer-wmi/acer-wmi/ 2>/dev/null \
  | grep -E 'predator_sense|nitro_sense' || true)"
if [[ -n "$model_path" ]]; then
  echo "Detected model directory: $model_path"
  conf_file="/etc/tmpfiles.d/$MODNAME.conf"
  [[ -f "$conf_file" ]] || sudo touch "$conf_file"
  if echo "$model_path" | grep -q "nitro_sense"; then
    supported_fields="fan_speed battery_limiter battery_calibration usb_charging"
  else
    supported_fields="backlight_timeout battery_calibration battery_limiter boot_animation_sound fan_speed lcd_override usb_charging"
  fi
  for f in $supported_fields; do
    entry="f /sys/module/$MODNAME/drivers/platform:acer-wmi/acer-wmi/$model_path/$f 0660 root $MODNAME"
    grep -qxF "$entry" "$conf_file" || echo "$entry" | sudo tee -a "$conf_file" > /dev/null
  done
  kb_base="/sys/module/$MODNAME/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb"
  if [[ -d "$kb_base" ]]; then
    for z in four_zone_mode per_zone_mode brightness; do
      entry="f $kb_base/$z 0660 root $MODNAME"
      grep -qxF "$entry" "$conf_file" || echo "$entry" | sudo tee -a "$conf_file" > /dev/null
    done
  fi
  sudo systemd-tmpfiles --create "$conf_file"
else
  echo "Warning: could not detect predator_sense/nitro_sense in sysfs"
fi

echo
echo "==> DKMS status =="
dkms status "$MODNAME"
echo "==> Installed module =="
modinfo "/lib/modules/$(uname -r)/updates/dkms/$MODNAME.ko" | grep -E 'filename|srcversion|vermagic'
echo
echo "Install complete. DKMS will rebuild the module automatically on kernel updates."
echo "Verify shortly after a kernel update with: dkms status $MODNAME"
