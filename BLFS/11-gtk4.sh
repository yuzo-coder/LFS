#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "gstreamer"
    "gst-plugins-base"
    "gst-plugins-good"
    "gst-plugins-bad"
    "graphene"
    "glslc"
    "gtk4"
    "libsigc++"
    "libsigc++3"
    "mm-common"
    "cairomm"
    "glibmm"
    "pangomm"
    "atkmm"
    "rtkit"
    "gtkmm3"
    "gtkmm4"
)

for pkg in "${scripts[@]}"; do
    echo "========== Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done


echo "===== 11-GTK4 ALL BUILD & CONFIG COMPLETED ====="
