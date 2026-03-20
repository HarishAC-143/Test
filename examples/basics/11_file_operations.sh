#!/bin/bash
# File Operations — create, read, write, copy, move, delete, test

testdir="/tmp/bash_tutorial_file_ops_$$"
mkdir -p "$testdir"
trap 'rm -rf "$testdir"' EXIT

echo "=== Creating Files ==="
echo "Hello World" > "$testdir/file1.txt"
echo "Bash Tutorial" > "$testdir/file2.txt"
date > "$testdir/timestamp.txt"
printf "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\n" > "$testdir/multiline.txt"
echo "Files created in $testdir"

echo ""
echo "=== File Tests ==="
for f in "$testdir/file1.txt" "$testdir/nonexistent" "/tmp" "$testdir/multiline.txt"; do
    printf "  %-40s " "$f"
    if [[ ! -e "$f" ]]; then
        echo "does not exist"
    elif [[ -f "$f" ]]; then
        echo "regular file ($(wc -c < "$f") bytes)"
    elif [[ -d "$f" ]]; then
        echo "directory"
    fi
done

echo ""
echo "=== Reading Files ==="
echo "--- Read line by line ---"
while IFS= read -r line; do
    echo "  > $line"
done < "$testdir/multiline.txt"

echo "--- Read into variable ---"
content=$(<"$testdir/file2.txt")
echo "  Content: '$content'"

echo "--- Read into array ---"
mapfile -t lines < "$testdir/multiline.txt"
echo "  Line count: ${#lines[@]}"
echo "  Line 3: '${lines[2]}'"

echo ""
echo "=== Writing and Appending ==="
echo "Original line" > "$testdir/append_test.txt"
echo "Appended line 1" >> "$testdir/append_test.txt"
echo "Appended line 2" >> "$testdir/append_test.txt"
echo "Contents of append_test.txt:"
cat "$testdir/append_test.txt"

echo ""
echo "=== Copy, Move, Remove ==="
cp "$testdir/file1.txt" "$testdir/file1_backup.txt"
echo "Copied file1.txt -> file1_backup.txt"

mv "$testdir/timestamp.txt" "$testdir/time.txt"
echo "Moved timestamp.txt -> time.txt"

rm "$testdir/file2.txt"
echo "Removed file2.txt"

echo ""
echo "=== Directory Listing ==="
echo "Files in $testdir:"
for f in "$testdir"/*; do
    [[ -e "$f" ]] || continue
    printf "  %-30s %s\n" "$(basename "$f")" "$(wc -c < "$f" 2>/dev/null || echo '?') bytes"
done

echo ""
echo "=== Finding Files by Pattern ==="
echo ".txt files:"
for f in "$testdir"/*.txt; do
    [[ -f "$f" ]] && echo "  $(basename "$f")"
done

echo ""
echo "=== File Information ==="
file="$testdir/file1.txt"
echo "File: $file"
echo "  Size: $(wc -c < "$file") bytes"
echo "  Lines: $(wc -l < "$file")"
echo "  Words: $(wc -w < "$file")"

echo ""
echo "=== Temporary Files ==="
tmpfile=$(mktemp)
tmpdir_created=$(mktemp -d)
echo "Temp file: $tmpfile"
echo "Temp dir:  $tmpdir_created"
echo "secret data" > "$tmpfile"
rm "$tmpfile"
rmdir "$tmpdir_created"
echo "Cleaned up temp file and dir"

echo ""
echo "Test directory will be cleaned up on exit (trap)"
