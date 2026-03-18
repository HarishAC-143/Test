#!/usr/bin/env bash
# =============================================================================
# Database Backup Script
#
# Performs automated database backups with compression, encryption,
# retention policies, and notification support. Supports MySQL/MariaDB
# and PostgreSQL.
#
# Usage: ./10_database_backup.sh --type TYPE --database DB [OPTIONS]
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly BACKUP_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
readonly LOG_DATE_FMT='+%Y-%m-%d %H:%M:%S'

usage() {
    cat << EOF
Database Backup Script - Automated database backups

Usage: $SCRIPT_NAME --type TYPE --database DB [OPTIONS]

Required:
    --type TYPE          Database type: mysql, postgres
    --database DB        Database name (or 'all' for all databases)

Connection:
    --host HOST          Database host (default: localhost)
    --port PORT          Database port (default: auto)
    --user USER          Database user (default: root)
    --password PASS      Database password (or use env var DB_PASSWORD)

Backup:
    --output DIR         Output directory (default: /tmp/db_backups)
    --compress METHOD    Compression: gzip, bzip2, xz, none (default: gzip)
    --encrypt            Encrypt backup with GPG (requires GPG key)
    --gpg-key KEY        GPG key ID for encryption

Retention:
    --retention DAYS     Keep backups for N days (default: 30)
    --max-backups N      Maximum number of backups to keep (default: 50)

Other:
    --verify             Verify backup integrity after creation
    --dry-run            Show what would be done
    --quiet              Suppress non-error output
    -h, --help           Show this help

Environment Variables:
    DB_PASSWORD          Database password (alternative to --password)
    GPG_KEY              GPG key ID for encryption

Examples:
    $SCRIPT_NAME --type mysql --database myapp --user admin
    $SCRIPT_NAME --type postgres --database all --compress xz
    $SCRIPT_NAME --type mysql --database shop --encrypt --retention 7
    $SCRIPT_NAME --type mysql --database mydb --dry-run
EOF
}

log_file=""
quiet=false

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date "$LOG_DATE_FMT")
    local message="[$timestamp] [$level] $*"

    if ! $quiet || [[ "$level" == "ERROR" ]]; then
        echo "$message"
    fi

    if [[ -n "$log_file" ]]; then
        echo "$message" >> "$log_file"
    fi
}

die() {
    log "ERROR" "$*"
    exit 1
}

format_size() {
    local size=$1
    if (( size >= 1073741824 )); then
        echo "$(echo "scale=2; $size / 1073741824" | bc) GB"
    elif (( size >= 1048576 )); then
        echo "$(echo "scale=2; $size / 1048576" | bc) MB"
    elif (( size >= 1024 )); then
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    else
        echo "${size} B"
    fi
}

format_duration() {
    local seconds=$1
    if (( seconds >= 3600 )); then
        printf "%dh %dm %ds" $(( seconds / 3600 )) $(( (seconds % 3600) / 60 )) $(( seconds % 60 ))
    elif (( seconds >= 60 )); then
        printf "%dm %ds" $(( seconds / 60 )) $(( seconds % 60 ))
    else
        printf "%ds" "$seconds"
    fi
}

check_mysql_tools() {
    if ! command -v mysqldump &>/dev/null; then
        die "mysqldump not found. Install mysql-client or mariadb-client."
    fi
}

check_postgres_tools() {
    if ! command -v pg_dump &>/dev/null; then
        die "pg_dump not found. Install postgresql-client."
    fi
}

get_default_port() {
    case "$1" in
        mysql)    echo "3306" ;;
        postgres) echo "5432" ;;
        *)        echo "" ;;
    esac
}

get_compress_extension() {
    case "$1" in
        gzip)  echo ".gz" ;;
        bzip2) echo ".bz2" ;;
        xz)    echo ".xz" ;;
        none)  echo "" ;;
        *)     echo ".gz" ;;
    esac
}

compress_file() {
    local file="$1"
    local method="$2"

    case "$method" in
        gzip)  gzip -9 "$file"; echo "${file}.gz" ;;
        bzip2) bzip2 -9 "$file"; echo "${file}.bz2" ;;
        xz)    xz -9 "$file"; echo "${file}.xz" ;;
        none)  echo "$file" ;;
        *)     gzip -9 "$file"; echo "${file}.gz" ;;
    esac
}

encrypt_file() {
    local file="$1"
    local gpg_key="$2"

    if ! command -v gpg &>/dev/null; then
        die "GPG not found. Install gnupg to use encryption."
    fi

    log "INFO" "Encrypting backup..."
    gpg --batch --yes --recipient "$gpg_key" --encrypt "$file" 2>/dev/null
    rm -f "$file"
    echo "${file}.gpg"
}

