#!/usr/bin/env tclsh
#
# Interactive Command-Line Calculator
# Supports arithmetic, variables, functions, and history.

namespace eval calc {
    variable history {}
    variable vars {}

    proc evaluate {expression} {
        variable vars

        set expression [string trim $expression]
        if {$expression eq ""} { return "" }

        if {[regexp {^(\w+)\s*=\s*(.+)$} $expression -> name value]} {
            set result [safe_eval $value]
            dict set vars $name $result
            return "$name = $result"
        }

        return [safe_eval $expression]
    }

    proc safe_eval {expression} {
        variable vars

        dict for {name value} $vars {
            regsub -all "\\m$name\\M" $expression $value expression
        }

        set allowed_funcs {
            abs acos asin atan atan2 ceil cos cosh
            double exp floor fmod hypot int log log10
            max min pow rand round sin sinh sqrt tan tanh wide
        }

        if {[regexp {[;\[\]]} $expression]} {
            error "Invalid characters in expression"
        }

        return [expr $expression]
    }

    proc show_help {} {
        puts {
╔════════════════════════════════════════════════════════════╗
║                    Tcl Calculator Help                     ║
╠════════════════════════════════════════════════════════════╣
║  Arithmetic:   2 + 3, 10 - 4, 6 * 7, 15 / 4, 2 ** 10    ║
║  Modulo:       17 % 5                                      ║
║  Parentheses:  (2 + 3) * 4                                 ║
║  Functions:    sqrt(16), sin(3.14), abs(-5), log(100)      ║
║                ceil(3.2), floor(3.8), round(3.5)           ║
║                max(1,2,3), min(1,2,3), pow(2,10)           ║
║                rand() - random number [0,1)                ║
║  Variables:    x = 42, then use x in expressions           ║
║  Constants:    pi, e (predefined)                          ║
║  History:      Type 'history' to see past calculations     ║
║  Variables:    Type 'vars' to see stored variables         ║
║  Clear:        Type 'clear' to reset                       ║
║  Quit:         Type 'quit' or 'exit'                       ║
╚════════════════════════════════════════════════════════════╝
        }
    }

    proc show_history {} {
        variable history
        if {[llength $history] == 0} {
            puts "  (no history)"
            return
        }
        set i 1
        foreach entry $history {
            lassign $entry expr result
            puts [format "  %3d. %s = %s" $i $expr $result]
            incr i
        }
    }

    proc show_vars {} {
        variable vars
        if {[dict size $vars] == 0} {
            puts "  (no variables)"
            return
        }
        dict for {name value} $vars {
            puts [format "  %-15s = %s" $name $value]
        }
    }

    proc run {} {
        variable history
        variable vars

        dict set vars pi 3.14159265358979
        dict set vars e 2.71828182845905

        puts "╔═══════════════════════════════════════╗"
        puts "║     Tcl Interactive Calculator        ║"
        puts "║     Type 'help' for instructions      ║"
        puts "╚═══════════════════════════════════════╝"

        while {1} {
            puts -nonewline "\ncalc> "
            flush stdout

            if {[gets stdin input] < 0} break
            set input [string trim $input]
            if {$input eq ""} continue

            switch -nocase $input {
                quit - exit {
                    puts "Goodbye!"
                    break
                }
                help {
                    show_help
                    continue
                }
                history {
                    show_history
                    continue
                }
                vars {
                    show_vars
                    continue
                }
                clear {
                    set history {}
                    set vars {}
                    dict set vars pi 3.14159265358979
                    dict set vars e 2.71828182845905
                    puts "  Cleared."
                    continue
                }
            }

            if {[catch {evaluate $input} result]} {
                puts "  Error: $result"
            } else {
                puts "  = $result"
                lappend history [list $input $result]
            }
        }
    }
}

if {[info script] eq $argv0} {
    calc::run
}
