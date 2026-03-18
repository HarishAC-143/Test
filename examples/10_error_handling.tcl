#!/usr/bin/env tclsh
# =============================================================================
# Example 10: Error Handling
# Demonstrates: catch, try/on/trap, error, return -code error, custom errors
# =============================================================================

puts "=== Error Handling ===\n"

# --- catch (traditional) ---
puts "--- catch (Traditional Style) ---"

# Division by zero
if {[catch {expr {10 / 0}} result]} {
    puts "  Caught error: $result"
} else {
    puts "  Result: $result"
}

# Undefined variable
if {[catch {set val $undefined_var} result]} {
    puts "  Caught error: $result"
}

# Successful operation
if {[catch {expr {10 + 20}} result]} {
    puts "  Error: $result"
} else {
    puts "  Success: $result"
}

# catch with options
if {[catch {open "/nonexistent/path/file.txt" r} result options]} {
    puts "  Error: $result"
    puts "  Error code: [dict get $options -errorcode]"
}

# --- try / on / trap / finally (modern, Tcl 8.6+) ---
puts "\n--- try / on / trap / finally ---"

# Basic try/on error
try {
    set x [expr {100 / 0}]
} on error {msg opts} {
    puts "  Error caught: $msg"
} finally {
    puts "  Finally block executed (cleanup happens here)"
}

# try with trap for specific error codes
proc safe_divide {a b} {
    if {![string is double -strict $a] || ![string is double -strict $b]} {
        return -code error -errorcode {MATH BADTYPE} \
            "Arguments must be numbers: got '$a' and '$b'"
    }
    if {$b == 0} {
        return -code error -errorcode {MATH DIVZERO} \
            "Division by zero: $a / $b"
    }
    return [expr {double($a) / $b}]
}

puts "\n  Safe division examples:"
foreach {a b} {10 3 10 0 "abc" 5 100 7} {
    try {
        set result [safe_divide $a $b]
        puts [format "    %s / %s = %.4f" $a $b $result]
    } trap {MATH DIVZERO} {msg} {
        puts "    $a / $b -> Division by zero!"
    } trap {MATH BADTYPE} {msg} {
        puts "    $a / $b -> Bad input: $msg"
    } on error {msg} {
        puts "    $a / $b -> Other error: $msg"
    }
}

# --- Custom error with error command ---
puts "\n--- Custom Errors ---"

proc validate_age {age} {
    if {![string is integer -strict $age]} {
        error "Age must be an integer, got '$age'" "" {VALIDATION TYPE}
    }
    if {$age < 0 || $age > 150} {
        error "Age must be between 0 and 150, got $age" "" {VALIDATION RANGE}
    }
    return $age
}

foreach test_age {25 -5 200 "abc" 65} {
    try {
        set valid [validate_age $test_age]
        puts "  Age '$test_age' -> Valid: $valid"
    } trap {VALIDATION TYPE} {msg} {
        puts "  Age '$test_age' -> Type error: $msg"
    } trap {VALIDATION RANGE} {msg} {
        puts "  Age '$test_age' -> Range error: $msg"
    }
}

# --- Error propagation and stack traces ---
puts "\n--- Error Propagation ---"

proc level3 {} {
    error "Something went wrong deep inside" "" {APP INTERNAL}
}

proc level2 {} {
    level3
}

proc level1 {} {
    level2
}

try {
    level1
} on error {msg opts} {
    puts "  Error: $msg"
    puts "  Code: [dict get $opts -errorcode]"
    puts "  Stack trace (first 3 lines):"
    set trace [dict get $opts -errorinfo]
    set lines [split $trace "\n"]
    for {set i 0} {$i < 3 && $i < [llength $lines]} {incr i} {
        puts "    [lindex $lines $i]"
    }
}

# --- Retry pattern ---
puts "\n--- Retry Pattern ---"

set ::attempt_counter 0

proc unreliable_operation {} {
    global attempt_counter
    incr attempt_counter
    if {$attempt_counter < 3} {
        error "Temporary failure (attempt $attempt_counter)"
    }
    return "Success on attempt $attempt_counter"
}

proc retry {command max_retries} {
    for {set i 1} {$i <= $max_retries} {incr i} {
        try {
            set result [uplevel 1 $command]
            return $result
        } on error {msg} {
            puts "  Attempt $i failed: $msg"
            if {$i == $max_retries} {
                error "All $max_retries attempts failed. Last error: $msg"
            }
        }
    }
}

set ::attempt_counter 0
try {
    set result [retry unreliable_operation 5]
    puts "  Result: $result"
} on error {msg} {
    puts "  Final failure: $msg"
}

# --- Resource cleanup pattern ---
puts "\n--- Resource Cleanup (RAII-style) ---"

proc process_file {filename} {
    set tmpfile "/tmp/tcl_error_demo_[pid].tmp"

    # Create a temp file for the demo
    set fp [open $tmpfile w]
    puts $fp "test data"
    close $fp

    try {
        set fp [open $tmpfile r]
        try {
            set data [read $fp]
            puts "  Read [string length $data] bytes from temp file"
        } finally {
            close $fp
            puts "  File handle closed (in finally)"
        }
    } finally {
        file delete -force $tmpfile
        puts "  Temp file cleaned up (in outer finally)"
    }
}

process_file "test"

puts "\nDone."
