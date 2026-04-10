#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=${ROOT_DIR:-$(pwd)}
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

build_autotools nasm "https://www.nasm.us/pub/nasm/releasebuilds/3.01/nasm-3.01.tar.xz" ""

# x264
# グラフィックスの安定性を確保する
build_autotools "x264" \
    "https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2" \
    "--enable-shared --enable-pic --disable-cli --host=x86_64-linux"

# libva
# 動画支援の窓口を作る
build_meson libva "https://github.com/intel/libva/releases/download/2.22.0/libva-2.22.0.tar.bz2" ""

# fdk-aac
# 高品質なAAC再生
build_autotools "fdk-aac" \
    "https://downloads.sourceforge.net/opencore-amr/fdk-aac-2.0.3.tar.gz" \
    "--disable-static"

# libvpx
echo "===== Building libvpx ====="
cd "$SRC"
wget https://github.com/webmproject/libvpx/archive/v1.16.0/libvpx-1.16.0.tar.gz
tar -xf libvpx-1.16.0.tar.gz
cd libvpx-1.16.0
mkdir -p build && cd build
../configure --prefix=/usr \
             --enable-shared \
             --disable-static \
             --enable-vp8 \
             --enable-vp9 \
             --enable-postproc \
             --enable-vp9-highbitdepth \
             --enable-pic > "$LOG/libvpx.log" 2>&1
make -j$(nproc) >> "$LOG/libvpx.log" 2>&1
make install >> "$LOG/libvpx.log" 2>&1
cd "$ROOT_DIR"

# 1. ffmpeg
echo "===== Building FFMPEG ====="
cd "$SRC"
wget https://ftp.lfs-matrix.net/pub/blfs/12.3/f/ffmpeg-7.1.tar.xz
tar xf ffmpeg-7.1.tar.xz
cd ffmpeg-7.1

# 1. configure を手動で実行（設定を生成する）
# ここでエラーが出ないか注視してください。
./configure --prefix=/usr               \
            --enable-shared             \
            --disable-static            \
            --enable-gpl                \
            --enable-version3           \
            --enable-nonfree            \
            --enable-libvpx             \
            --enable-libx264            \
            --enable-vdpau              \
            --enable-vaapi              \
            --enable-runtime-cpudetect  \
            --enable-libfdk-aac         \
            --disable-debug             \
            --disable-doc               \
            --extra-cflags="-march=native -O2" \
            --extra-cxxflags="-march=native -O2"

# 2. 上記が成功したら make を実行
# (config.mak が作成されているので、今度はエラーになりません)
make -j$(nproc)

# 3. インストール
make install
ldconfig

echo "=================================================="
echo "FFMPEG Build Complete."
echo "Check acceleration with: eglinfo | grep renderer"
echo "=================================================="
