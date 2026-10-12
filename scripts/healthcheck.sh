#!/bin/bash
# healthcheck.sh — checks data freshness across monitored files.
# Config: config/healthcheck.yaml (file paths + max age in hours).

set -u

LOG="${HEALTHCHECK_LOG:-/var/log/healthcheck.log}"
CONFIG="${HEALTHCHECK_CONFIG:-./config/healthcheck.list}"

log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" >> "$LOG"
}

if [ ! -f "$CONFIG" ]; then
    log "ERROR: config not found: $CONFIG"
    exit 1
fi

issues=0
while IFS='|' read -r path max_age_h name; do
    [ -z "$path" ] && continue
    [[ "$path" =~ ^# ]] && continue

    if [ ! -f "$path" ]; then
        log "MISSING: $name ($path)"
        issues=$((issues + 1))
        continue
    fi

    age_sec=$(( $(date +%s) - $(stat -c%Y "$path") ))
    age_h=$(( age_sec / 3600 ))

    if [ "$age_h" -gt "$max_age_h" ]; then
        log "STALE: $name (last=$age_h h, max=$max_age_h h)"
        issues=$((issues + 1))
    fi
done < "$CONFIG"

if [ "$issues" -eq 0 ]; then
    log "OK: all checks passed"
fi

# Rotate log if > 5 MB
if [ -f "$LOG" ]; then
    size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt 5242880 ]; then
        tail -500 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
    fi
fi

exit 0
