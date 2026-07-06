#!/usr/bin/env bash

CONFIG="$HOME/.config/rofi/config.rasi"

rofi \
    -filebrowser-cancel-returns-1 true \
    -filebrowser-directory ~/rice/wallpapers/ \
    -filebrowser-command ~/scripts/set_wallpaper.sh \
    -show filebrowser \
    -theme ${CONFIG}
