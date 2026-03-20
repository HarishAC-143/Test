#!/usr/bin/env bash
#
# 06_health_monitor.sh — Monitors endpoints and reports their status
#
# Usage: ./06_health_monitor.sh [url1 url2 ...]
#
# If no URLs are supplied, a default set is used for demonstration.
#

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

TIMEOUT=10
LOGFILE="/tmp/health_monitor.log"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"
}

check_endpoint() {
    local url=$1
    local start end status duration

    start=$(date +%s%N)
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))

    local color="$RED"
    local label="DOWN"
    if [[ "$status" =~ ^2 ]]; then
        color="$GREEN"
        label="UP"
    elif [[ "$status" =~ ^3 ]]; then
        color="$YELLOW"
        label="REDIRECT"
    fi

    printf "  ${color}%-12s${NC} %-45s HTTP %-3s  %4dms\n" "[$label]" "$url" "$status" "$duration"
    log "$label $url HTTP=$status ${duration}ms"
}

echo "================================"
echo "  Service Health Monitor"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================"
echo ""

if [[ $# -gt 0 ]]; then
    for url in "$@"; do
        check_endpoint "$url"
    done
else
    default_urls=(
        "https://www.google.com"
        "https://github.com"
        "https://example.com"
    )
    for url in "${default_urls[@]}"; do
        check_endpoint "$url"
    done
fi

echo ""
echo "Log: $LOGFILE"
