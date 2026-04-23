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

build_meson libdisplay-info "https://gitlab.freedesktop.org/emersion/libdisplay-info/-/archive/0.2.0/libdisplay-info-0.2.0.tar.gz" ""

build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" ""

echo "===== Building glslang 16.2.0 ====="
cd "$SRC"

rm -rf glslang-16.2.0

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

cargo install bindgen-cli


echo "===== libclc ====="

cd "$SRC"

rm -rf libclc-20.1.8.src

wget https://github.com/llvm/llvm-project/releases/download/llvmorg-20.1.8/libclc-20.1.8.src.tar.xz

tar -xf libclc-20.1.8.src.tar.xz

cd libclc-20.1.8.src

mkdir -pv build

cd build

cmake -DCMAKE_INSTALL_PREFIX=/usr               \
      -DCMAKE_BUILD_TYPE=Release                \
      -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
      -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
      -DLLVM_TARGETS_TO_BUILD="X86"             \
      -DLLVM_LINK_LLVM_DYLIB=ON                 \
      -DLLVM_ENABLE_RTTI=ON                     \
      -DLLVM_INCLUDE_BENCHMARKS=OFF             \
      -DCLANG_DEFAULT_RTLIB=compiler-rt         \
      -DCLANG_DEFAULT_UNWINDLIB=libunwind       \
      -Wno-dev -G Ninja ..

ninja

ninja install 

ldconfig

cd "$ROOT_DIR"

python3 -m pip install pyyaml

echo "===== SPIRV-LLVM-Translator ====="

cd "$SRC"

rm -rf SPIRV-LLVM-Translator-20.1.5

wget https://github.com/KhronosGroup/SPIRV-LLVM-Translator/archive/v20.1.5/SPIRV-LLVM-Translator-20.1.5.tar.gz

tar -xf SPIRV-LLVM-Translator-20.1.5.tar.gz

cd SPIRV-LLVM-Translator-20.1.5

mkdir build && cd build

cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release ..

make

make install

cd "$ROOT_DIR"
build_meson mesa "https://mesa.freedesktop.org/archive/mesa-25.1.8.tar.xz" \
    "-Dplatforms=wayland \
     -Dglx=disabled \
     -Dgles1=disabled \
     -Dgles2=enabled \
     -Degl=enabled \
     -Dgbm=enabled \
     -Dgallium-drivers=nouveau,virgl,zink \
     -Dvulkan-drivers=nouveau,swrast \
     -Dllvm=enabled \
     -Dshared-llvm=enabled"


ln -sv /usr/lib/pkgconfig/gl.pc /usr/lib/pkgconfig/opengl.pc || true
# opengl.pc を gl.pc として参照できるようにリンクを貼る
# ln -s /usr/lib/pkgconfig/opengl.pc /usr/lib/pkgconfig/gl.pc

# --- 5. ユーティリティツールのビルド ---

build_meson glu "https://archive.mesa3d.org/glu/glu-9.0.3.tar.xz" ""


echo "=================================================="
echo "Mesa (VirtIO-GPU) and Utils Build Complete."
echo "Check acceleration with: eglinfo | grep renderer"
echo "=================================================="
