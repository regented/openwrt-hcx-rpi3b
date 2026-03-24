#!/usr/bin/env bash
# Install Arch Linux build dependencies for OpenWrt cross-compilation
set -euo pipefail

echo "==> Installing OpenWrt build dependencies on Arch Linux..."

sudo pacman -S --needed --noconfirm \
    base-devel \
    ncurses \
    zlib \
    gawk \
    gettext \
    unzip \
    python \
    perl \
    wget \
    git \
    rsync \
    file \
    swig

echo "==> Host dependencies installed."
