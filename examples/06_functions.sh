#!/bin/bash
# Functions: definition, arguments, return values, scope, and recursion

echo "=== Basic Functions ==="

greet() {
    echo "Hello, ${1:-stranger}!"
}

greet "Alice"
greet "Bob"
greet

echo ""
echo "=== Function with Return Value ==="

add() {
    echo $(( $1 + $2 ))
}

result=$(add 15 27)
echo "15 + 27 = $result"

echo ""
echo "=== Function with Exit Code ==="

is_even() {
    (( $1 % 2 == 0 ))
}

for num in 1 2 3 4 5 6; do
    if is_even $num; then
        echo "  $num is even"
    else
        echo "  $num is odd"
    fi
done

echo ""
echo "=== Local vs Global Scope ==="

scope_demo() {
    local local_var="I'm local"
    global_var="I'm global"
    echo "  Inside:  local_var='$local_var', global_var='$global_var'"
}

scope_demo
echo "  Outside: local_var='$local_var', global_var='$global_var'"

echo ""
echo "=== Recursive Factorial ==="

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

for n in 1 5 8 10; do
    echo "  ${n}! = $(factorial $n)"
done

echo ""
echo "=== Recursive Fibonacci ==="

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

echo -n "  First 10 Fibonacci numbers: "
for (( i = 0; i < 10; i++ )); do
    echo -n "$(fibonacci $i) "
done
echo ""

echo ""
echo "=== Function with Array Arguments ==="

array_stats() {
    local arr=("$@")
    local sum=0 min=${arr[0]} max=${arr[0]}

    for val in "${arr[@]}"; do
        (( sum += val ))
        (( val < min )) && min=$val
        (( val > max )) && max=$val
    done

    local count=${#arr[@]}
    local avg=$(( sum / count ))

    echo "  Count: $count"
    echo "  Sum:   $sum"
    echo "  Avg:   $avg"
    echo "  Min:   $min"
    echo "  Max:   $max"
}

numbers=(12 45 7 89 23 56 34 78 90 11)
echo "Numbers: ${numbers[*]}"
array_stats "${numbers[@]}"
