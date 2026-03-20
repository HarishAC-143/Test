#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 07: Control Flow
# =============================================================================

puts "=== if / elseif / else ==="
set score 85

if {$score >= 90} {
    puts "Grade: A (Excellent!)"
} elseif {$score >= 80} {
    puts "Grade: B (Good)"
} elseif {$score >= 70} {
    puts "Grade: C (Average)"
} elseif {$score >= 60} {
    puts "Grade: D (Below Average)"
} else {
    puts "Grade: F (Fail)"
}

puts "\n=== Nested if ==="
set age 25
set has_license true

if {$age >= 18} {
    if {$has_license} {
        puts "You can drive."
    } else {
        puts "You are old enough but need a license."
    }
} else {
    puts "You are too young to drive."
}

puts "\n=== Compound Conditions ==="
set temperature 72
set raining false

if {$temperature > 60 && $temperature < 85 && !$raining} {
    puts "Perfect weather for a walk!"
} elseif {$raining} {
    puts "Better bring an umbrella."
} else {
    puts "Maybe stay indoors."
}

puts "\n=== switch (exact match) ==="
set day "Wednesday"
switch $day {
    Monday    { puts "Start of work week" }
    Tuesday   { puts "Second day" }
    Wednesday { puts "Midweek — hump day!" }
    Thursday  { puts "Almost Friday" }
    Friday    { puts "TGIF!" }
    Saturday -
    Sunday    { puts "Weekend!" }
    default   { puts "Not a valid day" }
}

puts "\n=== switch -exact with variable ==="
set fruit "banana"
switch -exact -- $fruit {
    apple   { puts "An apple a day..." }
    banana  { puts "Banana is rich in potassium" }
    cherry  { puts "Life is a bowl of cherries" }
    default { puts "Unknown fruit: $fruit" }
}

puts "\n=== switch -glob ==="
set filename "report_2026.csv"
switch -glob -- $filename {
    *.txt  { puts "Text file" }
    *.csv  { puts "CSV file" }
    *.json { puts "JSON file" }
    *.tcl  { puts "Tcl script" }
    default { puts "Unknown file type" }
}

puts "\n=== switch -regexp ==="
set logline "2026-03-20 ERROR: Connection timeout"
switch -regexp -- $logline {
    {ERROR}   { puts "Error detected!" }
    {WARNING} { puts "Warning detected" }
    {INFO}    { puts "Info message" }
    {DEBUG}   { puts "Debug message" }
    default   { puts "Unclassified" }
}

puts "\n=== Ternary-style Expression ==="
set x 42
set result [expr {$x > 0 ? "positive" : ($x < 0 ? "negative" : "zero")}]
puts "$x is $result"

set y -5
set abs_y [expr {$y < 0 ? -$y : $y}]
puts "Absolute value of $y is $abs_y"

puts "\n=== Boolean Evaluation ==="
set items {a b c}
if {[llength $items] > 0} {
    puts "List has [llength $items] items"
}

set name ""
if {$name eq ""} {
    puts "Name is empty"
}

if {[string length $name] == 0} {
    puts "Name has zero length"
}
