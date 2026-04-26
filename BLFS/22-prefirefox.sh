#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "python3"
    "nodejs"
    "libwebp"
    "libevent"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

#jbuild_autotools "sqlite" \
#    "https://www.sqlite.org/2024/sqlite-autoconf-3450200.tar.gz" \
#    "--disable-static"

echo "===== Pre-Firefox installation completed! ====="
