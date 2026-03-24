#!/usr/bin/env bash
# Configure OpenWrt build for RPi3B+ with hcxdumptool/hcxtools:
#   1. Copy .config into OpenWrt source tree
#   2. Run make defconfig to expand minimal config into full .config
#
# Idempotent — safe to run multiple times.
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
OPENWRT_DIR="$HOME/openwrt-src"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_SRC="$PROJECT_DIR/config/.config"

# ── Sanity checks ────────────────────────────────────────────────────
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "ERROR: OpenWrt source not found at $OPENWRT_DIR"
    echo "       Run 01_setup_buildenv.sh first."
    exit 1
fi

if [ ! -f "$CONFIG_SRC" ]; then
    echo "ERROR: Config file not found at $CONFIG_SRC"
    exit 1
fi

# ── Step 1: Copy .config ─────────────────────────────────────────────
echo ""
echo "==> [1/2] Copying .config into OpenWrt source tree..."
cp "$CONFIG_SRC" "$OPENWRT_DIR/.config"
echo "    Copied: $CONFIG_SRC -> $OPENWRT_DIR/.config"

# ── Step 2: Expand with make defconfig ───────────────────────────────
echo ""
echo "==> [2/2] Running make defconfig to expand configuration..."
cd "$OPENWRT_DIR"
make defconfig

echo ""
echo "==> Configuration complete."
echo "    Full .config generated at: $OPENWRT_DIR/.config"
echo "    To review: make menuconfig (inside $OPENWRT_DIR)"
echo "    Next step: build with 03_build.sh"
