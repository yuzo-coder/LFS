#!/bin/bash
set -euo pipefail

echo "===== /usr/bin/start-sway ====="

cat << 'EOF' > /usr/bin/start-sway
#!/bin/bash
# 1. ユーザー環境変数のクリーンアップと設定
# Wayland関連の環境変数を定義
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway
export MOZ_ENABLE_WAYLAND=1
export _JAVA_AWT_WM_NONREPARENTING=1

# 日本語入力 (Fcitx5) 関連の設定
export XMODIFIERS="@im=fcitx"
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx

# 2. XDG_RUNTIME_DIR の確認（LFSでは重要）
# これがないとWaybarやFcitx5がソケットを作れずエラーになります
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR=/run/user/$(id -u)
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 700 "$XDG_RUNTIME_DIR"
        chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR"
    fi
fi

# 3. GLibスキーマのキャッシュ更新（念のための自動化）
# 起動時の「スキーマがありません」エラーを未然に防ぎます
if [ -d /usr/share/glib-2.0/schemas ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas
fi

dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway

# tty1でsway実行
export XDG_vt=1

# 4. SwayをD-Busセッション経由で起動
# これにより Waybar, Fcitx5, Portal が互いに通信可能になります
exec dbus-run-session sway > /home/user/sway.log 2>&1
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

### Key bindings
    bindsym $mod+Return exec $term > /tmp/foot.log 2>&1
    bindsym $mod+Shift+q kill
    bindsym $mod+d exec wofi --show drun
    floating_modifier $mod normal
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+e exec wlogout

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

exec_always fcitx5 -d --replace

exec pipewire
exec wireplumber

exec dbus-update-activation-environment --all

include /etc/sway/config.d/*

EOF

echo "===== /etc/xdg/waybar/config ====="

# 既存のディレクトリ・ファイルを整理
mkdir -p /etc/xdg/waybar
rm -f /etc/xdg/waybar/config

# 新しい設定を書き出し
cat << 'EOF' > /etc/xdg/waybar/config
// -*- mode: jsonc -*-
{
    "layer": "top",
    "position": "top", 
    "height": 30,
    "spacing": 4,
    "modules-left": [
        "sway/workspaces",
        "custom/foot",
        "custom/pcmanfm",
        "custom/firefox",
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
    "custom/foot": {
        "format": "", // ここに  (f120) を入力
        "on-click": "foot",
        "tooltip": false
    },
    "custom/pcmanfm": {
        "format": "", //  (f07b) がフォルダアイコンです
        "on-click": "pcmanfm",
        "tooltip": true,
        "tooltip-format": "File Manager"
    },
    "custom/firefox": {
        "format": "", // Font Awesomeなどのアイコンフォントが必要
        "on-click": "/usr/bin/start-firefox",
        "tooltip": false
    },
    "sway/mode": {
        "format": "<span style=\"italic\">{}</span>"
    },
    "custom/fcitx5": {
        "exec": "fcitx5-remote -n | sed -e 's/anthy/ あ/' -e 's/keyboard-us/ A/'", 
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
        "on-click": "wlogout"
    }
}

EOF


echo "===== /etc/xdg/waybar/style.css ====="

# 既存のファイルを削除
rm -f /etc/xdg/waybar/style.css

# 新しいスタイルシートを書き出し
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

# 既存のディレクトリ作成とファイル削除
mkdir -p /etc/foot
rm -f /etc/foot/foot.ini

# 新しい設定を書き出し
cat << 'EOF' > /etc/xdg/foot/foot.ini
# /etc/xdg/foot/foot.ini
[main]
# fc-list で表示された名前と完全に一致させる必要があります
font=JetBrainsMono Nerd Font:size=11, Noto Sans CJK JP:style=Regular:size=11
EOF

# 既存のディレクトリ作成とファイル削除
mkdir -p /etc/wlogout
rm -f /etc/wlogout/style.css

# 新しいスタイルシートを書き出し
cat << 'EOF' > /etc/wlogout/style.css
window {
    background-color: rgba(0, 0, 0, 0.5);
}

/* 全ボタン共通のスタイル */
button {
    border: 2px solid #ffffff;
    border-radius: 20px;
    margin: 10px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 25%;
    background-color: rgba(255, 255, 255, 0.1);

    /* 文字の設定 */
    color: #ffffff;
    font-size: 20px;
    font-weight: bold;
    text-shadow: 0 0 5px rgba(0,0,0,1);
    
    /* 文字の位置をアイコンの下側に調整 */
    background-origin: padding-box;
    background-clip: padding-box;
    padding-top: 100px;
}

/* ホバー時の設定 */
button:focus, button:active, button:hover {
    background-color: rgba(255, 255, 255, 0.3);
    outline-style: none;
}

/* 各ボタンのアイコン画像定義 */
#lock {
    background-image: image(url("/usr/share/wlogout/icons/lock.png"), url("/usr/local/share/wlogout/icons/lock.png"));
}
#logout {
    background-image: image(url("/usr/share/wlogout/icons/logout.png"), url("/usr/local/share/wlogout/icons/logout.png"));
}
#suspend {
    background-image: image(url("/usr/share/wlogout/icons/suspend.png"), url("/usr/local/share/wlogout/icons/suspend.png"));
}
#hibernate {
    background-image: image(url("/usr/share/wlogout/icons/hibernate.png"), url("/usr/local/share/wlogout/icons/hibernate.png"));
}
#shutdown {
    background-image: image(url("/usr/share/wlogout/icons/shutdown.png"), url("/usr/local/share/wlogout/icons/shutdown.png"));
}
#reboot {
    background-image: image(url("/usr/share/wlogout/icons/reboot.png"), url("/usr/local/share/wlogout/icons/reboot.png"));
}
EOF


