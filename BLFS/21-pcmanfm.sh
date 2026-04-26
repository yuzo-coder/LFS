#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "gsettings-desktop-schemas"
    "nghttp2"
    "sqlite"
    "libsoap"
    "libbytesize"
    "libaio"
    "lvm2"
    "dmraid"
    "nspr"
    "nss"
    "keyutils"
    "popt"
    "cryptsetup"
    "libnvme"
    "libatasmart"
    "libyaml"
    "libblockdev"
    "udisk2"
    "libusb"
    "libarchive"
    "libcdio"
    "libcdio-paranoia"
    "gvfs"
    "menu-cache"
    "libfm"
    "pcmanfm"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done


# gdk-pixbuf のローダーキャッシュを強制更新
gdk-pixbuf-query-loaders --update-cache

update-mime-database /usr/share/mime


echo "=================================================="
echo "    13 GUI Management Tools Build Complete!          "
echo "    You can now launch:                           "
echo "    - PCMAN                        "
echo "    - nm-connection-editor (Network)              "
echo "=================================================="
