#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   21   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "

scripts=(

babl
gegl
exiv2
gexiv2
libmypaint
mypaint-brushes
appstream-glib
poppler
poppler-data
pygobject
gimp

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   21   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "

