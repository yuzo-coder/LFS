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

download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    cd "$SRC"
    echo "Downloading $TAR..." >&2
    [ -f "$TAR" ] || wget -c "$URL" --no-check-certificate >&2
    
    # ディレクトリ名を特定
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    # 特殊なケース（tarの中身が直下のファイル群の場合）の対策
    if [ -z "$DIR" ]; then DIR="${TAR%.tar*}"; fi
    
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$SRC/$DIR"
}

build_meson() {
    local NAME=$1; local URL_OR_GIT=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    
    local DIR=""
    if [[ "$URL_OR_GIT" == *.git ]]; then
        cd "$SRC"
        rm -rf "$NAME"
        git clone --depth 1 "$URL_OR_GIT" "$NAME"
        DIR="$SRC/$NAME"
    else
        DIR=$(download_extract "$URL_OR_GIT")
    fi

    cd "$DIR"
    rm -rf build
    # --libdir=/usr/lib を明示することで 64bit 環境での不整合を防ぐ
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
}

# --- 3. メインビルドプロセス ---

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
