#!/bin/bash
set -euo pipefail

source ./functions.sh

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   17   START                        =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "

scripts=(

xwayland
wlroots
sway
swaybg
Waybar
wofi
wlogout
wl-clipboard
foot

)

for pkg in "${scripts[@]}"; do
    echo "========= Building $pkg =========="
    cd "$ROOT_DIR"
    source "./scripts/$pkg"
done

cat << 'EOF' > /usr/bin/start-sway
#!/bin/bash

# 1. ユーザー環境変数の設定
export XDG_CURRENT_DESKTOP=sway
export MOZ_ENABLE_WAYLAND=1
export WLR_NO_HARDWARE_CURSORS=1

# export WLR_RENDERER_ALLOW_SOFTWARE=1

export WLR_RENDERER=pixman

export WLR_SCENE_DISABLE_DIRECT_SCANOUT=1

# 日本語入力 (Fcitx5)
export XMODIFIERS="@im=fcitx"

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway

# (A) 裏でSwayの起動を監視し、立ち上がったタイミングでPipeWireをスタートさせる部隊
(
    # Swayが画面を作り終えるのをほんの少しだけ待つ（安全策）
    sleep 1
    # ページャーなしで静かにサービスを起動
    systemctl --user start pipewire pipewire-pulse wireplumber >/dev/null 2>&1
) &

# 6. Sway の実行
# dbus-run-session を使って Sway を起動するのが最もクリーンです。
exec dbus-run-session sway > /tmp/sway.log 2>&1
EOF

chmod +x /usr/bin/start-sway

echo "===== /etc/sway/config ====="

# 既存のファイルを削除
rm -f /etc/sway/config

# $mod を Mod1 (Alt) に変更して再書き出し
cat << 'EOF' > /etc/sway/config
### Variables
# Mod1 is Alt, Mod4 is Super (Windows Key)
set $mod Mod1
set $left h
set $down j
set $up k
set $right l
set $term foot
set $menu dmenu_path | wmenu | xargs swaymsg exec --

### Output configuration
output * bg /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
output * resolution 1920x1080

exec dbus-update-activation-environment --all
exec systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK

### Key bindings
    bindsym $mod+Return exec $term > /tmp/foot.log 2>&1
    bindsym $mod+Shift+q kill
    bindsym $mod+d exec wofi --show drun
    floating_modifier $mod normal
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+e exec nwg-bar 

    # Moving around
    bindsym $mod+$left focus left
    bindsym $mod+$down focus down
    bindsym $mod+$up focus up
    bindsym $mod+$right focus right
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right

    # Move window
    bindsym $mod+Shift+$left move left
    bindsym $mod+Shift+$down move down
    bindsym $mod+Shift+$up move up
    bindsym $mod+Shift+$right move right
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right

    # Workspaces
    bindsym $mod+1 workspace number 1
    bindsym $mod+2 workspace number 2
    bindsym $mod+3 workspace number 3
    bindsym $mod+4 workspace number 4
    bindsym $mod+5 workspace number 5
    bindsym $mod+Shift+1 move container to workspace number 1
    bindsym $mod+Shift+2 move container to workspace number 2
    bindsym $mod+Shift+3 move container to workspace number 3
    bindsym $mod+Shift+4 move container to workspace number 4
    bindsym $mod+Shift+5 move container to workspace number 5

    # Layout stuff
    bindsym $mod+b splith
    bindsym $mod+v splitv
    bindsym $mod+s layout stacking
    bindsym $mod+w layout tabbed
    bindsym $mod+e layout toggle split
    bindsym $mod+f fullscreen
    bindsym $mod+Shift+space floating toggle
    bindsym $mod+space focus mode_toggle
    bindsym $mod+a focus parent

    # Scratchpad
    bindsym $mod+Shift+minus move scratchpad
    bindsym $mod+minus scratchpad show

