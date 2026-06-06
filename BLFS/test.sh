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

if swapon --show | grep -q /swapfile; then
    swapoff "/swapfile"
fi

dd if=/dev/zero of=/swapfile bs=1M count=12288
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

if ! grep -q  /swapfile /etc/fstab; then
    echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
fi



echo "===== COMPLETE ====="
