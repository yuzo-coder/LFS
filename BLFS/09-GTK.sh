#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(

gsettings-desktop-schemas
glib-networking

atk
at-spi2-core
at-spi2-atk

cairo
pango
librsvg
graphene

gtk3
gtk4
libadwaita

hicolor-icon-theme
adwaita-icon-theme

libsigc++
libsigc++3

glibmm

cairomm
pangomm
atkmm
gtkmm3
gtkmm4
mm-common

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LLVM COMPLETE ====="
