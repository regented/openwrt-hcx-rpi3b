# OpenWrt HCX — Raspberry Pi 3B+

Minimal OpenWrt image for the Raspberry Pi 3B+ with **hcxdumptool** and **hcxtools** pre-installed for WiFi PMKID/EAPOL capture. Management access is via an SSH-only WiFi access point on the internal radio; the external MT7601U USB adapter is dedicated to packet capture.

```
                                Architecture
 ┌──────────┐         ┌─────────────────────────────────────────────┐
 │          │  WiFi   │              Raspberry Pi 3B+               │
 │  Laptop  │◄───────►│                                             │
 │          │  SSH    │  wlan0 (brcmfmac)        wlan1 (MT7601U)   │
 │          │         │  ┌───────────────┐       ┌───────────────┐  │
 └──────────┘         │  │ AP mode       │       │ Monitor mode  │  │
   192.168.99.x       │  │ SSID: rpi-ssh │       │ hcxdumptool   │  │
                      │  │ 192.168.99.1  │       │ (unmanaged)   │  │
                      │  │ WPA2-PSK      │       │               │  │
                      │  │ DHCP via      │       │    ┌─────┐    │  │
                      │  │ dnsmasq       │       │    │ USB │    │  │
                      │  └───────────────┘       └────┴─────┴────┘  │
                      │   Internal radio          External dongle   │
                      └─────────────────────────────────────────────┘
```

## Prerequisites

**Build host**: Arch Linux (x86_64). Other distros will work but package names differ.

Install build dependencies:

```bash
sudo pacman -S --needed --noconfirm \
    base-devel ncurses zlib gawk gettext unzip python perl \
    wget git rsync file swig
```

Or run the provided script:

```bash
./scripts/01_setup_buildenv.sh    # installs deps + clones OpenWrt source
```

**Hardware**:
- Raspberry Pi 3 Model B+ (BCM2837B0)
- MediaTek MT7601U USB WiFi adapter (for capture)
- MicroSD card (4 GB minimum, 8 GB recommended)
- SD card reader

## Quick Start

```bash
# 1. Set up build environment (install deps, clone OpenWrt, configure feeds)
./scripts/01_setup_buildenv.sh

# 2. IMPORTANT: edit the WiFi passphrase before building
nano files/etc/config/wireless    # change CHANGEME_BEFORE_BUILD

# 3. Copy .config and expand with make defconfig
./scripts/02_configure.sh

# 4. Build (first run: 1-3 hours; incremental: ~10-20 min)
./scripts/03_build.sh             # uses all cores by default
./scripts/03_build.sh 4           # or limit to 4 jobs

# 5. Flash to SD card
./scripts/04_flash.sh /dev/sdb    # replace with your SD card device

# 6. (Optional) Validate the image contains expected binaries
sudo ./scripts/05_validate.sh
```

> **Do not run `make` as root.** The build will refuse to run as root. All scripts
> except `04_flash.sh` (which needs `sudo` for `dd`) run as your normal user.

## First Boot

### 1. Insert and Power On

Insert the flashed SD card into the RPi3B+ and plug in power. Boot takes 30-60 seconds. The green ACT LED will flash during boot.

### 2. Connect to the Access Point

From your laptop/PC, scan for WiFi networks and connect to:

| Setting    | Value                  |
|------------|------------------------|
| SSID       | `rpi-ssh-ap`           |
| Security   | WPA2-PSK               |
| Passphrase | *(what you set in step 2)* |

Your PC will get a DHCP address in the `192.168.99.0/24` range.

### 3. SSH In

```bash
ssh root@192.168.99.1
```

Default root password is empty on first boot. **Set one immediately:**

```bash
passwd
```

### 4. Verify Tools

```bash
hcxdumptool --version
hcxpcapngtool --version
hcxhashtool --version
tcpdump --version
iw list
```

## Using hcxdumptool

### Plug In the MT7601U Adapter

Insert the USB adapter. Verify it's detected:

```bash
# Check kernel messages
dmesg | tail -20

# Should show wlan1
ip link show wlan1
iw dev
```

