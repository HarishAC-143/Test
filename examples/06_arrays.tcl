#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 06: Arrays (Associative Hash Tables)
# =============================================================================

puts "=== Creating and Setting Array Elements ==="
set config(host) "localhost"
set config(port) 8080
set config(debug) true
set config(log_level) "info"

puts "Host: $config(host)"
puts "Port: $config(port)"
puts "Debug: $config(debug)"

puts "\n=== Array from a List (array set) ==="
array set colors {
    red     "#FF0000"
    green   "#00FF00"
    blue    "#0000FF"
    yellow  "#FFFF00"
    white   "#FFFFFF"
    black   "#000000"
}
puts "Red hex: $colors(red)"
puts "Blue hex: $colors(blue)"

puts "\n=== Array Information ==="
puts "Array 'config' exists? [array exists config]"
puts "Array 'undefined' exists? [array exists undefined]"
puts "config(host) exists? [info exists config(host)]"
puts "config(missing) exists? [info exists config(missing)]"
puts "Size of 'config': [array size config]"
puts "Size of 'colors': [array size colors]"

puts "\n=== Array Names ==="
puts "Config keys: [array names config]"
puts "Config keys sorted: [lsort [array names config]]"
puts "Color keys with pattern 'b*': [array names colors "b*"]"

puts "\n=== Iterating Over an Array ==="
puts "--- Using array get ---"
foreach {key value} [array get config] {
    puts [format "  %-12s = %s" $key $value]
}

puts "\n--- Using array names (sorted) ---"
foreach key [lsort [array names colors]] {
    puts [format "  %-8s => %s" $key $colors($key)]
}

puts "\n=== Array Get (Export to List) ==="
set config_list [array get config]
puts "Config as list: $config_list"

puts "\n=== Modifying Array Elements ==="
set config(port) 9090
set config(timeout) 30
puts "Updated port: $config(port)"
puts "New key 'timeout': $config(timeout)"

puts "\n=== Unsetting Array Elements ==="
array unset config debug
puts "After unsetting 'debug', keys: [lsort [array names config]]"

puts "\n=== Unsetting Entire Array ==="
array set temp_array {a 1 b 2 c 3}
puts "Before unset: [array names temp_array]"
array unset temp_array
puts "After unset: [array exists temp_array]"

puts "\n=== Array vs Dict Comparison ==="
puts "Arrays:"
puts "  - Accessed via \$arr(key) syntax"
puts "  - Cannot be passed as a single value"
puts "  - Modified in-place (no set needed)"
puts "  - Great for global lookup tables"
puts ""
puts "Dicts:"
puts "  - A regular Tcl value (string)"
puts "  - Can be passed to procs and returned"
puts "  - Require dict set to modify"
puts "  - Better for structured data and nesting"

puts "\n=== Practical: Building a Frequency Counter ==="
set text "the cat sat on the mat the cat wore a hat"
foreach word [split $text] {
    if {[info exists freq($word)]} {
        incr freq($word)
    } else {
        set freq($word) 1
    }
}

puts "Word frequencies:"
foreach word [lsort [array names freq]] {
    puts [format "  %-8s : %d" $word $freq($word)]
}

puts "\n=== Practical: Multi-dimensional Array ==="
for {set r 0} {$r < 3} {incr r} {
    for {set c 0} {$c < 3} {incr c} {
        set grid($r,$c) [expr {$r * 3 + $c + 1}]
    }
}

puts "3x3 Grid:"
for {set r 0} {$r < 3} {incr r} {
    set row {}
    for {set c 0} {$c < 3} {incr c} {
        lappend row [format "%2d" $grid($r,$c)]
    }
    puts "  [join $row "  "]"
}
