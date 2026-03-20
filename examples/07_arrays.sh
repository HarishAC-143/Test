#!/bin/bash
# Indexed arrays, associative arrays, and array operations

echo "=== Indexed Arrays ==="
fruits=("apple" "banana" "cherry" "date" "elderberry")

echo "All fruits: ${fruits[*]}"
echo "First: ${fruits[0]}"
echo "Last: ${fruits[-1]}"
echo "Count: ${#fruits[@]}"
echo "Indices: ${!fruits[@]}"

echo ""
echo "=== Iterating Arrays ==="
for fruit in "${fruits[@]}"; do
    echo "  - $fruit"
done

echo ""
echo "With indices:"
for i in "${!fruits[@]}"; do
    echo "  [$i] ${fruits[$i]}"
done

echo ""
echo "=== Modifying Arrays ==="
fruits+=("fig" "grape")
echo "After append: ${fruits[*]}"

unset 'fruits[1]'
echo "After removing index 1 (banana): ${fruits[*]}"
echo "Indices after removal: ${!fruits[@]}"

echo ""
echo "=== Array Slicing ==="
numbers=({1..10})
echo "Full array: ${numbers[*]}"
echo "Slice [3..5]: ${numbers[*]:3:3}"
echo "From index 7: ${numbers[*]:7}"

echo ""
echo "=== Associative Arrays ==="
declare -A capitals
capitals=(
    ["France"]="Paris"
    ["Japan"]="Tokyo"
    ["India"]="New Delhi"
    ["Brazil"]="Brasilia"
    ["Egypt"]="Cairo"
)

echo "Capital of Japan: ${capitals["Japan"]}"
echo ""
echo "All entries:"
for country in "${!capitals[@]}"; do
    printf "  %-10s → %s\n" "$country" "${capitals[$country]}"
done

if [[ -v capitals["France"] ]]; then
    echo ""
    echo "France exists in the map"
fi

echo ""
echo "=== Array Operations ==="
data=(5 3 8 1 9 2 7 4 6)
echo "Original: ${data[*]}"

sorted=($(printf '%s\n' "${data[@]}" | sort -n))
echo "Sorted:   ${sorted[*]}"

reversed=($(printf '%s\n' "${data[@]}" | sort -nr))
echo "Reversed: ${reversed[*]}"

echo ""
echo "=== Joining Array Elements ==="
join_by() {
    local IFS="$1"
    shift
    echo "$*"
}
echo "Comma-joined: $(join_by ',' "${fruits[@]}")"
echo "Pipe-joined:  $(join_by '|' "${sorted[@]}")"

echo ""
echo "=== Reading Lines into Array ==="
mapfile -t passwd_lines < <(head -5 /etc/passwd)
echo "First 5 lines from /etc/passwd:"
for line in "${passwd_lines[@]}"; do
    echo "  $line"
done
