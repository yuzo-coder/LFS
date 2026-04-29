#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libvdpau"
    "libunwind"
    "libdisplay-info"
#    "libdrm"
    "glslang"
    "bindgen-cli"
    "libclc"
    "pyyaml"
    "SPIRV-Headers"
    "SPIRV-Tools"
    "SPIRV-LLVM-Translator"
    "cbindgen"
    "mesa"
    "libglvnd"
    "glu"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done


echo "=================================================="
echo "Mesa (VirtIO-GPU) and Utils Build Complete."
echo "Check acceleration with: eglinfo | grep renderer"
echo "=================================================="
