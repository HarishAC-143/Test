#!/bin/bash
# Regular Expressions — =~ operator, BASH_REMATCH, validation patterns

echo "=== Basic Regex Match ==="
string="Error: file not found on line 42"
if [[ "$string" =~ [0-9]+ ]]; then
    echo "Found number: '${BASH_REMATCH[0]}' in '$string'"
fi

echo ""
echo "=== Capture Groups ==="
timestamp="2026-03-20 14:30:45"
if [[ "$timestamp" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})\ ([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]]; then
    echo "Parsed timestamp: $timestamp"
    echo "  Full match: ${BASH_REMATCH[0]}"
    echo "  Year:       ${BASH_REMATCH[1]}"
    echo "  Month:      ${BASH_REMATCH[2]}"
    echo "  Day:        ${BASH_REMATCH[3]}"
    echo "  Hour:       ${BASH_REMATCH[4]}"
    echo "  Minute:     ${BASH_REMATCH[5]}"
    echo "  Second:     ${BASH_REMATCH[6]}"
fi

echo ""
echo "=== IP Address Validation ==="
validate_ip() {
    local ip="$1"
    local octet="([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"
    local regex="^${octet}\.${octet}\.${octet}\.${octet}$"
    if [[ "$ip" =~ $regex ]]; then
        echo "  VALID:   $ip"
        return 0
    else
        echo "  INVALID: $ip"
        return 1
    fi
}

for ip in "192.168.1.1" "10.0.0.255" "256.1.1.1" "0.0.0.0" "1.2.3" "1.2.3.4.5"; do
    validate_ip "$ip"
done

echo ""
echo "=== Email Validation ==="
validate_email() {
    local email="$1"
    local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if [[ "$email" =~ $regex ]]; then
        echo "  VALID:   $email"
    else
        echo "  INVALID: $email"
    fi
}

for email in "user@example.com" "name.last@company.co.uk" "bad@" "@missing.com" "no-at-sign" "ok+tag@test.org"; do
    validate_email "$email"
done

echo ""
echo "=== Phone Number Validation ==="
validate_phone() {
    local phone="$1"
    local regex='^(\+?1?[-. ]?)?\(?[0-9]{3}\)?[-. ]?[0-9]{3}[-. ]?[0-9]{4}$'
    if [[ "$phone" =~ $regex ]]; then
        echo "  VALID:   $phone"
    else
        echo "  INVALID: $phone"
    fi
}

for phone in "555-123-4567" "(555) 123-4567" "+1 555.123.4567" "1234567890" "123-45" "555-1234"; do
    validate_phone "$phone"
done

echo ""
echo "=== Extract All Matches ==="
text="Contact alice@example.com or bob.smith@company.co.uk for details. CC: admin@test.org"
echo "Extracting emails from: '$text'"
remaining="$text"
regex='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
while [[ "$remaining" =~ $regex ]]; do
    echo "  Found: ${BASH_REMATCH[0]}"
    remaining="${remaining/${BASH_REMATCH[0]}/}"
done

echo ""
echo "=== URL Validation ==="
validate_url() {
    local url="$1"
    local regex='^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/[a-zA-Z0-9._~:/?#\[\]@!$&()*+,;=-]*)?$'
    if [[ "$url" =~ $regex ]]; then
        echo "  VALID:   $url"
    else
        echo "  INVALID: $url"
    fi
}

for url in "https://example.com" "http://localhost:8080/path" "ftp://invalid.com" "https://a.b/c?d=e" "not-a-url"; do
    validate_url "$url"
done

echo ""
echo "=== Practical: Log Line Parser ==="
log_line='192.168.1.100 - admin [20/Mar/2026:14:30:00 +0000] "GET /api/users HTTP/1.1" 200 1234'
log_regex='^([0-9.]+) - ([^ ]+) \[([^\]]+)\] "([A-Z]+) ([^ ]+) HTTP/[0-9.]+" ([0-9]+) ([0-9]+)$'

if [[ "$log_line" =~ $log_regex ]]; then
    echo "Parsed log entry:"
    echo "  IP:       ${BASH_REMATCH[1]}"
    echo "  User:     ${BASH_REMATCH[2]}"
    echo "  Date:     ${BASH_REMATCH[3]}"
    echo "  Method:   ${BASH_REMATCH[4]}"
    echo "  Path:     ${BASH_REMATCH[5]}"
    echo "  Status:   ${BASH_REMATCH[6]}"
    echo "  Size:     ${BASH_REMATCH[7]}"
fi

echo ""
echo "=== Practical: Version String Comparison ==="
parse_version() {
    local version="$1"
    if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-([a-zA-Z0-9.]+))?$ ]]; then
        echo "  Version: $version"
        echo "    Major: ${BASH_REMATCH[1]}"
        echo "    Minor: ${BASH_REMATCH[2]}"
        echo "    Patch: ${BASH_REMATCH[3]}"
        [[ -n "${BASH_REMATCH[5]}" ]] && echo "    Pre:   ${BASH_REMATCH[5]}"
    else
        echo "  Invalid version: $version"
    fi
}

for v in "1.2.3" "10.20.30" "1.0.0-beta.1" "1.0.0-rc.2" "invalid"; do
    parse_version "$v"
done
