#!/bin/bash
set -e

JOBS=$(nproc)
PREFIX=/usr
SRC=$PWD/src
LOG=$PWD/logs

mkdir -p $SRC $LOG
cd $SRC

build_auto() {
  URL=$1
  NAME=$(basename $URL)

  echo "===== $NAME ====="
  wget -c $URL
  tar xf $NAME
  DIR=$(tar tf $NAME | head -1 | cut -d/ -f1)
  cd $DIR

  ./configure --prefix=$PREFIX > $LOG/$DIR.log 2>&1
  make -j$JOBS >> $LOG/$DIR.log 2>&1
  make install >> $LOG/$DIR.log 2>&1

  cd ..
}

# ---- 基本マクロとproto ----

build_auto https://xorg.freedesktop.org/releases/individual/util/util-macros-1.20.2.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/proto/xorgproto-2024.1.tar.xz

# ---- xcb最小 ----

build_auto https://xorg.freedesktop.org/releases/individual/lib/libXau-1.0.12.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/lib/libXdmcp-1.1.5.tar.xz
build_auto https://xcb.freedesktop.org/dist/xcb-proto-1.17.0.tar.xz
build_auto https://xcb.freedesktop.org/dist/libxcb-1.17.0.tar.xz

# ---- 必須ライブラリ ----

build_auto https://xorg.freedesktop.org/releases/individual/lib/libX11-1.8.10.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/lib/libXext-1.3.6.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/lib/libXrandr-1.5.4.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/lib/libXrender-0.9.12.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/lib/libXcursor-1.2.3.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/lib/libXft-2.3.8.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/lib/libXinerama-1.1.5.tar.xz

# ---- pixman（描画必須）----

build_auto https://www.cairographics.org/releases/pixman-0.44.2.tar.gz

# ---- サーバ ----

build_auto https://xorg.freedesktop.org/releases/individual/xserver/xorg-server-21.1.18.tar.xz

# ---- 最小アプリ ----

build_auto https://xorg.freedesktop.org/releases/individual/app/xinit-1.4.4.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/app/xterm-401.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/app/twm-1.0.13.tar.xz
build_auto https://xorg.freedesktop.org/releases/individual/app/xclock-1.1.1.tar.xz

echo "===== MINIMAL X COMPLETE ====="
