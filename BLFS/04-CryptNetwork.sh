#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libgpg-error
libgcrypt
nettle
libunistring
nspr
nss
gnutls
nghttp2
libpsl
libevent

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 04-COMPLETE ====="
