#!/bin/bash
# Performance Optimization — built-ins vs externals, batching, benchmarking

echo "=== Tip 1: Built-in String Operations vs External Commands ==="
path="/home/user/documents/file.txt"

echo "--- External commands ---"
time (for i in {1..500}; do basename "$path" > /dev/null; done) 2>&1

echo "--- Parameter expansion ---"
time (for i in {1..500}; do x="${path##*/}"; done) 2>&1

echo ""
echo "=== Tip 2: Avoid Unnecessary Forks ==="

echo "--- Using cut (external) ---"
time (
    for i in {1..200}; do
        echo "hello:world:foo" | cut -d: -f1 > /dev/null
    done
) 2>&1

echo "--- Using parameter expansion (built-in) ---"
time (
    str="hello:world:foo"
    for i in {1..200}; do
        x="${str%%:*}"
    done
) 2>&1

echo ""
echo "=== Tip 3: printf vs echo ==="
echo "printf is more portable and slightly faster for formatted output."
printf "Name: %-10s Age: %3d\n" "Alice" 30
printf "Name: %-10s Age: %3d\n" "Bob" 25

echo ""
echo "=== Tip 4: Read Entire File at Once ==="
tmpfile=$(mktemp)
for i in {1..100}; do echo "Line $i"; done > "$tmpfile"

echo "--- Line by line ---"
time (
    while IFS= read -r line; do
        :
    done < "$tmpfile"
) 2>&1

echo "--- Entire file at once ---"
time (
    content=$(<"$tmpfile")
) 2>&1
rm "$tmpfile"

echo ""
echo "=== Tip 5: mapfile/readarray for Bulk Reading ==="
tmpfile=$(mktemp)
for i in {1..100}; do echo "Data line $i"; done > "$tmpfile"

echo "--- while read loop ---"
time (
    arr=()
    while IFS= read -r line; do
        arr+=("$line")
    done < "$tmpfile"
) 2>&1

echo "--- mapfile ---"
time (
    mapfile -t arr < "$tmpfile"
) 2>&1

echo "Lines read: ${#arr[@]}"
rm "$tmpfile"

echo ""
echo "=== Tip 6: Batch Operations ==="
echo "Instead of multiple greps:"
echo "  grep 'a' file; grep 'b' file; grep 'c' file"
echo "Use single grep with alternation:"
echo "  grep -E 'a|b|c' file"

echo ""
echo "=== Tip 7: Use Arrays Instead of Repeated Parsing ==="
time (
    items=()
    for i in {1..5000}; do
        items+=("item_$i")
    done
) 2>&1
echo "Built array with ${#items[@]} items"

echo ""
echo "=== Tip 8: Avoid Subshells in Loops ==="
tmpfile=$(mktemp)
for i in {1..50}; do echo "line $i"; done > "$tmpfile"

echo "--- Pipe (creates subshell) ---"
time (
    count=0
    cat "$tmpfile" | while read -r line; do ((count++)); done
) 2>&1

echo "--- Redirect (no subshell) ---"
time (
    count=0
    while read -r line; do ((count++)); done < "$tmpfile"
) 2>&1
rm "$tmpfile"

echo ""
echo "=== Tip 9: Use [[ ]] Over [ ] ==="
echo "[[ ]] is a Bash built-in — faster than [ ] which may fork /usr/bin/test"

echo ""
echo "=== Tip 10: Arithmetic Comparison ==="
echo "--- Using [[ ]] with -gt ---"
time (
    for i in {1..5000}; do
        [[ $i -gt 2500 ]] && true
    done
) 2>&1

echo "--- Using (( )) ---"
time (
    for i in {1..5000}; do
        (( i > 2500 )) && true
    done
) 2>&1

echo ""
echo "=== Summary ==="
cat << 'EOF'
Performance Tips:
  1. Use ${var##*/} instead of basename
  2. Use ${var%%:*} instead of cut/awk
  3. Use printf for formatted output
  4. Read files with $(<file) when possible
  5. Use mapfile for bulk file reading
  6. Batch grep patterns: grep -E "a|b|c"
  7. Pre-build arrays instead of re-parsing
  8. Use redirect < instead of cat | pipe
  9. Use [[ ]] and (( )) built-ins
  10. Minimize subshell creation in loops
EOF
