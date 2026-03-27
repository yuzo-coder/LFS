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

# --- 2. FreeType (1回目: HarfBuzzなしでビルド) ---
# --without-harfbuzz を明示的に指定して、中途半端なリンクを防ぎます
build_autotools freetype "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.xz" \
    "--disable-static --without-harfbuzz"

# --- 3. HarfBuzz (文字配置エンジン) ---
# 先に入れた Freetype を使って HarfBuzz をビルドします
build_meson harfbuzz "https://github.com/harfbuzz/harfbuzz/releases/download/8.3.1/harfbuzz-8.3.1.tar.xz" \
    "-Dbenchmark=disabled"

# --- 4. FreeType (2回目: HarfBuzzを有効にして再ビルド) ---
# 今度は HarfBuzz がシステムにあるので、自動的に認識して高品質な描画が可能になります
build_autotools freetype "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.xz" \
    "--disable-static"

# Fontconfig (fc-cache コマンドを含む)
build_autotools fontconfig "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz" \
    "--sysconfdir=/etc --localstatedir=/var --disable-docs"

# --- 4. フォントの配置 ---
echo "===== Installing Fonts ====="
mkdir -p /usr/share/fonts/truetype/{dejavu,noto,font-awesome,JetBrainsMono}
mkdir -p /usr/share/fonts/opentype/{ipaexfont-gothic,ipaexfont-mincho}

cp $ROOT_DIR/fonts/noto/* /usr/share/fonts/truetype/noto/ 2>/dev/null || true
cp $ROOT_DIR/fonts/dejavu/* /usr/share/fonts/truetype/dejavu/ 2>/dev/null || true
cp $ROOT_DIR/fonts/font-awesome/*.ttf /usr/share/fonts/truetype/font-awesome/ 2>/dev/null || true
cp $ROOT_DIR/fonts/JetBrainsMono/*.ttf /usr/share/fonts/truetype/JetBrainsMono/ 2>/dev/null || true

chmod 644 /usr/share/fonts/truetype/noto/*
chmod 644 /usr/share/fonts/truetype/dejavu/*
chmod 644 /usr/share/fonts/truetype/font-awesome/*
chmod 644 /usr/share/fonts/truetype/JetBrainsMono/*

# 1. ダウンロード
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.tar.xz
# 2. 解凍用のディレクトリ作成（既存の jetbrains-mono と分ける）
mkdir -p /usr/share/fonts/truetype/jetbrains-mono-nerd
# 3. 解凍（-C でディレクトリを指定）
tar xf JetBrainsMono.tar.xz -C /usr/share/fonts/truetype/jetbrains-mono-nerd
# 4. 権限設定とキャッシュ更新
chmod 644 /usr/share/fonts/truetype/jetbrains-mono-nerd/*.ttf

wget https://github.com/googlefonts/noto-cjk/raw/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf
mkdir -p /usr/share/fonts/truetype/noto-cjk
cp NotoSansCJKjp-Regular.otf /usr/share/fonts/truetype/noto-cjk/
chmod 644 /usr/share/fonts/truetype/noto-cjk/*

sudo fc-cache -fv



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
