#!/usr/bin/env tclsh
#
# 02_control_flow.tcl — Demonstrates if/else, switch, and loops
#

puts "=============================="
puts " Control Flow Demo"
puts "=============================="
puts ""

# --- if / elseif / else ---
puts "--- if / elseif / else ---"
set temperature 25

if {$temperature > 35} {
    puts "It's hot! ($temperature°C)"
} elseif {$temperature > 20} {
    puts "It's warm. ($temperature°C)"
} elseif {$temperature > 10} {
    puts "It's cool. ($temperature°C)"
} else {
    puts "It's cold! ($temperature°C)"
}
puts ""

# --- switch ---
puts "--- switch ---"
set day "Wednesday"

switch $day {
    "Monday" - "Tuesday" - "Wednesday" - "Thursday" - "Friday" {
        puts "$day is a weekday."
    }
    "Saturday" - "Sunday" {
        puts "$day is a weekend."
    }
    default {
        puts "Unknown day: $day"
    }
}
puts ""

# --- for loop ---
puts "--- for loop (squares of 1-10) ---"
for {set i 1} {$i <= 10} {incr i} {
    puts [format "  %2d^2 = %3d" $i [expr {$i * $i}]]
}
puts ""

# --- while loop ---
puts "--- while loop (Collatz sequence from 27) ---"
set n 27
set steps 0
puts -nonewline "  $n"
while {$n != 1} {
    if {$n % 2 == 0} {
        set n [expr {$n / 2}]
    } else {
        set n [expr {3 * $n + 1}]
    }
    puts -nonewline " -> $n"
    incr steps
}
puts "\n  Reached 1 in $steps steps."
puts ""

# --- foreach ---
puts "--- foreach ---"
set languages [list TCL Python Perl Ruby Go Rust]
foreach lang $languages {
    puts "  Language: $lang ([string length $lang] chars)"
}
puts ""

# --- foreach with multiple variables ---
puts "--- foreach (key-value pairs) ---"
set info [list name Alice age 30 city Boston role Engineer]
foreach {key val} $info {
    puts [format "  %-6s: %s" $key $val]
}
puts ""

# --- break and continue ---
puts "--- break and continue ---"
puts "  Odd numbers under 20 (skipping multiples of 5):"
puts -nonewline "  "
for {set i 1} {$i < 20} {incr i} {
    if {$i % 2 == 0} continue
    if {$i % 5 == 0} continue
    puts -nonewline "$i "
}
puts "\n"

# --- Nested loops ---
puts "--- Multiplication table (1-5) ---"
puts -nonewline [format "  %4s" ""]
for {set j 1} {$j <= 5} {incr j} {
    puts -nonewline [format "%4d" $j]
}
puts ""
puts "  [string repeat "----" 6]"
for {set i 1} {$i <= 5} {incr i} {
    puts -nonewline [format "  %2d |" $i]
    for {set j 1} {$j <= 5} {incr j} {
        puts -nonewline [format "%4d" [expr {$i * $j}]]
    }
    puts ""
}
puts ""

puts "Done!"
