#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
TARGET_USER="user" # 一般ユーザー名

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi



# 1. extra-cmake-modules (ビルド支援ツール)
build_cmake "extra-cmake-modules" \
    "https://download.kde.org/stable/frameworks/6.11/extra-cmake-modules-6.11.0.tar.xz" \
    ""

# 2. xcb-util-keysyms (依存ライブラリ)
build_autotools "xcb-util-keysyms" \
    "https://xcb.freedesktop.org/dist/xcb-util-keysyms-0.4.1.tar.xz" \
    ""

# libxcb-1.17.0 のビルド
build_autotools "libxcb" \
    "https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz" \
    "--prefix=/usr --disable-static --enable-xinput"

# 1. xcb-util (AUX を提供)
build_autotools "xcb-util" \
    "https://xcb.freedesktop.org/dist/xcb-util-0.4.1.tar.xz" \
    ""

# 2. xcb-util-wm (ICCCM と EWMH を提供)
build_autotools "xcb-util-wm" \
    "https://xcb.freedesktop.org/dist/xcb-util-wm-0.4.2.tar.xz" \
    ""

# xcb-imdkit-1.0.9 (Fcitx5 5.1.14 が要求する 1.0.3 以上を満たします)
build_cmake "xcb-imdkit" \
    "https://github.com/fcitx/xcb-imdkit/archive/refs/tags/1.0.9.tar.gz" \
    ""

# libxkbcommon-1.7.0 (最新版に合わせて調整してください)
build_meson "libxkbcommon" \
    "https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz" \
    "-Denable-x11=true"


build_cmake "fcitx5" \
    "https://github.com/fcitx/fcitx5/archive/refs/tags/5.1.14.tar.gz" \
    "-DENABLE_ENCHANT=OFF -DENABLE_WAYLAND=ON -DENABLE_X11=ON"

# 4. fcitx5-gtk (GTKアプリでの入力用)
build_cmake "fcitx5-gtk" \
    "https://github.com/fcitx/fcitx5-gtk/archive/refs/tags/5.1.4.tar.gz" \
    "-DENABLE_GTK2_IM_MODULE=OFF -DENABLE_GTK3_IM_MODULE=ON -DENABLE_GTK4_IM_MODULE=OFF"

echo "===== /etc/xdg/fcitx5/profile ====="

mkdir -p /etc/xdg/fcitx5

rm -rf /etc/xdg/fcitx5/profile

cat << 'EOF' > /etc/xdg/fcitx5/profile

[Groups/0]
Name=Default
Default Layout=jp
# keyboard-jp を先頭（または anthy の前）に置く
DefaultIMList=keyboard-jp,anthy

[Groups/0/Items/0]
Name=keyboard-jp
Layout=

[Groups/0/Items/1]
Name=anthy
Layout=

[GroupOrder]
0=Default
EOF

echo "===== 15 FCITX Build Completed  ====="

