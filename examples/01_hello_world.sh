#!/bin/bash
# First BASH script — Hello World with variations

echo "Hello, World!"

echo "Current date: $(date)"
echo "Current user: $USER"
echo "Home directory: $HOME"
echo "Running shell: $SHELL"

printf "\n--- Formatted output ---\n"
printf "%-15s : %s\n" "Hostname" "$(hostname)"
printf "%-15s : %s\n" "Kernel" "$(uname -r)"
printf "%-15s : %s\n" "Architecture" "$(uname -m)"
