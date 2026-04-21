#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
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


echo "===== Python-3.11.0 ====="

cd $SRC

mkdir -p /opt/python311

wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tar.xz

tar -xf Python-3.11.0.tar.xz

cd Python-3.11.0

./configure --prefix=/opt/python311       \
            --enable-shared     \
            --without-ensurepip \
            --without-static-libpython

make

make install

cd $ROOT_DIR


# Rust/Cargoの準備（システムパスへ配置）
cp /root/.cargo/bin/rustc /usr/bin/rustc
cp /root/.cargo/bin/cargo /usr/bin/cargo
cp /root/.cargo/bin/rustup /usr/bin/rustup
chmod +x /usr/bin/rustup /usr/bin/rustc /usr/bin/cargo

# 一般ユーザー 'user' の環境整備
su - user -c "rustup default stable"
su - user -c "cargo install cbindgen"
chown -R user:user /home/user/.cargo

# --- 2. Firefox ソースの準備 ---
FIREFOX_URL="https://archive.mozilla.org/pub/firefox/releases/128.1.0esr/source/firefox-128.1.0esr.source.tar.xz"
TAR_NAME="firefox-128.1.0esr.source.tar.xz"
NAME="firefox-128.1.0"

echo "===== Preparing $NAME ====="
cd "$SRC"
rm -rf "$NAME"
[ -f "$TAR_NAME" ] || wget "$FIREFOX_URL"
tar xf "$TAR_NAME"
cd "$NAME"

# --- 3. .mozconfig の作成（エラー原因を完全排除） ---
cat << EOF > .mozconfig
ac_add_options --prefix=/usr
ac_add_options --enable-application=browser
ac_add_options --enable-release
ac_add_options --without-wasm-sandboxed-libraries

# オーディオ設定（ALSA重視）
ac_add_options --enable-alsa
ac_add_options --disable-pulseaudio
ac_add_options --enable-audio-backends=alsa

# システムライブラリの利用
ac_add_options --enable-ffmpeg
ac_add_options --with-system-libvpx
ac_add_options --with-system-ffi
ac_add_options --with-system-nspr
ac_add_options --with-system-nss
# ac_add_options --with-system-icu

# 最適化設定（GCC 15/16対策）
ac_add_options --enable-optimize="-O2 -march=native -fno-delete-null-pointer-checks"

# ビルドディレクトリ設定
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-firefox

# その他
ac_add_options --disable-tests
ac_add_options --disable-updater
EOF

# --- 4. 各種互換性パッチの適用 ---
echo "Applying LFS & cbindgen compatibility patches..."

# (1) cbindgenパースエラー回避
sed 's/input.try/&_parse/' -i servo/components/style_traits/values.rs

# (2) 重複キー "Keyframe" の解消
sed '0,/"Keyframe"/{//d}' -i servo/ports/geckolib/cbindgen.toml

# (4) Cargoの設定調整
sed '/patch.crates-io/a glslopt={path="third_party/rust/glslopt"}' -i Cargo.toml
sed '/name = "glslopt"/,/^$/{/source/d;/checksum/d}' -i Cargo.lock

# --- 5. 環境変数と権限の設定 ---
export CFLAGS="-march=native -DSYS_SECCOMP=317"
export CXXFLAGS="-march=native -DSYS_SECCOMP=317"
export BINDGEN_EXTRA_CLANG_ARGS="-march=native -target x86_64-unknown-linux-gnu"

# 所有権を user に一括変更
chown -R user:user .

# --- 6. ビルド実行 ---
echo "Starting build with $JOBS cores..."
rm -rf obj-firefox

mkdir -p /tmp/firefox-obj
chown -R user:user /tmp/firefox-obj
ln -s /tmp/firefox-obj $SRC/firefox-128.1.0/obj-firefox
chown -h user:user $SRC/firefox-128.1.0/obj-firefox
echo "/tmp/firefox-obj: " "$SRC/firefox-128.1.0/obj-firefox"

su - user -c "
    cd $SRC/$NAME && \
    export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig && \
    export PYTHON=/opt/python311/bin/python3.11 && \
    export PATH=/opt/python311/bin:\$PATH:/home/user/.cargo/bin && \
    export LD_LIBRARY_PATH=/opt/python311/lib:\$LD_LIBRARY_PATH && \
    export RUSTC=/usr/bin/rustc && \
    export CARGO=/usr/bin/cargo && \
    ./mach build" >> "$LOG/firefox.log" 2>&1

# --- 7. インストール（root権限） ---
echo "Installing Firefox..."
export PYTHON=/opt/python311/bin/python3.11
export PATH=/opt/python311/bin:$PATH
$PYTHON ./mach install >> "$LOG/firefox.log" 2>&1

echo "===== Firefox-128 Complete ====="
