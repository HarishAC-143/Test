#!/bin/bash
# All loop types: for, while, until, select, and loop control

echo "=== C-style for loop ==="
for (( i = 1; i <= 5; i++ )); do
    echo "  Iteration $i"
done

echo ""
echo "=== for loop with a list ==="
for color in red green blue yellow purple; do
    echo "  Color: $color"
done

echo ""
echo "=== for loop with a range ==="
echo -n "  "
for i in {1..10}; do
    echo -n "$i "
done
echo ""

echo ""
echo "=== Range with step ==="
echo -n "  Evens: "
for i in {2..20..2}; do
    echo -n "$i "
done
echo ""

echo ""
echo "=== for loop over files ==="
for file in /etc/host*; do
    [[ -e "$file" ]] && echo "  Found: $file"
done

echo ""
echo "=== while loop ==="
count=1
while (( count <= 5 )); do
    echo "  Count: $count"
    (( count++ ))
done

echo ""
echo "=== until loop ==="
n=5
until (( n == 0 )); do
    echo "  Countdown: $n"
    (( n-- ))
done
echo "  Launch!"

echo ""
echo "=== Loop control: continue (skip multiples of 3) ==="
echo -n "  "
for i in {1..15}; do
    (( i % 3 == 0 )) && continue
    echo -n "$i "
done
echo ""

echo ""
echo "=== Loop control: break (stop at 7) ==="
echo -n "  "
for i in {1..15}; do
    (( i == 8 )) && break
    echo -n "$i "
done
echo ""

echo ""
echo "=== Multiplication Table (nested loops) ==="
for (( i = 1; i <= 5; i++ )); do
    for (( j = 1; j <= 10; j++ )); do
        printf "%4d" $(( i * j ))
    done
    echo ""
done
