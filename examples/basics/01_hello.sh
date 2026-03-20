#!/bin/bash
# First Bash Script — Hello World with date information

echo "Hello, World!"
echo "Today is $(date +%A), $(date +%B) $(date +%d), $(date +%Y)."
echo "Current time: $(date +%H:%M:%S)"
echo "Hostname: $(hostname)"
echo "Running as user: $(whoami)"
echo "Shell: $SHELL"
echo "Bash version: ${BASH_VERSION}"
