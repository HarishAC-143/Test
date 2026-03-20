#!/bin/bash
set -euo pipefail
# Practical example: Log File Analyzer
# Generates a sample log, then analyzes it for patterns and statistics

DEMO_DIR=$(mktemp -d)
trap 'rm -rf "$DEMO_DIR"' EXIT

LOG_FILE="$DEMO_DIR/application.log"

generate_sample_log() {
    local levels=("INFO" "WARN" "ERROR" "DEBUG")
    local messages_info=(
        "Request processed successfully"
        "User session started"
        "Cache hit for key users:list"
        "Database query completed in 45ms"
        "File uploaded: report.pdf (2.3MB)"
        "API response sent: 200 OK"
    )
    local messages_warn=(
        "Slow query detected: 2500ms"
        "Disk usage at 87%"
        "Connection pool near capacity: 45/50"
        "Deprecated API endpoint called: /v1/users"
        "Rate limit approaching for client 192.168.1.50"
    )
    local messages_error=(
        "Database connection refused: timeout after 30s"
        "Failed to parse JSON payload"
        "Authentication failed for user admin"
        "Out of memory: heap allocation failed"
        "File not found: /data/config.yaml"
    )

    for i in $(seq 1 100); do
        local hour=$(( RANDOM % 24 ))
        local minute=$(( RANDOM % 60 ))
        local second=$(( RANDOM % 60 ))
        local timestamp
        timestamp=$(printf "2026-03-20 %02d:%02d:%02d" "$hour" "$minute" "$second")

        local rand=$(( RANDOM % 100 ))
        if (( rand < 50 )); then
            level="INFO"
            msg="${messages_info[$(( RANDOM % ${#messages_info[@]} ))]}"
        elif (( rand < 75 )); then
            level="DEBUG"
            msg="Debug trace: checkpoint $i"
        elif (( rand < 90 )); then
            level="WARN"
            msg="${messages_warn[$(( RANDOM % ${#messages_warn[@]} ))]}"
        else
            level="ERROR"
            msg="${messages_error[$(( RANDOM % ${#messages_error[@]} ))]}"
        fi

        echo "$timestamp [$level] $msg"
    done | sort > "$LOG_FILE"
}

echo "Generating sample log file..."
generate_sample_log
echo "Generated: $LOG_FILE ($(wc -l < "$LOG_FILE") lines)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║            LOG ANALYSIS REPORT                   ║"
echo "╠══════════════════════════════════════════════════╣"

total=$(wc -l < "$LOG_FILE")
echo "  Total log entries: $total"

echo ""
echo "  Log Level Distribution:"
for level in INFO DEBUG WARN ERROR; do
    count=$(grep -c "\[$level\]" "$LOG_FILE" || true)
    pct=0
    (( total > 0 )) && pct=$(( count * 100 / total ))
    bar=""
    for (( b = 0; b < pct / 2; b++ )); do bar+="█"; done
    printf "    %-7s: %3d (%2d%%) %s\n" "$level" "$count" "$pct" "$bar"
done

echo ""
echo "  Hourly Activity:"
awk '{split($2, t, ":"); hours[t[1]]++} END {
    for (h = 0; h < 24; h++) {
        hh = sprintf("%02d", h)
        count = (hh in hours) ? hours[hh] : 0
        bar = ""
        for (i = 0; i < count; i++) bar = bar "▓"
        printf "    %s:00  %3d %s\n", hh, count, bar
    }
}' "$LOG_FILE"

echo ""
echo "  Top 5 Error Messages:"
grep "\[ERROR\]" "$LOG_FILE" | \
    sed 's/.*\[ERROR\] //' | \
    sort | uniq -c | sort -rn | head -5 | \
    while read -r count msg; do
        printf "    %3d × %s\n" "$count" "$msg"
    done

echo ""
echo "  Time Range:"
echo "    First entry: $(head -1 "$LOG_FILE" | awk '{print $1, $2}')"
echo "    Last entry:  $(tail -1 "$LOG_FILE" | awk '{print $1, $2}')"

error_count=$(grep -c "\[ERROR\]" "$LOG_FILE" || true)
if (( error_count > 10 )); then
    echo ""
    echo "  ⚠ WARNING: High error rate detected ($error_count errors)"
fi

echo "╚══════════════════════════════════════════════════╝"
