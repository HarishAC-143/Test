#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 02: Variables and Data Types
# =============================================================================

puts "=== Setting and Getting Variables ==="
set name "Alice"
set age 30
set height 5.7
set active true

puts "Name: $name"
puts "Age: $age"
puts "Height: $height"
puts "Active: $active"

puts "\n=== Variable Substitution ==="
puts "Hello, $name! You are $age years old."
puts "In 10 years, $name will be [expr {$age + 10}] years old."

puts "\n=== Braces Prevent Substitution ==="
puts {The variable $name is not substituted inside braces.}
puts {Neither is the command [expr {1 + 1}].}

puts "\n=== Dynamic Typing ==="
set x "42"
puts "x as string has length: [string length $x]"
puts "x as number plus 8: [expr {$x + 8}]"
puts "x in a list context: [lindex [list $x 99] 0]"

puts "\n=== Checking Variable Existence ==="
puts "Does 'name' exist? [info exists name]"
puts "Does 'unknown_var' exist? [info exists unknown_var]"

puts "\n=== Unsetting Variables ==="
set temp "I will be deleted"
puts "temp before unset: $temp"
unset temp
puts "Does 'temp' exist after unset? [info exists temp]"

puts "\n=== Multi-word Variable Values ==="
set greeting "Hello, World!"
set sentence "Tcl is a powerful scripting language"
puts $greeting
puts "Word count: [llength [split $sentence]]"

puts "\n=== Appending to Variables ==="
set msg "Hello"
append msg ", " "World" "!"
puts $msg

puts "\n=== Increment/Decrement ==="
set counter 0
incr counter       ;# counter = 1
incr counter 5     ;# counter = 6
incr counter -2    ;# counter = 4
puts "Counter: $counter"
