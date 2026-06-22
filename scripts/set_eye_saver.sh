#!/usr/bin/env bash

DIR="/tmp"
STATUS_FILE="$DIR/eye_saver_status.txt"

TEMPERATURE=4000

TOGGLE=0
DISABLED=0
ENABLED=1

ENABLE_COMMAND="hyprctl hyprsunset temperature $TEMPERATURE"
DISABLE_COMMAND="hyprctl hyprsunset identity"
COMMANDS=( "$DISABLE_COMMAND" "$ENABLE_COMMAND")

if [[ "$1" == "--help" ]]; then
cat <<EOF
Usage: set_eye_saver.sh [OPTIONS]

Set eye saver filter on/off based on the value at $STATUS_FILE

Options:
    -t: Toggle eye saver and update reference file.
    --help: Print this menu.
EOF
exit 0
fi

if [[ ! -f $STATUS_FILE ]]; then
    mkdir -p $DIR
    touch $STATUS_FILE
    echo 0 > $STATUS_FILE
fi

_STATUS=$(cat $STATUS_FILE)
STATUS=$_STATUS
echo "CURRENT_STATUS=$_STATUS"

if [[ "$1" == "-t" ]];then
    TOGGLE=1
fi
echo "TOGGLE=$TOGGLE"

if [[ "$TOGGLE" -eq $ENABLED ]];then
    if [[ $_STATUS -eq $DISABLED ]]; then
        STATUS=$ENABLED
        echo $ENABLED > $STATUS_FILE
    else
        STATUS=$DISABLED
        echo $DISABLED > $STATUS_FILE
    fi
fi

echo "ENABLED=$_STATUS -> $STATUS"
${COMMANDS[$STATUS]}
exit 0



