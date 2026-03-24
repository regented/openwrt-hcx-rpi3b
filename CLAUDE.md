# OpenWrt HCX RPi3B+ Build

Minimal OpenWrt image for Raspberry Pi 3B+ with hcxdumptool/hcxtools for WiFi capture.

## Project Goals

1. **Minimal OpenWrt for RPi3B+** — target `bcm27xx/bcm2710` (aarch64_cortex-a53)
2. **SSH via internal WiFi** — brcmfmac on wlan0, OpenSSH + OpenSSL (NOT dropbear)
3. **hcxdumptool + hcxtools compiled in** — external MT7601U adapter on wlan1 for capture
4. **tcpdump with libpcap** compiled in
5. **MT7601U kernel module** (`kmod-mt7601u`) included
6. **Cross-compiled from Arch Linux**

## Architecture

```
RPi3B+
├── wlan0 (brcmfmac, internal) — SSH access point / management
└── wlan1 (MT7601U, external) — capture interface for hcxdumptool
```

## Directory Structure

```
openwrt-hcx-rpi3/
├── CLAUDE.md              # This file
├── scripts/
│   ├── 01-setup-host.sh   # Install Arch Linux build dependencies
│   ├── 02-clone-openwrt.sh# Clone OpenWrt source and update feeds
│   ├── 03-configure.sh    # Apply .config and custom packages
│   ├── 04-build.sh        # Run the build
│   └── 05-flash.sh        # Flash image to SD card
├── config/
│   └── diffconfig          # Minimal diff config for menuconfig
├── packages/
│   ├── hcxdumptool/
│   │   └── Makefile        # OpenWrt package Makefile
│   └── hcxtools/
│       └── Makefile        # OpenWrt package Makefile
└── files/                  # rootfs overlay (copied to image verbatim)
    └── etc/
        ├── config/
        │   ├── network     # LAN/loopback config
        │   ├── wireless    # wlan0 AP config for SSH access
        │   └── firewall    # Minimal firewall
        ├── ssh/
        │   └── sshd_config # OpenSSH server config
        └── dropbear        # Empty — dropbear is REMOVED, not used
```

## Technical Constraints

### Target Hardware
- **Board**: Raspberry Pi 3 Model B+ (BCM2837B0)
- **SoC**: Broadcom BCM2710 (Cortex-A53, aarch64)
- **OpenWrt target**: `bcm27xx/bcm2710`
- **Internal WiFi**: Broadcom 43430 (brcmfmac driver, wlan0)
- **External WiFi**: MediaTek MT7601U USB adapter (wlan1)

### OpenWrt Version
- Use OpenWrt 23.05.x stable branch (or latest stable at build time)
- SDK is NOT used — full source build for maximum control

### SSH Stack
- **MUST use OpenSSH server** (`openssh-server`, `openssh-sftp-server`)
- **MUST use OpenSSL** (`libopenssl`) as the crypto backend
- **MUST remove dropbear** — set `CONFIG_PACKAGE_dropbear=n` explicitly
- dropbear conflicts with openssh-server on port 22; removing it avoids issues

### WiFi Configuration
- **wlan0 (brcmfmac)**: Runs as AP for management/SSH access
  - SSID: `OpenWrt-HCX` (change in files/etc/config/wireless)
  - Encryption: WPA2-PSK (change key before building)
  - Channel: auto
  - IP: 192.168.1.1/24 with DHCP
- **wlan1 (MT7601U)**: Left unmanaged — used exclusively by hcxdumptool
  - Do NOT configure in /etc/config/wireless
  - Must support monitor mode

### Required Kernel Modules
- `kmod-brcmfmac` — internal WiFi
- `kmod-mt7601u` — external USB WiFi (depends on `kmod-mac80211`)
- `kmod-usb-core`, `kmod-usb-dwc2` — USB support for RPi3

### Required Packages
- `openssh-server`, `openssh-sftp-server`, `libopenssl`
- `tcpdump`, `libpcap`
- `hcxdumptool`, `hcxtools` (custom packages, see packages/)
- `hostapd-openssl` (for WPA2 AP on wlan0, OpenSSL variant)
- `dnsmasq` (DHCP server for AP clients)
- `kmod-mt7601u`
- `wireless-tools`, `iw`

### Packages to EXCLUDE
- `dropbear` — conflicts with openssh-server
- `wpad-basic-mbedtls` — replaced by `hostapd-openssl`
- `ppp`, `ppp-mod-pppoe` — no WAN PPP needed
- `ip6tables`, `odhcp6c` — no IPv6 needed
- `luci` — no web UI, SSH-only management

### Custom Packages (hcxdumptool / hcxtools)
- Upstream: https://github.com/ZerBea/hcxdumptool / https://github.com/ZerBea/hcxtools
- hcxtools depends on: `libopenssl`, `libcurl`, `zlib`
- hcxdumptool depends on: `libpcap`
- Both use plain Makefile builds (no autotools/cmake)
- Package Makefiles follow OpenWrt package format in `packages/`

### Build Host (Arch Linux)
- Required host packages: `base-devel`, `ncurses`, `zlib`, `gawk`, `gettext`,
  `unzip`, `python`, `perl`, `wget`, `git`, `rsync`, `file`
- Do NOT run `make` as root
- Use `make -j$(nproc)` for parallel build
- First build takes 1-3 hours depending on hardware
- Subsequent builds are incremental (~10-20 min)

### Build Workflow
```bash
./scripts/01-setup-host.sh   # Install Arch dependencies (run once)
./scripts/02-clone-openwrt.sh # Clone source + update feeds
./scripts/03-configure.sh    # Copy config, link custom packages
./scripts/04-build.sh        # Compile everything
./scripts/05-flash.sh        # Write image to SD card
```

### Output
- Image location: `openwrt/bin/targets/bcm27xx/bcm2710/`
- Image format: `*-rpi-3-ext4-factory.img.gz` or `*-rpi-3-squashfs-factory.img.gz`
- Use ext4 variant for easier post-flash modification

### Flashing
```bash
# Decompress and write to SD card (replace /dev/sdX)
gunzip -k openwrt-*-rpi-3-ext4-factory.img.gz
sudo dd if=openwrt-*-rpi-3-ext4-factory.img of=/dev/sdX bs=4M status=progress
sync
```

### macOS Pre-Push Checklist
- macOS `chmod +x` does NOT persist in git by default. Before committing, run:
  ```bash
  git update-index --chmod=+x scripts/*.sh
  ```
  This sets the executable bit in git's index so that scripts are executable
  after cloning on Arch Linux. The `08_verify_on_arch.sh` script will warn
  if any scripts are missing the execute bit after clone.

## Common Issues

- **Build fails with missing host tool**: Run `01-setup-host.sh` again
- **WiFi not starting**: Check `kmod-brcmfmac` firmware is included
- **MT7601U not detected**: Verify `kmod-mt7601u` and USB modules are loaded
- **SSH refused**: Ensure dropbear is fully removed and openssh-server is enabled
- **hcxdumptool can't capture**: wlan1 must be in monitor mode, not managed by netifd
