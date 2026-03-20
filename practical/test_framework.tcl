#!/usr/bin/env tclsh
# =============================================================================
# Practical Example: Minimal Unit Test Framework
# =============================================================================
# A lightweight test framework with assertions, setup/teardown, test suites,
# and colored output. Demonstrates: namespaces, procedures, error handling,
# string formatting, upvar, and metaprogramming.
# =============================================================================

namespace eval TestFramework {
    variable suites {}
    variable current_suite ""
    variable results [dict create passed 0 failed 0 errors 0 skipped 0]
    variable test_details {}
    variable setup_proc ""
    variable teardown_proc ""
    variable use_color true

    namespace export suite test skip setup teardown \
        assert assert_equal assert_not_equal assert_true assert_false \
        assert_match assert_regexp assert_error assert_near assert_list_equal

    proc color {code text} {
        variable use_color
        if {$use_color} {
            return "\033\[${code}m${text}\033\[0m"
        }
        return $text
    }

    proc green {text}  { color "32" $text }
    proc red {text}    { color "31" $text }
    proc yellow {text} { color "33" $text }
    proc cyan {text}   { color "36" $text }
    proc bold {text}   { color "1" $text }

    proc suite {name body} {
        variable current_suite
        variable suites
        variable setup_proc
        variable teardown_proc

        set current_suite $name
        set setup_proc ""
        set teardown_proc ""
        lappend suites $name

        puts "\n[bold "Suite: $name"]"
        puts [string repeat "─" [expr {[string length "Suite: $name"] + 2}]]

        uplevel 1 $body

        set current_suite ""
        set setup_proc ""
        set teardown_proc ""
    }

    proc setup {body} {
        variable setup_proc
        set setup_proc $body
    }

    proc teardown {body} {
        variable teardown_proc
        set teardown_proc $body
    }

    proc test {name body} {
        variable current_suite
        variable results
        variable test_details
        variable setup_proc
        variable teardown_proc

        set full_name "$current_suite :: $name"
        set start_time [clock microseconds]

        try {
            if {$setup_proc ne ""} {
                uplevel 1 $setup_proc
            }

            uplevel 1 $body

            set elapsed [expr {[clock microseconds] - $start_time}]
            dict incr results passed
            lappend test_details [dict create \
                name $full_name status "PASS" time $elapsed message ""]
            puts "  [green "PASS"] $name ([format_time $elapsed])"

        } on error {msg opts} {
            set elapsed [expr {[clock microseconds] - $start_time}]

            if {[string match "ASSERTION FAILED:*" $msg]} {
                dict incr results failed
                lappend test_details [dict create \
                    name $full_name status "FAIL" time $elapsed message $msg]
                puts "  [red "FAIL"] $name"
                puts "        $msg"
            } else {
                dict incr results errors
                lappend test_details [dict create \
                    name $full_name status "ERROR" time $elapsed message $msg]
                puts "  [red "ERROR"] $name"
                puts "        $msg"
            }
        } finally {
            if {$teardown_proc ne ""} {
                catch {uplevel 1 $teardown_proc}
            }
        }
    }

    proc skip {name reason} {
        variable current_suite
        variable results
        variable test_details

        set full_name "$current_suite :: $name"
        dict incr results skipped
        lappend test_details [dict create \
            name $full_name status "SKIP" time 0 message $reason]
        puts "  [yellow "SKIP"] $name ($reason)"
    }

    proc format_time {microseconds} {
        if {$microseconds < 1000} {
            return "${microseconds}µs"
        } elseif {$microseconds < 1000000} {
            return [format "%.2fms" [expr {$microseconds / 1000.0}]]
        } else {
            return [format "%.2fs" [expr {$microseconds / 1000000.0}]]
        }
    }

    # --- Assertions ---

    proc assert {condition {message ""}} {
        if {![uplevel 1 [list expr $condition]]} {
            if {$message eq ""} {
                set message "Assertion failed: $condition"
            }
            error "ASSERTION FAILED: $message"
        }
    }

    proc assert_equal {expected actual {message ""}} {
        if {$expected ne $actual} {
            if {$message eq ""} {
                set message "Expected '$expected' but got '$actual'"
            }
            error "ASSERTION FAILED: $message"
        }
    }

    proc assert_not_equal {unexpected actual {message ""}} {
        if {$unexpected eq $actual} {
            if {$message eq ""} {
                set message "Expected value to differ from '$unexpected'"
            }
            error "ASSERTION FAILED: $message"
        }
    }

