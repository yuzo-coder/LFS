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



build_autotools "strace" \
    "https://github.com/strace/strace/releases/download/v6.14/strace-6.14.tar.xz" \
    ""



echo "===== COMPLETE ====="
