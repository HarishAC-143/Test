#!/bin/bash
set -euo pipefail
# Practical example: Backup Script with Rotation
# Creates compressed backups of a directory with automatic cleanup of old backups

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <source_directory>

Creates compressed backups with automatic rotation.

Options:
    -o DIR      Output directory for backups (default: /tmp/backups)
    -k NUM      Number of backups to keep (default: 5)
    -n NAME     Backup name prefix (default: derived from source dir)
    -v          Verbose output
    -d          Dry run (show what would happen)
    -h          Show this help

Examples:
    $(basename "$0") /home/user/projects
    $(basename "$0") -o /mnt/backup -k 10 /var/www
    $(basename "$0") -d -v /etc
EOF
}

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        INFO)  echo "[$timestamp] INFO  $*" ;;
        WARN)  echo "[$timestamp] WARN  $*" >&2 ;;
        ERROR) echo "[$timestamp] ERROR $*" >&2 ;;
    esac
}

backup_dir="/tmp/backups"
keep=5
prefix=""
verbose=false
dry_run=false

while getopts ":o:k:n:vdh" opt; do
    case "$opt" in
        o) backup_dir="$OPTARG" ;;
        k) keep="$OPTARG" ;;
        n) prefix="$OPTARG" ;;
        v) verbose=true ;;
        d) dry_run=true ;;
        h) usage; exit 0 ;;
        :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
        ?) echo "Unknown option: -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $(( OPTIND - 1 ))

source_dir="${1:?$(usage)}"

if [[ ! -d "$source_dir" ]]; then
    log ERROR "Source directory not found: $source_dir"
    exit 1
fi

[[ -z "$prefix" ]] && prefix=$(basename "$source_dir")
bk_timestamp=$(date +%Y%m%d_%H%M%S)
readonly backup_name="${prefix}_${bk_timestamp}.tar.gz"
readonly backup_path="${backup_dir}/${backup_name}"

echo "╔══════════════════════════════════════╗"
echo "║          BACKUP UTILITY              ║"
echo "╠══════════════════════════════════════╣"
echo "  Source:    $source_dir"
echo "  Output:    $backup_dir"
echo "  Filename:  $backup_name"
echo "  Keep last: $keep backups"
echo "  Dry run:   $dry_run"
echo "╚══════════════════════════════════════╝"
echo ""

# Create backup directory
if ! $dry_run; then
    mkdir -p "$backup_dir"
fi

# Calculate source size
source_size=$(du -sh "$source_dir" 2>/dev/null | cut -f1)
log INFO "Source size: $source_size"

# Count files
file_count=$(find "$source_dir" -type f 2>/dev/null | wc -l)
log INFO "Files to backup: $file_count"

# Create backup
if $dry_run; then
    log INFO "[DRY RUN] Would create: $backup_path"
else
    log INFO "Creating backup..."
    start_time=$(date +%s)

    tar -czf "$backup_path" \
        -C "$(dirname "$source_dir")" \
        "$(basename "$source_dir")" 2>/dev/null

    end_time=$(date +%s)
    duration=$(( end_time - start_time ))
    backup_size=$(du -h "$backup_path" | cut -f1)

    log INFO "Backup created: $backup_name ($backup_size) in ${duration}s"

    if $verbose; then
        log INFO "Backup contents:"
        tar -tzf "$backup_path" | head -20
        total_in_archive=$(tar -tzf "$backup_path" | wc -l)
        echo "  ... ($total_in_archive entries total)"
    fi
fi

# Rotate old backups
log INFO "Checking for old backups to rotate..."
existing=$(ls -1t "$backup_dir"/${prefix}_*.tar.gz 2>/dev/null | wc -l)

if (( existing > keep )); then
    remove_count=$(( existing - keep ))
    log INFO "Removing $remove_count old backup(s)..."

    ls -1t "$backup_dir"/${prefix}_*.tar.gz 2>/dev/null | \
        tail -n "$remove_count" | while read -r old_backup; do
        if $dry_run; then
            log INFO "[DRY RUN] Would remove: $(basename "$old_backup")"
        else
            old_size=$(du -h "$old_backup" | cut -f1)
            rm -f "$old_backup"
            log INFO "Removed: $(basename "$old_backup") ($old_size)"
        fi
    done
else
    log INFO "No rotation needed ($existing/$keep)"
fi

# Summary
echo ""
echo "=== Current Backups ==="
if ls "$backup_dir"/${prefix}_*.tar.gz &>/dev/null; then
    printf "  %-40s %8s %s\n" "Filename" "Size" "Date"
    printf "  %s\n" "$(printf '─%.0s' {1..60})"
    ls -lht "$backup_dir"/${prefix}_*.tar.gz 2>/dev/null | \
        awk '{printf "  %-40s %8s %s %s %s\n", $NF, $5, $6, $7, $8}' | \
        sed "s|$backup_dir/||"
    echo ""
    total_size=$(du -sh "$backup_dir"/${prefix}_*.tar.gz 2>/dev/null | tail -1 | cut -f1)
    echo "  Total backup storage: $total_size"
else
    echo "  No backups found"
fi

log INFO "Backup operation complete"
