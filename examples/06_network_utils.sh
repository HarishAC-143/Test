#!/usr/bin/env bash
# =============================================================================
# Network Utilities
#
# A collection of network diagnostic and monitoring tools including
# connectivity checks, port scanning, DNS lookups, and bandwidth testing.
#
# Usage: ./06_network_utils.sh COMMAND [OPTIONS]
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

usage() {
    cat << EOF
Network Utilities - Diagnostic and monitoring tools

Usage: $SCRIPT_NAME COMMAND [OPTIONS]

Commands:
    ping HOST [-c COUNT]          Check connectivity to a host
    portscan HOST [PORT_RANGE]    Scan ports on a host (e.g., 1-1024)
    dns HOST                      DNS lookup with details
    connections                   Show active network connections
    interfaces                    Show network interface details
    gateway                       Show default gateway and route info
    listening                     Show listening ports and their processes
    http URL                      HTTP request with timing details
    myip                          Show public and private IP addresses
    speed                         Basic bandwidth estimation

Options:
    -h, --help                    Show this help

Examples:
    $SCRIPT_NAME ping google.com -c 5
    $SCRIPT_NAME portscan 192.168.1.1 20-100
    $SCRIPT_NAME dns example.com
    $SCRIPT_NAME listening
    $SCRIPT_NAME http https://example.com
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

check_command() {
    command -v "$1" &>/dev/null || die "Required command not found: $1"
}

cmd_ping() {
    local host="$1"
    local count="${2:-4}"

    echo "Pinging $host ($count packets)..."
    echo "──────────────────────────────────────────"

    if ! ping -c "$count" -W 3 "$host" 2>&1; then
        echo "Host $host is unreachable"
        return 1
    fi
}

cmd_portscan() {
    local host="$1"
    local range="${2:-1-1024}"

    local start_port end_port
    IFS='-' read -r start_port end_port <<< "$range"
    end_port="${end_port:-$start_port}"

    echo "Scanning $host ports $start_port-$end_port..."
    echo "──────────────────────────────────────────"

    local open_count=0
    local scanned=0
    local total=$(( end_port - start_port + 1 ))

    printf "%-8s %-10s %s\n" "PORT" "STATE" "SERVICE"
    echo "$(printf -- '-%.0s' {1..40})"

    for (( port = start_port; port <= end_port; port++ )); do
        (( scanned++ ))

        # Show progress every 100 ports
        if (( scanned % 100 == 0 )); then
            printf "\r  Progress: %d/%d ports scanned..." "$scanned" "$total" >&2
        fi

        if (echo > "/dev/tcp/$host/$port") 2>/dev/null; then
            local service
            service=$(getent services "$port" 2>/dev/null | awk '{print $1}' || echo "unknown")
            printf "%-8s %-10s %s\n" "$port" "open" "$service"
            (( open_count++ ))
        fi
    done

    printf "\r%s\r" "$(printf ' %.0s' {1..50})" >&2
    echo ""
    echo "Scan complete: $open_count open port(s) found out of $total scanned"
}

cmd_dns() {
    local host="$1"

    echo "DNS Lookup: $host"
    echo "──────────────────────────────────────────"

    if command -v dig &>/dev/null; then
        echo ""
        echo ">> A Records (IPv4):"
        dig +short A "$host" 2>/dev/null | while read -r ip; do
            echo "   $ip"
        done

        echo ""
        echo ">> AAAA Records (IPv6):"
        dig +short AAAA "$host" 2>/dev/null | while read -r ip; do
            echo "   $ip"
        done

        echo ""
        echo ">> MX Records (Mail):"
        dig +short MX "$host" 2>/dev/null | sort -n | while read -r priority server; do
            printf "   %-5s %s\n" "$priority" "$server"
        done

        echo ""
        echo ">> NS Records (Nameservers):"
        dig +short NS "$host" 2>/dev/null | while read -r ns; do
            echo "   $ns"
        done

        echo ""
        echo ">> TXT Records:"
        dig +short TXT "$host" 2>/dev/null | head -5 | while read -r txt; do
            echo "   ${txt:0:70}"
        done

    elif command -v nslookup &>/dev/null; then
        nslookup "$host" 2>/dev/null
    elif command -v host &>/dev/null; then
        host "$host" 2>/dev/null
    else
        getent hosts "$host" 2>/dev/null || die "No DNS tools available"
    fi
}

cmd_connections() {
    echo "Active Network Connections"
    echo "──────────────────────────────────────────"

    if command -v ss &>/dev/null; then
        echo ""
        echo ">> Connection Summary:"
        ss -s 2>/dev/null

        echo ""
        echo ">> Established Connections:"
        printf "%-6s %-25s %-25s %-12s\n" "PROTO" "LOCAL" "REMOTE" "STATE"
        echo "$(printf -- '-%.0s' {1..70})"
        ss -tunapH state established 2>/dev/null \
            | awk '{printf "%-6s %-25s %-25s %-12s\n", $1, $5, $6, $2}' \
            | head -20
    elif command -v netstat &>/dev/null; then
        netstat -tunapl 2>/dev/null | head -30
    else
        echo "Neither ss nor netstat available"
    fi
}

cmd_interfaces() {
    echo "Network Interfaces"
    echo "──────────────────────────────────────────"

    if command -v ip &>/dev/null; then
        ip -br addr show 2>/dev/null | while read -r iface state addrs; do
            local status_icon="●"
            [[ "$state" == "UP" ]] && status_icon="✓"
            [[ "$state" == "DOWN" ]] && status_icon="✗"

            echo ""
            printf "  %s %-15s [%s]\n" "$status_icon" "$iface" "$state"
            if [[ -n "$addrs" ]]; then
                echo "$addrs" | tr ' ' '\n' | while read -r addr; do
                    echo "    Address: $addr"
                done
            fi

            # MAC address
            local mac
            mac=$(ip link show "$iface" 2>/dev/null | awk '/link\/ether/ {print $2}')
            [[ -n "$mac" ]] && echo "    MAC:     $mac"

            # Statistics
            if [[ -d "/sys/class/net/$iface/statistics" ]]; then
                local rx tx
                rx=$(< "/sys/class/net/$iface/statistics/rx_bytes")
                tx=$(< "/sys/class/net/$iface/statistics/tx_bytes")
                printf "    RX:      %s\n" "$(numfmt --to=iec "$rx" 2>/dev/null || echo "${rx} B")"
                printf "    TX:      %s\n" "$(numfmt --to=iec "$tx" 2>/dev/null || echo "${tx} B")"
            fi
        done
    elif command -v ifconfig &>/dev/null; then
        ifconfig 2>/dev/null
    fi
}

cmd_gateway() {
    echo "Gateway and Routing"
    echo "──────────────────────────────────────────"

    if command -v ip &>/dev/null; then
        echo ""
        echo ">> Default Gateway:"
        ip route show default 2>/dev/null | while read -r line; do
            echo "   $line"
        done

        echo ""
        echo ">> Routing Table:"
        printf "   %-18s %-18s %-8s %s\n" "DESTINATION" "GATEWAY" "DEV" "METRIC"
        echo "   $(printf -- '-%.0s' {1..55})"
        ip route show 2>/dev/null | while read -r line; do
            echo "   $line"
        done
    elif command -v route &>/dev/null; then
        route -n 2>/dev/null
    fi
}

cmd_listening() {
    echo "Listening Ports"
    echo "──────────────────────────────────────────"

    if command -v ss &>/dev/null; then
        printf "%-8s %-25s %-8s %s\n" "PROTO" "ADDRESS" "PID" "PROCESS"
        echo "$(printf -- '-%.0s' {1..60})"

        ss -tlnpH 2>/dev/null | while read -r state recv send local peer process; do
            local proto="tcp"
            local pid_name
            pid_name=$(echo "$process" | grep -oP 'pid=\K[0-9]+' 2>/dev/null || echo "-")
            local pname
            pname=$(echo "$process" | grep -oP '"\K[^"]+' 2>/dev/null || echo "-")
            printf "%-8s %-25s %-8s %s\n" "$proto" "$local" "$pid_name" "$pname"
        done

        ss -ulnpH 2>/dev/null | while read -r state recv send local peer process; do
            local pid_name
            pid_name=$(echo "$process" | grep -oP 'pid=\K[0-9]+' 2>/dev/null || echo "-")
            local pname
            pname=$(echo "$process" | grep -oP '"\K[^"]+' 2>/dev/null || echo "-")
            printf "%-8s %-25s %-8s %s\n" "udp" "$local" "$pid_name" "$pname"
        done
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null
    fi
}

cmd_http() {
    local url="$1"

    check_command curl

    echo "HTTP Request: $url"
    echo "──────────────────────────────────────────"

    local tmpfile
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' RETURN

    local http_code
    http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" \
        --connect-timeout 10 \
        --max-time 30 \
        "$url" 2>/dev/null) || true

    echo ""
    echo ">> Response:"
    echo "   Status Code:   $http_code"

    # Timing details
    curl -s -o /dev/null -w "\
   DNS Lookup:    %{time_namelookup}s
   Connect:       %{time_connect}s
   TLS Handshake: %{time_appconnect}s
   First Byte:    %{time_starttransfer}s
   Total Time:    %{time_total}s
   Download Size: %{size_download} bytes
   Speed:         %{speed_download} bytes/s
" --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || true

    echo ""
    echo ">> Response Headers:"
    curl -sI --connect-timeout 10 --max-time 30 "$url" 2>/dev/null \
        | head -15 \
        | while IFS= read -r line; do
            echo "   $line"
        done
}

cmd_myip() {
    echo "IP Address Information"
    echo "──────────────────────────────────────────"

    echo ""
    echo ">> Private IP Addresses:"
    if command -v ip &>/dev/null; then
        ip -4 addr show 2>/dev/null | awk '/inet / && !/127.0.0.1/ {
            split($2, a, "/")
            printf "   %-15s (%s)\n", a[1], $NF
        }'
    elif command -v hostname &>/dev/null; then
        hostname -I 2>/dev/null | tr ' ' '\n' | while read -r ip; do
            [[ -n "$ip" ]] && echo "   $ip"
        done
    fi

    echo ""
    echo ">> Public IP Address:"
    local public_ip
    if command -v curl &>/dev/null; then
        public_ip=$(curl -s --connect-timeout 5 --max-time 10 \
            "https://ifconfig.me" 2>/dev/null || echo "Unable to determine")
    elif command -v wget &>/dev/null; then
        public_ip=$(wget -qO- --timeout=10 \
            "https://ifconfig.me" 2>/dev/null || echo "Unable to determine")
    else
        public_ip="curl/wget not available"
    fi
    echo "   $public_ip"
}

