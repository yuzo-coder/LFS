#!/bin/bash
set -euo pipefail

source ./functions.sh

#build_meson libgedit-amtk "https://gitlab.gnome.org/World/gedit/libgedit-amtk/-/archive/5.9.1/libgedit-amtk-5.9.1.tar.bz2" "-Dgtk_doc=false"

#build_meson libgedit-gtksourceview "https://gitlab.gnome.org/World/gedit/libgedit-gtksourceview/-/archive/299.5.0/libgedit-gtksourceview-299.5.0.tar.bz2" "-Dgtk_doc=false"

#build_meson libgedit-gfls "https://gitlab.gnome.org/World/gedit/libgedit-gfls/-/archive/0.3.0/libgedit-gfls-0.3.0.tar.bz2" "-Dgtk_doc=false"


# cd "$SRC"

#wget https://github.com/unicode-org/icu/releases/download/release-77-1/icu4c-77_1-src.tgz

#rm -rf icu

#tar -xf icu4c-77_1-src.tgz

#cd icu/source

#./configure --prefix=/usr

#make

#make install

#build_meson libhandy "https://download.gnome.org/sources/libhandy/1.8/libhandy-1.8.3.tar.xz" "-Dgtk_doc=false"

#build_meson libgedit-tepl "https://gitlab.gnome.org/World/gedit/libgedit-tepl/-/archive/6.13.0/libgedit-tepl-6.13.0.tar.bz2" "-Dgtk_doc=false"

#build_meson libpeas "https://download.gnome.org/sources/libpeas/1.36/libpeas-1.36.0.tar.xz" ""

build_autotools enchant "https://github.com/rrthomas/enchant/releases/download/v2.8.12/enchant-2.8.12.tar.gz" ""

build_meson gspell "https://download.gnome.org/sources/gspell/1.14/gspell-1.14.0.tar.xz" "-Dgtk_doc=false"

build_meson gedit "https://download.gnome.org/sources/gedit/48/gedit-48.1.tar.xz" "-Dgtk_doc=false"

echo "===== COMPLETE ====="
