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

# --- 2. 共通ユーティリティ関数 ---

download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    echo "Downloading $TAR..." >&2
    cd "$SRC"
    [ -f "$TAR" ] || wget -c "$URL" --no-check-certificate >&2
    
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    [ -z "$DIR" ] && DIR=$(basename "$TAR" .tar.xz)
    
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$SRC/$DIR"
}

build_meson() {
    local NAME=$1; local URL_OR_GIT=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    local DIR=""
    if [[ "$URL_OR_GIT" == *.git ]]; then
        cd "$SRC"
        rm -rf "$NAME"
        git clone "$URL_OR_GIT" "$NAME"
        DIR="$SRC/$NAME"
    else
        DIR=$(download_extract "$URL_OR_GIT")
    fi
    cd "$DIR"
    rm -rf build
    # --libdir=/usr/lib を明示
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

# --- 3. 依存ライブラリのビルド ---

# libdrm: MesaがGPUと対話するために必須
build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" \
    "-Dudev=true -Dvalgrind=disabled"

# --- LLVM ビルド設定 ---
# バージョン定義 (LFSの記述に合わせて 20.1.8 を例にしますが、18.1.2等でも同様です)
LLVM_VER="18.1.2" # お使いのバージョンに合わせて変更してください
BASE_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VER"

build_llvm_lfs_style() {
    echo "===== Starting LLVM LFS-Style Build ($LLVM_VER) ====="
    cd "$SRC"

    # 1. 必要なファイルをすべてダウンロード
    for pkg in llvm cmake third-party clang; do
        local TAR="$pkg-$LLVM_VER.src.tar.xz"
        [ -f "$TAR" ] || wget -c "$BASE_URL/$TAR" --no-check-certificate
    done

    # 2. 展開と構造の整理
    rm -rf "llvm-$LLVM_VER.src"
    tar -xf "llvm-$LLVM_VER.src.tar.xz"
    cd "llvm-$LLVM_VER.src"

    # 追加パーツを同じ階層に展開
    tar -xf "../cmake-$LLVM_VER.src.tar.xz"
    tar -xf "../third-party-$LLVM_VER.src.tar.xz"
    
    # Clangをtools配下に入れる
    mkdir -pv tools
    tar -xf "../clang-$LLVM_VER.src.tar.xz" -C tools
    mv "tools/clang-$LLVM_VER.src" "tools/clang"

    # 3. LFS流パッチ (パスの修正)
    echo "Applying LFS patches..."
    sed "/LLVM_COMMON_CMAKE_UTILS/s@../cmake@cmake-$LLVM_VER.src@" -i CMakeLists.txt
    sed "/LLVM_THIRD_PARTY_DIR/s@../third-party@third-party-$LLVM_VER.src@" -i cmake/modules/HandleLLVMOptions.cmake
    # 2. 問題の SmallVector.h に <cstdint> を追加するパッチ（sed）
    sed -i '29i #include <cstdint>' include/llvm/ADT/SmallVector.h

    # 3. ついでに、今後他のファイルでも同じエラーが出るのを防ぐため
    # 一般的にこの問題が起きやすい別の重要ファイルにも入れておきます
    sed -i '17i #include <cstdint>' include/llvm/Support/Signals.h
   
    # スクリプトのパッチ部分に追加
    echo "Injecting <cstdint> into all target descriptions..."
    find lib/Target -name "*MCTargetDesc.h" -exec sed -i '1i #include <cstdint>' {} \;
    
    # Pythonスクリプトのシバンを修正
    grep -rl '#!.*python' | xargs sed -i '1s/python$/python3/' || true
    
    # 4. ビルド (LFS指定のオプション)
    rm -rf build && mkdir -v build && cd build

    cmake -D CMAKE_INSTALL_PREFIX=/usr           \
          -D CMAKE_SKIP_INSTALL_RPATH=ON         \
          -D LLVM_ENABLE_FFI=ON                  \
          -D CMAKE_BUILD_TYPE=Release            \
          -D LLVM_BUILD_LLVM_DYLIB=ON            \
          -D LLVM_LINK_LLVM_DYLIB=ON             \
          -D LLVM_ENABLE_RTTI=ON                 \
          -D LLVM_TARGETS_TO_BUILD="host;AMDGPU" \
          -D LLVM_BINUTILS_INCDIR=/usr/include   \
          -D LLVM_INCLUDE_BENCHMARKS=OFF         \
          -D CLANG_DEFAULT_PIE_ON_LINUX=ON       \
          -W no-dev -G Ninja .. > "$LOG/llvm.log" 2>&1

    echo "Configuration done. Starting Ninja build..."
    ninja >> "$LOG/llvm.log" 2>&1
    ninja install >> "$LOG/llvm.log" 2>&1
    
    ldconfig
    cd "$ROOT_DIR"
}

build_llvm_lfs_style


# --- 4. Mesa本体のビルド (VirtIO 3D加速対応) ---
# QEMU環境で爆速にするための重要フラグ:
# - gallium-drivers=virtio,swrast (仮想ドライバとソフトウェアバックアップ)
# - vulkan-drivers=swrast (Vulkanはひとまずソフトのみ)
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
           -Dshared-llvm=enabled"

build_meson mesa "https://archive.mesa3d.org/mesa-24.0.3.tar.xz" "$MESA_OPTS"

ln -sv /usr/lib/pkgconfig/gl.pc /usr/lib/pkgconfig/opengl.pc || true

# --- 5. ユーティリティツールのビルド ---

build_meson glu "https://archive.mesa3d.org/glu/glu-9.0.3.tar.xz" ""

# 1. mesa-demos (eglinfo, es2gears_wayland 等)
build_meson mesa-demos "https://archive.mesa3d.org/demos/mesa-demos-9.0.0.tar.xz" \
    "-Dwayland=enabled -Dx11=disabled -Dgles2=enabled"

# 2. wayland-utils (wayland-info)
build_meson wayland-utils "https://gitlab.freedesktop.org/wayland/wayland-utils/-/archive/1.2.0/wayland-utils-1.2.0.tar.gz" ""

echo "=================================================="
echo "Mesa (VirtIO-GPU) and Utils Build Complete."
echo "Check acceleration with: eglinfo | grep renderer"
echo "=================================================="
