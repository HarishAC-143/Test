#!/usr/bin/env tclsh
#
# CLI Task/Todo Manager with File Persistence
# Manages tasks with priorities, categories, due dates, and status tracking.

namespace eval taskman {
    variable tasks {}
    variable next_id 1
    variable datafile "~/.tcl_tasks.json"

    proc init {{file ""}} {
        variable datafile
        if {$file ne ""} { set datafile $file }
        load_tasks
    }

    proc add {title args} {
        variable tasks
        variable next_id

        set defaults [dict create \
            priority "medium" \
            category "general" \
            due "" \
            notes ""]
        set opts [dict merge $defaults $args]

        set task [dict create \
            id $next_id \
            title $title \
            status "todo" \
            priority [dict get $opts priority] \
            category [dict get $opts category] \
            due [dict get $opts due] \
            notes [dict get $opts notes] \
            created [clock format [clock seconds] -format "%Y-%m-%d %H:%M"] \
            completed ""]

        lappend tasks $task
        set id $next_id
        incr next_id
        save_tasks
        return $id
    }

    proc complete {id} {
        variable tasks
        set idx [find_index $id]
        if {$idx < 0} { error "Task #$id not found" }

        set task [lindex $tasks $idx]
        dict set task status "done"
        dict set task completed [clock format [clock seconds] -format "%Y-%m-%d %H:%M"]
        lset tasks $idx $task
        save_tasks
    }

    proc remove {id} {
        variable tasks
        set idx [find_index $id]
        if {$idx < 0} { error "Task #$id not found" }

        set tasks [lreplace $tasks $idx $idx]
        save_tasks
    }

    proc update {id args} {
        variable tasks
        set idx [find_index $id]
        if {$idx < 0} { error "Task #$id not found" }

        set task [lindex $tasks $idx]
        dict for {key value} $args {
            dict set task $key $value
        }
        lset tasks $idx $task
        save_tasks
    }

    proc list_tasks {args} {
        variable tasks

        set filter_status ""
        set filter_category ""
        set filter_priority ""
        set sort_by "id"

        foreach {key val} $args {
            switch $key {
                -status   { set filter_status $val }
                -category { set filter_category $val }
                -priority { set filter_priority $val }
                -sort     { set sort_by $val }
            }
        }

        set filtered {}
        foreach task $tasks {
            if {$filter_status ne "" && [dict get $task status] ne $filter_status} continue
            if {$filter_category ne "" && [dict get $task category] ne $filter_category} continue
            if {$filter_priority ne "" && [dict get $task priority] ne $filter_priority} continue
            lappend filtered $task
        }

        set priority_map {high 0 medium 1 low 2}
        switch $sort_by {
            priority {
                set filtered [lsort -command [list apply {{pmap a b} {
                    set pa [expr {[dict exists $pmap [dict get $a priority]] ? [dict get $pmap [dict get $a priority]] : 9}]
                    set pb [expr {[dict exists $pmap [dict get $b priority]] ? [dict get $pmap [dict get $b priority]] : 9}]
                    expr {$pa - $pb}
                }} $priority_map] $filtered]
            }
            due {
                set filtered [lsort -command {apply {{a b} {
                    set da [dict get $a due]
                    set db [dict get $b due]
                    if {$da eq "" && $db eq ""} { return 0 }
                    if {$da eq ""} { return 1 }
                    if {$db eq ""} { return -1 }
                    string compare $da $db
                }}} $filtered]
            }
            category {
                set filtered [lsort -command {apply {{a b} {
                    string compare [dict get $a category] [dict get $b category]
                }}} $filtered]
            }
            default {
                set filtered [lsort -command {apply {{a b} {
                    expr {[dict get $a id] - [dict get $b id]}
                }}} $filtered]
            }
        }

        return $filtered
    }

