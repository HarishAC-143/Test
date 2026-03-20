#!/bin/bash
# 04_functions.sh -- Functions, arguments, return values, scope, and recursion
#
# Demonstrates: function definitions, local variables, return codes,
#               stdout returns, pass-by-reference, recursion
#
# Usage: ./04_functions.sh

set -euo pipefail

echo "========================================="
echo "  Functions Examples"
echo "========================================="

# --- BASIC FUNCTION ---
greet() {
    echo "Hello from the greet function!"
}

echo ""
echo "--- Basic Function Call ---"
greet

# --- FUNCTION WITH ARGUMENTS ---
introduce() {
    local name="$1"
    local role="${2:-unknown}"
    echo "Hi, I'm $name and I work as a $role."
    echo "  (This function received $# argument(s))"
}

echo ""
echo "--- Function Arguments ---"
introduce "Alice" "Engineer"
introduce "Bob"

# --- RETURN STATUS ---
is_positive() {
    local num=$1
    if (( num > 0 )); then
        return 0
    else
        return 1
    fi
}

echo ""
echo "--- Return Status (exit codes) ---"
for n in 42 -5 0 100 -1; do
    if is_positive "$n"; then
        echo "  $n is positive"
    else
        echo "  $n is NOT positive"
    fi
done

# --- RETURNING VALUES VIA STDOUT ---
add() {
    echo $(( $1 + $2 ))
}

multiply() {
    echo $(( $1 * $2 ))
}

echo ""
echo "--- Returning Values via stdout ---"
sum=$(add 15 27)
echo "  15 + 27 = $sum"

product=$(multiply 6 7)
echo "  6 * 7 = $product"

nested_result=$(add "$(multiply 3 4)" "$(multiply 5 6)")
echo "  (3*4) + (5*6) = $nested_result"

# --- RETURNING MULTIPLE VALUES ---
get_date_parts() {
    date '+%Y %m %d %H %M %S'
}

echo ""
echo "--- Returning Multiple Values ---"
read -r year month day hour min sec <<< "$(get_date_parts)"
echo "  Year: $year, Month: $month, Day: $day"
echo "  Time: $hour:$min:$sec"

# --- VARIABLE SCOPE ---
outer_var="global"

scope_demo() {
    local local_var="I'm local"
    outer_var="modified by function"
    echo "  Inside function: local_var='$local_var'"
    echo "  Inside function: outer_var='$outer_var'"
}

echo ""
echo "--- Variable Scope ---"
echo "  Before function: outer_var='$outer_var'"
scope_demo
echo "  After function:  outer_var='$outer_var'"
echo "  After function:  local_var='${local_var:-<not accessible>}'"

# --- DYNAMIC SCOPING ---
caller_func() {
    local message="from caller"
    callee_func
}

callee_func() {
    echo "  Callee sees message='${message:-<undefined>}'"
}

echo ""
echo "--- Dynamic Scoping ---"
caller_func
callee_func

# --- FUNCTION AS HIGHER-ORDER (map pattern) ---
apply_to_each() {
    local func="$1"
    shift
    for item in "$@"; do
        "$func" "$item"
    done
}

double() {
    echo "  double($1) = $(( $1 * 2 ))"
}

square() {
    echo "  square($1) = $(( $1 * $1 ))"
}

echo ""
echo "--- Higher-Order Function Pattern ---"
echo "Doubling:"
apply_to_each double 1 2 3 4 5
echo "Squaring:"
apply_to_each square 1 2 3 4 5

# --- RECURSION: FACTORIAL ---
factorial() {
    local n=$1
    if (( n <= 1 )); then
        echo 1
    else
        local sub
        sub=$(factorial $(( n - 1 )))
        echo $(( n * sub ))
    fi
}

echo ""
echo "--- Recursion: Factorial ---"
for n in 1 5 8 10; do
    echo "  $n! = $(factorial $n)"
done

# --- RECURSION: FIBONACCI ---
fibonacci() {
    local n=$1
    if (( n <= 0 )); then
        echo 0
    elif (( n == 1 )); then
        echo 1
    else
        local a b
        a=$(fibonacci $(( n - 1 )))
        b=$(fibonacci $(( n - 2 )))
        echo $(( a + b ))
    fi
}

echo ""
echo "--- Recursion: Fibonacci ---"
for n in 0 1 2 5 10; do
    echo "  fib($n) = $(fibonacci $n)"
done

# --- UTILITY: REPEAT A STRING ---
repeat_str() {
    local str="$1"
    local count="$2"
    local result=""
    for (( i = 0; i < count; i++ )); do
        result+="$str"
    done
    echo "$result"
}

echo ""
echo "--- Utility: Repeat String ---"
echo "  $(repeat_str "=-" 20)"
echo "  $(repeat_str "* " 10)"

echo ""
echo "All function examples complete!"
