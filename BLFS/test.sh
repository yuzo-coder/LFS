#!/bin/bash
set -euo pipefail

source ./functions.sh


LUA52_DIR=$(download_extract "https://www.lua.org/ftp/lua-5.2.4.tar.gz")
cd "$LUA52_DIR"

# 共有ライブラリ(liblua.so)を作成するための修正
sed -i '/^LUA_T=/s/$/ liblua.so/' src/Makefile
sed -i '/^ALL_T=/s/$/ $(LUA_T)/' src/Makefile

make linux MYCFLAGS="-fPIC" > "$LOG/lua52.log" 2>&1

# インストール（衝突を避けるため手動で配置）
mkdir -p "$PREFIX/bin" "$PREFIX/include/lua52" "$PREFIX/lib/pkgconfig"

install -m755 src/lua "$PREFIX/bin/lua52"
install -m755 src/luac "$PREFIX/bin/luac52"
install -m644 src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp "$PREFIX/include/lua52/"
install -m755 src/liblua.a "$PREFIX/lib/liblua52.a"

# pkg-configファイルの作成 (lua52.pc)
cat << EOF > "$PREFIX/lib/pkgconfig/lua52.pc"
V=5.2
R=5.2.4
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include/lua52

Name: Lua
Description: An Extensible Extension Language (v5.2)
Version: \${R}
Libs: -L\${libdir} -llua52 -lm -ldl
Cflags: -I\${includedir}
EOF

LUA54_DIR=$(download_extract "https://www.lua.org/ftp/lua-5.4.0.tar.gz")
cd "$LUA54_DIR"

# 5.4系でも共有ライブラリが作れるように調整
make linux MYCFLAGS="-fPIC" > "$LOG/lua54.log" 2>&1

# こちらは通常の install
make install INSTALL_TOP="$PREFIX" >> "$LOG/lua54.log" 2>&1

# pkg-configファイルの作成 (lua.pc)
cat << EOF > "$PREFIX/lib/pkgconfig/lua.pc"
V=5.4
R=5.4.0
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: Lua
Description: An Extensible Extension Language (v5.4)
Version: \${R}
Libs: -L\${libdir} -llua -lm -ldl
Cflags: -I\${includedir}
EOF

ldconfig
build_meson "wireplumber" ""https://ftp2.osuosl.org/pub/blfs/12.4/w/wireplumber-0.5.10.tar.bz2 "-Ddoc=disabled -Dsystem-lua=true -Dintrospection=disabled"

build_meson "mpv" \
    "https://github.com/mpv-player/mpv/archive/refs/tags/v0.41.0.tar.gz" \
    "-Dalsa=enabled \
    -Dpulse=enabled \
    -Dpipewire=enabled \
    -Dwayland=enabled \
    -Dx11=enabled \
    -Dlua=lua52 \
    --libdir=/usr/lib \
    -Dlibmpv=true \
    -Djavascript=disabled"

echo "mpv --vo=gpu /pathtovideo "



echo "===== COMPLETE ====="
