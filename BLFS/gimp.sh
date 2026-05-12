#!/bin/bash
set -euo pipefail

source ./functions.sh


# build_meson babl "https://download.gimp.org/pub/babl/0.1/babl-0.1.114.tar.xz" ""



# build_meson gegl "https://download.gimp.org/pub/gegl/0.4/gegl-0.4.62.tar.xz" ""


# build_cmake exiv2 "https://github.com/Exiv2/exiv2/archive/v0.27.7/exiv2-0.27.7.tar.gz" ""

# build_meson gexiv2 "https://download.gnome.org/sources/gexiv2/0.14/gexiv2-0.14.6.tar.xz" ""


# build_autotools libmypaint "https://github.com/mypaint/libmypaint/releases/download/v1.6.1/libmypaint-1.6.1.tar.xz" ""

# build_autotools mypaint-brushes "https://github.com/mypaint/mypaint-brushes/releases/download/v1.3.1/mypaint-brushes-1.3.1.tar.xz" ""


# build_meson appstream-glib "http://people.freedesktop.org/~hughsient/appstream-glib/releases/appstream-glib-0.8.3.tar.xz" "-Drpm=false -Dman=false"

# build_cmake poppler "https://poppler.freedesktop.org/poppler-25.08.0.tar.xz" "-DENABLE_QT5=OFF -DENABLE_QT6=OFF -DENABLE_GPGME=OFF -DENABLE_BOOST=OFF -DENABLE_LIBOPENJPEG=unmaintained"

# cd "$SRC"
# wget https://poppler.freedesktop.org/poppler-data-0.4.12.tar.gz
# rm -rf poppler-data-0.4.12
# tar -xf poppler-data-0.4.12.tar.gz
# cd poppler-data-0.4.12

# インストール（prefixを指定）
# make install prefix=/usr

build_meson pygobject "https://download.gnome.org/sources/pygobject/3.52/pygobject-3.52.3.tar.gz" ""

build_meson gimp "https://download.gimp.org/gimp/v3.0/gimp-3.0.4.tar.xz" "-Djavascript=enabled -Dlua=true -Dvala=enabled -Dgi-docgen=disabled"


echo "===== COMPLETE ====="
