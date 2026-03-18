#!/usr/bin/env bash
# =============================================================================
# Backup Tool
#
# Creates timestamped compressed backups of specified directories with support
# for incremental backups, retention policies, and logging.
#
# Usage: ./02_backup_tool.sh -s SOURCE -d DESTINATION [-r DAYS] [-c LEVEL]
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DATE_FMT='+%Y-%m-%d %H:%M:%S'
readonly BACKUP_DATE_FMT='+%Y%m%d_%H%M%S'
readonly DEFAULT_RETENTION_DAYS=30
readonly DEFAULT_COMPRESSION=6

log_file=""

usage() {
    cat << EOF
Backup Tool - Create compressed backups with retention

Usage: $SCRIPT_NAME [OPTIONS]

Required:
    -s, --source DIR         Source directory to back up
    -d, --destination DIR    Destination directory for backups

Optional:
    -r, --retention DAYS     Delete backups older than DAYS (default: $DEFAULT_RETENTION_DAYS)
    -c, --compression LEVEL  Gzip compression level 1-9 (default: $DEFAULT_COMPRESSION)
    -l, --log FILE           Log file path (default: DESTINATION/backup.log)
    -n, --name PREFIX        Backup file name prefix (default: "backup")
    -e, --exclude PATTERN    Exclude pattern (can be repeated)
    --dry-run                Show what would be done without doing it
    -h, --help               Show this help

Examples:
    $SCRIPT_NAME -s /home/user -d /mnt/backups
    $SCRIPT_NAME -s /var/www -d /backups -r 7 -c 9 -e "*.log" -e "cache/"
    $SCRIPT_NAME -s /data -d /backups --dry-run
EOF
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date "$LOG_DATE_FMT")
    local entry="[$timestamp] [$level] $message"

    echo "$entry"
    if [[ -n "$log_file" ]]; then
        echo "$entry" >> "$log_file"
    fi
}

die() {
    log "ERROR" "$*"
    exit 1
}

check_dependencies() {
    local missing=()
    for cmd in tar gzip find du; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required commands: ${missing[*]}"
    fi
}

format_size() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif (( bytes >= 1048576 )); then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    elif (( bytes >= 1024 )); then
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

create_backup() {
    local source="$1"
    local destination="$2"
    local prefix="$3"
    local compression="$4"
    local dry_run="$5"
    shift 5
    local excludes=("$@")

    local timestamp
    timestamp=$(date "$BACKUP_DATE_FMT")
    local backup_name="${prefix}_${timestamp}.tar.gz"
    local backup_path="${destination}/${backup_name}"

    log "INFO" "Starting backup of '$source'"
    log "INFO" "Destination: $backup_path"

    local source_size
    source_size=$(du -sb "$source" 2>/dev/null | cut -f1 || echo "0")
    source_size="${source_size:-0}"
    log "INFO" "Source size: $(format_size "$source_size")"

    if $dry_run; then
        log "INFO" "[DRY RUN] Would create backup: $backup_path"
        local exclude_args=""
        for pattern in "${excludes[@]}"; do
            exclude_args+=" --exclude='$pattern'"
        done
        log "INFO" "[DRY RUN] Command: tar czf '$backup_path' $exclude_args -C '$(dirname "$source")' '$(basename "$source")'"
        return 0
    fi

    local tar_args=()
    for pattern in "${excludes[@]}"; do
        tar_args+=("--exclude=$pattern")
    done

    local start_time
    start_time=$(date +%s)

    if tar -czf "$backup_path" \
        --gzip \
        -"$compression" \
        "${tar_args[@]}" \
        -C "$(dirname "$source")" \
        "$(basename "$source")" 2>/dev/null; then

        local end_time elapsed backup_size
        end_time=$(date +%s)
        elapsed=$(( end_time - start_time ))
        backup_size=$(stat -c%s "$backup_path" 2>/dev/null || stat -f%z "$backup_path" 2>/dev/null)

        log "INFO" "Backup completed successfully"
        log "INFO" "Archive size: $(format_size "$backup_size")"
        if (( source_size > 0 )); then
            log "INFO" "Compression ratio: $(echo "scale=1; $backup_size * 100 / $source_size" | bc)%"
        fi
        log "INFO" "Duration: ${elapsed}s"

        if command -v md5sum &>/dev/null; then
            local checksum
            checksum=$(md5sum "$backup_path" | cut -d' ' -f1)
            log "INFO" "MD5: $checksum"
            echo "$checksum  $backup_name" > "${backup_path}.md5"
        fi
    else
        die "Backup creation failed"
    fi
}

rotate_backups() {
    local destination="$1"
    local prefix="$2"
    local retention_days="$3"
    local dry_run="$4"

    log "INFO" "Rotating backups older than ${retention_days} days"

    local count=0
    while IFS= read -r -d '' old_backup; do
        if $dry_run; then
            log "INFO" "[DRY RUN] Would delete: $(basename "$old_backup")"
        else
            rm -f "$old_backup" "${old_backup}.md5"
            log "INFO" "Deleted old backup: $(basename "$old_backup")"
        fi
        (( count++ ))
    done < <(find "$destination" -maxdepth 1 -name "${prefix}_*.tar.gz" -mtime +"$retention_days" -print0 2>/dev/null)

    log "INFO" "Rotation complete: $count old backup(s) ${dry_run:+would be }removed"

    local remaining
    remaining=$(find "$destination" -maxdepth 1 -name "${prefix}_*.tar.gz" 2>/dev/null | wc -l)
    log "INFO" "Remaining backups: $remaining"
}

main() {
    local source=""
    local destination=""
    local retention_days=$DEFAULT_RETENTION_DAYS
    local compression=$DEFAULT_COMPRESSION
    local prefix="backup"
    local dry_run=false
    local excludes=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)      source="$2"; shift 2 ;;
            -d|--destination) destination="$2"; shift 2 ;;
            -r|--retention)   retention_days="$2"; shift 2 ;;
            -c|--compression) compression="$2"; shift 2 ;;
            -l|--log)         log_file="$2"; shift 2 ;;
            -n|--name)        prefix="$2"; shift 2 ;;
            -e|--exclude)     excludes+=("$2"); shift 2 ;;
            --dry-run)        dry_run=true; shift ;;
            -h|--help)        usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    [[ -n "$source" ]] || die "Source directory is required (-s)"
    [[ -n "$destination" ]] || die "Destination directory is required (-d)"
    [[ -d "$source" ]] || die "Source directory does not exist: $source"

    if [[ -z "$log_file" ]]; then
        log_file="${destination}/backup.log"
    fi

    check_dependencies

    mkdir -p "$destination"

    log "INFO" "=========================================="
    log "INFO" "Backup session started"
    log "INFO" "=========================================="

    create_backup "$source" "$destination" "$prefix" "$compression" "$dry_run" "${excludes[@]+"${excludes[@]}"}"
    rotate_backups "$destination" "$prefix" "$retention_days" "$dry_run"

    log "INFO" "Backup session complete"
}

main "$@"
