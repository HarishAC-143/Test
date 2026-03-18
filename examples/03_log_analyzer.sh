#!/usr/bin/env bash
# =============================================================================
# Log Analyzer
#
# Parses log files to extract statistics, filter by severity, find patterns,
# and generate summary reports.
#
# Usage: ./03_log_analyzer.sh LOGFILE [OPTIONS]
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

declare -A SEVERITY_COLORS=(
    [ERROR]="\033[31m"     # Red
    [WARN]="\033[33m"      # Yellow
    [INFO]="\033[32m"      # Green
    [DEBUG]="\033[36m"     # Cyan
)
readonly RESET="\033[0m"

usage() {
    cat << EOF
Log Analyzer - Parse and summarize log files

Usage: $SCRIPT_NAME LOGFILE [OPTIONS]

Options:
    -l, --level LEVEL    Filter by minimum severity (DEBUG, INFO, WARN, ERROR)
    -s, --start DATE     Filter entries after DATE (YYYY-MM-DD or YYYY-MM-DD HH:MM:SS)
    -e, --end DATE       Filter entries before DATE
    -p, --pattern REGEX  Search for a pattern in log messages
    -t, --top N          Show top N most frequent messages (default: 10)
    --summary            Show summary statistics only
    --no-color           Disable colored output
    -h, --help           Show this help

Examples:
    $SCRIPT_NAME /var/log/syslog --summary
    $SCRIPT_NAME app.log -l ERROR -t 20
    $SCRIPT_NAME app.log -p "timeout|connection refused"
    $SCRIPT_NAME app.log -s "2026-03-01" -e "2026-03-18"
EOF
}

severity_rank() {
    case "${1^^}" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN*) echo 2 ;;
        ERROR) echo 3 ;;
        FATAL|CRITICAL) echo 4 ;;
        *) echo -1 ;;
    esac
}

colorize_severity() {
    local level="${1^^}"
    local use_color="$2"
    if $use_color && [[ -n "${SEVERITY_COLORS[$level]+x}" ]]; then
        echo -e "${SEVERITY_COLORS[$level]}${level}${RESET}"
    else
        echo "$level"
    fi
}

count_by_severity() {
    local log_file="$1"
    echo "Severity Breakdown:"
    echo "  -----------------------------------------------"

    local total=0
    for level in ERROR WARN INFO DEBUG; do
        local count
        count=$(grep -ci "\b${level}\b" "$log_file" 2>/dev/null || echo 0)
        local bar
        bar=$(printf '#%.0s' $(seq 1 $(( count > 50 ? 50 : (count == 0 ? 0 : count) )) ) 2>/dev/null || true)
        printf "  %-8s %6d  %s\n" "$level" "$count" "$bar"
        total=$(( total + count ))
    done

    echo "  -----------------------------------------------"
    printf "  %-8s %6d\n" "TOTAL" "$total"
}

top_messages() {
    local log_file="$1"
    local top_n="$2"

    echo ""
    echo "Top ${top_n} Most Frequent Messages:"
    echo "  -----------------------------------------------"

    # Extract the message portion (after the severity level)
    grep -oP '(ERROR|WARN|INFO|DEBUG)\s+\K.*' "$log_file" 2>/dev/null \
        | sort \
        | uniq -c \
        | sort -rn \
        | head -"$top_n" \
        | while read -r count message; do
            printf "  %6d  %s\n" "$count" "${message:0:60}"
        done

    if [[ $(grep -oP '(ERROR|WARN|INFO|DEBUG)\s+\K.*' "$log_file" 2>/dev/null | wc -l) -eq 0 ]]; then
        # Fallback for non-standard log formats
        sort "$log_file" \
            | uniq -c \
            | sort -rn \
            | head -"$top_n" \
            | while read -r count message; do
                printf "  %6d  %s\n" "$count" "${message:0:60}"
            done
    fi
}

