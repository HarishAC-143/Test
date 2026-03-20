#!/bin/bash
# 03_control_flow.sh -- Conditionals, loops, and case statements
#
# Demonstrates: if/elif/else, test operators, for/while/until, case, break/continue
#
# Usage: ./03_control_flow.sh

set -euo pipefail

echo "========================================="
echo "  Control Flow Examples"
echo "========================================="

# --- IF / ELIF / ELSE ---
echo ""
echo "--- Grade Calculator ---"
score=78

if (( score >= 90 )); then
    grade="A"
elif (( score >= 80 )); then
    grade="B"
elif (( score >= 70 )); then
    grade="C"
elif (( score >= 60 )); then
    grade="D"
else
    grade="F"
fi
echo "Score: $score => Grade: $grade"

# --- STRING COMPARISON ---
echo ""
echo "--- String Comparison ---"
str1="hello"
str2="world"

if [[ "$str1" == "$str2" ]]; then
    echo "'$str1' equals '$str2'"
elif [[ "$str1" < "$str2" ]]; then
    echo "'$str1' sorts before '$str2'"
else
    echo "'$str1' sorts after '$str2'"
fi

# --- FILE TESTS ---
echo ""
echo "--- File Tests ---"
test_file="/etc/passwd"

if [[ -f "$test_file" ]]; then
    echo "$test_file exists and is a regular file"
fi

if [[ -r "$test_file" ]]; then
    echo "$test_file is readable"
fi

if [[ -s "$test_file" ]]; then
    echo "$test_file is non-empty ($(wc -c < "$test_file") bytes)"
fi

# --- LOGICAL OPERATORS ---
echo ""
echo "--- Logical Operators ---"
age=25
name="Alice"

if [[ $age -ge 18 && $name == "Alice" ]]; then
    echo "$name is $age and is an adult"
fi

if [[ $age -lt 10 || $age -gt 20 ]]; then
    echo "Age $age is outside 10-20 range"
fi

if [[ ! -d "/nonexistent_dir" ]]; then
    echo "/nonexistent_dir does not exist (negation test)"
fi

# --- FOR LOOPS ---
echo ""
echo "--- For Loop: Counting ---"
for i in {1..5}; do
    echo "  Count: $i"
done

echo ""
echo "--- For Loop: C-style ---"
for (( i = 0; i < 5; i++ )); do
    printf "  i=%d " "$i"
done
echo ""

echo ""
echo "--- For Loop: Iterating Over Words ---"
for day in Monday Wednesday Friday Sunday; do
    echo "  Day: $day"
done

echo ""
echo "--- For Loop: Array Iteration ---"
languages=("BASH" "Python" "Go" "Rust" "C")
for lang in "${languages[@]}"; do
    echo "  Language: $lang"
done

# --- WHILE LOOP ---
echo ""
echo "--- While Loop: Countdown ---"
count=5
while (( count > 0 )); do
    printf "  %d... " "$count"
    ((count--))
done
echo "Liftoff!"

# --- UNTIL LOOP ---
echo ""
echo "--- Until Loop: Count Up ---"
n=1
until (( n > 5 )); do
    printf "  %d " "$n"
    ((n++))
done
echo ""

# --- BREAK AND CONTINUE ---
echo ""
echo "--- Break Example (stop at 7) ---"
for i in {1..10}; do
    if (( i == 7 )); then
        echo "  Breaking at $i!"
        break
    fi
    printf "  %d" "$i"
done
echo ""

echo ""
echo "--- Continue Example (skip even numbers) ---"
for i in {1..10}; do
    if (( i % 2 == 0 )); then
        continue
    fi
    printf "  %d" "$i"
done
echo ""

# --- CASE STATEMENT ---
echo ""
echo "--- Case Statement ---"
extension="tar.gz"

case "$extension" in
    tar.gz|tgz)    echo "  '$extension' -> Gzipped tarball" ;;
    tar.bz2|tbz2)  echo "  '$extension' -> Bzipped tarball" ;;
    zip)           echo "  '$extension' -> ZIP archive" ;;
    rar)           echo "  '$extension' -> RAR archive" ;;
    *)             echo "  '$extension' -> Unknown format" ;;
esac

echo ""
echo "--- Case with Patterns ---"
for file in "photo.jpg" "data.csv" "script.sh" "readme.md" "archive.zip"; do
    case "$file" in
        *.jpg|*.png|*.gif) type="Image" ;;
        *.csv|*.tsv)       type="Data" ;;
        *.sh|*.bash)       type="Script" ;;
        *.md|*.txt)        type="Text" ;;
        *)                 type="Other" ;;
    esac
    printf "  %-15s -> %s\n" "$file" "$type"
done

echo ""
echo "All control flow examples complete!"
