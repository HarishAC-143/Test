#!/bin/bash
# Variables — declaration, usage, scope, and special variables

# Simple assignment (no spaces around '=')
name="Alice"
age=30
distro="Ubuntu"

echo "=== Basic Variables ==="
echo "Name: $name"
echo "Age: $age"
echo "Distro: ${distro}"

# Read-only variable
readonly PI=3.14159
echo "Pi: $PI"
# PI=3.0  # Uncommenting this line would cause an error

# Environment variables
export APP_ENV="production"
echo "APP_ENV: $APP_ENV"

# Unsetting a variable
temp="delete me"
echo "Before unset: temp='$temp'"
unset temp
echo "After unset:  temp='$temp'"

# Variable with command output
current_date=$(date +%Y-%m-%d)
file_count=$(ls /etc/ | wc -l)
echo "Date: $current_date"
echo "Files in /etc: $file_count"

echo ""
echo "=== Special Variables ==="
echo "Script name (\$0):   $0"
echo "Argument count (\$#): $#"
echo "All args (\$@):       $@"
echo "Process ID (\$\$):    $$"
echo "Last exit code (\$?): $?"

echo ""
echo "=== Variable Tricks ==="
# String length
greeting="Hello, World!"
echo "Length of '$greeting': ${#greeting}"

# Default values
echo "Unset var with default: ${undefined_var:-fallback_value}"

# Concatenation
first="Hello"
second="World"
combined="${first}, ${second}!"
echo "Combined: $combined"
