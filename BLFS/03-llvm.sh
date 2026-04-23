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
LLVM_VER="20.1.8"
BASE_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VER"
SRC="/LFS/BLFS"  # yuzoさんの環境に合わせて適宜調整してください
LOG="/var/log"

echo "===== Starting LLVM LFS-Style Build ($LLVM_VER) ====="
cd "$SRC"

# 1. 必要なファイルをすべてダウンロード
# 20.x系ではコンポーネントが細分化されているため、漏れなく取得します
for pkg in llvm cmake third-party clang lld libunwind; do
    TAR="$pkg-$LLVM_VER.src.tar.xz"
    [ -f "$TAR" ] || wget -c "$BASE_URL/$TAR" --no-check-certificate
done

# 2. 既存のディレクトリを完全にクリーンアップ
echo "Cleaning up old source trees..."
rm -rf llvm clang lld cmake third-party libunwind

# 3. すべてのコンポーネントを展開
echo "Extracting components..."
for pkg in llvm cmake third-party clang lld libunwind; do
    tar -xf "$pkg-$LLVM_VER.src.tar.xz"
    # ディレクトリ名を「バージョン無し」に統一して兄弟関係を作る
    mv -v "$pkg-$LLVM_VER.src" "$pkg"
done

# --- 修正: LLDのビルドエラー回避 (compact_unwind_encoding.h) ---
echo "Injecting Mach-O headers..."
mkdir -pv "$SRC/llvm/include/mach-o"
cp -v "$SRC/libunwind/include/mach-o/compact_unwind_encoding.h" "$SRC/llvm/include/mach-o/"

# 5. LLVM ディレクトリに入ってパッチ作業
cd llvm

echo "Applying GCC14/15 compatibility patches..."
# 最新のLLVMでも必要なケースが多い <cstdint> の追加
sed -i '29i #include <cstdint>' include/llvm/ADT/SmallVector.h
sed -i '17i #include <cstdint>' include/llvm/Support/Signals.h
find lib/Target -name "*MCTargetDesc.h" -exec sed -i '1i #include <cstdint>' {} \;

# Pythonシバンの修正
echo "Fixing python shebangs..."
find utils -name "*.py" -exec sed -i '1s/python$/python3/' {} +

# 6. ビルドディレクトリの作成
rm -rf build && mkdir -v build && cd build

# 7. CMake 実行
echo "Configuring with CMake (LLVM 20.1.8)..."
cmake -D CMAKE_INSTALL_PREFIX=/usr               \
      -D CMAKE_SKIP_INSTALL_RPATH=ON             \
      -D LLVM_ENABLE_FFI=ON                      \
      -D CMAKE_BUILD_TYPE=Release                \
      -D LLVM_ENABLE_PROJECTS="clang;lld"        \
      -D LLVM_BUILD_LLVM_DYLIB=ON                \
      -D LLVM_LINK_LLVM_DYLIB=ON                 \
      -D LLVM_ENABLE_RTTI=ON                     \
      -D LLVM_DEFAULT_TARGET_TRIPLE="x86_64-unknown-linux-gnu" \
      -D LLVM_HOST_TRIPLE="x86_64-unknown-linux-gnu" \
      -D LLVM_TARGETS_TO_BUILD="X86;AMDGPU"      \
      -D LLVM_BINUTILS_INCDIR=/usr/include       \
      -D LLVM_INCLUDE_BENCHMARKS=OFF             \
      -D CLANG_DEFAULT_PIE_ON_LINUX=ON           \
      -D LLVM_ENABLE_SPHINX=OFF                  \
      -W no-dev -G Ninja .. > "$LOG/llvm.log" 2>&1

# 8. ビルドとインストール (36コアフル活用)
echo "Configuration done. Starting Ninja build (j$(nproc))..."
ninja >> "$LOG/llvm.log" 2>&1
ninja install >> "$LOG/llvm.log" 2>&1

# 9. インストール後の後処理
echo "Finalizing Clang structure..."
# バージョン番号に基づいたディレクトリへのリンクを作成
CLANG_MAJOR=$(echo $LLVM_VER | cut -d. -f1)
if [ -d "/usr/lib/clang/$LLVM_VER" ]; then
    ln -sfv "$LLVM_VER" "/usr/lib/clang/$CLANG_MAJOR"
fi

# 共有ライブラリの反映と物理書き込み
ldconfig
sync

echo "LLVM $LLVM_VER build completed successfully."
clang --version



echo "===== LLVM COMPLETE ====="
