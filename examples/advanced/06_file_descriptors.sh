#!/bin/bash
# File Descriptors and Advanced Redirection — custom FDs, swapping, logging

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== Open FD for Writing ==="
exec 3> "$tmpdir/fd3_output.txt"
echo "Line 1 to fd 3" >&3
echo "Line 2 to fd 3" >&3
echo "Line 3 to fd 3" >&3
exec 3>&-
echo "Wrote 3 lines to fd 3:"
cat "$tmpdir/fd3_output.txt"

echo ""
echo "=== Open FD for Reading ==="
echo -e "alpha\nbeta\ngamma\ndelta" > "$tmpdir/fd4_input.txt"
exec 4< "$tmpdir/fd4_input.txt"
read -r line1 <&4
read -r line2 <&4
read -r line3 <&4
exec 4<&-
echo "Read from fd 4: '$line1', '$line2', '$line3'"

echo ""
echo "=== Read/Write FD ==="
exec 5<> "$tmpdir/fd5_rw.txt"
echo "Written via fd 5" >&5
exec 5<&-
echo "Read back: $(cat "$tmpdir/fd5_rw.txt")"

echo ""
echo "=== Redirect a Block ==="
{
    echo "Block line 1"
    echo "Block line 2"
    echo "Block line 3"
} > "$tmpdir/block_output.txt"
echo "Block output:"
cat "$tmpdir/block_output.txt"

echo ""
echo "=== Separate stdout and stderr ==="
{
    echo "This is stdout"
    echo "This is stderr" >&2
    echo "More stdout"
    echo "More stderr" >&2
} > "$tmpdir/stdout.txt" 2> "$tmpdir/stderr.txt"

echo "Captured stdout:"
cat "$tmpdir/stdout.txt"
echo "Captured stderr:"
cat "$tmpdir/stderr.txt"

echo ""
echo "=== Swap stdout and stderr ==="
echo "Before swap (stdout=1, stderr=2):"
{
    echo "  stdout message"
    echo "  stderr message" >&2
} 2>/dev/null

echo ""
echo "=== Practical: Logging Framework ==="
LOG_FILE="$tmpdir/app.log"

setup_logging() {
    exec 6>&1
    exec > >(while IFS= read -r line; do
        echo "[$(date '+%H:%M:%S')] $line" | tee -a "$LOG_FILE" >&6
    done)
}

teardown_logging() {
    exec 1>&6 6>&-
}

setup_logging
echo "Application started"
echo "Processing data..."
echo "Task complete"
teardown_logging

sleep 0.5
echo ""
echo "Log file contents:"
cat "$LOG_FILE"

echo ""
echo "=== Practical: Reading Two Files Simultaneously ==="
echo -e "Alice\nBob\nCharlie" > "$tmpdir/names.txt"
echo -e "30\n25\n35" > "$tmpdir/ages.txt"

exec 7< "$tmpdir/names.txt"
exec 8< "$tmpdir/ages.txt"

echo "Name-Age pairs:"
while read -r name <&7 && read -r age <&8; do
    echo "  $name is $age years old"
done

exec 7<&-
exec 8<&-