    proc assert_true {value {message ""}} {
        if {![string is true -strict $value] && $value ni {1 true yes}} {
            if {$message eq ""} {
                set message "Expected true but got '$value'"
            }
            error "ASSERTION FAILED: $message"
        }
    }

    proc assert_false {value {message ""}} {
        if {![string is false -strict $value] && $value ni {0 false no}} {
            if {$message eq ""} {
                set message "Expected false but got '$value'"
            }
            error "ASSERTION FAILED: $message"
        }
    }

    proc assert_match {pattern actual {message ""}} {
        if {![string match $pattern $actual]} {
            if {$message eq ""} {
                set message "Expected '$actual' to match pattern '$pattern'"
            }
            error "ASSERTION FAILED: $message"
        }
    }

    proc assert_regexp {pattern actual {message ""}} {
        if {![regexp $pattern $actual]} {
            if {$message eq ""} {
                set message "Expected '$actual' to match regex '$pattern'"
            }
            error "ASSERTION FAILED: $message"
        }
    }

    proc assert_error {body {expected_msg ""}} {
        set caught 0
        try {
            uplevel 1 $body
        } on error {msg} {
            set caught 1
            if {$expected_msg ne "" && ![string match $expected_msg $msg]} {
                error "ASSERTION FAILED: Expected error matching '$expected_msg' but got '$msg'"
            }
        }
        if {!$caught} {
            error "ASSERTION FAILED: Expected an error but none was raised"
        }
    }

    proc assert_near {expected actual {tolerance 1e-6} {message ""}} {
        if {abs($expected - $actual) > $tolerance} {
            if {$message eq ""} {
                set message "Expected ~$expected but got $actual (tolerance: $tolerance)"
            }
            error "ASSERTION FAILED: $message"
        }
    }

    proc assert_list_equal {expected actual {message ""}} {
        if {[llength $expected] != [llength $actual]} {
            if {$message eq ""} {
                set message "Lists differ in length: [llength $expected] vs [llength $actual]"
            }
            error "ASSERTION FAILED: $message"
        }
        for {set i 0} {$i < [llength $expected]} {incr i} {
            if {[lindex $expected $i] ne [lindex $actual $i]} {
                if {$message eq ""} {
                    set message "Lists differ at index $i: '[lindex $expected $i]' vs '[lindex $actual $i]'"
                }
                error "ASSERTION FAILED: $message"
            }
        }
    }

    # --- Report ---

    proc report {} {
        variable results
        variable test_details

        set total [expr {[dict get $results passed] + [dict get $results failed] + \
                         [dict get $results errors] + [dict get $results skipped]}]

        puts "\n[bold [string repeat "═" 50]]"
        puts [bold "  TEST RESULTS"]
        puts [bold [string repeat "═" 50]]
        puts ""
        puts "  Total:   $total"
        puts "  [green "Passed:  [dict get $results passed]"]"
        if {[dict get $results failed] > 0} {
            puts "  [red "Failed:  [dict get $results failed]"]"
        } else {
            puts "  Failed:  0"
        }
        if {[dict get $results errors] > 0} {
            puts "  [red "Errors:  [dict get $results errors]"]"
        } else {
            puts "  Errors:  0"
        }
        if {[dict get $results skipped] > 0} {
            puts "  [yellow "Skipped: [dict get $results skipped]"]"
        } else {
            puts "  Skipped: 0"
        }

        set failures [lmap d $test_details {
            if {[dict get $d status] in {FAIL ERROR}} {set d} else continue
        }]
        if {[llength $failures] > 0} {
            puts "\n[red "  Failures and Errors:"]"
            foreach d $failures {
                puts "    [red "✗"] [dict get $d name]"
                puts "      [dict get $d message]"
            }
        }

        set total_time 0
        foreach d $test_details {
            incr total_time [dict get $d time]
        }
        puts "\n  Total time: [format_time $total_time]"
        puts [bold [string repeat "═" 50]]

        if {[dict get $results failed] > 0 || [dict get $results errors] > 0} {
            return 1
        }
        return 0
    }

    proc reset {} {
        variable results
        variable test_details
        variable suites
        set results [dict create passed 0 failed 0 errors 0 skipped 0]
        set test_details {}
        set suites {}
    }
}

# =============================================================================
# Demo: Running tests with the framework
# =============================================================================

namespace import TestFramework::*

puts [TestFramework::bold "═══ Tcl Unit Test Framework Demo ═══"]

