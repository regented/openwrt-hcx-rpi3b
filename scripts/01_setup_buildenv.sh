#!/usr/bin/env bash
# Setup complete OpenWrt build environment on Arch Linux:
#   1. Install host dependencies
#   2. Clone OpenWrt source
#   3. Configure custom package feed (hcxdumptool/hcxtools)
#   4. Update and install all feeds
#
# Idempotent — safe to run multiple times.
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
OPENWRT_TAG="v23.05.5"
OPENWRT_DIR="$HOME/openwrt-src"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CUSTOM_PKG_DIR="$PROJECT_DIR/packages"

# ── Step 1: Install host build dependencies ──────────────────────────
echo ""
echo "==> [1/4] Installing OpenWrt build dependencies via pacman..."

sudo pacman -S --needed --noconfirm \
    base-devel \
    autoconf \
    automake \
    bash \
    binutils \
    bzip2 \
    fakeroot \
    file \
    findutils \
    flex \
    gawk \
    gcc \
    gettext \
    git \
    grep \
    groff \
    gzip \
    libelf \
    libtool \
    libxslt \
    make \
    ncurses \
    openssl \
    patch \
    perl \
    pkgconf \
    python \
    rsync \
    sed \
    swig \
    texinfo \
    time \
    unzip \
    util-linux \
    wget \
    which \
    zlib \
    zstd

echo "    Host dependencies installed."

# ── Step 2: Clone OpenWrt source ─────────────────────────────────────
echo ""
echo "==> [2/4] Setting up OpenWrt source at $OPENWRT_DIR..."

if [ -d "$OPENWRT_DIR/.git" ]; then
    echo "    Source already cloned — skipping."
    echo "    (To re-clone: rm -rf $OPENWRT_DIR)"
else
    git clone --depth 1 --branch "$OPENWRT_TAG" \
        https://github.com/openwrt/openwrt.git "$OPENWRT_DIR"
    echo "    Cloned OpenWrt $OPENWRT_TAG."
fi

# ── Step 3: Configure custom package feed ────────────────────────────
echo ""
echo "==> [3/4] Configuring custom package feed..."

FEEDS_CONF="$OPENWRT_DIR/feeds.conf.default"
FEED_LINE="src-link custom $CUSTOM_PKG_DIR"

# Preserve upstream feeds, add/update our custom feed
if [ -f "$FEEDS_CONF" ]; then
    # Remove any existing custom feed line to avoid duplicates
    sed -i '/^src-link custom /d' "$FEEDS_CONF"
fi

echo "$FEED_LINE" >> "$FEEDS_CONF"
echo "    Added local feed: $FEED_LINE"
echo "    Full feeds.conf.default:"
sed 's/^/      /' "$FEEDS_CONF"

# ── Step 4: Update and install feeds ─────────────────────────────────
echo ""
echo "==> [4/4] Updating and installing feeds..."

cd "$OPENWRT_DIR"
./scripts/feeds update -a
./scripts/feeds install -a

echo ""
echo "==> Build environment ready."
echo "    OpenWrt source: $OPENWRT_DIR"
echo "    Custom packages: $CUSTOM_PKG_DIR"
echo "    Next step: configure and build."
