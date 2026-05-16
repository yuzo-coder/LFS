#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   24   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "


build_autotools libexif "https://github.com/libexif/libexif/releases/download/v0.6.24/libexif-0.6.24.tar.bz2" ""


build_autotools imlib2 "https://download.sourceforge.net/enlightenment/imlib2-1.12.3.tar.gz" ""


cd "$SRC"

wget https://deb.debian.org/debian/pool/main/n/nsxiv/nsxiv_33.orig.tar.gz

rm -rf nsxiv-33

tar -xf nsxiv_33.orig.tar.gz

cd nsxiv-33

# config.mk の調整（オプション）
# LFSの標準パスに合わせて PREFIX を /usr に設定してビルドします
make CC=gcc PREFIX=/usr

# インストール
make CC=gcc PREFIX=/usr install

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   24   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "

