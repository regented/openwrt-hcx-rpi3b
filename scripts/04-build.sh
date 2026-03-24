#!/usr/bin/env bash
# Build the OpenWrt image
set -euo pipefail

OPENWRT_DIR="$(cd "$(dirname "$0")/.." && pwd)/openwrt"

if [ ! -f "$OPENWRT_DIR/.config" ]; then
    echo "ERROR: No .config found. Run 03-configure.sh first."
    exit 1
fi

cd "$OPENWRT_DIR"

JOBS="${1:-$(nproc)}"

echo "==> Building OpenWrt with ${JOBS} jobs..."
echo "    First build takes 1-3 hours. Subsequent builds are incremental."

make -j"$JOBS" V=s 2>&1 | tee build.log

echo "==> Build complete. Images at:"
ls -lh bin/targets/bcm27xx/bcm2710/*factory* 2>/dev/null || echo "    (no factory images found — check build.log)"
