#!/bin/bash
# 09_backup_tool.sh -- Practical example: Automated backup with rotation
#
# Creates compressed backups of a source directory,
# manages rotation (keeping N most recent backups),
# and maintains a log of operations.
#
# Usage: ./09_backup_tool.sh [OPTIONS]
#   -s, --source DIR     Source directory to back up (default: current dir)
#   -d, --dest DIR       Destination for backups (default: ./backups)
#   -k, --keep N         Number of backups to keep (default: 5)
#   -n, --dry-run        Show what would be done
#   -h, --help           Show help

set -euo pipefail

# Defaults
BACKUP_SRC="."
BACKUP_DST="./backups"
MAX_KEEP=5
DRY_RUN=false
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --source DIR   Source directory (default: .)"
    echo "  -d, --dest DIR     Backup destination (default: ./backups)"
    echo "  -k, --keep N       Backups to retain (default: 5)"
    echo "  -n, --dry-run      Preview without changes"
    echo "  -h, --help         Show this help"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--source)  BACKUP_SRC="$2"; shift 2 ;;
        -d|--dest)    BACKUP_DST="$2"; shift 2 ;;
        -k|--keep)    MAX_KEEP="$2"; shift 2 ;;
        -n|--dry-run) DRY_RUN=true; shift ;;
        -h|--help)    usage ;;
        *)            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

LOG_FILE="$BACKUP_DST/backup.log"

log() {
    local level="$1"; shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$msg"
    $DRY_RUN || echo "$msg" >> "$LOG_FILE"
}

# Validate source
if [[ ! -d "$BACKUP_SRC" ]]; then
    echo "Error: Source directory '$BACKUP_SRC' does not exist." >&2
    exit 1
fi

BACKUP_SRC=$(cd "$BACKUP_SRC" && pwd)
SRC_NAME=$(basename "$BACKUP_SRC")
ARCHIVE_NAME="backup_${SRC_NAME}_${TIMESTAMP}.tar.gz"

echo "========================================="
echo "  Backup Tool"
echo "========================================="
echo "Source:      $BACKUP_SRC"
echo "Destination: $BACKUP_DST"
echo "Keep last:   $MAX_KEEP backups"
$DRY_RUN && echo "Mode:        DRY RUN"
echo ""

# Create destination
if ! $DRY_RUN; then
    mkdir -p "$BACKUP_DST"
fi

# Calculate source size
src_size=$(du -sh "$BACKUP_SRC" 2>/dev/null | cut -f1)
log "INFO" "Source size: $src_size"

# Create backup
log "INFO" "Creating backup: $ARCHIVE_NAME"

if $DRY_RUN; then
    log "INFO" "(Dry run) Would create: $BACKUP_DST/$ARCHIVE_NAME"
else
    if tar -czf "$BACKUP_DST/$ARCHIVE_NAME" \
        -C "$(dirname "$BACKUP_SRC")" \
        "$(basename "$BACKUP_SRC")" 2>&1; then

        archive_size=$(du -h "$BACKUP_DST/$ARCHIVE_NAME" | cut -f1)
        log "INFO" "Backup created: $archive_size"

        # Verify the archive
        if tar -tzf "$BACKUP_DST/$ARCHIVE_NAME" > /dev/null 2>&1; then
            log "INFO" "Archive verification: PASSED"
        else
            log "ERROR" "Archive verification: FAILED"
            exit 1
        fi
    else
        log "ERROR" "Backup creation failed"
        exit 1
    fi
fi

# Rotate old backups
log "INFO" "Checking rotation (keeping $MAX_KEEP most recent)"

backup_files=()
while IFS= read -r -d '' f; do
    backup_files+=("$f")
done < <(find "$BACKUP_DST" -maxdepth 1 -name "backup_*.tar.gz" -print0 2>/dev/null | sort -z)

total=${#backup_files[@]}

if (( total > MAX_KEEP )); then
    remove_count=$((total - MAX_KEEP))
    log "INFO" "Found $total backups, removing $remove_count oldest"

    for (( i = 0; i < remove_count; i++ )); do
        old="${backup_files[$i]}"
        if $DRY_RUN; then
            log "INFO" "(Dry run) Would remove: $(basename "$old")"
        else
            rm -f "$old"
            log "INFO" "Removed: $(basename "$old")"
        fi
    done
else
    log "INFO" "No rotation needed ($total backups, limit is $MAX_KEEP)"
fi

# Summary
echo ""
echo "========================================="
echo "  Backup Summary"
echo "========================================="
echo "Current backups:"
find "$BACKUP_DST" -maxdepth 1 -name "backup_*.tar.gz" -printf "  %f  (%s bytes)\n" 2>/dev/null | sort || \
    find "$BACKUP_DST" -maxdepth 1 -name "backup_*.tar.gz" 2>/dev/null | sort | while read -r f; do
        echo "  $(basename "$f")"
    done

echo ""
log "INFO" "Backup operation complete"
