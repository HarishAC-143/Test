#!/bin/bash
# Log File Analyzer — parses Apache/Nginx access logs and produces a summary report
# Usage: ./01_log_analyzer.sh [-n top_count] [-s start_date] [-e end_date] logfile
#        ./01_log_analyzer.sh --demo   (generate sample data and analyze it)

set -euo pipefail

TOP_N=10
START_DATE=""
END_DATE=""
DEMO_MODE=false

usage() {
    cat << EOF
Log File Analyzer — Analyze Apache/Nginx access logs

Usage: $(basename "$0") [OPTIONS] LOGFILE
       $(basename "$0") --demo

Options:
    -n NUM    Show top NUM results (default: 10)
    -s DATE   Start date filter (format: DD/Mon/YYYY)
    -e DATE   End date filter (format: DD/Mon/YYYY)
    --demo    Generate sample log data and run analysis
    -h        Show this help

Example:
    $(basename "$0") -n 20 /var/log/nginx/access.log
    $(basename "$0") --demo
EOF
    exit 0
}

generate_demo_log() {
    local tmplog
    tmplog=$(mktemp)

    local ips=("192.168.1.100" "10.0.0.50" "172.16.0.1" "203.0.113.42" "198.51.100.7"
               "192.168.1.101" "10.0.0.51" "172.16.0.2" "203.0.113.43" "198.51.100.8")
    local paths=("/index.html" "/about" "/api/users" "/api/products" "/login"
                 "/dashboard" "/api/orders" "/static/style.css" "/images/logo.png" "/health")
    local methods=("GET" "GET" "GET" "POST" "GET" "GET" "GET" "GET" "GET" "GET")
    local statuses=("200" "200" "200" "301" "404" "200" "500" "200" "200" "200")
    local agents=("Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "Mozilla/5.0 (Macintosh; Intel Mac OS X)" "curl/7.68.0" "python-requests/2.28.0" "Googlebot/2.1")

    for i in {1..200}; do
        local ip="${ips[$((RANDOM % ${#ips[@]}))]}"
        local path="${paths[$((RANDOM % ${#paths[@]}))]}"
        local method="${methods[$((RANDOM % ${#methods[@]}))]}"
        local status="${statuses[$((RANDOM % ${#statuses[@]}))]}"
        local agent="${agents[$((RANDOM % ${#agents[@]}))]}"
        local hour=$(printf "%02d" $((RANDOM % 24)))
        local minute=$(printf "%02d" $((RANDOM % 60)))
        local second=$(printf "%02d" $((RANDOM % 60)))
        local size=$((RANDOM % 50000 + 100))
        echo "$ip - - [20/Mar/2026:${hour}:${minute}:${second} +0000] \"$method $path HTTP/1.1\" $status $size \"-\" \"$agent\""
    done > "$tmplog"

    echo "$tmplog"
}

if [[ "${1:-}" == "--demo" ]]; then
    DEMO_MODE=true
    shift
fi

while getopts "n:s:e:h" opt 2>/dev/null; do
    case "$opt" in
        n) TOP_N="$OPTARG" ;;
        s) START_DATE="$OPTARG" ;;
        e) END_DATE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

if $DEMO_MODE; then
    echo "Generating demo log data..."
    LOGFILE=$(generate_demo_log)
    trap 'rm -f "$LOGFILE"' EXIT
else
    LOGFILE="${1:?Error: log file path required. Use -h for help or --demo for sample data.}"
    [[ -f "$LOGFILE" ]] || { echo "Error: '$LOGFILE' not found" >&2; exit 1; }
fi

total_lines=$(wc -l < "$LOGFILE")
unique_ips=$(awk '{print $1}' "$LOGFILE" | sort -u | wc -l)

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║           LOG FILE ANALYSIS REPORT                  ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  File:        %-38s ║\n" "$(basename "$LOGFILE")"
printf "║  Total Lines: %-38s ║\n" "$total_lines"
printf "║  Unique IPs:  %-38s ║\n" "$unique_ips"
echo "╚══════════════════════════════════════════════════════╝"
echo

echo "━━━ Top $TOP_N IP Addresses ━━━"
awk '{print $1}' "$LOGFILE" | sort | uniq -c | sort -rn | head -"$TOP_N" | \
    awk '{printf "  %-20s %6s requests\n", $2, $1}'
echo

echo "━━━ HTTP Status Code Distribution ━━━"
awk '{print $9}' "$LOGFILE" | grep -E '^[0-9]+$' | sort | uniq -c | sort -rn | \
    while read -r count code; do
        local_desc=""
        case "$code" in
            200) local_desc="OK" ;;
            301) local_desc="Moved" ;;
            302) local_desc="Found" ;;
            304) local_desc="Not Modified" ;;
            400) local_desc="Bad Request" ;;
            401) local_desc="Unauthorized" ;;
            403) local_desc="Forbidden" ;;
            404) local_desc="Not Found" ;;
            500) local_desc="Server Error" ;;
            502) local_desc="Bad Gateway" ;;
            503) local_desc="Unavailable" ;;
            *)   local_desc="" ;;
        esac
        printf "  HTTP %-4s %-15s %6s occurrences\n" "$code" "($local_desc)" "$count"
    done
echo

echo "━━━ Top $TOP_N Requested URLs ━━━"
awk '{print $7}' "$LOGFILE" | sort | uniq -c | sort -rn | head -"$TOP_N" | \
    awk '{printf "  %-40s %6s hits\n", $2, $1}'
echo

echo "━━━ HTTP Methods ━━━"
awk '{gsub(/"/, "", $6); print $6}' "$LOGFILE" | sort | uniq -c | sort -rn | \
    awk '{printf "  %-8s %6s requests\n", $2, $1}'
echo

echo "━━━ Requests by Hour ━━━"
awk -F'[\\[:]' '{print $3}' "$LOGFILE" | sort -n | uniq -c | \
    while read -r count hour; do
        bar=""
        bar_len=$((count / 5))
        (( bar_len > 40 )) && bar_len=40
        for ((i=0; i<bar_len; i++)); do bar+="█"; done
        printf "  %s:00  %4d  %s\n" "$hour" "$count" "$bar"
    done
echo

echo "━━━ Top $TOP_N User Agents ━━━"
awk -F'"' '{print $6}' "$LOGFILE" | sort | uniq -c | sort -rn | head -"$TOP_N" | \
    while read -r count agent; do
        printf "  %6s  %s\n" "$count" "$agent"
    done
echo

total_bytes=$(awk '{sum += $10} END {print int(sum)}' "$LOGFILE" 2>/dev/null || echo "0")
if [[ -n "$total_bytes" && "$total_bytes" != "0" ]]; then
    echo "━━━ Bandwidth Summary ━━━"
    if (( total_bytes > 1073741824 )); then
        printf "  Total transferred: %d GB\n" "$((total_bytes / 1073741824))"
    elif (( total_bytes > 1048576 )); then
        printf "  Total transferred: %d MB\n" "$((total_bytes / 1048576))"
    elif (( total_bytes > 1024 )); then
        printf "  Total transferred: %d KB\n" "$((total_bytes / 1024))"
    else
        printf "  Total transferred: %s bytes\n" "$total_bytes"
    fi
    echo
fi

echo "══════════════════════════════════════════════════════"
echo "  Report generated at $(date)"
echo "══════════════════════════════════════════════════════"