# Resizing mode
mode "resize" {
    bindsym $left resize shrink width 10px
    bindsym $down resize grow height 10px
    bindsym $up resize shrink height 10px
    bindsym $right resize grow width 10px
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Execution & Input
exec LANG=ja_JP.UTF-8 waybar -c /etc/xdg/waybar/config > waybar.log 2>&1

input "type:keyboard" {
    xkb_layout jp
}

input "type:tablet" {
    map_to_output *
}

input "type:mouse" {
    accel_profile "flat"
    pointer_accel 0
}

# 1. Sway 自体のカーソル設定 (seatコマンドを使用)
# 全ての入力デバイス (*) に対して Adwaita テーマのサイズ 24 を適用
# seat * cursor_theme Adwaita 24

# 2. GTKアプリ (Waybar等) への通知
# 起動時に gsettings を使ってテーマを流し込みます
exec_always {
    gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
    gsettings set org.gnome.desktop.interface cursor-size 24
}

exec_always /usr/bin/pgrep -x fcitx5 > /dev/null || /usr/bin/fcitx5 -d

exec dbus-update-activation-environment --all

include /etc/sway/config.d/*
EOF



echo "===== /etc/xdg/waybar/config ====="

mkdir -p /etc/xdg/waybar

rm -f /etc/xdg/waybar/config

cat << 'EOF' > /etc/xdg/waybar/config
// -*- mode: jsonc -*-
{
    "layer": "top",
    "position": "top", 
    "height": 30,
    "spacing": 4,
    "modules-left": [
        "custom/menu",
		"custom/wofi",
        "sway/workspaces",
        "sway/window",
        "custom/foot",
        "custom/pcmanfm",
        "custom/yazi",
        "custom/firefox",
        "custom/gimp",
        "custom/gedit",
        "custom/celluloid",
        "sway/mode",
        "sway/scratchpad"
    ],
    "modules-center": [
        "sway/window"
    ],
    "modules-right": [
        "custom/fcitx5",
        "pulseaudio",
        "network",
        "cpu",
        "memory",
        "clock",
        "tray",
        "custom/power"
    ],

    // --- Modules configuration ---
    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}",
        "persistent-workspaces": {
            "1": [],
            "2": [],
            "3": [],
            "4": [],
            "5": []
        }
    },
    "custom/menu": {
        "format": "", //f135
        "on-click": "exec nwg-drawer",
        "tooltip": false
    },
	"custom/wofi": {
        "format": "\uf192",
        "on-click": "exec wofi --show drun -I",
        "tooltip": false
    },
    "sway/window": {
        "format": "{}",
        "max-length": 50,
        "tooltip": true
    },
    "custom/foot": {
        "format": "", // ここに  (f120) を入力
        "on-click": "foot",
        "tooltip": false
    },
    "custom/pcmanfm": {
        "format": "\uf07b", //  (f07b) がフォルダアイコンです
        "on-click": "pcmanfm",
        "tooltip": true,
        "tooltip-format": "File Manager"
    },
    "custom/yazi": {
    	"format": "\uf0e7",
    	"on-click": "foot yazi",
    	"tooltip": false
    },
    "custom/firefox": {
        "format": "\uf269", // Font Awesomeなどのアイコンフォントが必要
        "on-click": "/usr/bin/start-firefox",
        "tooltip": false
    },
    "custom/gimp": {
        "format": "\uf1fc",
        "on-click": "gimp",
        "tooltip-format": "GIMP Image Editor",
        "tooltip": true
    },
    "custom/gedit": {
        "format": "\uf044", // または 
        "on-click": "gedit",
        "tooltip-format": "gedit Text Editor",
        "tooltip": true
    },
    "custom/celluloid": {
        "format": "\uf008", // または 
        "on-click": "celluloid",
        "tooltip-format": "Celluloid Video Player",
        "tooltip": true
    },
    "sway/mode": {
        "format": "<span style=\"italic\">{}</span>"
    },
    "custom/fcitx5": {
        "exec": "fcitx5-remote -n | sed -e 's/anthy/ あ/' -e 's/keyboard-jp/ A/'", 
        "interval": 1,
        "format": "{}",
    }, 
    "sway/scratchpad": {
        "format": "{icon} {count}",
        "show-empty": false,
        "format-icons": ["", ""],
        "tooltip": true,
        "tooltip-format": "{app}: {title}"
    },

    "tray": {
        "spacing": 10
    },

    "clock": {
        "format": "{:%H:%M:%S}",
        "format-alt": "{:%Y-%m-%d}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "interval": 1
    },

    "cpu": {
        "format": "CPU: {usage}% ",
        "tooltip": true,
        "interval": 2
    },

    "memory": {
        "format": "MEM: {}% ",
        "tooltip-format": "Used: {used:0.1f}G / Total: {total:0.1f}G",
        "interval": 2
    },

    "network": {
        "format-ethernet": "󰈀 {ipaddr}",
        "format-disconnected": "Disconnected ⚠",
        "tooltip-format": "{ifname} via {gwaddr} "
    },

    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-muted": "",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },

    "custom/power": {
        "format": "   ",
        "tooltip": false,
        "on-click": "nwg-bar"
    }
}

EOF


echo "===== /etc/xdg/waybar/style.css ====="

rm -f /etc/xdg/waybar/style.css

cat << 'EOF' > /etc/xdg/waybar/style.css
* {
    /* `otf-font-awesome` is required to be installed for icons */
    font-family: FontAwesome, Roboto, Helvetica, Arial, sans-serif;
    font-size: 13px;
}

