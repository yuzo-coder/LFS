#!/bin/bash
set -euo pipefail

# --- 1. �~R��~C設�~Z ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
TARGET_USER="user" # �~@�~H��~C��~C��~B��~C��~P~M

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通関数のインクルード ---
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# Rust Toolchain
if ! command -v cargo &> /dev/null; then
    echo "===== Installing Rust Toolchain ====="
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env

    # /usr/local/bin などにリンクを貼っておくと、後のビルドで「見つからない」ミスが減ります
    # ln -sf $HOME/.cargo/bin/cargo /usr/local/bin/cargo
    # ln -sf $HOME/.cargo/bin/rustc /usr/local/bin/rustc
fi

# cargo-c (Rust ライブラリを C 用にビルドするためのツール)
# https://github.com/lu-zero/cargo-c/archive/v0.10.15/cargo-c-0.10.15.tar.gz
echo "===== Building cargo-c (Rust/Cargo) ====="
DIR=$(download_extract "https://github.com/lu-zero/cargo-c/archive/v0.10.15/cargo-c-0.10.15.tar.gz")
cd "$DIR"
# --release で最適化、--locked で依存関係を固定
# 複数のバイナリ (cargo-cbuild, cargo-cinstall 等) が生成されます
cargo build --release > "$LOG/cargo-c.log" 2>&1
# 生成されたバイナリを /usr/bin へ配置
cp target/release/cargo-c* "$PREFIX/bin/"

export PATH=/root/.cargo/bin:$PATH:/usr/local/bin

ldconfig

cd "$ROOT_DIR"

build_meson cairo "https://www.cairographics.org/releases/cairo-1.18.2.tar.xz" "-Dfontconfig=enabled -Dfreetype=enabled -Dxcb=enabled -Dxlib=enabled -Dtests=disabled"

# --- 5. Font & Drawing Stack ---
build_meson pixman "https://www.cairographics.org/releases/pixman-0.43.4.tar.gz" ""

build_meson fribidi "https://github.com/fribidi/fribidi/releases/download/v1.0.15/fribidi-1.0.15.tar.xz" ""


# build_meson pango "https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz" "-Dintrospection=enabled"

# 環境変数 CXXFLAGS に C++17 をセットして構成
export CXXFLAGS="-O3 -std=c++17"
build_meson pango "https://download.gnome.org/sources/pango/1.56/pango-1.56.4.tar.xz" "-Dintrospection=enabled"


# 4. librsvg (最重要：SVG アイコンの描画エンジン)
# gdk-pixbuf の情報を pkg-config で強制的に認識させる
export PKG_CONFIG_PATH="/usr/lib/pkgconfig:$PKG_CONFIG_PATH"
build_meson "librsvg" \
    "https://download.gnome.org/sources/librsvg/2.62/librsvg-2.62.1.tar.xz" \
    "-Dintrospection=enabled -Ddocs=disabled -Dvala=disabled -Dpixbuf=enabled \
     -Dpixbuf-loader=enabled"

# 5. ローダーキャッシュの更新 (librsvg が入った後に行う)
echo "Updating gdk-pixbuf loaders cache..."
/usr/bin/gdk-pixbuf-query-loaders --update-cache

echo "===== 09 RUST COMPLETE ====="

