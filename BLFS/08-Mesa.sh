#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   08   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(
wayland
wayland-protocols
wayland-utils
libxkbcommon
xkbcomp
Vulkan-Headers
Vulkan-Loader
libdrm
cargo
cargo-c
bindgen-cli
cbindgen
nodejs
llvm
libclc
SPIRV-LLVM-Translator
SPIRV-Headers
SPIRV-Tools
glslang
glslc

mesa-1
libglvnd
mesa-2

libepoxy

glu
libva
libva-utils
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   08   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
