#!/bin/bash
set -euo pipefail

JOBS=$(nproc)
PREFIX=/usr
ROOT=$PWD
SRC=$ROOT/sources
LOG=$ROOT/logs

mkdir -p "$SRC" "$LOG"
cd "$SRC"

# --- ユーティリティ関数 ---

download_extract() {
    local URL=$1
    echo "Downloading ${URL##*/}..."
    wget -c "$URL" --no-check-certificate
    local TAR=${URL##*/}
    # 展開してディレクトリ名を取得（安全な方法に変更）
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$DIR"
}

build_autotools() {
    local NAME=$1; local URL=$2; local CONF_OPTS=$3
    echo "===== Building $NAME (autotools) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    ./configure --prefix="$PREFIX" --libdir=/usr/lib $CONF_OPTS > "$LOG/$NAME.log" 2>&1
    make -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd .. && rm -rf "$DIR"
}

build_meson() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build
    # libdir=/usr/lib を明示することで lib64 問題を回避
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd .. && rm -rf "$DIR"
}

build_cmake() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (cmake) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build && mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib $EXTRA .. > "$LOG/$NAME.log" 2>&1
    make -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd ../.. && rm -rf "$DIR"
}

# =============================
# 1. 基礎ライブラリ (Base)
# =============================

build_autotools expat "https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.xz" ""
build_autotools libffi "https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz" ""
build_autotools pcre2 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz" "--enable-unicode"

# GLib2 (Sway/Wayland系の基盤)
build_meson glib2 "https://download.gnome.org/sources/glib/2.80/glib-2.80.4.tar.xz" "-Dtests=false"

# json-c (Swayの依存: 前回のハマりどころ)
build_cmake json-c "https://s3.amazonaws.com/json-c_releases/releases/json-c-0.18.tar.gz" ""

# =============================
# 2. Wayland 核心部 (これがないと始まらない)
# =============================

build_meson wayland "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.0/downloads/wayland-1.23.0.tar.xz" "-Ddocumentation=false"
build_meson wayland-protocols "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.36/downloads/wayland-protocols-1.36.tar.xz" ""
build_meson libdisplay-info "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/archive/0.2.0/libdisplay-info-0.2.0.tar.gz" ""

# =============================
# 3. 入力スタック (Input Stack)
# =============================

build_autotools libevdev "https://www.freedesktop.org/software/libevdev/libevdev-1.13.1.tar.xz" "--disable-static"
build_autotools mtdev "https://bitmath.org/code/mtdev/mtdev-1.1.6.tar.gz" "--disable-static"
build_meson libgudev "https://download.gnome.org/sources/libgudev/238/libgudev-238.tar.xz" "-Dtests=disabled"
build_meson libwacom "https://github.com/linuxwacom/libwacom/releases/download/libwacom-2.12.0/libwacom-2.12.0.tar.xz" "-Dtests=disabled"

# libinput (udevを確実に有効化)
build_meson libinput "https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.25.0/libinput-1.25.0.tar.gz" "-Ddebug-gui=false -Dudev=enabled"

echo "===== PHASE1 COMPLETE: Core graphics/input libraries installed ====="
