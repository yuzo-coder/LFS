#!/bin/bash
set -euo pipefail

# --- 1. 環境設定 ---
JOBS=$(nproc)
PREFIX=/usr
ROOT_DIR=$(pwd)
SRC=$ROOT_DIR/sources
LOG=$ROOT_DIR/logs

mkdir -p "$SRC" "$LOG"
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/lib/pkgconfig
export MAKEFLAGS="-j$JOBS"

# Python依存の解決
pip3 install --break-system-packages mako pyserpent 2>/dev/null || true

# 共通関数の読み込み
if [ -f "./common.sh" ]; then
    source "./common.sh"
else
    echo "Error: common.sh not found!"
    exit 1
fi


# --- 3. 基礎ライブラリ (Base) ---
build_autotools expat "https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.xz" ""

build_autotools libffi "https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz" ""

build_autotools pcre2 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.43/pcre2-10.43.tar.gz" "--enable-unicode"

build_meson glib2 "https://download.gnome.org/sources/glib/2.80/glib-2.80.4.tar.xz" "-Dtests=false"

build_meson seatd "https://git.sr.ht/~kennylevinsen/seatd/archive/0.8.0.tar.gz" "-Dlibseat-builtin=enabled -Dserver=enabled -Dman-pages=disabled"

# --- 4. ツールチェーン (CMake Bootstrap) ---
if ! command -v cmake &> /dev/null; then
    echo "===== Building CMake  ====="
    DIR=$(download_extract "https://cmake.org/files/v4.1/cmake-4.1.0.tar.gz")
    cd "$DIR"

    # 1. CursesDialog のビルドを「正規の手順」で無効化する
    # ファイルの中身を「何もしない」という命令に書き換えます
    echo "return()" > Source/CursesDialog/CMakeLists.txt  

    # 2. Curses を見つけられないようにダミーの値を設定（または空にする）
    # さらに GCC 15 対策のフラグを export
    export CXXFLAGS="-O2 -fpermissive -DNCURSES_NOMACROS"

    ./bootstrap \
        --prefix="$PREFIX" \
        --parallel="$JOBS" \
        --no-system-libs \
        > "$LOG/cmake.log" 2>&1
        
    make -j"$JOBS" >> "$LOG/cmake.log" 2>&1
    make install >> "$LOG/cmake.log" 2>&1
    cd "$ROOT_DIR"
fi

# --- 5. PAM & Shadow ログインスタック ---
# PAM導入
build_meson linux-pam "https://github.com/linux-pam/linux-pam/releases/download/v1.7.2/Linux-PAM-1.7.2.tar.xz" "-Ddocs=disabled -Dnis=disabled"

# PAM設定の最小構成（これがないとログインできなくなります）
if [ ! -f /etc/pam.d/other ]; then
    mkdir -p /etc/pam.d
    cat > /etc/pam.d/other << "EOF"
auth     required       pam_unix.so
account  required       pam_unix.so
password required       pam_unix.so
session  required       pam_unix.so
EOF
fi

# Shadow再ビルド (PAM有効化)
build_autotools shadow "https://github.com/shadow-maint/shadow/releases/download/4.18.0/shadow-4.18.0.tar.xz" \
    "--sysconfdir=/etc --disable-static --with-libpam --without-libbsd"

# Systemd (PAM有効化)
build_meson systemd "https://github.com/systemd/systemd/archive/v257.8/systemd-257.8.tar.gz" "-Dpam=enabled -Dmode=release"

echo "===== LFS Sway & systemd Environment ULTIMATE Setup ====="

# 0. ディレクトリの準備
# LFS/systemd環境ではユニットファイルは /usr/lib/systemd/system が推奨されます
UNIT_DIR=/usr/lib/systemd/system
mkdir -p /etc/pam.d
mkdir -p "$UNIT_DIR"
mkdir -p /etc/systemd/system/multi-user.target.wants
mkdir -p /etc/systemd/system/sockets.target.wants

# D-Bus用ディレクトリ
mkdir -p /run/dbus
if getent passwd dbus >/dev/null; then
    chown dbus:dbus /run/dbus
fi

