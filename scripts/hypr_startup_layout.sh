#!/usr/bin/env bash
# scripts/hypr_startup_layout.sh
# Spawns a fixed set of windows and arranges them into a predefined dwindle tree
#
# Usage: hypr_startup_layout.sh [workspace] [--return]
#   --return  go back to the workspace that was active before building the layout

set -euo pipefail

WORKSPACE="${1:-6}"
RETURN_TO_ORIGIN=false
[ "${2:-}" = "--return" ] && RETURN_TO_ORIGIN=true

WINDOW_TIMEOUT=10

# Fraction of each split taken by its first child (the top one and the left one)
TOP_SHARE=0.5
LEFT_SHARE=0.6666

# A dedicated class per window is what makes the rules and lookups below unambiguous:
# without it every kitty instance on the system would match
MAIN_CLASS=layout-main
SIDE_CLASS=layout-side
BOTTOM_CLASS=layout-bottom

MAIN_CMD=(kitty --class "$MAIN_CLASS" -e fastfetch --dynamic-interval 1000)
SIDE_CMD=(kitty --class "$SIDE_CLASS" -e cmatrix)
BOTTOM_CMD=(kitty --class "$BOTTOM_CLASS" -e cava)

window_exists() {
    hyprctl clients -j | jq -e --arg c "$1" 'any(.[]; .class == $c)' >/dev/null
}

# Polling beats a fixed sleep here: spawn time swings a lot between a cold and a warm start,
# and every dispatch below depends on the previous window already being mapped
wait_for_window() {
    local class=$1
    local deadline=$((SECONDS + WINDOW_TIMEOUT))

    until window_exists "$class"; do
        if ((SECONDS >= deadline)); then
            echo "Error: window '$class' did not appear within ${WINDOW_TIMEOUT}s" >&2
            exit 1
        fi
        sleep 0.1
    done
}

spawn() {
    local class=$1
    shift

    "$@" &
    disown
    wait_for_window "$class"
}

# hyprctl exits 0 even when a dispatcher is unknown or refuses to run, so its
# reply is the only way to notice a failed step
dispatch() {
    local response
    response=$(hyprctl dispatch "$@")

    if [ "$response" != "ok" ]; then
        echo "Error: 'hyprctl dispatch $*' returned: $response" >&2
        exit 1
    fi
}

focus() {
    dispatch focuswindow "class:^($1)$"
}

# A dwindle split starts even and only accepts a relative delta, which leaves its
# first child with (1 + delta) / 2 of the parent
set_split_share() {
    local window=$1 share=$2 delta
    delta=$(awk -v s="$share" 'BEGIN { printf "%.4f", 2 * s - 1 }')

    [ "$delta" = "0.0000" ] && return 0

    focus "$window"
    dispatch layoutmsg splitratio "$delta"
}

if window_exists "$MAIN_CLASS"; then
    echo "Layout already present, nothing to do"
    exit 0
fi

ORIGIN_WORKSPACE=$(hyprctl activeworkspace -j | jq -r '.id')

# preselect only applies to the focused workspace, so the layout has to be built
# in the foreground and the original workspace restored afterwards
dispatch workspace "$WORKSPACE"

spawn "$MAIN_CLASS" "${MAIN_CMD[@]}"

focus "$MAIN_CLASS"
dispatch layoutmsg preselect d
spawn "$BOTTOM_CLASS" "${BOTTOM_CMD[@]}"

focus "$MAIN_CLASS"
dispatch layoutmsg preselect r
spawn "$SIDE_CLASS" "${SIDE_CMD[@]}"

# splitratio acts on the parent split of the focused window, which is how each
# level of the tree gets its own proportion
set_split_share "$MAIN_CLASS" "$LEFT_SHARE"
set_split_share "$BOTTOM_CLASS" "$TOP_SHARE"

focus "$MAIN_CLASS"

if [ "$RETURN_TO_ORIGIN" = true ] && [ "$ORIGIN_WORKSPACE" != "$WORKSPACE" ]; then
    dispatch workspace "$ORIGIN_WORKSPACE"
fi

echo "Layout built on workspace $WORKSPACE ✓"
