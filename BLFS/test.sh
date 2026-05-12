#!/bin/bash
set -euo pipefail

source ./functions.sh


build_cmake "glslang" \
    "https://github.com/KhronosGroup/glslang/archive/16.2.0/glslang-16.2.0.tar.gz" \
    "-D ENABLE_OPT=OFF -G Unix Makefiles"

echo "===== COMPLETE ====="