### Put wlan1 Into Monitor Mode

hcxdumptool manages monitor mode internally, but if you need to set it manually:

```bash
# Ensure netifd isn't managing the interface
ip link set wlan1 down
iw dev wlan1 set type monitor
ip link set wlan1 up

# Verify
iw dev wlan1 info    # should show "type monitor"
```

### Capture PMKID/EAPOL Handshakes

```bash
# Basic capture — writes to pcapng format
hcxdumptool -i wlan1 -o capture.pcapng --active_beacon --enable_status=15

# Capture for 120 seconds then stop
hcxdumptool -i wlan1 -o capture.pcapng --active_beacon --enable_status=15 \
    --tot=120

# Filter by channel (e.g., channel 6 only)
hcxdumptool -i wlan1 -o capture.pcapng --active_beacon -c 6
```

Press `Ctrl+C` to stop capture.

### Convert Captures for Hashcat

```bash
# Convert pcapng to hashcat 22000 format (PMKID + EAPOL)
hcxpcapngtool -o hash.22000 capture.pcapng

# Show capture statistics
hcxpcapngtool --info capture.pcapng

# Generate PMK from ESSID + passphrase (for testing)
hcxpmktool --essid "TestNetwork" --passphrase "password123"
```

### Using tcpdump

```bash
# Capture on wlan1 in monitor mode
tcpdump -i wlan1 -w raw_capture.pcap -c 1000

# Show beacon frames
tcpdump -i wlan1 -e -s 256 type mgt subtype beacon

# Capture and display in real-time
tcpdump -i wlan1 -n -v
```

## Project Structure

```
openwrt-hcx-rpi3/
├── README.md                      # This file
├── CLAUDE.md                      # AI assistant project context
├── config/
│   ├── .config                    # Full OpenWrt config (input to make defconfig)
│   └── diffconfig                 # Minimal diff config (reference)
├── packages/
│   ├── hcxdumptool/Makefile       # OpenWrt package: WiFi capture tool
│   └── hcxtools/Makefile          # OpenWrt package: capture converters
├── files/                         # Rootfs overlay (copied verbatim into image)
│   └── etc/
│       ├── config/
│       │   ├── network            # LAN: 192.168.99.1/24 on wlan0
│       │   ├── wireless           # AP config + MT7601U (disabled)
│       │   ├── firewall           # Accept LAN, allow SSH
│       │   └── dropbear           # Disabled (OpenSSH used instead)
│       ├── ssh/
│       │   └── sshd_config        # OpenSSH: listen on 192.168.99.1
│       └── rc.local               # Start sshd, bring up WiFi
├── scripts/
│   ├── 01_setup_buildenv.sh       # Install deps + clone OpenWrt + feeds
│   ├── 02_configure.sh            # Copy .config + make defconfig
│   ├── 03_build.sh                # Build image (logged to output/build.log)
│   ├── 04_flash.sh                # Flash SD card (with safety checks)
│   └── 05_validate.sh             # Validate image contents
└── output/                        # Build artifacts (created by 03_build.sh)
    ├── *.img.gz                   # Flashable image
    └── build.log                  # Full build log
```

## Build Scripts

| Script | Purpose | Runs as root? |
|--------|---------|---------------|
| `01_setup_buildenv.sh` | Install Arch packages, clone OpenWrt v23.05.5, configure feeds | `sudo` for pacman only |
| `02_configure.sh` | Copy `.config` → `~/openwrt-src/.config`, run `make defconfig` | No |
| `03_build.sh [jobs]` | Full build, copy image to `output/` | No |
| `04_flash.sh /dev/sdX` | Flash image to SD card | `sudo` for dd |
| `05_validate.sh` | Mount image, verify binaries exist | `sudo` for mount |

All scripts are idempotent and safe to re-run.

## Troubleshooting

### MT7601U Not Detected

**Symptoms**: `wlan1` doesn't appear, `iw dev` shows only `wlan0`.

```bash
# Check USB devices
lsusb                          # should show "148f:7601 Ralink Technology"
dmesg | grep -i mt7601         # check for firmware errors

# Verify kernel module is loaded
lsmod | grep mt7601u

# Manually load if needed
modprobe mt7601u
```

