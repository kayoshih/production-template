#!/bin/bash
# backup.sh — syncs code + selected data to S3 via rclone.
# Config: config/backup.list (source → destination pairs).
#
# Format: <source_path>|<rclone_destination>
# Example: /home/user/project|s3:backup/project

set -u

LOG="${BACKUP_LOG:-/var/log/backup.log}"
CONFIG="${BACKUP_CONFIG:-./config/backup.list}"
RCLONE="${RCLONE_BIN:-/usr/bin/rclone}"

log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" >> "$LOG"
}

if [ ! -f "$CONFIG" ]; then
    log "ERROR: config not found: $CONFIG"
    exit 1
fi

rc=0
while IFS='|' read -r src dst; do
    [ -z "$src" ] && continue
    [[ "$src" =~ ^# ]] && continue

    if [ ! -e "$src" ]; then
        log "SKIP: $src (not found)"
        continue
    fi

    log "SYNC: $src → $dst"
    if "$RCLONE" sync "$src" "$dst" >> "$LOG" 2>&1; then
        log "OK: $src"
    else
        log "ERROR: $src (RC=$?)"
        rc=1
    fi
done < "$CONFIG"

log "DONE RC=$rc"

# Rotate log if > 5 MB
if [ -f "$LOG" ]; then
    size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt 5242880 ]; then
        tail -500 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
    fi
fi

exit $rc
