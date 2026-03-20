#!/bin/bash
# System Health Monitor — CPU, memory, disk usage with alerting thresholds
# Usage: ./02_system_monitor.sh [-i interval] [-c cpu%] [-m mem%] [-d disk%]

set -euo pipefail

INTERVAL=5
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=90
REPORT_FILE="/tmp/system_health_$(date +%Y%m%d).log"
ITERATIONS=0
MAX_ITERATIONS="${MAX_ITER:-3}"

usage() {
    cat << EOF
System Health Monitor

Usage: $(basename "$0") [OPTIONS]

Options:
    -i SEC   Check interval in seconds (default: 5)
    -c PCT   CPU alert threshold % (default: 80)
    -m PCT   Memory alert threshold % (default: 80)
    -d PCT   Disk alert threshold % (default: 90)
    -h       Show this help

Environment:
    MAX_ITER   Maximum iterations (default: 3, 0 = infinite)
EOF
    exit 0
}

while getopts "i:c:m:d:h" opt; do
    case "$opt" in
        i) INTERVAL="$OPTARG" ;;
        c) CPU_THRESHOLD="$OPTARG" ;;
        m) MEM_THRESHOLD="$OPTARG" ;;
        d) DISK_THRESHOLD="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

log_msg() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] %s\n" "$timestamp" "$*" | tee -a "$REPORT_FILE"
}

alert() {
    printf "\033[31m[ALERT]\033[0m %s\n" "$*"
    log_msg "ALERT: $*"
}

get_cpu_usage() {
    if [[ -f /proc/stat ]]; then
        local cpu_line1 cpu_line2
        cpu_line1=$(head -1 /proc/stat)
        sleep 0.5
        cpu_line2=$(head -1 /proc/stat)

        read -ra c1 <<< "$cpu_line1"
        read -ra c2 <<< "$cpu_line2"

        local idle1=${c1[4]} idle2=${c2[4]}
        local total1=0 total2=0

        for i in {1..7}; do
            (( total1 += ${c1[$i]:-0} ))
            (( total2 += ${c2[$i]:-0} ))
        done

        local total_diff=$(( total2 - total1 ))
        local idle_diff=$(( idle2 - idle1 ))

        if (( total_diff > 0 )); then
            echo $(( 100 * (total_diff - idle_diff) / total_diff ))
        else
            echo "0"
        fi
    else
        echo "N/A"
    fi
}

get_memory_info() {
    if [[ -f /proc/meminfo ]]; then
        awk '/MemTotal/{total=$2} /MemAvailable/{avail=$2}
             END {
                 if (total > 0) {
                     used=total-avail
                     pct=int(used*100/total)
                     printf "%d %d %d", int(total/1024), int(used/1024), pct
                 } else {
                     printf "0 0 0"
                 }
             }' /proc/meminfo
    else
        echo "0 0 0"
    fi
}

get_disk_usage() {
    df / 2>/dev/null | awk 'NR==2 {
        gsub(/%/,"",$5)
        printf "%s %s %s %s", $2, $3, $4, $5
    }'
}

get_load_average() {
    if [[ -f /proc/loadavg ]]; then
        awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg
    else
        uptime | awk -F'load average:' '{print $2}' | tr -d ' '
    fi
}

display_bar() {
    local pct="$1"
    local width=30
    [[ "$pct" == "N/A" ]] && { printf "N/A"; return; }

    local filled=$(( pct * width / 100 ))
    (( filled > width )) && filled=$width
    (( filled < 0 )) && filled=0
    local empty=$(( width - filled ))
    local color

    if (( pct >= 90 )); then color="\033[31m"
    elif (( pct >= 70 )); then color="\033[33m"
    else color="\033[32m"
    fi

    printf "${color}["
    for ((i=0; i<filled; i++)); do printf "#"; done
    for ((i=0; i<empty; i++)); do printf "-"; done
    printf "] %3d%%\033[0m" "$pct"
}

check_health() {
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║          SYSTEM HEALTH MONITOR                      ║"
    printf "║   %-51s║\n" "$(date '+%Y-%m-%d %H:%M:%S')"
    echo "╠══════════════════════════════════════════════════════╣"

    # CPU
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    printf "║  CPU Usage:    "
    if [[ "$cpu_usage" != "N/A" ]]; then
        display_bar "$cpu_usage"
        echo "  ║"
        if (( cpu_usage > CPU_THRESHOLD )); then
            alert "CPU usage is ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
        fi
    else
        printf "%-38s║\n" "N/A"
    fi

    # Memory
    local mem_info
    mem_info=$(get_memory_info)
    read -r mem_total mem_used mem_pct <<< "$mem_info"
    printf "║  Memory:       "
    display_bar "$mem_pct"
    echo "  ║"
    printf "║    Total: %s MB / Used: %s MB\n" "$mem_total" "$mem_used"
    if (( mem_pct > MEM_THRESHOLD )); then
        alert "Memory usage is ${mem_pct}% (threshold: ${MEM_THRESHOLD}%)"
    fi

    # Disk
    local disk_info
    disk_info=$(get_disk_usage)
    if [[ -n "$disk_info" ]]; then
        read -r disk_size disk_used disk_avail disk_pct <<< "$disk_info"
        printf "║  Disk (/):     "
        display_bar "$disk_pct"
        echo "  ║"
        if (( disk_pct > DISK_THRESHOLD )); then
            alert "Disk usage is ${disk_pct}% (threshold: ${DISK_THRESHOLD}%)"
        fi
    fi

    # Load average
    local load_avg
    load_avg=$(get_load_average)
    printf "║  Load Average: %-38s║\n" "$load_avg"

    # Process count
    local proc_count
    proc_count=$(ps aux 2>/dev/null | wc -l)
    printf "║  Processes:    %-38s║\n" "$proc_count"

    # Uptime
    local uptime_str
    if [[ -f /proc/uptime ]]; then
        local seconds
        seconds=$(awk '{print int($1)}' /proc/uptime)
        local days=$(( seconds / 86400 ))
        local hours=$(( (seconds % 86400) / 3600 ))
        local mins=$(( (seconds % 3600) / 60 ))
        uptime_str="${days}d ${hours}h ${mins}m"
    else
        uptime_str="N/A"
    fi
    printf "║  Uptime:       %-38s║\n" "$uptime_str"

    echo "╚══════════════════════════════════════════════════════╝"
    echo "  Log: $REPORT_FILE | Iteration: $((ITERATIONS + 1))/$MAX_ITERATIONS"
}

trap 'echo; log_msg "Monitor stopped."; exit 0' INT TERM

log_msg "System Health Monitor started (CPU>${CPU_THRESHOLD}% MEM>${MEM_THRESHOLD}% DISK>${DISK_THRESHOLD}%)"

while true; do
    check_health
    ((ITERATIONS++)) || true
    if (( MAX_ITERATIONS > 0 && ITERATIONS >= MAX_ITERATIONS )); then
        log_msg "Reached maximum iterations ($MAX_ITERATIONS). Exiting."
        break
    fi
    sleep "$INTERVAL"
done
