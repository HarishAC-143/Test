#!/bin/bash
set -euo pipefail
# Practical example: System Health Monitor
# Collects and displays system metrics with color-coded status

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

status_color() {
    local value=$1 warn=$2 crit=$3
    if (( value >= crit )); then
        printf "${RED}%d%%${NC}" "$value"
    elif (( value >= warn )); then
        printf "${YELLOW}%d%%${NC}" "$value"
    else
        printf "${GREEN}%d%%${NC}" "$value"
    fi
}

progress_bar() {
    local value=$1 max=30
    local filled=$(( value * max / 100 ))
    local empty=$(( max - filled ))
    local color="${GREEN}"
    (( value >= 70 )) && color="${YELLOW}"
    (( value >= 90 )) && color="${RED}"

    printf "${color}"
    printf '█%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null || true
    printf "${NC}"
    printf '░%.0s' $(seq 1 $empty 2>/dev/null) 2>/dev/null || true
}

echo -e "${BLUE}${BOLD}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║            SYSTEM HEALTH DASHBOARD                ║"
echo "╠═══════════════════════════════════════════════════╣"
echo -e "╚═══════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${BOLD}[System Information]${NC}"
printf "  %-14s: %s\n" "Hostname" "$(hostname)"
printf "  %-14s: %s\n" "OS" "$(uname -s) $(uname -r)"
printf "  %-14s: %s\n" "Architecture" "$(uname -m)"
printf "  %-14s: %s\n" "Date" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf "  %-14s: %s\n" "Uptime" "$(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /' | sed 's/,.*$//')"

echo ""
echo -e "${BOLD}[CPU]${NC}"
cpu_count=$(nproc 2>/dev/null || echo "1")
load_avg=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0")
cpu_pct=$(awk -v load="$load_avg" -v cpus="$cpu_count" 'BEGIN {
    pct = int(load / cpus * 100)
    if (pct > 100) pct = 100
    print pct
}')
printf "  %-14s: %s\n" "CPU Cores" "$cpu_count"
printf "  %-14s: %s\n" "Load Average" "$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || echo 'N/A')"
printf "  %-14s: " "Usage"
status_color "$cpu_pct" 70 90
echo -n "  "
progress_bar "$cpu_pct"
echo ""

echo ""
echo -e "${BOLD}[Memory]${NC}"
if command -v free &>/dev/null; then
    read -r mem_total mem_used mem_free mem_shared mem_buff mem_avail < <(
        free | awk '/^Mem:/ {print $2, $3, $4, $5, $6, $7}'
    )
    mem_pct=$(( mem_used * 100 / mem_total ))
    printf "  %-14s: %s\n" "Total" "$(free -h | awk '/^Mem:/{print $2}')"
    printf "  %-14s: %s\n" "Used" "$(free -h | awk '/^Mem:/{print $3}')"
    printf "  %-14s: %s\n" "Available" "$(free -h | awk '/^Mem:/{print $7}')"
    printf "  %-14s: " "Usage"
    status_color "$mem_pct" 70 90
    echo -n "  "
    progress_bar "$mem_pct"
    echo ""
fi

echo ""
echo -e "${BOLD}[Disk Usage]${NC}"
printf "  ${CYAN}%-25s %8s %8s %8s %6s${NC}\n" "Filesystem" "Size" "Used" "Avail" "Use%"
df -h --type=ext4 --type=xfs --type=btrfs --type=overlay 2>/dev/null | awk 'NR>1 {
    gsub(/%/, "", $5)
    printf "  %-25s %8s %8s %8s ", $6, $2, $3, $4
}' | while read -r line; do
    echo -n "$line"
    pct=$(echo "$line" | awk '{print $NF}')
    if [[ "$pct" =~ ^[0-9]+$ ]]; then
        status_color "$pct" 70 90
    fi
    echo ""
done
df -h / 2>/dev/null | awk 'NR>1 {
    gsub(/%/, "", $5)
    printf "  %-25s %8s %8s %8s %5d%%\n", $6, $2, $3, $4, $5
}' 2>/dev/null || true

echo ""
echo -e "${BOLD}[Top 5 Processes by CPU]${NC}"
printf "  ${CYAN}%-8s %-15s %6s %6s${NC}\n" "PID" "COMMAND" "CPU%" "MEM%"
ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=6 {
    cmd = $11
    if (length(cmd) > 15) cmd = substr(cmd, 1, 15)
    printf "  %-8s %-15s %6s %6s\n", $2, cmd, $3, $4
}'

echo ""
echo -e "${BOLD}[Top 5 Processes by Memory]${NC}"
printf "  ${CYAN}%-8s %-15s %6s %6s${NC}\n" "PID" "COMMAND" "CPU%" "MEM%"
ps aux --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=6 {
    cmd = $11
    if (length(cmd) > 15) cmd = substr(cmd, 1, 15)
    printf "  %-8s %-15s %6s %6s\n", $2, cmd, $3, $4
}'

echo ""
echo -e "${BOLD}[Network]${NC}"
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "  Internet:      ${GREEN}Connected${NC}"
else
    echo -e "  Internet:      ${RED}Disconnected${NC}"
fi

echo ""
echo -e "${BLUE}Report generated at $(date '+%H:%M:%S')${NC}"
