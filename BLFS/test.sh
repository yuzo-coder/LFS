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


echo "===== Building glslang 16.2.0 ====="

cd "$SRC"
wget https://github.com/KhronosGroup/glslang/archive/16.2.0/glslang-16.2.0.tar.gz
tar -xf glslang-16.2.0.tar.gz
cd glslang-16.2.0

# 2. ビルド用ディレクトリの作成
mkdir build && cd build

# 3. CMake 実行
# CXXFLAGS に -fpermissive を入れているのは、GCC 15対策です
export CXXFLAGS="-O2 -fpermissive"

cmake -D CMAKE_INSTALL_PREFIX=/usr \
      -D CMAKE_BUILD_TYPE=Release   \
      -D ENABLE_OPT=OFF            \
      -G "Unix Makefiles" ..

# 4. コンパイルとインストール
make -j$(nproc)
make install

# 5. 後片付け
ldconfig
cd "$ROOT_DIR"

# ビルドが終わったら後始末（スクリプトの最後に）
echo "===== TEST COMPLETED ====="

