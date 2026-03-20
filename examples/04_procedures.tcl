#!/usr/bin/env tclsh
#
# 04_procedures.tcl — Demonstrates procedures, scope, and functional patterns
#

puts "=============================="
puts " Procedures & Functions Demo"
puts "=============================="
puts ""

# --- Basic Procedures ---
puts "--- Basic Procedures ---"

proc greet {name} {
    return "Hello, $name! Welcome to TCL."
}

puts [greet "Alice"]
puts [greet "Bob"]
puts ""

# --- Default Arguments ---
puts "--- Default Arguments ---"

proc make_tag {text {tag "p"} {class ""}} {
    if {$class ne ""} {
        return "<$tag class=\"$class\">$text</$tag>"
    }
    return "<$tag>$text</$tag>"
}

puts [make_tag "Hello World"]
puts [make_tag "Title" "h1"]
puts [make_tag "Important" "span" "highlight"]
puts ""

# --- Variable Arguments ---
puts "--- Variable Arguments (args) ---"

proc log_message {level args} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    puts "\[$timestamp\] \[$level\] [join $args " "]"
}

log_message "INFO" "Application started successfully"
log_message "WARN" "Connection timeout after" "30" "seconds"
log_message "ERROR" "Failed to open file:" "/tmp/data.txt"
puts ""

# --- Recursive Procedures ---
puts "--- Recursion ---"

proc factorial {n} {
    if {$n <= 1} { return 1 }
    return [expr {$n * [factorial [expr {$n - 1}]]}]
}

for {set i 1} {$i <= 10} {incr i} {
    puts [format "  %2d! = %d" $i [factorial $i]]
}
puts ""

proc quicksort {lst} {
    if {[llength $lst] <= 1} { return $lst }
    set pivot [lindex $lst 0]
    set rest [lrange $lst 1 end]
    set less [list]
    set greater [list]
    foreach elem $rest {
        if {$elem <= $pivot} {
            lappend less $elem
        } else {
            lappend greater $elem
        }
    }
    return [concat [quicksort $less] [list $pivot] [quicksort $greater]]
}

set unsorted [list 38 27 43 3 9 82 10 64 51 17]
puts "Unsorted:  $unsorted"
puts "Sorted:    [quicksort $unsorted]"
puts ""

# --- upvar (pass by reference) ---
puts "--- upvar (pass by reference) ---"

proc swap {varA varB} {
    upvar 1 $varA a $varB b
    set temp $a
    set a $b
    set b $temp
}

set x "first"
set y "second"
puts "Before swap: x=$x, y=$y"
swap x y
puts "After swap:  x=$x, y=$y"
puts ""

proc increment_all {listVar amount} {
    upvar 1 $listVar data
    set result [list]
    foreach val $data {
        lappend result [expr {$val + $amount}]
    }
    set data $result
}

set values [list 10 20 30 40 50]
puts "Before: $values"
increment_all values 5
puts "After +5: $values"
puts ""

# --- Passing arrays to procedures ---
puts "--- Passing Arrays ---"

proc array_stats {arrName} {
    upvar 1 $arrName arr
    set total 0
    set count 0
    foreach key [array names arr] {
        set total [expr {$total + $arr($key)}]
        incr count
    }
    set avg [expr {double($total) / $count}]
    return [dict create count $count total $total average $avg]
}

array set scores {math 95 science 88 english 92 history 78 art 96}
set stats [array_stats scores]
puts "Scores statistics:"
dict for {k v} $stats {
    puts [format "  %-10s: %.1f" $k $v]
}
puts ""

# --- Lambda / apply ---
puts "--- Lambda (apply) ---"

set double [list x {expr {$x * 2}}]
set square [list x {expr {$x * $x}}]

puts "double(7) = [apply $double 7]"
puts "square(7) = [apply $square 7]"
puts ""

# Higher-order function: map
proc map {func lst} {
    set result [list]
    foreach item $lst {
        lappend result [apply $func $item]
    }
    return $result
}

proc filter {func lst} {
    set result [list]
    foreach item $lst {
        if {[apply $func $item]} {
            lappend result $item
        }
    }
    return $result
}

proc reduce {func init lst} {
    set acc $init
    foreach item $lst {
        set acc [apply $func $acc $item]
    }
    return $acc
}

set nums [list 1 2 3 4 5 6 7 8 9 10]
puts "Numbers: $nums"
puts "Doubled: [map {x {expr {$x * 2}}} $nums]"
puts "Evens:   [filter {x {expr {$x % 2 == 0}}} $nums]"
puts "Sum:     [reduce {{acc x} {expr {$acc + $x}}} 0 $nums]"
puts "Product: [reduce {{acc x} {expr {$acc * $x}}} 1 $nums]"
puts ""

# --- Memoization ---
puts "--- Memoization ---"

proc memoize {func} {
    set body [info body $func]
    set args [info args $func]
    rename $func _original_$func
    proc $func $args "
        variable _memo_cache
        set key \[list $func [join [lmap a $args {subst {[set $a]}}] " "]\]
        if {\[info exists _memo_cache(\$key)\]} {
            return \$_memo_cache(\$key)
        }
        set result \[_original_$func [join [lmap a $args {set a}] " "]\]
        set _memo_cache(\$key) \$result
        return \$result
    "
}

proc slow_square {n} {
    after 10
    return [expr {$n * $n}]
}

set start [clock milliseconds]
for {set i 0} {$i < 20} {incr i} {
    slow_square [expr {$i % 5}]
}
set elapsed [expr {[clock milliseconds] - $start}]
puts "Without memoization: ${elapsed}ms for 20 calls"

puts ""
puts "Done!"
