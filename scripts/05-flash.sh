#!/usr/bin/env bash
# Flash OpenWrt image to SD card
set -euo pipefail

OPENWRT_DIR="$(cd "$(dirname "$0")/.." && pwd)/openwrt"
IMAGE_DIR="${OPENWRT_DIR}/bin/targets/bcm27xx/bcm2710"

# Find the factory image
IMAGE=$(find "$IMAGE_DIR" -name '*-rpi-3-ext4-factory.img.gz' -print -quit 2>/dev/null)

if [ -z "$IMAGE" ]; then
    echo "ERROR: No factory image found in ${IMAGE_DIR}"
    echo "       Run 04-build.sh first."
    exit 1
fi

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
    echo "Usage: $0 /dev/sdX"
    echo ""
    echo "Available block devices:"
    lsblk -d -o NAME,SIZE,MODEL | grep -v loop
    exit 1
fi

if [ ! -b "$DEVICE" ]; then
    echo "ERROR: ${DEVICE} is not a block device"
    exit 1
fi

echo "==> WARNING: This will ERASE ALL DATA on ${DEVICE}"
echo "    Image: $(basename "$IMAGE")"
read -rp "    Continue? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "Aborted."
    exit 0
fi

echo "==> Flashing..."
gunzip -c "$IMAGE" | sudo dd of="$DEVICE" bs=4M status=progress conv=fsync
sync

echo "==> Done. Remove SD card and boot the RPi3B+."
