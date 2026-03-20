# 11. Error Handling

Robust error handling is critical for production-quality scripts. Tcl provides several mechanisms for catching, raising, and managing errors.

## The `catch` Command

`catch` executes a script and captures any error, returning 0 for success or 1 for error:

```tcl
# Basic usage
if {[catch {expr {1/0}} result]} {
    puts "Error: $result"
} else {
    puts "Result: $result"
}
# Output: Error: divide by zero
```

### Capturing Error Information

```tcl
if {[catch {open "nonexistent.txt" r} result options]} {
    puts "Error message: $result"
    puts "Error code: [dict get $options -errorcode]"
    puts "Error info: [dict get $options -errorinfo]"
}
```

### Return Codes

`catch` returns the Tcl return code:

| Code | Meaning | Constant |
|------|---------|----------|
| 0 | Success (TCL_OK) | `ok` |
| 1 | Error (TCL_ERROR) | `error` |
| 2 | Return (TCL_RETURN) | `return` |
| 3 | Break (TCL_BREAK) | `break` |
| 4 | Continue (TCL_CONTINUE) | `continue` |

```tcl
set code [catch {
    set f [open "file.txt" r]
    set data [read $f]
    close $f
} result options]

switch $code {
    0 { puts "Success: read [string length $result] chars" }
    1 { puts "Error: $result" }
}
```

## The `try` Command (Tcl 8.6+)

`try` is a more structured and readable approach to error handling:

```tcl
try {
    set f [open "data.txt" r]
    set contents [read $f]
    close $f
    puts "Read [string length $contents] characters"
} on error {msg options} {
    puts "Failed to read file: $msg"
}
```

### Try with Finally

`finally` runs cleanup code regardless of success or failure:

```tcl
set f [open "data.txt" r]
try {
    set contents [read $f]
    # Process the data...
} on error {msg} {
    puts "Error processing file: $msg"
} finally {
    close $f
    puts "File handle closed"
}
```

### Try with Multiple Handlers

```tcl
try {
    set result [some_operation]
} trap {POSIX ENOENT} {msg} {
    puts "File not found: $msg"
} trap {POSIX EACCES} {msg} {
    puts "Permission denied: $msg"
} trap {ARITH DIVZERO} {msg} {
    puts "Division by zero: $msg"
} on error {msg options} {
    puts "Unexpected error: $msg"
} on ok {result} {
    puts "Success: $result"
} finally {
    puts "Cleanup done"
}
```

## Raising Errors

### The `error` Command

```tcl
proc divide {a b} {
    if {$b == 0} {
        error "Division by zero" "" {ARITH DIVZERO}
    }
    return [expr {double($a) / $b}]
}

try {
    puts [divide 10 0]
} trap {ARITH DIVZERO} {msg} {
    puts "Caught: $msg"
}
```

`error` takes three arguments:
1. The error message
2. Error info (stack trace supplement, usually empty)
3. Error code (a list used for programmatic matching)

### The `throw` Command (Tcl 8.6+)

`throw` is a cleaner alternative to `error` for typed errors:

```tcl
proc validate_age {age} {
    if {![string is integer -strict $age]} {
        throw {VALIDATION TYPE} "Age must be an integer"
    }
    if {$age < 0 || $age > 150} {
        throw {VALIDATION RANGE} "Age must be between 0 and 150"
    }
    return $age
}

try {
    validate_age "abc"
} trap {VALIDATION TYPE} {msg} {
    puts "Type error: $msg"
} trap {VALIDATION RANGE} {msg} {
    puts "Range error: $msg"
}
```

### The `return -code error` Pattern

Used inside procedures for structured error returns:

```tcl
proc parse_int {str} {
    if {![string is integer -strict $str]} {
        return -code error -errorcode {PARSE INT} \
            "Cannot parse '$str' as integer"
    }
    return $str
}
```

## Error Codes and `trap`

Error codes are lists, and `trap` matches by prefix:

```tcl
# This handler catches {APP DB} and {APP DB TIMEOUT} and {APP DB CONNECT}
try {
    throw {APP DB TIMEOUT} "Database connection timed out"
} trap {APP DB} {msg} {
    puts "Database error: $msg"
} trap {APP} {msg} {
    puts "Application error: $msg"
}
# Output: Database error: Database connection timed out
```

## Custom Exception Hierarchy

