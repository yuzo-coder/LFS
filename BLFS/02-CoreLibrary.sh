#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   02   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(
expat
libffi
pcre2
libxml2
libxslt
libyaml
libfyaml
json-c
json-glib
jsoncpp
libmd
libbsd
libpthread-stubs
libtirpc
sqlite

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   02   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
