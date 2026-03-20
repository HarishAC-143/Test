#!/bin/bash
# Arithmetic operators, comparisons, and file tests

echo "=== Arithmetic Operators ==="
a=25
b=7

echo "a = $a, b = $b"
echo "Addition:       $(( a + b ))"
echo "Subtraction:    $(( a - b ))"
echo "Multiplication: $(( a * b ))"
echo "Division:       $(( a / b ))"
echo "Modulus:        $(( a % b ))"
echo "Exponentiation: $(( a ** 2 ))"

echo ""
echo "=== Increment / Decrement ==="
x=10
echo "x = $x"
(( x++ ))
echo "After x++: $x"
(( x-- ))
echo "After x--: $x"
(( x += 5 ))
echo "After x+=5: $x"

echo ""
echo "=== Floating-Point with bc ==="
pi=$(echo "scale=6; 22/7" | bc)
echo "Pi ≈ $pi"
area=$(echo "scale=4; 3.14159 * 5 * 5" | bc)
echo "Area of circle (r=5): $area"

echo ""
echo "=== Integer Comparisons ==="
if [[ $a -gt $b ]]; then echo "$a > $b : true"; fi
if [[ $a -ge $b ]]; then echo "$a >= $b : true"; fi
if [[ $b -lt $a ]]; then echo "$b < $a : true"; fi
if [[ $a -ne $b ]]; then echo "$a != $b : true"; fi

echo ""
echo "=== String Comparisons ==="
str1="hello"
str2="world"
if [[ "$str1" != "$str2" ]]; then echo "'$str1' != '$str2' : true"; fi
if [[ -n "$str1" ]]; then echo "'$str1' is non-empty"; fi
if [[ "$str1" == h* ]]; then echo "'$str1' starts with 'h'"; fi

echo ""
echo "=== File Test Operators ==="
test_file="/etc/passwd"
echo "Testing: $test_file"
[[ -e "$test_file" ]] && echo "  Exists: yes"
[[ -f "$test_file" ]] && echo "  Regular file: yes"
[[ -r "$test_file" ]] && echo "  Readable: yes"
[[ -s "$test_file" ]] && echo "  Non-empty: yes"
