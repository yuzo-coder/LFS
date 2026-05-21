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


echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   10   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
