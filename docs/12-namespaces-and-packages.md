# 12. Namespaces & Packages

## Namespaces

Namespaces provide a way to organize commands and variables into separate, hierarchical scopes to avoid name collisions.

### Creating a Namespace

```tcl
namespace eval math {
    variable PI 3.14159265358979

    proc circle_area {radius} {
        variable PI
        return [expr {$PI * $radius * $radius}]
    }

    proc circle_circumference {radius} {
        variable PI
        return [expr {2 * $PI * $radius}]
    }
}

# Call namespaced procedures
puts [math::circle_area 5]           ;# → 78.5398...
puts [math::circle_circumference 5]  ;# → 31.4159...

# Access namespaced variables
puts $math::PI                       ;# → 3.14159...
```

### Namespace Variables

`variable` declares a namespace variable (analogous to `global` for the global namespace):

```tcl
namespace eval counter {
    variable count 0

    proc increment {} {
        variable count
        incr count
    }

    proc get {} {
        variable count
        return $count
    }

    proc reset {} {
        variable count
        set count 0
    }
}

counter::increment
counter::increment
counter::increment
puts [counter::get]   ;# → 3
counter::reset
puts [counter::get]   ;# → 0
```

### Nested Namespaces

```tcl
namespace eval app {
    namespace eval db {
        proc connect {host port} {
            puts "Connecting to $host:$port"
        }
    }

    namespace eval ui {
        proc render {template} {
            puts "Rendering: $template"
        }
    }
}

app::db::connect "localhost" 5432
app::ui::render "homepage.html"
```

### Importing and Exporting

```tcl
namespace eval utils {
    namespace export log warn
    
    proc log {msg} {
        puts "\[LOG\] $msg"
    }

    proc warn {msg} {
        puts "\[WARN\] $msg"
    }

    proc internal_helper {} {
        puts "This is not exported"
    }
}

# Import specific commands into the current namespace
namespace import utils::log utils::warn

log "Application started"    ;# Can call without utils:: prefix
warn "Low disk space"

# Import all exported commands
namespace import utils::*

# Remove imports
namespace forget utils::*
```

### Current and Parent Namespace

```tcl
namespace eval myns {
    proc where_am_i {} {
        puts "Current namespace: [namespace current]"
        puts "Parent namespace: [namespace parent]"
        puts "Qualified name: [namespace which -command where_am_i]"
    }
}

myns::where_am_i
# Current namespace: ::myns
# Parent namespace: ::
# Qualified name: ::myns::where_am_i
```

### Namespace Ensembles

Ensembles create a single command that dispatches to subcommands — similar to how `string length`, `string index`, etc. work:

```tcl
namespace eval stack {
    variable data {}

    namespace export push pop peek size clear
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
        set val [lindex $data end]
        set data [lrange $data 0 end-1]
        return $val
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
}

# Use as subcommands — clean API
stack push 10
stack push 20
stack push 30
puts [stack peek]   ;# → 30
puts [stack pop]    ;# → 30
puts [stack size]   ;# → 2
```

### Custom Ensemble Mapping

```tcl
namespace eval color {
    proc _red {} { return "\033\[31m" }
    proc _green {} { return "\033\[32m" }
    proc _reset {} { return "\033\[0m" }

    namespace ensemble create -map {
        red   _red
        green _green
        reset _reset
    }
}

puts "[color red]Error![color reset]"
```

## Namespace Introspection

```tcl
namespace eval example {
    variable x 10
    variable y 20
    proc hello {} { puts "hello" }
    proc goodbye {} { puts "goodbye" }
}

# List child namespaces
namespace children ::                ;# → ::example ...

# List commands in a namespace
namespace eval example { info commands * }

# List variables in a namespace
namespace eval example { info vars }

# Check if namespace exists
namespace exists ::example   ;# → 1

# Delete a namespace and everything in it
namespace delete example
```

## Packages

Packages are the standard mechanism for distributing reusable Tcl code.

### Creating a Package

