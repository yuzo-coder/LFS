#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs
mkdir -p "$SRC" "$LOG"

# 共通関数の読み込み
if [ -f "./common.sh" ]; then
    source "./common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi


build_autotools "libfyaml" \
    "https://github.com/pantoniou/libfyaml/releases/download/v0.9/libfyaml-0.9.tar.gz" \
    "--disable-static"

build_autotools "libxml2" \
    "https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz" \
    "--disable-static"

build_autotools "itstool" \
    "https://files.itstool.org/itstool/itstool-2.0.7.tar.bz2" \
    "--disable-static"


build_autotools "bash-completion" \
    "https://github.com/scop/bash-completion/releases/download/2.16.0/bash-completion-2.16.0.tar.xz" \
    "--disable-static"


build_autotools "vapigen" \
    "https://download.gnome.org/sources/vala/0.56/vala-0.56.18.tar.xz" \
    "--disable-valadoc"


# build_meson "gdk-pixbuf" \
#    "https://gitlab.gnome.org/GNOME/gdk-pixbuf.git" \
#    "-Dbuiltin_loaders=none -Djpeg=enabled -Dtests=false -Dpng=enabled -Dtiff=enabled -Dintrospection=enabled -Dman=false -Dglycin=disabled"

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



echo "===== Building gobject-introspection  ====="

cd "$SRC"
    
rm -rf gobject-introspection-1.80.1

wget https://download.gnome.org/sources/gobject-introspection/1.84/gobject-introspection-1.84.0.tar.xz

tar -xf gobject-introspection-1.84.0.tar.xz
    
cd gobject-introspection-1.84.0

# MSVCCompiler �~B~R�~C~@�~C~_�~C��~A��~B��~C��~B��~A��~Z義�~A~W�~@~ANameError �~B~R�~[~^�~A��~A~Y�~B~K
sed -i 's/from distutils.msvccompiler import MSVCCompiler/class MSVCCompiler: pass/' giscanner/ccompiler.py
    
export SETUPTOOLS_USE_DISTUTILS=local
meson setup build --prefix=/usr --libdir=/usr/lib --buildtype=release \
    -Dbuild_introspection_data=true \
    -Dgtk_doc=false \
    -Ddoctool=disabled \
    -Dbuild_introspection_data=true \
    -Dpython=python3 > $LOG/gobject.log 2>&1

ninja -C build -j"$JOBS" >> "$LOG/gobject.log" 2>&1

ninja -C build install >> "$LOG/gobject.log" 2>&1

mkdir -pv /usr/share/gir-1.0

mkdir -pv /usr/lib/girepository-1.0

cd build

cp -v gir/*.gir /usr/share/gir-1.0/

cp -v gir/*.typelib /usr/lib/girepository-1.0/
ldconfig 

cd "$ROOT_DIR"

# 環境変数 CXXFLAGS に C++17 をセットして構成
#export CXXFLAGS="-O3 -std=c++17"
# build_meson pango "https://download.gnome.org/sources/pango/1.56/pango-1.56.0.tar.xz" "-Dintrospection=enabled -Dcpp_std=c++17"



# build_meson "gtk4" \
#     "https://download.gnome.org/sources/gtk/4.18/gtk-4.18.6.tar.xz" \
#    "-Dbuild-tests=false -Dbuild-examples=false -Dintrospection=enabled -Dvulkan=disabled -Dx11-backend=true -Dwayland-backend=true -Dmedia-gstreamer=disabled"


echo "===== pygments ====="
cd "$SRC"

rm -rf pygments-2.20.0

wget -O pygments.tar.gz https://github.com/pygments/pygments/archive/refs/tags/2.20.0.tar.gz

tar -xf pygments.tar.gz

cd pygments-2.20.0

python3 -m pip install --break-system-packages .

cd "$ROOT_DIR"
build_meson "gtk-doc" \
    "https://download.gnome.org/sources/gtk-doc/1.34/gtk-doc-1.34.0.tar.xz" \
    ""

echo "===== COMPLETE ====="