# 1. ユーザー権限の設定
echo "Step 1: Setting up user groups..."
# 'user' というユーザーが存在することを確認してから実行
if id "user" &>/dev/null; then
    for grp in video input render seat; do
        groupadd -f -r "$grp"
        usermod -aG "$grp" user
    done
else
    echo "Warning: User 'user' not found. skipping group assignment."
fi

# 2. PAM 設定 (systemd-logind と session 認識に必須)
echo "Step 2: Configuring PAM..."

# system-session: セッション開始時に systemd-logind をフックする
cat > /etc/pam.d/system-session << "EOF"
session    required    pam_loginuid.so
session    required    pam_limits.so
session    required    pam_unix.so
session    optional    pam_systemd.so
EOF

# system-auth: 基本認証（これがないとlogin自体ができなくなる恐れあり）
cat > /etc/pam.d/system-auth << "EOF"
auth       required    pam_unix.so
account    required    pam_unix.so
password   required    pam_unix.so
session    required    pam_unix.so
EOF

# login: 物理コンソールからのログイン用（最重要）
cat > /etc/pam.d/login << "EOF"
auth      requisite    pam_nologin.so
auth      include      system-auth
account   include      system-auth
password  include      system-auth
session   include      system-session
EOF

# sshd: リモートログイン用
cat > /etc/pam.d/sshd << "EOF"
auth      include      system-auth
account   include      system-auth
password  include      system-auth
session   include      system-session
EOF

# 3. D-Bus ユニットファイルの作成
echo "Step 3: Creating D-Bus units..."
cat > "$UNIT_DIR/dbus.socket" << "EOF"
[Unit]
Description=D-Bus System Message Bus Socket
[Socket]
ListenStream=/run/dbus/system_bus_socket
EOF

cat > "$UNIT_DIR/dbus.service" << "EOF"
[Unit]
Description=D-Bus System Message Bus
Requires=dbus.socket
After=dbus.socket
[Service]
ExecStart=/usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation
ExecReload=/usr/bin/dbus-send --print-reply --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig
[Install]
WantedBy=multi-user.target
Alias=dbus.service
EOF

# 4. seatd サービスユニット作成
echo "Step 4: Creating seatd service..."
cat > "$UNIT_DIR/seatd.service" << "EOF"
[Unit]
Description=Seat management daemon
Before=display-manager.service
[Service]
Type=simple
ExecStart=/usr/bin/seatd -g video
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# 5. systemd-logind の確認と有効化
echo "Step 5: Enabling services..."
# 手動シンボリックリンク（systemctl enableの代行）
ln -sf "$UNIT_DIR/dbus.socket" /etc/systemd/system/sockets.target.wants/dbus.socket
ln -sf "$UNIT_DIR/dbus.service" /etc/systemd/system/multi-user.target.wants/dbus.service
ln -sf "$UNIT_DIR/seatd.service" /etc/systemd/system/multi-user.target.wants/seatd.service

# logind が /usr/lib か /lib かを判定して有効化
LOGIND_SRC=$(find /usr/lib/systemd /lib/systemd -name systemd-logind.service 2>/dev/null | head -n 1)
if [ -n "$LOGIND_SRC" ]; then
    ln -sf "$LOGIND_SRC" /etc/systemd/system/multi-user.target.wants/systemd-logind.service
    echo "Enabled logind from $LOGIND_SRC"
fi

# 6. 反映
# すでに systemd 環境で動いているなら daemon-reload
systemctl daemon-reload 2>/dev/null || echo "Running in chroot? Skipping daemon-reload."
systemctl start seatd dbus 2>/dev/null || true
systemctl enable seatd dbus 2>/dev/null || true

# 7. 環境変数の設定 (Sway起動に必須)
# 次回ログイン時に自動適用されるよう profile.d に配置
mkdir -p /etc/profile.d
cat > /etc/profile.d/sway.sh << "EOF"
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        mkdir -p "$XDG_RUNTIME_DIR"
        chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR"
        chmod 700 "$XDG_RUNTIME_DIR"
    fi
fi
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway
EOF


echo "===== 01-Systemd COMPLETE: Login Session is ready ====="
