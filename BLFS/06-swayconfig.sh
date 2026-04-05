#!/bin/bash
set -euo pipefail

# 1. ユーザー設定
TARGET_USER="user"
TARGET_HOME="/home/$TARGET_USER"

echo "===== Configuring Sway & All Tools for $TARGET_USER ====="

# 2. ディレクトリ作成 (パスの整合性を修正)
mkdir -p "$TARGET_HOME/.config"/{sway,waybar,foot,wlogout,wofi,yazi}
mkdir -p "/etc/sway/config.d"

# --- 3. Sway Config (標準的な構成) ---
cat > "$TARGET_HOME/.config/sway/config" << 'EOF'
set $mod Mod4
set $left h
set $down j
set $up k
set $right l
set $term foot
set $menu dmenu_path | wmenu | xargs swaymsg exec --

output * bg /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
output * resolution 1024x768

bindsym $mod+Return exec $term
bindsym $mod+Shift+q kill
bindsym $mod+d exec wofi --show drun
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exec wlogout

# Focus/Move (Vim style)
bindsym $mod+$left focus left
bindsym $mod+$down focus down
bindsym $mod+$up focus up
bindsym $mod+$right focus right
bindsym $mod+Shift+$left move left
bindsym $mod+Shift+$down move down
bindsym $mod+Shift+$up move up
bindsym $mod+Shift+$right move right

# Workspaces 1-10
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9
bindsym $mod+Shift+0 move container to workspace number 10

bindsym $mod+b splith
bindsym $mod+v splitv
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent
bindsym $mod+Shift+minus move scratchpad
bindsym $mod+minus scratchpad show

mode "resize" {
    bindsym $left resize shrink width 10px
    bindsym $down resize grow height 10px
    bindsym $up resize shrink height 10px
    bindsym $right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

exec LANG=ja_JP.UTF-8 waybar

input "type:keyboard" { xkb_layout jp }
input "type:mouse" { accel_profile "flat"; pointer_accel 0 }
include /etc/sway/config.d/*
EOF

# --- 4. foot Config (パス修正: ~/.config/foot/foot.ini) ---
cat > "$TARGET_HOME/.config/foot/foot.ini" << 'EOF'
[main]
font=JetBrainsMono Nerd Font:size=11, Noto Sans CJK JP:size=11
[colors]
alpha=0.8
EOF

# --- 5. Waybar Config (パス修正: ~/.config/waybar/config.json) ---
cat > "$TARGET_HOME/.config/waybar/config.json" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["sway/workspaces", "sway/mode", "sway/scratchpad"],
    "modules-center": ["sway/window"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "clock", "tray", "custom/power"],
    "sway/mode": { "format": "<span style=\"italic\">{}</span>" },
    "clock": { "format": "{:%H:%M:%S}", "interval": 1 },
    "cpu": { "format": "CPU: {usage}% " },
    "memory": { "format": "MEM: {}% " },
    "custom/power": { "format": " ", "on-click": "wlogout" }
}
EOF

# --- 6. Waybar Style ---
cat > "$TARGET_HOME/.config/waybar/style.css" << 'EOF'
* { font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK JP", sans-serif; font-size: 13px; }
window#waybar { background-color: rgba(30, 30, 46, 0.7); color: #cdd6f4; }
#cpu, #memory, #clock, #pulseaudio, #network, #tray, #custom-power {
    padding: 0 12px; margin: 4px 2px; border-radius: 8px; background-color: #313244;
}
#custom-power { color: #f38ba8; }
EOF

# --- 7. wlogout Style (アイコンパスに注意) ---
cat > "$TARGET_HOME/.config/wlogout/style.css" << 'EOF'
window { background-color: rgba(0, 0, 0, 0.5); }
button {
    color: #ffffff; font-size: 20px; font-weight: bold;
    background-repeat: no-repeat; background-position: center; background-size: 25%;
    background-color: rgba(255, 255, 255, 0.1);
    border: 2px solid #ffffff; border-radius: 20px; margin: 10px;
    padding-top: 100px;
}
button:hover { background-color: rgba(255, 255, 255, 0.3); }
#lock { background-image: image(url("/usr/share/wlogout/icons/lock.png"), url("/usr/local/share/wlogout/icons/lock.png")); }
#logout { background-image: image(url("/usr/share/wlogout/icons/logout.png"), url("/usr/local/share/wlogout/icons/logout.png")); }
#shutdown { background-image: image(url("/usr/share/wlogout/icons/shutdown.png"), url("/usr/local/share/wlogout/icons/shutdown.png")); }
#reboot { background-image: image(url("/usr/share/wlogout/icons/reboot.png"), url("/usr/local/share/wlogout/icons/reboot.png")); }
EOF

# --- 8. wofi Config & Style ---
cat > "$TARGET_HOME/.config/wofi/config" << 'EOF'
show=drun
width=400
height=500
prompt=Search Apps...
EOF

cat > "$TARGET_HOME/.config/wofi/style.css" << 'EOF'
window { background-color: rgba(30, 30, 30, 0.8); border-radius: 15px; color: white; border: 2px solid #ffffff; }
#input { margin: 10px; border-radius: 10px; background-color: rgba(255, 255, 255, 0.1); color: white; }
#entry:selected { background-color: rgba(255, 255, 255, 0.2); }
EOF

# --- 9. Yazi Config (提示されたフルセットを適用) ---
cat > "$TARGET_HOME/.config/yazi/yazi.toml" << 'EOF'
"$schema" = "https://yazi-rs.github.io/schemas/yazi.json"
[mgr]
ratio = [ 1, 4, 3 ]
sort_by = "alphabetical"
sort_dir_first = true
show_symlink = true
mouse_events = [ "click", "scroll" ]

[preview]
tab_size = 2
max_width = 600
max_height = 900
image_delay = 30
preview_client = "ueberzugpp"

[opener]
edit = [
    { run = '${EDITOR:-vi} "$@"', desc = "$EDITOR", block = true, for = "unix" },
]
play = [
    { run = 'xdg-open "$@"', desc = "Play", orphan = true, for = "linux" },
]
open = [
    { run = 'xdg-open "$@"', desc = "Open", for = "linux" },
]

[open]
rules = [
    { url = "*/", use = [ "edit", "open" ] },
    { mime = "text/*", use = [ "edit" ] },
    { mime = "image/*", use = [ "open" ] },
    { mime = "{audio,video}/*", use = [ "play" ] },
    { url = "*", use = [ "open" ] },
]
EOF

# --- 10. 仕上げ: 所有権の一括変更 ---
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

echo "===== Configuration Complete for $TARGET_USER ====="
