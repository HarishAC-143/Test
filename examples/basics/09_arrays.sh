#!/bin/bash
# Arrays — indexed arrays, operations, iteration, searching

echo "=== Creating Arrays ==="
fruits=("apple" "banana" "cherry" "date" "elderberry")
echo "Fruits: ${fruits[@]}"

echo ""
echo "=== Accessing Elements ==="
echo "First element:  ${fruits[0]}"
echo "Third element:  ${fruits[2]}"
echo "Last element:   ${fruits[-1]}"
echo "Second-to-last: ${fruits[-2]}"

echo ""
echo "=== Array Information ==="
echo "All elements: ${fruits[@]}"
echo "Length:       ${#fruits[@]}"
echo "All indices:  ${!fruits[@]}"
echo "Length of 'banana': ${#fruits[1]}"

echo ""
echo "=== Modifying Arrays ==="
fruits+=("fig" "grape")
echo "After append: ${fruits[@]}"

fruits[1]="blueberry"
echo "After modify [1]: ${fruits[@]}"

unset 'fruits[3]'
echo "After unset [3]:  ${fruits[@]}"
echo "Indices now:      ${!fruits[@]}"

echo ""
echo "=== Array Slicing ==="
numbers=(0 1 2 3 4 5 6 7 8 9)
echo "Full array:     ${numbers[@]}"
echo "Slice [2..5]:   ${numbers[@]:2:4}"
echo "From index 7:   ${numbers[@]:7}"

echo ""
echo "=== Iterating Arrays ==="
echo "--- By value ---"
for fruit in "${fruits[@]}"; do
    echo "  $fruit"
done

echo "--- By index ---"
for i in "${!fruits[@]}"; do
    echo "  [$i] = ${fruits[$i]}"
done

echo ""
echo "=== Array from Command Output ==="
mapfile -t passwd_users < <(cut -d: -f1 /etc/passwd | head -5)
echo "First 5 users: ${passwd_users[@]}"

echo ""
echo "=== Array from String Split ==="
IFS=',' read -ra csv <<< "one,two,three,four,five"
echo "CSV items: ${csv[@]}"
echo "Item count: ${#csv[@]}"

IFS=':' read -ra path_parts <<< "$PATH"
echo "PATH has ${#path_parts[@]} entries"

echo ""
echo "=== Searching Arrays ==="
contains() {
    local target="$1"
    shift
    for item in "$@"; do
        [[ "$item" == "$target" ]] && return 0
    done
    return 1
}

colors=("red" "green" "blue" "yellow")
for search in "blue" "purple"; do
    if contains "$search" "${colors[@]}"; then
        echo "  '$search' found in colors"
    else
        echo "  '$search' NOT found in colors"
    fi
done

echo ""
echo "=== Array Operations ==="
# Copy
original=(1 2 3 4 5)
copy=("${original[@]}")
echo "Original: ${original[@]}"
echo "Copy:     ${copy[@]}"

# Reverse
arr=(a b c d e)
reversed=()
for (( i=${#arr[@]}-1; i>=0; i-- )); do
    reversed+=("${arr[$i]}")
done
echo "Original: ${arr[@]}"
echo "Reversed: ${reversed[@]}"

# Sort (using readarray and sort)
unsorted=("banana" "apple" "date" "cherry")
readarray -t sorted < <(printf '%s\n' "${unsorted[@]}" | sort)
echo "Unsorted: ${unsorted[@]}"
echo "Sorted:   ${sorted[@]}"

# Unique elements
with_dupes=(1 2 3 2 1 4 5 4 3)
readarray -t unique < <(printf '%s\n' "${with_dupes[@]}" | sort -u)
echo "With dupes: ${with_dupes[@]}"
echo "Unique:     ${unique[@]}"

echo ""
echo "=== Practical: Stack Implementation ==="
declare -a stack
push()  { stack+=("$1"); echo "  Pushed: $1"; }
pop()   {
    if (( ${#stack[@]} == 0 )); then
        echo "  Stack is empty!"
        return 1
    fi
    local top="${stack[-1]}"
    unset 'stack[-1]'
    echo "  Popped: $top"
}
peek()  { echo "  Top: ${stack[-1]:-empty}"; }

push "first"
push "second"
push "third"
peek
pop
pop
peek
pop
pop || true
