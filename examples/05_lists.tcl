#!/usr/bin/env tclsh
# =============================================================================
# Example 5: Lists
# Demonstrates: list operations, sorting, searching, nested lists, lmap
# =============================================================================

puts "=== Lists ===\n"

# --- Creating lists ---
puts "--- Creating Lists ---"
set fruits {apple banana cherry date elderberry}
puts "  Literal: $fruits"

set mixed [list "hello world" 42 {with braces} normal]
puts "  list cmd: $mixed"

set from_split [split "one:two:three:four" ":"]
puts "  split:    $from_split"

# --- Accessing elements ---
puts "\n--- Accessing Elements ---"
puts "  First:    [lindex $fruits 0]"
puts "  Third:    [lindex $fruits 2]"
puts "  Last:     [lindex $fruits end]"
puts "  2nd last: [lindex $fruits end-1]"
puts "  Length:   [llength $fruits]"
puts "  Range:    [lrange $fruits 1 3]"

# --- Modifying lists ---
puts "\n--- Modifying Lists ---"
set colors {red green blue}
puts "  Original:  $colors"

lappend colors "yellow" "purple"
puts "  lappend:   $colors"

set colors [linsert $colors 2 "cyan"]
puts "  linsert:   $colors"

set colors [lreplace $colors 1 1 "GREEN"]
puts "  lreplace:  $colors"

lset colors end "PURPLE"
puts "  lset:      $colors"

set colors [lreplace $colors 2 2]
puts "  remove:    $colors"

# --- Searching ---
puts "\n--- Searching ---"
set animals {cat dog bird fish cat dog elephant}

puts "  Find 'bird':   index [lsearch $animals "bird"]"
puts "  Find 'snake':  index [lsearch $animals "snake"]"
puts "  All 'cat':     indices [lsearch -all $animals "cat"]"
puts "  Glob 'd*':     index [lsearch -glob $animals "d*"]"
puts "  Inline 'f*':   [lsearch -inline $animals "f*"]"
puts "  All inline '*a*': [lsearch -all -inline $animals "*a*"]"

# --- Sorting ---
puts "\n--- Sorting ---"
set numbers {3 1 4 1 5 9 2 6 5 3 5}
puts "  Original:    $numbers"
puts "  Sorted:      [lsort -integer $numbers]"
puts "  Descending:  [lsort -integer -decreasing $numbers]"
puts "  Unique:      [lsort -unique -integer $numbers]"

set words {banana Apple cherry Date elderberry}
puts "  Words (case): [lsort $words]"
puts "  Words (no case): [lsort -nocase $words]"

# --- Iteration ---
puts "\n--- Iteration ---"
puts "  Fruits:"
foreach fruit {apple banana cherry} {
    puts "    - $fruit"
}

puts "  Key-Value pairs:"
foreach {key val} {name Alice age 30 city Boston} {
    puts "    $key = $val"
}

puts "  Parallel lists:"
set names {Alice Bob Carol}
set scores {95 87 92}
foreach name $names score $scores {
    puts "    $name scored $score"
}

# --- lmap (transform) ---
puts "\n--- lmap (Transform) ---"
set nums {1 2 3 4 5 6 7 8 9 10}
set squares [lmap n $nums { expr {$n * $n} }]
puts "  Squares: $squares"

set evens [lmap n $nums {
    if {$n % 2 == 0} {set n} else {continue}
}]
puts "  Evens:   $evens"

# --- join ---
puts "\n--- Joining ---"
set parts {usr local bin}
puts "  Join with '/': [join $parts "/"]"
puts "  Join with ', ': [join $fruits ", "]"
puts "  Join with ' | ': [join {A B C D} " | "]"

# --- Nested lists ---
puts "\n--- Nested Lists ---"
set matrix {{1 2 3} {4 5 6} {7 8 9}}
puts "  Matrix:"
foreach row $matrix {
    puts "    $row"
}
puts "  Element \[1\]\[2\]: [lindex $matrix 1 2]"

# --- Stack and Queue operations ---
puts "\n--- Stack (LIFO) ---"
set stack [list]
foreach item {A B C D} {
    lappend stack $item
    puts "  Push $item -> $stack"
}
while {[llength $stack] > 0} {
    set top [lindex $stack end]
    set stack [lrange $stack 0 end-1]
    puts "  Pop $top  -> $stack"
}

puts "\nDone."
