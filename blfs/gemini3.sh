#!/bin/bash
set -uo pipefail

echo "===== Sway & Session Environment ULTIMATE Setup ====="

# 1. ライブラリ不整合の強制修正
echo "Step 1: Fixing library links..."
ldconfig
if [ -f /usr/lib/libdbus-1.so.3.38.3 ]; then
    ln -sf libdbus-1.so.3.38.3 /usr/lib/libdbus-1.so.3
fi
ldconfig

# 2. D-Bus ユーザー/グループの完全再構築 (217/USERエラー対策)
echo "Step 2: Reconstructing dbus user/group..."
# 既存の残骸を一度リセットして確実に作成
userdel dbus 2>/dev/null || true
groupdel dbus 2>/dev/null || true
groupadd -g 81 dbus
useradd -c "System Message Bus" -d /run/dbus -u 81 -g 81 -s /bin/false dbus

# 一般ユーザー(user)の権限付与
for grp in video input render seat; do
    groupadd -f -r "$grp"
    usermod -aG "$grp" user
done

# 3. PAM 設定ファイルの新規作成と統合
echo "Step 3: Configuring PAM for systemd-logind..."
# 欠落していた system-session を作成
cat > /etc/pam.d/system-session << "EOF"
# Begin /etc/pam.d/system-session
session    required    pam_loginuid.so
session    optional    pam_systemd.so
session    required    pam_unix.so
# End /etc/pam.d/system-session
EOF

# system-auth にセッション設定が含まれていない場合は追記
if ! grep -q "pam_systemd.so" /etc/pam.d/system-auth; then
    cat >> /etc/pam.d/system-auth << "EOF"
session    required    pam_loginuid.so
session    optional    pam_systemd.so
session    required    pam_unix.so
EOF
fi

# 4. D-Bus / machine-id の確立
echo "Step 4: Setting up machine-id..."
mkdir -p /var/lib/dbus
dbus-uuidgen --ensure
dbus-uuidgen > /var/lib/dbus/machine-id
cp -f /var/lib/dbus/machine-id /etc/machine-id

# 5. seatd サービスユニット作成
echo "Step 5: Creating seatd service..."
cat > /etc/systemd/system/seatd.service << "EOF"
[Unit]
Description=Seat management daemon
[Service]
Type=simple
ExecStart=/usr/bin/seatd -g video
Restart=always
[Install]
WantedBy=multi-user.target
EOF

# 6. サービスの有効化と強制リンク
echo "Step 6: Enabling and starting services..."
mkdir -p /etc/systemd/system/multi-user.target.wants
mkdir -p /etc/systemd/system/sockets.target.wants

ln -sf /usr/lib/systemd/system/dbus.socket /etc/systemd/system/sockets.target.wants/dbus.socket
ln -sf /usr/lib/systemd/system/systemd-logind.service /etc/systemd/system/multi-user.target.wants/systemd-logind.service
ln -sf /etc/systemd/system/seatd.service /etc/systemd/system/multi-user.target.wants/seatd.service

systemctl daemon-reload
# D-Busをこの場で起動させてみる
systemctl start dbus.socket || echo "D-Bus socket failed, will fix on reboot"

# 7. Runtime ディレクトリ
mkdir -p /run/user/1000
chown user:user /run/user/1000
chmod 700 /run/user/1000

echo "===== Setup Finished! ====="
echo "Check: id dbus -> $(id dbus)"
echo "Action: Please run 'reboot' now."
