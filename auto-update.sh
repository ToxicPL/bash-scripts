#!/bin/bash
# Version 1.0 Auto-update script to pull latest upgrades and log the update time
# Version 1.1 - Added webhook notification with list of updated packages
# Version 1.2 - Added check for available updates before patching and logging accordingly
# Version 1.3 - Added error handling for apt and curl failures
# Version 1.4 - Added hostname to log and notification messages
# Version 1.5 - Added jq fallback, reboot-required status, and clearer package update summary

LOGFILE="/mnt/NAS/home-lab/logs/updates.txt"
WEBHOOK_URL="EXAMPLE_WEBHOOK_URL"  # Replace with your actual Discord webhook URL
HOSTNAME="$(hostname)"
REBOOT_REQUIRED="no"

mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || true
touch "$LOGFILE" 2>/dev/null || true

if [ -f /var/run/reboot-required ]; then
    REBOOT_REQUIRED="yes"
fi

log_event() {
    local LEVEL="$1"
    local MESSAGE="$2"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    echo "$TIMESTAMP - [$LEVEL] $MESSAGE <$HOSTNAME>" >> "$LOGFILE" 2>/dev/null || {
        echo "Warning: failed to write to $LOGFILE" >&2
        return 1
    }

    if [ -n "$WEBHOOK_URL" ] && [ "$WEBHOOK_URL" != "EXAMPLE_WEBHOOK_URL" ]; then
        local JSON_PAYLOAD
        JSON_PAYLOAD=$(printf '%s' "$TIMESTAMP - $MESSAGE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        curl -s -X POST \
            -H "Content-Type: application/json" \
            --data "{\"content\":\"$JSON_PAYLOAD\"}" \
            "$WEBHOOK_URL" >/dev/null 2>&1 || echo "Warning: failed to send Discord notification" >> "$LOGFILE" 2>/dev/null || true
    fi
}

run_updates() {
    apt-get update -y 2>/dev/null || return 1
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 2>/dev/null || return 2
}

NEW_PACKAGES=$(apt-get -s upgrade 2>/dev/null | awk '/^Inst / {print $2}')
PENDING_COUNT=0
if [ -n "$NEW_PACKAGES" ]; then
    PENDING_COUNT=$(printf '%s\n' "$NEW_PACKAGES" | sed '/^$/d' | wc -l | tr -d ' ')
fi

if [ -z "$NEW_PACKAGES" ]; then
    log_event "INFO" "No updates available on **$HOSTNAME**. Packages pending: $PENDING_COUNT | Updated: 0 | Failed: 0 | Reboot required: $REBOOT_REQUIRED"
    exit 0
fi

run_updates
EXIT_CODE=$?
PKG_LIST=$(printf '%s\n' "$NEW_PACKAGES" | tr '\n' ', ' | sed 's/,$//')

case "$EXIT_CODE" in
    0)
        log_event "OK" "System updated successfully on **$HOSTNAME**. Packages pending: $PENDING_COUNT | Updated: $PENDING_COUNT | Failed: 0 | Reboot required: $REBOOT_REQUIRED. New/updated packages: $PKG_LIST"
        ;;
    1)
        log_event "FAIL" "apt-get update failed on **$HOSTNAME**. Packages pending: $PENDING_COUNT | Updated: 0 | Failed: 1 | Reboot required: $REBOOT_REQUIRED. Packages: $PKG_LIST"
        ;;
    2)
        log_event "FAIL" "apt-get upgrade failed on **$HOSTNAME**. Packages pending: $PENDING_COUNT | Updated: 0 | Failed: 1 | Reboot required: $REBOOT_REQUIRED. Packages: $PKG_LIST"
        ;;
    *)
        log_event "FAIL" "Update failed with unknown error on **$HOSTNAME**. Packages pending: $PENDING_COUNT | Updated: 0 | Failed: 1 | Reboot required: $REBOOT_REQUIRED. Packages: $PKG_LIST"
        ;;
esac

exit "$EXIT_CODE"