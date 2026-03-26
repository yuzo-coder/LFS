#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=${ROOT_DIR:-$(pwd)}
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

mkdir -p "$SRC" "$LOG"
export MAKEFLAGS="-j$JOBS"

# --- 2. 共通ユーティリティ関数 ---

download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    echo "Downloading $TAR..." >&2
    cd "$SRC"
    [ -f "$TAR" ] || wget -c "$URL" --no-check-certificate >&2
    
    # 展開ディレクトリ名の取得
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

# --- 3. フォントスタックのビルド ---
# libpng, freetype, harfbuzz, fontconfig の順でビルド

build_autotools libpng "https://downloads.sourceforge.net/libpng/libpng-1.6.43.tar.xz" ""

# 1回目のFreetype (harfbuzzなし)
build_autotools freetype "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.xz" "--disable-static"

# HarfBuzz (日本語の合字などを正しく処理するために必要)
build_meson harfbuzz "https://github.com/harfbuzz/harfbuzz/releases/download/8.3.1/harfbuzz-8.3.1.tar.xz" "-Dbenchmark=disabled"

# Fontconfig (fc-cache コマンドを含む)
build_autotools fontconfig "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz" \
    "--sysconfdir=/etc --localstatedir=/var --disable-docs"

# --- 4. フォントの配置 ---
echo "===== Installing Fonts ====="
mkdir -p /usr/share/fonts/truetype/{dejavu,noto,font-awesome,jetbrains-mono}
mkdir -p /usr/share/fonts/opentype/{ipaexfont-gothic,ipaexfont-mincho}

cp $ROOT_DIR/fonts/dejavu/* /usr/share/fonts/truetype/dejavu/ 2>/dev/null || true
cp $ROOT_DIR/fonts/noto/*.ttf         /usr/share/fonts/truetype/noto/ 2>/dev/null || true
cp $ROOT_DIR/fonts/font-awesome/*.ttf /usr/share/fonts/truetype/font-awesome/ 2>/dev/null || true
cp $ROOT_DIR/fonts/jetbrains-mono/*.ttf /usr/share/fonts/truetype/jetbrains-mono/ 2>/dev/null || true
cp $ROOT_DIR/fonts/ipaexfont-gothic/* /usr/share/fonts/opentype/ipaexfont-gothic/ 2>/dev/null || true
cp $ROOT_DIR/fonts/ipaexfont-mincho/* /usr/share/fonts/opentype/ipaexfont-mincho/ 2>/dev/null || true

# フォントキャッシュの更新
if command -v fc-cache &> /dev/null; then
    fc-cache -fv
fi

# --- 5. 日本語ロケール生成と環境設定 ---
echo "===== Generating Locales ====="
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8

cat > /etc/profile.d/i18n.sh << "EOF"
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8
EOF

source /etc/profile.d/i18n.sh

# --- 6. vi (vim) 日本語設定 ---
if [ ! -f ~/.vimrc ]; then touch ~/.vimrc; fi
if ! grep -q "encoding=utf-8" ~/.vimrc; then
cat >> ~/.vimrc << "EOF"
" --- 日本語設定 ---
set encoding=utf-8
set fileencodings=utf-8,cp932,euc-jp,sjis
set fileencoding=utf-8
EOF
fi

echo "===== Verification ====="
locale
echo "Font Match Check:"
fc-match monospace
