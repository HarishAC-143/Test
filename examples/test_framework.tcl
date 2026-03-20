#!/usr/bin/env tclsh
#
# Minimal Unit Test Framework for Tcl
# Provides assertions, test organization, setup/teardown, and reporting.

namespace eval tunit {
    variable tests {}
    variable results {}
    variable current_suite ""
    variable setup_cmd ""
    variable teardown_cmd ""
    variable verbose 1

    proc suite {name body} {
        variable current_suite
        variable setup_cmd
        variable teardown_cmd

        set old_suite $current_suite
        set old_setup $setup_cmd
        set old_teardown $teardown_cmd

        set current_suite $name
        set setup_cmd ""
        set teardown_cmd ""

        if {$verbose} {
            puts "\n  Suite: $name"
            puts "  [string repeat "-" [expr {[string length $name] + 8}]]"
        }

        uplevel 1 $body

        set current_suite $old_suite
        set setup_cmd $old_setup
        set teardown_cmd $old_teardown
    }

    proc setup {body} {
        variable setup_cmd
        set setup_cmd $body
    }

    proc teardown {body} {
        variable teardown_cmd
        set teardown_cmd $body
    }

    proc test {name body} {
        variable current_suite
        variable setup_cmd
        variable teardown_cmd
        variable results
        variable verbose

        set full_name "$current_suite::$name"

        if {$setup_cmd ne ""} {
            if {[catch {uplevel 1 $setup_cmd} err]} {
                record_result $full_name "ERROR" "Setup failed: $err"
                return
            }
        }

        set start [clock microseconds]
        set status "PASS"
        set message ""

        if {[catch {uplevel 1 $body} err options]} {
            set code [dict get $options -errorcode]
            if {[lindex $code 0] eq "TUNIT"} {
                set status "FAIL"
                set message $err
            } else {
                set status "ERROR"
                set message $err
            }
        }

        set elapsed [expr {([clock microseconds] - $start) / 1000.0}]

        if {$teardown_cmd ne ""} {
            catch {uplevel 1 $teardown_cmd}
        }

        record_result $full_name $status $message $elapsed

        if {$verbose} {
            switch $status {
                PASS  { puts "    PASS  $name (${elapsed}ms)" }
                FAIL  { puts "    FAIL  $name: $message" }
                ERROR { puts "    ERROR $name: $message" }
                SKIP  { puts "    SKIP  $name: $message" }
            }
        }
    }

    proc skip {reason} {
        throw {TUNIT SKIP} $reason
    }

    proc record_result {name status message {elapsed 0}} {
        variable results
        lappend results [dict create \
            name $name status $status \
            message $message elapsed $elapsed]
    }

    # --- Assertions ---

    proc assert_true {value {msg ""}} {
        if {![expr {$value ? 1 : 0}]} {
            set msg [expr {$msg ne "" ? $msg : "Expected true, got '$value'"}]
            throw {TUNIT ASSERT} $msg
        }
    }

    proc assert_false {value {msg ""}} {
        if {[expr {$value ? 1 : 0}]} {
            set msg [expr {$msg ne "" ? $msg : "Expected false, got '$value'"}]
            throw {TUNIT ASSERT} $msg
        }
    }

    proc assert_equal {expected actual {msg ""}} {
        if {$expected ne $actual} {
            set msg [expr {$msg ne "" ? $msg : "Expected '$expected', got '$actual'"}]
            throw {TUNIT ASSERT} $msg
        }
    }

    proc assert_not_equal {unexpected actual {msg ""}} {
        if {$unexpected eq $actual} {
            set msg [expr {$msg ne "" ? $msg : "Expected value different from '$unexpected'"}]
            throw {TUNIT ASSERT} $msg
        }
    }

    proc assert_match {pattern actual {msg ""}} {
        if {![string match $pattern $actual]} {
            set msg [expr {$msg ne "" ? $msg : "'$actual' does not match pattern '$pattern'"}]
            throw {TUNIT ASSERT} $msg
        }
    }

    proc assert_regexp {pattern actual {msg ""}} {
        if {![regexp $pattern $actual]} {
            set msg [expr {$msg ne "" ? $msg : "'$actual' does not match regex '$pattern'"}]
            throw {TUNIT ASSERT} $msg
        }
    }

    proc assert_near {expected actual {tolerance 1e-6} {msg ""}} {
        if {abs($expected - $actual) > $tolerance} {
            set msg [expr {$msg ne "" ? $msg : "Expected ~$expected, got $actual (tolerance: $tolerance)"}]
            throw {TUNIT ASSERT} $msg
        }
    }

    proc assert_error {body {pattern ""}} {
        if {[catch {uplevel 1 $body} result]} {
            if {$pattern ne "" && ![string match $pattern $result]} {
                throw {TUNIT ASSERT} "Error message '$result' doesn't match '$pattern'"
            }
            return
        }
        throw {TUNIT ASSERT} "Expected an error but none occurred"
    }

    proc assert_no_error {body} {
        if {[catch {uplevel 1 $body} result]} {
            throw {TUNIT ASSERT} "Unexpected error: $result"
        }
    }

    proc assert_list_equal {expected actual {msg ""}} {
        if {[llength $expected] != [llength $actual]} {
            set msg [expr {$msg ne "" ? $msg : \
                "List length mismatch: [llength $expected] vs [llength $actual]"}]
            throw {TUNIT ASSERT} $msg
        }
        for {set i 0} {$i < [llength $expected]} {incr i} {
            if {[lindex $expected $i] ne [lindex $actual $i]} {
                set msg "Element $i differs: '[lindex $expected $i]' vs '[lindex $actual $i]'"
                throw {TUNIT ASSERT} $msg
            }
        }
    }

    # --- Reporting ---

