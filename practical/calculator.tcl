#!/usr/bin/env tclsh
# =============================================================================
# Practical Example: Interactive Command-Line Calculator
# =============================================================================
# A feature-rich calculator with variable storage, expression history,
# built-in functions, and a help system.
# Demonstrates: expr, procedures, error handling, string processing, dicts.
# =============================================================================

namespace eval Calculator {
    variable history {}
    variable variables [dict create \
        pi  3.14159265358979 \
        e   2.71828182845905 \
        tau 6.28318530717959 \
        phi 1.61803398874989 \
    ]

    proc evaluate {expression} {
        variable history
        variable variables

        set expr_str $expression

        # Replace $varname references first
        dict for {name value} $variables {
            set expr_str [string map [list "\$$name" $value] $expr_str]
        }

        # Replace bare variable names only as whole words (not inside other words)
        # Sort by length descending to replace longer names first
        set sorted_names {}
        dict for {name value} $variables {
            lappend sorted_names [list $name $value]
        }
        set sorted_names [lsort -index 0 -command {apply {{a b} {
            expr {[string length [lindex $b 0]] - [string length [lindex $a 0]]}
        }}} $sorted_names]

        foreach pair $sorted_names {
            lassign $pair name value
            regsub -all "\\m${name}\\M" $expr_str $value expr_str
        }

        set expr_str [preprocess $expr_str]

        try {
            set result [expr $expr_str]
            lappend history [dict create \
                input $expression \
                result $result \
                time [clock format [clock seconds] -format {%H:%M:%S}] \
            ]
            return $result
        } on error {msg} {
            error "Evaluation error: $msg"
        }
    }

