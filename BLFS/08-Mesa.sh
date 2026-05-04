#!/bin/bash
set -euo pipefail

source ./functions.sh

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
libglvnd
mesa

libepoxy

glu

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== 08 COMPLETE ====="
