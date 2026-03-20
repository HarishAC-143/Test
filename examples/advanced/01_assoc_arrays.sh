#!/bin/bash
# Associative Arrays — declaration, access, iteration, practical examples

echo "=== Declare and Populate ==="
declare -A user_info
user_info[name]="Alice"
user_info[email]="alice@example.com"
user_info[role]="admin"
user_info[active]="true"

echo "Name:  ${user_info[name]}"
echo "Email: ${user_info[email]}"
echo "Role:  ${user_info[role]}"

echo ""
echo "=== Keys and Values ==="
echo "Keys:   ${!user_info[@]}"
echo "Values: ${user_info[@]}"
echo "Count:  ${#user_info[@]}"

echo ""
echo "=== Iteration ==="
for key in "${!user_info[@]}"; do
    printf "  %-10s => %s\n" "$key" "${user_info[$key]}"
done

echo ""
echo "=== Key Existence Check ==="
if [[ -v user_info[email] ]]; then
    echo "'email' key exists"
fi
if [[ ! -v user_info[phone] ]]; then
    echo "'phone' key does not exist"
fi

echo ""
echo "=== Delete a Key ==="
unset 'user_info[active]'
echo "After deleting 'active': ${!user_info[@]}"

echo ""
echo "=== Inline Initialization ==="
declare -A http_codes=(
    [200]="OK"
    [301]="Moved Permanently"
    [302]="Found"
    [400]="Bad Request"
    [401]="Unauthorized"
    [403]="Forbidden"
    [404]="Not Found"
    [500]="Internal Server Error"
    [502]="Bad Gateway"
    [503]="Service Unavailable"
)

for code in 200 301 404 500 999; do
    if [[ -v http_codes[$code] ]]; then
        echo "  HTTP $code: ${http_codes[$code]}"
    else
        echo "  HTTP $code: Unknown"
    fi
done

echo ""
echo "=== Practical: Word Frequency Counter ==="
declare -A word_count
text="the cat sat on the mat and the cat chased the mouse around the mat"
for word in $text; do
    ((word_count[$word]++))
done

echo "Word frequencies (sorted by count):"
for word in "${!word_count[@]}"; do
    printf "%d %s\n" "${word_count[$word]}" "$word"
done | sort -rn | while read -r count word; do
    printf "  %-10s %d\n" "$word" "$count"
done

echo ""
echo "=== Practical: Config File Parser ==="
declare -A config

parse_config() {
    local file="$1"
    while IFS='=' read -r key value; do
        key="${key// /}"
        value="${value// /}"
        [[ -z "$key" || "$key" == \#* ]] && continue
        config[$key]="$value"
    done < "$file"
}

# Create a sample config
cat > /tmp/sample_config_$$.ini << 'EOF'
# Database settings
db_host=localhost
db_port=5432
db_name=myapp
db_user=admin

# App settings
debug=true
log_level=info
max_connections=100
EOF

parse_config "/tmp/sample_config_$$.ini"

echo "Parsed config:"
for key in $(echo "${!config[@]}" | tr ' ' '\n' | sort); do
    printf "  %-20s = %s\n" "$key" "${config[$key]}"
done

rm -f "/tmp/sample_config_$$.ini"

echo ""
echo "=== Practical: Inventory Tracker ==="
declare -A inventory=(
    [apples]=50
    [bananas]=30
    [oranges]=45
    [grapes]=20
)

sell() {
    local item="$1" qty="$2"
    if [[ ! -v inventory[$item] ]]; then
        echo "  Unknown item: $item"
        return 1
    fi
    if (( inventory[$item] < qty )); then
        echo "  Not enough $item (have: ${inventory[$item]}, need: $qty)"
        return 1
    fi
    ((inventory[$item] -= qty))
    echo "  Sold $qty $item (remaining: ${inventory[$item]})"
}

restock() {
    local item="$1" qty="$2"
    ((inventory[$item] += qty))
    echo "  Restocked $qty $item (total: ${inventory[$item]})"
}

echo "Initial inventory:"
for item in "${!inventory[@]}"; do
    echo "  $item: ${inventory[$item]}"
done

echo ""
sell apples 10
sell bananas 5
restock grapes 30
sell mangoes 5

echo ""
echo "Final inventory:"
for item in "${!inventory[@]}"; do
    echo "  $item: ${inventory[$item]}"
done
