#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   12   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(
libnl
libndp
mobile-broadband-provider-info

duktape
polkit
libgudev
libbytesize
libnvme
libsecret

NetworkManager
libnma
network-manager-applet

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

# polkit rule
cat > /etc/polkit-1/rules.d/10-enable-shutdown.rules << "EOF"
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.reboot" ||
         action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
         action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
         action.id == "org.freedesktop.login1.suspend" ||
         action.id == "org.freedesktop.login1.hibernate") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

systemctl daemon-reload

systemctl start polkit

systemctl enable polkit

systemctl start NetworkManager

systemctl enable NetworkManager

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   12   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
