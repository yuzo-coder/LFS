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

build_autotools "sqlite" \
    "https://www.sqlite.org/2024/sqlite-autoconf-3450200.tar.gz" \
    "--disable-static"

build_autotools "python" \
    "https://www.python.org/ftp/python/3.13.7/Python-3.13.7.tar.xz" \
    "--enable-shared --with-system-expat --with-system-ffi --enable-optimizations"

# icu
echo "===== Building icu ====="
cd "$SRC"
wget https://github.com/unicode-org/icu/releases/download/release-78.3/icu4c-78.3-sources.tgz
tar -xf icu4c-78.3-sources.tgz
cd icu/source
./configure --prefix=/usr
make -j$(nproc)
make install
cd "$ROOT_DIR"


# nodejs
echo "===== nodejs ====="
cd "$SRC"
wget https://nodejs.org/dist/v24.14.1/node-v24.14.1.tar.xz
tar -xf node-v24.14.1.tar.xz
cd node-v24.14.1
./configure --prefix=/usr \
            --shared-zlib \
            --shared-openssl \
            --with-intl=system-icu
make -j$(nproc)
make install
cd "$ROOT_DIR"

# libwebp 
echo "===== Building libwebp ====="
cd "$SRC"
wget https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.5.0.tar.gz
tar -xf libwebp-1.5.0.tar.gz
cd libwebp-1.5.0
./configure --prefix=/usr           \
            --enable-everything      \
            --enable-libwebpdemux    \
            --enable-libwebpmux      \
            --enable-libwebpdecoder  \
            --disable-static > "$LOG/libwebp.log" 2>&1
make -j$(nproc) >> "$LOG/libwebp.log" 2>&1
make install >> "$LOG/libwebp.log" 2>&1
cd "$ROOT_DIR"

build_autotools libevent "https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz" ""



echo "===== Pre-Firefox installation completed! ====="
