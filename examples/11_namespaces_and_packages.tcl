#!/usr/bin/env tclsh
# =============================================================================
# Example 11: Namespaces and Packages
# Demonstrates: namespace eval, variables, export/import, nested namespaces
# =============================================================================

puts "=== Namespaces and Packages ===\n"

# --- Basic namespace ---
puts "--- Basic Namespace ---"

namespace eval geometry {
    variable pi 3.14159265358979

    proc circle_area {radius} {
        variable pi
        return [expr {$pi * $radius * $radius}]
    }

    proc circle_circumference {radius} {
        variable pi
        return [expr {2 * $pi * $radius}]
    }

    proc sphere_volume {radius} {
        variable pi
        return [expr {(4.0/3.0) * $pi * $radius ** 3}]
    }

    proc rectangle_area {w h} {
        return [expr {$w * $h}]
    }

    proc triangle_area {base height} {
        return [expr {0.5 * $base * $height}]
    }
}

puts "  Circle (r=5):"
puts [format "    Area:          %.4f" [geometry::circle_area 5]]
puts [format "    Circumference: %.4f" [geometry::circle_circumference 5]]
puts [format "  Sphere (r=3) volume: %.4f" [geometry::sphere_volume 3]]
puts [format "  Rectangle (4x6):    %.1f" [geometry::rectangle_area 4 6]]
puts [format "  Triangle (b=8,h=5): %.1f" [geometry::triangle_area 8 5]]
puts "  Pi = $geometry::pi"

# --- Namespace with export/import ---
puts "\n--- Export and Import ---"

namespace eval stringutils {
    namespace export capitalize repeat_str truncate

    proc capitalize {str} {
        return [string toupper [string index $str 0]][string range $str 1 end]
    }

    proc repeat_str {str n} {
        return [string repeat $str $n]
    }

    proc truncate {str maxlen {suffix "..."}} {
        if {[string length $str] <= $maxlen} {
            return $str
        }
        set cutlen [expr {$maxlen - [string length $suffix]}]
        return "[string range $str 0 [expr {$cutlen - 1}]]$suffix"
    }

    proc _internal_helper {} {
        return "I am not exported"
    }
}

namespace import stringutils::*
puts "  capitalize 'hello': [capitalize "hello"]"
puts "  repeat_str '=-' 10: [repeat_str "=-" 10]"
puts "  truncate: [truncate "This is a very long string that should be truncated" 30]"

# --- Nested namespaces ---
puts "\n--- Nested Namespaces ---"

namespace eval app {
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
                puts "    $k = $v"
            }
        }
    }

    namespace eval logger {
        variable log_entries [list]

        proc log {level message} {
            variable log_entries
            set timestamp [clock format [clock seconds] -format "%H:%M:%S"]
            set entry "\[$timestamp\] $level: $message"
            lappend log_entries $entry
            puts "    $entry"
        }

        proc info {msg} { log "INFO" $msg }
        proc warn {msg} { log "WARN" $msg }
        proc error {msg} { log "ERROR" $msg }

        proc get_entries {} {
            variable log_entries
            return $log_entries
        }
    }

    namespace eval counter {
        variable counts
        array set counts {}

        proc increment {name {amount 1}} {
            variable counts
            if {[::info exists counts($name)]} {
                incr counts($name) $amount
            } else {
                set counts($name) $amount
            }
        }

        proc get {name} {
            variable counts
            if {[::info exists counts($name)]} {
                return $counts($name)
            }
            return 0
        }

        proc report {} {
            variable counts
            foreach name [lsort [array names counts]] {
                puts [format "    %-20s: %d" $name $counts($name)]
            }
        }
    }
}

# Use nested namespaces
app::config::set_value "host" "localhost"
app::config::set_value "port" "8080"
app::config::set_value "debug" "true"

puts "  App version: $app::version"
puts "  Configuration:"
app::config::dump

puts "\n  Logging:"
app::logger::info "Application started"
app::logger::info "Loading configuration"
app::logger::warn "Debug mode is enabled"

puts "\n  Counters:"
app::counter::increment "page_views" 10
app::counter::increment "api_calls" 5
app::counter::increment "page_views" 3
app::counter::increment "errors" 1
app::counter::report

# --- Namespace introspection ---
puts "\n--- Namespace Introspection ---"
puts "  Children of '::': [namespace children ::]"
puts "  Children of '::app': [namespace children ::app]"
puts "  Procs in geometry: [info procs ::geometry::*]"
puts "  Vars in geometry: [info vars ::geometry::*]"
puts "  Current namespace: [namespace current]"

# --- Namespace ensemble (object-like syntax) ---
puts "\n--- Namespace Ensemble ---"

namespace eval stack {
    variable data [list]

    namespace export push pop peek size is_empty to_string
    namespace ensemble create

    proc push {item} {
        variable data
        lappend data $item
    }

    proc pop {} {
        variable data
        if {[llength $data] == 0} {
            error "Stack underflow"
        }
        set item [lindex $data end]
        set data [lrange $data 0 end-1]
        return $item
    }

    proc peek {} {
        variable data
        if {[llength $data] == 0} {
            error "Stack is empty"
        }
        return [lindex $data end]
    }

    proc size {} {
        variable data
        return [llength $data]
    }

    proc is_empty {} {
        variable data
        return [expr {[llength $data] == 0}]
    }

    proc to_string {} {
        variable data
        return "\[bottom -> [join $data " -> "] -> top\]"
    }
}

stack push "A"
stack push "B"
stack push "C"
puts "  Stack: [stack to_string]"
puts "  Size: [stack size]"
puts "  Peek: [stack peek]"
puts "  Pop: [stack pop]"
puts "  Pop: [stack pop]"
puts "  Stack: [stack to_string]"
puts "  Empty? [stack is_empty]"

puts "\nDone."