backup_mysql() {
    local database="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local output_dir="$6"
    local dry_run="$7"

    check_mysql_tools

    local backup_file
    if [[ "$database" == "all" ]]; then
        backup_file="${output_dir}/mysql_all_${BACKUP_TIMESTAMP}.sql"
    else
        backup_file="${output_dir}/mysql_${database}_${BACKUP_TIMESTAMP}.sql"
    fi

    local dump_args=(
        "--host=$host"
        "--port=$port"
        "--user=$user"
        "--single-transaction"
        "--routines"
        "--triggers"
        "--events"
        "--add-drop-database"
    )

    if [[ -n "$password" ]]; then
        dump_args+=("--password=$password")
    fi

    if $dry_run; then
        log "INFO" "[DRY RUN] Would run: mysqldump ${dump_args[*]} > $backup_file"
        echo "$backup_file"
        return 0
    fi

    log "INFO" "Starting MySQL dump: $database"

    if [[ "$database" == "all" ]]; then
        dump_args+=("--all-databases")
    else
        dump_args+=("$database")
    fi

    if mysqldump "${dump_args[@]}" > "$backup_file" 2>/dev/null; then
        log "INFO" "MySQL dump completed"
        echo "$backup_file"
    else
        die "MySQL dump failed for database: $database"
    fi
}

backup_postgres() {
    local database="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local output_dir="$6"
    local dry_run="$7"

    check_postgres_tools

    local backup_file
    if [[ "$database" == "all" ]]; then
        backup_file="${output_dir}/postgres_all_${BACKUP_TIMESTAMP}.sql"
    else
        backup_file="${output_dir}/postgres_${database}_${BACKUP_TIMESTAMP}.sql"
    fi

    if [[ -n "$password" ]]; then
        export PGPASSWORD="$password"
    fi

    if $dry_run; then
        log "INFO" "[DRY RUN] Would run: pg_dump -h $host -p $port -U $user $database > $backup_file"
        echo "$backup_file"
        return 0
    fi

    log "INFO" "Starting PostgreSQL dump: $database"

    local dump_ok=false
    if [[ "$database" == "all" ]]; then
        if pg_dumpall -h "$host" -p "$port" -U "$user" > "$backup_file" 2>/dev/null; then
            dump_ok=true
        fi
    else
        if pg_dump -h "$host" -p "$port" -U "$user" "$database" > "$backup_file" 2>/dev/null; then
            dump_ok=true
        fi
    fi

    if $dump_ok; then
        log "INFO" "PostgreSQL dump completed"
        echo "$backup_file"
    else
        die "PostgreSQL dump failed for database: $database"
    fi
}

verify_backup() {
    local backup_file="$1"
    local db_type="$2"

    log "INFO" "Verifying backup integrity..."

    if [[ ! -f "$backup_file" ]]; then
        die "Backup file not found: $backup_file"
    fi

    local file_size
    file_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
    if (( file_size == 0 )); then
        die "Backup file is empty!"
    fi

    # Verify compressed file integrity
    case "$backup_file" in
        *.gz)  gzip -t "$backup_file" 2>/dev/null || die "Gzip integrity check failed" ;;
        *.bz2) bzip2 -t "$backup_file" 2>/dev/null || die "Bzip2 integrity check failed" ;;
        *.xz)  xz -t "$backup_file" 2>/dev/null || die "XZ integrity check failed" ;;
    esac

    # Generate checksum
    local checksum
    if command -v sha256sum &>/dev/null; then
        checksum=$(sha256sum "$backup_file" | cut -d' ' -f1)
        echo "$checksum  $(basename "$backup_file")" > "${backup_file}.sha256"
        log "INFO" "SHA256: $checksum"
    elif command -v md5sum &>/dev/null; then
        checksum=$(md5sum "$backup_file" | cut -d' ' -f1)
        echo "$checksum  $(basename "$backup_file")" > "${backup_file}.md5"
        log "INFO" "MD5: $checksum"
    fi

    log "INFO" "Backup verification passed ($(format_size "$file_size"))"
}

rotate_backups() {
    local output_dir="$1"
    local retention_days="$2"
    local max_backups="$3"
    local db_type="$4"
    local dry_run="$5"

    log "INFO" "Applying retention policy..."

    # Delete backups older than retention days
    local old_count=0
    while IFS= read -r -d '' old_file; do
        if $dry_run; then
            log "INFO" "[DRY RUN] Would delete (age): $(basename "$old_file")"
        else
            rm -f "$old_file" "${old_file}.sha256" "${old_file}.md5"
            log "INFO" "Deleted old backup: $(basename "$old_file")"
        fi
        (( old_count++ ))
    done < <(find "$output_dir" -name "${db_type}_*" -type f -mtime +"$retention_days" -print0 2>/dev/null)

    # Enforce max backups count
    local current_count
    current_count=$(find "$output_dir" -name "${db_type}_*" -type f \
        ! -name "*.sha256" ! -name "*.md5" 2>/dev/null | wc -l)

    if (( current_count > max_backups )); then
        local to_delete=$(( current_count - max_backups ))
        find "$output_dir" -name "${db_type}_*" -type f \
            ! -name "*.sha256" ! -name "*.md5" 2>/dev/null \
            | sort \
            | head -"$to_delete" \
            | while read -r excess; do
                if $dry_run; then
                    log "INFO" "[DRY RUN] Would delete (excess): $(basename "$excess")"
                else
                    rm -f "$excess" "${excess}.sha256" "${excess}.md5"
                    log "INFO" "Deleted excess backup: $(basename "$excess")"
                fi
            done
    fi

    local remaining
    remaining=$(find "$output_dir" -name "${db_type}_*" -type f \
        ! -name "*.sha256" ! -name "*.md5" 2>/dev/null | wc -l)
    log "INFO" "Rotation complete: $old_count old + excess removed, $remaining remaining"
}

