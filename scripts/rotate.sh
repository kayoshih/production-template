#!/bin/bash
# rotate.sh — rotates data files by age.
# Config: config/rotate.list (paths + retention tiers in days).
#
# Format: <path>|<live_days>|<archive_days>|<cold_days>
#   live_days:    keep files in place (freshest)
#   archive_days: move files older than live to archive/
#   cold_days:    zip files older than archive
#
# Example: /data/raw/trades|30|90|365

set -u

LOG="${ROTATE_LOG:-/var/log/rotate.log}"
CONFIG="${ROTATE_CONFIG:-./config/rotate.list}"

log() {
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $*" >> "$LOG"
}

if [ ! -f "$CONFIG" ]; then
    log "ERROR: config not found: $CONFIG"
    exit 1
fi

while IFS='|' read -r path live_days archive_days cold_days; do
    [ -z "$path" ] && continue
    [[ "$path" =~ ^# ]] && continue

    if [ ! -d "$path" ]; then
        log "SKIP: $path (not a directory)"
        continue
    fi

    archive_dir="${path}/../archive"
    cold_dir="${archive_dir}/_cold"
    mkdir -p "$archive_dir" "$cold_dir"

    # Move to archive: files older than live_days
    find "$path" -maxdepth 1 -type f -mtime +"$live_days" \
        -exec mv {} "$archive_dir/" \; 2>/dev/null

    # Zip: files in archive older than (archive_days - live_days)
    zip_after=$((archive_days - live_days))
    find "$archive_dir" -maxdepth 1 -type f -mtime +"$zip_after" \
        -exec gzip {} \; 2>/dev/null

    # Cold: move zipped files older than cold_days - archive_days
    cold_after=$((cold_days - archive_days))
    find "$archive_dir" -maxdepth 1 -type f -name "*.gz" -mtime +"$cold_after" \
        -exec mv {} "$cold_dir/" \; 2>/dev/null

    log "OK: $path (live=$live_days archive=$archive_days cold=$cold_days)"
done < "$CONFIG"

log "DONE"

# Rotate log if > 5 MB
if [ -f "$LOG" ]; then
    size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt 5242880 ]; then
        tail -500 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
    fi
fi

exit 0
