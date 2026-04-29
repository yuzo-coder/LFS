#!/bin/bash
set -euo pipefail

source ./functions.sh

scripts=(
    "oneTBB"
    "extra-cmake-modules"
    "libvips"
    "libsixel"
    "chafa"
    "gtk-layer-shell"
    "wl-clipboard"
    "wlr-randr"
    "wofi"
    "wlogout"
    "ueberzugpp"
    "yazi"
    "btop"
    "greetd"
    "gtkgreet"
)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

# greetd 用のユーザー・ディレクトリ設定
if ! id "greeter" &>/dev/null; then
    useradd -M -G video greeter
    usermod -aG seat,video,input greeter
fi

# /etc/systemd/system/greetd.service
cat > /etc/systemd/system/greetd.service << "EOF"
[Unit]
Description=Greeter daemon
After=systemd-user-sessions.service plymouth-quit-wait.service
After=getty@tty1.service
Conflicts=getty@tty1.service

[Service]
Type=simple
ExecStart=/usr/bin/greetd
IgnoreSIGPIPE=no
SendSIGHUP=yes
TimeoutStopSec=30s
KeyringMode=shared

[Install]
WantedBy=graphical.target
EOF

mkdir -p /etc/greetd

# /etc/greetd/config.toml
cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1
[default_session]
command = "gtkgreet -l -c sway"
user = "greeter"
EOF

# gtkgreet用の専用Sway設定 (ログイン画面用)
cat > /etc/greetd/sway-config <<EOF
input * xkb_layout "jp"
output * bg /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
exec "gtkgreet -l -c sway; swaymsg exit"
include /etc/sway/config.d/*
EOF

echo "===== ALL BUILD & CONFIG COMPLETED ====="
