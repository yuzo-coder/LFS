#!/bin/bash
# LFS Desktop Enhancer - Icons & Portals
set -euo pipefail

source ./functions.sh

scripts=(
    "hicolor-icon-theme"
    "adwaita-icon-theme"
    "fuse3"
    "pipewire"
    "bubblewrap"
    "json-glib"
    "graphviz"
    "vala"
    "libpcap"
    "umockdev"
    "libgudev"
    "pytest"
    "pygobject"
    "dbus-python"
    "python-dbusmock"
    "xdg-desktop-portal"
    "inih"
    "xdg-desktop-portal-wlr"
)

for pkg in "${scripts[@]}"; do
    echo "========== Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "=================================================="
echo "   Desktop Enhancement Build Complete!            "
echo "   Icons and Portals are ready.                   "
echo "=================================================="
