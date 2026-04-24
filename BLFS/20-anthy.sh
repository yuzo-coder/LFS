#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
TARGET_USER="user" # 一般ユーザー名

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# --- 3. Anthy 本体 (Engine) のビルド ---
echo "===== Building Anthy (Engine) ====="
DIR=$(download_extract "https://ftp.jaist.ac.jp/pub/osdn.net/anthy/37536/anthy-9100h.tar.gz")
# 展開ディレクトリ名は anthy-9100h
cd "$SRC/anthy-9100h"
echo "Configuring Anthy..."
./configure --prefix=$PREFIX > "$LOG/anthy.log" 2>&1
echo "Compiling and Installing Anthy..."
make >> "$LOG/anthy.log" 2>&1
make install >> "$LOG/anthy.log" 2>&1

# 共有ライブラリのキャッシュ更新
ldconfig

build_cmake "fcitx5-anthy" \
    "https://github.com/fcitx/fcitx5-anthy/archive/5.1.7/fcitx5-anthy-5.1.7.tar.gz" \
    ""


# 設定ディレクトリの作成
mkdir -p /etc/xdg/fcitx5

# profile などの設定ファイルを配置
cat << 'EOF' > /etc/xdg/fcitx5/profile
[GroupOrder]
0=Default

[Group/0]
Name=Default
DefaultLayout=jp
DefaultIM=anthy
EOF

# プロファイル設定の書き込み
cat << 'EOF' > /home/user/.bash_profile
export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
EOF

echo "===== All tasks completed successfully! ====="
echo "Please restart fcitx5 and add 'Anthy' from your config tool."
