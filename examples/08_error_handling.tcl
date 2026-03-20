#!/usr/bin/env tclsh
#
# 08_error_handling.tcl — Demonstrates error handling techniques
#

puts "=============================="
puts " Error Handling Demo"
puts "=============================="
puts ""

# --- Basic catch ---
puts "--- Basic catch ---"

if {[catch {expr {10 / 0}} result]} {
    puts "Caught error: $result"
} else {
    puts "Result: $result"
}

if {[catch {expr {10 / 3}} result]} {
    puts "Caught error: $result"
} else {
    puts "Result: $result"
}
puts ""

# --- try / on error / finally ---
puts "--- try / on error / finally ---"

proc divide {a b} {
    try {
        set result [expr {double($a) / $b}]
        if {$b == 0} {
            error "Division by zero"
        }
        return $result
    } on error {msg opts} {
        puts "  Error: $msg"
        return "NaN"
    } finally {
        puts "  (cleanup for divide $a / $b)"
    }
}

puts "10 / 3 = [divide 10 3]"
puts "10 / 0 = [divide 10 0]"
puts ""

# --- Custom Error Codes with throw/trap ---
puts "--- Custom Error Codes with throw/trap ---"

proc validate_user {username password} {
    if {$username eq ""} {
        throw {VALIDATION EMPTY_USERNAME} "Username cannot be empty"
    }
    if {[string length $password] < 8} {
        throw {VALIDATION WEAK_PASSWORD} "Password must be at least 8 characters"
    }
    if {![regexp {[A-Z]} $password]} {
        throw {VALIDATION WEAK_PASSWORD} "Password must contain an uppercase letter"
    }
    if {![regexp {\d} $password]} {
        throw {VALIDATION WEAK_PASSWORD} "Password must contain a digit"
    }
    return "User '$username' validated successfully"
}

foreach {user pass} [list "" "abc" "alice" "short" "bob" "longpassword" "carol" "GoodPass1"] {
    try {
        puts "  [validate_user $user $pass]"
    } trap {VALIDATION EMPTY_USERNAME} {msg} {
        puts "  Username error: $msg"
    } trap {VALIDATION WEAK_PASSWORD} {msg} {
        puts "  Password error ($user): $msg"
    } on error {msg} {
        puts "  Unexpected error: $msg"
    }
}
puts ""

# --- Retry Pattern ---
puts "--- Retry Pattern ---"

proc unreliable_operation {} {
    set chance [expr {int(rand() * 3)}]
    if {$chance != 0} {
        error "Random failure (chance=$chance)"
    }
    return "Success!"
}

proc retry {max_attempts delay_ms command} {
    for {set attempt 1} {$attempt <= $max_attempts} {incr attempt} {
        try {
            set result [uplevel 1 $command]
            puts "  Attempt $attempt: $result"
            return $result
        } on error {msg} {
            puts "  Attempt $attempt failed: $msg"
            if {$attempt < $max_attempts} {
                after $delay_ms
            }
        }
    }
    error "All $max_attempts attempts failed"
}

expr {srand(42)}
try {
    retry 5 100 unreliable_operation
} on error {msg} {
    puts "  Final: $msg"
}
puts ""

# --- Error Context and Stack Traces ---
puts "--- Error Context ---"

proc level_3 {} {
    error "Something went wrong deep inside"
}

proc level_2 {} {
    level_3
}

proc level_1 {} {
    level_2
}

try {
    level_1
} on error {msg opts} {
    puts "Error message: $msg"
    puts ""
    puts "Error info (stack trace):"
    set stack [dict get $opts -errorinfo]
    foreach line [split $stack "\n"] {
        puts "  $line"
    }
    puts ""
    puts "Error code: [dict get $opts -errorcode]"
}
puts ""

# --- Resource Guard Pattern ---
puts "--- Resource Guard Pattern ---"

proc with_temp_file {varName body} {
    upvar 1 $varName filepath
    set filepath [file join "/tmp" "tcl_temp_[pid]_[clock microseconds].tmp"]

    set fp [open $filepath w]
    puts $fp "temporary data"
    close $fp

    try {
        uplevel 1 $body
    } finally {
        if {[file exists $filepath]} {
            file delete $filepath
            puts "  (Cleaned up temp file: [file tail $filepath])"
        }
    }
}

with_temp_file tmpfile {
    puts "  Temp file created: $tmpfile"
    puts "  File exists: [file exists $tmpfile]"
    puts "  Content: [string trim [read [set f [open $tmpfile r]]]][close $f]"
}
puts ""

# --- Assertion Utility ---
puts "--- Assertions ---"

proc assert {condition {message ""}} {
    if {![uplevel 1 [list expr $condition]]} {
        if {$message eq ""} {
            set message "Assertion failed: $condition"
        }
        error $message
    }
}

try {
    set x 42
    assert {$x > 0} "x must be positive"
    puts "  Assertion passed: x > 0"

    assert {$x == 42}
    puts "  Assertion passed: x == 42"

    assert {$x < 0} "x must be negative"
} on error {msg} {
    puts "  Assertion failed: $msg"
}
puts ""

puts "Done!"
