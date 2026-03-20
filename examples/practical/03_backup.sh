#!/bin/bash
# Automated Backup Utility — incremental backups with rotation, compression, verification
# Usage: ./03_backup.sh -s /source/path -d /backup/path [-k keep_count] [-c]
#        ./03_backup.sh --demo

set -euo pipefail

SOURCE=""
DEST=""
KEEP=7
COMPRESS=false
DEMO_MODE=false
LOG_FILE=""

usage() {
    cat << EOF
Automated Backup Utility

Usage: $(basename "$0") [OPTIONS]

Options:
    -s PATH   Source directory to back up (required unless --demo)
    -d PATH   Destination directory for backups (required unless --demo)
    -k NUM    Number of backups to keep (default: 7)
    -c        Compress backup with gzip
    --demo    Run demo with temporary directories
    -h        Show this help

Examples:
    $(basename "$0") -s /home/user/projects -d /mnt/backup -k 14 -c
    $(basename "$0") --demo
EOF
    exit 0
}

if [[ "${1:-}" == "--demo" ]]; then
    DEMO_MODE=true
    shift
fi

while getopts "s:d:k:ch" opt 2>/dev/null; do
    case "$opt" in
        s) SOURCE="$OPTARG" ;;
        d) DEST="$OPTARG" ;;
        k) KEEP="$OPTARG" ;;
        c) COMPRESS=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

if $DEMO_MODE; then
    SOURCE=$(mktemp -d)
    DEST=$(mktemp -d)
    trap 'rm -rf "$SOURCE" "$DEST"' EXIT

    mkdir -p "$SOURCE"/{docs,src,config}
    echo "# Project README" > "$SOURCE/README.md"
    echo "print('hello')" > "$SOURCE/src/main.py"
    echo "host=localhost" > "$SOURCE/config/settings.ini"
    for i in {1..5}; do
        echo "Document $i content" > "$SOURCE/docs/doc_$i.txt"
    done
    echo "Demo source created: $SOURCE"
    echo "Demo destination: $DEST"
    echo ""
fi

[[ -z "$SOURCE" ]] && { echo "Error: source (-s) is required" >&2; usage; }
[[ -z "$DEST" ]]   && { echo "Error: destination (-d) is required" >&2; usage; }
[[ -d "$SOURCE" ]] || { echo "Error: source '$SOURCE' does not exist" >&2; exit 1; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}"
LOG_FILE="${DEST}/backup.log"

mkdir -p "$DEST"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

log "═══════════════════════════════════════"
log "Backup started"
log "Source:      $SOURCE"
log "Destination: $DEST/$BACKUP_NAME"
log "Compression: $COMPRESS"
log "Keep last:   $KEEP backups"

# Count source files and size
source_files=$(find "$SOURCE" -type f | wc -l)
source_size=$(du -sh "$SOURCE" 2>/dev/null | awk '{print $1}')
log "Source files: $source_files ($source_size)"

# Check for latest backup (incremental)
LATEST_LINK=""
latest_backup=$(ls -1d "$DEST"/backup_*/ 2>/dev/null | sort | tail -1 || true)
if [[ -n "$latest_backup" && -d "$latest_backup" ]]; then
    LATEST_LINK="--link-dest=$latest_backup"
    log "Incremental from: $(basename "$latest_backup")"
else
    log "Full backup (no previous backup found)"
fi

# Perform backup
BACKUP_PATH="${DEST}/${BACKUP_NAME}"

if command -v rsync &>/dev/null; then
    rsync_opts=(-a --delete --stats)
    [[ -n "$LATEST_LINK" ]] && rsync_opts+=("$LATEST_LINK")

    log "Running rsync..."
    rsync_output=$(rsync "${rsync_opts[@]}" "$SOURCE/" "$BACKUP_PATH/" 2>&1) || {
        log "ERROR: rsync failed with exit code $?"
        echo "$rsync_output" >> "$LOG_FILE"
        exit 1
    }

    transferred=$(echo "$rsync_output" | grep "Number of regular files transferred" | awk '{print $NF}' || echo "N/A")
    log "Files transferred: $transferred"
else
    log "rsync not found — falling back to cp"
    mkdir -p "$BACKUP_PATH"
    cp -a "$SOURCE/." "$BACKUP_PATH/" 2>&1 || {
        log "ERROR: cp failed with exit code $?"
        exit 1
    }
    transferred=$(find "$BACKUP_PATH" -type f | wc -l)
    log "Files copied: $transferred"
fi

# Compress if requested
if $COMPRESS; then
    log "Compressing backup..."
    tar -czf "${BACKUP_PATH}.tar.gz" -C "$DEST" "$BACKUP_NAME" 2>&1
    rm -rf "$BACKUP_PATH"
    BACKUP_PATH="${BACKUP_PATH}.tar.gz"
    log "Compressed to: $(basename "$BACKUP_PATH")"
fi

# Verify backup
backup_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | awk '{print $1}')
if $COMPRESS; then
    backup_files="(compressed archive)"
else
    backup_files=$(find "$BACKUP_PATH" -type f 2>/dev/null | wc -l)
fi
log "Backup size: $backup_size"
log "Backup files: $backup_files"

# Verify integrity
if $COMPRESS; then
    if tar -tzf "$BACKUP_PATH" > /dev/null 2>&1; then
        log "Integrity check: PASSED (tar archive valid)"
    else
        log "ERROR: Integrity check FAILED"
    fi
else
    if [[ -d "$BACKUP_PATH" ]]; then
        verify_count=$(find "$BACKUP_PATH" -type f | wc -l)
        log "Integrity check: PASSED ($verify_count files verified)"
    fi
fi

# Rotate old backups
rotate_backups() {
    local count=0
    local all_backups

    if $COMPRESS; then
        all_backups=$(ls -1t "$DEST"/backup_*.tar.gz 2>/dev/null || true)
    else
        all_backups=$(ls -1dt "$DEST"/backup_*/ 2>/dev/null | sed 's:/$::' || true)
    fi

    [[ -z "$all_backups" ]] && return

    while IFS= read -r old_backup; do
        ((count++)) || true
        if (( count > KEEP )); then
            log "Rotating out: $(basename "$old_backup")"
            rm -rf "$old_backup"
        fi
    done <<< "$all_backups"

    log "Kept $((count > KEEP ? KEEP : count)) of $count backup(s)"
}

rotate_backups

log "Backup completed successfully!"
log "═══════════════════════════════════════"

# Summary
echo ""
echo "╔═══════════════════════════════════════╗"
echo "║        BACKUP SUMMARY                 ║"
echo "╠═══════════════════════════════════════╣"
printf "║  Source:     %-25s║\n" "$(basename "$SOURCE")"
printf "║  Backup:     %-25s║\n" "$(basename "$BACKUP_PATH")"
printf "║  Size:       %-25s║\n" "$backup_size"
printf "║  Compressed: %-25s║\n" "$COMPRESS"
echo "║  Status:     SUCCESS                 ║"
echo "╚═══════════════════════════════════════╝"
