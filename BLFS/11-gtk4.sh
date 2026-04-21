#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
TARGET_USER="user"

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# --- GTK4 Stack Dependencies ---


# 1. graphene (GTK4に必須の数学ライブラリ)
build_meson "graphene" \
    "https://github.com/ebassi/graphene/archive/refs/tags/1.10.8.tar.gz" \
    "-Dintrospection=enabled"

# 2. libepoxy (GPU描画の管理)
# build_meson "libepoxy" \
#    "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz" ""

# 3. GTK4 本体
# ※ビルドに時間がかかりますが、Z840なら数分です。
build_meson "gtk4" \
    "https://download.gnome.org/sources/gtk/4.12/gtk-4.12.5.tar.xz" \
    "-Dbuild-tests=false -Dbuild-examples=false -Dintrospection=enabled -Dvulkan=disabled -Dx11-backend=true -Dwayland-backend=true -Dmedia-gstreamer=disabled"


# Fontconfig 2.17.1 (最新安定版)
# ※ これが Pango の要求を満たします
build_autotools "fontconfig" \
    "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.17.1/fontconfig-2.17.1.tar.xz" \
    "--disable-docs --sysconfdir=/etc --localstatedir=/var"

build_mm_lib libsigc++ "https://download.gnome.org/sources/libsigc++/2.12/libsigc++-2.12.0.tar.xz" ""

build_mm_lib libsigc++3 "https://download.gnome.org/sources/libsigc++/3.6/libsigc++-3.6.0.tar.xz" ""

echo "===== Building mm-common ====="
DIR=$(download_extract "https://download.gnome.org/sources/mm-common/1.0/mm-common-1.0.6.tar.xz")

cd "$DIR"
    
rm -rf build && mkdir build && cd build

meson setup .. --prefix=/usr --buildtype=release > "$LOG/mm-common.log" 2>&1

ninja install >> "$LOG/mm-common.log" 2>&1

cd "$ROOT_DIR"
# ===== end mm-common ====="

build_mm_lib cairomm "https://www.cairographics.org/releases/cairomm-1.18.0.tar.xz" "--wrap-mode=nofallback"

build_mm_lib glibmm "https://download.gnome.org/sources/glibmm/2.66/glibmm-2.66.7.tar.xz" \
    "-Dbuild-documentation=false"

build_mm_lib pangomm "https://download.gnome.org/sources/pangomm/2.54/pangomm-2.54.0.tar.xz" "-Dbuild-documentation=false"

build_mm_lib atkmm "https://download.gnome.org/sources/atkmm/2.28/atkmm-2.28.4.tar.xz" "--wrap-mode=nofallback"


groupadd -g 133 rtkit &&
useradd -c "RealtimeKit Daemon User" -d /var/lib/rtkit -u 133 -g rtkit -s /bin/false rtkit

mkdir -p /var/lib/rtkit
chown rtkit:rtkit /var/lib/rtkit
chmod 750 /var/lib/rtkit 
    
build_meson rtkit "https://github.com/heftig/rtkit/releases/download/v0.13/rtkit-0.13.tar.xz" "-Dlibsystemd=disabled"

build_meson gtkmm3 "https://download.gnome.org/sources/gtkmm/3.24/gtkmm-3.24.9.tar.xz" "-Dbuild-demos=false -Dbuild-tests=false"

# 4. gtkmm-4.0 (pavucontrol の直接の依存先)
build_meson "gtkmm4" \
    "https://download.gnome.org/sources/gtkmm/4.12/gtkmm-4.12.0.tar.xz" "--wrap-mode=nodownload -Dbuild-demos=false -Dbuild-tests=false"

echo "===== 11-GTK4 ALL BUILD & CONFIG COMPLETED ====="