# --- Test Suite 1: String Operations ---
suite "String Operations" {

    test "string length" {
        assert_equal 5 [string length "hello"]
        assert_equal 0 [string length ""]
        assert_equal 11 [string length "hello world"]
    }

    test "string toupper" {
        assert_equal "HELLO" [string toupper "hello"]
        assert_equal "HELLO WORLD" [string toupper "hello world"]
    }

    test "string trim" {
        assert_equal "hello" [string trim "  hello  "]
        assert_equal "hello  " [string trimleft "  hello  "]
        assert_equal "  hello" [string trimright "  hello  "]
    }

    test "string match" {
        assert_true [string match "Hello*" "Hello World"]
        assert_false [string match "Hello*" "Goodbye World"]
    }

    test "string reverse" {
        assert_equal "olleh" [string reverse "hello"]
        assert_equal "racecar" [string reverse "racecar"]
    }

    test "string replace" {
        set result [string map {world "Tcl"} "hello world"]
        assert_equal "hello Tcl" $result
    }
}

# --- Test Suite 2: List Operations ---
suite "List Operations" {

    setup {
        set test_list {1 2 3 4 5}
    }

    test "lindex" {
        assert_equal 1 [lindex $test_list 0]
        assert_equal 5 [lindex $test_list end]
        assert_equal 3 [lindex $test_list 2]
    }

    test "llength" {
        assert_equal 5 [llength $test_list]
        assert_equal 0 [llength {}]
    }

    test "lsort" {
        assert_list_equal {1 2 3 4 5} [lsort -integer $test_list]
        assert_list_equal {5 4 3 2 1} [lsort -integer -decreasing $test_list]
    }

    test "lsearch" {
        assert_equal 2 [lsearch $test_list 3]
        assert_equal -1 [lsearch $test_list 99]
    }

    test "lrange" {
        assert_list_equal {2 3 4} [lrange $test_list 1 3]
        assert_list_equal {1 2 3 4} [lrange $test_list 0 end-1]
    }

    test "lappend" {
        set lst {a b c}
        lappend lst "d"
        assert_equal 4 [llength $lst]
        assert_equal "d" [lindex $lst end]
    }
}

# --- Test Suite 3: Math Operations ---
suite "Math Operations" {

    test "basic arithmetic" {
        assert_equal 7 [expr {3 + 4}]
        assert_equal 12 [expr {3 * 4}]
        assert_equal 3 [expr {10 / 3}]
        assert_equal 1 [expr {10 % 3}]
    }

    test "floating point" {
        assert_near 3.14159 [expr {acos(-1)}] 0.0001
        assert_near 1.0 [expr {sin(acos(-1)/2)}] 1e-10
    }

    test "power" {
        assert_equal 1024 [expr {2 ** 10}]
        assert_equal 1 [expr {5 ** 0}]
    }

    test "comparison" {
        assert_true [expr {5 > 3}]
        assert_false [expr {3 > 5}]
        assert_true [expr {5 == 5}]
    }

    test "math functions" {
        assert_equal 42 [expr {abs(-42)}]
        assert_near 12.0 [expr {sqrt(144)}] 1e-10
        assert_equal 4 [expr {round(3.7)}]
        assert_equal 3 [expr {int(3.99)}]
    }
}

# --- Test Suite 4: Dict Operations ---
suite "Dict Operations" {

    setup {
        set test_dict [dict create name "Alice" age 30 city "Portland"]
    }

    test "dict get" {
        assert_equal "Alice" [dict get $test_dict name]
        assert_equal 30 [dict get $test_dict age]
    }

    test "dict set" {
        dict set test_dict email "alice@test.com"
        assert_equal "alice@test.com" [dict get $test_dict email]
    }

    test "dict exists" {
        assert_true [dict exists $test_dict name]
        assert_false [dict exists $test_dict phone]
    }

    test "dict size" {
        assert_equal 3 [dict size $test_dict]
    }

    test "dict keys" {
        set keys [lsort [dict keys $test_dict]]
        assert_list_equal {age city name} $keys
    }

    test "dict merge" {
        set extra [dict create phone "555-1234" age 31]
        set merged [dict merge $test_dict $extra]
        assert_equal "555-1234" [dict get $merged phone]
        assert_equal 31 [dict get $merged age]
    }
}

# --- Test Suite 5: Error Handling ---
suite "Error Handling" {

    test "catch division by zero" {
        assert_error {expr {1 / 0}}
    }

    test "catch with specific message" {
        assert_error {error "custom error"} "*custom*"
    }

    test "no error on valid operation" {
        set result [expr {10 / 2}]
        assert_equal 5 $result
    }

    skip "database tests" "No database available"

    test "deliberate failure for demo" {
        assert_equal "expected" "actual" "This test is designed to fail"
    }
}

# --- Print report ---
set exit_code [TestFramework::report]
