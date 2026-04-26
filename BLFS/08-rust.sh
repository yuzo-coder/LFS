#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "cargo"
    "cargo-c"
    "cairo"
    "pixman"
    "fribidi"
    "pango"
    "librsvg"
)

for pkg in "${scripts[@]}"; do
    echo "--- Building $pkg ---"
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

# 5. ローダーキャッシュの更新 (librsvg が入った後に行う)
echo "Updating gdk-pixbuf loaders cache..."

/usr/bin/gdk-pixbuf-query-loaders --update-cache

echo "===== 09 RUST COMPLETE ====="

