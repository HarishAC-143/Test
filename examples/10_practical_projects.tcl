#!/usr/bin/env tclsh
#
# 10_practical_projects.tcl — Real-world practical examples
#

puts "=============================="
puts " Practical TCL Projects"
puts "=============================="
puts ""

# ===================================================================
# Project 1: Word Frequency Counter
# ===================================================================
puts "=== Project 1: Word Frequency Counter ==="
puts ""

proc word_frequency {text {top_n 10}} {
    set text [string tolower $text]
    set text [regsub -all {[^\w\s]} $text ""]
    set words [regexp -all -inline {\w+} $text]

    set freq [dict create]
    foreach word $words {
        dict incr freq $word
    }

    set sorted_pairs [list]
    dict for {word count} $freq {
        lappend sorted_pairs [list $word $count]
    }
    set sorted_pairs [lsort -index 1 -integer -decreasing $sorted_pairs]

    return [lrange $sorted_pairs 0 [expr {$top_n - 1}]]
}

set sample_text "
    TCL is a powerful scripting language. TCL stands for Tool Command Language.
    TCL was created by John Ousterhout. TCL is used for rapid prototyping,
    scripted applications, GUIs, and testing. Many EDA tools use TCL for
    automation. TCL is simple yet powerful. The TCL language is easy to learn
    and TCL scripts are easy to write. TCL provides excellent string handling
    and TCL has great list operations. TCL is extensible and embeddable.
"

set top_words [word_frequency $sample_text 8]
puts "Top words:"
puts [format "  %-15s %s" "Word" "Count"]
puts "  [string repeat "-" 25]"
foreach pair $top_words {
    lassign $pair word count
    set bar [string repeat "#" $count]
    puts [format "  %-15s %3d  %s" $word $count $bar]
}
puts ""

# ===================================================================
# Project 2: Simple Calculator with Expression Parser
# ===================================================================
puts "=== Project 2: Calculator ==="
puts ""

namespace eval calc {
    variable history [list]
    variable last_result 0

    proc evaluate {expression} {
        variable history
        variable last_result

        set expression [string map {ans $last_result} $expression]

        try {
            set result [expr $expression]
            set last_result $result
            lappend history [dict create expr $expression result $result]
            return $result
        } on error {msg} {
            return "Error: $msg"
        }
    }

    proc show_history {} {
        variable history
        if {[llength $history] == 0} {
            puts "  (no calculations yet)"
            return
        }
        set i 0
        foreach entry $history {
            incr i
            puts [format "  %2d. %s = %s" $i \
                [dict get $entry expr] \
                [dict get $entry result]]
        }
    }
}

set expressions [list \
    "2 + 3 * 4" \
    "sqrt(144) + pow(2, 10)" \
    "(100 - 32) * 5.0 / 9" \
    "sin(3.14159/4)" \
    "log10(1000)" \
    "abs(-42) + ceil(3.2)" \
]

foreach expr_str $expressions {
    set result [calc::evaluate $expr_str]
    puts [format "  %-30s = %s" $expr_str $result]
}
puts ""
puts "Calculation history:"
calc::show_history
puts ""

# ===================================================================
# Project 3: Data Pipeline
# ===================================================================
puts "=== Project 3: Data Pipeline ==="
puts ""

proc pipeline {data args} {
    set result $data
    foreach step $args {
        set result [apply $step $result]
    }
    return $result
}

set raw_data [list \
    "  Alice, 95  " \
    "  Bob, 87  " \
    "  Carol, 92  " \
    "  Dave, 78  " \
    "  Eve, 88  " \
    "  Frank, 65  " \
    "  Grace, 91  " \
    "  Henry, 73  " \
]

puts "Raw data: [llength $raw_data] records"

set trim_step [list data {
    set result [list]
    foreach item $data {
        lappend result [string trim $item]
    }
    return $result
}]

set parse_step [list data {
    set result [list]
    foreach item $data {
        set parts [split $item ","]
        set name [string trim [lindex $parts 0]]
        set score [string trim [lindex $parts 1]]
        lappend result [dict create name $name score $score]
    }
    return $result
}]

set filter_step [list data {
    set result [list]
    foreach item $data {
        if {[dict get $item score] >= 80} {
            lappend result $item
        }
    }
    return $result
}]

set grade_step [list data {
    set result [list]
    foreach item $data {
        set score [dict get $item score]
        if {$score >= 90} {
            set grade "A"
        } elseif {$score >= 80} {
            set grade "B"
        } else {
            set grade "C"
        }
        dict set item grade $grade
        lappend result $item
    }
    return $result
}]

set sort_step [list data {
    return [lsort -command {apply {{a b} {
        expr {[dict get $b score] - [dict get $a score]}
    }}} $data]
}]

set processed [pipeline $raw_data $trim_step $parse_step $filter_step $grade_step $sort_step]

puts "Processed (score >= 80, sorted):"
puts [format "  %-10s %5s  %s" "Name" "Score" "Grade"]
puts "  [string repeat "-" 25]"
foreach student $processed {
    puts [format "  %-10s %5d  %s" \
        [dict get $student name] \
        [dict get $student score] \
        [dict get $student grade]]
}
puts ""

# ===================================================================
# Project 4: State Machine
# ===================================================================
puts "=== Project 4: Simple State Machine ==="
puts ""

namespace eval fsm {
    variable states [dict create]
    variable current ""
    variable name ""

