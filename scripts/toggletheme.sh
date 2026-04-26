#!/usr/bin/env bash

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/theme_mode"
CURRENT="light"

if [[ -f "$STATE_FILE" ]]; then
    CURRENT=$(cat "$STATE_FILE")
fi

if [[ "$CURRENT" == "dark" ]]; then
    NEW="light"
else
    NEW="dark"
fi

echo "$NEW" > "$STATE_FILE"

# ---- ENV VARS ----
if [[ "$NEW" == "dark" ]]; then
    export GTK_THEME="Adwaita-dark"
    export QT_QPA_PLATFORMTHEME="qt5ct"
    export QT_STYLE_OVERRIDE="Fusion"
    export GTK_APPLICATION_PREFER_DARK_THEME=1
else
    export GTK_THEME="Adwaita"
    export QT_QPA_PLATFORMTHEME="qt5ct"
    export QT_STYLE_OVERRIDE="Fusion"
    export GTK_APPLICATION_PREFER_DARK_THEME=0
fi

# ---- GTK (GNOME/GTK3/GTK4 apps) ----
if command -v gsettings >/dev/null; then
    if [[ "$NEW" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    else
        gsettings set org.gnome.desktop.interface color-scheme 'default'
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
    fi
fi

# ---- KDE / Plasma ----
if command -v lookandfeeltool >/dev/null; then
    if [[ "$NEW" == "dark" ]]; then
        lookandfeeltool -a org.kde.breezedark.desktop
    else
        lookandfeeltool -a org.kde.breeze.desktop
    fi
fi

# ---- Qt (qt5ct / qt6ct) ----
QT_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/qt5ct/qt5ct.conf"
if [[ -f "$QT_CONF" ]]; then
    if [[ "$NEW" == "dark" ]]; then
        sed -i 's/^style=.*/style=Fusion/' "$QT_CONF"
        sed -i 's/^palette=.*/palette=dark/' "$QT_CONF"
    else
        sed -i 's/^style=.*/style=Fusion/' "$QT_CONF"
        sed -i 's/^palette=.*/palette=default/' "$QT_CONF"
    fi
fi

# ---- Waybar refresh ----
/bin/bash wbrestart.sh

# Optional notification
if command -v notify-send >/dev/null; then
    notify-send "Theme switched to $NEW"
fi
