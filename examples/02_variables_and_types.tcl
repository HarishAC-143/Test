#!/usr/bin/env tclsh
# =============================================================================
# Example 2: Variables and Data Types
# Demonstrates: set, unset, info exists, numeric types, booleans, env vars
# =============================================================================

puts "=== Variables and Data Types ===\n"

# --- String variables ---
set greeting "Hello"
set first_name "Bob"
set full_greeting "$greeting, $first_name!"
puts "String: $full_greeting"

# --- Variable name delimiting with braces ---
set fruit "apple"
puts "I like ${fruit}s"

# --- Numeric variables ---
set integer_val 42
set float_val 3.14159
set negative -17
set hex_val 0xFF
set octal_val 0o77
set binary_val 0b11001010

puts "\nNumeric values:"
puts "  Integer:  $integer_val"
puts "  Float:    $float_val"
puts "  Negative: $negative"
puts "  Hex 0xFF: [expr {$hex_val}]  (decimal)"
puts "  Oct 0o77: [expr {$octal_val}] (decimal)"
puts "  Bin 0b11001010: [expr {$binary_val}] (decimal)"

# --- Type checking / classification ---
puts "\nType checks with 'string is':"
puts "  '42' is integer?  [string is integer "42"]"
puts "  '3.14' is double? [string is double "3.14"]"
puts "  'hello' is alpha?  [string is alpha "hello"]"
puts "  'abc123' is alnum? [string is alnum "abc123"]"
puts "  '12345' is digit?  [string is digit "12345"]"

# --- Boolean values ---
puts "\nBoolean interpretation:"
foreach val {1 0 true false yes no on off} {
    if {[catch {expr {bool($val)}} result]} {
        puts "  '$val' -> error"
    } else {
        puts "  '$val' -> $result"
    }
}

# --- Variable existence ---
set x 100
puts "\nVariable existence:"
puts "  x exists? [info exists x]"
puts "  y exists? [info exists y]"

# --- Unsetting variables ---
unset x
puts "  x exists after unset? [info exists x]"

# --- Environment variables ---
puts "\nEnvironment:"
puts "  HOME = $::env(HOME)"
if {[info exists ::env(USER)]} {
    puts "  USER = $::env(USER)"
}

# --- Using 'set' to read a variable ---
set demo_var "read me"
puts "\nUsing set to read: [set demo_var]"

puts "\nDone."
