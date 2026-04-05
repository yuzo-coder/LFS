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

# --- 2. 共通ユーティリティ関数 ---

download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    echo "Downloading $TAR..." >&2
    cd "$SRC"
    [ -f "$TAR" ] || wget -c "$URL" --no-check-certificate >&2
    
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$SRC/$DIR"
}

build_autotools() {
    local NAME=$1; local URL=$2; local CONF_OPTS=$3
    echo "===== Building $NAME (autotools) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    ./configure --prefix="$PREFIX" --libdir=/usr/lib $CONF_OPTS > "$LOG/$NAME.log" 2>&1
    make >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

build_meson() {
    local NAME=$1; local URL_OR_GIT=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    
    local DIR=""
    if [[ "$URL_OR_GIT" == *.git ]]; then
        cd "$SRC"
        rm -rf "$NAME"
        git clone "$URL_OR_GIT" "$NAME"
        DIR="$SRC/$NAME"
    else
        DIR=$(download_extract "$URL_OR_GIT")
    fi

    cd "$DIR"
    rm -rf build
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

build_cmake() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (cmake) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build && mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib $EXTRA .. > "$LOG/$NAME.log" 2>&1
    make >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}


# --- 3. PulseAudio 依存関係 & 本体ビルド ---

# 1. libsndfile (音声ファイルの読み書きに必須)
build_cmake "libsndfile" \
    "https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz" \
    "-DBUILD_SHARED_LIBS=ON -DENABLE_EXTERNAL_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5"

# 2. check (PulseAudioのビルドに推奨されるユニットテストフレームワーク)
build_cmake "check" \
    "https://github.com/libcheck/check/releases/download/0.15.2/check-0.15.2.tar.gz" \
    ""

# 3. PulseAudio 本体
# ALSA (Linux標準の音響層) との連携を有効にし、
# システム管理用(systemd等)の不要な依存はオフにします。
build_meson "pulseaudio" \
    "https://freedesktop.org/software/pulseaudio/releases/pulseaudio-17.0.tar.xz" \
    "-Ddatabase=gdbm \
     -Dbluez5=disabled \
     -Dgtk=disabled \
     -Dsystemd=disabled \
     -Dvalgrind=disabled \
     -Dman=false \
     -Dtests=false"

# --- 4. 権限と設定の調整 ---

echo "Configuring Audio Groups..."
# 音声デバイスにアクセスするためのグループ設定
groupadd -f pulse
groupadd -f pulse-access
groupadd -f audio
usermod -aG audio,pulse,pulse-access $TARGET_USER

# --- Network用 (libnl) ---
build_autotools "libnl" \
    "https://github.com/thom311/libnl/releases/download/libnl3_9_0/libnl-3.9.0.tar.gz" \
    "--sysconfdir=/etc --disable-static"

# --- Tray用 (libdbusmenu) ---
# ※これはGTK3版が必要です
# build_autotools "libdbusmenu" \
#     "https://launchpad.net/libdbusmenu/16.04/16.04.0/+download/libdbusmenu-16.04.0.tar.gz" \
#     "--with-gtk=3 --disable-static --disable-doxygen"

# Waybarの再ビルド
# Mesonが libpulse, libnl, libdbusmenu を自動検出し、モジュールを有効化します
#build_meson "waybar" \
#    "https://github.com/Alexays/Waybar/archive/refs/tags/0.10.0.tar.gz" \
#    "-Dpulseaudio=enabled -Dnetwork=enabled -Dlibnl=enabled -Dtray=enabled -Dlibdbusmenu=disabled"

# 4-5. Waybar (Final)
echo "===== Building Waybar ====="
WAYBAR_DIR=$(download_extract "https://github.com/Alexays/Waybar/archive/0.11.0.tar.gz")
cd "$WAYBAR_DIR"

# C++20標準を強制
export CXXFLAGS="-std=c++20"

meson setup build --prefix=/usr --libdir=/usr/lib --buildtype=release \
    -Dcpp_std=c++20 \
    -Dtests=disabled \
    -Dman-pages=disabled \
    -Dpulseaudio=enabled \
    -Dlibnl=enabled \
    -Ddbusmenu-gtk=disabled > "$LOG/waybar.log" 2>&1

ninja -C build -j"$JOBS" >> "$LOG/waybar.log" 2>&1
ninja -C build install >> "$LOG/waybar.log" 2>&1

echo "=================================================="
echo "   PulseAudio Build Complete!                    "
echo "   Please restart Sway and Waybar.               "
echo "=================================================="
