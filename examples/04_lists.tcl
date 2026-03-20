#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 04: Lists
# =============================================================================

puts "=== Creating Lists ==="
set fruits {apple banana cherry date elderberry}
set nums [list 1 2 3 4 5]
set mixed [list "hello world" 42 {nested item}]

puts "Fruits: $fruits"
puts "Numbers: $nums"
puts "Mixed: $mixed"

puts "\n=== Accessing Elements ==="
puts "First fruit: [lindex $fruits 0]"
puts "Third fruit: [lindex $fruits 2]"
puts "Last fruit: [lindex $fruits end]"
puts "Second to last: [lindex $fruits end-1]"

puts "\n=== List Length ==="
puts "Number of fruits: [llength $fruits]"
puts "Number of nums: [llength $nums]"

puts "\n=== Appending Elements ==="
lappend fruits "fig" "grape"
puts "After lappend: $fruits"

puts "\n=== Inserting Elements ==="
set fruits [linsert $fruits 2 "blueberry"]
puts "After insert at 2: $fruits"

puts "\n=== Replacing Elements ==="
set fruits [lreplace $fruits 1 1 "blackberry"]
puts "After replace at 1: $fruits"

puts "\n=== Removing Elements ==="
set fruits [lreplace $fruits 3 3]
puts "After removing index 3: $fruits"

puts "\n=== Searching ==="
puts "Index of 'cherry': [lsearch $fruits "cherry"]"
puts "Index of 'mango': [lsearch $fruits "mango"]"
puts "Glob search 'b*': [lsearch -all -inline $fruits "b*"]"

puts "\n=== Sorting ==="
puts "Alphabetical: [lsort $fruits]"
puts "Reverse: [lsort -decreasing $fruits]"
set numbers {10 2 30 4 15 8}
puts "Numeric sort: [lsort -integer $numbers]"
puts "Reverse numeric: [lsort -integer -decreasing $numbers]"
set names {Bob alice Charlie bob Alice charlie}
puts "Case-insensitive sort: [lsort -nocase $names]"
puts "Unique sort: [lsort -unique {a b a c b d}]"

puts "\n=== Iterating ==="
puts "--- foreach ---"
foreach fruit $fruits {
    puts "  Fruit: $fruit"
}

puts "\n--- foreach with multiple variables ---"
foreach {key value} {name Alice age 30 city Portland} {
    puts "  $key: $value"
}

puts "\n--- foreach over multiple lists ---"
foreach letter {a b c} number {1 2 3} {
    puts "  $letter -> $number"
}

puts "\n=== Joining and Splitting ==="
set csv [join $fruits ", "]
puts "Joined with comma: $csv"

set path "/usr/local/bin"
set parts [split $path "/"]
puts "Split path: $parts"

set csv_line "Alice,30,Portland,Engineer"
set fields [split $csv_line ","]
puts "CSV fields: $fields"

puts "\n=== List Range ==="
puts "Range 1-3: [lrange $fruits 1 3]"
puts "Range 0-end-1: [lrange $fruits 0 end-1]"

puts "\n=== lmap (Tcl 8.6+) ==="
set upper_fruits [lmap f $fruits {string toupper $f}]
puts "Uppercased: $upper_fruits"

set doubled [lmap n {1 2 3 4 5} {expr {$n * 2}}]
puts "Doubled: $doubled"

puts "\n=== Nested Lists ==="
set matrix [list [list 1 2 3] [list 4 5 6] [list 7 8 9]]
puts "Matrix: $matrix"
puts "Element (1,2): [lindex [lindex $matrix 1] 2]"
puts "Using multi-index: [lindex $matrix 1 2]"

puts "\n=== List as Stack ==="
set stack {}
lappend stack "first"
lappend stack "second"
lappend stack "third"
puts "Stack: $stack"

set top [lindex $stack end]
set stack [lrange $stack 0 end-1]
puts "Popped: $top"
puts "Stack now: $stack"

puts "\n=== List as Queue ==="
set queue {}
lappend queue "first"
lappend queue "second"
lappend queue "third"
puts "Queue: $queue"

set front [lindex $queue 0]
set queue [lrange $queue 1 end]
puts "Dequeued: $front"
puts "Queue now: $queue"