```tcl
# File: mymath.tcl
package provide mymath 1.0

namespace eval mymath {
    namespace export factorial fibonacci gcd

    proc factorial {n} {
        if {$n <= 1} { return 1 }
        set result 1
        for {set i 2} {$i <= $n} {incr i} {
            set result [expr {$result * $i}]
        }
        return $result
    }

    proc fibonacci {n} {
        if {$n <= 0} { return 0 }
        if {$n == 1} { return 1 }
        set a 0
        set b 1
        for {set i 2} {$i <= $n} {incr i} {
            set temp [expr {$a + $b}]
            set a $b
            set b $temp
        }
        return $b
    }

    proc gcd {a b} {
        while {$b != 0} {
            set temp $b
            set b [expr {$a % $b}]
            set a $temp
        }
        return $a
    }
}
```

### Package Index File

Create a `pkgIndex.tcl` file (usually generated with `pkg_mkIndex`):

```tcl
# pkgIndex.tcl
package ifneeded mymath 1.0 [list source [file join $dir mymath.tcl]]
```

### Using a Package

```tcl
# Add the package directory to the search path
lappend auto_path /path/to/package/dir

# Require the package
package require mymath 1.0

# Use it
puts [mymath::factorial 10]
puts [mymath::fibonacci 20]
puts [mymath::gcd 48 18]
```

### Package Versioning

```tcl
# Require minimum version
package require mymath 1.0

# Require exact version range
package require -exact mymath 1.0

# Check what version is loaded
package present mymath    ;# → 1.0

# List available packages
package names

# Get version of a loaded package
package versions mymath
```

### Standard Package: Tcllib

Tcllib is Tcl's standard library, providing many useful packages:

```tcl
package require struct::list
package require csv
package require json
package require logger
package require md5
package require uri
```

## Practical Example: Module System

```tcl
# A simple module pattern for organizing application code

namespace eval ::app {
    variable version "1.0.0"
    variable modules {}
}

proc ::app::register_module {name version init_proc} {
    variable modules
    dict set modules $name [dict create \
        version $version \
        init_proc $init_proc \
        loaded false]
}

proc ::app::load_module {name} {
    variable modules
    if {![dict exists $modules $name]} {
        error "Unknown module: $name"
    }
    set mod [dict get $modules $name]
    if {[dict get $mod loaded]} return

    set init [dict get $mod init_proc]
    $init
    dict set modules $name loaded true
    puts "Module loaded: $name v[dict get $mod version]"
}

proc ::app::info {} {
    variable version
    variable modules
    puts "Application v$version"
    puts "Modules:"
    dict for {name mod} $modules {
        set status [expr {[dict get $mod loaded] ? "loaded" : "pending"}]
        puts "  $name v[dict get $mod version] ($status)"
    }
}

# Register modules
namespace eval ::app::logging {
    proc init {} {
        namespace export log warn error_log
        proc log {msg} { puts "\[LOG\] $msg" }
        proc warn {msg} { puts "\[WARN\] $msg" }
        proc error_log {msg} { puts "\[ERROR\] $msg" }
    }
}

::app::register_module "logging" "1.0" ::app::logging::init
::app::load_module "logging"
::app::info
```

## Practical Example: Plugin Architecture

```tcl
namespace eval ::plugins {
    variable registry {}

    proc register {name spec} {
        variable registry
        dict set registry $name $spec
    }

    proc execute {name method args} {
        variable registry
        if {![dict exists $registry $name]} {
            error "Plugin not found: $name"
        }
        set ns [dict get $registry $name namespace]
        set cmd "${ns}::${method}"
        if {[llength [info commands $cmd]] == 0} {
            error "Plugin '$name' has no method '$method'"
        }
        return [$cmd {*}$args]
    }

    proc list_plugins {} {
        variable registry
        return [dict keys $registry]
    }
}

# Define a plugin
namespace eval ::plugin::uppercase {
    proc transform {text} {
        return [string toupper $text]
    }

    proc describe {} {
        return "Converts text to uppercase"
    }
}

plugins::register "uppercase" {
    namespace ::plugin::uppercase
    version  1.0
}

# Use the plugin
puts [plugins::execute "uppercase" transform "hello world"]
# → HELLO WORLD
puts [plugins::execute "uppercase" describe]
# → Converts text to uppercase
```

---

**Previous:** [Error Handling](11-error-handling.md) | **Next:** [Object-Oriented Programming](13-oop-with-tcloo.md)
