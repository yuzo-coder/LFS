#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   23   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "

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

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   23   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "

