#!/usr/bin/env bash
# Apply config, link custom packages, and expand to full .config
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENWRT_DIR="${PROJECT_DIR}/openwrt"

if [ ! -d "$OPENWRT_DIR" ]; then
    echo "ERROR: OpenWrt source not found. Run 02-clone-openwrt.sh first."
    exit 1
fi

# Link custom packages into OpenWrt feed
echo "==> Linking custom packages..."
mkdir -p "$OPENWRT_DIR/package/custom"

for pkg in hcxdumptool hcxtools; do
    src="${PROJECT_DIR}/packages/${pkg}"
    dst="${OPENWRT_DIR}/package/custom/${pkg}"
    if [ -d "$src" ]; then
        ln -sfn "$src" "$dst"
        echo "    Linked ${pkg}"
    fi
done

# Copy diffconfig and expand
echo "==> Applying diffconfig..."
cp "${PROJECT_DIR}/config/diffconfig" "${OPENWRT_DIR}/.config"

cd "$OPENWRT_DIR"
make defconfig

# Copy rootfs overlay
echo "==> Copying rootfs overlay files..."
rm -rf "${OPENWRT_DIR}/files"
cp -r "${PROJECT_DIR}/files" "${OPENWRT_DIR}/files"

echo "==> Configuration applied. Review with: cd $OPENWRT_DIR && make menuconfig"
