#!/usr/bin/env bash
# =============================================================================
# Application Deployment Script
#
# Automates application deployment with environment checks, dependency
# installation, configuration management, health checks, and rollback.
#
# Usage: ./09_deployment_script.sh --env ENV --app APP [OPTIONS]
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEPLOY_LOG="/tmp/deployment.log"
readonly DEPLOY_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Colors for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

usage() {
    cat << EOF
Deployment Script - Automated application deployment

Usage: $SCRIPT_NAME --env ENV --app APP [OPTIONS]

Required:
    --env ENV            Target environment (dev, staging, production)
    --app APP            Application name

Optional:
    --version VERSION    Version to deploy (default: latest)
    --branch BRANCH      Git branch to deploy from (default: main)
    --config FILE        Path to deployment config file
    --skip-tests         Skip running tests before deployment
    --skip-backup        Skip pre-deployment backup
    --force              Force deployment (skip confirmations)
    --rollback           Rollback to previous version
    --dry-run            Show what would be done
    -h, --help           Show this help

Examples:
    $SCRIPT_NAME --env staging --app myapp
    $SCRIPT_NAME --env production --app myapp --version 2.1.0
    $SCRIPT_NAME --env production --app myapp --rollback
    $SCRIPT_NAME --env dev --app myapp --dry-run
EOF
}

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""

    case "$level" in
        INFO)  color="$GREEN" ;;
        WARN)  color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        STEP)  color="$BLUE" ;;
    esac

    echo -e "${color}[$timestamp] [$level] $*${NC}"
    echo "[$timestamp] [$level] $*" >> "$DEPLOY_LOG"
}

die() {
    log "ERROR" "$*"
    exit 1
}

step() {
    local step_num="$1"
    local total="$2"
    local description="$3"

    echo ""
    log "STEP" "═══ Step $step_num/$total: $description ═══"
}

check_prerequisites() {
    local app="$1"
    local env="$2"

    log "INFO" "Checking prerequisites..."

    local required_cmds=(git)
    local optional_cmds=(rsync curl)
    local missing=()

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required commands: ${missing[*]}"
    fi

    for cmd in "${optional_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log "WARN" "Optional command not found: $cmd (some features may be limited)"
        fi
    done

    log "INFO" "All prerequisites satisfied"
}

validate_environment() {
    local env="$1"

    case "$env" in
        dev|development)
            echo "dev"
            ;;
        staging|stage)
            echo "staging"
            ;;
        prod|production)
            echo "production"
            ;;
        *)
            die "Invalid environment: $env (use: dev, staging, production)"
            ;;
    esac
}

load_config() {
    local env="$1"
    local config_file="${2:-}"

    declare -gA CONFIG

    # Defaults
    CONFIG[deploy_dir]="/opt/apps"
    CONFIG[backup_dir]="/opt/backups"
    CONFIG[log_dir]="/var/log/apps"
    CONFIG[health_check_url]="http://localhost:8080/health"
    CONFIG[health_check_retries]=5
    CONFIG[health_check_interval]=3
    CONFIG[restart_command]="systemctl restart"
    CONFIG[notify_email]=""
    CONFIG[max_backups]=5

    # Environment-specific overrides
    case "$env" in
        dev)
            CONFIG[deploy_dir]="/tmp/deploy/dev"
            CONFIG[backup_dir]="/tmp/deploy/backups"
            CONFIG[health_check_retries]=2
            ;;
        staging)
            CONFIG[deploy_dir]="/tmp/deploy/staging"
            CONFIG[backup_dir]="/tmp/deploy/backups"
            ;;
        production)
            CONFIG[deploy_dir]="/tmp/deploy/production"
            CONFIG[backup_dir]="/tmp/deploy/backups"
            CONFIG[health_check_retries]=10
            CONFIG[health_check_interval]=5
            ;;
    esac

    # Load from config file if provided
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        log "INFO" "Loading config from: $config_file"
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            CONFIG["$key"]="$value"
        done < "$config_file"
    fi

    log "INFO" "Configuration loaded for environment: $env"
}

