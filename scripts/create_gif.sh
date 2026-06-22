#!/usr/bin/env bash
# scripts/create_gif.sh
# Convert a video to an optimized GIF using ffmpeg's two-pass palette method.
#
# Example: create_gif.sh input.mp4 -o output.gif -f 15 -w 800

set -e

usage() {
    cat <<EOF
Usage: ${0##*/} INPUT [options]

Convert a video to an optimized GIF (two-pass palette method).

Positional arguments:
  INPUT                 Path to the video to be converted

Options:
  -o, --output FILE     Output file (default: INPUT with .gif extension)
  -f, --fps N           Frames per second of the resulting GIF (default: 15)
  -w, --width N         Width in pixels; height keeps aspect ratio (default: 800)
  -d, --dither MODE     paletteuse dither mode (default: bayer:bayer_scale=3)
      --keep-palette    Keep the intermediate palette file instead of deleting it
  -h, --help            Show this help and exit
EOF
}

OUTPUT=""
FPS=15
WIDTH=800
DITHER="bayer:bayer_scale=3"
KEEP_PALETTE=0
INPUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output)        OUTPUT="$2"; shift 2 ;;
        -f|--fps)           FPS="$2"; shift 2 ;;
        -w|--width)         WIDTH="$2"; shift 2 ;;
        -d|--dither)        DITHER="$2"; shift 2 ;;
        --keep-palette)     KEEP_PALETTE=1; shift ;;
        -h|--help)          usage; exit 0 ;;
        -*)                 echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)
            if [ -z "$INPUT" ]; then
                INPUT="$1"; shift
            else
                echo "Error: unexpected argument: $1" >&2; exit 1
            fi
            ;;
    esac
done

if [ -z "$INPUT" ]; then
    echo "Error: no input video provided" >&2
    usage >&2
    exit 1
fi

INPUT="${INPUT/#\~/$HOME}"
if [ ! -f "$INPUT" ]; then
    echo "Error: input video not found: $INPUT" >&2
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg is not installed" >&2
    exit 1
fi

case "$FPS" in
    ''|*[!0-9]*) echo "Error: --fps must be a positive integer" >&2; exit 1 ;;
esac
case "$WIDTH" in
    ''|*[!0-9]*) echo "Error: --width must be a positive integer" >&2; exit 1 ;;
esac
[ "$FPS" -gt 0 ] || { echo "Error: --fps must be a positive integer" >&2; exit 1; }
[ "$WIDTH" -gt 0 ] || { echo "Error: --width must be a positive integer" >&2; exit 1; }

if [ -z "$OUTPUT" ]; then
    OUTPUT="${INPUT%.*}.gif"
fi
OUTPUT="${OUTPUT/#\~/$HOME}"

OUT_DIR="$(dirname "$OUTPUT")"
[ -d "$OUT_DIR" ] || mkdir -p "$OUT_DIR"

if [ "$KEEP_PALETTE" -eq 1 ]; then
    PALETTE="${OUTPUT%.*}.palette.png"
else
    PALETTE="$(mktemp --suffix=.png)"
    trap 'rm -f "$PALETTE"' EXIT
fi

FILTER="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos"

ffmpeg -i "$INPUT" \
    -vf "${FILTER},palettegen=stats_mode=diff" \
    -y "$PALETTE"

ffmpeg -i "$INPUT" -i "$PALETTE" \
    -lavfi "${FILTER}[x];[x][1:v]paletteuse=dither=${DITHER}" \
    -y "$OUTPUT"

SIZE="$(du -h "$OUTPUT" | cut -f1)"
echo "GIF written to $OUTPUT ($SIZE)"
[ "$KEEP_PALETTE" -eq 1 ] && echo "Palette kept at $PALETTE"
