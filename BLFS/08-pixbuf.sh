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

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# 1. libtiff (画像の基礎ライブラリ)
build_autotools "libtiff" \
    "https://download.osgeo.org/libtiff/tiff-4.7.1.tar.gz" \
    "--disable-static"

# libyuv (libavif の依存関係)
# 共有ライブラリとしてビルドし、LFS の標準パスへインストール
echo "===== Building libyuv (CMake/Manual Install) ====="
cd "$SRC"
rm -rf libyuv
git clone https://chromium.googlesource.com/libyuv/libyuv
cd libyuv
rm -rf build && mkdir build && cd build
# 共有ライブラリ (.so) を生成するように指定
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON .. > "$LOG/libyuv.log" 2>&1

make -j"$JOBS" >> "$LOG/libyuv.log" 2>&1
# libyuv は "make install" が不完全な場合があるため、手動で確実に配置
cp libyuv.so* /usr/lib/
mkdir -p /usr/include/libyuv
cp -r ../include/* /usr/include/
# 一部のアプリが include/libyuv/libyuv.h ではなく include/libyuv.h を探すための対策
cp ../include/libyuv.h /usr/include/
ldconfig
cd "$ROOT_DIR"

# yasm (GCC 15/C23 対策版：環境変数としてフラグを渡す)
echo "===== Building yasm (autotools - C99 mode) ====="
DIR=$(download_extract "https://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz")
cd "$DIR"
# 失敗した形跡を完全にクリア
make distclean || true
# CFLAGS/CPPFLAGS を環境変数として configure に渡す
CFLAGS="-g -O2 -std=gnu99" \
CPPFLAGS="-std=gnu99" \
./configure --prefix="$PREFIX" > "$LOG/yasm.log" 2>&1
make -j"$JOBS" >> "$LOG/yasm.log" 2>&1
make install >> "$LOG/yasm.log" 2>&1
ldconfig
cd "$ROOT_DIR"

# 1. libaom (AV1 コーデックの参照実装)
# https://storage.googleapis.com/aom-releases/libaom-3.13.2.tar.gz
echo "===== Building libaom (CMake) ====="
DIR=$(download_extract "https://storage.googleapis.com/aom-releases/libaom-3.13.2.tar.gz")
cd "$DIR"
# aom はソースツリー内ビルドを禁止しているため、明示的にディレクトリを作成
rm -rf aom_build && mkdir aom_build && cd aom_build
# 共有ライブラリを有効にし、テストを無効化してビルド時間を短縮
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON \
      -DENABLE_DOCS=OFF \
      -DENABLE_TESTS=OFF \
      -DENABLE_EXAMPLES=OFF \
      -DENABLE_TOOLS=OFF .. > "$LOG/libaom.log" 2>&1
make -j"$JOBS" >> "$LOG/libaom.log" 2>&1
make install >> "$LOG/libaom.log" 2>&1
ldconfig
cd "$ROOT_DIR"

# 2. libavif (AVIF サポート - 必要であれば)
build_cmake "libavif" \
    "https://github.com/AOMediaCodec/libavif/archive/v1.4.1/libavif-1.4.1.tar.gz" \
    "-DAVIF_CODEC_AOM=SYSTEM -DAVIF_LIBYUV=SYSTEM"

build_meson shared-mime-info "https://gitlab.freedesktop.org/xdg/shared-mime-info/-/archive/2.4/shared-mime-info-2.4.tar.gz" ""

# 5-1. libjpeg-turbo
echo "===== Building libjpeg-turbo ====="
DIR=$(download_extract "https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz")
cd "$DIR"
rm -rf build && mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_BUILD_TYPE=RELEASE \
      -DENABLE_STATIC=FALSE \
      -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .. > "$LOG/libjpeg-turbo.log" 2>&1
make -j"$JOBS" >> "$LOG/libjpeg-turbo.log" 2>&1
make install >> "$LOG/libjpeg-turbo.log" 2>&1
ldconfig
cd "$ROOT_DIR"

# 3. gdk-pixbuf (先にビルドして librsvg のインストール先を確定させる)
build_meson "gdk-pixbuf" \
    "https://gitlab.gnome.org/GNOME/gdk-pixbuf.git" \
    "-Dbuiltin_loaders=none -Djpeg=enabled -Dtests=false -Dpng=enabled -Dtiff=enabled -Dintrospection=disabled -Dman=false -Dglycin=disabled"

gdk-pixbuf-query-loaders --update-cache

update-mime-database /usr/share/mime

echo "===== Image Stack Build Completed (Minimal) ====="
