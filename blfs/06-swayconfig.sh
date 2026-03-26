#!/bin/bash
set -euo pipefail

# 1. ターゲットユーザーの設定
# LFS環境の一般ユーザー名を指定してください
TARGET_USER="yuzo"
TARGET_HOME="/home/$TARGET_USER"

echo "===== Configuring Sway for $TARGET_USER ====="

# 2. 設定ディレクトリの作成
mkdir -p "$TARGET_HOME/.config/sway"
mkdir -p "$TARGET_HOME/.config/waybar"
mkdir -p "/etc/sway/config.d"

# 3. Sway設定ファイルの作成
cat > "$TARGET_HOME/.config/sway/config" << 'EOF'
### Variables
set $mod Mod4
set $left h
set $down j
set $up k
set $right l
set $term foot
set $menu dmenu_path | wmenu | xargs swaymsg exec --

### Output configuration
# 解像度を1024x768に固定（QEMU環境等で安定します）
output * bg /usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png fill
output * resolution 1024x768

### Key bindings
bindsym $mod+Return exec $term
bindsym $mod+Shift+q kill
bindsym $mod+d exec wofi --show drun
floating_modifier $mod normal
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exec wlogout

# Focus move (Vim style)
bindsym $mod+$left focus left
bindsym $mod+$down focus down
bindsym $mod+$up focus up
bindsym $mod+$right focus right

# Move window (Vim style)
bindsym $mod+Shift+$left move left
bindsym $mod+Shift+$down move down
bindsym $mod+Shift+$up move up
bindsym $mod+Shift+$right move right

# Workspaces
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

# Layout
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

# Resize mode
mode "resize" {
    bindsym $left resize shrink width 10px
    bindsym $down resize grow height 10px
    bindsym $up resize shrink height 10px
    bindsym $right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Status Bar (Waybar)
# 日本語ロケールを明示的に指定して起動
exec LANG=ja_JP.UTF-8 waybar

### Input configuration
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

# 4. 所有権の変更
# rootで作成したファイルを一般ユーザーが読み書きできるようにします
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"

echo "===== Configuration Complete ====="
echo "You can now start sway as user '$TARGET_USER' using: sway"
