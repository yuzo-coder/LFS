#!/bin/bash
set -uo pipefail

echo "===== LFS Sway & systemd Environment ULTIMATE Setup ====="

# 0. ディレクトリの強制準備
mkdir -p /etc/pam.d
mkdir -p /lib/systemd/system
mkdir -p /etc/systemd/system/multi-user.target.wants
mkdir -p /etc/systemd/system/sockets.target.wants
mkdir -p /run/dbus
chown dbus:dbus /run/dbus 2>/dev/null || true

# 1. ユーザー権限の設定
echo "Step 1: Setting up user groups..."
for grp in video input render seat; do
    groupadd -f -r "$grp"
    usermod -aG "$grp" user
done

# 2. PAM 設定 (systemd-logind がセッションを認識するために必須)
echo "Step 2: Configuring PAM..."
cat > /etc/pam.d/system-session << "EOF"
# Begin /etc/pam.d/system-session
session    required    pam_loginuid.so
session    optional    pam_systemd.so
session    required    pam_unix.so
# End /etc/pam.d/system-session
EOF

cat > /etc/pam.d/system-auth << "EOF"
# Minimal system-auth for LFS
auth       required    pam_unix.so
account    required    pam_unix.so
session    required    pam_unix.so
session    optional    pam_systemd.so
EOF

# /etc/pam.d/sshd があるか確認し、無ければ作成
cat > /etc/pam.d/sshd << "EOF"
auth      include     system-auth
account   include     system-auth
password  include     system-auth
session   include     system-session
EOF

# 3. D-Bus ユニットファイルの作成と強制有効化
echo "Step 3: Creating and forcing D-Bus units..."
cat > /lib/systemd/system/dbus.socket << "EOF"
[Unit]
Description=D-Bus System Message Bus Socket
[Socket]
ListenStream=/run/dbus/system_bus_socket
EOF

cat > /lib/systemd/system/dbus.service << "EOF"
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

# 手動でシンボリックリンクを作成 (systemctl enable の代わり)
ln -sf /lib/systemd/system/dbus.socket /etc/systemd/system/sockets.target.wants/dbus.socket
ln -sf /lib/systemd/system/dbus.service /etc/systemd/system/multi-user.target.wants/dbus.service

# 4. seatd サービスユニット作成と強制有効化
echo "Step 4: Creating seatd service..."
cat > /lib/systemd/system/seatd.service << "EOF"
[Unit]
Description=Seat management daemon
[Service]
Type=simple
ExecStart=/usr/bin/seatd -g video
Restart=always
[Install]
WantedBy=multi-user.target
EOF

ln -sf /lib/systemd/system/seatd.service /etc/systemd/system/multi-user.target.wants/seatd.service

# 5. systemd-logind の強制有効化
echo "Step 5: Forcing systemd-logind..."
# LFSの標準パスにあるはずのファイルをリンク
if [ -f /lib/systemd/system/systemd-logind.service ]; then
    ln -sf /lib/systemd/system/systemd-logind.service /etc/systemd/system/multi-user.target.wants/systemd-logind.service
elif [ -f /usr/lib/systemd/system/systemd-logind.service ]; then
    ln -sf /usr/lib/systemd/system/systemd-logind.service /etc/systemd/system/multi-user.target.wants/systemd-logind.service
fi

# 6. 反映
systemctl daemon-reload

# 7. Runtime ディレクトリ (ログイン時に自動生成されない場合への保険)
mkdir -p /run/user/1000
chown user:user /run/user/1000
chmod 700 /run/user/1000

echo "===== All Process Finished! ====="
echo "Check: id user -> $(id user)"
echo "Action: Type 'reboot' now."
