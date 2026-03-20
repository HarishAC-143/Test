#!/bin/bash
# 07_advanced_topics.sh -- Advanced BASH: processes, signals, debugging, error handling
#
# Demonstrates: process management, trap/signals, subshells,
#               debugging, error handling, strict mode
#
# Usage: ./07_advanced_topics.sh

set -euo pipefail

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "========================================="
echo "  Advanced BASH Topics"
echo "========================================="

# --- BACKGROUND PROCESSES ---
echo ""
echo "--- Background Processes ---"

simulate_work() {
    local name="$1"
    local duration="$2"
    sleep "$duration"
    echo "$name completed (${duration}s)"
}

echo "Starting 3 background tasks..."
simulate_work "Task-A" 1 &
pid_a=$!
simulate_work "Task-B" 2 &
pid_b=$!
simulate_work "Task-C" 1 &
pid_c=$!

echo "  Task-A PID: $pid_a"
echo "  Task-B PID: $pid_b"
echo "  Task-C PID: $pid_c"

echo "Waiting for all tasks..."
wait "$pid_a" && echo "  Task-A: success" || echo "  Task-A: failed"
wait "$pid_b" && echo "  Task-B: success" || echo "  Task-B: failed"
wait "$pid_c" && echo "  Task-C: success" || echo "  Task-C: failed"

# --- PARALLEL EXECUTION WITH STATUS ---
echo ""
echo "--- Parallel Execution Pattern ---"

run_parallel() {
    local -a pids=()
    local -a names=()

    for i in {1..4}; do
        (sleep $((RANDOM % 2 + 1)); exit $((RANDOM % 2))) &
        pids+=($!)
        names+=("Job-$i")
    done

    local failed=0
    for i in "${!pids[@]}"; do
        if wait "${pids[$i]}" 2>/dev/null; then
            echo "  ${names[$i]} (PID ${pids[$i]}): PASSED"
        else
            echo "  ${names[$i]} (PID ${pids[$i]}): FAILED"
            ((++failed))
        fi
    done

    echo "  Result: $((${#pids[@]} - failed))/${#pids[@]} succeeded"
}

run_parallel

# --- SUBSHELLS ---
echo ""
echo "--- Subshells vs Command Grouping ---"

var="original"

echo "Subshell (changes don't leak):"
(
    var="changed_in_subshell"
    cd /tmp
    echo "  Inside subshell: var=$var, pwd=$(pwd)"
)
echo "  After subshell: var=$var, pwd=$(pwd)"

echo ""
echo "Command grouping (changes persist):"
{
    var="changed_in_group"
    echo "  Inside group: var=$var"
}
echo "  After group: var=$var"

var="original"  # Reset

echo ""
echo "Subshell for isolating failures:"
(
    set +e  # Allow errors in subshell
    false
    echo "  This prints because set +e is in effect"
)
echo "  Main script continues (exit status of subshell: $?)"

# --- TRAP AND SIGNAL HANDLING ---
echo ""
echo "--- Trap and Cleanup ---"

cleanup_demo() {
    local tmpfile
    tmpfile=$(mktemp "$WORK_DIR/trap_demoXXXXXX")

    cleanup() {
        echo "  Cleanup: removing $(basename "$tmpfile")"
        rm -f "$tmpfile"
    }
    trap cleanup RETURN

    echo "  Created: $(basename "$tmpfile")"
    echo "test data" > "$tmpfile"
    echo "  File exists: $([[ -f "$tmpfile" ]] && echo yes || echo no)"
}

cleanup_demo
echo "  (Cleanup was triggered automatically on function return)"

# --- ERROR HANDLING PATTERNS ---
echo ""
echo "--- Error Handling ---"

die() {
    echo "FATAL: $*" >&2
    return 1
}

try_command() {
    local cmd_output
    if cmd_output=$("$@" 2>&1); then
        echo "  SUCCESS: $cmd_output"
        return 0
    else
        echo "  FAILED ($?): $cmd_output"
        return 1
    fi
}

echo "Trying commands:"
try_command echo "hello world" || true
try_command ls /this/does/not/exist || true

echo ""
echo "--- Retry Pattern ---"

retry() {
    local max_attempts=$1
    local delay=$2
    shift 2

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        if "$@" 2>/dev/null; then
            echo "  Succeeded on attempt $attempt"
            return 0
        fi
        echo "  Attempt $attempt failed, waiting ${delay}s..."
        sleep "$delay"
    done

    echo "  All $max_attempts attempts failed"
    return 1
}

test_file="$WORK_DIR/retry_target"
(sleep 2 && touch "$test_file") &

retry 5 1 test -f "$test_file" || true

# --- DEBUGGING TECHNIQUES ---
echo ""
echo "--- Debugging Techniques ---"

demo_debug() {
    local saved_opts="$-"

    echo "  Enabling trace (set -x) for this section:"
    set -x
    local x=5
    local y=10
    local sum=$((x + y))
    [[ "$saved_opts" != *x* ]] && set +x

    echo "  Sum computed: $sum (tracing was active above)"
}

demo_debug

echo ""
echo "  Custom PS4 for enhanced trace output:"
(
    export PS4='  + [${BASH_SOURCE##*/}:${LINENO}] '
    set -x
    local_var="traced"
    echo "$local_var" > /dev/null
    set +x
) 2>&1

echo ""
echo "--- Conditional Debugging ---"

DEBUG="${DEBUG:-false}"

debug_log() {
    [[ "$DEBUG" == "true" ]] && echo "  [DEBUG] $*" >&2 || true
}

echo "  DEBUG=$DEBUG (set DEBUG=true to see debug messages)"
debug_log "This is a debug message"
debug_log "Another debug detail"

# Run with debug enabled
DEBUG=true
debug_log "Now debug is enabled -- this message appears"
DEBUG=false

# --- STRICT MODE EXPLAINED ---
echo ""
echo "--- Strict Mode (set -euo pipefail) ---"

echo "  set -e : Exit immediately on command failure"
echo "  set -u : Treat unset variables as errors"
echo "  set -o pipefail : Pipe returns rightmost non-zero exit code"
echo ""

echo "  PIPESTATUS example:"
(
    set +eo pipefail
    echo "hello" | grep "goodbye" | cat > /dev/null
    echo "  Exit codes: ${PIPESTATUS[0]} ${PIPESTATUS[1]} ${PIPESTATUS[2]}"
    echo "  (echo=0, grep=1 (no match), cat=0)"
)

# --- HEREDOC TRICKS ---
echo ""
echo "--- Advanced Here Documents ---"

read -r -d '' help_text << 'HELP' || true
This is a multi-line string
stored in a variable using
a here document with read.

It preserves all formatting
and whitespace exactly.
HELP

echo "  Multi-line variable (${#help_text} chars):"
echo "$help_text" | while IFS= read -r line; do
    echo "    > $line"
done

# --- NAMEREF (Pass by Reference) ---
echo ""
echo "--- Nameref (Pass by Reference) ---"

increment() {
    local -n ref=$1
    ((++ref))
}

counter=0
echo "  Before: counter=$counter"
increment counter
increment counter
increment counter
echo "  After 3 increments: counter=$counter"

swap() {
    local -n a=$1
    local -n b=$2
    local tmp="$a"
    a="$b"
    b="$tmp"
}

x="first"
y="second"
echo "  Before swap: x=$x, y=$y"
swap x y
echo "  After swap:  x=$x, y=$y"

echo ""
echo "All advanced topic examples complete!"
