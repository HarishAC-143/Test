#!/bin/bash
# 01_hello_world.sh -- Your very first BASH script
#
# Demonstrates: echo, variables, command substitution, special variables
#
# Usage: ./01_hello_world.sh [your_name]

echo "============================================"
echo "  Welcome to BASH Programming!"
echo "============================================"
echo ""

name="${1:-World}"

echo "Hello, $name!"
echo ""
echo "--- Script Information ---"
echo "Script name:       $0"
echo "Arguments passed:  $#"
echo "All arguments:     $@"
echo "Process ID:        $$"
echo ""
echo "--- System Information ---"
echo "Current user:      $USER"
echo "Home directory:    $HOME"
echo "Current directory: $(pwd)"
echo "Shell:             $SHELL"
echo "BASH version:      $BASH_VERSION"
echo "Date and time:     $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "--- Fun with Arithmetic ---"
a=42
b=13
echo "$a + $b = $((a + b))"
echo "$a - $b = $((a - b))"
echo "$a * $b = $((a * b))"
echo "$a / $b = $((a / b)) (integer division)"
echo "$a % $b = $((a % b)) (remainder)"
echo ""
echo "Done! Try running: $0 YourName"
