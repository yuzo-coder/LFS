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



build_cmake "Vulkan-Headers" \
    "https://github.com/KhronosGroup/Vulkan-Headers/archive/v1.4.321/Vulkan-Headers-1.4.321.tar.gz" \
    ""


echo "===== Building Vulkan ====="
cd "$SRC"

wget https://github.com/KhronosGroup/Vulkan-Loader/archive/v1.4.321/Vulkan-Loader-1.4.321.tar.gz

rm -rf Vulkan-Loader-1.4.321

tar -xf Vulkan-Loader-1.4.321.tar.gz

cd Vulkan-Loader-1.4.321 

# --- 2. ビルド設定 (CMake) ---
# Vulkan-LoaderはCMakeを使用します
mkdir -p build && cd build

cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_BUILD_TYPE=Release \
      -DVULKAN_HEADERS_INSTALL_DIR=/usr \
      -DBUILD_WSI_XCB_SUPPORT=ON \
      -DBUILD_WSI_XLIB_SUPPORT=ON \
      -DBUILD_WSI_WAYLAND_SUPPORT=ON \
      -GNinja .. > "$LOG/vulkan_loader.log" 2>&1

# --- 3. コンパイルとインストール ---
echo "Starting Vulkan-Loader build with 36 cores..."
ninja  >> "$LOG/vulkan_loader.log" 2>&1
ninja install >> "$LOG/vulkan_loader.log" 2>&1

echo "Vulkan-Loader Installation Complete!"



build_autotools "libfyaml" \
    "https://github.com/pantoniou/libfyaml/releases/download/v0.9/libfyaml-0.9.tar.gz" \
    "--disable-static"

build_autotools "libxml2" \
    "https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz" \
    "--disable-static"

build_autotools "itstool" \
    "https://files.itstool.org/itstool/itstool-2.0.7.tar.bz2" \
    "--disable-static"


build_autotools "bash-completion" \
    "https://github.com/scop/bash-completion/releases/download/2.16.0/bash-completion-2.16.0.tar.xz" \
    "--disable-static"


build_autotools "vapigen" \
    "https://download.gnome.org/sources/vala/0.56/vala-0.56.18.tar.xz" \
    "--disable-valadoc"


build_meson "gdk-pixbuf" \
    "https://gitlab.gnome.org/GNOME/gdk-pixbuf.git" \
    "-Dbuiltin_loaders=none -Djpeg=enabled -Dtests=false -Dpng=enabled -Dtiff=enabled -Dintrospection=enabled -Dman=false -Dglycin=disabled"


echo "===== COMPLETE ====="
