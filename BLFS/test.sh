#!/bin/bash
set -euo pipefail

source ./functions.sh


echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                      START                          =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

if [ ! -f /etc/pulse/system.pa ]; then
    cp /etc/pulse/default.pa /etc/pulse/system.pa
fi

# システムモードでrootや他のユーザーが制限なく音を鳴らせるように設定を追記
cat >> /etc/pulse/system.pa << "EOF"
load-module module-native-protocol-unix auth-anonymous=1
EOF

cat > /lib/systemd/system/pulseaudio-system.service << "EOF"
[Unit]
Description=PulseAudio Sound System (System-wide)
After=sound.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStartPre=/usr/bin/mkdir -p /run/pulse
ExecStartPre=/usr/bin/chown -R pulse:pulse /run/pulse
ExecStart=/usr/bin/pulseaudio --system --realtime --disallow-exit --disable-shm --log-target=syslog -v
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# 1. pulse グループを作成 (GIDは空いているシステム用ID)
groupadd -fg 65 pulse

# 2. pulse ユーザーを作成 (UIDは同上、usersやaudioグループにも追加)

if ! getent passwd pulse >/dev/null; then
useradd -c "PulseAudio System Daemon" -d /var/run/pulse \
        -u 65 -g pulse -G audio,users -s /bin/false pulse
fi

# 3. ついでに、音声アクセス用グループ（pulse-access）も作成
groupadd -fg 66 pulse-access

if ! getent passwd pulse-access >/dev/null; then
useradd -c "PulseAudio System Access" -d /var/run/pulse \
        -u 66 -g pulse-access -s /bin/false pulse-access
fi


mkdir -p /var/run/pulse

chown -R pulse:pulse /var/run/pulse

systemctl daemon-reload

systemctl enable pulseaudio-system.service
systemctl start pulseaudio-system.service

cat >> /root/.bashrc << "EOF"
export PULSE_SERVER=unix:/var/run/pulse/native
EOF


echo "===== COMPLETE ====="
