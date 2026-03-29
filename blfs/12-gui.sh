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

# --- 2. 共通ユーティリティ関数 ---

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

build_autotools() {
    local NAME=$1; local URL=$2; local CONF_OPTS=$3
    echo "===== Building $NAME (autotools) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    ./configure --prefix="$PREFIX" --libdir=/usr/lib $CONF_OPTS > "$LOG/$NAME.log" 2>&1
    make >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

build_meson() {
    local NAME=$1; local URL_OR_GIT=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    
    local DIR=""
    if [[ "$URL_OR_GIT" == *.git ]]; then
        cd "$SRC"
        rm -rf "$NAME"
        git clone "$URL_OR_GIT" "$NAME"
        DIR="$SRC/$NAME"
    else
        DIR=$(download_extract "$URL_OR_GIT")
    fi

    cd "$DIR"
    rm -rf build
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

# 1. libogg (Vorbis の基礎となるコンテナフォーマット)
build_autotools "libogg" \
    "https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.xz" \
    "--disable-static"

# 2. libvorbis (これが 'vorbisfile' を提供します)
build_autotools "libvorbis" \
    "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz" \
    "--disable-static"


# --- 5. GUI 管理ツール (pavucontrol & nm-connection-editor) ---

# 1. libcanberra (pavucontrol の音量フィードバック音に必要)
# ※ GUI アプリの動作を安定させるために推奨されます
build_autotools "libcanberra" \
    "https://0pointer.de/lennart/projects/libcanberra/libcanberra-0.30.tar.xz" \
    "--disable-oss --disable-lynx --disable-tdb --disable-gtk --disable-gtk3"

# 2. pavucontrol (PulseAudio Volume Control)
# ※ C++ のモダンな実装のため、sigc++ や gtkmm などの C++ ラッパーが必要です。
# BLFS 環境で不足している場合は Meson が自動でチェックします。
build_meson "pavucontrol" \
    "https://freedesktop.org/software/pulseaudio/pavucontrol/pavucontrol-6.0.tar.xz" \
    "-Dlynx=false"


# iso-codes (国名・言語コードの標準データ)
# configure 時に --prefix を指定するだけでOKです

# 1. 翻訳データのリンクが衝突している場所を削除
# (各言語の LC_MESSAGES 内にある iso-codes 関連ファイルを消去)
find /usr/share/locale -name "iso_*.mo" -delete

# 2. XML データのインストール先を削除
rm -rf /usr/share/xml/iso-codes
build_autotools "iso-codes" \
    "https://ftp.debian.org/debian/pool/main/i/iso-codes/iso-codes_4.18.0.orig.tar.xz" \
    ""

# mobile-broadband-provider-info (モバイル回線設定データベース)
build_meson "mobile-broadband-provider-info" \
    "https://download.gnome.org/sources/mobile-broadband-provider-info/20240407/mobile-broadband-provider-info-20240407.tar.xz" \
    ""


# Duktape (Polkitのルール評価用エンジン)
build_cmake "duktape" \
    "https://duktape.org/duktape-2.7.0.tar.xz" \
    ""

# Polkit (権限管理フレームワーク)
# 依存関係を最小限にしてビルドを通します
build_meson "polkit" \
    "https://github.com/polkit-org/polkit/archive/refs/tags/124.tar.gz" \
    "-Dintrospection=false -Dman=false -Dexamples=false -Dgtk_doc=false -Dtests=false"

# 1. libndp (隣接デバイス発見プロトコル - NMに必須)
build_autotools "libndp" \
    "https://libndp.org/files/libndp-1.9.tar.gz" ""


# 2. NetworkManager 本体
# ※ これが "libnm" を提供します。
# Z840 の環境に合わせて、不要な機能（nmtuiの要求するシステム等）は最小限にします。
build_meson "NetworkManager" \
    "https://download.gnome.org/sources/NetworkManager/1.44/NetworkManager-1.44.2.tar.xz" \
    "-Dintrospection=false \
     -Dqt=false \
     -Dlibaudit=no \
     -Dtests=no \
     -Dnmtui=false \
     -Dselinux=false \
     -Dsession_tracking=no \
     -Dsystemd_journal=false \
     -Dppp=false \
     -Dovs=false" 

# 3. libnma (nm-connection-editor のコアライブラリ)
# ネットワーク設定の GUI コンポーネントを提供します。
build_meson "libnma" \
    "https://download.gnome.org/sources/libnma/1.10/libnma-1.10.6.tar.xz" \
    "-Dintrospection=false -Dgtk_doc=false"

# 4. nm-connection-editor (NetworkManager Connection Editor)
# ※ network-manager 本体がビルド済みであることを前提としています。
build_meson "nm-connection-editor" \
    "https://download.gnome.org/sources/nm-connection-editor/1.30/nm-connection-editor-1.30.0.tar.xz" \
    "-Dintrospection=false -Dgtk_doc=false -Dselinux=false"

echo "=================================================="
echo "    GUI Management Tools Build Complete!          "
echo "    You can now launch:                           "
echo "    - pavucontrol (Volume)                        "
echo "    - nm-connection-editor (Network)              "
echo "=================================================="
