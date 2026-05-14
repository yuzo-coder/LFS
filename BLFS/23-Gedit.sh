#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libgedit-amtk
libgedit-gtksourceview
libgedit-gfls

icu4u
libhandy
libgedit-tepl
libpeas
enchant
gspell
gedit

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== COMPLETE ====="
