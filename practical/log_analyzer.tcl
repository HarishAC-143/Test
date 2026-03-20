#!/usr/bin/env tclsh
# =============================================================================
# Practical Example: Log File Analyzer
# =============================================================================
# Parses structured log files, extracts statistics, identifies patterns,
# and generates a summary report. Demonstrates file I/O, regex, dicts,
# procedures, and string formatting.
# =============================================================================

namespace eval LogAnalyzer {
    variable stats

    proc init {} {
        variable stats
        set stats [dict create \
            total_lines 0 \
            by_level [dict create] \
            by_hour [dict create] \
            errors [list] \
            warnings [list] \
            unique_sources [dict create] \
            first_timestamp "" \
            last_timestamp "" \
        ]
    }

    proc parse_line {line} {
        if {[regexp {^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+\[(\w+)\]\s+\[([^\]]*)\]\s+(.*)$} \
                $line _ timestamp level source message]} {
            return [dict create \
                timestamp $timestamp \
                level $level \
                source $source \
                message $message \
                raw $line \
            ]
        }
        return ""
    }

    proc analyze_entry {entry} {
        variable stats

        dict incr stats total_lines

        set level [dict get $entry level]
        set timestamp [dict get $entry timestamp]
        set source [dict get $entry source]
        set message [dict get $entry message]

        dict incr [dict get $stats by_level] $level
        dict set stats by_level [dict get $stats by_level]

        regexp {\d{4}-\d{2}-\d{2}\s+(\d{2}):} $timestamp _ hour
        set hourly [dict get $stats by_hour]
        dict incr hourly $hour
        dict set stats by_hour $hourly

        set sources [dict get $stats unique_sources]
        dict incr sources $source
        dict set stats unique_sources $sources

        if {[dict get $stats first_timestamp] eq ""} {
            dict set stats first_timestamp $timestamp
        }
        dict set stats last_timestamp $timestamp

        if {$level eq "ERROR"} {
            dict lappend stats errors $entry
        } elseif {$level eq "WARNING"} {
            dict lappend stats warnings $entry
        }
    }

    proc analyze_file {filepath} {
        init

        if {![file exists $filepath]} {
            error "Log file not found: $filepath"
        }

        set fd [open $filepath r]
        while {[gets $fd line] >= 0} {
            set line [string trim $line]
            if {$line eq ""} continue
            set entry [parse_line $line]
            if {$entry ne ""} {
                analyze_entry $entry
            }
        }
        close $fd
    }

    proc analyze_lines {lines} {
        init
        foreach line $lines {
            set line [string trim $line]
            if {$line eq ""} continue
            set entry [parse_line $line]
            if {$entry ne ""} {
                analyze_entry $entry
            }
        }
    }

    proc generate_report {} {
        variable stats

        set width 60
        set bar [string repeat "=" $width]
        set thin_bar [string repeat "-" $width]

        set report ""
        append report "$bar\n"
        append report "  LOG ANALYSIS REPORT\n"
        append report "$bar\n\n"

        append report "Time Range:\n"
        append report "  From: [dict get $stats first_timestamp]\n"
        append report "  To:   [dict get $stats last_timestamp]\n"
        append report "  Total Entries: [dict get $stats total_lines]\n\n"

        append report "$thin_bar\n"
        append report "Entries by Log Level:\n"
        append report "$thin_bar\n"
        set levels [dict get $stats by_level]
        set total [dict get $stats total_lines]
        foreach level [lsort [dict keys $levels]] {
            set count [dict get $levels $level]
            set pct [expr {$total > 0 ? double($count) / $total * 100 : 0}]
            set bar_len [expr {int($pct / 2)}]
            set bar_str [string repeat "#" $bar_len]
            append report [format "  %-8s %5d (%5.1f%%) %s\n" $level $count $pct $bar_str]
        }

        append report "\n$thin_bar\n"
        append report "Activity by Hour:\n"
        append report "$thin_bar\n"
        set hours [dict get $stats by_hour]
        for {set h 0} {$h < 24} {incr h} {
            set hh [format "%02d" $h]
            set count 0
            if {[dict exists $hours $hh]} {
                set count [dict get $hours $hh]
            }
            if {$count > 0} {
                set bar_len [expr {min($count, 40)}]
                set bar_str [string repeat "|" $bar_len]
                append report [format "  %s:00  %4d  %s\n" $hh $count $bar_str]
            }
        }

        append report "\n$thin_bar\n"
        append report "Top Sources:\n"
        append report "$thin_bar\n"
        set sources [dict get $stats unique_sources]
        set sorted_sources {}
        dict for {src count} $sources {
            lappend sorted_sources [list $src $count]
        }
        set sorted_sources [lsort -index 1 -integer -decreasing $sorted_sources]
        set shown 0
        foreach pair $sorted_sources {
            lassign $pair src count
            append report [format "  %-25s %5d entries\n" $src $count]
            incr shown
            if {$shown >= 10} break
        }

        set errors [dict get $stats errors]
        if {[llength $errors] > 0} {
            append report "\n$thin_bar\n"
            append report "Recent Errors (last 5):\n"
            append report "$thin_bar\n"
            set start [expr {max(0, [llength $errors] - 5)}]
            foreach entry [lrange $errors $start end] {
                append report "  \[[dict get $entry timestamp]\] [dict get $entry source]\n"
                append report "    [dict get $entry message]\n"
            }
        }

        set warnings [dict get $stats warnings]
        if {[llength $warnings] > 0} {
            append report "\n$thin_bar\n"
            append report "Recent Warnings (last 5):\n"
            append report "$thin_bar\n"
            set start [expr {max(0, [llength $warnings] - 5)}]
            foreach entry [lrange $warnings $start end] {
                append report "  \[[dict get $entry timestamp]\] [dict get $entry source]\n"
                append report "    [dict get $entry message]\n"
            }
        }

        append report "\n$bar\n"
        return $report
    }
}

