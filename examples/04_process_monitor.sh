#!/usr/bin/env bash
# =============================================================================
# Process Monitor
#
# Monitors system processes and resources. Shows top processes by CPU and
# memory, alerts on thresholds, and can watch specific processes.
#
# Usage: ./04_process_monitor.sh [OPTIONS]
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_INTERVAL=5
readonly DEFAULT_TOP_N=10
readonly DEFAULT_CPU_THRESHOLD=80
readonly DEFAULT_MEM_THRESHOLD=80

usage() {
    cat << EOF
Process Monitor - Watch system processes and resources

Usage: $SCRIPT_NAME [OPTIONS]

Options:
    -w, --watch PID|NAME     Watch a specific process by PID or name
    -i, --interval SECONDS   Refresh interval (default: $DEFAULT_INTERVAL)
    -n, --top N              Show top N processes (default: $DEFAULT_TOP_N)
    --cpu-alert PCT          Alert if CPU usage exceeds PCT% (default: $DEFAULT_CPU_THRESHOLD)
    --mem-alert PCT          Alert if memory usage exceeds PCT% (default: $DEFAULT_MEM_THRESHOLD)
    --snapshot               Take a single snapshot (no continuous monitoring)
    -h, --help               Show this help

Examples:
    $SCRIPT_NAME --snapshot                     # Single snapshot
    $SCRIPT_NAME -w nginx -i 3                  # Watch nginx every 3s
    $SCRIPT_NAME --cpu-alert 90 --mem-alert 85  # Custom alert thresholds
EOF
}

get_cpu_usage() {
    if [[ -f /proc/stat ]]; then
        local cpu_line
        cpu_line=$(head -1 /proc/stat)
        local -a fields
        read -ra fields <<< "$cpu_line"

        local user=${fields[1]} nice=${fields[2]} system=${fields[3]}
        local idle=${fields[4]} iowait=${fields[5]} irq=${fields[6]}
        local softirq=${fields[7]}

        local total=$(( user + nice + system + idle + iowait + irq + softirq ))
        local active=$(( total - idle - iowait ))

        echo "$active $total"
    fi
}

calc_cpu_percent() {
    local prev_active=$1 prev_total=$2 curr_active=$3 curr_total=$4

    local delta_active=$(( curr_active - prev_active ))
    local delta_total=$(( curr_total - prev_total ))

    if (( delta_total == 0 )); then
        echo "0"
    else
        echo $(( delta_active * 100 / delta_total ))
    fi
}

print_header() {
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)
    local sep
    sep=$(printf '=%.0s' $(seq 1 "$term_width"))

    echo "$sep"
    printf " PROCESS MONITOR  |  %s  |  Interval: %ss\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
    echo "$sep"
}

show_system_overview() {
    echo ""
    echo ">> SYSTEM OVERVIEW"
    echo "   ──────────────────────────────────────────"

    # CPU
    if [[ -f /proc/loadavg ]]; then
        local load
        load=$(cut -d' ' -f1-3 /proc/loadavg)
        echo "   Load Average:  $load"
    fi

    # Memory
    if [[ -f /proc/meminfo ]]; then
        local total avail used pct
        total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
        avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
        used=$(( total - avail ))
        pct=$(( used * 100 / total ))

        printf "   Memory:        %d MB / %d MB (%d%%)\n" \
            $(( used / 1024 )) $(( total / 1024 )) "$pct"

        local bar_len=$(( pct / 2 ))
        local bar
        bar=$(printf '█%.0s' $(seq 1 "$bar_len") 2>/dev/null || true)
        bar+=$(printf '░%.0s' $(seq 1 $(( 50 - bar_len )) ) 2>/dev/null || true)
        echo "   [$bar] ${pct}%"
    fi

    # Swap
    if [[ -f /proc/meminfo ]]; then
        local swap_total swap_free swap_used swap_pct
        swap_total=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
        swap_free=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)
        if (( swap_total > 0 )); then
            swap_used=$(( swap_total - swap_free ))
            swap_pct=$(( swap_used * 100 / swap_total ))
            printf "   Swap:          %d MB / %d MB (%d%%)\n" \
                $(( swap_used / 1024 )) $(( swap_total / 1024 )) "$swap_pct"
        fi
    fi

    # Process counts
    local total_procs running sleeping
    total_procs=$(ps aux --no-headers 2>/dev/null | wc -l)
    running=$(ps aux --no-headers 2>/dev/null | awk '$8 ~ /R/' | wc -l)
    sleeping=$(ps aux --no-headers 2>/dev/null | awk '$8 ~ /S/' | wc -l)
    printf "   Processes:     %d total, %d running, %d sleeping\n" \
        "$total_procs" "$running" "$sleeping"
}

show_top_processes() {
    local top_n=$1
    local sort_by=$2

    echo ""
    echo ">> TOP ${top_n} PROCESSES (by ${sort_by})"
    echo "   ──────────────────────────────────────────"
    printf "   %-8s %-15s %6s %6s %10s  %s\n" \
        "PID" "USER" "CPU%" "MEM%" "RSS(MB)" "COMMAND"
    echo "   $(printf -- '-%.0s' {1..65})"

    if [[ "$sort_by" == "CPU" ]]; then
        ps aux --no-headers --sort=-%cpu 2>/dev/null | head -"$top_n"
    else
        ps aux --no-headers --sort=-%mem 2>/dev/null | head -"$top_n"
    fi | while read -r user pid cpu mem vsz rss tty stat start time command; do
        local rss_mb=$(( rss / 1024 ))
        printf "   %-8s %-15s %5.1f %5.1f %8d  %s\n" \
            "$pid" "${user:0:15}" "$cpu" "$mem" "$rss_mb" "${command:0:30}"
    done
}

