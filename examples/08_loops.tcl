#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 08: Loops
# =============================================================================

puts "=== while Loop ==="
set i 1
while {$i <= 5} {
    puts "  while: i = $i"
    incr i
}

puts "\n=== for Loop (C-style) ==="
for {set i 1} {$i <= 5} {incr i} {
    puts "  for: i = $i"
}

puts "\n=== Counting Down ==="
for {set i 5} {$i >= 1} {incr i -1} {
    puts "  countdown: $i"
}
puts "  Blast off!"

puts "\n=== Stepping by 2 ==="
for {set i 0} {$i <= 10} {incr i 2} {
    puts -nonewline "  $i"
}
puts ""

puts "\n=== foreach — Single Variable ==="
foreach fruit {apple banana cherry date} {
    puts "  Fruit: $fruit"
}

puts "\n=== foreach — Multiple Variables ==="
foreach {key value} {name Alice age 30 city Portland job Engineer} {
    puts "  $key: $value"
}

puts "\n=== foreach — Multiple Lists ==="
foreach letter {a b c d} number {1 2 3 4} {
    puts "  $letter -> $number"
}

puts "\n=== foreach — Uneven Lists ==="
foreach x {1 2 3} y {a b} {
    puts "  x=$x, y=$y"
}

puts "\n=== break ==="
puts "Breaking out of loop at 5:"
for {set i 0} {$i < 10} {incr i} {
    if {$i == 5} break
    puts -nonewline "  $i"
}
puts ""

puts "\n=== continue ==="
puts "Skipping odd numbers:"
for {set i 0} {$i < 10} {incr i} {
    if {$i % 2 != 0} continue
    puts -nonewline "  $i"
}
puts ""

puts "\n=== Nested Loops ==="
puts "Multiplication table (1-5):"
puts -nonewline [format "  %4s" ""]
for {set j 1} {$j <= 5} {incr j} {
    puts -nonewline [format " %4d" $j]
}
puts ""
puts "  [string repeat "-" 25]"
for {set i 1} {$i <= 5} {incr i} {
    puts -nonewline [format "  %3d|" $i]
    for {set j 1} {$j <= 5} {incr j} {
        puts -nonewline [format " %4d" [expr {$i * $j}]]
    }
    puts ""
}

puts "\n=== Loop with Accumulator ==="
set sum 0
for {set i 1} {$i <= 100} {incr i} {
    incr sum $i
}
puts "Sum of 1 to 100: $sum"

puts "\n=== Building a List in a Loop ==="
set squares {}
for {set i 1} {$i <= 10} {incr i} {
    lappend squares [expr {$i * $i}]
}
puts "Squares: $squares"

puts "\n=== do-while Equivalent ==="
set n 0
while {1} {
    incr n
    puts "  Attempt $n"
    if {$n >= 3} break
}
puts "Completed after $n attempts"

puts "\n=== Iterating Over Characters ==="
set word "Tcl"
for {set i 0} {$i < [string length $word]} {incr i} {
    puts "  Char $i: [string index $word $i]"
}

puts "\n=== Loop with Dict ==="
set inventory [dict create apples 50 bananas 30 cherries 100 dates 25]
puts "Items with stock > 30:"
dict for {item count} $inventory {
    if {$count > 30} {
        puts "  $item: $count"
    }
}
