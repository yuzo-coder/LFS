#!/bin/bash
# common.sh

download_extract() {
    local URL=$1
    local TAR=${URL##*/}
    echo "Downloading $TAR..." >&2
    cd "$SRC"
    [ -f "$TAR" ] || wget -c "$URL" --no-check-certificate >&2
    
    local DIR=$(tar tf "$TAR" | head -1 | cut -d/ -f1)
    rm -rf "$DIR"
    tar xf "$TAR"
    echo "$SRC/$DIR"
}

build_autotools() {
    local NAME=$1; local URL=$2; local CONF_OPTS=$3
    echo "===== Building $NAME (autotools) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"

    # 以前のビルド残骸を掃除
    [ -f Makefile ] && make distclean || true

    ./configure --prefix="$PREFIX" --libdir=/usr/lib $CONF_OPTS > "$LOG/$NAME.log" 2>&1
    make -j$(nproc) >> "$LOG/$NAME.log" 2>&1
    
    # インストール。既存ファイルがあっても強制(force)するように、
    # あるいはエラーでも中断しないように設定（iso-codesのようなフック対策）
    make install >> "$LOG/$NAME.log" 2>&1 || make -i install >> "$LOG/$NAME.log" 2>&1

    ldconfig
    cd "$ROOT_DIR"
}

build_meson() {
    local NAME=$1; local URL_OR_GIT=$2; local EXTRA=$3
    echo "===== Building $NAME (meson) ====="
    
    local DIR=""
    if [[ "$URL_OR_GIT" == *.git ]]; then
        cd "$SRC"
        rm -rf "$NAME"
        git clone "$URL_OR_GIT" "$NAME"
        DIR="$SRC/$NAME"
    else
        DIR=$(download_extract "$URL_OR_GIT")
    fi

    cd "$DIR"
    rm -rf build
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release $EXTRA > "$LOG/$NAME.log" 2>&1
    ninja -C build >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

build_cmake() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (cmake) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build && mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib $EXTRA .. > "$LOG/$NAME.log" 2>&1
    make >> "$LOG/$NAME.log" 2>&1
    make install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

build_rust_task() {
    local NAME=$1; local GIT_URL=$2; local BIN_NAME=$3
    echo "===== Building $NAME (Rust) ====="
    cd "$SRC"
    rm -rf "$NAME"
    git clone "$GIT_URL" "$NAME"
    cd "$NAME"
    cargo build --release --locked > "$LOG/$NAME.log" 2>&1
    cp "target/release/$BIN_NAME" "$PREFIX/bin/"
    cd "$ROOT_DIR"
}

build_mm_lib() {
    local NAME=$1; local URL=$2; local EXTRA=$3
    echo "===== Building $NAME (meson lib) ====="
    local DIR=$(download_extract "$URL")
    cd "$DIR"
    rm -rf build
 
    # ドキュメント生成エラーを回避するためのダミーパス作成
    mkdir -p build/subprojects/mm-common
    touch build/subprojects/mm-common/libstdc++.tag
    
    meson setup build --prefix="$PREFIX" --libdir=/usr/lib --buildtype=release \
        -Dbuild-documentation=false $EXTRA > "$LOG/$NAME.log" 2>&1
    
    # libsigc++関連のパスも保険で作成
    mkdir -p build/subprojects/libsigcplusplus-2.0/docs/manual/html
    
    ninja -C build -j"$JOBS" >> "$LOG/$NAME.log" 2>&1
    ninja -C build install >> "$LOG/$NAME.log" 2>&1
    ldconfig
    cd "$ROOT_DIR"
}