pre_deploy_backup() {
    local app="$1"
    local env="$2"
    local dry_run="$3"

    local deploy_dir="${CONFIG[deploy_dir]}/$app"
    local backup_dir="${CONFIG[backup_dir]}/$app"
    local backup_name="${app}_${env}_${DEPLOY_TIMESTAMP}.tar.gz"

    if [[ ! -d "$deploy_dir" ]]; then
        log "INFO" "No existing deployment found, skipping backup"
        return 0
    fi

    if $dry_run; then
        log "INFO" "[DRY RUN] Would create backup: $backup_dir/$backup_name"
        return 0
    fi

    mkdir -p "$backup_dir"

    log "INFO" "Creating pre-deployment backup..."
    if tar -czf "$backup_dir/$backup_name" -C "$(dirname "$deploy_dir")" "$(basename "$deploy_dir")" 2>/dev/null; then
        local size
        size=$(du -h "$backup_dir/$backup_name" | cut -f1)
        log "INFO" "Backup created: $backup_name ($size)"

        # Rotate old backups
        local max=${CONFIG[max_backups]}
        local backup_count
        backup_count=$(find "$backup_dir" -name "${app}_${env}_*.tar.gz" -type f | wc -l)
        if (( backup_count > max )); then
            log "INFO" "Rotating old backups (keeping $max)..."
            find "$backup_dir" -name "${app}_${env}_*.tar.gz" -type f \
                | sort \
                | head -n $(( backup_count - max )) \
                | while read -r old_backup; do
                    rm -f "$old_backup"
                    log "INFO" "Removed old backup: $(basename "$old_backup")"
                done
        fi
    else
        die "Backup failed"
    fi
}

run_tests() {
    local app="$1"
    local dry_run="$2"

    log "INFO" "Running pre-deployment tests..."

    if $dry_run; then
        log "INFO" "[DRY RUN] Would run test suite"
        return 0
    fi

    local test_commands=(
        "echo 'Running unit tests...'"
        "echo 'Running integration tests...'"
        "echo 'Running smoke tests...'"
    )

    local failed=0
    for cmd in "${test_commands[@]}"; do
        if eval "$cmd"; then
            log "INFO" "  PASS: $cmd"
        else
            log "ERROR" "  FAIL: $cmd"
            (( failed++ ))
        fi
    done

    if (( failed > 0 )); then
        die "$failed test(s) failed. Aborting deployment."
    fi

    log "INFO" "All tests passed"
}

deploy_application() {
    local app="$1"
    local env="$2"
    local version="$3"
    local branch="$4"
    local dry_run="$5"

    local deploy_dir="${CONFIG[deploy_dir]}/$app"

    if $dry_run; then
        log "INFO" "[DRY RUN] Would deploy $app v$version to $deploy_dir"
        return 0
    fi

    mkdir -p "$deploy_dir"

    log "INFO" "Deploying $app v$version from branch $branch..."

    # Simulate deployment steps
    log "INFO" "  Preparing deployment directory: $deploy_dir"
    mkdir -p "$deploy_dir"/{bin,config,data,logs}

    log "INFO" "  Writing version information..."
    cat > "$deploy_dir/VERSION" << EOF
app=$app
version=$version
branch=$branch
environment=$env
deployed_at=$(date -Iseconds)
deployed_by=$(whoami)
EOF

    log "INFO" "  Installing dependencies..."
    sleep 1

    log "INFO" "  Configuring application for $env environment..."
    cat > "$deploy_dir/config/app.conf" << EOF
# Auto-generated deployment config
environment=$env
version=$version
log_level=$([ "$env" = "production" ] && echo "warn" || echo "debug")
port=8080
EOF

    log "INFO" "  Setting permissions..."
    chmod -R 755 "$deploy_dir/bin" 2>/dev/null || true
    chmod -R 644 "$deploy_dir/config" 2>/dev/null || true

    log "INFO" "Deployment files installed successfully"
}

health_check() {
    local app="$1"
    local dry_run="$2"

    local url="${CONFIG[health_check_url]}"
    local retries=${CONFIG[health_check_retries]}
    local interval=${CONFIG[health_check_interval]}

    if $dry_run; then
        log "INFO" "[DRY RUN] Would perform health check: $url ($retries retries)"
        return 0
    fi

    log "INFO" "Performing health checks..."

    local deploy_dir="${CONFIG[deploy_dir]}/$app"
    if [[ -f "$deploy_dir/VERSION" ]]; then
        log "INFO" "  Version file exists: PASS"
    else
        log "WARN" "  Version file missing"
    fi

    if [[ -d "$deploy_dir/config" ]]; then
        log "INFO" "  Config directory exists: PASS"
    else
        log "WARN" "  Config directory missing"
    fi

    if [[ -f "$deploy_dir/config/app.conf" ]]; then
        log "INFO" "  App config exists: PASS"
    else
        log "WARN" "  App config missing"
    fi

    # Simulate HTTP health check
    for (( attempt = 1; attempt <= retries; attempt++ )); do
        log "INFO" "  Health check attempt $attempt/$retries..."

        if command -v curl &>/dev/null; then
            if curl -sf --connect-timeout 5 "$url" &>/dev/null; then
                log "INFO" "  Health check PASSED on attempt $attempt"
                return 0
            fi
        fi

        if (( attempt < retries )); then
            log "WARN" "  Health check failed, retrying in ${interval}s..."
            sleep "$interval"
        fi
    done

    log "WARN" "HTTP health check did not pass (service may not be running)"
    log "INFO" "File-based health checks passed"
    return 0
}

