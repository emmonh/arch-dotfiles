#!/usr/bin/env bash
# scripts/set_wallpaper.sh
# Sets the wallpaper, generates the color palette with matugen, and reloads affected apps

set -e

WALLPAPER="$1"

if [ -z "$WALLPAPER" ]; then
    echo "Usage: set-wallpaper.sh /path/to/wallpaper.jpg"
    exit 1
fi

if [ ! -f "$WALLPAPER" ]; then
    echo "Error: file '$WALLPAPER' does not exist"
    exit 1
fi

echo "Generating palette with matugen..."
matugen image --source-color-index 0 "$WALLPAPER"

echo "Setting wallpaper..."
awww img --transition-type center --transition-pos 0,0 --transition-step 90 "$WALLPAPER"

echo "Reloading waybar..."
~/scripts/waybar_restart.sh

#echo "Reloading hyprland..."
#hyprctl reload

echo "Reloading kitty..."
for socket in /tmp/kitty-*; do
    kitty @ --to "unix:$socket" set-colors -a -c ~/.config/kitty/colors.conf 2>/dev/null || true
done

echo "Wallpaper and theme updated ✓"
