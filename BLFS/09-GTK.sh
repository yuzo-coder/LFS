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

gstreamer
gst-plugins-base

gst-plugins-good
gst-plugins-bad

gobject-introspection
librsvg
graphene
graphviz

vala

gtk3
gtk4
libadwaita
mesa-demos

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

echo "===== 09 COMPLETE ====="
