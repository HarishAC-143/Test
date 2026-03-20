#!/bin/bash
# Functions — definition, arguments, return values, scope, recursion

echo "=== Basic Function ==="
greet() {
    echo "Hello, $1! Welcome to $2."
}
greet "Alice" "Bash scripting"
greet "Bob" "the tutorial"

echo ""
echo "=== Return Value (exit code) ==="
is_even() {
    if (( $1 % 2 == 0 )); then
        return 0
    else
        return 1
    fi
}

for n in 1 2 3 4 5; do
    if is_even $n; then
        echo "  $n is even"
    else
        echo "  $n is odd"
    fi
done

echo ""
echo "=== Return Data via stdout ==="
add() {
    echo $(( $1 + $2 ))
}
multiply() {
    echo $(( $1 * $2 ))
}
sum=$(add 17 25)
product=$(multiply 6 7)
echo "  17 + 25 = $sum"
echo "  6 * 7 = $product"

echo ""
echo "=== Local Variables ==="
outer_var="I'm global"
demo_scope() {
    local inner_var="I'm local"
    echo "  Inside:  outer_var='$outer_var', inner_var='$inner_var'"
}
demo_scope
echo "  Outside: outer_var='$outer_var', inner_var='$inner_var'"

echo ""
echo "=== Default Parameters ==="
create_user() {
    local name="${1:?Error: name is required}"
    local role="${2:-viewer}"
    local active="${3:-true}"
    echo "  User: name=$name, role=$role, active=$active"
}
create_user "alice"
create_user "bob" "admin"
create_user "carol" "editor" "false"

echo ""
echo "=== Recursive Function: Factorial ==="
factorial() {
    if (( $1 <= 1 )); then
        echo 1
    else
        local prev
        prev=$(factorial $(( $1 - 1 )))
        echo $(( $1 * prev ))
    fi
}
for n in 1 5 10; do
    echo "  ${n}! = $(factorial $n)"
done

echo ""
echo "=== Recursive Function: Fibonacci ==="
fibonacci() {
    if (( $1 <= 0 )); then
        echo 0
    elif (( $1 == 1 )); then
        echo 1
    else
        local a b
        a=$(fibonacci $(( $1 - 1 )))
        b=$(fibonacci $(( $1 - 2 )))
        echo $(( a + b ))
    fi
}
echo -n "  Fibonacci sequence: "
for n in {0..10}; do
    echo -n "$(fibonacci $n) "
done
echo

echo ""
echo "=== Passing Arrays to Functions (nameref) ==="
print_array() {
    local -n arr=$1
    local label="$2"
    echo "  $label: ${arr[*]}"
}
fruits=("apple" "banana" "cherry")
numbers=(1 2 3 4 5)
print_array fruits "Fruits"
print_array numbers "Numbers"

echo ""
echo "=== Function Returning Multiple Values ==="
get_min_max() {
    local -n result_arr=$1
    shift
    local min=$1 max=$1
    for val in "$@"; do
        (( val < min )) && min=$val
        (( val > max )) && max=$val
    done
    result_arr=("$min" "$max")
}
declare -a minmax
get_min_max minmax 42 17 93 8 56
echo "  Min: ${minmax[0]}, Max: ${minmax[1]}"
