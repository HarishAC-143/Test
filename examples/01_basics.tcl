#!/usr/bin/env tclsh
#
# 01_basics.tcl — Demonstrates fundamental TCL concepts
#

puts "=============================="
puts " TCL Basics Demo"
puts "=============================="
puts ""

# --- Variables ---
puts "--- Variables ---"
set name "Alice"
set age 30
set pi 3.14159

puts "Name: $name"
puts "Age:  $age"
puts "Pi:   $pi"
puts ""

# --- Expressions ---
puts "--- Arithmetic ---"
set a 15
set b 4

puts "$a + $b = [expr {$a + $b}]"
puts "$a - $b = [expr {$a - $b}]"
puts "$a * $b = [expr {$a * $b}]"
puts "$a / $b = [expr {$a / $b}]  (integer division)"
puts "$a / $b = [expr {double($a) / $b}]  (float division)"
puts "$a % $b = [expr {$a % $b}]"
puts "2^10   = [expr {2 ** 10}]"
puts ""

# --- Strings ---
puts "--- String Operations ---"
set greeting "Hello, World!"
puts "String:  $greeting"
puts "Length:  [string length $greeting]"
puts "Upper:   [string toupper $greeting]"
puts "Lower:   [string tolower $greeting]"
puts "Index 0: [string index $greeting 0]"
puts "Range:   [string range $greeting 0 4]"
puts "Reverse: [string reverse $greeting]"
puts ""

# --- Quoting ---
puts "--- Quoting ---"
set val 42
puts "Double quotes allow substitution: $val"
puts {Curly braces prevent substitution: $val}
puts "Command substitution: [expr {$val * 2}]"
puts ""

# --- Ternary ---
puts "--- Ternary Operator ---"
set score 85
set grade [expr {$score >= 90 ? "A" : $score >= 80 ? "B" : "C"}]
puts "Score $score => Grade $grade"
puts ""

# --- Type Checking ---
puts "--- Type Checking ---"
foreach {val type} [list "42" integer "3.14" double "hello" alpha "yes" boolean "" space] {
    puts [format "  %-10s is %-10s: %s" "\"$val\"" $type [string is $type $val]]
}
puts ""

puts "Done!"
