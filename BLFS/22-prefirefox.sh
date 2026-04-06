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

# unzip
echo "===== Building unzip ====="
cd "$SRC"
wget https://downloads.sourceforge.net/infozip/unzip60.tar.gz
tar -xf unzip60.tar.gz
cd unzip60
# 2. 前回の gmtime エラーの修正だけを適用（これだけで十分です）
sed -i 's/struct tm \*gmtime(), \*localtime();/\/* struct tm *gmtime(), *localtime(); *\//' unix/unxcfg.h
gcc -c -I. -Ibzip2 -DUNIX -O3 -DLARGE_FILE_SUPPORT -DUNICODE_SUPPORT -DHAVE_DIRENT_H -DHAVE_TERMIOS_H *.c unix/unix.c
# 1. unzip本体に関係ない、別の「main」を持つファイルを削除
rm -f funzip.o gbloffs.o unzipstb.o unzipsfx.o
gcc -o unzip *.o -lbz2
cp -v unzip /usr/bin/
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

build_autotools nasm "https://www.nasm.us/pub/nasm/releasebuilds/3.01/nasm-3.01.tar.xz" ""

# --- 2. Firefox 専用ビルド処理 ---
FIREFOX_URL="https://archive.mozilla.org/pub/firefox/releases/140.9.0esr/source/firefox-140.9.0esr.source.tar.xz"
NAME="firefox-140.9.0"

echo "===== Building $NAME ====="
cd "$SRC"
wget $FIREFOX_URL
tar xf firefox-140.9.0esr.source.tar.xz 
echo "$NAME"
cd "$NAME"

# Firefox は専用の .mozconfig ファイルで設定を行います
cat << EOF > .mozconfig
# インストール先
ac_add_options --prefix=$PREFIX

# ビルドオプション
ac_add_options --enable-application=browser
ac_add_options --enable-optimize
ac_add_options --enable-release
ac_add_options --enable-linker=gold

# システムライブラリの利用設定（LFSの既存ライブラリを優先）
ac_add_options --with-system-icu
ac_add_options --with-system-zlib
ac_add_options --with-system-webp
ac_add_options --with-system-png
ac_add_options --with-system-jpeg
ac_add_options --with-system-libvpx
ac_add_options --with-system-ffi

# オーディオ設定 (先ほど構築した PipeWire/PulseAudio 用)
ac_add_options --enable-alsa
ac_add_options --enable-pulseaudio

# 機能制限（ビルド時間短縮と安定性のため）
ac_add_options --disable-tests
ac_add_options --disable-debug
ac_add_options --disable-crashreporter
ac_add_options --disable-updater

# 並列ビルド設定
mk_add_options MOZ_MAKE_FLAGS="-j$JOBS"
EOF

echo "Starting Firefox build (This may take an hour or more)..."
pwd
# mach を使ってビルド開始
./mach build > "$LOG/firefox.log" 2>&1

echo "Installing Firefox..."
DESTDIR="/" ./mach install >> "$LOG/firefox.log" 2>&1

ldconfig
cd "$ROOT_DIR"

echo "===== Firefox installation completed! ====="
