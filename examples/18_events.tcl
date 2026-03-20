#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 18: Event-Driven Programming
# =============================================================================

puts "=== Variable Traces ==="
puts "--- Write trace ---"
proc on_write {name1 name2 op} {
    upvar 1 $name1 var
    puts "  TRACE: '$name1' was written, new value: $var"
}

trace add variable watched_var write on_write
set watched_var 10
set watched_var 20
set watched_var 30
trace remove variable watched_var write on_write

puts "\n--- Read trace ---"
set access_count 0
proc on_read {name1 name2 op} {
    global access_count
    incr access_count
}

trace add variable config_value read on_read
set config_value "important_setting"
puts "Value: $config_value"
puts "Value again: $config_value"
puts "Value once more: $config_value"
trace remove variable config_value read on_read
puts "config_value was read $access_count times"

puts "\n--- Unset trace ---"
proc on_unset {name1 name2 op} {
    puts "  TRACE: '$name1' is being unset"
}

trace add variable temp_var unset on_unset
set temp_var "will be deleted"
unset temp_var

puts "\n=== Validated Variable (using write trace) ==="
proc validate_positive {name1 name2 op} {
    upvar 1 $name1 var
    if {![string is integer -strict $var] || $var < 0} {
        set old_val $var
        set var 0
        puts "  VALIDATE: Rejected '$old_val', reset to 0"
    }
}

trace add variable positive_int write validate_positive
set positive_int 42
puts "Set to 42: $positive_int"
set positive_int -5
puts "Set to -5: $positive_int"
set positive_int "abc"
puts "Set to 'abc': $positive_int"
set positive_int 100
puts "Set to 100: $positive_int"
trace remove variable positive_int write validate_positive

puts "\n=== Command Traces ==="
proc my_important_proc {x} {
    return [expr {$x * $x}]
}

proc on_enter {cmd op} {
    puts "  ENTER: $cmd"
}

proc on_leave {cmd code result op} {
    puts "  LEAVE: result=$result (code=$code)"
}

trace add execution my_important_proc enter on_enter
trace add execution my_important_proc leave on_leave
puts "Calling my_important_proc 7:"
set r [my_important_proc 7]
puts "Got: $r"
trace remove execution my_important_proc enter on_enter
trace remove execution my_important_proc leave on_leave

puts "\n=== after — Scheduled Execution (Demonstration) ==="
puts "after can schedule code to run after a delay."
puts "In a full event loop (vwait/Tk), these fire asynchronously."
puts ""

proc simulate_timer_callback {id} {
    puts "  Timer $id fired at [clock format [clock seconds] -format %H:%M:%S]"
}

puts "Simulating timer callbacks synchronously:"
foreach id {1 2 3} {
    simulate_timer_callback $id
}

puts "\n=== Event Loop Concepts ==="
puts {
  Tcl's event loop (entered via 'vwait' or Tk's mainloop) handles:

  1. Timer events      — after <ms> <script>
  2. File events       — fileevent <chan> readable/writable <script>
  3. Idle callbacks    — after idle <script>
  4. Variable events   — vwait <varName>

  The event loop is critical for:
  - GUI applications (Tk)
  - Socket servers
  - Non-blocking I/O
  - Periodic tasks
}

puts "=== Practical: Observable Pattern ==="
namespace eval Observable {
    variable listeners

    proc create {name} {
        variable listeners
        set listeners($name) {}
    }

    proc on {name event callback} {
        variable listeners
        dict lappend listeners($name) $event $callback
    }

    proc emit {name event args} {
        variable listeners
        if {![info exists listeners($name)]} return
        if {[dict exists $listeners($name) $event]} {
            foreach cb [dict get $listeners($name) $event] {
                {*}$cb {*}$args
            }
        }
    }
}

proc on_temp_change {temp} {
    puts "  Temperature changed to: $temp°C"
    if {$temp > 100} {
        puts "  WARNING: Temperature critical!"
    }
}

proc on_temp_log {temp} {
    puts "  LOG: temp=$temp recorded at [clock format [clock seconds] -format %H:%M:%S]"
}

Observable::create thermostat
Observable::on thermostat "change" on_temp_change
Observable::on thermostat "change" on_temp_log

puts "Emitting temperature changes:"
Observable::emit thermostat "change" 25
Observable::emit thermostat "change" 75
Observable::emit thermostat "change" 105
