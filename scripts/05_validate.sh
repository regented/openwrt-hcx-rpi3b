#!/usr/bin/env bash
# Validate that the built OpenWrt image contains all expected binaries
# and configuration files by mounting it and checking.
#
# Usage: sudo ./05_validate.sh [image.img.gz]
#
# If no argument is given, finds the image in output/.
# Requires root (for loop-mounting the ext4 partition).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/output"

# ── Colors for output ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check_exists() {
    local path="$1"
    local description="$2"
    if [ -e "$MOUNTPOINT$path" ]; then
        printf "  ${GREEN}PASS${NC}  %-40s %s\n" "$path" "$description"
        PASS=$((PASS + 1))
    else
        printf "  ${RED}FAIL${NC}  %-40s %s\n" "$path" "$description"
        FAIL=$((FAIL + 1))
    fi
}

check_executable() {
    local path="$1"
    local description="$2"
    if [ -x "$MOUNTPOINT$path" ]; then
        printf "  ${GREEN}PASS${NC}  %-40s %s\n" "$path" "$description"
        PASS=$((PASS + 1))
    elif [ -e "$MOUNTPOINT$path" ]; then
        printf "  ${YELLOW}WARN${NC}  %-40s %s (exists but not executable)\n" "$path" "$description"
        WARN=$((WARN + 1))
    else
        printf "  ${RED}FAIL${NC}  %-40s %s\n" "$path" "$description"
        FAIL=$((FAIL + 1))
    fi
}

check_not_exists() {
    local path="$1"
    local description="$2"
    if [ ! -e "$MOUNTPOINT$path" ]; then
        printf "  ${GREEN}PASS${NC}  %-40s %s\n" "! $path" "$description"
        PASS=$((PASS + 1))
    else
        printf "  ${RED}FAIL${NC}  %-40s %s (should not be present)\n" "$path" "$description"
        FAIL=$((FAIL + 1))
    fi
}

check_contains() {
    local path="$1"
    local pattern="$2"
    local description="$3"
    if [ -f "$MOUNTPOINT$path" ] && grep -q "$pattern" "$MOUNTPOINT$path" 2>/dev/null; then
        printf "  ${GREEN}PASS${NC}  %-40s %s\n" "$path ~ $pattern" "$description"
        PASS=$((PASS + 1))
    else
        printf "  ${RED}FAIL${NC}  %-40s %s\n" "$path ~ $pattern" "$description"
        FAIL=$((FAIL + 1))
    fi
}

# ── Must run as root (for mount) ─────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must run as root (for loop-mounting the image)."
    echo "Usage: sudo $0 [image.img.gz]"
    exit 1
fi

# ── Locate image ─────────────────────────────────────────────────────
IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
    for pattern in "*-ext4-factory.img.gz" "*-squashfs-factory.img.gz"; do
        found=$(find "$OUTPUT_DIR" -maxdepth 1 -name "$pattern" -print -quit 2>/dev/null)
        if [ -n "$found" ]; then
            IMAGE="$found"
            break
        fi
    done
fi

if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
    echo "ERROR: No image found. Run 03_build.sh first, or pass the image path:"
    echo "       sudo $0 output/openwrt-*-ext4-factory.img.gz"
    exit 1
fi

echo ""
echo "==> Validating image: $(basename "$IMAGE")"

# ── Decompress to temp file ──────────────────────────────────────────
TMPDIR=$(mktemp -d)
IMGFILE="$TMPDIR/image.img"
MOUNTPOINT="$TMPDIR/rootfs"
LOOPDEV=""

