#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
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

echo "===== FIREFOX BINARY ====="

cd "$SRC"

# 128系最新のESRバイナリをダウンロード (日本語版)
wget "https://download.mozilla.org/?product=firefox-128.8.0esr-ssl&os=linux64&lang=ja" -O firefox-128.8.0esr.tar.bz2

# /opt に展開
tar xjf firefox-128.8.0esr.tar.bz2 -C /opt/

# 既存のシンボリックリンクがあれば削除し、新しいバイナリに繋ぎ直す
ln -sf /opt/firefox/firefox /usr/bin/firefox

echo "===== Firefox Complete ====="
