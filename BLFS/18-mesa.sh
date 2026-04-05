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
MESA_OPTS="-Dplatforms=wayland,x11 \
           -Dgallium-drivers=virgl,swrast \
           -Dvulkan-drivers=swrast \
           -Dgbm=enabled \
           -Dglx=dri \
           -Degl=enabled \
           -Dgles1=disabled \
           -Dgles2=enabled \
           -Dopengl=true \
           -Dllvm=enabled \
           -Dshared-llvm=enabled \
           -Dlibunwind=enabled \
           -Dgallium-vdpau=enabled \
           -Dmicrosoft-clc=disabled"

build_meson mesa "https://archive.mesa3d.org/mesa-24.0.3.tar.xz" "$MESA_OPTS"

ln -sv /usr/lib/pkgconfig/gl.pc /usr/lib/pkgconfig/opengl.pc || true

# --- 5. ユーティリティツールのビルド ---

build_meson glu "https://archive.mesa3d.org/glu/glu-9.0.3.tar.xz" ""

# 1. mesa-demos (eglinfo, es2gears_wayland 等)
build_meson mesa-demos "https://archive.mesa3d.org/demos/mesa-demos-9.0.0.tar.xz" \
    "-Dwayland=enabled -Dx11=disabled -Dgles2=enabled"

echo "=================================================="
echo "Mesa (VirtIO-GPU) and Utils Build Complete."
echo "Check acceleration with: eglinfo | grep renderer"
echo "=================================================="
