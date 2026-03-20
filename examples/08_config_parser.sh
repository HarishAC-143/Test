#!/usr/bin/env bash
#
# 08_config_parser.sh — Parses INI-style configuration files into BASH variables
#
# Usage: ./08_config_parser.sh [config_file.ini]
#
# Variables are created as SECTION__KEY=VALUE.
# Without a section header, variables are just KEY=VALUE.
#

set -euo pipefail

parse_ini() {
    local ini_file=$1
    local current_section=""

    [[ -f "$ini_file" ]] || { echo "File not found: $ini_file" >&2; return 1; }

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^\[([a-zA-Z0-9_]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            value="${value%\"}"
            value="${value#\"}"

            local var_name
            if [[ -n "$current_section" ]]; then
                var_name="${current_section}__${key}"
            else
                var_name="$key"
            fi

            declare -g "$var_name=$value"
        fi
    done < "$ini_file"
}

if [[ $# -ge 1 && -f "$1" ]]; then
    config_file="$1"
else
    config_file=$(mktemp)
    trap 'rm -f "$config_file"' EXIT

    cat > "$config_file" << 'SAMPLE'
# Sample Application Configuration

[database]
host = localhost
port = 5432
name = myapp_db
user = admin

[server]
host = 0.0.0.0
port = 8080
workers = 4
debug = false

[logging]
level = INFO
file = /var/log/myapp.log
SAMPLE

    echo "No config file provided — using built-in sample."
    echo ""
fi

parse_ini "$config_file"

echo "Parsed Configuration:"
echo "  Database: ${database__user:-?}@${database__host:-?}:${database__port:-?}/${database__name:-?}"
echo "  Server:   ${server__host:-?}:${server__port:-?} (${server__workers:-?} workers, debug=${server__debug:-?})"
echo "  Logging:  level=${logging__level:-?}, file=${logging__file:-?}"
