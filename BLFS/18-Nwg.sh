#!/bin/bash
set -euo pipefail

source ./functions.sh


echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   18 START                          =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "



scripts=(
gtk-layer-shell
nwg-bar
go

cliphist
clipman
nwg-clipman

i3ipc
python-xlib
six
nwg-displays
nwg-drawer
nwg-look
nwg-wrapper


)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

mkdir -p /home/$TARGET_USER/.config/sway

cp -r /etc/sway/* /home/$TARGET_USER/.config/sway/

chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.config/sway

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   18   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
