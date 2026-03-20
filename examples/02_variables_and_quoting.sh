#!/bin/bash
# Variables, quoting rules, and parameter expansion

name="Alice"
age=30
city="New York"

echo "=== Basic Variables ==="
echo "Name: $name, Age: $age, City: $city"

echo ""
echo "=== Quoting Differences ==="
echo "Double quotes expand: Hello, $name"
echo 'Single quotes are literal: Hello, $name'

echo ""
echo "=== Command Substitution ==="
current_date=$(date +%Y-%m-%d)
file_count=$(ls -1 | wc -l)
echo "Date: $current_date"
echo "Files in current directory: $file_count"

echo ""
echo "=== Parameter Expansion ==="
unset maybe_empty
echo "Default value: ${maybe_empty:-'not set'}"
echo "String length of name: ${#name}"

greeting="Hello, Beautiful World!"
echo "Substring (0,5): ${greeting:0:5}"
echo "Uppercase: ${greeting^^}"
echo "Lowercase: ${greeting,,}"

echo ""
echo "=== Declare with Types ==="
declare -i number=42
declare -r constant="immutable"
declare -l lower_var="HELLO WORLD"
declare -u upper_var="hello world"

echo "Integer: $number"
echo "Constant: $constant"
echo "Lowercase: $lower_var"
echo "Uppercase: $upper_var"

echo ""
echo "=== Special Variables ==="
echo "Script name: $0"
echo "Number of arguments: $#"
echo "All arguments: $@"
echo "Process ID: $$"
