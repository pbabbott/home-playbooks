#!/bin/bash

FILE_TO_WATCH="/home/albus/pironman_monitor/color.txt"
SCRIPT_TO_RUN="sudo /usr/local/bin/pironman -rc"

inotifywait -m -e modify "$FILE_TO_WATCH" | while read -r path action file; do
    echo "File changed: $FILE_TO_WATCH"

    # Extract information from the file (modify this to fit your needs)
    PARAM=$(tail -n 1 "$FILE_TO_WATCH")

    # Run your script with the extracted parameter
    echo sudo /usr/local/bin/pironman -rc $PARAM
    sudo /usr/local/bin/pironman -rc $PARAM
done
