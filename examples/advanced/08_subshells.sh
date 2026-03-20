#!/bin/bash
# Subshells and Command Grouping — isolation, parallel execution, coprocess

echo "=== Subshell Isolation ==="
x=10
echo "Before subshell: x=$x, pwd=$(pwd)"
(
    x=20
    cd /tmp
    echo "Inside subshell: x=$x, pwd=$(pwd)"
)
echo "After subshell:  x=$x, pwd=$(pwd)"

echo ""
echo "=== Command Grouping (Current Shell) ==="
y=10
echo "Before group: y=$y"
{
    y=20
    echo "Inside group: y=$y"
}
echo "After group:  y=$y (changed!)"

echo ""
echo "=== Redirect a Group ==="
tmpfile=$(mktemp)
{
    echo "Group line 1"
    echo "Group line 2"
    echo "Group line 3"
} > "$tmpfile"
echo "Group output (from file):"
cat "$tmpfile"
rm "$tmpfile"

echo ""
echo "=== Subshell for Environment Isolation ==="
original_path="$PATH"
(
    export PATH="/custom/bin:$PATH"
    echo "Modified PATH in subshell starts with: ${PATH:0:20}..."
)
if [[ "$PATH" == "$original_path" ]]; then
    echo "PATH unchanged in parent (confirmed)"
fi

echo ""
echo "=== Parallel Execution ==="
start=$SECONDS

task() {
    local name="$1" duration="$2"
    sleep "$duration"
    echo "  Task $name completed (${duration}s)"
}

task "A" 1 &
task "B" 1 &
task "C" 1 &
wait

elapsed=$((SECONDS - start))
echo "All parallel tasks completed in ${elapsed}s (should be ~1s, not ~3s)"

echo ""
echo "=== Sequential vs Parallel Comparison ==="
echo "--- Sequential ---"
start=$SECONDS
sleep 0.3
sleep 0.3
sleep 0.3
echo "  Sequential: $((SECONDS - start))s"

echo "--- Parallel ---"
start=$SECONDS
sleep 0.3 &
sleep 0.3 &
sleep 0.3 &
wait
echo "  Parallel: $((SECONDS - start))s"

echo ""
echo "=== Capturing Subshell Output ==="
result=$(
    total=0
    for i in {1..100}; do
        ((total += i))
    done
    echo $total
)
echo "Sum of 1-100: $result"

echo ""
echo "=== Nested Subshells ==="
echo "Level 0: BASHPID=$$"
(
    echo "  Level 1: BASHPID=$BASHPID"
    (
        echo "    Level 2: BASHPID=$BASHPID"
    )
)

echo ""
echo "=== Practical: Parallel Downloads Simulation ==="
download_sim() {
    local url="$1"
    local duration=$((RANDOM % 3 + 1))
    sleep "$duration"
    echo "  Downloaded $url (${duration}s)"
}

urls=("https://example.com/file1" "https://example.com/file2" "https://example.com/file3")
echo "Starting parallel downloads..."
start=$SECONDS
pids=()

for url in "${urls[@]}"; do
    download_sim "$url" &
    pids+=($!)
done

all_ok=true
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        echo "  Download PID $pid failed"
        all_ok=false
    fi
done

elapsed=$((SECONDS - start))
if $all_ok; then
    echo "All downloads completed in ${elapsed}s"
else
    echo "Some downloads failed (${elapsed}s)"
fi

echo ""
echo "=== Coprocess (Bash 4.0+) ==="
coproc ADDER {
    while read -r a b; do
        echo $(( a + b ))
    done
}

echo "5 3" >&"${ADDER[1]}"
read -r sum <&"${ADDER[0]}"
echo "Coprocess 5+3 = $sum"

echo "10 20" >&"${ADDER[1]}"
read -r sum <&"${ADDER[0]}"
echo "Coprocess 10+20 = $sum"

echo "100 200" >&"${ADDER[1]}"
read -r sum <&"${ADDER[0]}"
echo "Coprocess 100+200 = $sum"

exec {ADDER[1]}>&-
wait "$ADDER_PID" 2>/dev/null
echo "Coprocess terminated"
