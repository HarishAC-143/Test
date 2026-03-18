#!/usr/bin/env tclsh
# =============================================================================
# Example 1: Hello World and Basic Syntax
# Demonstrates: puts, variables, substitution, comments, expressions
# =============================================================================

puts "=== Hello World and Basic Syntax ===\n"

# --- Simple output ---
puts "Hello, World!"
puts "Welcome to TCL programming.\n"

# --- Variables and substitution ---
set name "Alice"
set age 28
set language "TCL"

puts "My name is $name."
puts "I am $age years old."
puts "I am learning $language.\n"

# --- Expression evaluation with command substitution ---
puts "Basic arithmetic:"
puts "  10 + 5  = [expr {10 + 5}]"
puts "  10 - 5  = [expr {10 - 5}]"
puts "  10 * 5  = [expr {10 * 5}]"
puts "  10 / 3  = [expr {10 / 3}]      (integer division)"
puts "  10.0 / 3 = [expr {10.0 / 3}]  (float division)"
puts "  10 % 3  = [expr {10 % 3}]      (modulo)"
puts "  2 ** 8  = [expr {2 ** 8}]    (exponentiation)\n"

# --- Quoting differences ---
puts "Double quotes allow substitution: name = $name"
puts {Curly braces prevent substitution: name = $name}
puts ""

# --- Multi-line string ---
set message "This is a multi-line\n\
string that spans\n\
multiple lines."
puts $message
puts ""

# --- String formatting ---
puts [format "%-15s: %s" "Name" $name]
puts [format "%-15s: %d" "Age" $age]
puts [format "%-15s: %s" "Language" $language]
puts ""

# --- Current date and time ---
set now [clock seconds]
set formatted [clock format $now -format "%Y-%m-%d %H:%M:%S"]
puts "Current date/time: $formatted"
puts "Epoch seconds: $now"
