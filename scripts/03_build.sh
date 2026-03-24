#!/usr/bin/env bash
# Build OpenWrt image for RPi3B+ and copy output to project output/ dir.
#
# Usage:
#   ./03_build.sh          # build with $(nproc) jobs
#   ./03_build.sh 4        # build with 4 jobs
#   ./03_build.sh 1        # single-threaded (easiest to debug)
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
OPENWRT_DIR="$HOME/openwrt-src"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/output"
IMAGE_DIR="bin/targets/bcm27xx/bcm2710"
BUILD_LOG="$PROJECT_DIR/output/build.log"
JOBS="${1:-$(nproc)}"

# ── Sanity checks ────────────────────────────────────────────────────
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "ERROR: OpenWrt source not found at $OPENWRT_DIR"
    echo "       Run 01_setup_buildenv.sh first."
    exit 1
fi

if [ ! -f "$OPENWRT_DIR/.config" ]; then
    echo "ERROR: No .config found in $OPENWRT_DIR"
    echo "       Run 02_configure.sh first."
    exit 1
fi

# ── Prepare output directory ─────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

# ── Build ────────────────────────────────────────────────────────────
echo ""
echo "==> Building OpenWrt with ${JOBS} parallel jobs..."
echo "    Source:    $OPENWRT_DIR"
echo "    Log:       $BUILD_LOG"
echo "    First build takes 1-3 hours. Subsequent builds are incremental."
echo ""

cd "$OPENWRT_DIR"

# V=s enables full verbose output; tee duplicates to both console and log.
# pipefail ensures we catch make failures even through the pipe.
if make -j"$JOBS" V=s 2>&1 | tee "$BUILD_LOG"; then
    echo ""
    echo "==> Build succeeded."
else
    echo ""
    echo "==> BUILD FAILED. Check log: $BUILD_LOG"
    echo "    Tip: re-run with ./03_build.sh 1 for single-threaded debug output."
    exit 1
fi

# ── Locate and copy output image ─────────────────────────────────────
echo ""
echo "==> Locating output image..."

# Prefer ext4-factory, fall back to squashfs-factory
IMAGE=""
for pattern in "*-ext4-factory.img.gz" "*-squashfs-factory.img.gz"; do
    found=$(find "$OPENWRT_DIR/$IMAGE_DIR" -maxdepth 1 -name "$pattern" -print -quit 2>/dev/null)
    if [ -n "$found" ]; then
        IMAGE="$found"
        break
    fi
done

if [ -z "$IMAGE" ]; then
    echo "WARNING: No factory image found in $OPENWRT_DIR/$IMAGE_DIR"
    echo "         Available files:"
    ls -lh "$OPENWRT_DIR/$IMAGE_DIR/" 2>/dev/null || echo "         (directory does not exist)"
    exit 1
fi

cp "$IMAGE" "$OUTPUT_DIR/"
BASENAME=$(basename "$IMAGE")
SIZE=$(du -h "$OUTPUT_DIR/$BASENAME" | cut -f1)

echo ""
echo "==> Image copied to output directory."
echo "    Path: $OUTPUT_DIR/$BASENAME"
echo "    Size: $SIZE"
echo "    Next step: flash with ./04_flash.sh /dev/sdX"