generate_report() {
    local db_type="$1"
    local database="$2"
    local backup_file="$3"
    local start_time="$4"
    local output_dir="$5"

    local end_time
    end_time=$(date +%s)
    local duration=$(( end_time - start_time ))

    local file_size=0
    if [[ -f "$backup_file" ]]; then
        file_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
    fi

    local total_backups
    total_backups=$(find "$output_dir" -name "${db_type}_*" -type f \
        ! -name "*.sha256" ! -name "*.md5" 2>/dev/null | wc -l)

    local total_size
    total_size=$(find "$output_dir" -name "${db_type}_*" -type f \
        ! -name "*.sha256" ! -name "*.md5" -exec stat -c%s {} + 2>/dev/null \
        | awk '{sum+=$1} END {print sum+0}')

    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║          DATABASE BACKUP REPORT              ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "  Database Type:  $db_type"
    echo "  Database:       $database"
    echo "  Backup File:    $(basename "$backup_file")"
    echo "  File Size:      $(format_size "$file_size")"
    echo "  Duration:       $(format_duration "$duration")"
    echo "  Status:         SUCCESS"
    echo "  Timestamp:      $(date "$LOG_DATE_FMT")"
    echo ""
    echo "  Total Backups:  $total_backups"
    echo "  Total Size:     $(format_size "$total_size")"
    echo "  Output Dir:     $output_dir"
    echo ""
    echo "══════════════════════════════════════════════"
}

main() {
    local db_type=""
    local database=""
    local host="localhost"
    local port=""
    local user="root"
    local password="${DB_PASSWORD:-}"
    local output_dir="/tmp/db_backups"
    local compress_method="gzip"
    local do_encrypt=false
    local gpg_key="${GPG_KEY:-}"
    local retention_days=30
    local max_backups=50
    local do_verify=false
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)         db_type="$2"; shift 2 ;;
            --database)     database="$2"; shift 2 ;;
            --host)         host="$2"; shift 2 ;;
            --port)         port="$2"; shift 2 ;;
            --user)         user="$2"; shift 2 ;;
            --password)     password="$2"; shift 2 ;;
            --output)       output_dir="$2"; shift 2 ;;
            --compress)     compress_method="$2"; shift 2 ;;
            --encrypt)      do_encrypt=true; shift ;;
            --gpg-key)      gpg_key="$2"; shift 2 ;;
            --retention)    retention_days="$2"; shift 2 ;;
            --max-backups)  max_backups="$2"; shift 2 ;;
            --verify)       do_verify=true; shift ;;
            --dry-run)      dry_run=true; shift ;;
            --quiet)        quiet=true; shift ;;
            -h|--help)      usage; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    [[ -n "$db_type" ]] || die "Database type is required (--type mysql|postgres)"
    [[ -n "$database" ]] || die "Database name is required (--database)"

    if [[ -z "$port" ]]; then
        port=$(get_default_port "$db_type")
    fi

    mkdir -p "$output_dir"
    log_file="${output_dir}/backup.log"

    local start_time
    start_time=$(date +%s)

    log "INFO" "═══════════════════════════════════════"
    log "INFO" "Database backup started"
    log "INFO" "Type: $db_type | DB: $database | Host: $host:$port"
    $dry_run && log "INFO" "*** DRY RUN MODE ***"

    # Perform the backup
    local backup_file=""
    case "$db_type" in
        mysql)
            backup_file=$(backup_mysql "$database" "$host" "$port" "$user" "$password" "$output_dir" "$dry_run")
            ;;
        postgres)
            backup_file=$(backup_postgres "$database" "$host" "$port" "$user" "$password" "$output_dir" "$dry_run")
            ;;
        *)
            die "Unsupported database type: $db_type (use mysql or postgres)"
            ;;
    esac

    # Compress
    if [[ "$compress_method" != "none" && -f "$backup_file" ]] && ! $dry_run; then
        log "INFO" "Compressing with $compress_method..."
        backup_file=$(compress_file "$backup_file" "$compress_method")
        log "INFO" "Compressed: $(basename "$backup_file")"
    fi

    # Encrypt
    if $do_encrypt && [[ -n "$gpg_key" ]] && ! $dry_run; then
        backup_file=$(encrypt_file "$backup_file" "$gpg_key")
        log "INFO" "Encrypted: $(basename "$backup_file")"
    fi

    # Verify
    if $do_verify && ! $dry_run; then
        verify_backup "$backup_file" "$db_type"
    fi

    # Rotate
    rotate_backups "$output_dir" "$retention_days" "$max_backups" "$db_type" "$dry_run"

    generate_report "$db_type" "$database" "$backup_file" "$start_time" "$output_dir"

    log "INFO" "Database backup completed successfully"
}

main "$@"
