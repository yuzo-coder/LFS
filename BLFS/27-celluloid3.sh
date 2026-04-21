#!/bin/bash
set -euo pipefail

source "./common.sh"

JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
mkdir -p "$SRC" "$LOG"


echo "===== shaderc ====="
cd "$SRC"

wget https://github.com/google/shaderc/archive/v2026.1/shaderc-2026.1.tar.gz

rm -rf shaderc-2026.1

tar -xf shaderc-2026.1.tar.gz

cd shaderc-2026.1

# 2. 外部依存リポジトリ（glslang, SPIRV-Tools等）の取得
# これを忘れるとビルド時に「ファイルがない」と怒られます
./utils/git-sync-deps

# 3. ビルドディレクトリの作成
mkdir build && cd build

# 4. CMake の実行
# -DSHADERC_SKIP_TESTS=ON でテストをスキップして時間を短縮します
cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DSHADERC_SKIP_TESTS=ON \
    -DSHADERC_SKIP_EXAMPLES=ON

make 

make install

cd "$ROOT_DIR"

echo "===== Building libadwaita ====="
cd "$SRC"

wget https://download.gnome.org/sources/libadwaita/1.6/libadwaita-1.6.4.tar.xz

rm -rf libadwaita-1.6.4

tar -xf libadwaita-1.6.4.tar.xz

cd libadwaita-1.6.4

meson subprojects download
sed -i "s|subdir('docs/')|# subdir('docs/')|" subprojects/appstream/meson.build
sed -i "s|subdir('docs')|# subdir('docs')|" subprojects/appstream/meson.build
# --- 2. ビルド設定 (CMake) ---
mkdir -p build && cd build

meson setup .. \
    --prefix=/usr \
    --buildtype=release \
    -Dtests=false \
    -Dintrospection=enabled \
    --wrap-mode=nodownload \
    -Dvapi=true

ninja > "$LOG/libadwaita.log" 2>&1
ninja install >> "$LOG/libadwaita.log" 2>&1
ldconfig
cd "$ROOT_DIR"

echo "libadwaita Installation Complete!"

build_meson "desktop-file-utils" \
    "https://www.freedesktop.org/software/desktop-file-utils/releases/desktop-file-utils-0.28.tar.xz" \
    ""

build_meson "celluloid" \
    "https://github.com/celluloid-player/celluloid/archive/refs/tags/v0.28.tar.gz" \
    ""


echo "===== COMPLETE ====="

