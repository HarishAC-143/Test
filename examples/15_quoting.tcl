#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 15: Command Substitution and Quoting
# =============================================================================

set x 10
set name "Alice"

puts "=== Double Quotes — Substitution Happens ==="
puts "x = $x"
puts "2 + 2 = [expr {2 + 2}]"
puts "Hello, $name! You are [expr {$x * 3}] in dog years."
puts "A tab:\there. A newline follows:"
puts "Line 1\nLine 2"

puts "\n=== Braces — No Substitution ==="
puts {x = $x}
puts {2 + 2 = [expr {2 + 2}]}
puts {Braces preserve $everything \literally}

puts "\n=== Why Braces Matter for expr ==="
set a 5
set b 3
puts "Braced: [expr {$a + $b}]"
puts "Quoted: [expr "$a + $b"]"
# Both produce 8, but braced is faster and safer.
# Braced expr is compiled once; unbraced is re-parsed each time.

puts "\n=== Backslash Substitution ==="
puts "Newline: line1\nline2"
puts "Tab: col1\tcol2"
puts "Backslash: \\"
puts "Dollar sign: \$x (literal, not variable)"
puts "Bracket: \[not a command\]"
puts "Unicode: \u0041\u0042\u0043"

puts "\n=== Command as Variable ==="
set cmd "puts"
set arg "Hello from a dynamic command!"
$cmd $arg

set op "expr"
puts "Dynamic expr: [$op {3 * 7}]"

puts "\n=== list Command — Safe Quoting ==="
set userInput {some "tricky" input with $vars and [commands]}
set safe [list puts $userInput]
puts "Safe list representation: $safe"
eval $safe

puts "\n=== Expansion Operator {*} (Tcl 8.5+) ==="
proc sum3 {a b c} {
    expr {$a + $b + $c}
}

set args {10 20 30}
puts "sum3 with expansion: [sum3 {*}$args]"

set options [list -nocase -all -inline]
set result [lsearch {*}$options {apple BANANA cherry} "*a*"]
puts "Search with expanded options: $result"

puts "\n=== eval vs {*} ==="
set cmd_parts [list string length "Hello, World!"]
puts "Using eval: [eval $cmd_parts]"
puts "Using {*}: [string length {*}{Hello, World!}]"

puts "\n=== uplevel — Execute in Caller's Scope ==="
proc with_timing {description body} {
    set start [clock microseconds]
    uplevel 1 $body
    set elapsed [expr {[clock microseconds] - $start}]
    puts "  $description took $elapsed microseconds"
}

with_timing "String operations" {
    set result ""
    for {set i 0} {$i < 1000} {incr i} {
        append result "x"
    }
}

with_timing "List operations" {
    set result {}
    for {set i 0} {$i < 1000} {incr i} {
        lappend result $i
    }
}

puts "\n=== upvar — Bind to Caller's Variable ==="
proc push {stackVar value} {
    upvar 1 $stackVar stack
    lappend stack $value
}

proc pop {stackVar} {
    upvar 1 $stackVar stack
    set top [lindex $stack end]
    set stack [lrange $stack 0 end-1]
    return $top
}

set myStack {}
push myStack "first"
push myStack "second"
push myStack "third"
puts "Stack: $myStack"
puts "Popped: [pop myStack]"
puts "Popped: [pop myStack]"
puts "Stack now: $myStack"

puts "\n=== Quoting Summary ==="
puts {
  +------------------+-----------------------------------+
  | Syntax           | Behavior                          |
  +------------------+-----------------------------------+
  | "double quotes"  | $var and [cmd] are substituted    |
  | {braces}         | Everything is literal             |
  | \backslash       | Escape single characters          |
  | $var             | Variable substitution             |
  | [cmd]            | Command substitution              |
  | {*}list          | Expand list into separate words   |
  +------------------+-----------------------------------+
}