check_alerts() {
    local cpu_threshold=$1
    local mem_threshold=$2

    local alerts=()

    # Memory alert
    if [[ -f /proc/meminfo ]]; then
        local total avail pct
        total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
        avail=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
        pct=$(( (total - avail) * 100 / total ))
        if (( pct > mem_threshold )); then
            alerts+=("ALERT: Memory usage at ${pct}% (threshold: ${mem_threshold}%)")
        fi
    fi

    # High CPU process alert
    while read -r pid cpu command; do
        local cpu_int=${cpu%.*}
        if (( cpu_int > cpu_threshold )); then
            alerts+=("ALERT: PID $pid (${command:0:20}) CPU at ${cpu}% (threshold: ${cpu_threshold}%)")
        fi
    done < <(ps aux --no-headers --sort=-%cpu 2>/dev/null \
        | head -5 \
        | awk '{print $2, $3, $11}')

    if [[ ${#alerts[@]} -gt 0 ]]; then
        echo ""
        echo ">> ALERTS"
        echo "   ──────────────────────────────────────────"
        for alert in "${alerts[@]}"; do
            echo "   ⚠  $alert"
        done
    fi
}

watch_process() {
    local target="$1"
    local pid=""

    # Check if target is a PID or process name
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        pid="$target"
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "Error: PID $pid not found" >&2
            return 1
        fi
    else
        pid=$(pgrep -f "$target" | head -1 || true)
        if [[ -z "$pid" ]]; then
            echo "Error: No process matching '$target'" >&2
            return 1
        fi
    fi

    echo ""
    echo ">> WATCHING PROCESS: $target (PID: $pid)"
    echo "   ──────────────────────────────────────────"

    if [[ -d "/proc/$pid" ]]; then
        local cmd status threads fd_count
        cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "N/A")
        status=$(awk '/^State:/ {print $2, $3}' "/proc/$pid/status" 2>/dev/null || echo "N/A")
        threads=$(awk '/^Threads:/ {print $2}' "/proc/$pid/status" 2>/dev/null || echo "N/A")
        fd_count=$(ls "/proc/$pid/fd" 2>/dev/null | wc -l || echo "N/A")

        local vmrss vmsize
        vmrss=$(awk '/^VmRSS:/ {print $2, $3}' "/proc/$pid/status" 2>/dev/null || echo "N/A")
        vmsize=$(awk '/^VmSize:/ {print $2, $3}' "/proc/$pid/status" 2>/dev/null || echo "N/A")

        echo "   Command:     ${cmd:0:60}"
        echo "   State:       $status"
        echo "   Threads:     $threads"
        echo "   Open FDs:    $fd_count"
        echo "   RSS:         $vmrss"
        echo "   Virtual:     $vmsize"

        ps -p "$pid" -o %cpu,%mem,etime --no-headers 2>/dev/null \
            | awk '{printf "   CPU:         %s%%\n   Memory:     %s%%\n   Elapsed:    %s\n", $1, $2, $3}'
    else
        ps -p "$pid" -o pid,user,%cpu,%mem,rss,etime,command --no-headers 2>/dev/null \
            | awk '{printf "   PID: %s  User: %s  CPU: %s%%  Mem: %s%%  RSS: %s KB  Time: %s\n   Cmd: ", $1,$2,$3,$4,$5,$6; for(i=7;i<=NF;i++) printf "%s ", $i; print ""}'
    fi
}

snapshot() {
    local top_n=$1
    local cpu_threshold=$2
    local mem_threshold=$3
    local watch_target=$4

    print_header "N/A"
    show_system_overview
    show_top_processes "$top_n" "CPU"
    show_top_processes "$top_n" "MEM"

    if [[ -n "$watch_target" ]]; then
        watch_process "$watch_target"
    fi

    check_alerts "$cpu_threshold" "$mem_threshold"
    echo ""
}

monitor_loop() {
    local interval=$1
    local top_n=$2
    local cpu_threshold=$3
    local mem_threshold=$4
    local watch_target=$5

    trap 'echo ""; echo "Monitor stopped."; exit 0' INT TERM

    while true; do
        clear 2>/dev/null || true
        print_header "$interval"
        show_system_overview
        show_top_processes "$top_n" "CPU"

        if [[ -n "$watch_target" ]]; then
            watch_process "$watch_target"
        fi

        check_alerts "$cpu_threshold" "$mem_threshold"
        echo ""
        echo "Press Ctrl+C to stop"
        sleep "$interval"
    done
}

main() {
    local watch_target=""
    local interval=$DEFAULT_INTERVAL
    local top_n=$DEFAULT_TOP_N
    local cpu_threshold=$DEFAULT_CPU_THRESHOLD
    local mem_threshold=$DEFAULT_MEM_THRESHOLD
    local snapshot_mode=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w|--watch)     watch_target="$2"; shift 2 ;;
            -i|--interval)  interval="$2"; shift 2 ;;
            -n|--top)       top_n="$2"; shift 2 ;;
            --cpu-alert)    cpu_threshold="$2"; shift 2 ;;
            --mem-alert)    mem_threshold="$2"; shift 2 ;;
            --snapshot)     snapshot_mode=true; shift ;;
            -h|--help)      usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    if $snapshot_mode; then
        snapshot "$top_n" "$cpu_threshold" "$mem_threshold" "$watch_target"
    else
        monitor_loop "$interval" "$top_n" "$cpu_threshold" "$mem_threshold" "$watch_target"
    fi
}

main "$@"
