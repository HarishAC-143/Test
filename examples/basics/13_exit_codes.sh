#!/bin/bash
# Exit Codes and Error Handling — $?, set -e, trap ERR, pipefail

echo "=== Exit Codes ==="
ls /etc/passwd > /dev/null 2>&1
echo "ls /etc/passwd -> exit code: $?"

ls /nonexistent_path 2>/dev/null
echo "ls /nonexistent -> exit code: $?"

echo ""
echo "=== Logical Operators ==="
mkdir -p /tmp/test_exit_codes && echo "Directory created successfully"
ls /nonexistent 2>/dev/null || echo "Command failed — fallback executed"

echo ""
echo "=== Custom Return Codes ==="
check_file() {
    local file="$1"
    if [[ ! -e "$file" ]]; then
        return 2
    elif [[ ! -r "$file" ]]; then
        return 3
    elif [[ ! -s "$file" ]]; then
        return 4
    fi
    return 0
}

for f in /etc/passwd /nonexistent /dev/null; do
    check_file "$f"
    rc=$?
    case $rc in
        0) echo "  $f: OK" ;;
        2) echo "  $f: does not exist" ;;
        3) echo "  $f: not readable" ;;
        4) echo "  $f: empty file" ;;
    esac
done

echo ""
echo "=== die() Pattern ==="
die() {
    echo "FATAL: $*" >&2
    return 1
}

check_prerequisites() {
    command -v bash > /dev/null 2>&1 || { die "bash not found"; return 1; }
    command -v ls > /dev/null 2>&1   || { die "ls not found"; return 1; }
    echo "  All prerequisites met"
    return 0
}
check_prerequisites

echo ""
echo "=== set -e Demo ==="
(
    set -e
    echo "  Command 1: OK"
    true
    echo "  Command 2: OK"
    true
    echo "  Command 3: OK"
    echo "  All commands passed with set -e"
)

echo ""
echo "=== PIPESTATUS Array ==="
set -o pipefail
echo "hello" | grep "hello" | wc -l > /dev/null
echo "Pipeline exit codes: ${PIPESTATUS[*]}"

echo "hello" | grep "nonexistent" | wc -l 2>/dev/null
echo "Failed pipeline exit codes: ${PIPESTATUS[*]}"
set +o pipefail

echo ""
echo "=== trap ERR Demo ==="
(
    error_handler() {
        echo "  ERROR caught on line $1 (exit code: $2)" >&2
    }
    trap 'error_handler $LINENO $?' ERR

    echo "  Running safe command..."
    true
    echo "  Running another safe command..."
    true
    echo "  All commands succeeded in trap demo"
)

echo ""
echo "=== trap EXIT (cleanup) ==="
demo_cleanup() {
    local tmpfile
    tmpfile=$(mktemp)

    cleanup() {
        rm -f "$tmpfile"
        echo "  Cleanup: removed $tmpfile"
    }
    trap cleanup RETURN

    echo "  Created tempfile: $tmpfile"
    echo "data" > "$tmpfile"
    echo "  Wrote data to tempfile"
}
demo_cleanup

echo ""
echo "=== Retry Pattern ==="
flaky_command() {
    local attempt=$1
    if (( attempt < 3 )); then
        return 1
    fi
    echo "  Success on attempt $attempt"
    return 0
}

max_retries=5
for (( attempt=1; attempt<=max_retries; attempt++ )); do
    if flaky_command $attempt; then
        break
    fi
    echo "  Attempt $attempt failed, retrying..."
    sleep 0.1
done

rmdir /tmp/test_exit_codes 2>/dev/null
