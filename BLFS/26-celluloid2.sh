#!/bin/bash
set -euo pipefail

source "./common.sh"

JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
mkdir -p "$SRC" "$LOG"

export CXXFLAGS="-O3 -std=c++17"




pip3 install https://github.com/djc/rnc2rng/archive/refs/tags/2.7.0.tar.gz


echo "===== sassc ====="
cd "$SRC"

wget https://github.com/sass/sassc/archive/3.6.2/sassc-3.6.2.tar.gz

rm -rf sassc-3.6.2

tar -xf sassc-3.6.2.tar.gz

cd sassc-3.6.2

wget https://github.com/sass/libsass/archive/3.6.4/libsass-3.6.4.tar.gz

tar -xzvf libsass-3.6.4.tar.gz

mv libsass-3.6.4 libsass

export SASS_LIBSASS_PATH=$(pwd)/libsass

make

install -v -m755 bin/sassc /usr/bin/sassc

cd "$ROOT_DIR"


echo "===== COMPLETE ====="

