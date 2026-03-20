#!/bin/bash
# Debugging Techniques — set flags, tracing, logging, PS4

echo "=== Method 1: set -x (Trace Mode) ==="
echo "Tracing enabled:"
set -x
greeting="Hello"
echo "$greeting, World!"
result=$((6 * 7))
set +x
echo "Tracing disabled"

echo ""
echo "=== Method 2: set -e (Exit on Error) ==="
(
    set -e
    echo "  Command 1: OK"
    true
    echo "  Command 2: OK"
    true
    echo "  All commands passed with set -e"
)

echo ""
echo "=== Method 3: set -u (Undefined Variables) ==="
(
    set -u
    defined_var="hello"
    echo "  Defined variable: $defined_var"
    # echo "$undefined_var"  # would cause an error
    echo "  Undefined variables would cause error (commented out)"
    set +u
)

echo ""
echo "=== Method 4: set -o pipefail ==="
(
    set -o pipefail
    echo "hello" | grep "hello" | wc -l > /dev/null
    echo "  Successful pipeline: exit code $?"

    echo "hello" | grep "nonexistent" | wc -l > /dev/null 2>&1
    echo "  Failed pipeline: exit code $?"
    set +o pipefail
)

echo ""
echo "=== Method 5: Custom Logging ==="
LOG_LEVEL="${LOG_LEVEL:-INFO}"

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    declare -A levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4)
    local current_level="${levels[$LOG_LEVEL]:-1}"
    local msg_level="${levels[$level]:-1}"

    if (( msg_level >= current_level )); then
        local color=""
        local reset="\033[0m"
        case "$level" in
            DEBUG) color="\033[36m" ;;
            INFO)  color="\033[32m" ;;
            WARN)  color="\033[33m" ;;
            ERROR) color="\033[31m" ;;
            FATAL) color="\033[35m" ;;
        esac
        printf "${color}[%s] [%-5s] %s${reset}\n" "$timestamp" "$level" "$*" >&2
    fi
}

log INFO "Application started"
log DEBUG "Debug message (hidden at INFO level)"
log WARN "Something might be wrong"
log ERROR "Something IS wrong"

echo ""
echo "Setting LOG_LEVEL=DEBUG:"
LOG_LEVEL=DEBUG
log DEBUG "Now you can see debug messages"
log INFO "Regular info"
LOG_LEVEL=INFO

echo ""
echo "=== Method 6: Trace a Specific Function ==="
calculate() {
    local -
    set -x
    local a=$1 b=$2
    local sum=$((a + b))
    local product=$((a * b))
    echo "sum=$sum product=$product"
}
echo "Tracing only inside calculate:"
result=$(calculate 3 7)
echo "Result: $result"

echo ""
echo "=== Method 7: Enhanced PS4 ==="
export PS4='+(${BASH_SOURCE##*/}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
demo_func() {
    local x=1
    local y=2
    echo $((x + y))
}
set -x
demo_func > /dev/null
set +x
export PS4='+ '

echo ""
echo "=== Method 8: Variable Inspection ==="
inspect() {
    local var_name="$1"
    local var_value="${!var_name}"
    echo "  Variable: $var_name"
    echo "  Value:    '$var_value'"
    echo "  Length:   ${#var_value}"
    echo "  Type:     $(declare -p "$var_name" 2>/dev/null || echo 'undefined')"
}

my_string="Hello, World!"
my_array=(1 2 3 4 5)
declare -A my_map=([key1]="val1" [key2]="val2")

echo "Inspecting variables:"
inspect my_string
echo ""
echo "  Array:   $(declare -p my_array)"
echo "  Map:     $(declare -p my_map)"

echo ""
echo "=== Method 9: Execution Timer ==="
time_cmd() {
    local label="$1"
    shift
    local start=$SECONDS
    "$@"
    local elapsed=$((SECONDS - start))
    echo "  [$label] completed in ${elapsed}s"
}

time_cmd "Quick sleep" sleep 1
time_cmd "Process files" ls /etc > /dev/null

echo ""
echo "=== Debugging Summary ==="
cat << 'EOF'
  Debugging Quick Reference:
    set -x          Trace all commands
    set -e          Exit on any error
    set -u          Error on undefined variables
    set -o pipefail Detect pipe failures
    trap ... ERR    Custom error handler
    trap ... DEBUG  Run before every command
    PS4='...'       Customize trace prefix
    bash -n script  Syntax check only
    shellcheck      Static analysis tool
EOF
