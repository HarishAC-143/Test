#!/bin/bash
# 08_system_info.sh -- Practical example: System Information Reporter
#
# Collects and displays comprehensive system information
# in a formatted report.
#
# Usage: ./08_system_info.sh [-o output_file]

set -euo pipefail

OUTPUT_FILE=""
[[ "${1:-}" == "-o" && -n "${2:-}" ]] && OUTPUT_FILE="$2"

SEPARATOR=$(printf '=%.0s' {1..60})

section() {
    echo ""
    echo "$SEPARATOR"
    echo "  $1"
    echo "$SEPARATOR"
}

generate_report() {
    echo "$SEPARATOR"
    echo "  SYSTEM INFORMATION REPORT"
    echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "$SEPARATOR"

    section "GENERAL"
    echo "Hostname:      $(hostname 2>/dev/null || echo 'N/A')"
    echo "Kernel:        $(uname -r)"
    echo "Architecture:  $(uname -m)"
    echo "OS:            $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)"
    echo "Uptime:        $(uptime -p 2>/dev/null || uptime | sed 's/.*up/up/')"
    echo "Current User:  ${USER:-$(whoami)}"
    echo "Shell:         $SHELL"
    echo "BASH Version:  $BASH_VERSION"

    section "CPU"
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model cpu_cores
        cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "N/A")
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "N/A")
        echo "Model:         $cpu_model"
        echo "Cores:         $cpu_cores"
    else
        echo "CPU info:      $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'N/A')"
    fi
    echo "Load Average:  $(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || uptime | grep -oE 'load average.*')"

    section "MEMORY"
    if command -v free &>/dev/null; then
        free -h 2>/dev/null | awk '
            /^Mem:/ {
                printf "RAM Total:     %s\n", $2
                printf "RAM Used:      %s\n", $3
                printf "RAM Available: %s\n", $7
            }
            /^Swap:/ {
                printf "Swap Total:    %s\n", $2
                printf "Swap Used:     %s\n", $3
                printf "Swap Free:     %s\n", $4
            }'
    else
        echo "Memory info not available"
    fi

    section "DISK USAGE"
    printf "%-25s %6s %6s %6s %5s  %s\n" "DEVICE" "SIZE" "USED" "AVAIL" "USE%" "MOUNT"
    printf "%s\n" "$(printf -- '-%.0s' {1..75})"
    df -h 2>/dev/null | awk 'NR>1 && /^\/dev\// {
        printf "%-25s %6s %6s %6s %5s  %s\n", $1, $2, $3, $4, $5, $6
    }'

    section "NETWORK"
    if command -v ip &>/dev/null; then
        ip -br addr show 2>/dev/null | while read -r iface state addrs; do
            printf "%-15s %-10s %s\n" "$iface" "$state" "$addrs"
        done
    fi

    echo ""
    echo "Default Gateway: $(ip route show default 2>/dev/null | awk '{print $3; exit}' || echo 'N/A')"
    echo "DNS Servers:     $(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{printf "%s ", $2}' || echo 'N/A')"

    section "TOP PROCESSES (by CPU)"
    printf "%-12s %5s %5s  %s\n" "USER" "%CPU" "%MEM" "COMMAND"
    printf "%s\n" "$(printf -- '-%.0s' {1..50})"
    ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6 {
        printf "%-12s %5s %5s  %s\n", $1, $3, $4, $11
    }'

    section "TOP PROCESSES (by Memory)"
    printf "%-12s %5s %5s  %s\n" "USER" "%CPU" "%MEM" "COMMAND"
    printf "%s\n" "$(printf -- '-%.0s' {1..50})"
    ps aux --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=6 {
        printf "%-12s %5s %5s  %s\n", $1, $3, $4, $11
    }'

    section "ENVIRONMENT SNAPSHOT"
    echo "PATH directories:"
    echo "$PATH" | tr ':' '\n' | while read -r p; do
        if [[ -d "$p" ]]; then
            echo "  [OK]  $p"
        else
            echo "  [!!]  $p (not found)"
        fi
    done

    echo ""
    echo "$SEPARATOR"
    echo "  End of Report"
    echo "$SEPARATOR"
}

if [[ -n "$OUTPUT_FILE" ]]; then
    generate_report > "$OUTPUT_FILE"
    echo "Report written to: $OUTPUT_FILE"
else
    generate_report
fi
