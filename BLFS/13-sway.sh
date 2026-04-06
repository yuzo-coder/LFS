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

build_meson wayland "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.0/downloads/wayland-1.23.0.tar.xz" "-Ddocumentation=false"

build_meson wayland-protocols "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.36/downloads/wayland-protocols-1.36.tar.xz" ""

# 2. wayland-utils (wayland-info)
     83 build_meson wayland-utils "https://gitlab.freedesktop.org/wayland/wayland-utils/-/archive/1.2.0/wayland-utils-1.2.0.tar.gz" ""

build_meson libdisplay-info "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/archive/0.2.0/libdisplay-info-0.2.0.tar.gz" ""

build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" ""
build_meson mesa "https://archive.mesa3d.org/mesa-24.0.5.tar.xz" \
    "-Dplatforms=wayland -Dglx=disabled -Dgles1=disabled -Dgles2=enabled -Degl=enabled -Dgbm=enabled -Dgallium-drivers=virgl,swrast -Dvulkan-drivers= -Dllvm=disabled"

# --- 4. Input Stack ---
build_autotools libevdev "https://www.freedesktop.org/software/libevdev/libevdev-1.13.1.tar.xz" "--disable-static"
build_autotools mtdev "https://bitmath.org/code/mtdev/mtdev-1.1.6.tar.gz" "--disable-static"
build_meson libgudev "https://download.gnome.org/sources/libgudev/238/libgudev-238.tar.xz" ""
build_meson libinput "https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.25.0/libinput-1.25.0.tar.gz" "-Ddebug-gui=false -Dtests=false -Ddocumentation=false -Dlibwacom=false"

# --- 5. Font & Drawing Stack ---
build_meson pixman "https://www.cairographics.org/releases/pixman-0.43.4.tar.gz" ""
build_meson fribidi "https://github.com/fribidi/fribidi/releases/download/v1.0.15/fribidi-1.0.15.tar.xz" ""
build_meson cairo "https://www.cairographics.org/releases/cairo-1.18.2.tar.xz" \
    "-Dfontconfig=enabled -Dfreetype=enabled -Dxcb=disabled -Dxlib=disabled -Dtests=disabled"
build_meson pango "https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz" "-Dintrospection=disabled"

# --- 6. Sway & Wlroots ---
build_meson seatd "https://git.sr.ht/~kennylevinsen/seatd/archive/0.8.0.tar.gz" ""
build_meson libxkbcommon "https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz" "-Denable-x11=false"
build_meson xkeyboard-config "https://www.x.org/pub/individual/data/xkeyboard-config/xkeyboard-config-2.45.tar.xz" ""

build_meson wlroots "https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/0.17.2/wlroots-0.17.2.tar.gz" \
    "-Dbackends=drm,libinput -Dxwayland=disabled"

build_meson sway "https://github.com/swaywm/sway/releases/download/1.9/sway-1.9.tar.gz" "-Dxwayland=disabled"

# --- 3. Sway初期設定 & フォント配置 ---
echo "===== Configuring Sway & Fonts ====="
# ユーザー設定ディレクトリの準備
mkdir -pv /root/.config/sway
mkdir -pv /home/user/.config/sway
if [ -f /etc/sway/config ]; then
    cp -v /etc/sway/config /root/.config/sway/config
    cp -v /etc/sway/config /home/user/.config/sway/config
fi


# --- 7. foot ターミナルスタック ---
build_meson tllist "https://codeberg.org/dnkl/tllist.git" ""
build_meson fcft "https://codeberg.org/dnkl/fcft.git" "-Ddocs=disabled"
build_meson foot "https://codeberg.org/dnkl/foot.git" "-Dterminfo=enabled -Ddocs=disabled -Dtests=false"

# foot設定ファイル
mkdir -p /root/.config/foot
mkdir -p /home/user/.config/foot
cat > /root/.config/foot/foot.ini << EOF
[main]
font=Noto Sans Mono CJK JP:size=12

[colors-dark]
alpha=0.8
EOF

cat > /home/user/.config/foot/foot.ini << EOF
[main]
font=Noto Sans Mono CJK JP:size=12

[colors-dark]
alpha=0.8
EOF

# --- 8. 完了処理 ---
echo "---"
echo "===== ALL PHASES COMPLETE: Sway & foot are ready ====="
echo "Usage: Start Sway and use 'foot' as your terminal emulator."
