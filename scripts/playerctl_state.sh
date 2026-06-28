#!/usr/bin/env bash
# playerctl status as a waybar widget string, with a marquee for titles
# wider than the widget. Runs continuously (no "interval" in the module
# config) so it can scroll faster than waybar's 1s minimum interval.
# Note: requires playerctl

set -euo pipefail

WIDTH=32        # visor width, in characters
SEP=" • "   # gap between the end and the looped-around start
TICK=0.25       # seconds between marquee frames
PAUSE=8         # frames held at the start before scrolling (~2s at TICK)

# `|| true` so a missing player doesn't trip `set -e` and kill the loop.
metadata() { playerctl metadata --format "$1" 2>/dev/null || true; }

# Heuristic display width: bash has no wcwidth, so wide glyphs (CJK, Hangul,
# kana, fullwidth forms, emoji) are detected by codepoint range and counted as
# two columns. Lets every frame be padded to a constant on-screen width so the
# widget doesn't resize on non-ASCII content.
is_wide() {
    local cp=$1
    (( (cp >= 0x1100  && cp <= 0x115F)  || (cp >= 0x2E80  && cp <= 0x303E)  ||
       (cp >= 0x3041  && cp <= 0x33FF)  || (cp >= 0x3400  && cp <= 0x4DBF)  ||
       (cp >= 0x4E00  && cp <= 0x9FFF)  || (cp >= 0xA000  && cp <= 0xA4CF)  ||
       (cp >= 0xAC00  && cp <= 0xD7A3)  || (cp >= 0xF900  && cp <= 0xFAFF)  ||
       (cp >= 0xFE30  && cp <= 0xFE4F)  || (cp >= 0xFF00  && cp <= 0xFF60)  ||
       (cp >= 0xFFE0  && cp <= 0xFFE6)  || (cp >= 0x1F300 && cp <= 0x1FAFF) ||
       (cp >= 0x20000 && cp <= 0x3FFFD) ))
}

dwidth() {
    local s=$1 w=0 cp i
    for (( i = 0; i < ${#s}; i++ )); do
        printf -v cp '%d' "'${s:i:1}"
        is_wide "$cp" && w=$(( w + 2 )) || w=$(( w + 1 ))
    done
    printf '%s' "$w"
}

# Truncate $1 to at most $2 columns, then right-pad with spaces to exactly $2
# (the `%*s` field width is the hfill that fills the leftover columns).
fit_cols() {
    local s=$1 max=$2 out="" w=0 cw cp i
    for (( i = 0; i < ${#s}; i++ )); do
        printf -v cp '%d' "'${s:i:1}"
        is_wide "$cp" && cw=2 || cw=1
        (( w + cw > max )) && break
        out+=${s:i:1}
        w=$(( w + cw ))
    done
    printf '%s%*s' "$out" "$(( max - w ))" ''
}

# Plain text only: no pango markup, so character counts below match what is
# actually rendered (markup tags would skew the marquee window math).
# Sets the globals ICON and TEXT directly (no echo/subshell) so ICON survives
# into the loop, where it stays pinned left while only TEXT scrolls.
build() {
    local state title album artist
    state="$(playerctl status 2>/dev/null || echo "No players found")"

    if [ "$state" == "No players found" ] || [ "$state" == "Stopped" ]; then
        ICON=""
        TEXT="Not Playing"
        return
    fi

    [ "$state" == "Playing" ] && ICON=""
    [ "$state" == "Paused" ]  && ICON=""
    title="$(metadata "{{ title }}")"
    album="$(metadata "{{ album }}")"
    artist="$(metadata "{{ artist }}")"

    [ -z "$title" ]  && title="Untitled"
    [ -z "$artist" ] && artist="Unknown"

    if [ -n "$album" ]; then
        TEXT="$title - $artist @ ($album)"
    else
        TEXT="$title - $artist"
    fi
}

offset=0
pause=$PAUSE
last=""
tw=0

while true; do
    build
    text="$TEXT"

    # Restart the marquee only when the text changes, not on a mere ICON
    # (play/pause) flip, so toggling playback doesn't jump the scroll. Column
    # width is cached here since it only depends on the text.
    if [ "$text" != "$last" ]; then
        last="$text"
        tw=$(dwidth "$text")
        offset=0
        pause=$PAUSE
    fi

    if [ "$tw" -le "$WIDTH" ]; then
        printf '%s %s\n' "$ICON" "$(fit_cols "$text" "$WIDTH")"
    else
        # Append a copy of the start so the window wraps around seamlessly
        # instead of running short near the end. The WIDTH-char slice always
        # spans at least WIDTH columns, which fit_cols then trims to exactly.
        frame="$text$SEP"
        frame="$frame${frame:0:WIDTH}"
        printf '%s %s\n' "$ICON" "$(fit_cols "${frame:offset:WIDTH}" "$WIDTH")"

        if [ "$pause" -gt 0 ]; then
            pause=$((pause - 1))
        else
            offset=$(( offset + 1 ))
            if [ "$offset" -ge $(( ${#text} + ${#SEP} )) ]; then
                offset=0
                pause=$PAUSE
            fi
        fi
    fi

    sleep "$TICK"
done
