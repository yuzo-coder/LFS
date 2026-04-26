#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libpng"
    "freetype"
    "gobject-introspection"
    "harfbuzz"
    "freetype"
    "fontconfig"
    "JetBrainsMono"
    "noto"
)

for pkg in "${scripts[@]}"; do
    echo "--- Building $pkg ---"
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

# --- 4. フォントの配置 ---
echo "===== Installing Fonts ====="

mkdir -p /usr/share/fonts/truetype/{dejavu,font-awesome}

cp $ROOT_DIR/fonts/dejavu/* /usr/share/fonts/truetype/dejavu/ 2>/dev/null || true

cp $ROOT_DIR/fonts/font-awesome/*.ttf /usr/share/fonts/truetype/font-awesome/ 2>/dev/null || true

chmod 644 /usr/share/fonts/truetype/dejavu/*

chmod 644 /usr/share/fonts/truetype/font-awesome/*

# フォントキャッシュの更新
fc-cache -fv

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
