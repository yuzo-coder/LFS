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

# glib-2.80.4 の再ビルド
# 以前のビルドディレクトリがある場合は必ず削除してください (rm -rf build)
build_meson glib2 "https://download.gnome.org/sources/glib/2.86/glib-2.86.4.tar.xz" \
    "-Dtests=false" \
    "-Dintrospection=enabled"

# 3. fcitx5 本体
# 依存関係として libevent, libuuid が必要です
build_cmake "fcitx5" \
    "https://github.com/fcitx/fcitx5/archive/refs/tags/5.1.14.tar.gz" \
    "-DENABLE_ENCHANT=OFF"

# 4. fcitx5-gtk (GTKアプリでの入力用)
build_cmake "fcitx5-gtk" \
    "https://github.com/fcitx/fcitx5-gtk/archive/refs/tags/5.1.4.tar.gz" \
    "-DENABLE_GTK2_IM_MODULE=OFF -DENABLE_GTK3_IM_MODULE=ON -DENABLE_GTK4_IM_MODULE=OFF"

# 5. fcitx5-mozc (日本語入力エンジン)
echo "===== Building fcitx5-mozc ====="
# タグを指定して再帰的にクローン（サブモジュールも含む）
git clone --recursive https://github.com/fcitx/mozc.git fcitx5-mozc-src
cd fcitx5-mozc-src/src

# Fcitx5-Mozc は src ディレクトリ内に CMakeLists.txt があります
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX="/usr" \
      -DENABLE_QT=OFF \
      -DCMAKE_BUILD_TYPE=Release \
      .. > "$LOG/fcitx5-mozc.log" 2>&1

make -j$(nproc) >> "$LOG/fcitx5-mozc.log" 2>&1
make install >> "$LOG/fcitx5-mozc.log" 2>&1
ldconfig
cd "$ROOT_DIR"

echo "===== 15 FCITX Build Completed  ====="

