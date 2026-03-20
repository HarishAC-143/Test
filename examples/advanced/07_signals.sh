#!/bin/bash
# Signal Handling with trap — EXIT, INT, TERM, ERR, cleanup patterns

tmpdir=$(mktemp -d)
echo "Created temp dir: $tmpdir"

echo "=== EXIT Trap (Cleanup) ==="
cleanup() {
    echo "Cleanup: removing $tmpdir"
    rm -rf "$tmpdir"
}
trap cleanup EXIT

echo "Files created in tmpdir will be cleaned up automatically."
touch "$tmpdir/important_data.txt"
echo "Created: $tmpdir/important_data.txt"

echo ""
echo "=== INT Trap (Ctrl+C) ==="
original_int_handler() {
    echo "Caught SIGINT (Ctrl+C)"
    echo "Performing graceful shutdown..."
}
trap original_int_handler INT

echo ""
echo "=== TERM Trap ==="
trap 'echo "Caught SIGTERM"' TERM

echo ""
echo "=== Current Traps ==="
echo "Active traps:"
trap -p | while IFS= read -r line; do
    echo "  $line"
done

echo ""
echo "=== ERR Trap ==="
(
    err_handler() {
        echo "  ERROR on line $1, command: '$BASH_COMMAND', exit code: $2"
    }
    trap 'err_handler $LINENO $?' ERR

    echo "Running commands with ERR trap..."
    true
    echo "  true succeeded"
    false || true
    echo "  false || true succeeded (|| prevents ERR)"
    echo "  All commands completed"
)

echo ""
echo "=== Practical: Lock File Pattern ==="
LOCKFILE="$tmpdir/script.lock"

acquire_lock() {
    if [[ -f "$LOCKFILE" ]]; then
        local pid
        pid=$(<"$LOCKFILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "  Lock held by active PID $pid"
            return 1
        fi
        echo "  Stale lock found (PID $pid is dead), removing"
        rm -f "$LOCKFILE"
    fi
    echo $$ > "$LOCKFILE"
    echo "  Lock acquired (PID $$)"
    return 0
}

release_lock() {
    rm -f "$LOCKFILE"
    echo "  Lock released"
}

if acquire_lock; then
    echo "  Doing critical work..."
    sleep 0.5
    release_lock
fi

echo ""
echo "=== Practical: Progress with Interruption ==="
handle_interrupt() {
    echo ""
    echo "  Interrupted at step $current_step!"
    echo "  Partial results saved."
}

current_step=0
trap handle_interrupt INT

for i in {1..5}; do
    current_step=$i
    echo "  Processing step $i/5..."
    sleep 0.2
done
echo "  All steps completed."

trap - INT

echo ""
echo "=== Practical: Timeout Pattern ==="
run_with_timeout() {
    local timeout=$1
    shift

    "$@" &
    local pid=$!

    (
        sleep "$timeout"
        if kill -0 "$pid" 2>/dev/null; then
            echo "  Timeout: killing PID $pid after ${timeout}s"
            kill "$pid"
        fi
    ) &
    local watchdog=$!

    wait "$pid" 2>/dev/null
    local exit_code=$?

    kill "$watchdog" 2>/dev/null
    wait "$watchdog" 2>/dev/null

    return $exit_code
}

echo "Running quick command with 5s timeout:"
if run_with_timeout 5 sleep 0.5; then
    echo "  Command completed within timeout"
fi

echo ""
echo "Script ending — EXIT trap will fire next"
