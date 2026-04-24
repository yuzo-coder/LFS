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

chmod 4755 /usr/bin/fusermount3

# fuse3 の後、xdg-desktop-portal の前に追加
build_meson "pipewire" \
    "https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/1.4.7/pipewire-1.4.7.tar.bz2" \
    "-Dsession-managers=[] -Draop=disabled -Dbluez5=disabled -Dgstreamer=enabled -Dsystemd=disabled"

# pipewire の後、xdg-desktop-portal の前に追加
build_meson "bubblewrap" \
    "https://github.com/containers/bubblewrap/releases/download/v0.9.0/bubblewrap-0.9.0.tar.xz" \
    "-Dman=disabled -Dpython=python3 -Dc_std=c11"

# xdg-desktop-portal の前にこれを実行
build_meson "json-glib" \
    "https://download.gnome.org/sources/json-glib/1.6/json-glib-1.6.6.tar.xz" \
    "-Dintrospection=disabled -Dgtk_doc=disabled -Dtests=false"



build_cmake "graphviz" \
    "https://ftp2.osuosl.org/pub/blfs/12.4/g/graphviz-13.1.2.tar.bz2" \
    "-D ENABLE_QT=OFF             \
      -D ENABLE_VISIO=OFF          \
      -D ENABLE_PHP=OFF            \
      -D ENABLE_PYTHON=OFF         \
      -D ENABLE_PERL=OFF           \
      -D ENABLE_LUA=OFF            \
       .."

build_autotools "vala" \
    "https://ftp2.osuosl.org/pub/blfs/12.4/v/vala-0.56.18.tar.xz" \
    ""

build_autotools "libpcap" \
    "https://ftp2.osuosl.org/pub/blfs/12.4/l/libpcap-1.10.5.tar.gz" \
    ""

build_meson "umockdev" \
    "https://ftp2.osuosl.org/pub/blfs/12.4/u/umockdev-0.19.3.tar.xz" \
    "-Dgtk_doc=false"


build_meson "libgudev" \
    "https://ftp2.osuosl.org/pub/blfs/12.4/l/libgudev-238.tar.xz" \
    "-Dtests=disabled -Dintrospection=enabled"

python3 -m pip install pytest


build_meson "pygobject" \
    "https://download.gnome.org/sources/pygobject/3.52/pygobject-3.52.3.tar.gz" \
    "-Dtests=false"

build_meson "dbus-python" \
    "https://dbus.freedesktop.org/releases/dbus-python/dbus-python-1.4.0.tar.xz" ""

python3 -m pip install python-dbusmock

build_meson "xdg-desktop-portal" \
    "https://ftp2.osuosl.org/pub/blfs/12.4/x/xdg-desktop-portal-1.20.3.tar.xz" \
    ""


# build_meson wayland-protocols "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.38/downloads/wayland-protocols-1.38.tar.xz" ""

# xdg-desktop-portal の後、xdg-desktop-portal-wlr の前に追加
build_meson "inih" \
    "https://github.com/benhoyt/inih/archive/refs/tags/r58.tar.gz" \
    "-Ddistro_install=true -Dwith_INIReader=true"

# 4. xdg-desktop-portal-wlr (Sway専用実装)
build_meson "xdg-desktop-portal-wlr" \
    "https://github.com/emersion/xdg-desktop-portal-wlr.git" \
    "-Dsd-bus-provider=libsystemd -Dc_args=-Wno-error=implicit-function-declaration"


echo "=================================================="
echo "   Desktop Enhancement Build Complete!            "
echo "   Icons and Portals are ready.                   "
echo "=================================================="