cleanup() {
    echo ""
    echo "==> Cleaning up..."
    if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
        umount "$MOUNTPOINT" 2>/dev/null || true
    fi
    if [ -n "$LOOPDEV" ]; then
        losetup -d "$LOOPDEV" 2>/dev/null || true
    fi
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "    Decompressing image..."
gunzip -c "$IMAGE" > "$IMGFILE"

# ── Mount the rootfs partition ───────────────────────────────────────
# OpenWrt RPi images: partition 1 = boot (vfat), partition 2 = rootfs (ext4)
mkdir -p "$MOUNTPOINT"

# Detect rootfs partition offset
ROOTFS_START=$(fdisk -l "$IMGFILE" 2>/dev/null | awk '/Linux/ {print $2; exit}')
if [ -z "$ROOTFS_START" ]; then
    echo "ERROR: Could not detect rootfs partition in image."
    exit 1
fi
OFFSET=$((ROOTFS_START * 512))

echo "    Mounting rootfs (partition 2, offset ${OFFSET})..."
LOOPDEV=$(losetup --find --show --offset "$OFFSET" "$IMGFILE")
mount -o ro "$LOOPDEV" "$MOUNTPOINT"

echo ""
echo "========================================"
echo "  Image Validation Results"
echo "========================================"

# ── 1. Core binaries ─────────────────────────────────────────────────
echo ""
echo "--- Core binaries ---"
check_executable "/usr/bin/hcxdumptool"       "WiFi capture tool"
check_executable "/usr/bin/hcxpcapngtool"     "pcapng converter"
check_executable "/usr/bin/hcxhashtool"       "hash tool"
check_executable "/usr/bin/hcxpmktool"        "PMK tool"
check_executable "/usr/sbin/tcpdump"          "Packet capture"
check_executable "/usr/bin/iw"                "Wireless config"
check_executable "/usr/sbin/sshd"             "OpenSSH server"
check_executable "/usr/bin/ssh-keygen"        "SSH key generator"
check_executable "/bin/bash"                  "Bash shell"
check_executable "/usr/bin/nano"              "Text editor"

# ── 2. Libraries ─────────────────────────────────────────────────────
echo ""
echo "--- Libraries ---"
check_exists "/usr/lib/libpcap.so*"           "libpcap"
check_exists "/usr/lib/libssl.so*"            "OpenSSL libssl"
check_exists "/usr/lib/libcrypto.so*"         "OpenSSL libcrypto"

# ── 3. Kernel modules ───────────────────────────────────────────────
echo ""
echo "--- Kernel modules ---"
# Kernel module paths vary by version; search for them
MT7601_FOUND=$(find "$MOUNTPOINT" -name "mt7601u.ko*" -print -quit 2>/dev/null)
BRCMFMAC_FOUND=$(find "$MOUNTPOINT" -name "brcmfmac.ko*" -print -quit 2>/dev/null)
MAC80211_FOUND=$(find "$MOUNTPOINT" -name "mac80211.ko*" -print -quit 2>/dev/null)
CFG80211_FOUND=$(find "$MOUNTPOINT" -name "cfg80211.ko*" -print -quit 2>/dev/null)

for mod_var in "MT7601_FOUND:mt7601u.ko" "BRCMFMAC_FOUND:brcmfmac.ko" \
               "MAC80211_FOUND:mac80211.ko" "CFG80211_FOUND:cfg80211.ko"; do
    var="${mod_var%%:*}"
    name="${mod_var#*:}"
    val="${!var}"
    if [ -n "$val" ]; then
        printf "  ${GREEN}PASS${NC}  %-40s %s\n" "$name" "found"
        PASS=$((PASS + 1))
    else
        printf "  ${RED}FAIL${NC}  %-40s %s\n" "$name" "not found in image"
        FAIL=$((FAIL + 1))
    fi
done

# MT7601U firmware blob
MT7601_FW=$(find "$MOUNTPOINT" -path "*/firmware/mt7601u.bin" -print -quit 2>/dev/null)
if [ -n "$MT7601_FW" ]; then
    printf "  ${GREEN}PASS${NC}  %-40s %s\n" "mt7601u.bin firmware" "found"
    PASS=$((PASS + 1))
else
    printf "  ${RED}FAIL${NC}  %-40s %s\n" "mt7601u.bin firmware" "not found"
    FAIL=$((FAIL + 1))
fi

# ── 4. Configuration files ──────────────────────────────────────────
echo ""
echo "--- Configuration files ---"
check_exists "/etc/config/network"            "Network config"
check_exists "/etc/config/wireless"           "Wireless config"
check_exists "/etc/config/firewall"           "Firewall config"
check_exists "/etc/ssh/sshd_config"           "OpenSSH config"
check_exists "/etc/rc.local"                  "rc.local boot script"

# ── 5. Configuration content checks ─────────────────────────────────
echo ""
echo "--- Configuration content ---"
check_contains "/etc/config/network"  "192.168.99.1"     "LAN IP is 192.168.99.1"
check_contains "/etc/config/wireless" "rpi-ssh-ap"       "SSID is rpi-ssh-ap"
check_contains "/etc/config/wireless" "disabled '1'"     "radio1 (MT7601U) disabled in UCI"
check_contains "/etc/ssh/sshd_config" "192.168.99.1"     "sshd listens on AP IP"
check_contains "/etc/ssh/sshd_config" "PermitRootLogin yes" "Root login enabled"

# ── 6. Excluded packages ────────────────────────────────────────────
echo ""
echo "--- Excluded packages (should NOT be present) ---"
check_not_exists "/usr/sbin/dropbear"         "dropbear not installed"
# LuCI check: no luci web UI
LUCI_FOUND=$(find "$MOUNTPOINT" -path "*/luci/*" -print -quit 2>/dev/null)
if [ -z "$LUCI_FOUND" ]; then
    printf "  ${GREEN}PASS${NC}  %-40s %s\n" "! /www/luci-*" "LuCI not installed"
    PASS=$((PASS + 1))
else
    printf "  ${RED}FAIL${NC}  %-40s %s\n" "/www/luci-*" "LuCI should not be present"
    FAIL=$((FAIL + 1))
fi

# ── 7. WiFi AP daemon ───────────────────────────────────────────────
echo ""
echo "--- WiFi AP ---"
HOSTAPD_FOUND=$(find "$MOUNTPOINT" -name "hostapd" -print -quit 2>/dev/null)
if [ -n "$HOSTAPD_FOUND" ]; then
    printf "  ${GREEN}PASS${NC}  %-40s %s\n" "hostapd" "found"
    PASS=$((PASS + 1))
else
    printf "  ${RED}FAIL${NC}  %-40s %s\n" "hostapd" "not found"
    FAIL=$((FAIL + 1))
fi
check_exists "/usr/sbin/dnsmasq"              "DHCP server"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "========================================"
TOTAL=$((PASS + FAIL + WARN))
printf "  Total: %d  |  ${GREEN}Pass: %d${NC}  |  ${RED}Fail: %d${NC}  |  ${YELLOW}Warn: %d${NC}\n" \
    "$TOTAL" "$PASS" "$FAIL" "$WARN"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "  Image validation FAILED. Review the failures above."
    exit 1
else
    echo ""
    echo "  Image validation PASSED."
    exit 0
fi
