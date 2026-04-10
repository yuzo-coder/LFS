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

# libdrm: MesaがGPUと対話するために必須
build_meson libdrm "https://dri.freedesktop.org/libdrm/libdrm-2.4.120.tar.xz" \
    "-Dudev=true -Dvalgrind=disabled"


# --- LLVM ビルド設定 ---
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
          -D LLVM_ENABLE_PROJECTS="clang;lld"    \
          -D LLVM_BUILD_LLVM_DYLIB=ON            \
          -D LLVM_LINK_LLVM_DYLIB=ON             \
          -D LLVM_ENABLE_RTTI=ON                 \
          -D LLVM_DEFAULT_TARGET_TRIPLE="x86_64-unknown-linux-gnu" \
          -D LLVM_HOST_TRIPLE="x86_64-unknown-linux-gnu" \
          -D LLVM_TARGETS_TO_BUILD="X86;AMDGPU" \
          -D LLVM_BINUTILS_INCDIR=/usr/include   \
          -D LLVM_INCLUDE_BENCHMARKS=OFF         \
          -D CLANG_DEFAULT_PIE_ON_LINUX=ON       \
          -W no-dev -G Ninja .. > "$LOG/llvm.log" 2>&1

    echo "Configuration done. Starting Ninja build..."
    ninja >> "$LOG/llvm.log" 2>&1
    ninja install >> "$LOG/llvm.log" 2>&1

    # --- ここから追加 ---
    echo "Fixing Clang directory structure..."
    # 18.x.x 系の実体ディレクトリを 18 に統一し、相互にリンクを貼る
    if [ -d "/usr/lib/clang/$LLVM_VER" ] && [ ! -L "/usr/lib/clang/$LLVM_VER" ]; then
        # もし 18.1.2 がディレクトリなら 18 にリネームしてリンクにする
        mv -v /usr/lib/clang/$LLVM_VER /usr/lib/clang/18_tmp
        rm -rf /usr/lib/clang/18
        mv -v /usr/lib/clang/18_tmp /usr/lib/clang/18
    fi

    # 18.1.2 と 18 を相互に認識できるようにする
    ln -sfv 18 /usr/lib/clang/18.1.2
    ln -sf /usr/lib/libclang.so.18.1.2 /usr/lib/libclang.so    
    ldconfig
    # clang -march=native -dM -E - < /dev/null | grep -E "SSE4_1|AVX"
    cd "$ROOT_DIR"
}

build_llvm_lfs_style
echo "===== LLVM COMPLETE ====="

