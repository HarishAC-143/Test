#!/bin/bash
# 06_file_operations.sh -- File I/O, redirection, pipes, here documents
#
# Demonstrates: file tests, reading/writing files, I/O redirection,
#               pipes, process substitution, here docs
#
# Usage: ./06_file_operations.sh

set -euo pipefail

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "========================================="
echo "  File Operations Examples"
echo "========================================="
echo "Working directory: $WORK_DIR"

# --- WRITING FILES ---
echo ""
echo "--- Writing Files ---"

echo "Line 1: Hello, File!" > "$WORK_DIR/output.txt"
echo "Line 2: Appended text" >> "$WORK_DIR/output.txt"
echo "Line 3: More content" >> "$WORK_DIR/output.txt"
echo "Created output.txt with 3 lines"

printf "%-15s %5s %10s\n" "Name" "Age" "City" > "$WORK_DIR/data.txt"
printf "%-15s %5d %10s\n" "Alice" 30 "NYC" >> "$WORK_DIR/data.txt"
printf "%-15s %5d %10s\n" "Bob" 25 "LA" >> "$WORK_DIR/data.txt"
printf "%-15s %5d %10s\n" "Charlie" 35 "Chicago" >> "$WORK_DIR/data.txt"
echo "Created data.txt with formatted data"

# Here document
cat > "$WORK_DIR/config.ini" << 'EOF'
[database]
host=localhost
port=5432
name=myapp_db

[server]
listen=0.0.0.0
port=8080
workers=4

[logging]
level=info
file=/var/log/app.log
EOF
echo "Created config.ini using here document"

# --- FILE TESTS ---
echo ""
echo "--- File Tests ---"
test_file="$WORK_DIR/output.txt"

[[ -e "$test_file" ]] && echo "  Exists: YES" || echo "  Exists: NO"
[[ -f "$test_file" ]] && echo "  Regular file: YES" || echo "  Regular file: NO"
[[ -d "$WORK_DIR" ]]  && echo "  Is directory: YES ($WORK_DIR)"
[[ -r "$test_file" ]] && echo "  Readable: YES" || echo "  Readable: NO"
[[ -w "$test_file" ]] && echo "  Writable: YES" || echo "  Writable: NO"
[[ -s "$test_file" ]] && echo "  Non-empty: YES ($(wc -c < "$test_file") bytes)"

# --- READING FILES ---
echo ""
echo "--- Reading Entire File ---"
content=$(<"$WORK_DIR/output.txt")
echo "$content"

echo ""
echo "--- Reading Line by Line ---"
line_num=0
while IFS= read -r line; do
    ((++line_num))
    printf "  %3d: %s\n" "$line_num" "$line"
done < "$WORK_DIR/output.txt"

echo ""
echo "--- Reading with Field Splitting ---"
echo "Parsing config.ini [database] section:"
in_section=false
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

    if [[ "$key" == "[database]" ]]; then
        in_section=true
        continue
    elif [[ "$key" == \[*\] ]]; then
        in_section=false
        continue
    fi

    if $in_section && [[ -n "$value" ]]; then
        printf "  %-10s = %s\n" "$key" "$value"
    fi
done < "$WORK_DIR/config.ini"

echo ""
echo "--- Reading into Array (mapfile) ---"
mapfile -t lines < "$WORK_DIR/output.txt"
echo "  Read ${#lines[@]} lines into array"
echo "  Last line: '${lines[-1]}'"

# --- I/O REDIRECTION ---
echo ""
echo "--- I/O Redirection ---"

echo "stdout goes here" > "$WORK_DIR/stdout.txt"
ls /nonexistent_file 2> "$WORK_DIR/stderr.txt" || true
echo "  stdout.txt: $(cat "$WORK_DIR/stdout.txt")"
echo "  stderr.txt: $(cat "$WORK_DIR/stderr.txt")"

{ echo "combined stdout"; ls /no_file 2>&1 || true; } > "$WORK_DIR/combined.txt" 2>&1
echo "  combined.txt has $(wc -l < "$WORK_DIR/combined.txt") lines"

echo "This goes to /dev/null" > /dev/null
echo "  Redirected to /dev/null (discarded)"

# --- CUSTOM FILE DESCRIPTORS ---
echo ""
echo "--- Custom File Descriptors ---"

exec 3> "$WORK_DIR/fd3_output.txt"
echo "Written via FD 3, line 1" >&3
echo "Written via FD 3, line 2" >&3
exec 3>&-

echo "  FD 3 output:"
while IFS= read -r line; do
    echo "    $line"
done < "$WORK_DIR/fd3_output.txt"

# --- PIPES ---
echo ""
echo "--- Pipes ---"

echo "  Files in /etc (first 5 .conf files):"
find /etc -maxdepth 1 -name "*.conf" -type f 2>/dev/null | sort | head -5 | while read -r f; do
    echo "    $(basename "$f")"
done

echo ""
echo "  Pipeline: generate | filter | transform | count"
result=$(seq 1 100 | grep -E '[0-9]*[05]$' | awk '{sum += $1} END {print sum}')
echo "  Sum of multiples of 5 from 1-100: $result"

# --- PROCESS SUBSTITUTION ---
echo ""
echo "--- Process Substitution ---"

echo -e "alpha\nbeta\ngamma" > "$WORK_DIR/list1.txt"
echo -e "beta\ngamma\ndelta" > "$WORK_DIR/list2.txt"

echo "  list1: $(cat "$WORK_DIR/list1.txt" | tr '\n' ' ')"
echo "  list2: $(cat "$WORK_DIR/list2.txt" | tr '\n' ' ')"

echo "  Common (comm -12):"
comm -12 <(sort "$WORK_DIR/list1.txt") <(sort "$WORK_DIR/list2.txt") | while read -r line; do
    echo "    $line"
done

echo "  Only in list1 (comm -23):"
comm -23 <(sort "$WORK_DIR/list1.txt") <(sort "$WORK_DIR/list2.txt") | while read -r line; do
    echo "    $line"
done

# --- HERE STRINGS ---
echo ""
echo "--- Here Strings ---"

read -r word1 word2 word3 <<< "alpha beta gamma"
echo "  Parsed: word1=$word1, word2=$word2, word3=$word3"

if command -v bc &>/dev/null; then
    result=$(bc <<< "scale=4; 355/113")
    echo "  bc calculation (355/113): $result"
else
    result=$(awk 'BEGIN {printf "%.4f", 355/113}')
    echo "  awk calculation (355/113): $result"
fi

upper=$(tr '[:lower:]' '[:upper:]' <<< "hello world")
echo "  Uppercase via here string: $upper"

# --- TEMPORARY FILES ---
echo ""
echo "--- Safe Temporary Files ---"

tmp=$(mktemp "$WORK_DIR/tempXXXXXX")
echo "  Created temp file: $(basename "$tmp")"
echo "temporary data" > "$tmp"
echo "  Contents: $(cat "$tmp")"

tmpdir=$(mktemp -d "$WORK_DIR/tmpdirXXXXXX")
echo "  Created temp dir: $(basename "$tmpdir")"
touch "$tmpdir/file1" "$tmpdir/file2"
echo "  Files inside: $(ls "$tmpdir" | tr '\n' ' ')"

echo ""
echo "All file operation examples complete!"
echo "(Working directory $WORK_DIR will be cleaned up on exit)"
