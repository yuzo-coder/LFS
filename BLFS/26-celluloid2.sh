#!/bin/bash
set -euo pipefail

source "./common.sh"

JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
mkdir -p "$SRC" "$LOG"


build_meson "libxmlb" \
    "https://github.com/hughsie/libxmlb/releases/download/0.3.23/libxmlb-0.3.23.tar.xz" \
    "-Dgtkdoc=false"

echo "===== Building libadwaita ====="
cd "$SRC"

wget https://download.gnome.org/sources/libadwaita/1.7/libadwaita-1.7.6.tar.xz

rm -rf libadwaita-1.7.6

tar -xf libadwaita-1.7.6.tar.xz

cd libadwaita-1.7.6

meson subprojects download
sed -i "s|subdir('docs/')|# subdir('docs/')|" subprojects/appstream/meson.build
sed -i "s|subdir('docs')|# subdir('docs')|" subprojects/appstream/meson.build
# --- 2. ビルド設定 (CMake) ---
mkdir -p build && cd build

meson setup .. \
    --prefix=/usr \
    --buildtype=release \
    -Dtests=false \
    -Dintrospection=enabled \
    --wrap-mode=nodownload \
    -Dvapi=true

ninja > "$LOG/libadwaita.log" 2>&1
ninja install >> "$LOG/libadwaita.log" 2>&1
ldconfig
cd "$ROOT_DIR"

echo "libadwaita Installation Complete!"

build_meson "desktop-file-utils" \
    "https://www.freedesktop.org/software/desktop-file-utils/releases/desktop-file-utils-0.28.tar.xz" \
    ""

build_meson "celluloid" \
    "https://github.com/celluloid-player/celluloid/archive/refs/tags/v0.28.tar.gz" \
    ""


echo "===== COMPLETE ====="