# 既存のディレクトリ作成とファイル削除
mkdir -p /etc/wofi
rm -f /etc/wofi/config

# 新しい設定を書き出し
cat << 'EOF' > /etc/wofi/config
show=drun
width=400
height=500
always_parse_args=true
show_all=false
print_command=true
insensitive=true
prompt=Search Apps...
EOF


# 既存のファイルを削除
rm -f /etc/wofi/style.css

# 新しいスタイルシートを書き出し
cat << 'EOF' > /etc/wofi/style.css
window {
    margin: 5px;
    border: 2px solid #ffffff;
    background-color: rgba(30, 30, 30, 0.8); /* 半透明グレー */
    border-radius: 15px;
    font-family: "Noto Sans Mono CJK JP";
}

#input {
    margin: 10px;
    border: none;
    border-radius: 10px;
    background-color: rgba(255, 255, 255, 0.1);
    color: white;
}

#inner-box {
    margin: 5px;
}

#entry:selected {
    background-color: rgba(255, 255, 255, 0.2);
    border-radius: 10px;
}

#text {
    margin: 5px;
    color: white;
}
EOF

# 既存のディレクトリ作成とファイル削除
mkdir -p /etc/yazi
rm -f /etc/yazi/yazi.toml

# 新しい設定を書き出し
cat << 'EOF' > /etc/yazi/yazi.toml
# A TOML linter such as https://taplo.tamasfe.dev/ can use this schema to validate your config.
# If you encounter any issues, please make an issue at https://github.com/yazi-rs/schemas.
"$schema" = "https://yazi-rs.github.io/schemas/yazi.json"

[mgr]
ratio          = [ 1, 4, 3 ]
sort_by        = "alphabetical"
sort_sensitive = false
sort_reverse   = false
sort_dir_first = true
sort_translit  = false
sort_fallback  = "alphabetical"
linemode       = "none"
show_hidden    = false
show_symlink   = true
scrolloff      = 5
mouse_events   = [ "click", "scroll" ]

[preview]
wrap            = "no"
tab_size        = 2
max_width       = 600
max_height      = 900
cache_dir       = ""
image_delay     = 30
image_filter    = "triangle"
image_quality   = 75
ueberzug_scale  = 1
ueberzug_offset = [ 0, 0, 0, 0 ]
preview_client = "ueberzugpp"

[opener]
edit = [
	{ run = '${EDITOR:-vi} %s', desc = "$EDITOR",     for = "unix", block = true },
	{ run = 'code %s',          desc = "code",          for = "windows", orphan = true },
	{ run = 'code -w %s',       desc = "code (block)", for = "windows", block = true },
]
play = [
	{ run = 'xdg-open %s1',    desc = "Play", for = "linux", orphan = true },
	{ run = 'open %s',          desc = "Play", for = "macos" },
	{ run = 'start "" %s1',    desc = "Play", for = "windows", orphan = true },
	{ run = 'termux-open %s1', desc = "Play", for = "android" },
	{ run = "mediainfo %s1; echo 'Press enter to exit'; read _", block = true, desc = "Show media info", for = "unix" },
	{ run = "mediainfo %s1 & pause", block = true, desc = "Show media info", for = "windows" },
]
open = [
	{ run = 'xdg-open %s1',    desc = "Open", for = "linux" },
	{ run = 'open %s',          desc = "Open", for = "macos" },
	{ run = 'start "" %s1',    desc = "Open", for = "windows", orphan = true },
	{ run = 'termux-open %s1', desc = "Open", for = "android" },
]
reveal = [
	{ run = 'xdg-open %d1',          desc = "Reveal", for = "linux" },
	{ run = 'open -R %s1',           desc = "Reveal", for = "macos" },
	{ run = 'explorer /select,%s1', desc = "Reveal", for = "windows", orphan = true },
	{ run = 'termux-open %d1',      desc = "Reveal", for = "android" },
	{ run = "clear; exiftool %s1; echo 'Press enter to exit'; read _", desc = "Show EXIF", for = "unix", block = true },
]
extract = [
	{ run = 'ya pub extract --list %s', desc = "Extract here" },
]
download = [
	{ run = 'ya emit download --open %S', desc = "Download and open" },
	{ run = 'ya emit download %S',        desc = "Download" },
]

