#!/usr/bin/env bash
# Template for a CLI script with long/short flags and positional arguments.
# Replace the case branches, usage() text and the domain validations below.

set -euo pipefail

usage() {
    cat <<EOF
Usage: ${0##*/} INPUT [options]

Positional arguments:
  INPUT                 Description of the positional argument

Options:
  -o, --output FILE     Option that takes a value
      --flag            Boolean flag (no value)
  -h, --help            Show this help and exit
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

OUTPUT=""
FLAG=0
INPUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output)
            [ $# -ge 2 ] || die "--output requires a value"
            OUTPUT="$2"; shift 2 ;;
        --flag)         FLAG=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        -*)             usage >&2; die "unknown option: $1" ;;
        *)
            if [ -z "$INPUT" ]; then
                INPUT="$1"; shift
            else
                die "unexpected argument: $1"
            fi
            ;;
    esac
done

if [ -z "$INPUT" ]; then
    usage >&2
    die "no input provided"
fi