cmd_speed() {
    echo "Basic Bandwidth Test"
    echo "──────────────────────────────────────────"

    check_command curl

    echo ""
    echo "Downloading test file (10 MB)..."

    local start_time end_time duration bytes speed
    start_time=$(date +%s%N)

    bytes=$(curl -s -o /dev/null -w "%{size_download}" \
        --connect-timeout 10 \
        --max-time 60 \
        "http://speedtest.tele2.net/10MB.zip" 2>/dev/null || echo "0")

    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))

    if (( bytes > 0 && duration > 0 )); then
        speed=$(( bytes * 8 * 1000 / duration ))
        echo ""
        printf "   Downloaded:  %s bytes\n" "$bytes"
        printf "   Duration:    %d ms\n" "$duration"
        printf "   Speed:       %s bps (~%s Mbps)\n" \
            "$speed" \
            "$(echo "scale=2; $speed / 1000000" | bc)"
    else
        echo "   Speed test failed or timed out"
    fi
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        ping)         cmd_ping "${1:?Host required}" "${2:-4}" ;;
        portscan)     cmd_portscan "${1:?Host required}" "${2:-1-100}" ;;
        dns)          cmd_dns "${1:?Host required}" ;;
        connections)  cmd_connections ;;
        interfaces)   cmd_interfaces ;;
        gateway)      cmd_gateway ;;
        listening)    cmd_listening ;;
        http)         cmd_http "${1:?URL required}" ;;
        myip)         cmd_myip ;;
        speed)        cmd_speed ;;
        -h|--help)    usage; exit 0 ;;
        *)            die "Unknown command: $command (use --help for usage)" ;;
    esac
}

main "$@"
