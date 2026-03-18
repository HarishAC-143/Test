#!/usr/bin/env tclsh
# =============================================================================
# Example 14: Practical - Command-Line TODO Application
# A complete TODO app with add, list, complete, delete, save/load, and search.
# =============================================================================

puts "=== Command-Line TODO Application ===\n"

namespace eval TodoApp {
    variable todos [list]
    variable next_id 1
    variable filename ""

    proc init {{file ""}} {
        variable filename
        set filename $file
        if {$file ne "" && [file exists $file]} {
            load $file
        }
    }

    proc add {title {priority "medium"} {category "general"}} {
        variable todos
        variable next_id

        set todo [dict create \
            id       $next_id \
            title    $title \
            priority $priority \
            category $category \
            done     0 \
            created  [clock format [clock seconds] -format "%Y-%m-%d %H:%M"] \
        ]

        lappend todos $todo
        set id $next_id
        incr next_id
        return $id
    }

    proc complete {id} {
        variable todos
        set idx [find_index $id]
        if {$idx < 0} { error "TODO #$id not found" }
        set todo [lindex $todos $idx]
        dict set todo done 1
        lset todos $idx $todo
    }

    proc delete {id} {
        variable todos
        set idx [find_index $id]
        if {$idx < 0} { error "TODO #$id not found" }
        set todos [lreplace $todos $idx $idx]
    }

    proc list_todos {{filter "all"}} {
        variable todos

        set filtered [list]
        foreach todo $todos {
            switch $filter {
                "all"      { lappend filtered $todo }
                "pending"  { if {![dict get $todo done]} { lappend filtered $todo } }
                "done"     { if {[dict get $todo done]}  { lappend filtered $todo } }
                "high"     { if {[dict get $todo priority] eq "high"} { lappend filtered $todo } }
            }
        }
        return $filtered
    }

    proc search {query} {
        variable todos
        set results [list]
        foreach todo $todos {
            if {[string match -nocase "*$query*" [dict get $todo title]]} {
                lappend results $todo
            }
        }
        return $results
    }

    proc display {todo_list} {
        if {[llength $todo_list] == 0} {
            puts "  (no items)"
            return
        }

        puts [format "  %-4s %-6s %-8s %-10s %-16s %s" \
            "ID" "Status" "Priority" "Category" "Created" "Title"]
        puts "  [string repeat - 70]"

        foreach todo $todo_list {
            set status [expr {[dict get $todo done] ? "\[X\]" : "\[ \]"}]
            set pri [dict get $todo priority]

            set pri_display $pri
            if {$pri eq "high"} {
                set pri_display "HIGH!"
            }

            puts [format "  %-4d %-6s %-8s %-10s %-16s %s" \
                [dict get $todo id] \
                $status \
                $pri_display \
                [dict get $todo category] \
                [dict get $todo created] \
                [dict get $todo title]]
        }
    }

    proc stats {} {
        variable todos
        set total [llength $todos]
        set done 0
        set pending 0
        array set by_priority {}
        array set by_category {}

        foreach todo $todos {
            if {[dict get $todo done]} {
                incr done
            } else {
                incr pending
            }

            set pri [dict get $todo priority]
            set cat [dict get $todo category]

            if {[info exists by_priority($pri)]} {
                incr by_priority($pri)
            } else {
                set by_priority($pri) 1
            }
            if {[info exists by_category($cat)]} {
                incr by_category($cat)
            } else {
                set by_category($cat) 1
            }
        }

        puts "  --- Statistics ---"
        puts "  Total:    $total"
        puts "  Done:     $done"
        puts "  Pending:  $pending"
        if {$total > 0} {
            puts [format "  Progress: %.1f%%" [expr {100.0 * $done / $total}]]
        }

        puts "\n  By Priority:"
        foreach pri [lsort [array names by_priority]] {
            puts "    $pri: $by_priority($pri)"
        }

        puts "\n  By Category:"
        foreach cat [lsort [array names by_category]] {
            puts "    $cat: $by_category($cat)"
        }
    }

    proc save {{file ""}} {
        variable todos
        variable filename
        variable next_id

        if {$file eq ""} { set file $filename }
        if {$file eq ""} { error "No filename specified" }

        set fp [open $file w]
        puts $fp "next_id $next_id"
        foreach todo $todos {
            puts $fp [list todo $todo]
        }
        close $fp
    }

    proc load {{file ""}} {
        variable todos
        variable filename
        variable next_id

        if {$file eq ""} { set file $filename }
        if {$file eq ""} { error "No filename specified" }

        set todos [list]
        set fp [open $file r]
        while {[gets $fp line] >= 0} {
            if {[lindex $line 0] eq "next_id"} {
                set next_id [lindex $line 1]
            } elseif {[lindex $line 0] eq "todo"} {
                lappend todos [lindex $line 1]
            }
        }
        close $fp
    }

    # Internal helper
    proc find_index {id} {
        variable todos
        for {set i 0} {$i < [llength $todos]} {incr i} {
            if {[dict get [lindex $todos $i] id] == $id} {
                return $i
            }
        }
        return -1
    }
}

# === Demo ===

TodoApp::init

# Add some tasks
TodoApp::add "Set up development environment" "high" "dev"
TodoApp::add "Write unit tests for auth module" "high" "dev"
TodoApp::add "Design database schema" "high" "dev"
TodoApp::add "Create API documentation" "medium" "docs"
TodoApp::add "Review pull requests" "medium" "dev"
TodoApp::add "Update README file" "low" "docs"
TodoApp::add "Fix login page CSS" "medium" "bug"
TodoApp::add "Optimize database queries" "high" "perf"
TodoApp::add "Add search functionality" "medium" "feature"
TodoApp::add "Write deployment script" "low" "ops"

puts "--- All Tasks ---"
TodoApp::display [TodoApp::list_todos]

# Complete some tasks
TodoApp::complete 1
TodoApp::complete 3
TodoApp::complete 6

puts "\n--- After Completing Tasks 1, 3, 6 ---"
TodoApp::display [TodoApp::list_todos]

# Show pending only
puts "\n--- Pending Tasks ---"
TodoApp::display [TodoApp::list_todos "pending"]

# Show completed only
puts "\n--- Completed Tasks ---"
TodoApp::display [TodoApp::list_todos "done"]

# Show high priority
puts "\n--- High Priority ---"
TodoApp::display [TodoApp::list_todos "high"]

# Search
puts "\n--- Search: 'database' ---"
TodoApp::display [TodoApp::search "database"]

puts "\n--- Search: 'script' ---"
TodoApp::display [TodoApp::search "script"]

# Delete a task
TodoApp::delete 10
puts "\n--- After Deleting Task 10 ---"
TodoApp::display [TodoApp::list_todos]

# Statistics
puts ""
TodoApp::stats

# Save and reload
set tmpfile "/tmp/tcl_todos_demo.dat"
TodoApp::save $tmpfile
puts "\n  Saved to $tmpfile"

# Cleanup
file delete -force $tmpfile

puts "\nDone."
