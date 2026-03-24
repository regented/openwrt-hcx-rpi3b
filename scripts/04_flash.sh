#!/usr/bin/env bash
# Flash OpenWrt image to SD card.
#
# Usage: ./04_flash.sh /dev/sdX
#
# Safety features:
#   - Refuses to flash system disks (sda, nvme0n1, mmcblk0 on some systems)
#   - Requires explicit confirmation with device name typed out
#   - Unmounts all partitions on the target device before writing
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/output"

# ── Find the image ───────────────────────────────────────────────────
IMAGE=""
for pattern in "*-ext4-factory.img.gz" "*-squashfs-factory.img.gz"; do
    found=$(find "$OUTPUT_DIR" -maxdepth 1 -name "$pattern" -print -quit 2>/dev/null)
    if [ -n "$found" ]; then
        IMAGE="$found"
        break
    fi
done

if [ -z "$IMAGE" ]; then
    echo "ERROR: No factory image found in $OUTPUT_DIR"
    echo "       Run 03_build.sh first."
    exit 1
fi

BASENAME=$(basename "$IMAGE")
SIZE=$(du -h "$IMAGE" | cut -f1)

# ── Parse and validate device argument ───────────────────────────────
DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
    echo "Usage: $0 /dev/sdX"
    echo ""
    echo "Image: $BASENAME ($SIZE)"
    echo ""
    echo "Available block devices:"
    lsblk -d -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep -v loop || true
    exit 1
fi

# Must be a block device
if [ ! -b "$DEVICE" ]; then
    echo "ERROR: $DEVICE is not a block device."
    exit 1
fi

# Refuse to flash common system disk names
DEVBASE=$(basename "$DEVICE")
case "$DEVBASE" in
    sda|sda[0-9]*|nvme0n1|nvme0n1p[0-9]*|mmcblk0|mmcblk0p[0-9]*)
        echo "ERROR: $DEVICE looks like a system disk. Refusing to flash."
        echo "       If this is really your SD card, use a different reader/port"
        echo "       or override by editing this script."
        exit 1
        ;;
esac

# Must not be a partition — only whole-disk devices
case "$DEVBASE" in
    sd[b-z][0-9]*|mmcblk[1-9]p[0-9]*)
        echo "ERROR: $DEVICE looks like a partition, not a whole disk."
        echo "       Use the base device (e.g., /dev/sdb not /dev/sdb1)."
        exit 1
        ;;
esac

# ── Show what we're about to do ──────────────────────────────────────
echo ""
echo "========================================"
echo "  WARNING: DESTRUCTIVE OPERATION"
echo "========================================"
echo ""
echo "  Image:  $BASENAME ($SIZE)"
echo "  Target: $DEVICE"
echo ""

# Show target device details
echo "  Device details:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT "$DEVICE" 2>/dev/null | sed 's/^/    /'
echo ""

echo "  ALL DATA ON $DEVICE WILL BE PERMANENTLY ERASED."
echo ""

# Require the user to type the device name to confirm
read -rp "  Type the device name to confirm (e.g., $DEVBASE): " confirm
if [ "$confirm" != "$DEVBASE" ] && [ "$confirm" != "$DEVICE" ]; then
    echo "  Aborted — input did not match."
    exit 0
fi

# ── Unmount any mounted partitions on the device ─────────────────────
echo ""
echo "==> Unmounting partitions on $DEVICE..."
for part in $(lsblk -ln -o NAME "$DEVICE" 2>/dev/null | tail -n +2); do
    mountpoint=$(lsblk -ln -o MOUNTPOINT "/dev/$part" 2>/dev/null | head -1)
    if [ -n "$mountpoint" ]; then
        echo "    Unmounting /dev/$part (mounted at $mountpoint)"
        sudo umount "/dev/$part" || true
    fi
done

# ── Flash ────────────────────────────────────────────────────────────
echo ""
echo "==> Flashing $BASENAME to $DEVICE..."
gunzip -c "$IMAGE" | sudo dd of="$DEVICE" bs=4M status=progress conv=fsync
sync

# ── Eject ────────────────────────────────────────────────────────────
echo ""
echo "==> Syncing and ejecting $DEVICE..."
sudo eject "$DEVICE" 2>/dev/null || true

echo ""
echo "==> Done. SD card is ready."
echo "    Insert into RPi3B+ and power on."
echo "    Connect to WiFi SSID 'rpi-ssh-ap' and SSH to 192.168.99.1"
