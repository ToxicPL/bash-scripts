#!/bin/bash
# Version 1.0 Ping to  8.8.8.8 and make file if ping failed

LOGFILE="/mnt/usb-drv/1tb/log.txt"

while true
do
    # Current timestamp
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    # Ping and store result
    if ! ping -c 1 8.8.8.8 &> /dev/null
    then
        echo "$TIMESTAMP - Ping failed" >> "$LOGFILE"
    fi

    # Wait before the next check
    sleep 15
done
