#!/bin/bash
set -euo pipefail

source ./functions.sh

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

echo "===== 03-COMPLETE ====="