```tcl
namespace eval AppError {
    proc file_not_found {path} {
        throw {APP FILE NOTFOUND} "File not found: $path"
    }

    proc permission_denied {path} {
        throw {APP FILE PERMISSION} "Permission denied: $path"
    }

    proc invalid_input {field reason} {
        throw {APP INPUT INVALID} "Invalid '$field': $reason"
    }

    proc timeout {operation seconds} {
        throw {APP TIMEOUT} "$operation timed out after ${seconds}s"
    }
}

try {
    AppError::file_not_found "/etc/secret.conf"
} trap {APP FILE} {msg} {
    puts "File error: $msg"
} trap {APP} {msg} {
    puts "App error: $msg"
}
```

## Stack Traces and Debugging

```tcl
proc inner {} {
    error "Something went wrong"
}

proc middle {} {
    inner
}

proc outer {} {
    middle
}

if {[catch {outer} msg options]} {
    puts "Error: $msg"
    puts "\nStack trace:"
    puts [dict get $options -errorinfo]
}
# Output:
# Error: Something went wrong
#
# Stack trace:
# Something went wrong
#     while executing
# "error "Something went wrong""
#     (procedure "inner" line 2)
#     invoked from within
# "inner"
#     (procedure "middle" line 2)
#     ...
```

## Retry Pattern

```tcl
proc retry {max_attempts delay body} {
    for {set attempt 1} {$attempt <= $max_attempts} {incr attempt} {
        try {
            set result [uplevel 1 $body]
            return $result
        } on error {msg} {
            if {$attempt == $max_attempts} {
                error "Failed after $max_attempts attempts: $msg"
            }
            puts "Attempt $attempt failed: $msg. Retrying in ${delay}ms..."
            after $delay
        }
    }
}

# Usage
try {
    retry 3 1000 {
        set f [open "/network/share/data.txt" r]
        set data [read $f]
        close $f
        set data
    }
} on error {msg} {
    puts "All retries failed: $msg"
}
```

## Assert Utility

```tcl
proc assert {condition {message ""}} {
    if {![uplevel 1 [list expr $condition]]} {
        if {$message eq ""} {
            set message "Assertion failed: $condition"
        }
        throw {ASSERT} $message
    }
}

proc process_data {data} {
    assert {[llength $data] > 0} "Data must not be empty"
    assert {[llength $data] <= 1000} "Data too large (max 1000 elements)"
    # process...
}
```

## Practical Example: Safe Resource Manager

```tcl
proc with_file {varName filename mode body} {
    upvar 1 $varName f
    set f [open $filename $mode]
    try {
        uplevel 1 $body
    } on error {msg options} {
        dict incr options -level 1
        return -options $options $msg
    } finally {
        catch {close $f}
    }
}

# Usage — file is automatically closed on success or error
with_file f "output.txt" w {
    puts $f "Line 1"
    puts $f "Line 2"
    # Even if an error occurs here, the file is closed
}
```

## Practical Example: Input Validation Framework

```tcl
proc validate {value rules} {
    set errors {}
    foreach {rule param} $rules {
        switch $rule {
            required {
                if {$value eq ""} {
                    lappend errors "Value is required"
                }
            }
            min_length {
                if {[string length $value] < $param} {
                    lappend errors "Minimum length is $param"
                }
            }
            max_length {
                if {[string length $value] > $param} {
                    lappend errors "Maximum length is $param"
                }
            }
            pattern {
                if {![regexp $param $value]} {
                    lappend errors "Does not match required pattern"
                }
            }
            integer {
                if {![string is integer -strict $value]} {
                    lappend errors "Must be an integer"
                }
            }
            range {
                lassign $param min max
                if {$value < $min || $value > $max} {
                    lappend errors "Must be between $min and $max"
                }
            }
        }
    }
    if {[llength $errors] > 0} {
        throw {VALIDATION} [join $errors "; "]
    }
    return $value
}

# Usage
try {
    validate "" {required {}}
} trap {VALIDATION} {msg} {
    puts "Validation error: $msg"
}

try {
    validate "ab" {min_length 3 max_length 20 pattern {^[a-z]+$}}
} trap {VALIDATION} {msg} {
    puts "Validation error: $msg"
}
```

---

**Previous:** [Regular Expressions](10-regular-expressions.md) | **Next:** [Namespaces & Packages](12-namespaces-and-packages.md)
