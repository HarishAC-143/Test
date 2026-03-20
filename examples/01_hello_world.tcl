#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 01: Hello World
# =============================================================================

puts "Hello, World!"

puts "---"

puts stderr "This message goes to standard error"

puts -nonewline "This has no trailing newline. "
puts "But this does."

puts "---"

# Multi-line string using braces
puts {
  Welcome to the Tcl Programming Tutorial!
  Tcl stands for "Tool Command Language".
  Let's get started.
}

# Using escape sequences inside double quotes
puts "Line 1\nLine 2\nLine 3"
puts "Column A\tColumn B\tColumn C"

# Semicolons can separate commands on the same line
puts "First" ; puts "Second" ; puts "Third"