**Common causes**:
- USB adapter not seated properly — re-plug it
- Missing firmware: the MT7601U firmware blob should be at `/lib/firmware/mt7601u.bin`. If missing, the build didn't include `kmod-mt7601u` correctly — rebuild with `CONFIG_PACKAGE_kmod-mt7601u=y`
- USB power: RPi3B+ may not supply enough current for some adapters — use a powered USB hub

### OpenSSH Not Starting

**Symptoms**: Can connect to WiFi AP but `ssh root@192.168.99.1` is refused.

```bash
# On the RPi (via serial console or keyboard):
/etc/init.d/sshd status
/etc/init.d/sshd start

# Check for errors
logread | grep ssh

# Verify host keys exist
ls -la /etc/ssh/ssh_host_*

# Regenerate host keys if missing
ssh-keygen -A
/etc/init.d/sshd restart
```

**Common causes**:
- Host keys not generated on first boot — run `ssh-keygen -A`
- dropbear is installed and holding port 22 — check with `netstat -tlnp | grep :22` and disable dropbear: `/etc/init.d/dropbear stop && /etc/init.d/dropbear disable`
- Firewall blocking — verify: `uci show firewall`

### WiFi AP Not Visible

**Symptoms**: `rpi-ssh-ap` SSID doesn't appear in WiFi scans.

```bash
# Check if radio is up
wifi status

# Restart wireless
wifi down && wifi up

# Check hostapd
logread | grep hostapd

# Verify brcmfmac firmware is loaded
dmesg | grep brcmfmac
```

**Common causes**:
- `hostapd-openssl` not installed — check with `opkg list-installed | grep hostapd`
- `wpad-basic-mbedtls` conflicts — only one hostapd variant can be installed
- Channel not supported — try changing to channel 1 or 11 in `/etc/config/wireless`

### Build Failures

**Feeds not updated**:
```bash
cd ~/openwrt-src
./scripts/feeds update -a
./scripts/feeds install -a
```

**Missing host tool**:
```bash
# Re-run dependency install
./scripts/01_setup_buildenv.sh

# Or install the specific missing tool
sudo pacman -S <tool-name>
```

**Package compile error** (hcxdumptool/hcxtools):
```bash
# Clean and rebuild just the failing package
cd ~/openwrt-src
make package/hcxdumptool/clean
make package/hcxdumptool/compile V=s

# For full rebuild
make clean
make -j$(nproc) V=s
```

**Single-threaded debug build** (shows the exact error):
```bash
./scripts/03_build.sh 1
```

### hcxdumptool Can't Capture

```bash
# wlan1 must NOT be managed by netifd
uci show wireless          # radio1 should show disabled=1

# Kill anything holding the interface
ip link set wlan1 down
iw dev wlan1 set type monitor
ip link set wlan1 up

# Test capture
hcxdumptool -i wlan1 -o /tmp/test.pcapng --tot=10
```

## Technical Details

| Component | Choice | Rationale |
|-----------|--------|-----------|
| OpenWrt branch | v23.05.5 | Latest stable at project start |
| SSH server | OpenSSH | Full-featured, key management, SFTP |
| Crypto backend | OpenSSL | Required by hcxtools and hostapd |
| WiFi AP daemon | hostapd-openssl | WPA2-PSK with OpenSSL backend |
| DHCP server | dnsmasq | Lightweight, default for OpenWrt |
| Capture tool | hcxdumptool 6.3.4 | Active PMKID/EAPOL capture |
| Conversion tools | hcxtools 6.3.4 | pcapng → hashcat 22000 format |
| Firewall | nftables (fw4) | OpenWrt 23.05 default |
| Init system | procd | OpenWrt default |
| Root filesystem | ext4 | Writable, easy post-flash edits |

## License

- **hcxdumptool/hcxtools**: MIT — Copyright ZerBea (https://github.com/ZerBea)
- **OpenWrt**: GPL-2.0 — Copyright OpenWrt Project
- **This project** (build scripts, configs): MIT
