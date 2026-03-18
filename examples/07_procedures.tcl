#!/usr/bin/env tclsh
# =============================================================================
# Example 7: Procedures (Functions)
# Demonstrates: proc, return, default args, args, upvar, global, recursion
# =============================================================================

puts "=== Procedures ===\n"

# --- Basic procedure ---
proc greet {name} {
    return "Hello, $name!"
}

puts [greet "Alice"]
puts [greet "World"]

# --- Multiple parameters ---
proc rectangle_area {width height} {
    return [expr {$width * $height}]
}

proc rectangle_perimeter {width height} {
    return [expr {2 * ($width + $height)}]
}

puts "\n--- Rectangle (5 x 3) ---"
puts "  Area:      [rectangle_area 5 3]"
puts "  Perimeter: [rectangle_perimeter 5 3]"

# --- Default arguments ---
proc connect {host {port 80} {protocol "http"}} {
    return "$protocol://$host:$port"
}

puts "\n--- Default Arguments ---"
puts "  [connect "example.com"]"
puts "  [connect "example.com" 443]"
puts "  [connect "example.com" 443 "https"]"

# --- Variable-length arguments ---
proc average {args} {
    if {[llength $args] == 0} {
        error "average requires at least one argument"
    }
    set sum 0.0
    foreach val $args {
        set sum [expr {$sum + $val}]
    }
    return [expr {$sum / [llength $args]}]
}

puts "\n--- Variable Arguments ---"
puts "  avg(10, 20, 30): [average 10 20 30]"
puts "  avg(5): [average 5]"
puts "  avg(1,2,3,4,5,6,7,8,9,10): [average 1 2 3 4 5 6 7 8 9 10]"

# --- Returning multiple values (as a list) ---
proc min_max {args} {
    set sorted [lsort -real $args]
    return [list [lindex $sorted 0] [lindex $sorted end]]
}

puts "\n--- Multiple Return Values ---"
lassign [min_max 42 17 93 5 68] minimum maximum
puts "  min_max(42,17,93,5,68): min=$minimum, max=$maximum"

# --- upvar: pass by reference ---
proc swap {varA varB} {
    upvar 1 $varA a $varB b
    set temp $a
    set a $b
    set b $temp
}

set x "first"
set y "second"
puts "\n--- upvar (pass by reference) ---"
puts "  Before swap: x=$x, y=$y"
swap x y
puts "  After swap:  x=$x, y=$y"

proc append_to_list {listVar args} {
    upvar 1 $listVar mylist
    foreach item $args {
        lappend mylist $item
    }
}

set mydata {1 2 3}
append_to_list mydata 4 5 6
puts "  After append_to_list: $mydata"

# --- global variables ---
set ::total_calls 0

proc tracked_operation {name} {
    global total_calls
    incr total_calls
    return "Operation '$name' (call #$total_calls)"
}

puts "\n--- Global Variables ---"
puts "  [tracked_operation "read"]"
puts "  [tracked_operation "write"]"
puts "  [tracked_operation "delete"]"
puts "  Total calls: $::total_calls"

# --- Recursion ---
proc factorial {n} {
    if {$n <= 1} { return 1 }
    return [expr {$n * [factorial [expr {$n - 1}]]}]
}

proc fibonacci_list {n} {
    set result [list]
    for {set i 0} {$i < $n} {incr i} {
        lappend result [fib $i]
    }
    return $result
}

proc fib {n} {
    if {$n <= 1} { return $n }
    return [expr {[fib [expr {$n-1}]] + [fib [expr {$n-2}]]}]
}

puts "\n--- Recursion ---"
foreach n {1 5 10 15 20} {
    puts "  $n! = [factorial $n]"
}
puts "  Fibonacci(12): [fibonacci_list 12]"

# --- Higher-order procedures ---
proc apply_to_each {lst func} {
    set result [list]
    foreach item $lst {
        lappend result [$func $item]
    }
    return $result
}

proc double {x} { return [expr {$x * 2}] }
proc square {x} { return [expr {$x * $x}] }
proc negate {x} { return [expr {-$x}] }

puts "\n--- Higher-Order Procedures ---"
set nums {1 2 3 4 5}
puts "  Original: $nums"
puts "  Doubled:  [apply_to_each $nums double]"
puts "  Squared:  [apply_to_each $nums square]"
puts "  Negated:  [apply_to_each $nums negate]"

# --- Procedure introspection ---
puts "\n--- Introspection ---"
puts "  'greet' args: [info args greet]"
puts "  'greet' body: [string trim [info body greet]]"
puts "  'connect' args: [info args connect]"
puts "  'connect' default for 'port': [info default connect port val]; val=$val"

puts "\nDone."
