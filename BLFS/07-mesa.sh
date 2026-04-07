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


# libvdpau
# 動画支援の窓口を作る
build_meson libvdpau ""https://gitlab.freedesktop.org/vdpau/libvdpau/-/archive/1.5/libvdpau-1.5.tar.bz2 "-Ddri2=true -Ddocumentation=false"

# 2. libunwind 
# グラフィックスの安定性を確保する
build_autotools "libunwind" \
    "https://download.savannah.nongnu.org/releases/libunwind/libunwind-1.6.2.tar.gz" \
    "--disable-static --enable-coredump --host=x86_64-linux"

# --- 4. Mesa本体のビルド (VirtIO 3D加速対応) ---
# QEMU環境で爆速にするための重要フラグ:
# - gallium-drivers=virtio,swrast (仮想ドライバとソフトウェアバックアップ)
# - vulkan-drivers=swrast (Vulkanはひとまずソフトのみ)
# libunwind の有効化（デバッグと安定性）
# gallium-vdpau の有効化（動画再生の支援）
# microsoft-clc の明示的な無効化（ビルドエラー回避）
#MESA_OPTS="-Dplatforms=wayland,x11 \
#           -Dgallium-drivers=virgl,swrast \
#           -Dvulkan-drivers=swrast \
#           -Dgbm=enabled \
#           -Dglx=dri \
#           -Degl=enabled \
#           -Dgles1=disabled \
#           -Dgles2=enabled \
#           -Dopengl=true \
#           -Dllvm=enabled \
#           -Dshared-llvm=enabled \
#           -Dlibunwind=enabled \
#           -Dgallium-vdpau=enabled \
#           -Dmicrosoft-clc=disabled"

#build_meson mesa "https://archive.mesa3d.org/mesa-24.0.3.tar.xz" "$MESA_OPTS"

build_meson libdisplay-info "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/archive/0.2.0/libdisplay-info-0.2.0.tar.gz" ""

build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" ""

echo "===== Building glslang 16.2.0 ====="
cd "$SRC"
wget https://github.com/KhronosGroup/glslang/archive/16.2.0/glslang-16.2.0.tar.gz
tar -xf glslang-16.2.0.tar.gz
cd glslang-16.2.0

# 2. ビルド用ディレクトリの作成
mkdir build && cd build

# 3. CMake 実行
cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release   \
      -D ENABLE_OPT=OFF            \
      -G "Unix Makefiles" ..

# 4. コンパイルとインストール
make -j$(nproc)
make install
ldconfig
cd "$ROOT_DIR"

build_meson mesa "https://archive.mesa3d.org/mesa-24.0.5.tar.xz" \
    "-Dplatforms=wayland,x11 -Dopengl=true -Dglx=dri -Dgles1=disabled -Dgles2=enabled -Degl=enabled -Dgbm=enabled -Dgallium-drivers=virgl,swrast -Dvulkan-drivers=auto -Dllvm=enabled"

ln -sv /usr/lib/pkgconfig/gl.pc /usr/lib/pkgconfig/opengl.pc || true
# opengl.pc を gl.pc として参照できるようにリンクを貼る
# ln -s /usr/lib/pkgconfig/opengl.pc /usr/lib/pkgconfig/gl.pc

# --- 5. ユーティリティツールのビルド ---

build_meson glu "https://archive.mesa3d.org/glu/glu-9.0.3.tar.xz" ""


echo "=================================================="
echo "Mesa (VirtIO-GPU) and Utils Build Complete."
echo "Check acceleration with: eglinfo | grep renderer"
echo "=================================================="
