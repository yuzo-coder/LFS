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

build_meson "gvfs" \
     "https://download.gnome.org/sources/gvfs/1.56/gvfs-1.56.1.tar.xz" \
     "--prefix=/usr \
     --buildtype=release \
     -Dsmb=false \
     -Dgphoto2=false \
     -Dmtp=false \
     -Dbluray=false \
     -Ddnssd=false \
     -Dgcr=false \
     -Dkeyring=false \
     -Dgoa=false \
     -Dafc=false \
     -Dfuse=false \
     -Donedrive=false \
     -Dnfs=false \
     -Dgoogle=false \
     -Dman=false"

# root権限で実行
ln -sf /usr/lib/gvfs/libgvfscommon.so /usr/lib/gio/modules/
ln -sf /usr/lib/gvfs/libgvfsdaemon.so /usr/lib/gio/modules/

# モジュールキャッシュの更新（必須）
gio-querymodules /usr/lib/gio/modules

echo "===== COMPLETE ====="
