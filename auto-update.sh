#!/bin/bash
# Version 1.0 Auto-update script to pull latest upgrades and log the update time
LOGFILE="/mnt/usb-drv/1tb/log.txt"

set -e

patching(){
    sudo apt-get update -y;
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y;
};

patching;
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP - System updated successfully" >> "$LOGFILE"