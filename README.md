# Linuwu-Sense fix for Acer Nitro 5 AN515-55

> Thanks to [fabiannabil1](https://github.com/fabiannabil1/Linuwu-AN515-58-Linuwu-Sense-Fix) for the 4-zone RGB patch this builds on.

This is a patched build of the original [Linuwu-Sense](https://github.com/0x7375646F/Linuwu-Sense), which stopped compiling on kernels `7.2` and newer after a sysfs API change ([details](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=079a028d6327e68cfa5d38b36123637b321c19a7)). It brings the module back to life on modern kernels and adds 4-zone keyboard RGB support.

Tested on:

- Model: `Acer Nitro 5 AN515-55`
- Kernel: `7.2.6-1-cachyos`
- Module: `linuwu_sense`

## What this patch does

- **4-zone RGB** (static + dynamic modes), ported from the AN515-58 fix:
  - per-zone static color via WMI method `6`, payload `{zone, red, green, blue}`
  - zone enabling via `SET_GAMING_LED` instead of `GET_GAMING_LED`
  - static-mode activation with a 16-byte payload to method `20`, same layout as `facer_rgb.py`
  - dynamic-mode payloads matching the Jafar implementation
  - breathing mode no longer forces `speed=0`
  - 8-digit RGBA (`RRGGBBAA`) support for per-zone transparency
  - dedicated `four_zoned_kb/brightness` sysfs node for 0-100% backlight dimming
- **Fan control**: the fan is driven directly through `fan_speed` — `0,0` for **Auto**, `100,100` for **Max**. No platform power-profile (quiet/balanced/...) exists on this model, and none is needed.
- **CLI Control Center (`nitro`)**: command-line tool for fans, RGB presets, brightness, and battery threshold control.

## Install

### Option 1 — AUR package (recommended, Arch-based)

On Arch Linux (or any Arch-based distro) the patched driver is packaged on the AUR as
[`linuwu-sense-an515-55-dkms`](https://aur.archlinux.org/packages/linuwu-sense-an515-55-dkms).
Grab it with your AUR helper:

```bash
yay -S linuwu-sense-an515-55-dkms
# or:
paru -S linuwu-sense-an515-55-dkms
```

The package builds this repo's latest `main` through DKMS, so it behaves just like the
source-based DKMS install below:

- Rebuilds automatically on every kernel update
- Module lands at `/lib/modules/$(uname -r)/updates/dkms/linuwu_sense.ko`
- Blacklists the stock `acer_wmi` driver so it doesn't conflict
- Enables auto-load on boot + the `linuwu_sense` systemd service
- Sets up the `linuwu_sense` group and `tmpfiles.d` permissions

Check the result:

```bash
dkms status linuwu_sense
modinfo /lib/modules/$(uname -r)/updates/dkms/linuwu_sense.ko | grep '^srcversion'
```

Not on an Arch-based distro, or prefer to build it yourself? Both options are below.

### Option 2 — DKMS from source

The module is rebuilt automatically on every kernel update:

```bash
sudo make dkms-install
# or directly:
sudo ./scripts/install-dkms.sh
```

What it does:

- `dkms add/build/install` → module lands at `/lib/modules/$(uname -r)/updates/dkms/linuwu_sense.ko`
- Blacklists the stock `acer_wmi` driver so it doesn't conflict
- Enables auto-load on boot + a systemd service
- Sets up the `linuwu_sense` group and `tmpfiles.d` permissions

Check the result:

```bash
dkms status linuwu_sense
modinfo /lib/modules/$(uname -r)/updates/dkms/linuwu_sense.ko | grep '^srcversion'
```

### Option 3 — manual build (no DKMS)

From this directory:

```bash
make
sudo make install
```

Or use the install-and-reload script, which builds, installs, and reloads the module in one shot:

```bash
sudo ./scripts/install-and-reload.sh
```

If the module was already loaded and you're doing this by hand, restart it:

```bash
sudo systemctl stop linuwu_sense.service 2>/dev/null || true
sudo rmmod linuwu_sense 2>/dev/null || true
sudo modprobe linuwu_sense
sudo systemctl start linuwu_sense.service 2>/dev/null || true
```

Verify the running module matches what's on disk:

```bash
cat /sys/module/linuwu_sense/srcversion
# the source of truth depends on how you installed:
#   DKMS: /lib/modules/$(uname -r)/updates/dkms/linuwu_sense.ko
#   make: /lib/modules/$(uname -r)/kernel/drivers/platform/x86/linuwu_sense.ko
modinfo /lib/modules/$(uname -r)/updates/dkms/linuwu_sense.ko 2>/dev/null \
  || modinfo /lib/modules/$(uname -r)/kernel/drivers/platform/x86/linuwu_sense.ko
```

## CLI Control Center (`nitro`)

A unified helper script `nitro` is installed to `/usr/local/bin/nitro`:

```bash
# Telemetry
nitro status

# Fans
nitro fan auto
nitro fan max
nitro fan toggle
nitro fan set 60 70

# Backlight brightness
nitro brightness 70

# RGB presets and 4-zone controls
nitro rgb red
nitro rgb rainbow
nitro rgb static ff0000 00ff00 0000ff ffffff 100
nitro rgb rgba ff0000ff 00ff0040 0000ff80 ffffff20 100
nitro rgb off

# Battery health threshold
nitro battery 80
nitro battery 100
```

## Test the RGB

Static 4-zone colors:

```bash
sudo ./scripts/test-rgb-static.sh
```

Expected result: zone 1 red, zone 2 green, zone 3 blue, zone 4 white.

Breathing magenta:

```bash
sudo ./scripts/test-rgb-breathing.sh
```

Or by hand:

```bash
BASE=/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi
echo ff0000,00ff00,0000ff,ffffff,100 | sudo tee "$BASE/four_zoned_kb/per_zone_mode"
echo 1,4,100,0,255,0,255 | sudo tee "$BASE/four_zoned_kb/four_zone_mode"
```

## Fan control

No power profiles here — you set the fan directly:

```bash
BASE=/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi
echo 0,0     | sudo tee "$BASE/nitro_sense/fan_speed"   # Auto
echo 100,100 | sudo tee "$BASE/nitro_sense/fan_speed"   # Max
```

## Uninstall

Via DKMS (removes DKMS registration too):

```bash
sudo make dkms-uninstall
# or directly:
sudo ./scripts/uninstall-dkms.sh
```

Old-school, via make:

```bash
sudo make uninstall
```

Or fall back to the stock in-kernel driver:

```bash
sudo rmmod linuwu_sense 2>/dev/null || true
sudo modprobe acer_wmi
```

## Troubleshooting

RGB not showing up:

```bash
ls /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb
dmesg | grep -iE 'linuwu|acer|wmi|rgb|keyboard|error|fail'
```

Module won't load due to a conflict:

```bash
lsmod | grep -E 'linuwu|facer|acer_wmi'
```

Don't load `facer` and `linuwu_sense` at the same time — they fight over the same hardware.

## Notes

This patch targets the Acer Nitro AN515-55. Other Nitro/Predator models may use different WMI payloads, so don't assume it's safe everywhere without testing.

RGB reference material:

- JafarAkhondali `acer-predator-turbo-and-rgb-keyboard-linux-module`
- `docs/facer_rgb_reference.py`