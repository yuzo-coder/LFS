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

build_meson libdisplay-info "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/archive/0.2.0/libdisplay-info-0.2.0.tar.gz" ""

build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" ""
build_meson mesa "https://archive.mesa3d.org/mesa-24.0.5.tar.xz" \
    "-Dplatforms=wayland -Dglx=disabled -Dgles1=disabled -Dgles2=enabled -Degl=enabled -Dgbm=enabled -Dgallium-drivers=virgl,swrast -Dvulkan-drivers= -Dllvm=disabled"

# --- 4. Input Stack ---
build_autotools libevdev "https://www.freedesktop.org/software/libevdev/libevdev-1.13.1.tar.xz" "--disable-static"
build_autotools mtdev "https://bitmath.org/code/mtdev/mtdev-1.1.6.tar.gz" "--disable-static"
build_meson libgudev "https://download.gnome.org/sources/libgudev/238/libgudev-238.tar.xz" ""
build_meson libinput "https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.25.0/libinput-1.25.0.tar.gz" "-Ddebug-gui=false -Dtests=false -Ddocumentation=false -Dlibwacom=false"


# --- 6. Sway & Wlroots ---
build_meson seatd "https://git.sr.ht/~kennylevinsen/seatd/archive/0.8.0.tar.gz" ""

build_meson wlroots "https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.17.2/wlroots-0.17.2.tar.gz" \
    "-Dbackends=drm,libinput -Dxwayland=disabled"

build_meson sway "https://github.com/swaywm/sway/releases/download/1.9/sway-1.9.tar.gz" "-Dxwayland=disabled"

# --- 7. foot ターミナルスタック ---
build_meson tllist "https://codeberg.org/dnkl/tllist.git" ""

build_meson fcft "https://codeberg.org/dnkl/fcft.git" "-Ddocs=disabled"

build_meson foot "https://codeberg.org/dnkl/foot.git" "-Dterminfo=enabled -Ddocs=disabled -Dtests=false"


# --- 8. 完了処理 ---
echo "---"
echo "===== ALL PHASES COMPLETE: Sway & foot are ready ====="
echo "Usage: Start Sway and use 'foot' as your terminal emulator."