window#waybar {
    background-color: rgba(43, 48, 59, 0.5);
    border-bottom: 3px solid rgba(100, 114, 125, 0.5);
    color: #ffffff;
    transition-property: background-color;
    transition-duration: .5s;
}

window#waybar.hidden {
    opacity: 0.2;
}

/*
window#waybar.empty {
    background-color: transparent;
}
window#waybar.solo {
    background-color: #FFFFFF;
}
*/

window#waybar.termite {
    background-color: #3F3F3F;
}

window#waybar.chromium {
    background-color: #000000;
    border: none;
}

button {
    /* Use box-shadow instead of border so the text isn't offset */
    box-shadow: inset 0 -3px transparent;
    /* Avoid rounded borders under each button name */
    border: none;
    border-radius: 0;
}

/* https://github.com/Alexays/Waybar/wiki/FAQ#the-workspace-buttons-have-a-strange-hover-effect */
button:hover {
    background: inherit;
    box-shadow: inset 0 -3px #ffffff;
}

/* you can set a style on hover for any module like this */
#pulseaudio:hover {
    background-color: #a37800;
}

#workspaces button {
    padding: 0 5px;
    background-color: transparent;
    color: #ffffff;
}

#workspaces button:hover {
    background: rgba(0, 0, 0, 0.2);
    box-shadow: inherit;
    text-shadow: inherit;
}

#workspaces button.focused {
    background-color: #64727D;
    box-shadow: inset 0 -3px #ffffff;
}

#workspaces button.urgent {
    background-color: #eb4d4b;
}

#mode {
    background-color: #64727D;
    box-shadow: inset 0 -3px #ffffff;
}

#clock,
#battery,
#cpu,
#memory,
#disk,
#temperature,
#backlight,
#network,
#pulseaudio,
#wireplumber,
#custom-media,
#tray,
#mode,
#idle_inhibitor,
#scratchpad,
#power-profiles-daemon,
#mpd {
    padding: 0 10px;
    color: #ffffff;
}

#window,
#workspaces {
    margin: 0 4px;
}

/* If workspaces is the leftmost module, omit left margin */
.modules-left > widget:first-child > #workspaces {
    margin-left: 0;
}

/* If workspaces is the rightmost module, omit right margin */
.modules-right > widget:last-child > #workspaces {
    margin-right: 0;
}

