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
# カレントディレクトリまたはスクリプトと同じディレクトリから common.sh を読み込む
if [ -f "./common.sh" ]; then
    source "./common.sh"
elif [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi

# --- 3. PulseAudio 依存関係 & 本体ビルド ---

# 1. libsndfile (音声ファイルの読み書きに必須)
build_cmake "libsndfile" \
    "https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz" \
    "-DBUILD_SHARED_LIBS=ON -DENABLE_EXTERNAL_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5"

# 2. check (PulseAudioのビルドに推奨されるユニットテストフレームワーク)
build_cmake "check" \
    "https://github.com/libcheck/check/releases/download/0.15.2/check-0.15.2.tar.gz" \
    ""

# 3. PulseAudio 本体
# ALSA (Linux標準の音響層) との連携を有効にし、
# システム管理用(systemd等)の不要な依存はオフにします。
build_meson "pulseaudio" \
    "https://freedesktop.org/software/pulseaudio/releases/pulseaudio-17.0.tar.xz" \
    "-Ddatabase=gdbm \
     -Dbluez5=disabled \
     -Dgtk=disabled \
     -Dsystemd=disabled \
     -Dvalgrind=disabled \
     -Dman=false \
     -Dtests=false"

# --- 4. 権限と設定の調整 ---

echo "Configuring Audio Groups..."
# 音声デバイスにアクセスするためのグループ設定
groupadd -f pulse
groupadd -f pulse-access
groupadd -f audio
usermod -aG audio,pulse,pulse-access $TARGET_USER

# --- Network用 (libnl) ---
build_autotools "libnl" \
    "https://github.com/thom311/libnl/releases/download/libnl3_9_0/libnl-3.9.0.tar.gz" \
    "--sysconfdir=/etc --disable-static"

# --- 3. ALSA Library のビルド ---
# 全てのオーディオ関連の基礎となるライブラリ
ALSA_LIB_URL="https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.11.tar.bz2"
build_autotools "alsa-lib" "$ALSA_LIB_URL" ""

# --- 4. ALSA Utils のビルド ---
# amixer, alsamixer 等のコマンドラインツール
# LFS環境でビルドエラーを防ぐため、一部の依存（xmlto, rst2man等）を無効化
ALSA_UTILS_URL="https://www.alsa-project.org/files/pub/utils/alsa-utils-1.2.11.tar.bz2"
ALSA_UTILS_OPTS="--disable-alsaconf --disable-bat --disable-xmlto --with-curses=ncursesw"
build_autotools "alsa-utils" "$ALSA_UTILS_URL" "$ALSA_UTILS_OPTS"

# 再ビルドの実行
build_meson "pipewire" \
    "https://github.com/PipeWire/pipewire/archive/refs/tags/1.0.7.tar.gz" \
    "-Dsession-managers=[] -Dalsa=enabled -Draop=disabled -Dbluez5=disabled -Dgstreamer=disabled -Dsystemd=disabled"

# --- 3. Lua 5.4.8 のビルド ---
# Lua は configure がないため、直接 make を叩きます
echo "===== Building Lua 5.4.8 ====="
LUA_URL="https://www.lua.org/ftp/lua-5.4.8.tar.gz"
LUA_DIR=$(download_extract "$LUA_URL")
cd "$LUA_DIR"
# linux ターゲットを指定することで、readline などの適切なフラグが立ちます
make linux MYCFLAGS="-fPIC" > "$LOG/lua.log" 2>&1
# INSTALL_TOP でインストール先を指定します
make install INSTALL_TOP="$PREFIX" >> "$LOG/lua.log" 2>&1
# WirePlumber (Meson) が lua.pc を探すため、pkg-config 用のファイルを作成します
echo "Creating lua.pc for pkg-config..."
mkdir -p "$PREFIX/lib/pkgconfig"
cat << EOF > "$PREFIX/lib/pkgconfig/lua.pc"
V=5.4
R=5.4.8
prefix=/usr
exec_prefix=/usr
libdir=/usr/lib
includedir=/usr/include
Name: Lua
Description: An Extensible Extension Language
Version: 5.4.8
Requires:
Libs: -L/usr/lib -llua -lm -ldl
Cflags: -I/usr/include
EOF
ldconfig
cd "$ROOT_DIR"

# --- 5. WirePlumber のビルド ---
# PipeWire のセッションマネージャー
# Meson を使用してビルドします
WIREPLUMBER_URL="https://gitlab.freedesktop.org/pipewire/wireplumber/-/archive/0.4.17/wireplumber-0.4.17.tar.gz"
# ドキュメント作成(Pandoc/Doxygen)を無効にし、システムLuaを使用するように設定
WIREPLUMBER_OPTS="-Ddoc=disabled -Dsystem-lua=true -Dintrospection=disabled"
build_meson "wireplumber" "$WIREPLUMBER_URL" "$WIREPLUMBER_OPTS"

echo "===== ALSA & WirePlumber installation completed! ====="
echo "Next steps:"
echo "1. Run 'amixer sset Master unmute' to enable sound."
echo "2. Add 'exec wireplumber' to your sway config."