    proc report {} {
        variable results

        set total 0
        set passed 0
        set failed 0
        set errors 0
        set skipped 0
        set total_time 0.0

        set failures {}

        foreach r $results {
            incr total
            set total_time [expr {$total_time + [dict get $r elapsed]}]
            switch [dict get $r status] {
                PASS  { incr passed }
                FAIL  {
                    incr failed
                    lappend failures $r
                }
                ERROR {
                    incr errors
                    lappend failures $r
                }
                SKIP  { incr skipped }
            }
        }

        puts "\n[string repeat "=" 60]"
        puts "TEST RESULTS"
        puts [string repeat "=" 60]

        if {[llength $failures] > 0} {
            puts "\nFailures and Errors:"
            foreach f $failures {
                puts "  [dict get $f status]: [dict get $f name]"
                puts "    [dict get $f message]"
            }
        }

        puts [format "\nTotal: %d | Passed: %d | Failed: %d | Errors: %d | Skipped: %d" \
            $total $passed $failed $errors $skipped]
        puts [format "Time: %.1f ms" $total_time]

        if {$failed == 0 && $errors == 0} {
            puts "\nALL TESTS PASSED"
        } else {
            puts "\nSOME TESTS FAILED"
        }
        puts [string repeat "=" 60]

        return [expr {$failed == 0 && $errors == 0}]
    }

    proc reset {} {
        variable results
        variable tests
        set results {}
        set tests {}
    }
}

# --- Demo: Testing a small math library ---

namespace eval mathlib {
    proc factorial {n} {
        if {$n < 0} { error "negative argument" }
        if {$n <= 1} { return 1 }
        set result 1
        for {set i 2} {$i <= $n} {incr i} {
            set result [expr {$result * $i}]
        }
        return $result
    }

    proc fibonacci {n} {
        if {$n < 0} { error "negative argument" }
        if {$n <= 1} { return $n }
        set a 0; set b 1
        for {set i 2} {$i <= $n} {incr i} {
            lassign [list $b [expr {$a + $b}]] a b
        }
        return $b
    }

    proc is_prime {n} {
        if {$n < 2} { return 0 }
        if {$n == 2} { return 1 }
        if {$n % 2 == 0} { return 0 }
        for {set i 3} {$i * $i <= $n} {incr i 2} {
            if {$n % $i == 0} { return 0 }
        }
        return 1
    }

    proc gcd {a b} {
        set a [expr {abs($a)}]
        set b [expr {abs($b)}]
        while {$b != 0} {
            lassign [list $b [expr {$a % $b}]] a b
        }
        return $a
    }
}

proc run_demo_tests {} {
    puts "=== Tcl Unit Test Framework Demo ===\n"

    tunit::reset

    tunit::suite "Factorial" {
        tunit::test "factorial of 0" {
            tunit::assert_equal 1 [mathlib::factorial 0]
        }

        tunit::test "factorial of 1" {
            tunit::assert_equal 1 [mathlib::factorial 1]
        }

        tunit::test "factorial of 5" {
            tunit::assert_equal 120 [mathlib::factorial 5]
        }

        tunit::test "factorial of 10" {
            tunit::assert_equal 3628800 [mathlib::factorial 10]
        }

        tunit::test "factorial of negative" {
            tunit::assert_error { mathlib::factorial -1 } "*negative*"
        }
    }

    tunit::suite "Fibonacci" {
        tunit::test "fibonacci base cases" {
            tunit::assert_equal 0 [mathlib::fibonacci 0]
            tunit::assert_equal 1 [mathlib::fibonacci 1]
        }

        tunit::test "fibonacci sequence" {
            set expected {0 1 1 2 3 5 8 13 21 34}
            for {set i 0} {$i < [llength $expected]} {incr i} {
                tunit::assert_equal [lindex $expected $i] [mathlib::fibonacci $i]
            }
        }

        tunit::test "fibonacci of 20" {
            tunit::assert_equal 6765 [mathlib::fibonacci 20]
        }
    }

    tunit::suite "Prime Numbers" {
        tunit::test "small primes" {
            foreach p {2 3 5 7 11 13 17 19 23 29} {
                tunit::assert_true [mathlib::is_prime $p] "$p should be prime"
            }
        }

        tunit::test "non-primes" {
            foreach n {0 1 4 6 8 9 10 12 15 20} {
                tunit::assert_false [mathlib::is_prime $n] "$n should not be prime"
            }
        }

        tunit::test "larger prime" {
            tunit::assert_true [mathlib::is_prime 997]
        }
    }

    tunit::suite "GCD" {
        tunit::test "basic gcd" {
            tunit::assert_equal 6 [mathlib::gcd 12 18]
        }

        tunit::test "coprime numbers" {
            tunit::assert_equal 1 [mathlib::gcd 7 13]
        }

        tunit::test "gcd with zero" {
            tunit::assert_equal 5 [mathlib::gcd 5 0]
            tunit::assert_equal 5 [mathlib::gcd 0 5]
        }

        tunit::test "gcd with negative" {
            tunit::assert_equal 6 [mathlib::gcd -12 18]
        }
    }

    tunit::suite "Assertion Demos" {
        tunit::test "string matching" {
            tunit::assert_match "hello*" "hello world"
            tunit::assert_regexp {\d{3}-\d{4}} "555-1234"
        }

        tunit::test "approximate equality" {
            set pi [expr {acos(-1)}]
            tunit::assert_near 3.14159 $pi 0.001
        }

        tunit::test "list equality" {
            tunit::assert_list_equal {a b c} {a b c}
        }

        tunit::test "deliberate failure" {
            tunit::assert_equal 42 43 "This test intentionally fails"
        }
    }

    set all_passed [tunit::report]
    return $all_passed
}

if {[info script] eq $argv0} {
    run_demo_tests
}
