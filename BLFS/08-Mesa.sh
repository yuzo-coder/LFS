#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
libxkbcommon
wayland
wayland-protocols
wayland-utils
# libxkbcommon
xkbcomp
Vulkan-Headers
Vulkan-Loader
libdrm
cargo
cargo-c

bindgen-cli
cbindgen
nodejs

libepoxy
llvm
libclc

SPIRV-LLVM-Translator
SPIRV-Headers
SPIRV-Tools
glslang
glslc
mesa

# libepoxy

libglvnd
glu
mesa-demos

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LLVM COMPLETE ====="
