#!/usr/bin/env bash
#
# 03_log_analyzer.sh — Parses log files and produces a summary report
#
# Usage: ./03_log_analyzer.sh <logfile>
#

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <logfile>"
    echo "Analyzes a log file and prints a summary report."
    exit 1
}

[[ $# -lt 1 ]] && usage
logfile="$1"
[[ -f "$logfile" ]] || { echo "File not found: $logfile" >&2; exit 1; }

total_lines=$(wc -l < "$logfile")

declare -A level_count
while IFS= read -r line; do
    for level in ERROR WARN INFO DEBUG; do
        if [[ "$line" == *"$level"* ]]; then
            ((level_count[$level]++)) || true
            break
        fi
    done
done < "$logfile"

echo "===== Log Analysis Report ====="
echo "File:        $logfile"
echo "Total lines: $total_lines"
echo ""
echo "--- Log Level Summary ---"
for level in ERROR WARN INFO DEBUG; do
    count="${level_count[$level]:-0}"
    pct=0
    (( total_lines > 0 )) && pct=$(awk "BEGIN {printf \"%.1f\", ($count/$total_lines)*100}")
    printf "  %-8s %6d  (%s%%)\n" "$level" "$count" "$pct"
done

echo ""
echo "--- Most Recent Errors (last 10) ---"
grep "ERROR" "$logfile" 2>/dev/null | tail -10 | while IFS= read -r line; do
    echo "  $line"
done || echo "  (No errors found)"

echo ""
echo "--- Hourly Distribution ---"
if grep -oP '\d{2}:\d{2}:\d{2}' "$logfile" &>/dev/null; then
    grep -oP '\d{2}(?=:\d{2}:\d{2})' "$logfile" | sort | uniq -c | sort -rn | head -10 | \
        while read -r cnt hour; do
            printf "  %s:00  %d entries\n" "$hour" "$cnt"
        done
else
    echo "  (No timestamp pattern detected)"
fi

echo ""
echo "Report generated at $(date)"
