# 14. Event-Driven Programming

Tcl has a built-in event loop that supports timers, I/O events, and coroutines — making it well-suited for network servers, GUIs, and asynchronous programming.

## The Event Loop

Tcl's event loop processes events from various sources. You enter the event loop with `vwait` or (in Tk) `tkwait`:

```tcl
# vwait blocks until the named variable is modified
set done 0

after 2000 {
    puts "2 seconds elapsed"
    set done 1
}

puts "Waiting..."
vwait done
puts "Done!"
```

## Timer Events with `after`

### One-Shot Timer

```tcl
# Schedule a command to run after N milliseconds
after 1000 { puts "1 second later" }
after 2000 { puts "2 seconds later" }
after 3000 { set done 1 }

set done 0
vwait done
```

### Repeating Timer

```tcl
proc tick {} {
    puts "Tick: [clock format [clock seconds] -format %H:%M:%S]"
    after 1000 tick   ;# Reschedule
}

tick
set forever 0
vwait forever   ;# Runs indefinitely
```

### Canceling Timers

```tcl
set id [after 5000 { puts "This won't run" }]
after cancel $id

# Cancel by command
after cancel { puts "This won't run either" }

# List pending timers
puts [after info]
```

### Debounce Pattern

```tcl
proc debounce {delay script} {
    variable debounce_id
    if {[info exists debounce_id]} {
        after cancel $debounce_id
    }
    set debounce_id [after $delay $script]
}

# Only the last call within 500ms executes
debounce 500 { puts "Search: hello" }
debounce 500 { puts "Search: hello w" }
debounce 500 { puts "Search: hello wo" }
debounce 500 { puts "Search: hello world" }
# Only "Search: hello world" prints
```

## File Events with `fileevent`

`fileevent` lets you react to I/O readiness on channels without blocking:

```tcl
# Non-blocking stdin reading
fconfigure stdin -blocking 0 -buffering line

fileevent stdin readable {
    if {[gets stdin line] >= 0} {
        puts "You typed: $line"
        if {$line eq "quit"} {
            set done 1
        }
    } elseif {[eof stdin]} {
        set done 1
    }
}

set done 0
vwait done
```

## TCP Networking

### Simple TCP Server

```tcl
proc accept {chan addr port} {
    puts "Connection from $addr:$port"
    fconfigure $chan -buffering line -blocking 0
    fileevent $chan readable [list handle_client $chan $addr]
}

proc handle_client {chan addr} {
    if {[gets $chan line] >= 0} {
        puts "From $addr: $line"
        puts $chan "Echo: $line"
        if {$line eq "quit"} {
            puts "Client $addr disconnected"
            close $chan
        }
    } elseif {[eof $chan]} {
        puts "Client $addr disconnected (EOF)"
        close $chan
    }
}

set server [socket -server accept 9000]
puts "Server listening on port 9000"

vwait forever
```

### TCP Client

```tcl
proc connect {host port} {
    set sock [socket $host $port]
    fconfigure $sock -buffering line -blocking 0
    return $sock
}

set sock [connect "localhost" 9000]
puts $sock "Hello, server!"
flush $sock
gets $sock response
puts "Server said: $response"
close $sock
```

### Async TCP Client

```tcl
proc async_connect {host port callback} {
    set sock [socket -async $host $port]
    fconfigure $sock -buffering line -blocking 0
    fileevent $sock writable [list on_connected $sock $callback]
}

proc on_connected {sock callback} {
    fileevent $sock writable {}
    set err [fconfigure $sock -error]
    if {$err ne ""} {
        {*}$callback error $err
    } else {
        {*}$callback connected $sock
    }
}

proc on_connect_result {status data} {
    if {$status eq "connected"} {
        puts "Connected! Socket: $data"
    } else {
        puts "Connection failed: $data"
    }
    set ::done 1
}

async_connect "localhost" 9000 on_connect_result
set done 0
vwait done
```

## Coroutines (Tcl 8.6+)

Coroutines allow cooperative multitasking — a procedure can yield control and be resumed later:

### Basic Coroutine

```tcl
proc counter_body {} {
    set i 0
    while {1} {
        yield $i
        incr i
    }
}

coroutine counter counter_body

puts [counter]   ;# → 0
puts [counter]   ;# → 1
puts [counter]   ;# → 2
puts [counter]   ;# → 3
```

### Generator Pattern

```tcl
proc fibonacci_gen {} {
    set a 0
    set b 1
    yield
    while {1} {
        yield $a
        lassign [list $b [expr {$a + $b}]] a b
    }
}

coroutine fib fibonacci_gen

for {set i 0} {$i < 10} {incr i} {
    puts "fib($i) = [fib]"
}
# Output: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34
```

### Range Generator

```tcl
proc range_gen {start end {step 1}} {
    yield
    for {set i $start} {$i < $end} {incr i $step} {
        yield $i
    }
    return -code break
}

coroutine rng range_gen 0 10 2
while {![catch {rng} val]} {
    puts $val
}
# Output: 0 2 4 6 8
```

### Coroutine-Based Async I/O

