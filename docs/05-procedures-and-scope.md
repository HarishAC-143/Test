# 5. Procedures & Scope

## Defining Procedures

Procedures are Tcl's equivalent of functions. Use `proc` to define them:

```tcl
proc greet {name} {
    puts "Hello, $name!"
}

greet "Alice"   ;# → Hello, Alice!
```

The general syntax is:

```tcl
proc procName {argList} {body}
```

## Return Values

Every procedure returns a value — either explicitly via `return` or implicitly (the result of the last command):

```tcl
proc add {a b} {
    return [expr {$a + $b}]
}

# Implicit return — same effect
proc add2 {a b} {
    expr {$a + $b}
}

puts [add 3 4]    ;# → 7
puts [add2 3 4]   ;# → 7
```

## Default Argument Values

```tcl
proc greet {name {greeting "Hello"}} {
    puts "$greeting, $name!"
}

greet "Alice"             ;# → Hello, Alice!
greet "Bob" "Good morning" ;# → Good morning, Bob!
```

## Variable-Length Arguments with `args`

The special parameter `args` captures all remaining arguments as a list:

```tcl
proc log {level args} {
    set message [join $args " "]
    puts "\[$level\] $message"
}

log INFO "Server started on port" 8080
# Output: [INFO] Server started on port 8080

log ERROR "File" "/tmp/data.txt" "not found"
# Output: [ERROR] File /tmp/data.txt not found
```

## Scope

Tcl has strict scoping rules. Variables defined inside a procedure are local; they do not see global variables unless explicitly told to:

```tcl
set x 100

proc show {} {
    # $x is NOT accessible here — it's in a different scope
    # puts $x   ;# ERROR: can't read "x": no such variable
}
```

### Accessing Global Variables with `global`

```tcl
set counter 0

proc increment {} {
    global counter
    incr counter
}

increment
increment
puts $counter   ;# → 2
```

### Accessing Caller's Variables with `upvar`

`upvar` creates a local alias for a variable in a calling scope:

```tcl
proc double_var {varName} {
    upvar 1 $varName var
    set var [expr {$var * 2}]
}

set x 5
double_var x
puts $x   ;# → 10
```

The `1` means "one level up" (the caller's scope). `#0` refers to the global scope.

### Accessing Caller's Scope with `uplevel`

`uplevel` executes a script in a calling scope:

```tcl
proc define_var {name value} {
    uplevel 1 [list set $name $value]
}

define_var greeting "hello"
puts $greeting   ;# → hello
```

## Recursion

```tcl
proc factorial {n} {
    if {$n <= 1} {
        return 1
    }
    return [expr {$n * [factorial [expr {$n - 1}]]}]
}

puts [factorial 10]   ;# → 3628800
```

### Tail-Call Optimization with `tailcall`

Tcl 8.6+ supports tail-call optimization:

```tcl
proc factorial_tail {n {acc 1}} {
    if {$n <= 1} {
        return $acc
    }
    tailcall factorial_tail [expr {$n - 1}] [expr {$n * $acc}]
}

puts [factorial_tail 20]   ;# → 2432902008176640000
```

## Renaming and Deleting Procedures

```tcl
proc hello {} { puts "Hello!" }

# Rename
rename hello greet
greet   ;# → Hello!

# Delete a procedure by renaming to empty string
rename greet ""
# greet   ;# ERROR: invalid command name "greet"
```

## Introspection

```tcl
proc example {a b {c 10}} {
    return [expr {$a + $b + $c}]
}

# Get argument list
puts [info args example]      ;# → a b c

# Get default value
info default example c defVal
puts $defVal                  ;# → 10

# Get procedure body
puts [info body example]

# List all procedures
puts [info procs]

# Check if procedure exists
if {[llength [info procs example]] > 0} {
    puts "example exists"
}
```

## Higher-Order Procedures

Procedures that take other procedures as arguments:

```tcl
proc apply_to_list {func lst} {
    set result {}
    foreach item $lst {
        lappend result [$func $item]
    }
    return $result
}

proc square {x} { expr {$x * $x} }
proc negate {x} { expr {-$x} }

puts [apply_to_list square {1 2 3 4 5}]
# → 1 4 9 16 25

puts [apply_to_list negate {1 2 3 4 5}]
# → -1 -2 -3 -4 -5
```

## Anonymous Procedures (Lambda)

Tcl 8.5+ supports anonymous procedures via `apply`:

```tcl
set square [list {x} {expr {$x * $x}}]
puts [apply $square 5]   ;# → 25

# With a namespace
set greet [list {name} {return "Hello, $name!"} ::]
puts [apply $greet "World"]   ;# → Hello, World!

# Inline usage
set nums {3 1 4 1 5 9 2 6}
set sorted [lsort -command [list apply {{a b} {
    expr {$a - $b}
}}] $nums]
puts $sorted   ;# → 1 1 2 3 4 5 6 9
```

## Practical Example: Memoization

```tcl
proc memoize {func} {
    set wrapper "memoized_$func"
    proc $wrapper {args} [format {
        variable cache_%s
        set key $args
        if {[info exists cache_%s($key)]} {
            return $cache_%s($key)
        }
        set result [%s {*}$args]
        set cache_%s($key) $result
        return $result
    } $func $func $func $func $func]
    return $wrapper
}

proc slow_fibonacci {n} {
    if {$n <= 1} { return $n }
    return [expr {[memo_fib [expr {$n-1}]] + [memo_fib [expr {$n-2}]]}]
}

# A cleaner recursive Fibonacci with manual memoization
proc fib {n} {
    variable fib_cache
    if {$n <= 1} { return $n }
    if {[info exists fib_cache($n)]} { return $fib_cache($n) }
    set result [expr {[fib [expr {$n-1}]] + [fib [expr {$n-2}]]}]
    set fib_cache($n) $result
    return $result
}

puts [fib 30]   ;# → 832040 (fast with memoization)
```

## Practical Example: Command Dispatcher

```tcl
proc dispatcher {cmd args} {
    set handler "handle_$cmd"
    if {[llength [info procs $handler]] == 0} {
        error "Unknown command: $cmd"
    }
    return [$handler {*}$args]
}

proc handle_add {a b} { expr {$a + $b} }
proc handle_mul {a b} { expr {$a * $b} }
proc handle_greet {name} { return "Hello, $name!" }

puts [dispatcher add 3 4]       ;# → 7
puts [dispatcher greet "Tcl"]   ;# → Hello, Tcl!
```

---

**Previous:** [Control Flow](04-control-flow.md) | **Next:** [String Operations](06-string-operations.md)
