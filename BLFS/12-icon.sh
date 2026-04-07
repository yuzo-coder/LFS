#!/bin/bash
# LFS Desktop Enhancer - Icons & Portals
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通ユーティリティ関数 ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# 1. すべてのアイコンテーマの基礎 (Meson/Autotoolsではなく単純な構成が多い)
echo "===== Building hicolor-icon-theme ====="
build_meson "hicolor-icon-theme" "https://icon-theme.freedesktop.org/releases/hicolor-icon-theme-0.18.tar.xz" ""

# 2. 標準カーソルテーマ (Adwaita)
# ※注: librsvgがない場合、アイコンの生成がスキップされることがありますが、
# カーソルファイル自体はインストールされるはずです。
build_meson "adwaita-icon-theme" \
    "https://download.gnome.org/sources/adwaita-icon-theme/46/adwaita-icon-theme-46.2.tar.xz" \
    ""
# json-glib の後、xdg-desktop-portal の前に追加
build_meson "fuse3" \
    "https://github.com/libfuse/libfuse/releases/download/fuse-3.16.2/fuse-3.16.2.tar.gz" \
    "-Dexamples=false -Duseroot=false -Dtests=false"

[ -e /dev/fuse ] || mknod /dev/fuse c 10 229

# fuse3 の後、xdg-desktop-portal の前に追加
build_meson "pipewire" \
    "https://github.com/PipeWire/pipewire/archive/refs/tags/1.0.7.tar.gz" \
    "-Dsession-managers=[] -Draop=disabled -Dbluez5=disabled -Dgstreamer=disabled -Dsystemd=disabled"

# pipewire の後、xdg-desktop-portal の前に追加
build_meson "bubblewrap" \
    "https://github.com/containers/bubblewrap/releases/download/v0.9.0/bubblewrap-0.9.0.tar.xz" \
    "-Dman=disabled -Dpython=python3 -Dc_std=c11"

# xdg-desktop-portal の前にこれを実行
build_meson "json-glib" \
    "https://download.gnome.org/sources/json-glib/1.6/json-glib-1.6.6.tar.xz" \
    "-Dintrospection=disabled -Dgtk_doc=disabled -Dtests=false"

# 3. xdg-desktop-portal (ポータル本体)
# Sway用ポータルの前に、これがないと pkg-config でエラーになります。
build_meson "xdg-desktop-portal" \
    "https://github.com/flatpak/xdg-desktop-portal/releases/download/1.18.4/xdg-desktop-portal-1.18.4.tar.xz" \
    ""

# build_meson wayland-protocols "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.38/downloads/wayland-protocols-1.38.tar.xz" ""

# xdg-desktop-portal の後、xdg-desktop-portal-wlr の前に追加
build_meson "inih" \
    "https://github.com/benhoyt/inih/archive/refs/tags/r58.tar.gz" \
    "-Ddistro_install=true -Dwith_INIReader=true"

# 4. xdg-desktop-portal-wlr (Sway専用実装)
build_meson "xdg-desktop-portal-wlr" \
    "https://github.com/emersion/xdg-desktop-portal-wlr.git" \
    "-Dsd-bus-provider=libsystemd -Dc_args=-Wno-error=implicit-function-declaration" # systemd環境でない場合は自動検知に任せる


echo "=================================================="
echo "   Desktop Enhancement Build Complete!            "
echo "   Icons and Portals are ready.                   "
echo "=================================================="
