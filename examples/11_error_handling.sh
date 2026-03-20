#!/bin/bash
# Error handling, debugging, and strict mode

echo "=== Exit Codes ==="
ls /etc/passwd > /dev/null 2>&1
echo "ls /etc/passwd → exit code: $?"

ls /nonexistent_file 2>/dev/null
echo "ls /nonexistent → exit code: $?"

echo ""
echo "=== Custom Error Function ==="

die() {
    echo "FATAL: $*" >&2
    return 1
}

try_operation() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        die "File not found: $file" || return $?
    fi
    echo "File OK: $file"
}

try_operation "/etc/passwd"
try_operation "/nonexistent" || echo "  (handled gracefully)"

echo ""
echo "=== The || Pattern ==="
mkdir -p /tmp/test_error_handling || echo "mkdir failed"
echo "Directory operation completed"

echo ""
echo "=== Trap for Cleanup ==="
demo_trap() {
    local tmpfile
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"; echo "  Cleanup: removed temp file"' RETURN
    echo "  Created: $tmpfile"
    echo "test data" > "$tmpfile"
    echo "  File exists: $(test -f "$tmpfile" && echo yes || echo no)"
}

echo "Running function with cleanup trap:"
demo_trap
echo "After function return, temp file is cleaned up"

echo ""
echo "=== Error Trap ==="
handle_error() {
    echo "  ERROR caught on line $1 (exit code $2)" >&2
}

(
    trap 'handle_error $LINENO $?' ERR
    set -e
    echo "Command 1: OK"
    true
    echo "Command 2: OK"
    false 2>/dev/null
    echo "This won't execute"
) || echo "  Subshell caught the error"

echo ""
echo "=== Retry Pattern ==="
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2

    local attempt=1
    while (( attempt <= max_attempts )); do
        echo "  Attempt $attempt/$max_attempts: $*"
        if "$@" 2>/dev/null; then
            echo "  Success on attempt $attempt"
            return 0
        fi
        (( attempt++ ))
        (( attempt <= max_attempts )) && sleep "$delay"
    done
    echo "  Failed after $max_attempts attempts" >&2
    return 1
}

retry 3 0.1 ls /etc/passwd > /dev/null
retry 3 0.1 ls /nonexistent > /dev/null || echo "  (all retries exhausted)"

echo ""
echo "=== Debugging with set -x ==="
echo "(debug trace for a small section)"
(
    set -x
    x=5
    y=10
    result=$(( x + y ))
    echo "Result: $result"
) 2>&1 | head -10

echo ""
echo "=== Validate Input Pattern ==="
validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "  Error: '$port' is not a number" >&2
        return 1
    fi
    if (( port < 1 || port > 65535 )); then
        echo "  Error: port $port out of range (1-65535)" >&2
        return 1
    fi
    echo "  Valid port: $port"
    return 0
}

validate_port "8080"
validate_port "abc" || true
validate_port "99999" || true
validate_port "443"
