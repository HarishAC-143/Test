#!/usr/bin/env tclsh
# =============================================================================
# Practical Example: Command-Line Task Manager
# =============================================================================
# A persistent to-do list manager supporting add, complete, delete, list,
# filter, priorities, and categories. Data stored as a Tcl-readable file.
# Demonstrates: file I/O, dicts, lists, procedures, namespaces, formatting.
# =============================================================================

namespace eval TaskManager {
    variable tasks {}
    variable next_id 1
    variable data_file ""

    proc init {{filepath ""}} {
        variable data_file
        if {$filepath eq ""} {
            set data_file "/tmp/tcl_tasks.dat"
        } else {
            set data_file $filepath
        }
        load_tasks
    }

    proc load_tasks {} {
        variable tasks
        variable next_id
        variable data_file

        set tasks {}
        set next_id 1

        if {[file exists $data_file]} {
            try {
                set fd [open $data_file r]
                set content [read $fd]
                close $fd
                set tasks [lindex $content 0]
                set next_id [lindex $content 1]
            } on error {msg} {
                puts "Warning: Could not load tasks: $msg"
                set tasks {}
                set next_id 1
            }
        }
    }

    proc save_tasks {} {
        variable tasks
        variable next_id
        variable data_file

        try {
            set fd [open $data_file w]
            puts $fd [list $tasks $next_id]
            close $fd
        } on error {msg} {
            puts "Error saving tasks: $msg"
        }
    }

    proc add {title {priority "medium"} {category "general"} {due ""}} {
        variable tasks
        variable next_id

        set task [dict create \
            id $next_id \
            title $title \
            priority $priority \
            category $category \
            status "pending" \
            created [clock format [clock seconds] -format {%Y-%m-%d %H:%M}] \
            due $due \
            completed_at "" \
        ]

        lappend tasks $task
        set id $next_id
        incr next_id
        save_tasks
        return $id
    }

    proc complete {id} {
        variable tasks

        set idx [find_index $id]
        if {$idx == -1} {
            error "Task $id not found"
        }

        set task [lindex $tasks $idx]
        dict set task status "completed"
        dict set task completed_at [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]
        lset tasks $idx $task
        save_tasks
        return $task
    }

    proc delete {id} {
        variable tasks

        set idx [find_index $id]
        if {$idx == -1} {
            error "Task $id not found"
        }

        set task [lindex $tasks $idx]
        set tasks [lreplace $tasks $idx $idx]
        save_tasks
        return $task
    }

    proc update {id args} {
        variable tasks

        set idx [find_index $id]
        if {$idx == -1} {
            error "Task $id not found"
        }

        set task [lindex $tasks $idx]
        foreach {key value} $args {
            dict set task $key $value
        }
        lset tasks $idx $task
        save_tasks
        return $task
    }

    proc find_index {id} {
        variable tasks
        for {set i 0} {$i < [llength $tasks]} {incr i} {
            if {[dict get [lindex $tasks $i] id] == $id} {
                return $i
            }
        }
        return -1
    }

    proc list_tasks {{filter_status ""} {filter_category ""} {filter_priority ""}} {
        variable tasks

        set result {}
        foreach task $tasks {
            if {$filter_status ne "" && [dict get $task status] ne $filter_status} continue
            if {$filter_category ne "" && [dict get $task category] ne $filter_category} continue
            if {$filter_priority ne "" && [dict get $task priority] ne $filter_priority} continue
            lappend result $task
        }
        return $result
    }

    proc search {query} {
        variable tasks
        set result {}
        foreach task $tasks {
            if {[string match -nocase "*$query*" [dict get $task title]]} {
                lappend result $task
            }
        }
        return $result
    }

    proc stats {} {
        variable tasks

        set total [llength $tasks]
        set pending 0
        set completed 0
        set by_priority [dict create high 0 medium 0 low 0]
        set by_category [dict create]

        foreach task $tasks {
            set status [dict get $task status]
            if {$status eq "pending"} { incr pending }
            if {$status eq "completed"} { incr completed }

            set pri [dict get $task priority]
            if {[dict exists $by_priority $pri]} {
                dict incr by_priority $pri
            }

            set cat [dict get $task category]
            dict incr by_category $cat
        }

        return [dict create \
            total $total \
            pending $pending \
            completed $completed \
            completion_rate [expr {$total > 0 ? double($completed) / $total * 100 : 0}] \
            by_priority $by_priority \
            by_category $by_category \
        ]
    }

    proc format_task {task {compact false}} {
        set id [dict get $task id]
        set title [dict get $task title]
        set status [dict get $task status]
        set priority [dict get $task priority]
        set category [dict get $task category]

        set status_icon [expr {$status eq "completed" ? "\[x\]" : "\[ \]"}]
        set pri_label ""
        switch $priority {
            high   { set pri_label "!!!" }
            medium { set pri_label " ! " }
            low    { set pri_label " . " }
        }

        if {$compact} {
            return [format "%s #%-3d %s %-30s \[%s\] (%s)" \
                $status_icon $id $pri_label $title $category $priority]
        }

        set output ""
        append output [format "%s Task #%d\n" $status_icon $id]
        append output [format "    Title:    %s\n" $title]
        append output [format "    Priority: %s\n" $priority]
        append output [format "    Category: %s\n" $category]
        append output [format "    Status:   %s\n" $status]
        append output [format "    Created:  %s\n" [dict get $task created]]
        if {[dict get $task due] ne ""} {
            append output [format "    Due:      %s\n" [dict get $task due]]
        }
        if {[dict get $task completed_at] ne ""} {
            append output [format "    Done:     %s\n" [dict get $task completed_at]]
        }
        return $output
    }