    proc create {machine_name initial_state} {
        variable states
        variable current
        variable name
        set name $machine_name
        set states [dict create]
        set current $initial_state
    }

    proc add_transition {from_state event to_state {action ""}} {
        variable states
        dict set states $from_state $event [dict create target $to_state action $action]
    }

    proc process {event} {
        variable states
        variable current
        variable name

        if {![dict exists $states $current $event]} {
            puts "  ! No transition from '$current' on event '$event'"
            return
        }

        set transition [dict get $states $current $event]
        set target [dict get $transition target]
        set action [dict get $transition action]

        puts "  $current --($event)--> $target"

        if {$action ne ""} {
            uplevel #0 $action
        }

        set current $target
    }

    proc get_state {} {
        variable current
        return $current
    }
}

fsm::create "TrafficLight" "RED"
fsm::add_transition "RED"    "timer" "GREEN"  {puts "    Action: Go!"}
fsm::add_transition "GREEN"  "timer" "YELLOW" {puts "    Action: Caution!"}
fsm::add_transition "YELLOW" "timer" "RED"    {puts "    Action: Stop!"}
fsm::add_transition "RED"    "emergency" "RED" {puts "    Action: Emergency stop!"}
fsm::add_transition "GREEN"  "emergency" "RED" {puts "    Action: Emergency stop!"}
fsm::add_transition "YELLOW" "emergency" "RED" {puts "    Action: Emergency stop!"}

puts "Traffic Light Simulation:"
puts "  Initial state: [fsm::get_state]"
foreach event [list timer timer timer timer emergency timer timer] {
    fsm::process $event
}
puts "  Final state: [fsm::get_state]"
puts ""

# ===================================================================
# Project 5: Template Engine
# ===================================================================
puts "=== Project 5: Simple Template Engine ==="
puts ""

proc render_template {template data} {
    set open_each [format "%c%c#each " 123 123]
    set close_brace [format "%c%c" 125 125]
    set close_each [format "%c%c/each%c%c" 123 123 125 125]
    set dot_placeholder [format "%c%c.%c%c" 123 123 125 125]

    set result $template

    while {1} {
        set start [string first $open_each $result]
        if {$start == -1} break

        set tag_end [string first $close_brace $result [expr {$start + 8}]]
        set list_key [string range $result [expr {$start + 8}] [expr {$tag_end - 1}]]

        set end [string first $close_each $result $tag_end]
        set body [string range $result [expr {$tag_end + 2}] [expr {$end - 1}]]

        set expanded ""
        if {[dict exists $data $list_key]} {
            foreach item [dict get $data $list_key] {
                append expanded [string map [list $dot_placeholder $item] $body]
            }
        }

        set before [string range $result 0 [expr {$start - 1}]]
        set after [string range $result [expr {$end + [string length $close_each]}] end]
        set result "${before}${expanded}${after}"
    }

    dict for {key value} $data {
        set placeholder [format "%c%c%s%c%c" 123 123 $key 125 125]
        set result [string map [list $placeholder $value] $result]
    }

    return $result
}

set template {
Report: {{title}}
Date:   {{date}}
Author: {{author}}

Summary:
  Total items: {{total}}
  Status:      {{status}}

Items:
{{#each items}}  - {{.}}
{{/each}}}

set data [dict create \
    title  "Monthly Sales Report" \
    date   "2026-03-20" \
    author "Alice Johnson" \
    total  "42" \
    status "Complete" \
    items  [list "Revenue: \$125,000" "Expenses: \$89,000" "Profit: \$36,000" "Growth: 12%"] \
]

puts [render_template $template $data]

# ===================================================================
# Project 6: JSON-like Data Builder
# ===================================================================
puts "=== Project 6: Data Serializer ==="
puts ""

proc to_json {data {indent 0}} {
    set pad [string repeat "  " $indent]
    set inner_pad [string repeat "  " [expr {$indent + 1}]]

    if {[string is integer -strict $data] || [string is double -strict $data]} {
        return $data
    }

    if {$data eq "true" || $data eq "false" || $data eq "null"} {
        return $data
    }

    if {[llength $data] % 2 == 0 && [llength $data] > 0} {
        set is_dict 1
        foreach {k v} $data {
            if {![string is wordchar -strict $k] && ![regexp {^[a-zA-Z_]\w*$} $k]} {
                set is_dict 0
                break
            }
        }
        if {$is_dict} {
            set pairs [list]
            foreach {k v} $data {
                lappend pairs "${inner_pad}\"$k\": [to_json $v [expr {$indent + 1}]]"
            }
            return "\{\n[join $pairs ",\n"]\n$pad\}"
        }
    }

    if {[llength $data] > 1 || ([llength $data] == 1 && [llength [lindex $data 0]] > 1)} {
        set items [list]
        foreach item $data {
            lappend items "${inner_pad}[to_json $item [expr {$indent + 1}]]"
        }
        return "\[\n[join $items ",\n"]\n$pad\]"
    }

    return "\"[string map {\" \\\" \\ \\\\ \n \\n \t \\t} $data]\""
}

set sample_data [dict create \
    name "Alice" \
    age 30 \
    active true \
    scores [list 95 88 92] \
    address [dict create city "Boston" state "MA" zip "02101"] \
]

puts "Serialized output:"
puts [to_json $sample_data]
puts ""

puts "Done!"
