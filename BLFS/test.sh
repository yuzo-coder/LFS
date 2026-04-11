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


# 2. libunwind 
# グラフィックスの安定性を確保する
build_autotools "libunwind" \
    "https://download.savannah.nongnu.org/releases/libunwind/libunwind-1.6.2.tar.gz" \
    "--disable-static --enable-coredump --host=x86_64-linux"

echo "===== COMPLETE ====="
