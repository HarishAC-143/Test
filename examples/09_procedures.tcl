#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 09: Procedures (Functions)
# =============================================================================

puts "=== Basic Procedure ==="
proc greet {name} {
    puts "Hello, $name!"
}
greet "Alice"
greet "Bob"

puts "\n=== Procedure with Return Value ==="
proc add {a b} {
    return [expr {$a + $b}]
}
puts "3 + 4 = [add 3 4]"
puts "10 + 20 = [add 10 20]"

puts "\n=== Multiple Parameters ==="
proc full_name {first middle last} {
    return "$first $middle $last"
}
puts [full_name "John" "Michael" "Doe"]

puts "\n=== Default Arguments ==="
proc connect {host {port 80} {protocol "http"}} {
    puts "Connecting to $protocol://$host:$port"
}
connect "example.com"
connect "example.com" 443
connect "example.com" 443 "https"

puts "\n=== Variable Arguments (args) ==="
proc sum {args} {
    set total 0
    foreach n $args {
        set total [expr {$total + $n}]
    }
    return $total
}
puts "sum(1,2,3): [sum 1 2 3]"
puts "sum(10,20,30,40,50): [sum 10 20 30 40 50]"

proc log {level args} {
    set msg [join $args " "]
    puts "\[[string toupper $level]\] $msg"
}
log info "Server" "started" "on" "port" "8080"
log error "Connection" "failed"

puts "\n=== Global Variables ==="
set ::app_version "1.0.0"
proc show_version {} {
    global app_version
    puts "App version: $app_version"
}
show_version

puts "\n=== upvar — Modifying Caller's Variables ==="
proc double_var {varName} {
    upvar 1 $varName var
    set var [expr {$var * 2}]
}
set x 5
double_var x
puts "x after doubling: $x"

proc swap {aName bName} {
    upvar 1 $aName a $bName b
    set temp $a
    set a $b
    set b $temp
}
set a 10
set b 20
swap a b
puts "After swap: a=$a, b=$b"

puts "\n=== Recursive Procedures ==="
proc factorial {n} {
    if {$n <= 1} {return 1}
    return [expr {$n * [factorial [expr {$n - 1}]]}]
}
foreach n {1 5 10 15} {
    puts "factorial($n) = [factorial $n]"
}

proc fibonacci_r {n} {
    if {$n <= 1} {return $n}
    return [expr {[fibonacci_r [expr {$n-1}]] + [fibonacci_r [expr {$n-2}]]}]
}
puts -nonewline "Fibonacci: "
for {set i 0} {$i < 12} {incr i} {
    puts -nonewline "[fibonacci_r $i] "
}
puts ""

puts "\n=== Procedures Returning Lists ==="
proc min_max {args} {
    set sorted [lsort -real $args]
    list [lindex $sorted 0] [lindex $sorted end]
}
lassign [min_max 3 1 4 1 5 9 2 6] minimum maximum
puts "Min: $minimum, Max: $maximum"

puts "\n=== Procedures Returning Dicts ==="
proc parse_url {url} {
    regexp {^(https?)://([^/:]+)(?::(\d+))?(.*)$} $url \
        _ protocol host port path
    if {$port eq ""} {
        set port [expr {$protocol eq "https" ? 443 : 80}]
    }
    if {$path eq ""} {set path "/"}
    dict create protocol $protocol host $host port $port path $path
}

set url_info [parse_url "https://example.com:8080/api/v1"]
dict for {k v} $url_info {
    puts "  $k: $v"
}

puts "\n=== Procedure Introspection ==="
puts "Body of 'greet':"
puts "  [info body greet]"
puts "Args of 'connect': [info args connect]"
puts "Default of 'port' in connect: [info default connect port val]; val=$val"

puts "\n=== Renaming Procedures ==="
proc original_func {} {
    return "I am the original"
}
rename original_func new_func
puts [new_func]

puts "\n=== Lambda-like with apply ==="
set square [list x {expr {$x * $x}}]
puts "5 squared: [apply $square 5]"
puts "12 squared: [apply $square 12]"

set make_adder [list n {
    list x [format {expr {$x + %d}} $n]
}]
set add5 [apply $make_adder 5]
puts "add5(10): [apply $add5 10]"
puts "add5(20): [apply $add5 20]"
