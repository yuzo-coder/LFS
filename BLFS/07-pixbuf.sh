#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libtiff"
    "libyuv"
    "yasm"
    "libaom"
    "libavif"
    "shared-mime-info"
    "libjpeg-turbo"
    "gdk-pixbuf"
)

for pkg in "${scripts[@]}"; do
    echo "--- Building $pkg ---"
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

gdk-pixbuf-query-loaders --update-cache

update-mime-database /usr/share/mime

echo "===== Image Stack Build Completed (Minimal) ====="
