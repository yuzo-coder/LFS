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


# --- 4. 基礎ライブラリ・フォント ---

# Rust Toolchain
if ! command -v cargo &> /dev/null; then
    echo "===== Installing Rust Toolchain ====="
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
fi

# 基礎ライブラリ群
build_cmake "oneTBB" "https://github.com/oneapi-src/oneTBB/archive/refs/tags/v2021.11.0.tar.gz" "-DTBB_TEST=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5"
build_cmake "extra-cmake-modules" "https://github.com/KDE/extra-cmake-modules/archive/refs/tags/v5.115.0.tar.gz" ""
build_meson "libvips" "https://github.com/libvips/libvips.git" ""
build_meson "libsixel" "https://github.com/libsixel/libsixel/archive/refs/tags/v1.10.3.tar.gz" ""

# Chafa (Autotools)
echo "===== Building Chafa ====="
cd "$SRC"
git clone https://github.com/hpjansson/chafa.git || true
cd chafa
./autogen.sh --prefix="$PREFIX"
make && make install
ldconfig

# --- 5. Sway 周辺ツール (Wayland関連) ---

build_meson "gtk-layer-shell" "https://github.com/wmww/gtk-layer-shell.git" "-Dintrospection=false"
build_meson "wl-clipboard" "https://github.com/bugaevc/wl-clipboard.git" ""
build_meson "wlr-randr" "https://github.com/emersion/wlr-randr.git" ""
build_meson "wofi" "https://github.com/SimplyCEO/wofi.git" ""
build_meson "wlogout" "https://github.com/ArtsyMacaw/wlogout.git" ""

# Ueberzug++ (Yaziの画像プレビュー用)
build_cmake "ueberzugpp" "https://github.com/jstkdng/ueberzugpp/archive/refs/tags/v2.9.6.tar.gz" \
    "-DENABLE_X11=OFF -DENABLE_WAYLAND=ON -DENABLE_OPENCV=OFF"

# --- 6. アプリケーション (Rust系 & その他) ---

build_rust_task "yazi" "https://github.com/sxyazi/yazi.git" "yazi"
# ya もコピー
cp "$SRC/yazi/target/release/ya" "$PREFIX/bin/"

# btop (Makefile)
echo "===== Building btop ====="
cd "$SRC"
git clone https://github.com/aristocratos/btop.git || true
cd btop
make && make install
cp bin/btop /usr/bin/

# --- 7. ログイン管理 (greetd / gtkgreet) ---

build_rust_task "greetd" "https://github.com/kennylevinsen/greetd.git" "greetd"
# サービスファイルの配置
cp "$SRC/greetd/greetd.service" /etc/systemd/system/

build_meson "gtkgreet" "https://github.com/kennylevinsen/gtkgreet.git" ""

# --- 8. 設定ファイルのデプロイ ---

echo "===== Deploying Configurations ====="
# ここで前回作成した「一括設定スクリプト」の内容を呼び出すか、
# 以下の設定ファイル作成処理を実行します

# greetd 用のユーザー・ディレクトリ設定
if ! id "greeter" &>/dev/null; then
    useradd -M -G video greeter
    usermod -aG seat,video,input greeter
fi
mkdir -p /etc/greetd

# greetd 設定
cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1
[default_session]
command = "gtkgreet -l -c sway"
user = "greeter"
EOF

# gtkgreet用の専用Sway設定 (ログイン画面用)
cat > /etc/greetd/sway-config <<EOF
input * xkb_layout "jp"
output * bg /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
exec "gtkgreet -l -c sway; swaymsg exit"
include /etc/sway/config.d/*
EOF

ldconfig
echo "===== ALL BUILD & CONFIG COMPLETED ====="
