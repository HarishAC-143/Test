#!/usr/bin/env tclsh
#
# Log File Analyzer
# Parse, analyze, and report statistics from log files.

namespace eval loganalyzer {
    variable patterns
    array set patterns {
        apache  {^(\S+) \S+ \S+ \[([^\]]+)\] "(\w+) (\S+) \S+" (\d+) (\d+|-)}
        syslog  {^(\w+\s+\d+\s+\d+:\d+:\d+)\s+(\S+)\s+(\S+?)(?:\[\d+\])?: (.*)$}
        app     {^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s+\[(\w+)\]\s+(?:\[(\S+)\]\s+)?(.*)$}
    }

    proc analyze {filename {format "app"}} {
        variable patterns

        set stats [dict create \
            total_lines 0 \
            parsed_lines 0 \
            error_lines 0 \
            levels {} \
            sources {} \
            hourly {} \
            errors {} \
            first_timestamp "" \
            last_timestamp ""]

        set f [open $filename r]
        try {
            while {[gets $f line] >= 0} {
                dict incr stats total_lines
                set line [string trim $line]
                if {$line eq ""} continue

                set parsed [parse_line $line $format]
                if {[dict size $parsed] > 0} {
                    dict incr stats parsed_lines
                    update_stats stats $parsed
                } else {
                    dict incr stats error_lines
                }
            }
        } finally {
            close $f
        }

        return $stats
    }

    proc parse_line {line format} {
        variable patterns

        switch $format {
            app {
                if {[regexp $patterns(app) $line -> date time level source message]} {
                    return [dict create \
                        date $date time $time level $level \
                        source $source message $message \
                        hour [string range $time 0 1]]
                }
            }
            apache {
                if {[regexp $patterns(apache) $line -> ip datetime method path status size]} {
                    return [dict create \
                        ip $ip datetime $datetime method $method \
                        path $path status $status size $size \
                        level [status_to_level $status] \
                        hour [extract_hour_apache $datetime]]
                }
            }
            syslog {
                if {[regexp $patterns(syslog) $line -> datetime host source message]} {
                    set level [guess_level $message]
                    return [dict create \
                        datetime $datetime host $host source $source \
                        message $message level $level hour "00"]
                }
            }
        }
        return {}
    }

    proc status_to_level {status} {
        if {$status >= 500} { return "ERROR" }
        if {$status >= 400} { return "WARNING" }
        return "INFO"
    }

    proc extract_hour_apache {datetime} {
        if {[regexp {\d{2}/\w+/\d{4}:(\d{2})} $datetime -> hour]} {
            return $hour
        }
        return "00"
    }

    proc guess_level {message} {
        set msg [string toupper $message]
        if {[string first "ERROR" $msg] >= 0 || [string first "FAIL" $msg] >= 0} {
            return "ERROR"
        }
        if {[string first "WARN" $msg] >= 0} { return "WARNING" }
        if {[string first "DEBUG" $msg] >= 0} { return "DEBUG" }
        return "INFO"
    }

    proc update_stats {statsVar parsed} {
        upvar 1 $statsVar stats

        set level [string toupper [dict get $parsed level]]
        set hour [dict get $parsed hour]

        set levels [dict get $stats levels]
        dict incr levels $level
        dict set stats levels $levels

        set hourly [dict get $stats hourly]
        dict incr hourly $hour
        dict set stats hourly $hourly

        if {[dict exists $parsed source] && [dict get $parsed source] ne ""} {
            set sources [dict get $stats sources]
            dict incr sources [dict get $parsed source]
            dict set stats sources $sources
        }

        if {$level in {ERROR CRITICAL FATAL}} {
            set msg ""
            if {[dict exists $parsed message]} {
                set msg [dict get $parsed message]
            }
            set errors [dict get $stats errors]
            lappend errors $msg
            dict set stats errors $errors
        }
    }

    proc report {stats {title "Log Analysis Report"}} {
        set width 60
        set sep [string repeat "=" $width]

        puts $sep
        puts [format_center $title $width]
        puts $sep

        puts "\n--- Overview ---"
        puts [format "  Total lines:    %8d" [dict get $stats total_lines]]
        puts [format "  Parsed lines:   %8d" [dict get $stats parsed_lines]]
        puts [format "  Unparsed lines: %8d" [dict get $stats error_lines]]

        set levels [dict get $stats levels]
        if {[dict size $levels] > 0} {
            puts "\n--- Log Levels ---"
            set total [dict get $stats parsed_lines]
            foreach level [lsort [dict keys $levels]] {
                set count [dict get $levels $level]
                set pct [expr {$total > 0 ? $count * 100.0 / $total : 0}]
                set bar [string repeat "#" [expr {int($pct / 2)}]]
                puts [format "  %-10s %6d (%5.1f%%) %s" $level $count $pct $bar]
            }
        }

        set hourly [dict get $stats hourly]
        if {[dict size $hourly] > 0} {
            puts "\n--- Hourly Distribution ---"
            set max_count 0
            dict for {_ count} $hourly {
                if {$count > $max_count} { set max_count $count }
            }
            for {set h 0} {$h < 24} {incr h} {
                set hour [format "%02d" $h]
                set count 0
                if {[dict exists $hourly $hour]} {
                    set count [dict get $hourly $hour]
                }
                set bar_len [expr {$max_count > 0 ? int($count * 30.0 / $max_count) : 0}]
                set bar [string repeat "#" $bar_len]
                puts [format "  %s:00  %5d  %s" $hour $count $bar]
            }
        }

        set sources [dict get $stats sources]
        if {[dict size $sources] > 0} {
            puts "\n--- Top Sources ---"
            set sorted {}
            dict for {src count} $sources {
                lappend sorted [list $src $count]
            }
            set sorted [lsort -index 1 -integer -decreasing $sorted]
            set shown 0
            foreach item $sorted {
                if {$shown >= 10} break
                lassign $item src count
                puts [format "  %-30s %6d" $src $count]
                incr shown
            }
        }

        set errors [dict get $stats errors]
        if {[llength $errors] > 0} {
            puts "\n--- Recent Errors (last 5) ---"
            set start [expr {max(0, [llength $errors] - 5)}]
            foreach msg [lrange $errors $start end] {
                set display [string range $msg 0 75]
                if {[string length $msg] > 76} { append display "..." }
                puts "  * $display"
            }
        }

        puts "\n$sep"
    }

    proc format_center {text width} {
        set pad [expr {($width - [string length $text]) / 2}]
        return "[string repeat " " $pad]$text"
    }

    proc generate_sample_log {filename {lines 200}} {
        set levels {INFO INFO INFO INFO INFO WARNING WARNING ERROR DEBUG DEBUG INFO}
        set sources {auth database api scheduler cache web worker}
        set messages [dict create \
            INFO [list "Request processed successfully" "User logged in" \
                       "Cache hit for key" "Health check passed" \
                       "Connection established" "Task completed"] \
            WARNING [list "Slow query detected (>1s)" "Memory usage above 80%" \
                          "Retry attempt 2/3" "Deprecated API called"] \
            ERROR [list "Connection refused" "Query timeout after 30s" \
                        "Authentication failed" "Disk space critical"] \
            DEBUG [list "Processing request" "Cache lookup" "Query plan generated"]]

        set f [open $filename w]
        set base_time [clock seconds]

        for {set i 0} {$i < $lines} {incr i} {
            set offset [expr {int(rand() * 86400)}]
            set timestamp [expr {$base_time - 86400 + $offset}]
            set date [clock format $timestamp -format "%Y-%m-%d"]
            set time [clock format $timestamp -format "%H:%M:%S"]

            set level [lindex $levels [expr {int(rand() * [llength $levels])}]]
            set source [lindex $sources [expr {int(rand() * [llength $sources])}]]
            set msg_list [dict get $messages $level]
            set message [lindex $msg_list [expr {int(rand() * [llength $msg_list])}]]

            puts $f "$date $time \[$level\] \[$source\] $message"
        }
        close $f
        return $filename
    }
}

proc demo {} {
    puts "Generating sample log file..."
    set logfile [loganalyzer::generate_sample_log "/tmp/sample_app.log" 500]
    puts "Analyzing: $logfile\n"

    set stats [loganalyzer::analyze $logfile "app"]
    loganalyzer::report $stats "Sample Application Log Analysis"

    file delete $logfile
}

if {[info script] eq $argv0} {
    if {[llength $argv] > 0} {
        set filename [lindex $argv 0]
        set format [expr {[llength $argv] > 1 ? [lindex $argv 1] : "app"}]

        if {![file exists $filename]} {
            puts stderr "Error: File not found: $filename"
            exit 1
        }

        set stats [loganalyzer::analyze $filename $format]
        loganalyzer::report $stats "Analysis: [file tail $filename]"
    } else {
        demo
    }
}
