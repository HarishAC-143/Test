#!/bin/bash
# Loops — for, while, until, break, continue

echo "=== for loop: list ==="
for color in red green blue yellow purple; do
    echo "  Color: $color"
done

echo ""
echo "=== for loop: C-style ==="
for ((i = 1; i <= 5; i++)); do
    echo "  Iteration: $i"
done

echo ""
echo "=== for loop: range ==="
echo -n "  "
for i in {1..10}; do
    echo -n "$i "
done
echo

echo ""
echo "=== for loop: range with step ==="
echo -n "  "
for i in {0..100..10}; do
    echo -n "$i "
done
echo

echo ""
echo "=== for loop: files ==="
for file in /etc/*.conf; do
    [[ -f "$file" ]] || continue
    echo "  Config: $(basename "$file")"
done | head -5

echo ""
echo "=== for loop: command output ==="
echo "  First 5 users in /etc/passwd:"
for user in $(cut -d: -f1 /etc/passwd | head -5); do
    echo "    - $user"
done

echo ""
echo "=== while loop: counter ==="
count=1
while [[ $count -le 5 ]]; do
    echo "  Count: $count"
    ((count++))
done

echo ""
echo "=== while loop: read file line by line ==="
echo "  First 3 lines of /etc/passwd:"
head -3 /etc/passwd | while IFS= read -r line; do
    echo "    $line"
done

echo ""
echo "=== until loop ==="
num=1
until [[ $num -gt 5 ]]; do
    echo "  Number: $num"
    ((num++))
done

echo ""
echo "=== continue (skip even numbers) ==="
echo -n "  Odd numbers: "
for i in {1..10}; do
    if (( i % 2 == 0 )); then
        continue
    fi
    echo -n "$i "
done
echo

echo ""
echo "=== break (stop at 5) ==="
echo -n "  Values: "
for i in {1..100}; do
    if (( i > 5 )); then
        break
    fi
    echo -n "$i "
done
echo

echo ""
echo "=== Nested loops with labeled break ==="
for i in {1..3}; do
    for j in {1..3}; do
        if (( i == 2 && j == 2 )); then
            echo "  Breaking at i=$i, j=$j"
            break 2
        fi
        echo "  i=$i, j=$j"
    done
done

echo ""
echo "=== Practical: multiplication table ==="
for ((i = 1; i <= 5; i++)); do
    for ((j = 1; j <= 5; j++)); do
        printf "%4d" $((i * j))
    done
    echo
done
