#!/usr/bin/env tclsh
#
# 09_namespaces_packages.tcl — Demonstrates namespaces and code organization
#

puts "=============================="
puts " Namespaces & Code Organization"
puts "=============================="
puts ""

# --- Basic Namespaces ---
puts "--- Basic Namespaces ---"

namespace eval math_utils {
    variable pi 3.14159265358979
    variable e  2.71828182845905

    proc factorial {n} {
        if {$n <= 1} { return 1 }
        return [expr {$n * [factorial [expr {$n - 1}]]}]
    }

    proc combinations {n r} {
        return [expr {[factorial $n] / ([factorial $r] * [factorial [expr {$n - $r}]])}]
    }

    proc permutations {n r} {
        return [expr {[factorial $n] / [factorial [expr {$n - $r}]]}]
    }

    proc deg_to_rad {degrees} {
        variable pi
        return [expr {$degrees * $pi / 180.0}]
    }

    proc rad_to_deg {radians} {
        variable pi
        return [expr {$radians * 180.0 / $pi}]
    }
}

puts "Pi: $math_utils::pi"
puts "5! = [math_utils::factorial 5]"
puts "C(10,3) = [math_utils::combinations 10 3]"
puts "P(10,3) = [math_utils::permutations 10 3]"
puts "45° = [format "%.4f" [math_utils::deg_to_rad 45]] rad"
puts "1.5708 rad = [format "%.1f" [math_utils::rad_to_deg 1.5708]]°"
puts ""

# --- Nested Namespaces ---
puts "--- Nested Namespaces ---"

namespace eval app {
    variable name "MyApp"
    variable version "1.0.0"

    namespace eval config {
        variable settings [dict create]

        proc set_value {key value} {
            variable settings
            dict set settings $key $value
        }

        proc get_value {key {default ""}} {
            variable settings
            if {[dict exists $settings $key]} {
                return [dict get $settings $key]
            }
            return $default
        }

        proc dump {} {
            variable settings
            dict for {k v} $settings {
                puts [format "  %-20s = %s" $k $v]
            }
        }
    }

    namespace eval logger {
        variable log_level "INFO"
        variable levels [dict create DEBUG 0 INFO 1 WARN 2 ERROR 3 FATAL 4]

        proc set_level {level} {
            variable log_level
            set log_level $level
        }

        proc log {level message} {
            variable log_level
            variable levels
            if {[dict get $levels $level] >= [dict get $levels $log_level]} {
                set ts [clock format [clock seconds] -format "%H:%M:%S"]
                puts "  \[$ts\] $level: $message"
            }
        }

        proc debug {msg} { log DEBUG $msg }
        proc info  {msg} { log INFO  $msg }
        proc warn  {msg} { log WARN  $msg }
        proc error {msg} { log ERROR $msg }
    }
}

app::config::set_value "host" "localhost"
app::config::set_value "port" "8080"
app::config::set_value "debug" "true"
app::config::set_value "max_connections" "100"

puts "Configuration:"
app::config::dump
puts ""

app::logger::set_level "INFO"
puts "Log output (level=INFO):"
app::logger::debug "This won't show (DEBUG < INFO)"
app::logger::info  "Application $app::name v$app::version starting"
app::logger::warn  "Config file not found, using defaults"
app::logger::error "Failed to bind to port [app::config::get_value port]"
puts ""

# --- Namespace Ensemble (subcommand dispatch) ---
puts "--- Namespace Ensemble ---"

namespace eval stack {
    variable data [list]

    namespace export push pop peek size empty display

    namespace ensemble create

    proc push {value} {
        variable data
        lappend data $value
    }

    proc pop {} {
        variable data
        if {[llength $data] == 0} { ::error "Stack underflow" }
        set val [lindex $data end]
        set data [lrange $data 0 end-1]
        return $val
    }

    proc peek {} {
        variable data
        if {[llength $data] == 0} { ::error "Stack is empty" }
        return [lindex $data end]
    }

    proc size {} {
        variable data
        return [llength $data]
    }

    proc empty {} {
        variable data
        return [expr {[llength $data] == 0}]
    }

    proc display {} {
        variable data
        if {[llength $data] == 0} {
            puts "  (empty stack)"
        } else {
            puts "  Bottom -> [join $data " | "] <- Top"
        }
    }
}

puts "Stack operations:"
stack push 10
stack push 20
stack push 30
stack push 40
stack display
puts "  Peek: [stack peek]"
puts "  Pop:  [stack pop]"
puts "  Pop:  [stack pop]"
puts "  Size: [stack size]"
stack display
puts ""

# --- Namespace Import ---
puts "--- Namespace Import ---"

namespace eval string_utils {
    namespace export pad_left pad_right truncate
    namespace ensemble create

    proc pad_left {str width {char " "}} {
        set padding [expr {$width - [string length $str]}]
        if {$padding <= 0} { return $str }
        return "[string repeat $char $padding]$str"
    }

    proc pad_right {str width {char " "}} {
        set padding [expr {$width - [string length $str]}]
        if {$padding <= 0} { return $str }
        return "$str[string repeat $char $padding]"
    }

    proc truncate {str max_len {suffix "..."}} {
        if {[string length $str] <= $max_len} { return $str }
        set cut [expr {$max_len - [string length $suffix]}]
        return "[string range $str 0 [expr {$cut - 1}]]$suffix"
    }
}

puts "Padding examples:"
puts "  |[string_utils pad_left "42" 10]|"
puts "  |[string_utils pad_right "hello" 15 "."]|"
puts "  |[string_utils pad_left "007" 6 "0"]|"
puts ""

puts "Truncation examples:"
puts "  [string_utils truncate "This is a very long string" 15]"
puts "  [string_utils truncate "Short" 15]"
puts ""

# --- Simulated Module System ---
puts "--- Simulated Module System ---"

namespace eval queue {
    variable items [list]

    namespace export enqueue dequeue peek size empty display
    namespace ensemble create

    proc enqueue {value} {
        variable items
        lappend items $value
    }

    proc dequeue {} {
        variable items
        if {[llength $items] == 0} { ::error "Queue is empty" }
        set val [lindex $items 0]
        set items [lrange $items 1 end]
        return $val
    }

    proc peek {} {
        variable items
        if {[llength $items] == 0} { ::error "Queue is empty" }
        return [lindex $items 0]
    }

    proc size {} {
        variable items
        return [llength $items]
    }

    proc empty {} {
        variable items
        return [expr {[llength $items] == 0}]
    }

    proc display {} {
        variable items
        if {[llength $items] == 0} {
            puts "  (empty queue)"
        } else {
            puts "  Front -> [join $items " | "] <- Back"
        }
    }
}

puts "Queue operations:"
queue enqueue "task-A"
queue enqueue "task-B"
queue enqueue "task-C"
queue enqueue "task-D"
queue display
puts "  Dequeue: [queue dequeue]"
puts "  Dequeue: [queue dequeue]"
queue enqueue "task-E"
queue display
puts "  Size: [queue size]"
puts ""

puts "Done!"
