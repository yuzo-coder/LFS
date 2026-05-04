#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
gobject-introspection

bash-completion
lua
python3

itstool
pygments
pytest
pyyaml
mako
dbus-python
python-dbusmock

glib2
doxygen

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 03-COMPLETE ====="
