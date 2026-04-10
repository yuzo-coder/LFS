#!/bin/bash
set -euo pipefail

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
output * resolution 1024x768

### Key bindings
    bindsym $mod+Return exec $term
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
exec LANG=ja_JP.UTF-8 waybar

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

include /etc/sway/config.d/*
EOF

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
        "sway/mode",
        "sway/scratchpad"
    ],
    "modules-center": [
        "sway/window"
    ],
    "modules-right": [
        "pulseaudio",
        "network",
        "cpu",
        "memory",
        "clock",
        "tray",
        "custom/power"
    ],

    // --- Modules configuration ---

    "sway/mode": {
        "format": "<span style=\"italic\">{}</span>"
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
        "format": " ",
        "tooltip": false,
        "on-click": "wlogout"
    }
}
EOF

# 既存のファイルを削除
rm -f /etc/xdg/waybar/style.css

# 新しいスタイルシートを書き出し
cat << 'EOF' > /etc/xdg/waybar/style.css
/* 全体のフォント設定（Nerd Fontを使用） */
* {
    font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK JP", sans-serif;
    font-size: 13px;
    border: none;
    border-radius: 0;
    min-height: 0;
}

/* バー全体の背景（半透明のダークグレー） */
window#waybar {
    background-color: rgba(30, 30, 46, 0.7); /* 透明度0.7 */
    color: #cdd6f4;
    transition-property: background-color;
    transition-duration: .5s;
    border-bottom: 2px solid rgba(255, 255, 255, 0.1);
}

/* ワークスペースボタン（現在の画面切り替え） */
#workspaces button {
    padding: 0 8px;
    color: #bac2de;
    background-color: transparent;
}

#workspaces button.focused {
    color: #89b4fa;
    background-color: rgba(137, 180, 250, 0.1);
    border-bottom: 2px solid #89b4fa;
}

#workspaces button:hover {
    background: rgba(0, 0, 0, 0.2);
    box-shadow: inherit;
    text-shadow: inherit;
}

/* 各モジュールの共通設定（角丸と余白） */
#cpu,
#memory,
#clock,
#pulseaudio,
#network,
#tray,
#custom-power {
    padding: 0 12px;
    margin: 4px 2px;
    border-radius: 8px;
    background-color: #313244;
}

/* CPU：使用率に応じて色を変える */
#cpu {
    color: #fab387; /* オレンジ系 */
}

/* メモリ：緑〜青系 */
#memory {
    color: #a6e3a1; /* グリーン系 */
}

/* 時計：白系でスッキリ */
#clock {
    color: #cdd6f4;
    font-weight: bold;
}

/* ネットワーク */
#network {
    color: #89dceb;
}

/* 音量 */
#pulseaudio {
    color: #f9e2af;
}

/* 電源ボタン（目立たせる） */
#custom-power {
    color: #f38ba8; /* レッド系 */
    margin-right: 8px;
}

/* トレイ（アプリアイコン） */
#tray {
    background-color: transparent;
}
EOF

# 既存のディレクトリ作成とファイル削除
mkdir -p /etc/foot
rm -f /etc/foot/foot.ini

# 新しい設定を書き出し
cat << 'EOF' > /etc/foot/foot.ini
# /etc/foot/foot.ini
[main]
font=JetBrainsMono Nerd Font:size=11, Noto Sans CJK JP:size=11

[colors]
alpha=0.8
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

echo "===== SWAY CONFIG COMPLETE ====="

