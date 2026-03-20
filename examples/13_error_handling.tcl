#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 13: Error Handling
# =============================================================================

puts "=== catch — Basic Error Handling ==="
if {[catch {expr {10 / 0}} result]} {
    puts "Caught error: $result"
} else {
    puts "Result: $result"
}

if {[catch {expr {10 / 2}} result]} {
    puts "Error: $result"
} else {
    puts "Success: $result"
}

puts "\n=== catch with Options Dict ==="
if {[catch {expr {10 / 0}} result opts]} {
    puts "Error message: $result"
    puts "Error code: [dict get $opts -errorcode]"
    puts "Error level: [dict get $opts -level]"
}

puts "\n=== try / on / finally (Tcl 8.6+) ==="
try {
    set result [expr {100 / 5}]
    puts "try result: $result"
} on error {msg opts} {
    puts "Error: $msg"
} finally {
    puts "finally block always runs"
}

puts ""
try {
    set result [expr {100 / 0}]
    puts "This won't be reached"
} on error {msg} {
    puts "Caught in try: $msg"
} finally {
    puts "Cleanup in finally"
}

puts "\n=== Raising Errors ==="
proc divide {a b} {
    if {$b == 0} {
        error "Division by zero: cannot divide $a by $b"
    }
    return [expr {double($a) / $b}]
}

if {[catch {divide 10 0} result]} {
    puts "Error from divide: $result"
}
puts "divide 10 3 = [divide 10 3]"

puts "\n=== Custom Error Codes ==="
proc validate_age {age} {
    if {![string is integer -strict $age]} {
        error "Age must be an integer, got '$age'" "" {VALIDATION TYPE_ERROR}
    }
    if {$age < 0 || $age > 150} {
        error "Age must be 0-150, got '$age'" "" {VALIDATION RANGE_ERROR}
    }
    return $age
}

foreach test_age {"25" "abc" "-5" "200" "42"} {
    if {[catch {validate_age $test_age} result opts]} {
        set code [dict get $opts -errorcode]
        puts "  validate_age($test_age): FAIL — $result (code: $code)"
    } else {
        puts "  validate_age($test_age): OK — $result"
    }
}

puts "\n=== throw and trap (Tcl 8.6+) ==="
proc parse_config {text} {
    if {[string trim $text] eq ""} {
        throw {CONFIG EMPTY} "Configuration text is empty"
    }
    if {![regexp {=} $text]} {
        throw {CONFIG SYNTAX} "No key=value pairs found"
    }
    set result [dict create]
    foreach line [split $text "\n"] {
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} continue
        if {[regexp {^(\w+)\s*=\s*(.*)$} $line _ key value]} {
            dict set result $key $value
        } else {
            throw {CONFIG SYNTAX} "Invalid line: $line"
        }
    }
    return $result
}

try {
    parse_config ""
} trap {CONFIG EMPTY} {msg} {
    puts "Empty config: $msg"
} trap {CONFIG SYNTAX} {msg} {
    puts "Syntax error: $msg"
}

try {
    parse_config "no equals sign here"
} trap {CONFIG EMPTY} {msg} {
    puts "Empty: $msg"
} trap {CONFIG SYNTAX} {msg} {
    puts "Syntax error: $msg"
}

try {
    set cfg [parse_config "host = localhost\nport = 8080\ndebug = true"]
    puts "Parsed config: $cfg"
} trap {CONFIG} {msg} {
    puts "Config error: $msg"
}

puts "\n=== Error Stack Trace ==="
proc level3 {} { error "Something went wrong at level 3" }
proc level2 {} { level3 }
proc level1 {} { level2 }

if {[catch {level1} result opts]} {
    puts "Error: $result"
    puts "\nStack trace:"
    puts [dict get $opts -errorinfo]
}

puts "\n=== Practical: Safe File Reader ==="
proc safe_read_file {filepath} {
    if {![file exists $filepath]} {
        error "File not found: $filepath" "" {FILE NOT_FOUND}
    }
    if {![file readable $filepath]} {
        error "File not readable: $filepath" "" {FILE NOT_READABLE}
    }
    try {
        set fd [open $filepath r]
        set content [read $fd]
        return $content
    } on error {msg} {
        error "Failed to read $filepath: $msg" "" {FILE READ_ERROR}
    } finally {
        catch {close $fd}
    }
}

if {[catch {safe_read_file "/nonexistent/file.txt"} result opts]} {
    puts "Safe read error: $result"
    puts "Error code: [dict get $opts -errorcode]"
}

puts "\n=== Practical: Retry Logic ==="
proc unreliable_operation {fail_count_var} {
    upvar 1 $fail_count_var fails
    incr fails
    if {$fails <= 3} {
        error "Transient error (attempt $fails)"
    }
    return "Success on attempt $fails"
}

proc with_retry {max_retries body} {
    for {set attempt 1} {$attempt <= $max_retries} {incr attempt} {
        if {![catch {set result [uplevel 1 $body]}]} {
            return $result
        }
        puts "  Retry $attempt/$max_retries..."
    }
    error "All $max_retries attempts failed"
}

set failures 0
try {
    set result [with_retry 5 {unreliable_operation failures}]
    puts "Operation result: $result"
} on error {msg} {
    puts "Gave up: $msg"
}
