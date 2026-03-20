#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 21: Coroutines (Tcl 8.6+)
# =============================================================================

puts "=== Basic Coroutine ==="
proc simple_counter {} {
    set i 0
    while {1} {
        yield $i
        incr i
    }
}

coroutine myCounter simple_counter
puts "Counter: [myCounter]"
puts "Counter: [myCounter]"
puts "Counter: [myCounter]"
puts "Counter: [myCounter]"
puts "Counter: [myCounter]"
rename myCounter {}

puts "\n=== Fibonacci Generator ==="
proc fibonacci {} {
    set a 0
    set b 1
    while {1} {
        yield $a
        lassign [list $b [expr {$a + $b}]] a b
    }
}

coroutine fib fibonacci
puts -nonewline "First 15 Fibonacci numbers: "
for {set i 0} {$i < 15} {incr i} {
    puts -nonewline "[fib] "
}
puts ""
rename fib {}

puts "\n=== Range Generator ==="
proc range_gen {start end {step 1}} {
    for {set i $start} {$i < $end} {incr i $step} {
        yield $i
    }
}

coroutine rng range_gen 0 10 2
puts -nonewline "Range 0-10 step 2: "
while {![catch {set val [rng]}]} {
    puts -nonewline "$val "
}
puts ""

puts "\n=== Infinite Sequence Generators ==="
proc powers_of {base} {
    set value 1
    while {1} {
        yield $value
        set value [expr {$value * $base}]
    }
}

coroutine pow2 powers_of 2
puts -nonewline "Powers of 2: "
for {set i 0} {$i < 10} {incr i} {
    puts -nonewline "[pow2] "
}
puts ""
rename pow2 {}

coroutine pow3 powers_of 3
puts -nonewline "Powers of 3: "
for {set i 0} {$i < 8} {incr i} {
    puts -nonewline "[pow3] "
}
puts ""
rename pow3 {}

puts "\n=== Coroutine with Input (yield receives values) ==="
proc accumulator {} {
    set total 0
    while {1} {
        set value [yield $total]
        set total [expr {$total + $value}]
    }
}

coroutine acc accumulator
acc 0
puts "Accumulator:"
foreach val {10 20 30 40 50} {
    puts "  Add $val → [acc $val]"
}
rename acc {}

puts "\n=== Producer-Consumer Pattern ==="
proc producer {consumer_name items} {
    foreach item $items {
        puts "  Producing: $item"
        $consumer_name $item
    }
    $consumer_name "DONE"
}

proc consumer_body {} {
    set received {}
    while {1} {
        set item [yield]
        if {$item eq "DONE"} break
        puts "  Consuming: $item"
        lappend received $item
    }
    puts "  Consumer received [llength $received] items: $received"
}

coroutine myConsumer consumer_body
producer myConsumer {apple banana cherry date elderberry}

puts "\n=== Coroutine-based State Machine ==="
proc traffic_light {} {
    while {1} {
        yield "RED"
        yield "RED"
        yield "GREEN"
        yield "GREEN"
        yield "GREEN"
        yield "YELLOW"
    }
}

coroutine light traffic_light
puts "Traffic light sequence:"
for {set i 0} {$i < 12} {incr i} {
    set state [light]
    set color_indicator ""
    switch $state {
        RED    { set color_indicator "●○○" }
        YELLOW { set color_indicator "○●○" }
        GREEN  { set color_indicator "○○●" }
    }
    puts "  Step [format %2d $i]: $color_indicator $state"
}
rename light {}

puts "\n=== Iterator Pattern ==="
proc list_iterator {lst} {
    foreach item $lst {
        yield $item
    }
}

proc dict_iterator {d} {
    dict for {key value} $d {
        yield [list $key $value]
    }
}

coroutine iter list_iterator {alpha beta gamma delta}
puts "List iteration:"
while {![catch {set val [iter]}]} {
    puts "  $val"
}

set data [dict create name "Alice" age 30 city "Portland"]
coroutine diter dict_iterator $data
puts "\nDict iteration:"
while {![catch {set pair [diter]}]} {
    lassign $pair k v
    puts "  $k => $v"
}

puts "\n=== Multiple Concurrent Coroutines ==="
proc worker {name tasks} {
    foreach task $tasks {
        yield "[$name] Processing: $task"
    }
    yield "[$name] Done!"
}

coroutine w1 worker "Worker-A" {task1 task2 task3}
coroutine w2 worker "Worker-B" {taskX taskY}
coroutine w3 worker "Worker-C" {alpha beta gamma delta}

set workers {w1 w2 w3}
set active $workers

puts "Round-robin scheduling:"
set round 1
while {[llength $active] > 0} {
    puts "  --- Round $round ---"
    set still_active {}
    foreach w $active {
        if {![catch {set msg [$w]}]} {
            puts "  $msg"
            lappend still_active $w
        }
    }
    set active $still_active
    incr round
}

puts "\n=== Practical: Coroutine-based Pipeline ==="
proc source_gen {items} {
    foreach item $items {
        yield $item
    }
}

proc transform {source_name func} {
    while {![catch {set item [$source_name]}]} {
        yield [apply $func $item]
    }
}

proc take_gen {source_name n} {
    for {set i 0} {$i < $n} {incr i} {
        if {[catch {set item [$source_name]}]} break
        yield $item
    }
}

coroutine src source_gen {1 2 3 4 5 6 7 8 9 10}
coroutine doubled transform src {x {expr {$x * 2}}}
coroutine first5 take_gen doubled 5

puts "Pipeline (source → double → take 5):"
while {![catch {set val [first5]}]} {
    puts "  $val"
}
