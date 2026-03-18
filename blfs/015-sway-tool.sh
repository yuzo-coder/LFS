#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 (既存) ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

mkdir -p "$SRC" "$LOG"
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/lib/pkgconfig
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通ユーティリティ関数 (既存) ---
download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    echo "Downloading $TAR..." >&2
    cd "$SRC"
    [ -f "$TAR" ] || wget -c "$URL" --no-check-certificate >&2
    
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$SRC/$DIR"
}

# --- 10. foot ターミナルスタック ---

# 10-1. tllist (ヘッダーのみの型付きリンク付きリスト)
echo "===== Building tllist ====="
# Gitクローンまたはアーカイブ取得
cd "$SRC"
rm -rf tllist
git clone https://codeberg.org/dnkl/tllist.git
cd tllist
meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release > "$LOG/tllist.log" 2>&1
ninja -C build >> "$LOG/tllist.log" 2>&1
ninja -C build install >> "$LOG/tllist.log" 2>&1
cd "$ROOT_DIR"

# 10-2. fcft (フォント描画ライブラリ)
echo "===== Building fcft ====="
# 注意: check や tllist がインストールされている必要があります
cd "$SRC"
rm -rf fcft
git clone https://codeberg.org/dnkl/fcft.git
cd fcft
# ドキュメント生成を無効化してビルドを軽量化
meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release \
    -Ddocs=disabled > "$LOG/fcft.log" 2>&1
ninja -C build >> "$LOG/fcft.log" 2>&1
ninja -C build install >> "$LOG/fcft.log" 2>&1
cd "$ROOT_DIR"

# 10-3. foot (ターミナル本体)
echo "===== Building foot ====="
cd "$SRC"
rm -rf foot
git clone https://codeberg.org/dnkl/foot.git
cd foot
# Sway環境に合わせ、x11サポート無し、terminfoありでビルド
meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release \
    -Dterminfo=enabled \
    -Ddocs=disabled \
    -Dtests=false > "$LOG/foot.log" 2>&1
ninja -C build >> "$LOG/foot.log" 2>&1
ninja -C build install >> "$LOG/foot.log" 2>&1
cd "$ROOT_DIR"

echo "===== ALL PHASES COMPLETE: foot is ready ====="
echo "Usage: Open Sway and press Mod+Enter (if configured) or run 'foot' from console."
