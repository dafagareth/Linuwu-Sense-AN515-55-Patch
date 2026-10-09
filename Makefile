obj-m := src/linuwu_sense.o

KVER  ?= $(shell uname -r)
KDIR  := /lib/modules/$(KVER)/build
PWD   := $(shell pwd)

MDIR  := /lib/modules/$(KVER)/kernel/drivers/platform/x86
MODNAME := linuwu_sense

DKMS_VERSION := $(shell sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' dkms.conf)
REAL_USER := $(shell echo $${SUDO_USER:-$$(whoami)})

KCONFIG := $(KDIR)/.config
CC_IS_CLANG := $(shell grep -q '^CONFIG_CC_IS_CLANG=y' $(KCONFIG) 2>/dev/null && echo 1)
ifeq ($(strip $(CC_IS_CLANG)),)
# /proc/config.gz describes the *running* kernel only. When building against a
# different kernel, trust the target kernel's own .config instead of assuming
# the running kernel's toolchain (e.g. a gcc-built LTS kernel with a clang
# running kernel would otherwise be built with the wrong compiler).
ifeq ($(KVER),$(shell uname -r))
CC_IS_CLANG := $(shell zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_CC_IS_CLANG=y' && echo 1)
endif
endif
LLVM ?= $(strip $(CC_IS_CLANG))

all:
	$(MAKE) -C $(KDIR) M=$(PWD) LLVM=$(LLVM) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) LLVM=$(LLVM) clean

uninstall:
	@sudo rm -f /etc/modules-load.d/$(MODNAME).conf
	@sudo rm -f /etc/modprobe.d/blacklist-acer_wmi.conf
	@sudo systemctl stop linuwu_sense.service
	@sudo systemctl disable linuwu_sense.service
	@sudo rm -f /etc/systemd/system/linuwu_sense.service
	@sudo systemctl daemon-reload
	@sudo rmmod $(MODNAME) 2>/dev/null || true
	@echo "Removing DKMS module registration (if any)..."
	@if command -v dkms >/dev/null 2>&1; then \
		sudo dkms remove -m $(MODNAME) -v $(DKMS_VERSION) --all 2>/dev/null || true; \
	fi
	@sudo modprobe acer_wmi
	@echo "Removing current user from linuwu_sense group if exists..."
	@if getent group linuwu_sense >/dev/null; then \
		sudo gpasswd -d $(REAL_USER) linuwu_sense || true; \
		sudo groupdel linuwu_sense || true; \
	else \
		echo "Group linuwu_sense does not exist."; \
	fi
	@sudo rm -f /etc/tmpfiles.d/$(MODNAME).conf
	@sudo rm -f $(MDIR)/$(MODNAME).ko
	@sudo depmod -a
	@echo "Uninstalled $(MODNAME) and cleaned up related configuration."

install: all
	@sudo rmmod acer_wmi 2>/dev/null || true
	@echo "blacklist acer_wmi" | sudo tee /etc/modprobe.d/blacklist-acer_wmi.conf > /dev/null
	sudo install -d $(MDIR)
	sudo install -m 644 src/$(MODNAME).ko $(MDIR)
	sudo depmod -a
	@echo "$(MODNAME)" | sudo tee /etc/modules-load.d/$(MODNAME).conf > /dev/null
	sudo modprobe $(MODNAME)
	@sudo cp linuwu_sense.service /etc/systemd/system/
	@sudo systemctl daemon-reload
	@sudo systemctl enable linuwu_sense.service
	@sudo systemctl start linuwu_sense.service
	@echo "Setting up group and permissions..."
	@echo "Detected user: $(REAL_USER)"
	@if ! getent group linuwu_sense >/dev/null; then \
		sudo groupadd linuwu_sense; \
	fi; 
	sudo usermod -aG linuwu_sense $(REAL_USER)
	@echo "Setting permissions via tmpfiles..."
	@model_path=$$(ls /sys/module/$(MODNAME)/drivers/platform:acer-wmi/acer-wmi/ | grep -E 'predator_sense|nitro_sense' || true); \
	if [ -n "$$model_path" ]; then \
		echo "Detected model directory: $$model_path"; \
		conf_file="/etc/tmpfiles.d/$(MODNAME).conf"; \
		[ -f $$conf_file ] || sudo touch $$conf_file; \
		if echo "$$model_path" | grep -q "nitro_sense"; then \
			supported_fields="fan_speed battery_limiter battery_calibration usb_charging"; \
		else \
			supported_fields="backlight_timeout battery_calibration battery_limiter boot_animation_sound fan_speed lcd_override usb_charging"; \
		fi; \
		for f in $$supported_fields; do \
			entry="f /sys/module/$(MODNAME)/drivers/platform:acer-wmi/acer-wmi/$$model_path/$$f 0660 root $(MODNAME)"; \
			grep -qxF "$$entry" $$conf_file || echo "$$entry" | sudo tee -a $$conf_file > /dev/null; \
		done; \
		kb_base="/sys/module/$(MODNAME)/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb"; \
		if [ -d "$$kb_base" ]; then \
			for z in four_zone_mode per_zone_mode brightness; do \
				entry="f $$kb_base/$$z 0660 root $(MODNAME)"; \
				grep -qxF "$$entry" $$conf_file || echo "$$entry" | sudo tee -a $$conf_file > /dev/null; \
			done; \
		fi; \
		sudo systemd-tmpfiles --create $$conf_file; \
	else \
		echo "Warning: Could not detect predator_sense or nitro_sense in sysfs."; \
	fi
	@echo "Module $(MODNAME) installed and configured to load at boot."

dkms-install:
	sudo ./scripts/install-dkms.sh

dkms-uninstall:
	sudo ./scripts/uninstall-dkms.sh

.PHONY: all clean install uninstall dkms-install dkms-uninstall

