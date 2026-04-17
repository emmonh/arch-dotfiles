#!/bin/bash

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/theme_mode"

if [[ -f "$STATE_FILE" ]]; then
    CURRENT=$(cat "$STATE_FILE")
fi

if [[ "$CURRENT" == "dark" ]]; then
    echo ""
else
    echo ""
fi
