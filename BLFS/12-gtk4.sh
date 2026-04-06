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
    "-Dintrospection=disabled"

# 2. libepoxy (GPU描画の管理)
build_meson "libepoxy" \
    "https://github.com/anholt/libepoxy/archive/refs/tags/1.5.10.tar.gz" ""

# 3. GTK4 本体
# ※ビルドに時間がかかりますが、Z840なら数分です。
build_meson "gtk4" \
    "https://download.gnome.org/sources/gtk/4.12/gtk-4.12.5.tar.xz" \
    "-Dbuild-tests=false -Dbuild-examples=false -Dintrospection=disabled -Dvulkan=disabled -Dx11-backend=false -Dmedia-gstreamer=disabled"

# Fontconfig 2.17.1 (最新安定版)
# ※ これが Pango の要求を満たします
build_autotools "fontconfig" \
    "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.17.1/fontconfig-2.17.1.tar.xz" \
    "--disable-docs --sysconfdir=/etc --localstatedir=/var"

# 4. gtkmm-4.0 (pavucontrol の直接の依存先)
build_meson "gtkmm4" \
    "https://download.gnome.org/sources/gtkmm/4.12/gtkmm-4.12.0.tar.xz" ""

echo "===== 11-GTK4 ALL BUILD & CONFIG COMPLETED ====="
