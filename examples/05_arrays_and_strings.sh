#!/bin/bash
# 05_arrays_and_strings.sh -- Arrays (indexed & associative) and string operations
#
# Demonstrates: array CRUD, slicing, iteration, associative arrays,
#               string manipulation, pattern matching
#
# Usage: ./05_arrays_and_strings.sh

set -euo pipefail

echo "========================================="
echo "  Arrays and Strings Examples"
echo "========================================="

# --- INDEXED ARRAYS ---
echo ""
echo "--- Indexed Arrays ---"

fruits=("apple" "banana" "cherry" "date" "elderberry")

echo "All fruits:     ${fruits[*]}"
echo "First:          ${fruits[0]}"
echo "Third:          ${fruits[2]}"
echo "Last:           ${fruits[-1]}"
echo "Count:          ${#fruits[@]}"
echo "Slice [1:3]:    ${fruits[@]:1:3}"
echo "Indices:        ${!fruits[@]}"

echo ""
echo "Adding and removing elements:"
fruits+=("fig" "grape")
echo "  After append:  ${fruits[*]}"

unset 'fruits[1]'
echo "  After unset[1]: ${fruits[*]}"
echo "  Indices now:    ${!fruits[*]}"

# Rebuild without gaps
fruits=("${fruits[@]}")
echo "  After rebuild:  ${fruits[*]}"
echo "  Indices now:    ${!fruits[*]}"

echo ""
echo "--- Array Iteration ---"
echo "By value:"
for fruit in "${fruits[@]}"; do
    echo "  - $fruit"
done

echo "By index:"
for i in "${!fruits[@]}"; do
    echo "  [$i] = ${fruits[$i]}"
done

# --- ARRAY OPERATIONS ---
echo ""
echo "--- Array Operations ---"

numbers=(34 12 67 5 89 23 45 1 78 56)
echo "Original: ${numbers[*]}"

sorted=($(printf '%s\n' "${numbers[@]}" | sort -n))
echo "Sorted:   ${sorted[*]}"

reversed=($(printf '%s\n' "${numbers[@]}" | sort -rn))
echo "Reversed: ${reversed[*]}"

unique_input=(1 2 3 2 4 3 5 1 6)
unique=($(printf '%s\n' "${unique_input[@]}" | sort -nu))
echo "Unique of (${unique_input[*]}): ${unique[*]}"

# Array search
search_array() {
    local needle="$1"
    shift
    local -a haystack=("$@")
    for i in "${!haystack[@]}"; do
        if [[ "${haystack[$i]}" == "$needle" ]]; then
            echo "$i"
            return 0
        fi
    done
    echo "-1"
    return 1
}

idx=$(search_array "cherry" "${fruits[@]}" || true)
echo "Index of 'cherry': $idx"

# Array join
join_array() {
    local delimiter="$1"
    shift
    local result="$1"
    shift
    for item in "$@"; do
        result+="${delimiter}${item}"
    done
    echo "$result"
}

echo "Joined: $(join_array ", " "${fruits[@]}")"

# --- ASSOCIATIVE ARRAYS ---
echo ""
echo "--- Associative Arrays ---"

declare -A person=(
    [name]="Alice Johnson"
    [age]="30"
    [role]="Software Engineer"
    [city]="San Francisco"
    [language]="BASH"
)

echo "Name:     ${person[name]}"
echo "Role:     ${person[role]}"
echo "Keys:     ${!person[*]}"
echo "Values:   ${person[*]}"
echo "Size:     ${#person[@]}"

echo ""
echo "Iterating key-value pairs:"
for key in "${!person[@]}"; do
    printf "  %-10s = %s\n" "$key" "${person[$key]}"
done

# Check if key exists
if [[ -v person[email] ]]; then
    echo "Email: ${person[email]}"
else
    echo "(No email set)"
fi

# --- WORD FREQUENCY COUNTER ---
echo ""
echo "--- Word Frequency Counter ---"

text="the quick brown fox jumps over the lazy dog the fox the dog"
declare -A freq=()

for word in $text; do
    freq[$word]=$(( ${freq[$word]:-0} + 1 ))
done

for word in $(echo "${!freq[@]}" | tr ' ' '\n' | sort); do
    printf "  %-10s : %d\n" "$word" "${freq[$word]}"
done

# --- STRING OPERATIONS ---
echo ""
echo "--- String Operations ---"

str="Hello, Wonderful World of BASH Programming!"
echo "String:    '$str'"
echo "Length:    ${#str}"
echo ""

echo "Substring [0:5]:  '${str:0:5}'"
echo "Substring [7:]:   '${str:7}'"
echo "Substring [-12:]: '${str: -12}'"

echo ""
echo "Replace first 'o':  '${str/o/0}'"
echo "Replace all 'o':    '${str//o/0}'"
echo "Remove 'World':     '${str/World/}'"

echo ""
echo "Uppercase:   '${str^^}'"
echo "Lowercase:   '${str,,}'"
echo "First upper: '${str^}'"

# --- PATH MANIPULATION ---
echo ""
echo "--- Path Manipulation ---"

path="/home/user/projects/my_app/src/main.py"
echo "Full path:   $path"
echo "Directory:   ${path%/*}"
echo "Filename:    ${path##*/}"
echo "Extension:   ${path##*.}"
echo "Without ext: ${path%.*}"
echo "Base name:   $(basename "$path" .py)"

# --- PATTERN MATCHING IN [[ ]] ---
echo ""
echo "--- Pattern Matching ---"

test_strings=("hello.txt" "data.csv" "image.png" "script.sh" "readme.md" "archive.tar.gz")

for s in "${test_strings[@]}"; do
    case_result=""
    [[ $s == *.txt ]]    && case_result="Text file"
    [[ $s == *.csv ]]    && case_result="CSV file"
    [[ $s == *.png ]]    && case_result="Image"
    [[ $s == *.sh ]]     && case_result="Shell script"
    [[ $s == *.md ]]     && case_result="Markdown"
    [[ $s == *.tar.* ]]  && case_result="Tarball"
    printf "  %-20s -> %s\n" "$s" "${case_result:-Unknown}"
done

# --- REGEX MATCHING ---
echo ""
echo "--- Regex Matching ---"

emails=("alice@example.com" "not-an-email" "bob@test.org" "@invalid" "user@domain.co.uk")
email_regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

for email in "${emails[@]}"; do
    if [[ $email =~ $email_regex ]]; then
        printf "  %-25s -> VALID\n" "$email"
    else
        printf "  %-25s -> INVALID\n" "$email"
    fi
done

echo ""
echo "All array and string examples complete!"
