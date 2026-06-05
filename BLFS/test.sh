#!/bin/bash
set -euo pipefail

source ./functions.sh


echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                      START                          =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

DIR=$(download_extract "https://github.com/storaged-project/udisks/releases/download/udisks-2.10.1/udisks-2.10.1.tar.bz2")

cd "$DIR"

sed -i 's/blockdev-mdraid >=/disable-mdraid-check >=/g' configure

./configure --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            --disable-static \
            --enable-daemon \
            --disable-man \
            --disable-btrfs \
            --disable-lvm2 \
            --disable-zram \
            --disable-encryption \
            --disable-introspection \
            --disable-vapi \
            --without-bash-completion \
            --with-systemdsystemunitdir=/lib/systemd/system

make

make install

ldconfig


echo "===== COMPLETE ====="
