#!/usr/bin/env bash
#
# 01_system_info.sh — Gathers and displays key system information
#
# Usage: ./01_system_info.sh
#

set -euo pipefail

readonly BOLD='\033[1m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

section() { printf "\n${BOLD}${CYAN}=== %s ===${NC}\n" "$1"; }

section "Hostname & OS"
printf "  Hostname: %s\n" "$(hostname)"
printf "  Kernel:   %s\n" "$(uname -r)"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    printf "  OS:       %s\n" "${PRETTY_NAME:-Unknown}"
fi

section "CPU"
if [[ -f /proc/cpuinfo ]]; then
    model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    cores=$(grep -c '^processor' /proc/cpuinfo)
    printf "  Model:  %s\n" "$model"
    printf "  Cores:  %s\n" "$cores"
fi
printf "  Load:   %s\n" "$(uptime | sed 's/.*load average: //')"

section "Memory"
if command -v free &>/dev/null; then
    free -h | awk '/^Mem:/ {printf "  Total: %s  Used: %s  Free: %s\n", $2, $3, $4}'
fi

section "Disk Usage"
df -h --output=source,size,used,avail,pcent,target 2>/dev/null | \
    grep '^/dev/' | \
    while read -r dev size used avail pct mount; do
        printf "  %-15s %5s used of %5s (%s) on %s\n" "$dev" "$used" "$size" "$pct" "$mount"
    done

section "Network Interfaces"
if command -v ip &>/dev/null; then
    ip -brief addr show 2>/dev/null | while read -r iface state addrs; do
        printf "  %-12s %-6s %s\n" "$iface" "$state" "$addrs"
    done
elif command -v ifconfig &>/dev/null; then
    ifconfig | grep -E '^[a-z]|inet ' | paste - - | \
        awk '{printf "  %-12s %s\n", $1, $6}'
fi

section "Uptime"
printf "  %s\n" "$(uptime -p 2>/dev/null || uptime)"

section "Top 5 Processes by Memory"
ps aux --sort=-%mem 2>/dev/null | head -6 | \
    awk 'NR==1 {printf "  %-10s %5s %5s %s\n", "USER", "%CPU", "%MEM", "COMMAND"}
         NR>1  {printf "  %-10s %5s %5s %s\n", $1, $3, $4, $11}'
