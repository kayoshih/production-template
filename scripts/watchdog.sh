#!/bin/bash
# watchdog.sh — monitors systemd services, restarts failed ones.
# Config: config/services.list (one service name per line).

set -u

LOG="${WATCHDOG_LOG:-/var/log/watchdog.log}"
CONFIG="${WATCHDOG_CONFIG:-./config/services.list}"
RESTART_COOLDOWN=60

log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" >> "$LOG"
}

if [ ! -f "$CONFIG" ]; then
    log "ERROR: config not found: $CONFIG"
    exit 1
fi

failed=0
while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    [[ "$svc" =~ ^# ]] && continue

    if ! systemctl is-active --quiet "$svc"; then
        log "FAIL: $svc not running, restarting"
        systemctl restart "$svc"
        sleep "$RESTART_COOLDOWN"
        if systemctl is-active --quiet "$svc"; then
            log "OK: $svc restarted"
        else
            log "ERROR: $svc failed to restart"
            failed=$((failed + 1))
        fi
    fi
done < "$CONFIG"

if [ "$failed" -eq 0 ]; then
    log "OK: all services running"
fi

# Rotate log if > 10 MB
if [ -f "$LOG" ]; then
    size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt 10485760 ]; then
        tail -1000 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
    fi
fi

exit 0
