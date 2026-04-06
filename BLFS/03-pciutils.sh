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

# 1. pciutils
echo "===== Building PCIUTILS ====="
cd "$SRC"
wget https://mj.ucw.cz/download/linux/pci/pciutils-3.14.0.tar.gz
tar xf pciutils-3.14.0.tar.gz
cd pciutils-3.14.0

# 2. ビルド設定
# PREFIX=/usr: 標準のシステムパスにインストール
# SHARED=yes: Firefoxが必要とする共有ライブラリ（libpci.so）を生成
# LIBDIR=/usr/lib: 64bit環境のライブラリパスを指定
make PREFIX=/usr                \
     SHAREDIR=/usr/share/hwdata \
     SHARED=yes                 \
     LIBDIR=/usr/lib            \
     HOST=x86_64-linux          \
     OPT="-march=native -O2"

# 3. インストール（root権限で実行）
# 共有ライブラリのインストールを確実にするため install-lib も実行
make PREFIX=/usr                \
     SHAREDIR=/usr/share/hwdata \
     SHARED=yes                 \
     LIBDIR=/usr/lib            \
     install install-lib

# 4. 共有ライブラリの認識を更新
ldconfig

# 5. PCI ID データベースの更新（ネットワークが必要）
# これにより最新のGPU名などが正しく表示されます
update-pciids

echo "===== PCIUTILS installation completed! ====="
