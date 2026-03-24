#!/usr/bin/env bash
# Clone OpenWrt source and update feeds
set -euo pipefail

OPENWRT_DIR="$(cd "$(dirname "$0")/.." && pwd)/openwrt"
OPENWRT_BRANCH="v23.05.5"

if [ -d "$OPENWRT_DIR" ]; then
    echo "==> OpenWrt source already exists at $OPENWRT_DIR"
    echo "    To re-clone, remove it first: rm -rf $OPENWRT_DIR"
    exit 0
fi

echo "==> Cloning OpenWrt ${OPENWRT_BRANCH}..."
git clone --depth 1 --branch "$OPENWRT_BRANCH" \
    https://github.com/openwrt/openwrt.git "$OPENWRT_DIR"

cd "$OPENWRT_DIR"

echo "==> Updating feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

echo "==> OpenWrt source ready at $OPENWRT_DIR"
