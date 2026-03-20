#!/bin/bash
# Command-Line Arguments — positional parameters, shift, getopts

echo "=== Positional Parameters ==="
echo "Script name (\$0): $0"
echo "Argument count (\$#): $#"
echo "Arg 1: ${1:-<none>}"
echo "Arg 2: ${2:-<none>}"
echo "Arg 3: ${3:-<none>}"
echo "All args (\$@): $@"

echo ""
echo "=== Iterating Arguments ==="
if [[ $# -gt 0 ]]; then
    echo "Iterating with for loop:"
    for arg in "$@"; do
        echo "  '$arg'"
    done
fi

echo ""
echo "=== shift Demo ==="
if [[ $# -ge 3 ]]; then
    echo "Before shift: \$1='$1' \$2='$2' \$3='$3'"
    shift
    echo "After shift 1: \$1='$1' \$2='$2' \$3='${3:-<none>}'"
fi

echo ""
echo "=== getopts Example ==="
usage() {
    cat << EOF
Usage: $(basename "$0") [-v] [-o output] [-n count] [args...]

Options:
    -v          Verbose mode
    -o FILE     Output file
    -n NUM      Number of iterations
    -h          Show help
EOF
}

verbose=false
output=""
count=1

OPTIND=1
while getopts "vo:n:h" opt; do
    case "$opt" in
        v) verbose=true ;;
        o) output="$OPTARG" ;;
        n) count="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

echo "Parsed options:"
echo "  verbose = $verbose"
echo "  output  = ${output:-<default>}"
echo "  count   = $count"
echo "  remaining args: ${*:-<none>}"

echo ""
echo "=== Practical: Simple Calculator ==="
calc_usage() {
    echo "Calculator: $(basename "$0") -a NUM1 -b NUM2 -op [add|sub|mul|div]"
}

num_a=""
num_b=""
operation=""

OPTIND=1
while getopts "a:b:o:" opt; do
    case "$opt" in
        a) num_a="$OPTARG" ;;
        b) num_b="$OPTARG" ;;
        o) operation="$OPTARG" ;;
    esac
done

if [[ -n "$num_a" && -n "$num_b" && -n "$operation" ]]; then
    case "$operation" in
        add) echo "  $num_a + $num_b = $((num_a + num_b))" ;;
        sub) echo "  $num_a - $num_b = $((num_a - num_b))" ;;
        mul) echo "  $num_a * $num_b = $((num_a * num_b))" ;;
        div)
            if [[ "$num_b" -eq 0 ]]; then
                echo "  Error: division by zero"
            else
                echo "  $num_a / $num_b = $((num_a / num_b))"
            fi
            ;;
        *) echo "  Unknown operation: $operation" ;;
    esac
else
    echo "  (Calculator example: pass -a NUM -b NUM -o add|sub|mul|div)"
fi
