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

echo "==> Stopping systemd service and unloading module"
sudo systemctl stop linuwu_sense.service 2>/dev/null || true
sudo systemctl disable linuwu_sense.service 2>/dev/null || true
sudo rmmod "$MODNAME" 2>/dev/null || true

echo "==> Removing DKMS registration (module $MODNAME v$MODULE_VERSION)"
if command -v dkms >/dev/null 2>&1; then
  sudo dkms remove -m "$MODNAME" -v "$MODULE_VERSION" --all 2>/dev/null || \
    echo "  (not registered in DKMS, or already removed — continuing)"
else
  echo "  (dkms not installed — nothing to deregister)"
fi

echo "==> Removing systemd service file"
sudo rm -f /etc/systemd/system/linuwu_sense.service
sudo systemctl daemon-reload

echo "==> Removing boot auto-load, CLI tool, and stock-driver blacklist"
sudo rm -f /usr/local/bin/nitro
sudo rm -f /etc/modules-load.d/$MODNAME.conf
sudo rm -f /etc/modprobe.d/blacklist-acer_wmi.conf

echo "==> Removing installed module files (all kernels, both install paths)"
for kver_dir in /lib/modules/*/; do
  sudo rm -f "${kver_dir}updates/dkms/${MODNAME}.ko"
  sudo rm -f "${kver_dir}kernel/drivers/platform/x86/${MODNAME}.ko"
done
sudo depmod -a

echo "==> Removing tmpfiles.d permissions and linuwu_sense group"
sudo rm -f /etc/tmpfiles.d/$MODNAME.conf
if getent group linuwu_sense >/dev/null 2>&1; then
  sudo gpasswd -d "$REAL_USER" linuwu_sense 2>/dev/null || true
  sudo groupdel linuwu_sense 2>/dev/null || true
fi

echo "==> Restoring stock acer_wmi driver"
sudo modprobe acer_wmi 2>/dev/null || true

echo
echo "==> Post-uninstall status =="
echo "--- dkms status ---"
dkms status 2>/dev/null || true
echo "--- module loaded? ---"
if [[ -d "/sys/module/$MODNAME" ]]; then
  echo "$MODNAME is STILL LOADED (reboot, or: sudo rmmod $MODNAME)"
else
  echo "$MODNAME not loaded."
fi
echo
echo "Uninstall complete. Re-login (or reboot) to finish group cleanup."
