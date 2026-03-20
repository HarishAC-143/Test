#!/bin/bash
# 02_variables_and_input.sh -- Variables, input, quoting, and expansion
#
# Demonstrates: variable assignment, read, quoting rules, parameter expansion
#
# Usage: ./02_variables_and_input.sh

set -euo pipefail

echo "=== Variable Assignment ==="
greeting="Hello"
name="BASH Learner"
combined="$greeting, $name!"
echo "$combined"

echo ""
echo "=== Quoting Differences ==="
fruit="apple"
echo "Double quotes: I have an $fruit"       # Variable expanded
echo 'Single quotes: I have an $fruit'       # Literal string
echo "Command sub:   Today is $(date +%A)"   # Command expanded

echo ""
echo "=== Parameter Expansion ==="
filepath="/home/user/documents/report.final.tar.gz"

echo "Full path:         $filepath"
echo "Filename:          ${filepath##*/}"
echo "Directory:         ${filepath%/*}"
echo "Remove short ext:  ${filepath%.*}"
echo "Remove long ext:   ${filepath%%.*}"
echo "Remove short pfx:  ${filepath#*/}"
echo "Remove long pfx:   ${filepath##*/}"

echo ""
echo "=== String Operations ==="
text="Hello, BASH World!"
echo "Original:    '$text'"
echo "Length:      ${#text}"
echo "Substring:   ${text:7:4}"
echo "Replace:     ${text/World/Universe}"
echo "Uppercase:   ${text^^}"
echo "Lowercase:   ${text,,}"

echo ""
echo "=== Default Values ==="
echo "With default:    ${UNDEFINED_VAR:-'fallback value'}"
echo "UNDEFINED_VAR:   '${UNDEFINED_VAR:-}'"   # Still unset

UNDEFINED_VAR="${UNDEFINED_VAR:=now_assigned}"
echo "After :=         '$UNDEFINED_VAR'"        # Now it's set

echo ""
echo "=== Read-only Variables ==="
declare -r CONSTANT="I cannot be changed"
echo "Constant: $CONSTANT"
echo "(Attempting to modify a readonly variable would cause an error)"

echo ""
echo "=== Integer Variables ==="
declare -i num=10
num=num+5
echo "Integer math: 10 + 5 = $num"
num=0
echo "Reset to zero: $num"

echo ""
echo "=== Arrays Quick Preview ==="
colors=("red" "green" "blue" "yellow")
echo "All colors:   ${colors[*]}"
echo "First color:  ${colors[0]}"
echo "Last color:   ${colors[-1]}"
echo "Count:        ${#colors[@]}"

echo ""
echo "Done!"
