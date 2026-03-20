#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 20: Metaprogramming
# =============================================================================

puts "=== Introspection with info ==="
proc sample_proc {a b {c 10}} {
    set local_var "hello"
    return [expr {$a + $b + $c}]
}

puts "Proc 'sample_proc' exists: [expr {[info procs sample_proc] ne {}}]"
puts "Arguments: [info args sample_proc]"
puts "Body: [info body sample_proc]"

set has_default [info default sample_proc c default_val]
puts "Param 'c' has default: $has_default (value: $default_val)"

puts "\nAll user-defined procs: [lsort [info procs]]"

puts "\n=== Dynamic Command Creation ==="
proc make_accessor {name} {
    proc get_$name {} [format {
        global %s
        return $%s
    } $name $name]

    proc set_$name {value} [format {
        global %s
        set %s $value
    } $name $name]
}

make_accessor username
set_username "Alice"
puts "Username: [get_username]"

make_accessor email
set_email "alice@example.com"
puts "Email: [get_email]"

puts "\n=== Dynamic Procedure Generation ==="
proc make_greeter {language greeting} {
    proc greet_in_$language {name} [format {
        return "%s, $name!"
    } $greeting]
}

make_greeter english "Hello"
make_greeter french "Bonjour"
make_greeter spanish "Hola"
make_greeter german "Guten Tag"
make_greeter japanese "Konnichiwa"

foreach lang {english french spanish german japanese} {
    puts "  [greet_in_$lang "World"]"
}

puts "\n=== apply — Anonymous Procedures (Lambdas) ==="
set double [list x {expr {$x * 2}}]
set square [list x {expr {$x * $x}}]
set negate [list x {expr {-$x}}]

puts "double(5) = [apply $double 5]"
puts "square(5) = [apply $square 5]"
puts "negate(5) = [apply $negate 5]"

puts "\n=== Higher-Order Functions ==="
proc map {func lst} {
    set result {}
    foreach item $lst {
        lappend result [apply $func $item]
    }
    return $result
}

proc filter {func lst} {
    set result {}
    foreach item $lst {
        if {[apply $func $item]} {
            lappend result $item
        }
    }
    return $result
}

proc reduce {func initial lst} {
    set acc $initial
    foreach item $lst {
        set acc [apply $func $acc $item]
    }
    return $acc
}

set numbers {1 2 3 4 5 6 7 8 9 10}

puts "Numbers: $numbers"
puts "Doubled: [map {x {expr {$x * 2}}} $numbers]"
puts "Squared: [map {x {expr {$x * $x}}} $numbers]"
puts "Even:    [filter {x {expr {$x % 2 == 0}}} $numbers]"
puts "Sum:     [reduce {acc x {expr {$acc + $x}}} 0 $numbers]"
puts "Product: [reduce {acc x {expr {$acc * $x}}} 1 [lrange $numbers 0 4]]"

set strings {hello world foo bar baz}
puts "\nStrings: $strings"
puts "Uppered: [map {s {string toupper $s}} $strings]"
puts "Long (>3): [filter {s {expr {[string length $s] > 3}}} $strings]"
puts "Joined: [reduce {a b {string cat $a "-" $b}} "" [lrange $strings 0 end]]"

puts "\n=== Function Composition ==="
proc compose {f g} {
    return [list x [format {apply {%s} [apply {%s} $x]} $f $g]]
}

set double_then_square [compose {x {expr {$x * $x}}} {x {expr {$x * 2}}}]
puts "double then square of 3: [apply $double_then_square 3]"

puts "\n=== Pipeline Pattern ==="
proc pipeline {value args} {
    foreach func $args {
        set value [apply $func $value]
    }
    return $value
}

set result [pipeline "  Hello, World!  " \
    {s {string trim $s}} \
    {s {string toupper $s}} \
    {s {string map {" " "_"} $s}} \
]
puts "Pipeline result: $result"

puts "\n=== Dynamic Dispatch ==="
namespace eval shapes {
    proc create {type args} {
        set shape [dict create type $type {*}$args]
        return $shape
    }

    proc area {shape} {
        set type [dict get $shape type]
        switch $type {
            circle {
                set r [dict get $shape radius]
                return [expr {3.14159 * $r * $r}]
            }
            rectangle {
                set w [dict get $shape width]
                set h [dict get $shape height]
                return [expr {$w * $h}]
            }
            triangle {
                set b [dict get $shape base]
                set h [dict get $shape height]
                return [expr {0.5 * $b * $h}]
            }
            default {
                error "Unknown shape type: $type"
            }
        }
    }
}

set shapes_list [list \
    [shapes::create circle radius 5] \
    [shapes::create rectangle width 4 height 6] \
    [shapes::create triangle base 3 height 8] \
]

foreach s $shapes_list {
    puts [format "  %-10s area = %.2f" [dict get $s type] [shapes::area $s]]
}

puts "\n=== Code Generation ==="
proc generate_struct {name fields} {
    set body "namespace eval $name \{\n"
    append body "    proc create \{[join $fields " "]\} \{\n"
    append body "        dict create"
    foreach f $fields {
        append body " $f \$$f"
    }
    append body "\n    \}\n"

    foreach f $fields {
        append body "    proc get_$f \{obj\} \{\n"
        append body "        dict get \$obj $f\n"
        append body "    \}\n"
    }

    append body "\}\n"
    eval $body
}

generate_struct person {name age email}

set p [person::create "Alice" 30 "alice@example.com"]
puts "Person: $p"
puts "Name: [person::get_name $p]"
puts "Age: [person::get_age $p]"
puts "Email: [person::get_email $p]"

puts "\n=== Practical: Simple DSL ==="
namespace eval html {
    proc tag {name args} {
        set attrs ""
        set content ""

        if {[llength $args] >= 2} {
            set attr_dict [lindex $args 0]
            set content [lindex $args 1]
            dict for {k v} $attr_dict {
                append attrs " $k=\"$v\""
            }
        } elseif {[llength $args] == 1} {
            set content [lindex $args 0]
        }

        return "<$name$attrs>$content</$name>"
    }

    proc h1 {args} { tag h1 {*}$args }
    proc h2 {args} { tag h2 {*}$args }
    proc p {args} { tag p {*}$args }
    proc div {args} { tag div {*}$args }
    proc span {args} { tag span {*}$args }
    proc a {args} { tag a {*}$args }
    proc ul {items} {
        set li_items ""
        foreach item $items {
            append li_items [tag li $item]
        }
        return [tag ul $li_items]
    }
}

set page [html::div {class "container"} [join [list \
    [html::h1 "Welcome to Tcl"] \
    [html::p {class "intro"} "Tcl is a powerful scripting language."] \
    [html::p "Features:"] \
    [html::ul {"Simple syntax" "Dynamic typing" "Extensible" "Cross-platform"}] \
    [html::p [html::a {href "https://www.tcl.tk"} "Learn more"]] \
] "\n"]]

puts "Generated HTML:"
puts $page