```tcl
proc async_read {chan} {
    fileevent $chan readable [info coroutine]
    yield
    fileevent $chan readable {}
    return [gets $chan]
}

proc async_sleep {ms} {
    after $ms [info coroutine]
    yield
}

proc worker {} {
    yield
    puts "Worker started"
    async_sleep 1000
    puts "After 1 second delay"
    async_sleep 2000
    puts "After 2 more seconds"
    set ::done 1
}

coroutine task worker
task

set done 0
vwait done
```

## Practical Example: Simple HTTP Server

```tcl
proc http_server {port} {
    socket -server http_accept $port
    puts "HTTP server on port $port"
}

proc http_accept {chan addr port} {
    fconfigure $chan -buffering line -blocking 0 -translation crlf
    fileevent $chan readable [list http_handle $chan $addr]
}

proc http_handle {chan addr} {
    if {[gets $chan line] < 0} {
        if {[eof $chan]} { close $chan }
        return
    }

    if {[regexp {^(GET|POST)\s+(\S+)\s+HTTP/} $line -> method path]} {
        while {[gets $chan header] > 0} {}

        set body ""
        switch $path {
            "/" {
                set body "<html><body><h1>Hello from Tcl!</h1>"
                append body "<p>Time: [clock format [clock seconds]]</p>"
                append body "<p>Your IP: $addr</p></body></html>"
            }
            "/api/time" {
                set body "{\"time\": \"[clock format [clock seconds] -format %Y-%m-%dT%H:%M:%S]\"}"
            }
            default {
                set status "404 Not Found"
                set body "<html><body><h1>404 Not Found</h1></body></html>"
            }
        }

        if {![info exists status]} {
            set status "200 OK"
        }

        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: text/html"
        puts $chan "Content-Length: [string length $body]"
        puts $chan "Connection: close"
        puts $chan ""
        puts -nonewline $chan $body
    }

    close $chan
}

http_server 8080
vwait forever
```

## Practical Example: Task Scheduler

```tcl
namespace eval scheduler {
    variable tasks {}
    variable running true

    proc schedule {name interval_ms command} {
        variable tasks
        dict set tasks $name [dict create \
            interval $interval_ms \
            command $command \
            runs 0 \
            last_run 0]
        run_task $name
    }

    proc run_task {name} {
        variable tasks
        variable running
        if {!$running} return
        if {![dict exists $tasks $name]} return

        set task [dict get $tasks $name]
        set cmd [dict get $task command]

        if {[catch {uplevel #0 $cmd} result]} {
            puts "Task '$name' error: $result"
        }

        dict set tasks $name runs [expr {[dict get $task runs] + 1}]
        dict set tasks $name last_run [clock seconds]

        set interval [dict get $task interval]
        after $interval [list ::scheduler::run_task $name]
    }

    proc cancel {name} {
        variable tasks
        dict unset tasks $name
    }

    proc stop {} {
        variable running
        set running false
    }

    proc status {} {
        variable tasks
        puts [format "%-15s %10s %6s %s" "Task" "Interval" "Runs" "Last Run"]
        puts [string repeat "-" 55]
        dict for {name task} $tasks {
            set last [dict get $task last_run]
            set last_str [expr {$last > 0 ? [clock format $last -format %H:%M:%S] : "never"}]
            puts [format "%-15s %8dms %6d %s" \
                $name [dict get $task interval] \
                [dict get $task runs] $last_str]
        }
    }
}

# Usage:
# scheduler::schedule "heartbeat" 5000 { puts "♥ alive" }
# scheduler::schedule "cleanup" 60000 { puts "Cleaning temp files..." }
# scheduler::status
# vwait forever
```

## Practical Example: Promise-Like Async

```tcl
oo::class create Promise {
    variable state value callbacks

    constructor {executor} {
        set state "pending"
        set value ""
        set callbacks {}

        set resolve [list [self] _resolve]
        set reject [list [self] _reject]

        if {[catch {{*}$executor $resolve $reject} err]} {
            my _reject $err
        }
    }

    method _resolve {val} {
        if {$state ne "pending"} return
        set state "fulfilled"
        set value $val
        my _run_callbacks
    }

    method _reject {err} {
        if {$state ne "pending"} return
        set state "rejected"
        set value $err
        my _run_callbacks
    }

    method then {on_fulfilled {on_rejected ""}} {
        lappend callbacks [list $on_fulfilled $on_rejected]
        if {$state ne "pending"} {
            my _run_callbacks
        }
        return [self]
    }

    method _run_callbacks {} {
        foreach cb $callbacks {
            lassign $cb on_ok on_err
            after 0 [list apply [list {} [subst {
                if {"$state" eq "fulfilled" && "$on_ok" ne ""} {
                    $on_ok {$value}
                } elseif {"$state" eq "rejected" && "$on_err" ne ""} {
                    $on_err {$value}
                }
            }]]]
        }
        set callbacks {}
    }
}

# Usage:
# set p [Promise new {resolve reject} {
#     after 1000 [list {*}$resolve "Hello from the future!"]
# }]
# $p then {msg { puts "Resolved: $msg" }} {err { puts "Error: $err" }}
```

---

**Previous:** [Namespaces & Packages](12-namespaces-and-packages.md)

---

**Back to:** [Table of Contents](../README.md)