    proc preprocess {expr_str} {
        set expr_str [string map {
            "^"    "**"
            "mod"  "%"
            "and"  "&&"
            "or"   "||"
            "not"  "!"
        } $expr_str]

        set expr_str [regsub -all {log2\(([^)]+)\)} $expr_str {(log(\1)/log(2))}]
        set expr_str [regsub -all {deg2rad\(([^)]+)\)} $expr_str {((\1)*3.14159265358979/180.0)}]
        set expr_str [regsub -all {rad2deg\(([^)]+)\)} $expr_str {((\1)*180.0/3.14159265358979)}]
        set expr_str [regsub -all {fact\(([^)]+)\)} $expr_str {[::Calculator::factorial_expr \1]}]

        return $expr_str
    }

    proc factorial_expr {n} {
        set n [expr {int($n)}]
        if {$n < 0} { error "Factorial undefined for negative numbers" }
        if {$n <= 1} { return 1 }
        set result 1
        for {set i 2} {$i <= $n} {incr i} {
            set result [expr {$result * $i}]
        }
        return $result
    }

    proc set_var {name value} {
        variable variables
        dict set variables $name $value
        return $value
    }

    proc get_var {name} {
        variable variables
        if {[dict exists $variables $name]} {
            return [dict get $variables $name]
        }
        error "Undefined variable: $name"
    }

    proc list_vars {} {
        variable variables
        set result ""
        dict for {name value} $variables {
            append result [format "  %-10s = %s\n" $name $value]
        }
        return $result
    }

    proc show_history {{count 10}} {
        variable history
        set result ""
        set start [expr {max(0, [llength $history] - $count)}]
        set idx $start
        foreach entry [lrange $history $start end] {
            incr idx
            append result [format "  %3d. \[%s\] %s = %s\n" \
                $idx \
                [dict get $entry time] \
                [dict get $entry input] \
                [dict get $entry result]]
        }
        if {$result eq ""} {
            return "  (no history)\n"
        }
        return $result
    }

    proc clear_history {} {
        variable history
        set history {}
    }

    proc help {} {
        return {
  Calculator Commands:
  ────────────────────────────────────────────────────
  <expression>         Evaluate a math expression
  let <name> = <expr>  Store result in a variable
  vars                 List all variables
  history [n]          Show last n entries (default: 10)
  clear                Clear history
  help                 Show this help message
  quit / exit          Exit the calculator

  Operators:
    +  -  *  /  %  **  (or ^)
    ==  !=  <  >  <=  >=
    &&  ||  !  (or: and  or  not)

  Built-in Functions:
    abs(x)  sqrt(x)  pow(x,y)  exp(x)  log(x)  log10(x)  log2(x)
    sin(x)  cos(x)  tan(x)  asin(x)  acos(x)  atan(x)  atan2(y,x)
    ceil(x)  floor(x)  round(x)  int(x)  double(x)
    min(x,y)  max(x,y)  hypot(x,y)  fmod(x,y)
    rand()  srand(x)
    deg2rad(x)  rad2deg(x)  fact(n)

  Constants:
    pi = 3.14159...  e = 2.71828...
    tau = 6.28318... phi = 1.61803...

  Examples:
    2 + 3 * 4           → 14
    sqrt(144)           → 12.0
    sin(pi/2)           → 1.0
    let r = 5
    pi * r^2            → 78.5398...
    fact(10)            → 3628800
  ────────────────────────────────────────────────────
}
    }

    proc process_command {input} {
        set input [string trim $input]

        if {$input eq ""} {
            return ""
        }

        switch -glob -- $input {
            "quit" - "exit" - "q" {
                return "EXIT"
            }
            "help" - "?" {
                return [help]
            }
            "vars" - "variables" {
                return "Variables:\n[list_vars]"
            }
            "history*" {
                set count 10
                if {[regexp {^history\s+(\d+)$} $input _ n]} {
                    set count $n
                }
                return "History (last $count):\n[show_history $count]"
            }
            "clear" {
                clear_history
                return "  History cleared."
            }
            "let *" {
                if {[regexp {^let\s+(\w+)\s*=\s*(.+)$} $input _ name expr]} {
                    try {
                        set value [evaluate $expr]
                        set_var $name $value
                        return "  $name = $value"
                    } on error {msg} {
                        return "  Error: $msg"
                    }
                }
                return "  Usage: let <name> = <expression>"
            }
            default {
                try {
                    set result [evaluate $input]
                    return "  = $result"
                } on error {msg} {
                    return "  Error: $msg"
                }
            }
        }
    }

    proc run_interactive {} {
        puts "╔══════════════════════════════════════════╗"
        puts "║       Tcl Interactive Calculator         ║"
        puts "║     Type 'help' for commands, 'quit'     ║"
        puts "╚══════════════════════════════════════════╝"
        puts ""

        while {1} {
            puts -nonewline "calc> "
            flush stdout

            if {[gets stdin input] < 0} break

            set output [process_command $input]
            if {$output eq "EXIT"} {
                puts "Goodbye!"
                break
            }
            if {$output ne ""} {
                puts $output
            }
        }
    }

    proc run_demo {} {
        puts "╔══════════════════════════════════════════╗"
        puts "║    Tcl Calculator — Demo Mode            ║"
        puts "╚══════════════════════════════════════════╝\n"

        set demo_inputs {
            "2 + 3 * 4"
            "sqrt(144)"
            "sin(pi / 2)"
            "log10(1000)"
            "2 ^ 10"
            "let radius = 5"
            "pi * radius ^ 2"
            "let circumference = 2 * pi * radius"
            "circumference"
            "fact(10)"
            "log2(1024)"
            "deg2rad(180)"
            "rad2deg(pi)"
            "abs(-42) + sqrt(16)"
            "(3 + 4) * (5 - 2) / 7"
            "vars"
            "history"
        }

        foreach input $demo_inputs {
            puts "calc> $input"
            set output [process_command $input]
            if {$output ne ""} {
                puts $output
            }
            puts ""
        }
    }
}

# --- Main ---
if {[llength $argv] > 0 && [lindex $argv 0] eq "-i"} {
    Calculator::run_interactive
} else {
    Calculator::run_demo
}
