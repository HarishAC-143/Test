#!/bin/bash
# File Locking and Concurrency — mkdir lock, flock, parallel execution

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== Method 1: mkdir-Based Locking (Portable) ==="
LOCKDIR="$tmpdir/myapp.lock.d"

acquire_lock_mkdir() {
    local max_wait=${2:-10}
    local waited=0
    while ! mkdir "$LOCKDIR" 2>/dev/null; do
        local owner
        owner=$(cat "$LOCKDIR/pid" 2>/dev/null || echo "unknown")
        if [[ "$owner" != "unknown" ]] && ! kill -0 "$owner" 2>/dev/null; then
            echo "  Stale lock from dead PID $owner, removing"
            rm -rf "$LOCKDIR"
            continue
        fi
        if (( waited >= max_wait )); then
            echo "  Timeout waiting for lock (held by PID $owner)"
            return 1
        fi
        sleep 1
        ((waited++))
    done
    echo $$ > "$LOCKDIR/pid"
    return 0
}

release_lock_mkdir() {
    rm -rf "$LOCKDIR"
}

echo "Acquiring mkdir lock..."
if acquire_lock_mkdir; then
    echo "  Lock acquired! PID $$ doing work..."
    sleep 0.5
    release_lock_mkdir
    echo "  Lock released."
fi

echo ""
echo "=== Method 2: flock-Based Locking (Linux) ==="
LOCKFILE="$tmpdir/myapp.flock"

if command -v flock &>/dev/null; then
    (
        flock -n 200 || { echo "Cannot acquire lock"; exit 1; }
        echo "  flock acquired! PID=$$ in critical section..."
        sleep 0.5
        echo "  flock released."
    ) 200>"$LOCKFILE"
else
    echo "  (flock not available on this system)"
fi

echo ""
echo "=== Method 3: Controlled Parallel Execution ==="
MAX_PARALLEL=3
RESULTS_DIR="$tmpdir/results"
mkdir -p "$RESULTS_DIR"

simulate_task() {
    local task_id="$1"
    local duration=$(( (RANDOM % 3) + 1 ))
    sleep "$duration"
    echo "completed in ${duration}s" > "$RESULTS_DIR/task_${task_id}.result"
}

echo "Running 8 tasks with max $MAX_PARALLEL in parallel:"
pids=()
task_names=()

for i in {1..8}; do
    while (( ${#pids[@]} >= MAX_PARALLEL )); do
        new_pids=()
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")
            fi
        done
        pids=("${new_pids[@]}")
        sleep 0.1
    done

    simulate_task "$i" &
    pids+=($!)
    task_names+=("task_$i")
    echo "  Started task_$i (PID: ${pids[-1]})"
done

echo "  Waiting for remaining tasks..."
for pid in "${pids[@]}"; do
    wait "$pid"
done

echo ""
echo "Results:"
for f in "$RESULTS_DIR"/*.result; do
    [[ -f "$f" ]] || continue
    task_name=$(basename "$f" .result)
    result=$(<"$f")
    echo "  $task_name: $result"
done

echo ""
echo "=== Method 4: Semaphore Pattern ==="
SEMAPHORE_DIR="$tmpdir/semaphore"
mkdir -p "$SEMAPHORE_DIR"
MAX_SLOTS=2

acquire_slot() {
    while true; do
        for ((slot=0; slot<MAX_SLOTS; slot++)); do
            if mkdir "$SEMAPHORE_DIR/slot_$slot" 2>/dev/null; then
                echo "$slot"
                return 0
            fi
        done
        sleep 0.1
    done
}

release_slot() {
    rmdir "$SEMAPHORE_DIR/slot_$1" 2>/dev/null
}

semaphore_task() {
    local name="$1"
    local slot
    slot=$(acquire_slot)
    echo "  $name started (slot $slot)"
    sleep 1
    echo "  $name finished (slot $slot)"
    release_slot "$slot"
}

echo "Semaphore with $MAX_SLOTS slots:"
for name in "JobA" "JobB" "JobC" "JobD"; do
    semaphore_task "$name" &
done
wait
echo "All semaphore jobs done"

echo ""
echo "=== Practical: Safe Counter ==="
COUNTER_FILE="$tmpdir/counter"
echo "0" > "$COUNTER_FILE"

safe_increment() {
    (
        flock -x 200 2>/dev/null || true
        local val
        val=$(<"$COUNTER_FILE")
        ((val++))
        echo "$val" > "$COUNTER_FILE"
    ) 200>"$tmpdir/counter.lock"
}

echo "Incrementing counter 20 times in parallel:"
for i in {1..20}; do
    safe_increment &
done
wait

echo "  Final counter value: $(<"$COUNTER_FILE") (expected: 20)"
