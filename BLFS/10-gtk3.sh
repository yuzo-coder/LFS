#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "libogg"
    "libvorbis"
    "libcanberra"
    "iso-codes"
    "libxslt"
    "mobile-broadband-provider-info"
    "duktape"
    "polkit"
    "libndp"
    "nettle"
    "libunistring"
    "gnutls"
    "libpsl"
    "NetworkManager"
    "libgpg-error"
    "libgcrypt"
    "libsecret"
    "10-glib2"
    "atk"
    "libepoxy"
    "at-spi2-core"
    "at-spi2-atk"
    "libxkbcommon"
    "gtk3"
    "libnma"
    "network-manager-applet"
    "xkeyboard-config"
    "mesa-demos"
)

for pkg in "${scripts[@]}"; do
    echo "========== Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "=================================================="
echo "    GUI Management Tools Build Complete!          "
echo "    You can now launch:                           "
echo "    - pavucontrol (Volume)                        "
echo "    - nm-connection-editor (Network)              "
echo "=================================================="
