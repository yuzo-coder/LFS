#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
font-util
freetype
harfbuzz
fontconfig
fribidi
libpng
libjpeg-turbo
libtiff
libwebp
libyuv
gdk-pixbuf
fonts
JetBrainsMono
noto

iso-codes

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done


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

echo "===== 06 COMPLETE ====="
