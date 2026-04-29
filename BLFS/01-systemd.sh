#!/bin/bash
set -euo pipefail

source ./functions.sh

export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/local/lib/pkgconfig
export MAKEFLAGS="-j$JOBS"

# Python依存の解決
pip3 install --break-system-packages mako pyserpent 2>/dev/null || true

scripts=(
    "expat"
    "libffi"
    "pcre2"
    "glib2"
    "seatd"
    "cmake"
    "pam"
    "libmd"
    "libbsd"
    "shadow"
    "systemd"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

echo "===== LFS Sway & systemd Environment ULTIMATE Setup ====="

# 0. ディレクトリの準備
# LFS/systemd環境ではユニットファイルは /usr/lib/systemd/system が推奨されます
UNIT_DIR=/usr/lib/systemd/system
mkdir -p /etc/pam.d
mkdir -p "$UNIT_DIR"
mkdir -p /etc/systemd/system/multi-user.target.wants
mkdir -p /etc/systemd/system/sockets.target.wants

cat > /etc/pam.d/login << "EOF"
#%PAM-1.0
auth     required       pam_unix.so
account  required       pam_unix.so
password required       pam_unix.so
session  required       pam_unix.so
EOF

cat > /etc/pam.d/other << "EOF"
#%PAM-1.0
auth     required       pam_unix.so
account  required       pam_unix.so
password required       pam_unix.so
session  required       pam_unix.so
EOF

cat > /etc/pam.d/su << "EOF"
# Begin /etc/pam.d/su
# rootからのsuは常に許可（パスワード不要）
auth     sufficient   pam_rootok.so
# 環境変数の読み込み
auth     include      system-auth
# アカウント管理
account  include      system-auth
# セッション管理
session  include      system-auth
# X11（GUI）アプリの権限引き継ぎを許可（Firefoxなどのビルドに便利）
session  optional     pam_xauth.so
# End /etc/pam.d/su
EOF


chmod 600 /etc/shadow

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
