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
if [ -f "./common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi


# --- 3. フォントスタックのビルド ---

#  libpng
echo "===== Building libpng ====="

cd "$SRC"

rm -rf libpng-1.6.45

wget https://downloads.sourceforge.net/libpng/libpng-1.6.45.tar.xz

tar -xf libpng-1.6.45.tar.xz

cd libpng-1.6.45

# APNGパッチのダウンロード（バージョンが近いものを使用）
wget https://downloads.sourceforge.net/project/libpng-apng/libpng16/1.6.45/libpng-1.6.45-apng.patch.gz

# パッチの解凍と適用
gunzip libpng-1.6.45-apng.patch.gz

patch -p1 < libpng-1.6.45-apng.patch

./configure --prefix=/usr --disable-static

make

make install

ldconfig

cd "$ROOT_DIR"

# --- 2. FreeType (1回目: HarfBuzzなしでビルド) ---
build_autotools freetype "https://downloads.sourceforge.net/freetype/freetype-2.13.2.tar.xz" \
    "--disable-static --without-harfbuzz"

echo "===== Building gobject-introspection  ====="

cd "$SRC"
    
rm -rf gobject-introspection-1.84.0

wget https://download.gnome.org/sources/gobject-introspection/1.84/gobject-introspection-1.84.0.tar.xz

tar -xf gobject-introspection-1.84.0.tar.xz
    
cd gobject-introspection-1.84.0

# MSVCCompiler �~B~R�~C~@�~C~_�~C��~A��~B��~C��~B��~A��~Z義�~A~W�~@~ANameError �~B~R�~[~^�~A��~A~Y�~B~K
sed -i 's/from distutils.msvccompiler import MSVCCompiler/class MSVCCompiler: pass/' giscanner/ccompiler.py
    
export SETUPTOOLS_USE_DISTUTILS=local
meson setup build --prefix=/usr --libdir=/usr/lib --buildtype=release \
    -Dbuild_introspection_data=true \
    -Dgtk_doc=false \
    -Ddoctool=disabled \
    -Dbuild_introspection_data=true \
    -Dpython=python3 > $LOG/gobject.log 2>&1

ninja -C build -j"$JOBS" >> "$LOG/gobject.log" 2>&1

ninja -C build install >> "$LOG/gobject.log" 2>&1

mkdir -pv /usr/share/gir-1.0

mkdir -pv /usr/lib/girepository-1.0

cd build

cp -v gir/*.gir /usr/share/gir-1.0/

cp -v gir/*.typelib /usr/lib/girepository-1.0/
ldconfig 

cd "$ROOT_DIR"



# --- 3. HarfBuzz (文字配置エンジン) ---
# 先に入れた Freetype を使って HarfBuzz をビルドします
build_meson harfbuzz "https://github.com/harfbuzz/harfbuzz/releases/download/8.3.1/harfbuzz-8.3.1.tar.xz" \
    "-Dbenchmark=disabled -Dintrospection=enabled"

# --- 4. FreeType (2回目: HarfBuzzを有効にして再ビルド) ---
# 今度は HarfBuzz がシステムにあるので、自動的に認識して高品質な描画が可能になります
build_autotools freetype "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.xz" \
    "--disable-static"

# Fontconfig (fc-cache コマンドを含む)
build_autotools fontconfig "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz" \
    "--sysconfdir=/etc --localstatedir=/var --disable-docs"

# --- 4. フォントの配置 ---
echo "===== Installing Fonts ====="
mkdir -p /usr/share/fonts/truetype/{dejavu,font-awesome}

cp $ROOT_DIR/fonts/dejavu/* /usr/share/fonts/truetype/dejavu/ 2>/dev/null || true
cp $ROOT_DIR/fonts/font-awesome/*.ttf /usr/share/fonts/truetype/font-awesome/ 2>/dev/null || true

chmod 644 /usr/share/fonts/truetype/dejavu/*
chmod 644 /usr/share/fonts/truetype/font-awesome/*

echo "===== JetBrainsMono ====="
FONT_DIR="/usr/local/share/fonts/jetbrains"
mkdir -p $FONT_DIR
# GitHubから最新のリリースをダウンロード（v3.1.1をターゲット）
cd $SRC
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip

if [ $? -eq 0 ]; then
    unzip JetBrainsMono.zip -d $FONT_DIR
    fc-cache -fv
    echo "Font installed and cache updated."
else
    echo "Failed to download fonts."
    exit 1
fi
cd $ROOT_DIR

echo "===== noto ====="
mkdir -p /usr/share/fonts/noto
cd "$SRC"
wget https://github.com/googlefonts/noto-cjk/raw/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf
mv NotoSansCJKjp-Regular.otf /usr/share/fonts/noto/
cd $ROOT_DIR

fc-cache -fv

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