# --- Generate sample log data for demonstration ---
proc generate_sample_log {} {
    set levels {INFO INFO INFO INFO INFO DEBUG DEBUG WARNING ERROR}
    set sources {WebServer Database AuthModule CacheLayer APIGateway TaskQueue}
    set messages [dict create \
        INFO [list \
            "Request processed successfully" \
            "User session started" \
            "Cache hit for key users:list" \
            "Health check passed" \
            "Configuration reloaded" \
            "Background job completed" \
        ] \
        DEBUG [list \
            "Query executed in 15ms" \
            "Connection pool stats: active=5 idle=10" \
            "Parsing request headers" \
            "Route matched: /api/v1/users" \
        ] \
        WARNING [list \
            "Slow query detected (>500ms)" \
            "Connection pool nearing capacity" \
            "Deprecated API endpoint called" \
            "Rate limit threshold at 80%" \
            "Disk usage above 75%" \
        ] \
        ERROR [list \
            "Connection timeout after 30s" \
            "Authentication failed for user admin" \
            "Out of memory in cache layer" \
            "Database connection refused" \
            "Unhandled exception in request handler" \
        ] \
    ]

    set lines {}
    set base_time [clock scan "2026-03-20 08:00:00"]

    for {set i 0} {$i < 200} {incr i} {
        set offset [expr {int(rand() * 36000)}]
        set ts [clock format [expr {$base_time + $offset}] -format {%Y-%m-%d %H:%M:%S}]

        set level [lindex $levels [expr {int(rand() * [llength $levels])}]]
        set source [lindex $sources [expr {int(rand() * [llength $sources])}]]
        set msg_list [dict get $messages $level]
        set message [lindex $msg_list [expr {int(rand() * [llength $msg_list])}]]

        lappend lines [format "%s \[%s\] \[%s\] %s" $ts $level $source $message]
    }

    return [lsort $lines]
}

# --- Main ---
puts "Generating sample log data (200 entries)..."
set log_lines [generate_sample_log]

puts "Analyzing...\n"
LogAnalyzer::analyze_lines $log_lines

set report [LogAnalyzer::generate_report]
puts $report