/* 1. アプリケーションメニューボタン (custom/menu) */
#custom-menu {
    background-color: #274a78;          
    color: #f3f3f2;                     
    font-size: 16px;                    /* アイコンがはっきり見えるサイズ */
    font-weight: bold;
    padding: 0 12px;                    /* 左右の絶妙な余白 */
    margin: 4px 2px 4px 6px;            /* バーの内側での位置調整 */
    border: 1px solid rgba(255, 255, 255, 0.4); /* うっすら白い外枠 */
    border-radius: 6px;                 /* 少し角を丸めてモダンに */
    transition: all 0.15s ease-in-out;
}

/* メニューボタンにマウスを乗せたとき */
#custom-menu:hover {
    background-color: #165e83;          /* 背景を白に反転 */
    color: #ffffff;                     /* アイコンを黒に反転 */
    border-color: #ffffff;
}

/* 2. アクティブウィンドウ名表示 (sway/window) */
#window {
    background-color: rgba(15, 15, 15, 0.75); /* タイトル背景は少し透過した黒 */
    color: #ffffff;                     /* 文字色ははっきりとした白 */
    font-weight: bold;                  /* 太字で視認性アップ */
    font-size: 13px;
    padding: 0 15px;                    /* 文字の左右に余裕を持たせる */
    margin: 4px 4px;
    border: 1px solid rgba(255, 255, 255, 0.2); /* 控えめな白い枠線 */
    border-radius: 6px;
}

/* 現在開いているウィンドウがない（デスクトップが空の）ときの設定 */
#window.empty {
    background-color: transparent;      /* 背景を透明に */
    border: none;                       /* 枠線も消してスッキリ */
}

#custom-foot {
    font-family: "FontAwesome", "Your-Main-Font"; /* ここでフォントを指定 */
    font-size: 16px;
    color: #8ae234; /* footのイメージに近い緑色 */
    padding: 0 12px;
}

#custom-foot:hover {
    background: rgba(255, 255, 255, 0.1);
}

#fcitx5 {
    padding: 0 10px;
    color: #ffffff;
    background-color: #383c4a;
}

#custom-pcmanfm {
    font-family: "FontAwesome";
    font-size: 16px;
    color: #e9b96e; /* フォルダっぽい落ち着いた黄色 */
    padding: 0 12px;
}

#custom-pcmanfm:hover {
    background: rgba(255, 255, 255, 0.1);
    color: #fce94f; /* ホバー時に明るくする */
}

#custom-yazi {
    font-family: "FontAwesome";
    font-size: 16px;
    color: #ffff00;
    padding: 0 12px;
    transition: all 0.3s ease; /* ホバー時の動きを滑らかに */
}

#custom-yazi:hover {
    color: #ffffff;
    background-color: rgba(93, 93, 93, 0.3);
    /* yaziの「鋭さ」を出すために、下線を少し明るいグレーに */
    border-bottom: 2px solid #8c8c8c; 
}
#custom-firefox {
    color: #ff9500; /* Firefoxブランドのオレンジ色 */
    background-color: transparent;
    padding: 0 10px;
    margin: 0 4px;
    font-size: 18px; /* アイコンの大きさ */
    transition: all 0.3s ease; /* ホバー時のアニメーション */
}

#custom-firefox:hover {
    color: #ffb347; /* ホバー時に少し明るく */
    background-color: rgba(255, 255, 255, 0.1); /* ほんのり背景を明るく */
    border-radius: 4px;
}

#custom-gimp {
    font-family: "FontAwesome";
    font-size: 16px;
    color: #000000;
    padding: 0 12px;
}

#custom-gimp:hover {
    color: #ffffff;
    background-color: rgba(93, 93, 93, 0.3);
    border-bottom: 2px solid #5d5d5d;
}

#custom-gedit {
    font-family: "FontAwesome";
    font-size: 16px;
    color: #ffffff;
    padding: 0 12px;
}

#custom-gedit:hover {
    color: #82b1ff;
    background-color: rgba(74, 144, 217, 0.2);
    border-bottom: 2px solid #4a90d9;
}
#custom-celluloid {
    font-family: "FontAwesome";
    font-size: 16px;
    color: #e53935;
    padding: 0 12px;
}

