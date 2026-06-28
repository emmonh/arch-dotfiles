#!/usr/bin/env bash
# Create local, rofi ready .desktop file from original AppImage .desktop entry

set -euo pipefail

usage() {
    cat <<EOF
Usage: ${0##*/} [options] APPIMAGE

Create local, rofi ready .desktop file for an APPIMAGE

Positional arguments:
  APPIMAGE              .AppImage source file

Options:
  -o, --output FILE     Output file to create (default: $HOME/.local/share/applications/<APPIMAGE basename>.desktop)
  -h, --help            Show this help and exit
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

desktopEntryKeys () {
    echo
    echo "Exec=$APPIMAGE %u"
    [ -n "$ICON_DEST" ] && echo "Icon=$ICON_DEST"
}


OUTPUT=""
APPIMAGE=""
ICON_DEST=""

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output)
            [ $# -ge 2 ] || die "--output requires a value"
            OUTPUT="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        -*)
            usage >&2; die "unknown option: $1" ;;
        *)
            if [ -z "$APPIMAGE" ]; then
                APPIMAGE="$1"; shift
            else
                die "unexpected argument: $1"
            fi
            ;;
    esac
done

if [ -z "$APPIMAGE" ]; then
    usage >&2
    die "no input provided"
fi

ICON_DIR="$HOME/.local/share/icons"
APPIMAGE="$(realpath -e "$APPIMAGE")" || die "file does not exist: $APPIMAGE"

WORKING_DIR="$(mktemp -d)"
trap 'rm -rf "$WORKING_DIR"' EXIT
cd "$WORKING_DIR"

"$APPIMAGE" --appimage-extract >/dev/null
cd squashfs-root/

shopt -s nullglob
desktops=(*.desktop)
[ ${#desktops[@]} -gt 0 ] || die "couldnt find .desktop source"
_RAW_DESKTOP_ENTRY="$(cat "${desktops[0]}")"

DESKTOP_ENTRY="$(echo "$_RAW_DESKTOP_ENTRY" | grep -vE "(Exec|Icon)=")"
_NAME="$(echo "$_RAW_DESKTOP_ENTRY" | grep -m1 -E "^Name=")"
NAME=${_NAME##*=}
EXT=""

if [ -e .DirIcon ]; then
    _SOURCE_ICON=.DirIcon
    if [ -L "$_SOURCE_ICON" ]; then
        _SOURCE_ICON="$(readlink -f "$_SOURCE_ICON")"
    fi

    case "$(file -b --mime-type "$_SOURCE_ICON")" in
        image/png)
            EXT=png ;;
        image/svg+xml)
            EXT=svg ;;
        *)
            EXT="" ;;
    esac

    if [ -n "$EXT" ]; then
        ICON_DEST="$ICON_DIR/$NAME.$EXT"
        mkdir -p "$ICON_DIR"
        cp "$_SOURCE_ICON" "$ICON_DEST"
    fi
else
    echo "could not find .DirIcon"
fi

KEYS="$(desktopEntryKeys)"

DESKTOP_ENTRY+="$KEYS"

OUTPUT="${OUTPUT:-$HOME/.local/share/applications/$NAME.desktop}"
mkdir -p "$(dirname "$OUTPUT")"
echo "$DESKTOP_ENTRY" > "$OUTPUT"
