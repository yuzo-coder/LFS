set -e
export MAKEFLAGS="-j$(nproc)"
mkdir -p /sources
cd /sources

############################
# バージョン定義
############################
LIBDRM_VER=2.4.120
MESA_VER=24.0.5
WAYLAND_VER=1.22.0
WAYLAND_PROTOCOLS_VER=1.36
LIBXKBCOMMON_VER=1.6.0
PIXMAN_VER=0.43.4
SEATD_VER=0.8.0
XORG_VER=21.1.11
WLROOTS_VER=0.17.2
SWAY_VER=1.9

############################
# ダウンロード
############################

wget https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_VER}.tar.xz
wget https://archive.mesa3d.org/mesa-${MESA_VER}.tar.xz
wget https://wayland.freedesktop.org/releases/wayland-${WAYLAND_VER}.tar.xz
wget https://wayland.freedesktop.org/releases/wayland-protocols-${WAYLAND_PROTOCOLS_VER}.tar.xz
wget https://xkbcommon.org/download/libxkbcommon-${LIBXKBCOMMON_VER}.tar.xz
wget https://www.cairographics.org/releases/pixman-${PIXMAN_VER}.tar.gz
wget https://git.sr.ht/~kennylevinsen/seatd/archive/${SEATD_VER}.tar.gz -O seatd-${SEATD_VER}.tar.gz
wget https://www.x.org/pub/individual/xserver/xorg-server-${XORG_VER}.tar.xz
wget https://gitlab.freedesktop.org/wlroots/wlroots/-/archive/${WLROOTS_VER}/wlroots-${WLROOTS_VER}.tar.gz
wget https://github.com/swaywm/sway/releases/download/${SWAY_VER}/sway-${SWAY_VER}.tar.gz

############################
# 1. libdrm
############################
tar xf libdrm-${LIBDRM_VER}.tar.xz
cd libdrm-${LIBDRM_VER}
meson setup build --prefix=/usr
ninja -C build
ninja -C build install
cd ..

############################
# 2. mesa (virtio/virgl)
############################
tar xf mesa-${MESA_VER}.tar.xz
cd mesa-${MESA_VER}
meson setup build \
  --prefix=/usr \
  -Dgallium-drivers=virgl,swrast \
  -Dvulkan-drivers= \
  -Dplatforms=x11,wayland \
  -Dglx=dri \
  -Degl=true \
  -Dgbm=true \
  -Dllvm=enabled \
  -Dshared-glapi=enabled
ninja -C build
ninja -C build install
cd ..

############################
# 3. wayland
############################
tar xf wayland-${WAYLAND_VER}.tar.xz
cd wayland-${WAYLAND_VER}
meson setup build --prefix=/usr -Ddocumentation=false
ninja -C build
ninja -C build install
cd ..

############################
# 4. wayland-protocols
############################
tar xf wayland-protocols-${WAYLAND_PROTOCOLS_VER}.tar.xz
cd wayland-protocols-${WAYLAND_PROTOCOLS_VER}
meson setup build --prefix=/usr
ninja -C build install
cd ..

############################
# 5. libxkbcommon
############################
tar xf libxkbcommon-${LIBXKBCOMMON_VER}.tar.xz
cd libxkbcommon-${LIBXKBCOMMON_VER}
meson setup build --prefix=/usr
ninja -C build
ninja -C build install
cd ..

############################
# 6. pixman
############################
tar xf pixman-${PIXMAN_VER}.tar.gz
cd pixman-${PIXMAN_VER}
meson setup build --prefix=/usr
ninja -C build
ninja -C build install
cd ..

############################
# 7. seatd
############################
tar xf seatd-${SEATD_VER}.tar.gz
cd seatd-${SEATD_VER}
meson setup build --prefix=/usr -Dsystemd=enabled
ninja -C build
ninja -C build install
cd ..

############################
# 8. Xwayland
############################
tar xf xorg-server-${XORG_VER}.tar.xz
cd xorg-server-${XORG_VER}
meson setup build \
  --prefix=/usr \
  -Dxwayland=true \
  -Dxorg=false \
  -Dglamor=true
ninja -C build
ninja -C build install
cd ..

############################
# 9. wlroots
############################
tar xf wlroots-${WLROOTS_VER}.tar.gz
cd wlroots-${WLROOTS_VER}
meson setup build --prefix=/usr -Dexamples=false
ninja -C build
ninja -C build install
cd ..

############################
# 10. sway
############################
tar xf sway-${SWAY_VER}.tar.gz
cd sway-${SWAY_VER}
meson setup build --prefix=/usr
ninja -C build
ninja -C build install
cd ..

echo "===== PHASE2 COMPLETE ====="
