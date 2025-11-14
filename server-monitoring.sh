#!/bin/bash
# Script to monitor disk CPU and RAM usage and send alert if usage exceeds threshold
# 14.11.2025 - Drive monitoring added

#List of monitored drives
PARTITION=("/" "/boot")
WEBHOOK_URL="https://example.com/webhook" # Replace with your webhook URL

for PART in "${PARTITION[@]}"; do
    USAGE=$(df -h "$PART" | awk 'NR==2 {gsub("%","",$5); print $5}')
    if [ $USAGE -gt 60 ] ; then
        MESSAGE="⚠️Warning: Disk usage on partition $PART is at ${USAGE}%"
        curl -X POST -H 'Content-type: application/json' --data "{\"content\":\"$MESSAGE\"}" $WEBHOOK_URL
    fi
done