    proc format_list {tasks_list {compact true}} {
        if {[llength $tasks_list] == 0} {
            return "  (no tasks)\n"
        }

        set priority_order {high 0 medium 1 low 2}
        set sorted [lsort -command [list apply {{a b} {
            set pa [dict get $a priority]
            set pb [dict get $b priority]
            set order {high 0 medium 1 low 2}
            set oa [expr {[dict exists $order $pa] ? [dict get $order $pa] : 1}]
            set ob [expr {[dict exists $order $pb] ? [dict get $order $pb] : 1}]
            if {$oa != $ob} { return [expr {$oa - $ob}] }
            return [expr {[dict get $a id] - [dict get $b id]}]
        }}] $tasks_list]

        set output ""
        foreach task $sorted {
            append output "  [format_task $task $compact]\n"
        }
        return $output
    }

    proc format_stats {} {
        set s [stats]
        set output ""
        append output "╔══════════════════════════════════╗\n"
        append output "║        Task Statistics           ║\n"
        append output "╠══════════════════════════════════╣\n"
        append output [format "║ Total:       %4d               ║\n" [dict get $s total]]
        append output [format "║ Pending:     %4d               ║\n" [dict get $s pending]]
        append output [format "║ Completed:   %4d               ║\n" [dict get $s completed]]
        append output [format "║ Done:       %5.1f%%              ║\n" [dict get $s completion_rate]]
        append output "╠══════════════════════════════════╣\n"
        append output "║ By Priority:                     ║\n"
        dict for {pri count} [dict get $s by_priority] {
            append output [format "║   %-10s %4d               ║\n" $pri $count]
        }
        append output "╠══════════════════════════════════╣\n"
        append output "║ By Category:                     ║\n"
        dict for {cat count} [dict get $s by_category] {
            append output [format "║   %-10s %4d               ║\n" $cat $count]
        }
        append output "╚══════════════════════════════════╝\n"
        return $output
    }
}

# =============================================================================
# Demo
# =============================================================================

puts "╔══════════════════════════════════════════════╗"
puts "║        Task Manager Demo                     ║"
puts "╚══════════════════════════════════════════════╝\n"

TaskManager::init "/tmp/tcl_task_demo.dat"

puts "=== Adding Tasks ==="
set id1 [TaskManager::add "Design database schema" "high" "backend" "2026-03-25"]
puts "  Added task #$id1"
set id2 [TaskManager::add "Write API endpoints" "high" "backend" "2026-03-28"]
puts "  Added task #$id2"
set id3 [TaskManager::add "Create login page" "medium" "frontend" "2026-03-26"]
puts "  Added task #$id3"
set id4 [TaskManager::add "Set up CI/CD pipeline" "medium" "devops" "2026-03-30"]
puts "  Added task #$id4"
set id5 [TaskManager::add "Write unit tests" "high" "backend" "2026-03-27"]
puts "  Added task #$id5"
set id6 [TaskManager::add "Update README documentation" "low" "general"]
puts "  Added task #$id6"
set id7 [TaskManager::add "Code review PR #42" "medium" "backend"]
puts "  Added task #$id7"
set id8 [TaskManager::add "Optimize database queries" "low" "backend" "2026-04-05"]
puts "  Added task #$id8"

puts "\n=== All Tasks ==="
puts [TaskManager::format_list [TaskManager::list_tasks]]

puts "=== Completing Tasks ==="
TaskManager::complete $id1
puts "  Completed task #$id1"
TaskManager::complete $id3
puts "  Completed task #$id3"

puts "\n=== Pending Tasks ==="
puts [TaskManager::format_list [TaskManager::list_tasks "pending"]]

puts "=== Completed Tasks ==="
puts [TaskManager::format_list [TaskManager::list_tasks "completed"]]

puts "=== High Priority Tasks ==="
puts [TaskManager::format_list [TaskManager::list_tasks "" "" "high"]]

puts "=== Backend Tasks ==="
puts [TaskManager::format_list [TaskManager::list_tasks "" "backend"]]

puts "=== Search: 'database' ==="
puts [TaskManager::format_list [TaskManager::search "database"]]

puts "=== Task Detail View ==="
set all [TaskManager::list_tasks]
puts [TaskManager::format_task [lindex $all 0] false]

puts "=== Updating Task ==="
TaskManager::update $id4 priority "high" title "Set up CI/CD pipeline (urgent)"
puts "  Updated task #$id4"
puts [TaskManager::format_task [lindex [TaskManager::list_tasks] [TaskManager::find_index $id4]] false]

puts "=== Statistics ==="
puts [TaskManager::format_stats]

puts "=== Deleting a Task ==="
TaskManager::delete $id8
puts "  Deleted task #$id8"
puts "  Remaining tasks: [llength [TaskManager::list_tasks]]"

file delete "/tmp/tcl_task_demo.dat"
