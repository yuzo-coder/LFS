#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
mkdir -p "$SRC" "$LOG"

# 共通関数の読み込み
if [ -f "./common.sh" ]; then
    source "./common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi


build_autotools lcms2 "https://github.com/mm2/Little-CMS/releases/download/lcms2.17/lcms2-2.17.tar.gz" ""

# libplacebo
cd "$SRC"

rm -rf libplacebo

git clone --recursive https://github.com/haasn/libplacebo.git

cd libplacebo

git checkout v7.360.1

git submodule update --init --recursive

# --- 2. ビルド設定 (Meson) ---
mkdir -v build
cd build

# LFS環境に合わせて、必須でないものは auto にしつつ、
meson setup .. \
    --prefix=/usr \
    --buildtype=release \
    -Dshaderc=disabled \
    -Dvulkan=enabled \
    -Dlcms=enabled \
    -Dopengl=enabled > "$LOG/libplacebo.log" 2>&1

# --- 3. コンパイルとインストール ---
echo "Starting libplacebo build with 36 cores..."
ninja  >> "$LOG/libplacebo.log" 2>&1
ninja install >> "$LOG/libplacebo.log" 2>&1

cd "$SRC"
echo "libplacebo Installation Complete!"


build_autotools libass "https://github.com/libass/libass/releases/download/0.17.4/libass-0.17.4.tar.xz" ""


echo "===== Building luajit ====="
cd "$SRC"
wget https://anduin.linuxfromscratch.org/BLFS/luajit/luajit-20250212.tar.xz

rm -rf luajit-20250212

tar -xf luajit-20250212.tar.xz

cd luajit-20250212

# 2. コンパイル
make PREFIX=/usr

# 3. インストール
make install PREFIX=/usr

# 4. mpvが正しく認識できるようにパスを整える
# (mpvのMesonは pkg-config を見に行きます)
ln -sfv /usr/lib/pkgconfig/luajit.pc /usr/lib/pkgconfig/lua-5.1.pc

ldconfig

cd "$SRC"


# mpv
build_meson "mpv" \
    "https://github.com/mpv-player/mpv/archive/refs/tags/v0.41.0.tar.gz" \
    "-Dalsa=enabled \
    -Dpulse=enabled \
    -Dpipewire=enabled \
    -Dwayland=enabled \
    -Dx11=enabled \
    -Dlua=enabled \
    --libdir=/usr/lib \
    -Dlibmpv=true \
    -Djavascript=disabled"

echo "mpv --vo=gpu /pathtovideo "

echo "===== COMPLETE ====="
