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
./configure --prefix=$PREFIX > "$LOG/anthy_config.log" 2>&1
echo "Compiling and Installing Anthy..."
make >> "$LOG/anthy_build.log" 2>&1
make install >> "$LOG/anthy_build.log" 2>&1

# 共有ライブラリのキャッシュ更新
ldconfig

# --- 4. fcitx5-anthy (Plugin) のビルド ---
echo "===== Building fcitx5-anthy (Plugin) ====="
DIR=$(download_extract "https://github.com/fcitx/fcitx5-anthy/archive/refs/tags/5.1.0.tar.gz")
# 展開ディレクトリ名は fcitx5-anthy-5.1.0
cd "$SRC/fcitx5-anthy-5.1.0"
echo "Configuring fcitx5-anthy with CMake..."
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=/usr/lib \
      -DCMAKE_BUILD_TYPE=Release \
      .. > "$LOG/fcitx5-anthy_config.log" 2>&1

echo "Compiling and Installing fcitx5-anthy..."
make >> "$LOG/fcitx5-anthy_build.log" 2>&1
make install >> "$LOG/fcitx5-anthy_build.log" 2>&1

# 最終的なライブラリ認識
ldconfig

# 設定ディレクトリの作成
mkdir -p /home/user/.config/fcitx5

# プロファイル設定の書き込み
cat << 'EOF' > /home/user/.config/fcitx5/profile
[Groups/0]
# グループ名
Name=Default
# デフォルトの入力方法
Default Layout=jp
DefaultIM=anthy
[Groups/0/Items/0]
Name=keyboard-jp
Layout=
[Groups/0/Items/1]
Name=anthy
Layout=
EOF


# プロファイル設定の書き込み
cat << 'EOF' > /home/user/.bash_profile
export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
EOF

echo "===== All tasks completed successfully! ====="
echo "Please restart fcitx5 and add 'Anthy' from your config tool."
