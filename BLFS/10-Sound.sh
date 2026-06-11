#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   10   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(
libogg
libvorbis
libsndfile
alsa-lib
alsa-utils
alsa-plugins
pipewire
wireplumber
pulseaudio
pavucontrol
rtkit
libcanberra

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

# systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service

cat << 'EOF' > /etc/asound.conf
pcm.!default {
    type pulse
    fallback "sysdefault"
}

ctl.!default {
    type pulse
}
EOF

if [ ! -f /etc/pulse/system.pa ]; then
    cp /etc/pulse/default.pa /etc/pulse/system.pa
fi

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

groupadd -fg 65 pulse

if ! getent passwd pulse >/dev/null; then
useradd -c "PulseAudio System Daemon" -d /var/run/pulse \
        -u 65 -g pulse -G audio,users -s /bin/false pulse
fi

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

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   10   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
