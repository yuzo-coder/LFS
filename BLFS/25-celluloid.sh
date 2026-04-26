#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libfyaml"
#    "libxml2"
     "itstool"
     "bash-completion"
     "vapigen"
     "rnc2rng"
     "sassc"
     "pygments"
     "gtk-doc"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done


echo "===== COMPLETE ====="