[open]
rules = [
	# Folder
	{ url = "*/", use = [ "edit", "open", "reveal" ] },
	# Text
	{ mime = "text/*", use = [ "edit", "reveal" ] },
	# Image
	{ mime = "image/*", use = [ "open", "reveal" ] },
	# Media
	{ mime = "{audio,video}/*", use = [ "play", "reveal" ] },
	# Code
	{ mime = "application/{json,ndjson,javascript,wine-extension-ini}", use = [ "edit", "reveal" ] },
	# Archive
	{ mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", use = [ "extract", "reveal" ] },
	# Empty file
	{ mime = "inode/empty", use = [ "edit", "reveal" ] },
	# Virtual file system
	{ mime = "vfs/{absent,stale}", use = "download" },
	# Fallback
	{ url = "*", use = [ "open", "reveal" ] },
]

[tasks]
file_workers     = 3
plugin_workers   = 5
fetch_workers    = 5
preload_workers  = 2
process_workers  = 5
bizarre_retry    = 3
image_alloc      = 536870912  # 512MB
image_bound      = [ 10000, 10000 ]
suppress_preload = false

[plugin]
fetchers = [
	# Mimetype
	{ id = "mime", url = "*/",          run = "mime.dir", prio = "high" },
	{ id = "mime", url = "local://*",  run = "mime.local", prio = "high" },
	{ id = "mime", url = "remote://*", run = "mime.remote", prio = "high" },
]
spotters = [
	# Multi-file
	{ mime = "multi/*", run = "multi" },
	# Folder
	{ url = "*/", run = "folder" },
	# Code
	{ mime = "text/*", run = "code" },
	{ mime = "application/{mbox,javascript,wine-extension-ini}", run = "code" },
	# Image
	{ mime = "image/{avif,hei?,jxl}", run = "magick" },
	{ mime = "image/svg+xml", run = "svg" },
	{ mime = "image/*", run = "image" },
	# Video
	{ mime = "video/*", run = "video" },
	# Virtual file system
	{ mime = "vfs/*", run = "vfs" },
	# Error
	{ mime = "null/*", run = "null" },
	# Fallback
	{ url = "*", run = "file" },
]
preloaders = [
	# Image
	{ mime = "image/{avif,hei?,jxl}", run = "magick" },
	{ mime = "image/svg+xml", run = "svg" },
	{ mime = "image/*", run = "image" },
	# Video
	{ mime = "video/*", run = "video" },
	# PDF
	{ mime = "application/pdf", run = "pdf" },
	# Font
	{ mime = "font/*", run = "font" },
	{ mime = "application/ms-opentype", run = "font" },
]
previewers = [
	{ url = "*/", run = "folder" },
	# Code
	{ mime = "text/*", run = "code" },
	{ mime = "application/{mbox,javascript,wine-extension-ini}", run = "code" },
	# JSON
	{ mime = "application/{json,ndjson}", run = "json" },
	# Image
	{ mime = "image/{avif,hei?,jxl}", run = "magick" },
	{ mime = "image/svg+xml", run = "svg" },
	{ mime = "image/*", run = "image" },
	# Video
	{ mime = "video/*", run = "video" },
	# PDF
	{ mime = "application/pdf", run = "pdf" },
	# Archive
	{ mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", run = "archive" },
	{ mime = "application/{debian*-package,redhat-package-manager,rpm,android.package-archive}", run = "archive" },
	{ url = "*.{AppImage,appimage}", run = "archive" },
	# Virtual Disk / Disk Image
	{ mime = "application/{iso9660-image,qemu-disk,ms-wim,apple-diskimage}", run = "archive" },
	{ mime = "application/virtualbox-{vhd,vhdx}", run = "archive" },
	{ url = "*.{img,fat,ext,ext2,ext3,ext4,squashfs,ntfs,hfs,hfsx}", run = "archive" },
	# Font
	{ mime = "font/*", run = "font" },
	{ mime = "application/ms-opentype", run = "font" },
	# Empty file
	{ mime = "inode/empty", run = "empty" },
	# Virtual file system
	{ mime = "vfs/*", run = "vfs" },
	# Error
	{ mime = "null/*", run = "null" },
	# Fallback
	{ url = "*", run = "file" },
]

[input]
cursor_blink = false

# cd
cd_title  = "Change directory:"
cd_origin = "top-center"
cd_offset = [ 0, 2, 50, 3 ]

# create
create_title  = [ "Create:", "Create (dir):" ]
create_origin = "top-center"
create_offset = [ 0, 2, 50, 3 ]

# rename
rename_title  = "Rename:"
rename_origin = "hovered"
rename_offset = [ 0, 1, 50, 3 ]

# filter
filter_title  = "Filter:"
filter_origin = "top-center"
filter_offset = [ 0, 2, 50, 3 ]

# find
find_title  = [ "Find next:", "Find previous:" ]
find_origin = "top-center"
find_offset = [ 0, 2, 50, 3 ]

# search
search_title  = "Search via {n}:"
search_origin = "top-center"
search_offset = [ 0, 2, 50, 3 ]

# shell
shell_title  = [ "Shell:", "Shell (block):" ]
shell_origin = "top-center"
shell_offset = [ 0, 2, 50, 3 ]

[confirm]
# trash
trash_title 	= "Trash {n} selected file{s}?"
trash_origin	= "center"
trash_offset	= [ 0, 0, 70, 20 ]

# delete
delete_title 	= "Permanently delete {n} selected file{s}?"
delete_origin	= "center"
delete_offset	= [ 0, 0, 70, 20 ]

# overwrite
overwrite_title  = "Overwrite file?"
overwrite_body   = "Will overwrite the following file:"
overwrite_origin = "center"
overwrite_offset = [ 0, 0, 50, 15 ]

# quit
quit_title  = "Quit?"
quit_body   = "There are unfinished tasks, quit anyway?\n(Open task manager with default key 'w')"
quit_origin = "center"
quit_offset = [ 0, 0, 50, 15 ]

[pick]
open_title  = "Open with:"
open_origin = "hovered"
open_offset = [ 0, 1, 50, 7 ]

[which]
sort_by      	 = "none"
sort_sensitive = false
sort_reverse 	 = false
sort_translit  = false
EOF

echo "===== /usr/bin/start-firefox ====="
cat << 'EOF' > /usr/bin/start-firefox

#!/bin/bash

# pgrepでチェック（/usr/local/bin にあるのでフルパスかパスを確認）
if ! pgrep -x "fcitx5" > /dev/null; then
    /usr/bin/fcitx5 -d
    sleep 0.5
fi

# --- Wayland / Fcitx5 連携のコア設定 ---
export MOZ_ENABLE_WAYLAND=1
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"

# ALSAを直接使う指定
export MOZ_ALSA_DEVICE=default
# 念のため、サウンドバックエンドを強制
export MOZ_PULSE_DISABLE=1

# --- サンドボックスとGPU偽装（既存） ---
# export MOZ_SANDBOX_ALLOW_SHM=1
# export MOZ_SANDBOX_ALLOW_SYSV_SHM=1
#export MOZ_GECKO_SANDBOX_ALLOW_PATH="/dev/dri/:/dev/shm/"
# export MOZ_GFX_SPOOF_GL_VENDOR="NVIDIA Corporation"
# export MOZ_GFX_SPOOF_GL_RENDERER="NVIDIA GeForce RTX 2070/PCIe/SSE2"

# 環境変数でサンドボックスを無効化して起動
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_DISABLE_RDD_SANDBOX=1
export LD_LIBRARY_PATH=/usr/lib
export MOZ_WEBRENDER=0
export MOZ_ACCEL_HWA=0

# Firefox 起動
firefox > /home/user/firefox.log 2>&1 &
# firefox --safe-mode
EOF

chmod +x /usr/bin/start-firefox

echo "===== /etc/xdg/fcitx5/profile ====="
cat << 'EOF' > /etc/xdg/fcitx5

[Groups/0]
Name=Default
Default Layout=jp
# keyboard-jp を先頭（または anthy の前）に置く
DefaultIMList=keyboard-jp,anthy

[Groups/0/Items/0]
Name=keyboard-jp
Layout=

[Groups/0/Items/1]
Name=anthy
Layout=

[GroupOrder]
0=Default
EOF

echo "===== SWAY CONFIG COMPLETE ====="

