#!/usr/bin/env tclsh
#
# 03_lists_and_dicts.tcl — Demonstrates lists, arrays, and dictionaries
#

puts "=============================="
puts " Lists, Arrays & Dicts Demo"
puts "=============================="
puts ""

# --- Lists ---
puts "--- Lists ---"
set fruits [list apple banana cherry date elderberry fig grape]
puts "Fruits: $fruits"
puts "Count:  [llength $fruits]"
puts "First:  [lindex $fruits 0]"
puts "Last:   [lindex $fruits end]"
puts "Slice:  [lrange $fruits 1 3]"
puts ""

puts "--- List Manipulation ---"
lappend fruits "honeydew"
puts "After lappend: $fruits"

set fruits [linsert $fruits 2 "coconut"]
puts "After linsert at 2: $fruits"

set fruits [lreplace $fruits 3 3]
puts "After removing index 3: $fruits"

puts "Sorted: [lsort $fruits]"
puts "Reversed: [lreverse $fruits]"
puts "Joined: [join $fruits ", "]"
puts ""

# --- List Search ---
puts "--- List Search ---"
puts "Index of 'grape': [lsearch $fruits grape]"
puts "Matching 'c*': [lsearch -all -inline $fruits c*]"
puts "Matching '*e*': [lsearch -all -inline $fruits *e*]"
puts ""

# --- Nested Lists (Matrix) ---
puts "--- Matrix Operations ---"
set matrix [list \
    [list 1 2 3] \
    [list 4 5 6] \
    [list 7 8 9] \
]

puts "Matrix:"
foreach row $matrix {
    puts "  [join $row "  "]"
}
puts "Element at (1,2): [lindex $matrix 1 2]"
puts ""

# Transpose the matrix
proc transpose {matrix} {
    set rows [llength $matrix]
    set cols [llength [lindex $matrix 0]]
    set result [list]
    for {set c 0} {$c < $cols} {incr c} {
        set new_row [list]
        for {set r 0} {$r < $rows} {incr r} {
            lappend new_row [lindex $matrix $r $c]
        }
        lappend result $new_row
    }
    return $result
}

puts "Transposed:"
foreach row [transpose $matrix] {
    puts "  [join $row "  "]"
}
puts ""

# --- lmap (TCL 8.6) ---
puts "--- lmap (functional list transform) ---"
set numbers [list 1 2 3 4 5 6 7 8 9 10]
set squares [lmap n $numbers {expr {$n * $n}}]
puts "Numbers: $numbers"
puts "Squares: $squares"

set evens [lmap n $numbers {
    if {$n % 2 == 0} {set n} else {continue}
}]
puts "Evens:   $evens"
puts ""

# --- Arrays ---
puts "--- Associative Arrays ---"
array set capital {
    USA        "Washington D.C."
    France     "Paris"
    Japan      "Tokyo"
    Australia  "Canberra"
    Brazil     "Brasilia"
}

puts "Countries: [lsort [array names capital]]"
puts "Capital of Japan: $capital(Japan)"
puts "Array size: [array size capital]"
puts ""

foreach country [lsort [array names capital]] {
    puts [format "  %-12s => %s" $country $capital($country)]
}
puts ""

# --- Dictionaries ---
puts "--- Dictionaries ---"
set student [dict create \
    name   "Bob" \
    id     "STU001" \
    grades [dict create math 95 science 88 english 92] \
    active true \
]

puts "Student: [dict get $student name]"
puts "ID:      [dict get $student id]"
puts "Math:    [dict get $student grades math]"
puts "Active:  [dict get $student active]"
puts ""

# Dictionary iteration
puts "All grades:"
dict for {subject score} [dict get $student grades] {
    puts [format "  %-10s %d" $subject $score]
}
puts ""

# Dictionary filtering
puts "--- Dictionary Filtering ---"
set inventory [dict create \
    apple   50 \
    banana  12 \
    cherry  75 \
    date    5 \
    fig     30 \
    grape   8 \
]

set low_stock [dict filter $inventory script {item qty} {
    expr {$qty < 15}
}]
puts "Low stock (< 15):"
dict for {item qty} $low_stock {
    puts "  $item: $qty units"
}
puts ""

# Dictionary merge
set defaults [dict create color blue size medium weight 1.0]
set overrides [dict create color red weight 2.5]
set config [dict merge $defaults $overrides]
puts "Merged config:"
dict for {k v} $config {
    puts "  $k = $v"
}
puts ""

puts "Done!"
