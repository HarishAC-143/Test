#!/bin/bash
# Here Documents and Here Strings — multi-line input, templating

echo "=== Basic Here Document ==="
cat << EOF
This is a here document.
Variables are expanded: HOME=$HOME
Command substitution: $(date +%Y)
Arithmetic: $((6 * 7))
Special chars need no escaping: $ " '
EOF

echo ""
echo "=== Quoted Delimiter (No Expansion) ==="
cat << 'EOF'
This text is completely literal.
$HOME is not expanded.
$(date) is not executed.
$(( 1 + 1 )) is not calculated.
EOF

echo ""
echo "=== Indented Here Document (<<-) ==="
if true; then
	cat <<-EOF
	Indented with tabs.
	The leading tabs are stripped.
	This keeps code nicely indented.
	EOF
fi

echo ""
echo "=== Write to a File ==="
tmpfile=$(mktemp)
cat << EOF > "$tmpfile"
[database]
host = localhost
port = 5432
name = myapp
user = admin
password = secret123
EOF
echo "Written config to $tmpfile:"
cat "$tmpfile"
rm "$tmpfile"

echo ""
echo "=== HTML Template ==="
generate_html() {
    local title="$1"
    local body="$2"
    local items=("${@:3}")

    cat << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$title</title>
    <style>body { font-family: sans-serif; margin: 2em; }</style>
</head>
<body>
    <h1>$title</h1>
    <p>$body</p>
    <ul>
EOF
    for item in "${items[@]}"; do
        echo "        <li>$item</li>"
    done
    cat << EOF
    </ul>
    <footer>Generated at $(date)</footer>
</body>
</html>
EOF
}

echo "Generated HTML:"
generate_html "My Page" "Welcome to Bash templating!" "Item One" "Item Two" "Item Three"

echo ""
echo "=== SQL Template ==="
generate_sql() {
    local table="$1"
    local columns="$2"
    local where_clause="${3:-1=1}"

    cat << EOF
SELECT $columns
FROM $table
WHERE $where_clause
ORDER BY id DESC
LIMIT 100;
EOF
}

echo "Generated SQL:"
generate_sql "users" "id, name, email" "active = true AND role = 'admin'"

echo ""
echo "=== Here String (<<<) ==="
result=$(grep "hello" <<< "hello world")
echo "Here string grep: '$result'"

data="apple
banana
cherry"
count=$(wc -l <<< "$data")
echo "Lines in here string: $count"

upper=$(tr '[:lower:]' '[:upper:]' <<< "make me uppercase")
echo "Uppercase: $upper"

echo ""
echo "=== Here String Preserves Variable Scope ==="
count=0
while IFS= read -r line; do
    ((count++))
done <<< "line1
line2
line3"
echo "Count (preserved): $count"

echo ""
echo "=== Practical: JSON Template ==="
generate_json() {
    local name="$1"
    local email="$2"
    local role="$3"
    cat << EOF
{
    "user": {
        "name": "$name",
        "email": "$email",
        "role": "$role",
        "created": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')",
        "active": true
    }
}
EOF
}

echo "Generated JSON:"
generate_json "Alice" "alice@example.com" "admin"

echo ""
echo "=== Practical: Multi-line Variable ==="
read -r -d '' script_template << 'TEMPLATE' || true
#!/bin/bash
# Auto-generated script
set -euo pipefail

echo "Running automated task..."
date
echo "Task complete."
TEMPLATE

echo "Script template:"
echo "$script_template"
