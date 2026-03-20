#!/bin/bash
# Advanced BASH features: subshells, process substitution, nameref, getopts

echo "=== Subshells vs Command Groups ==="

var="parent"
echo "Before subshell: var=$var"
(
    var="child"
    echo "  Inside subshell: var=$var"
)
echo "After subshell: var=$var (unchanged — subshell didn't affect parent)"

echo ""
{
    grouped_output="from group"
    echo "  Inside group"
}
echo "After group: grouped_output=$grouped_output (changed — same shell)"

echo ""
echo "=== Process Substitution ==="
echo "Comparing /usr/bin and /usr/sbin (first 5 differences):"
diff <(ls /usr/bin 2>/dev/null | head -10) <(ls /usr/sbin 2>/dev/null | head -10) | head -15 || true

echo ""
echo "=== Nameref (BASH 4.3+) ==="
set_value() {
    local -n ref=$1
    ref="$2"
}

my_var=""
set_value my_var "Hello via nameref"
echo "my_var = $my_var"

echo ""
echo "=== Indirect Variable Reference ==="
color_red="#FF0000"
color_green="#00FF00"
color_blue="#0000FF"

for name in red green blue; do
    var_name="color_$name"
    echo "  $name = ${!var_name}"
done

echo ""
echo "=== Extended Globbing ==="
DEMO_DIR=$(mktemp -d)
trap 'rm -rf "$DEMO_DIR"' EXIT

touch "$DEMO_DIR"/{file1.txt,file2.txt,file3.log,file4.sh,file5.md}

shopt -s extglob
echo "All files:"
ls "$DEMO_DIR"/

echo ""
echo "Files matching *.!(txt) (not .txt):"
ls "$DEMO_DIR"/*.!(txt) 2>/dev/null || echo "  (none matched)"

echo ""
echo "Files matching *.@(txt|md) (only .txt or .md):"
ls "$DEMO_DIR"/*.@(txt|md)

shopt -u extglob

echo ""
echo "=== Associative Array as Object ==="
declare -A person=(
    [name]="Alice Johnson"
    [age]="30"
    [email]="alice@example.com"
    [role]="Engineer"
)

echo "Person object:"
for key in "${!person[@]}"; do
    printf "  %-8s: %s\n" "$key" "${person[$key]}"
done

echo ""
echo "=== getopts Example ==="
demo_getopts() {
    local verbose=false
    local output=""
    local count=10
    local OPTIND

    while getopts ":vo:n:" opt; do
        case "$opt" in
            v) verbose=true ;;
            o) output="$OPTARG" ;;
            n) count="$OPTARG" ;;
            :) echo "  Option -$OPTARG requires an argument"; return 1 ;;
            ?) echo "  Unknown option: -$OPTARG"; return 1 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    echo "  Parsed options:"
    echo "    verbose: $verbose"
    echo "    output:  ${output:-'(stdout)'}"
    echo "    count:   $count"
    echo "    remaining args: $*"
}

echo "Calling with: -v -n 20 -o result.txt file1 file2"
demo_getopts -v -n 20 -o result.txt file1 file2

echo ""
echo "=== Here Document for Report Generation ==="
generate_report() {
    local hostname
    hostname=$(hostname)
    cat << EOF
╔══════════════════════════════════════╗
║         SYSTEM SNAPSHOT              ║
╠══════════════════════════════════════╣
  Host:    $hostname
  Date:    $(date '+%Y-%m-%d %H:%M:%S')
  Uptime:  $(uptime -p 2>/dev/null || echo "N/A")
  Kernel:  $(uname -r)
  CPUs:    $(nproc 2>/dev/null || echo "N/A")
  Memory:  $(free -h 2>/dev/null | awk '/^Mem:/{print $3 "/" $2}' || echo "N/A")
  Disk /:  $(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')
╚══════════════════════════════════════╝
EOF
}

generate_report
