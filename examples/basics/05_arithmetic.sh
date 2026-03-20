#!/bin/bash
# Arithmetic Operations — integer math, floating-point, bitwise

a=15
b=4

echo "=== Basic Arithmetic with \$(( )) ==="
echo "a=$a, b=$b"
echo "Addition:       $((a + b))"
echo "Subtraction:    $((a - b))"
echo "Multiplication: $((a * b))"
echo "Division:       $((a / b)) (integer)"
echo "Modulus:        $((a % b))"
echo "Exponentiation: $((a ** 2))"

echo ""
echo "=== Increment / Decrement ==="
count=0
echo "Initial:     $count"
((count++))
echo "After count++: $count"
((count += 10))
echo "After += 10:   $count"
((count--))
echo "After count--: $count"
((count -= 5))
echo "After -= 5:    $count"

echo ""
echo "=== let Command ==="
let "result = a * b + 2"
echo "let result (a * b + 2): $result"

echo ""
echo "=== expr (Legacy) ==="
result=$(expr $a + $b)
echo "expr result (a + b): $result"

echo ""
echo "=== Floating-Point with bc ==="
if command -v bc &>/dev/null; then
    echo "Division:    $(echo "scale=4; $a / $b" | bc)"
    echo "Square root: $(echo "scale=4; sqrt($a)" | bc)"
    echo "Sine(1):     $(echo "scale=6; s(1)" | bc -l)"
    echo "Pi:          $(echo "scale=10; 4*a(1)" | bc -l)"
else
    echo "(bc not installed — skipping)"
fi

echo ""
echo "=== Floating-Point with awk ==="
echo "Division:    $(awk "BEGIN {printf \"%.4f\", $a / $b}")"
echo "Square root: $(awk "BEGIN {printf \"%.4f\", sqrt($a)}")"

echo ""
echo "=== Bitwise Operations ==="
echo "AND  (a & b):  $((a & b))"
echo "OR   (a | b):  $((a | b))"
echo "XOR  (a ^ b):  $((a ^ b))"
echo "NOT  (~a):     $((~a))"
echo "Left shift  (a << 2): $((a << 2))"
echo "Right shift (a >> 2): $((a >> 2))"

echo ""
echo "=== Ternary Operator ==="
max=$(( a > b ? a : b ))
echo "Max of $a and $b: $max"

min=$(( a < b ? a : b ))
echo "Min of $a and $b: $min"

echo ""
echo "=== Practical: Conversions ==="
bytes=1048576
kb=$((bytes / 1024))
mb=$((bytes / 1024 / 1024))
echo "$bytes bytes = $kb KB = $mb MB"

celsius=37
fahrenheit=$(( celsius * 9 / 5 + 32 ))
echo "${celsius}°C = ${fahrenheit}°F"
