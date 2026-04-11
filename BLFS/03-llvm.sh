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

    echo "===== Starting LLVM LFS-Style Build ($LLVM_VER) ====="
    cd "$SRC"

    # 1. 必要なファイルをすべてダウンロード
    for pkg in llvm cmake third-party clang lld libunwind; do
         TAR="$pkg-$LLVM_VER.src.tar.xz"
        [ -f "$TAR" ] || wget -c "$BASE_URL/$TAR" --no-check-certificate
    done

# 2. 既存のディレクトリを完全にクリーンアップ (残骸による誤作動防止)
echo "Cleaning up old source trees..."
rm -rf llvm clang lld cmake third-party libunwind

# 3. すべてのコンポーネントを $SRC 直下に展開
echo "Extracting components..."
tar -xf "llvm-$LLVM_VER.src.tar.xz"
tar -xf "clang-$LLVM_VER.src.tar.xz"
tar -xf "lld-$LLVM_VER.src.tar.xz"
tar -xf "cmake-$LLVM_VER.src.tar.xz"
tar -xf "third-party-$LLVM_VER.src.tar.xz"
tar -xf "libunwind-$LLVM_VER.src.tar.xz"

# 4. ディレクトリ名を「バージョン無し」に統一して兄弟関係を作る
# これにより CMake の自動探索 (../cmake 等) が物理的に成立します
mv -v "llvm-$LLVM_VER.src"        "llvm"
mv -v "clang-$LLVM_VER.src"       "clang"
mv -v "lld-$LLVM_VER.src"         "lld"
mv -v "cmake-$LLVM_VER.src"       "cmake"
mv -v "third-party-$LLVM_VER.src" "third-party"
mv -v "libunwind-$LLVM_VER.src"   "libunwind"

# --- 追加修正: LLDのMach-Oビルドエラー回避 ---
echo "Injecting Mach-O headers into LLVM tree for LLD..."
mkdir -pv "$SRC/llvm/include/mach-o"
cp -v "$SRC/libunwind/include/mach-o/compact_unwind_encoding.h" "$SRC/llvm/include/mach-o/"

# 5. LLVM ディレクトリに入ってパッチ作業
cd llvm

echo "Applying GCC14 compatibility patches (<cstdint> injection)..."
# LLVM本体へのインジェクション
sed -i '29i #include <cstdint>' include/llvm/ADT/SmallVector.h
sed -i '17i #include <cstdint>' include/llvm/Support/Signals.h
# ターゲット記述ヘッダへの一括注入
find lib/Target -name "*MCTargetDesc.h" -exec sed -i '1i #include <cstdint>' {} \;

# Pythonシバンの修正 (検索範囲を限定して高速化)
echo "Fixing python shebangs..."
find utils -name "*.py" -exec sed -i '1s/python$/python3/' {} +

# 6. ビルドディレクトリの作成と移動
rm -rf build && mkdir -v build && cd build

# 7. CMake 実行
# LLVM_ENABLE_PROJECTS に clang と lld を入れるだけで、
# 隣にある ../clang や ../cmake を自動的に認識します。
echo "Configuring with CMake..."
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
      -D LLVM_TARGETS_TO_BUILD="X86;AMDGPU"  \
      -D LLVM_BINUTILS_INCDIR=/usr/include   \
      -D LLVM_INCLUDE_BENCHMARKS=OFF         \
      -D CLANG_DEFAULT_PIE_ON_LINUX=ON       \
      -W no-dev -G Ninja .. > "$LOG/llvm.log" 2>&1

# 8. ビルドとインストール
echo "Configuration done. Starting Ninja build (Check $LOG/llvm.log)..."
ninja >> "$LOG/llvm.log" 2>&1
ninja install >> "$LOG/llvm.log" 2>&1

# 9. インストール後の後処理 (Clangのディレクトリ構造修正)
echo "Finalizing Clang structure..."
if [ -d "/usr/lib/clang/$LLVM_VER" ]; then
    ln -sfv 18 /usr/lib/clang/18.1.2
fi
ldconfig

echo "===== LLVM COMPLETE ====="
