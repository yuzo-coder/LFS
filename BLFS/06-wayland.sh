#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

mkdir -p "$SRC" "$LOG"
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/lib/pkgconfig
export MAKEFLAGS="-j$JOBS"

if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# --- 3. Wayland & Graphics Foundation ---
build_autotools libxml2 "https://download.gnome.org/sources/libxml2/2.12/libxml2-2.12.7.tar.xz" "--disable-static --without-python"
build_autotools hwdata "https://github.com/vcrhonek/hwdata/archive/v0.404/hwdata-0.404.tar.gz" ""

build_cmake doxygen "https://doxygen.nl/files/doxygen-1.16.1.src.tar.gz" "-DCMAKE_BUILD_TYPE=Release"
build_cmake json-c "https://s3.amazonaws.com/json-c_releases/releases/json-c-0.18.tar.gz" "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"

build_meson wayland "https://ftp2.osuosl.org/pub/blfs/12.4/w/wayland-1.24.0.tar.xz" "-Ddocumentation=false"

build_meson wayland-protocols "https://ftp2.osuosl.org/pub/blfs/12.4/w/wayland-protocols-1.45.tar.xz" ""

# 2. wayland-utils (wayland-info)
build_meson wayland-utils "https://gitlab.freedesktop.org/wayland/wayland-utils/-/archive/1.2.0/wayland-utils-1.2.0.tar.gz" ""

echo "---"
echo "===== 06 WAYLAND COMPLETE:  ====="
