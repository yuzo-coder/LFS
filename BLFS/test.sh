#!/bin/bash
set -euo pipefail

source ./functions.sh



DIR=$(download_extract "https://downloads.sourceforge.net/pcmanfm/pcmanfm-1.3.2.tar.xz")

cd "$DIR"

CFLAGS="-Wno-error=incompatible-pointer-types" ./configure --prefix=/usr --sysconfdir=/etc --with-gtk=3  > "$LOG/pcmanfm.log" 2>&1

make >> "$LOG/pcmanfm.log" 2>&1

make install >> "$LOG/pcmanfm.log" 2>&1

ldconfig


echo "===== COMPLETE ====="