#custom-celluloid:hover {
    color: #ff5252;
    background-color: rgba(229, 57, 53, 0.2);
    border-bottom: 2px solid #e53935;
}

#clock {
    background-color: transparent;
    color: #ffffff;
}

#battery {
    background-color: #ffffff;
    color: #000000;
}

#battery.charging, #battery.plugged {
    color: #ffffff;
    background-color: #26A65B;
}

@keyframes blink {
    to {
        background-color: #ffffff;
        color: #000000;
    }
}

/* Using steps() instead of linear as a timing function to limit cpu usage */
#battery.critical:not(.charging) {
    background-color: #f53c3c;
    color: #ffffff;
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: steps(12);
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#power-profiles-daemon {
    padding-right: 15px;
}

#power-profiles-daemon.performance {
    background-color: #f53c3c;
    color: #ffffff;
}

#power-profiles-daemon.balanced {
    background-color: #2980b9;
    color: #ffffff;
}

#power-profiles-daemon.power-saver {
    background-color: #2ecc71;
    color: #000000;
}

label:focus {
    background-color: #000000;
}

#cpu {
    /* background-color: #2ecc71; */
    background-color: transparent;
    transition-property: background-color;
    transition-duration: .5s;

    color: #FFFFFF;
}

#memory {
    background-color: transparent;

}

#disk {
    background-color: #964B00;
}

#backlight {
    background-color: #90b1b1;
}

#network {
    background-color: #2980b9;
}

#network.disconnected {
    background-color: #f53c3c;
}

#pulseaudio {
    background-color: #f1c40f;
    color: #000000;
}

#pulseaudio.muted {
    background-color: #90b1b1;
    color: #2a5c45;
}

#wireplumber {
    background-color: #fff0f5;
    color: #000000;
}

#wireplumber.muted {
    background-color: #f53c3c;
}

#custom-media {
    background-color: #66cc99;
    color: #2a5c45;
    min-width: 100px;
}

#custom-media.custom-spotify {
    background-color: #66cc99;
}

#custom-media.custom-vlc {
    background-color: #ffa000;
}

#temperature {
    background-color: #f0932b;
}

#temperature.critical {
    background-color: #eb4d4b;
}

#tray {
    background-color: #2980b9;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
    background-color: #eb4d4b;
}

#idle_inhibitor {
    background-color: #2d3436;
}

#idle_inhibitor.activated {
    background-color: #ecf0f1;
    color: #2d3436;
}

#mpd {
    background-color: #66cc99;
    color: #2a5c45;
}

#mpd.disconnected {
    background-color: #f53c3c;
}

#mpd.stopped {
    background-color: #90b1b1;
}

#mpd.paused {
    background-color: #51a37a;
}

#language {
    background: #00b093;
    color: #740864;
    padding: 0 5px;
    margin: 0 5px;
    min-width: 16px;
}

#keyboard-state {
    background: #97e1ad;
    color: #000000;
    padding: 0 0px;
    margin: 0 5px;
    min-width: 16px;
}

#keyboard-state > label {
    padding: 0 5px;
}

#keyboard-state > label.locked {
    background: rgba(0, 0, 0, 0.2);
}

#scratchpad {
    background: rgba(0, 0, 0, 0.2);
}

#scratchpad.empty {
	background-color: transparent;
}

#privacy {
    padding: 0;
}

#privacy-item {
    padding: 0 5px;
    color: white;
}

#privacy-item.screenshare {
    background-color: #cf5700;
}

#privacy-item.audio-in {
    background-color: #1ca000;
}

#privacy-item.audio-out {
    background-color: #0069d4;
}


EOF

echo "                                                         "
echo "========================================================="
echo "========================================================="
echo "==                   17   COMPLETE                     =="
echo "==                                                     =="
echo "========================================================="
echo "========================================================="
echo "                                                         "