hourly_distribution() {
    local log_file="$1"

    echo ""
    echo "Hourly Distribution:"
    echo "  -----------------------------------------------"

    for hour in $(seq -w 0 23); do
        local count
        count=$(grep -c "\b${hour}:" "$log_file" 2>/dev/null || echo 0)
        local bar_len=$(( count / 5 ))
        (( bar_len == 0 && count > 0 )) && bar_len=1
        local bar
        bar=$(printf '#%.0s' $(seq 1 "$bar_len") 2>/dev/null || true)
        printf "  %s:00  %5d  %s\n" "$hour" "$count" "$bar"
    done
}

filter_and_display() {
    local log_file="$1"
    local min_level="$2"
    local start_date="$3"
    local end_date="$4"
    local pattern="$5"
    local use_color="$6"

    local min_rank
    min_rank=$(severity_rank "$min_level")

    local line_count=0
    local match_count=0

    while IFS= read -r line; do
        (( line_count++ ))

        # Extract severity if present
        local severity=""
        if [[ "$line" =~ (ERROR|WARN|WARNING|INFO|DEBUG|FATAL|CRITICAL) ]]; then
            severity="${BASH_REMATCH[1]}"
        fi

        # Filter by severity
        if [[ -n "$severity" && -n "$min_level" ]]; then
            local rank
            rank=$(severity_rank "$severity")
            if (( rank < min_rank )); then
                continue
            fi
        fi

        # Filter by pattern
        if [[ -n "$pattern" ]]; then
            if ! echo "$line" | grep -qiP "$pattern"; then
                continue
            fi
        fi

        # Filter by date range (basic: checks if date string is in line)
        if [[ -n "$start_date" ]]; then
            local line_date
            line_date=$(echo "$line" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
            if [[ -n "$line_date" && "$line_date" < "$start_date" ]]; then
                continue
            fi
        fi
        if [[ -n "$end_date" ]]; then
            local line_date
            line_date=$(echo "$line" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
            if [[ -n "$line_date" && "$line_date" > "$end_date" ]]; then
                continue
            fi
        fi

        # Display the line (colorize severity if applicable)
        if [[ -n "$severity" ]] && $use_color; then
            echo -e "${line/$severity/$(colorize_severity "$severity" true)}"
        else
            echo "$line"
        fi

        (( match_count++ ))
    done < "$log_file"

    echo ""
    echo "--- Displayed $match_count of $line_count lines ---"
}

generate_summary() {
    local log_file="$1"
    local top_n="$2"

    local total_lines file_size first_entry last_entry
    total_lines=$(wc -l < "$log_file")
    file_size=$(du -h "$log_file" | cut -f1)
    first_entry=$(head -1 "$log_file")
    last_entry=$(tail -1 "$log_file")

    echo "=============================================="
    echo "  LOG FILE SUMMARY"
    echo "=============================================="
    echo "  File:         $log_file"
    echo "  Size:         $file_size"
    echo "  Total Lines:  $total_lines"
    echo "  First Entry:  ${first_entry:0:60}"
    echo "  Last Entry:   ${last_entry:0:60}"
    echo "=============================================="
    echo ""

    count_by_severity "$log_file"
    top_messages "$log_file" "$top_n"
    hourly_distribution "$log_file"

    echo ""
    echo "=============================================="
}

main() {
    local log_file=""
    local min_level=""
    local start_date=""
    local end_date=""
    local pattern=""
    local top_n=10
    local summary_only=false
    local use_color=true

    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    # First argument is the log file
    log_file="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--level)    min_level="$2"; shift 2 ;;
            -s|--start)    start_date="$2"; shift 2 ;;
            -e|--end)      end_date="$2"; shift 2 ;;
            -p|--pattern)  pattern="$2"; shift 2 ;;
            -t|--top)      top_n="$2"; shift 2 ;;
            --summary)     summary_only=true; shift ;;
            --no-color)    use_color=false; shift ;;
            -h|--help)     usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    [[ -f "$log_file" ]] || { echo "Error: File not found: $log_file" >&2; exit 1; }

    if $summary_only; then
        generate_summary "$log_file" "$top_n"
    else
        filter_and_display "$log_file" "$min_level" "$start_date" "$end_date" "$pattern" "$use_color"
    fi
}

main "$@"
