#!/usr/bin/env bash
#
# 02_backup.sh — Creates compressed, timestamped backups with rotation
#
# Usage: ./02_backup.sh [backup_dir]
#
# Environment:
#   BACKUP_SOURCES  Colon-separated list of directories to back up
#   MAX_BACKUPS     Number of backups to retain (default: 7)
#

set -euo pipefail

BACKUP_DIR="${1:-$HOME/backups}"
MAX_BACKUPS="${MAX_BACKUPS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}.tar.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

IFS=':' read -ra BACKUP_SOURCES <<< "${BACKUP_SOURCES:-$HOME/Documents:$HOME/projects}"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

mkdir -p "$BACKUP_DIR"

log "Starting backup..."
log "Backup directory: $BACKUP_DIR"
log "Max backups to keep: $MAX_BACKUPS"

sources=()
for src in "${BACKUP_SOURCES[@]}"; do
    if [[ -d "$src" ]]; then
        sources+=("$src")
        log "  Including: $src"
    else
        log "  Skipping (not found): $src"
    fi
done

if [[ ${#sources[@]} -eq 0 ]]; then
    log "No valid sources to back up. Exiting."
    exit 1
fi

log "Creating archive: $BACKUP_NAME"
if tar -czf "$BACKUP_DIR/$BACKUP_NAME" "${sources[@]}" 2>/dev/null; then
    backup_size=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
    log "Backup complete: $BACKUP_NAME ($backup_size)"
else
    log "Warning: tar reported errors (some files may have been skipped)"
fi

backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -name 'backup_*.tar.gz' | wc -l)
if (( backup_count > MAX_BACKUPS )); then
    log "Rotating backups (keeping last $MAX_BACKUPS)..."
    find "$BACKUP_DIR" -maxdepth 1 -name 'backup_*.tar.gz' -printf '%T@ %p\n' | \
        sort -n | head -n -"$MAX_BACKUPS" | cut -d' ' -f2- | \
        while read -r old_backup; do
            log "  Deleting: $(basename "$old_backup")"
            rm -f "$old_backup"
        done
fi

log "Backup process finished."
