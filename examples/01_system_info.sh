#!/usr/bin/env bash
# =============================================================================
# System Information Reporter
#
# Gathers and displays key system information including OS details, hardware,
# memory, disk usage, network configuration, and uptime.
#
# Usage: ./01_system_info.sh [--json] [--section SECTION]
# =============================================================================
set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
readonly SEPARATOR="$(printf '=%.0s' {1..60})"
readonly THIN_SEP="$(printf -- '-%.0s' {1..60})"

usage() {
    cat << EOF
System Information Reporter v${SCRIPT_VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
    --json          Output in JSON format
    --section NAME  Show only a specific section
                    (os, cpu, memory, disk, network, uptime)
    --help          Show this help message

Examples:
    $(basename "$0")                  # Show all sections
    $(basename "$0") --section cpu    # Show only CPU info
    $(basename "$0") --json           # Output as JSON
EOF
}

print_header() {
    echo "$SEPARATOR"
    printf "  %s\n" "$1"
    echo "$SEPARATOR"
}

section_os() {
    print_header "OPERATING SYSTEM"
    if [[ -f /etc/os-release ]]; then
        local os_name os_version os_id
        os_name=$(grep '^NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
        os_version=$(grep '^VERSION=' /etc/os-release | cut -d= -f2- | tr -d '"')
        os_id=$(grep '^ID=' /etc/os-release | cut -d= -f2- | tr -d '"')
        echo "  Name:       ${os_name:-Unknown}"
        echo "  Version:    ${os_version:-Unknown}"
        echo "  ID:         ${os_id:-Unknown}"
    fi
    echo "  Kernel:     $(uname -r)"
    echo "  Arch:       $(uname -m)"
    echo "  Hostname:   $(hostname)"
}

section_cpu() {
    print_header "CPU INFORMATION"
    if [[ -f /proc/cpuinfo ]]; then
        local model cores
        model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
        cores=$(grep -c '^processor' /proc/cpuinfo)
        echo "  Model:      ${model:-Unknown}"
        echo "  Cores:      ${cores}"
    else
        echo "  CPU info:   $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unavailable')"
    fi

    if command -v nproc &>/dev/null; then
        echo "  Available:  $(nproc) processing units"
    fi
}

section_memory() {
    print_header "MEMORY USAGE"
    if command -v free &>/dev/null; then
        free -h | awk '
            /^Mem:/ {
                printf "  Total:      %s\n", $2
                printf "  Used:       %s\n", $3
                printf "  Free:       %s\n", $4
                printf "  Available:  %s\n", $7
            }
            /^Swap:/ {
                printf "  Swap Total: %s\n", $2
                printf "  Swap Used:  %s\n", $3
            }
        '
    fi

    if [[ -f /proc/meminfo ]]; then
        local total_kb used_kb pct
        total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
        local avail_kb
        avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
        used_kb=$(( total_kb - avail_kb ))
        pct=$(( used_kb * 100 / total_kb ))
        echo "  Usage:      ${pct}%"

        local bar filled empty
        filled=$(( pct / 2 ))
        empty=$(( 50 - filled ))
        bar=$(printf '#%.0s' $(seq 1 "$filled"))$(printf '.%.0s' $(seq 1 "$empty"))
        echo "  [${bar}]"
    fi
}

section_disk() {
    print_header "DISK USAGE"
    echo "  Filesystem       Size  Used  Avail  Use%  Mount"
    echo "  $THIN_SEP"
    df -h --output=source,size,used,avail,pcent,target 2>/dev/null \
        | grep '^/dev' \
        | while read -r fs size used avail pct mount; do
            printf "  %-16s %5s %5s %6s %5s  %s\n" \
                "$fs" "$size" "$used" "$avail" "$pct" "$mount"
        done
}

section_network() {
    print_header "NETWORK INTERFACES"
    if command -v ip &>/dev/null; then
        ip -4 addr show | awk '
            /^[0-9]+:/ { iface = $2; sub(/:$/, "", iface) }
            /inet / {
                split($2, a, "/")
                printf "  %-12s %s/%s\n", iface, a[1], a[2]
            }
        '
    elif command -v ifconfig &>/dev/null; then
        ifconfig | awk '
            /^[a-zA-Z]/ { iface = $1 }
            /inet / { printf "  %-12s %s\n", iface, $2 }
        '
    fi

    echo ""
    if command -v ip &>/dev/null; then
        local gw
        gw=$(ip route | awk '/default/ {print $3; exit}')
        echo "  Gateway:    ${gw:-N/A}"
    fi

    echo "  DNS:"
    if [[ -f /etc/resolv.conf ]]; then
        grep '^nameserver' /etc/resolv.conf | while read -r _ ns; do
            echo "              $ns"
        done
    fi
}

section_uptime() {
    print_header "SYSTEM UPTIME"
    if [[ -f /proc/uptime ]]; then
        local total_seconds days hours minutes
        total_seconds=$(awk '{printf "%d", $1}' /proc/uptime)
        days=$(( total_seconds / 86400 ))
        hours=$(( (total_seconds % 86400) / 3600 ))
        minutes=$(( (total_seconds % 3600) / 60 ))
        echo "  Uptime:     ${days}d ${hours}h ${minutes}m"
    fi
    echo "  Load Avg:   $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || uptime | awk -F'load average:' '{print $2}')"
    echo "  Date:       $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "  Users:      $(who 2>/dev/null | wc -l) logged in"
}

output_json() {
    local os_name kernel hostname
    if [[ -f /etc/os-release ]]; then
        os_name=$(grep '^NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
        os_name="${os_name:-Unknown}"
    else
        os_name="Unknown"
    fi
    kernel=$(uname -r)
    hostname=$(hostname)

    local cpu_model="Unknown" cpu_cores="0"
    if [[ -f /proc/cpuinfo ]]; then
        cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
        cpu_cores=$(grep -c '^processor' /proc/cpuinfo)
    fi

    local mem_total_kb mem_avail_kb mem_used_pct
    if [[ -f /proc/meminfo ]]; then
        mem_total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
        mem_avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
        mem_used_pct=$(( (mem_total_kb - mem_avail_kb) * 100 / mem_total_kb ))
    fi

    cat << ENDJSON
{
  "hostname": "${hostname}",
  "os": "${os_name}",
  "kernel": "${kernel}",
  "cpu": {
    "model": "${cpu_model}",
    "cores": ${cpu_cores}
  },
  "memory": {
    "total_kb": ${mem_total_kb:-0},
    "available_kb": ${mem_avail_kb:-0},
    "used_percent": ${mem_used_pct:-0}
  },
  "timestamp": "$(date -Iseconds)"
}
ENDJSON
}

main() {
    local json_output=false
    local section="all"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json_output=true; shift ;;
            --section) section="$2"; shift 2 ;;
            --help) usage; exit 0 ;;
            *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    if $json_output; then
        output_json
        exit 0
    fi

    echo ""
    echo "  SYSTEM INFORMATION REPORT"
    echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    case "$section" in
        all)
            section_os
            section_cpu
            section_memory
            section_disk
            section_network
            section_uptime
            ;;
        os)      section_os ;;
        cpu)     section_cpu ;;
        memory)  section_memory ;;
        disk)    section_disk ;;
        network) section_network ;;
        uptime)  section_uptime ;;
        *) echo "Unknown section: $section" >&2; exit 1 ;;
    esac

    echo "$SEPARATOR"
}

main "$@"
