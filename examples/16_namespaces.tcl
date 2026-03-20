#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 16: Namespaces
# =============================================================================

puts "=== Basic Namespace ==="
namespace eval math {
    variable pi 3.14159265358979
    variable e  2.71828182845905

    proc circle_area {radius} {
        variable pi
        return [expr {$pi * $radius * $radius}]
    }

    proc circle_circumference {radius} {
        variable pi
        return [expr {2 * $pi * $radius}]
    }

    proc degrees_to_radians {degrees} {
        variable pi
        return [expr {$degrees * $pi / 180.0}]
    }

    proc radians_to_degrees {radians} {
        variable pi
        return [expr {$radians * 180.0 / $pi}]
    }
}

puts [format "Circle area (r=5): %.4f" [math::circle_area 5]]
puts [format "Circumference (r=5): %.4f" [math::circle_circumference 5]]
puts [format "45 deg in radians: %.4f" [math::degrees_to_radians 45]]
puts "Pi: $math::pi"

puts "\n=== Nested Namespaces ==="
namespace eval app {
    variable name "MyApp"
    variable version "1.0.0"

    namespace eval db {
        variable connection_string ""
        variable connected false

        proc connect {host port dbname} {
            variable connection_string
            variable connected
            set connection_string "$host:$port/$dbname"
            set connected true
            puts "DB: Connected to $connection_string"
        }

        proc disconnect {} {
            variable connection_string
            variable connected
            set connected false
            puts "DB: Disconnected from $connection_string"
        }

        proc status {} {
            variable connected
            variable connection_string
            if {$connected} {
                return "Connected to $connection_string"
            }
            return "Not connected"
        }
    }

    namespace eval log {
        variable level "info"

        proc set_level {new_level} {
            variable level
            set level $new_level
        }

        proc _log {severity msg} {
            variable level
            set levels {debug 0 info 1 warning 2 error 3}
            if {[dict get $levels $severity] >= [dict get $levels $level]} {
                set ts [clock format [clock seconds] -format {%H:%M:%S}]
                puts "\[$ts\] [string toupper $severity]: $msg"
            }
        }

        proc debug {msg} { _log debug $msg }
        proc info {msg} { _log info $msg }
        proc warning {msg} { _log warning $msg }
        proc error {msg} { _log error $msg }
    }
}

app::log::set_level "info"
app::log::info "Application $app::name v$app::version starting"
app::db::connect "localhost" 5432 "mydb"
app::log::info "Database status: [app::db::status]"
app::log::debug "This debug message is hidden (level=info)"
app::log::warning "Low disk space"
app::db::disconnect

puts "\n=== namespace import / export ==="
namespace eval geometry {
    namespace export area perimeter

    proc area {shape args} {
        switch $shape {
            circle {
                set r [lindex $args 0]
                return [expr {3.14159 * $r * $r}]
            }
            rectangle {
                lassign $args w h
                return [expr {$w * $h}]
            }
            triangle {
                lassign $args base height
                return [expr {0.5 * $base * $height}]
            }
        }
    }

    proc perimeter {shape args} {
        switch $shape {
            circle {
                set r [lindex $args 0]
                return [expr {2 * 3.14159 * $r}]
            }
            rectangle {
                lassign $args w h
                return [expr {2 * ($w + $h)}]
            }
            triangle {
                lassign $args a b c
                return [expr {$a + $b + $c}]
            }
        }
    }

    proc _internal_helper {} {
        puts "This is not exported"
    }
}

namespace eval my_program {
    namespace import ::geometry::*

    puts "Circle area (r=7): [format %.2f [area circle 7]]"
    puts "Rectangle perimeter (3x4): [perimeter rectangle 3 4]"
    puts "Triangle area (base=6, h=8): [area triangle 6 8]"
}

puts "\n=== Namespace Ensemble ==="
namespace eval stack {
    variable data {}
    namespace export push pop peek size clear display
    namespace ensemble create

    proc push {value} {
        variable data
        lappend data $value
    }

    proc pop {} {
        variable data
        if {[llength $data] == 0} {
            error "Stack underflow"
        }
        set top [lindex $data end]
        set data [lrange $data 0 end-1]
        return $top
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

    proc clear {} {
        variable data
        set data {}
    }

    proc display {} {
        variable data
        return $data
    }
}

stack push 10
stack push 20
stack push 30
puts "Stack: [stack display]"
puts "Size: [stack size]"
puts "Peek: [stack peek]"
puts "Pop: [stack pop]"
puts "Stack after pop: [stack display]"
stack clear
puts "After clear, size: [stack size]"

puts "\n=== Namespace Introspection ==="
puts "Current namespace: [namespace current]"
puts "Children of '::app': [namespace children ::app]"
puts "Exported from '::geometry': [namespace eval ::geometry {namespace export}]"
puts "All math procs: [info procs math::*]"

puts "\n=== Namespace Qualified Variables ==="
namespace eval config {
    variable settings [dict create \
        theme "dark" \
        font_size 14 \
        language "en" \
    ]

    proc get {key} {
        variable settings
        return [dict get $settings $key]
    }

    proc set_val {key value} {
        variable settings
        dict set settings $key $value
    }

    proc dump {} {
        variable settings
        dict for {k v} $settings {
            puts "  $k = $v"
        }
    }
}

config::set_val theme "light"
config::set_val font_size 16
puts "Theme: [config::get theme]"
puts "All settings:"
config::dump