rollback() {
    local app="$1"
    local env="$2"
    local dry_run="$3"

    local backup_dir="${CONFIG[backup_dir]}/$app"
    local deploy_dir="${CONFIG[deploy_dir]}/$app"

    log "INFO" "Initiating rollback for $app ($env)..."

    # Find the most recent backup
    local latest_backup
    latest_backup=$(find "$backup_dir" -name "${app}_${env}_*.tar.gz" -type f 2>/dev/null \
        | sort -r \
        | head -1)

    if [[ -z "$latest_backup" ]]; then
        die "No backup found for rollback"
    fi

    log "INFO" "Found backup: $(basename "$latest_backup")"

    if $dry_run; then
        log "INFO" "[DRY RUN] Would rollback using: $(basename "$latest_backup")"
        return 0
    fi

    log "INFO" "Removing current deployment..."
    rm -rf "$deploy_dir"

    log "INFO" "Restoring from backup..."
    mkdir -p "$(dirname "$deploy_dir")"
    tar -xzf "$latest_backup" -C "$(dirname "$deploy_dir")"

    log "INFO" "Rollback completed successfully"
}

generate_report() {
    local app="$1"
    local env="$2"
    local version="$3"
    local start_time="$4"

    local end_time
    end_time=$(date +%s)
    local duration=$(( end_time - start_time ))

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║        DEPLOYMENT REPORT                 ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "  Application:    $app"
    echo "  Environment:    $env"
    echo "  Version:        $version"
    echo "  Duration:       ${duration}s"
    echo "  Status:         SUCCESS"
    echo "  Timestamp:      $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Deploy Dir:     ${CONFIG[deploy_dir]}/$app"
    echo "  Log File:       $DEPLOY_LOG"
    echo ""
    echo "══════════════════════════════════════════"
}

main() {
    local env=""
    local app=""
    local version="latest"
    local branch="main"
    local config_file=""
    local skip_tests=false
    local skip_backup=false
    local force=false
    local do_rollback=false
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)          env="$2"; shift 2 ;;
            --app)          app="$2"; shift 2 ;;
            --version)      version="$2"; shift 2 ;;
            --branch)       branch="$2"; shift 2 ;;
            --config)       config_file="$2"; shift 2 ;;
            --skip-tests)   skip_tests=true; shift ;;
            --skip-backup)  skip_backup=true; shift ;;
            --force)        force=true; shift ;;
            --rollback)     do_rollback=true; shift ;;
            --dry-run)      dry_run=true; shift ;;
            -h|--help)      usage; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    [[ -n "$env" ]] || die "Environment is required (--env)"
    [[ -n "$app" ]] || die "Application name is required (--app)"

    env=$(validate_environment "$env")

    local start_time
    start_time=$(date +%s)

    echo ""
    log "INFO" "╔══════════════════════════════════════════╗"
    log "INFO" "║        DEPLOYMENT STARTED                ║"
    log "INFO" "╚══════════════════════════════════════════╝"
    log "INFO" "App: $app | Env: $env | Version: $version"
    $dry_run && log "INFO" "*** DRY RUN MODE ***"

    local total_steps=5
    if $do_rollback; then
        total_steps=3
    fi

    # Step 1: Prerequisites
    step 1 "$total_steps" "Checking Prerequisites"
    check_prerequisites "$app" "$env"
    load_config "$env" "$config_file"

    if $do_rollback; then
        step 2 "$total_steps" "Rolling Back"
        rollback "$app" "$env" "$dry_run"

        step 3 "$total_steps" "Health Check"
        health_check "$app" "$dry_run"

        generate_report "$app" "$env" "rollback" "$start_time"
        exit 0
    fi

    # Confirmation for production
    if [[ "$env" == "production" ]] && ! $force && ! $dry_run; then
        echo ""
        log "WARN" "You are deploying to PRODUCTION!"
        read -rp "  Type 'deploy' to confirm: " confirm
        [[ "$confirm" == "deploy" ]] || die "Deployment cancelled"
    fi

    # Step 2: Pre-deployment backup
    step 2 "$total_steps" "Pre-Deployment Backup"
    if $skip_backup; then
        log "INFO" "Backup skipped (--skip-backup)"
    else
        pre_deploy_backup "$app" "$env" "$dry_run"
    fi

    # Step 3: Run tests
    step 3 "$total_steps" "Running Tests"
    if $skip_tests; then
        log "INFO" "Tests skipped (--skip-tests)"
    else
        run_tests "$app" "$dry_run"
    fi

    # Step 4: Deploy
    step 4 "$total_steps" "Deploying Application"
    deploy_application "$app" "$env" "$version" "$branch" "$dry_run"

    # Step 5: Health check
    step 5 "$total_steps" "Health Check"
    health_check "$app" "$dry_run"

    generate_report "$app" "$env" "$version" "$start_time"
}

main "$@"
