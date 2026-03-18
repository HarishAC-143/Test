#!/usr/bin/env tclsh
# =============================================================================
# Example 3: Control Flow
# Demonstrates: if/elseif/else, switch, while, for, foreach, break, continue
# =============================================================================

puts "=== Control Flow ===\n"

# --- if / elseif / else ---
puts "--- Grade Calculator (if/elseif/else) ---"
foreach score {95 85 75 65 50} {
    if {$score >= 90} {
        set grade "A"
    } elseif {$score >= 80} {
        set grade "B"
    } elseif {$score >= 70} {
        set grade "C"
    } elseif {$score >= 60} {
        set grade "D"
    } else {
        set grade "F"
    }
    puts "  Score $score -> Grade $grade"
}

# --- switch ---
puts "\n--- Traffic Light (switch) ---"
foreach color {red yellow green blue} {
    switch $color {
        red     { set action "STOP" }
        yellow  { set action "CAUTION" }
        green   { set action "GO" }
        default { set action "UNKNOWN" }
    }
    puts "  $color -> $action"
}

# --- switch with pattern matching ---
puts "\n--- File Type Detection (switch -glob) ---"
foreach file {report.pdf image.png data.csv script.tcl readme.xyz} {
    switch -glob $file {
        *.pdf   { set type "PDF Document" }
        *.png   { set type "PNG Image" }
        *.csv   { set type "CSV Data" }
        *.tcl   { set type "TCL Script" }
        default { set type "Unknown" }
    }
    puts "  $file -> $type"
}

# --- while loop ---
puts "\n--- Fibonacci Sequence (while loop) ---"
set a 0
set b 1
set count 0
set fib_list [list]
while {$count < 10} {
    lappend fib_list $a
    set temp $b
    set b [expr {$a + $b}]
    set a $temp
    incr count
}
puts "  First 10: [join $fib_list {, }]"

# --- for loop ---
puts "\n--- Multiplication Table (for loop) ---"
set n 5
puts "  Table of $n:"
for {set i 1} {$i <= 10} {incr i} {
    puts [format "    %d x %2d = %2d" $n $i [expr {$n * $i}]]
}

# --- foreach with multiple variables ---
puts "\n--- Inventory (foreach with pairs) ---"
set inventory {apple 50 banana 30 cherry 15 date 42}
foreach {item qty} $inventory {
    set status [expr {$qty < 20 ? "LOW STOCK" : "OK"}]
    puts [format "  %-10s %3d units  %s" $item $qty $status]
}

# --- break ---
puts "\n--- Finding first prime > 20 (break) ---"
proc is_prime {n} {
    if {$n < 2} { return 0 }
    if {$n == 2} { return 1 }
    if {$n % 2 == 0} { return 0 }
    for {set i 3} {$i * $i <= $n} {incr i 2} {
        if {$n % $i == 0} { return 0 }
    }
    return 1
}

for {set n 21} {$n < 100} {incr n} {
    if {[is_prime $n]} {
        puts "  First prime > 20 is: $n"
        break
    }
}

# --- continue ---
puts "\n--- Odd numbers 1-20 (continue) ---"
set odds [list]
for {set i 1} {$i <= 20} {incr i} {
    if {$i % 2 == 0} { continue }
    lappend odds $i
}
puts "  $odds"

puts "\nDone."