    proc display {tasks_list {show_completed 0}} {
        if {[llength $tasks_list] == 0} {
            puts "  (no tasks)"
            return
        }

        set priority_symbols [dict create high "!" medium "~" low "."]

        puts [format "  %-4s %-3s %-30s %-10s %-10s %-10s" \
            "ID" "Pri" "Title" "Status" "Category" "Due"]
        puts "  [string repeat "-" 72]"

        foreach task $tasks_list {
            set id [dict get $task id]
            set pri [dict get $task priority]
            set sym [expr {[dict exists $priority_symbols $pri] ? [dict get $priority_symbols $pri] : " "}]
            set title [dict get $task title]
            set status [dict get $task status]
            set cat [dict get $task category]
            set due [dict get $task due]

            if {[string length $title] > 28} {
                set title "[string range $title 0 25]..."
            }
            if {$due eq ""} { set due "-" }

            set marker [expr {$status eq "done" ? "x" : " "}]
            puts [format "  %-4d \[$marker\] %-28s %-10s %-10s %-10s" \
                $id $title $status $cat $due]
        }
    }

    proc stats {} {
        variable tasks
        set total [llength $tasks]
        set done 0
        set todo 0
        set in_progress 0
        set overdue 0
        set today [clock format [clock seconds] -format "%Y-%m-%d"]
        array set by_category {}
        array set by_priority {}

        foreach task $tasks {
            set status [dict get $task status]
            set cat [dict get $task category]
            set pri [dict get $task priority]

            switch $status {
                done { incr done }
                "in-progress" { incr in_progress }
                default { incr todo }
            }

            if {![info exists by_category($cat)]} { set by_category($cat) 0 }
            incr by_category($cat)

            if {![info exists by_priority($pri)]} { set by_priority($pri) 0 }
            incr by_priority($pri)

            set due [dict get $task due]
            if {$due ne "" && $status ne "done" && $due < $today} {
                incr overdue
            }
        }

        puts "\n  Task Statistics"
        puts "  [string repeat "-" 30]"
        puts [format "  Total:       %4d" $total]
        puts [format "  Todo:        %4d" $todo]
        puts [format "  In Progress: %4d" $in_progress]
        puts [format "  Done:        %4d" $done]
        puts [format "  Overdue:     %4d" $overdue]

        if {$total > 0} {
            set pct [expr {$done * 100.0 / $total}]
            set bar_len [expr {int($pct / 2)}]
            puts [format "\n  Progress: \[%s%s\] %.0f%%" \
                [string repeat "#" $bar_len] \
                [string repeat " " [expr {50 - $bar_len}]] $pct]
        }

        if {[array size by_category] > 0} {
            puts "\n  By Category:"
            foreach cat [lsort [array names by_category]] {
                puts [format "    %-15s %4d" $cat $by_category($cat)]
            }
        }

        if {[array size by_priority] > 0} {
            puts "\n  By Priority:"
            foreach pri {high medium low} {
                if {[info exists by_priority($pri)]} {
                    puts [format "    %-15s %4d" $pri $by_priority($pri)]
                }
            }
        }
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

    proc save_tasks {} {
        variable tasks
        variable next_id
        variable datafile

        set filepath [file normalize $datafile]
        set data [dict create version 1 next_id $next_id tasks $tasks]

        set f [open $filepath w]
        try {
            dict for {key value} $data {
                puts $f [list $key $value]
            }
        } finally {
            close $f
        }
    }

    proc load_tasks {} {
        variable tasks
        variable next_id
        variable datafile

        set filepath [file normalize $datafile]
        if {![file exists $filepath]} {
            set tasks {}
            set next_id 1
            return
        }

        set f [open $filepath r]
        try {
            set content [read $f]
            set data [dict create]
            foreach {key value} $content {
                dict set data $key $value
            }

            if {[dict exists $data tasks]} {
                set tasks [dict get $data tasks]
            }
            if {[dict exists $data next_id]} {
                set next_id [dict get $data next_id]
            }
        } on error {msg} {
            puts stderr "Warning: Could not load tasks: $msg"
            set tasks {}
            set next_id 1
        } finally {
            close $f
        }
    }

    proc help {} {
        puts {
╔════════════════════════════════════════════════════════════╗
║                    Task Manager Commands                   ║
╠════════════════════════════════════════════════════════════╣
║  add <title> [options]     Add a new task                  ║
║    -priority high|medium|low                               ║
║    -category <name>                                        ║
║    -due <YYYY-MM-DD>                                       ║
║    -notes <text>                                           ║
║                                                            ║
║  list [filters]            List tasks                      ║
║    -status todo|done|in-progress                           ║
║    -category <name>                                        ║
║    -priority high|medium|low                               ║
║    -sort id|priority|due|category                          ║
║                                                            ║
║  done <id>                 Mark task as done               ║
║  start <id>                Mark task as in-progress        ║
║  remove <id>               Delete a task                   ║
║  edit <id> <field> <value> Update a task field             ║
║  stats                     Show statistics                 ║
║  clear-done                Remove all completed tasks      ║
║  help                      Show this help                  ║
║  quit                      Exit                            ║
╚════════════════════════════════════════════════════════════╝
        }
    }

    proc interactive {} {
        init

        puts "╔═══════════════════════════════════════╗"
        puts "║       Tcl Task Manager v1.0           ║"
        puts "║       Type 'help' for commands        ║"
        puts "╚═══════════════════════════════════════╝"

        while {1} {
            puts -nonewline "\ntask> "
            flush stdout

            if {[gets stdin input] < 0} break
            set input [string trim $input]
            if {$input eq ""} continue

            set parts [parse_command $input]
            set cmd [lindex $parts 0]
            set args [lrange $parts 1 end]

            try {
                switch -nocase $cmd {
                    quit - exit - q {
                        puts "Goodbye!"
                        break
                    }
                    help - h - "?" {
                        help
                    }
                    add - a {
                        if {[llength $args] < 1} {
                            puts "Usage: add <title> [-priority ...] [-category ...] [-due ...]"
                            continue
                        }
                        set title [lindex $args 0]
                        set opts {}
                        for {set i 1} {$i < [llength $args]} {incr i} {
                            set flag [lindex $args $i]
                            if {[string index $flag 0] eq "-"} {
                                incr i
                                dict set opts [string range $flag 1 end] [lindex $args $i]
                            } else {
                                append title " [lindex $args $i]"
                            }
                        }
                        set id [add $title {*}$opts]
                        puts "  Added task #$id: $title"
                    }
                    list - ls - l {
                        set filtered [list_tasks {*}$args]
                        display $filtered
                    }
                    done - d {
                        set id [lindex $args 0]
                        complete $id
                        puts "  Task #$id marked as done"
                    }
                    start - s {
                        set id [lindex $args 0]
                        update $id status "in-progress"
                        puts "  Task #$id marked as in-progress"
                    }
                    remove - rm {
                        set id [lindex $args 0]
                        remove $id
                        puts "  Task #$id removed"
                    }
                    edit - e {
                        set id [lindex $args 0]
                        set field [lindex $args 1]
                        set value [join [lrange $args 2 end] " "]
                        update $id $field $value
                        puts "  Task #$id updated: $field = $value"
                    }
                    stats {
                        stats
                    }
                    clear-done {
                        variable tasks
                        set before [llength $tasks]
                        set tasks [lmap t $tasks {
                            if {[dict get $t status] eq "done"} continue
                            set t
                        }]
                        set removed [expr {$before - [llength $tasks]}]
                        save_tasks
                        puts "  Removed $removed completed tasks"
                    }
                    default {
                        puts "  Unknown command: $cmd (type 'help' for commands)"
                    }
                }
            } on error {msg} {
                puts "  Error: $msg"
            }
        }
    }

    proc parse_command {input} {
        set result {}
        set current ""
        set in_quotes 0

        foreach char [split $input ""] {
            if {$char eq "\"" && !$in_quotes} {
                set in_quotes 1
            } elseif {$char eq "\"" && $in_quotes} {
                set in_quotes 0
            } elseif {$char eq " " && !$in_quotes} {
                if {$current ne ""} {
                    lappend result $current
                    set current ""
                }
            } else {
                append current $char
            }
        }
        if {$current ne ""} {
            lappend result $current
        }
        return $result
    }
}

if {[info script] eq $argv0} {
    if {[llength $argv] > 0} {
        set cmd [lindex $argv 0]
        taskman::init
        switch $cmd {
            add {
                set id [taskman::add [lindex $argv 1] {*}[lrange $argv 2 end]]
                puts "Added task #$id"
            }
            list {
                taskman::display [taskman::list_tasks {*}[lrange $argv 1 end]]
            }
            done {
                taskman::complete [lindex $argv 1]
                puts "Done."
            }
            default {
                taskman::interactive
            }
        }
    } else {
        taskman::interactive
    }
}
