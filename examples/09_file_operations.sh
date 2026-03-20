#!/bin/bash
# File operations: reading, writing, testing, and temporary files

DEMO_DIR=$(mktemp -d)
trap 'rm -rf "$DEMO_DIR"' EXIT

echo "Working directory: $DEMO_DIR"

echo ""
echo "=== Writing Files ==="
echo "Line 1: Hello" > "$DEMO_DIR/output.txt"
echo "Line 2: World" >> "$DEMO_DIR/output.txt"
echo "Line 3: BASH is great" >> "$DEMO_DIR/output.txt"
echo "Created output.txt with 3 lines"

cat > "$DEMO_DIR/config.ini" << 'EOF'
[database]
host=localhost
port=5432
name=myapp_db

[server]
host=0.0.0.0
port=8080
debug=false
EOF
echo "Created config.ini with heredoc"

echo ""
echo "=== Reading Files ==="
echo "--- Method 1: Read entire file ---"
content=$(< "$DEMO_DIR/output.txt")
echo "$content"

echo ""
echo "--- Method 2: Line by line ---"
line_num=0
while IFS= read -r line; do
    (( line_num++ ))
    printf "  %3d: %s\n" "$line_num" "$line"
done < "$DEMO_DIR/config.ini"

echo ""
echo "--- Method 3: Read into array ---"
mapfile -t lines < "$DEMO_DIR/output.txt"
echo "Total lines: ${#lines[@]}"
echo "First: ${lines[0]}"
echo "Last:  ${lines[-1]}"

echo ""
echo "=== File Testing ==="
check_file() {
    local f="$1"
    echo "File: $f"
    [[ -e "$f" ]] && echo "  Exists: yes" || echo "  Exists: no"
    [[ -f "$f" ]] && echo "  Regular file: yes"
    [[ -d "$f" ]] && echo "  Directory: yes"
    [[ -r "$f" ]] && echo "  Readable: yes"
    [[ -w "$f" ]] && echo "  Writable: yes"
    [[ -s "$f" ]] && echo "  Non-empty: yes"
}

check_file "$DEMO_DIR/output.txt"
echo ""
check_file "$DEMO_DIR"
echo ""
check_file "$DEMO_DIR/nonexistent.txt"

echo ""
echo "=== Temporary Files ==="
tmpfile=$(mktemp "$DEMO_DIR/tmp.XXXXXX")
echo "Created temp file: $tmpfile"
echo "Temporary data: $(date)" > "$tmpfile"
cat "$tmpfile"

echo ""
echo "=== Processing Structured Data ==="
cat > "$DEMO_DIR/data.csv" << 'EOF'
Name,Age,City,Score
Alice,30,New York,92
Bob,25,London,88
Charlie,35,Paris,95
Diana,28,Tokyo,91
Eve,32,Berlin,87
EOF

echo "--- CSV Processing ---"
printf "%-10s %-5s %-10s %-5s\n" "Name" "Age" "City" "Score"
printf "%s\n" "$(printf '─%.0s' {1..35})"
while IFS=',' read -r name age city score; do
    [[ "$name" == "Name" ]] && continue
    printf "%-10s %-5s %-10s %-5s\n" "$name" "$age" "$city" "$score"
done < "$DEMO_DIR/data.csv"

echo ""
echo "=== File Comparison ==="
echo "hello world" > "$DEMO_DIR/file_a.txt"
echo "hello world" > "$DEMO_DIR/file_b.txt"
echo "hello BASH" > "$DEMO_DIR/file_c.txt"

if cmp -s "$DEMO_DIR/file_a.txt" "$DEMO_DIR/file_b.txt"; then
    echo "file_a.txt and file_b.txt are identical"
fi

if ! cmp -s "$DEMO_DIR/file_a.txt" "$DEMO_DIR/file_c.txt"; then
    echo "file_a.txt and file_c.txt are different"
    diff "$DEMO_DIR/file_a.txt" "$DEMO_DIR/file_c.txt" || true
fi
