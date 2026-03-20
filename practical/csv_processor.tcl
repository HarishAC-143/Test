#!/usr/bin/env tclsh
# =============================================================================
# Practical Example: CSV File Processor
# =============================================================================
# Parse, filter, transform, and aggregate CSV data. Supports quoting, custom
# delimiters, and SQL-like operations (select, where, group by, order by).
# Demonstrates: string processing, lists, dicts, procedures, file I/O.
# =============================================================================

namespace eval CSV {

    proc parse_line {line {delimiter ","}} {
        set fields {}
        set current ""
        set in_quotes false
        set len [string length $line]

        for {set i 0} {$i < $len} {incr i} {
            set ch [string index $line $i]

            if {$in_quotes} {
                if {$ch eq "\""} {
                    if {$i + 1 < $len && [string index $line [expr {$i+1}]] eq "\""} {
                        append current "\""
                        incr i
                    } else {
                        set in_quotes false
                    }
                } else {
                    append current $ch
                }
            } else {
                if {$ch eq "\""} {
                    set in_quotes true
                } elseif {$ch eq $delimiter} {
                    lappend fields [string trim $current]
                    set current ""
                } else {
                    append current $ch
                }
            }
        }
        lappend fields [string trim $current]
        return $fields
    }

    proc parse {text {delimiter ","} {has_header true}} {
        set lines [split [string trim $text] "\n"]
        set result [dict create headers {} rows {}]

        if {[llength $lines] == 0} {
            return $result
        }

        set start 0
        if {$has_header} {
            dict set result headers [parse_line [lindex $lines 0] $delimiter]
            set start 1
        }

        set rows {}
        for {set i $start} {$i < [llength $lines]} {incr i} {
            set line [string trim [lindex $lines $i]]
            if {$line eq ""} continue
            lappend rows [parse_line $line $delimiter]
        }
        dict set result rows $rows

        return $result
    }

    proc to_dicts {data} {
        set headers [dict get $data headers]
        set result {}
        foreach row [dict get $data rows] {
            set record [dict create]
            for {set i 0} {$i < [llength $headers]} {incr i} {
                dict set record [lindex $headers $i] [lindex $row $i]
            }
            lappend result $record
        }
        return $result
    }

    proc select {records columns} {
        set result {}
        foreach rec $records {
            set new_rec [dict create]
            foreach col $columns {
                if {[dict exists $rec $col]} {
                    dict set new_rec $col [dict get $rec $col]
                }
            }
            lappend result $new_rec
        }
        return $result
    }

    proc where {records condition} {
        set result {}
        foreach rec $records {
            dict for {k v} $rec {
                set $k $v
            }
            if {[expr $condition]} {
                lappend result $rec
            }
        }
        return $result
    }

    proc order_by {records column {direction "asc"} {type "-dictionary"}} {
        set indexed {}
        set idx 0
        foreach rec $records {
            lappend indexed [list [dict get $rec $column] $idx $rec]
            incr idx
        }

        set sort_opts [list $type]
        if {$direction eq "desc"} {
            lappend sort_opts "-decreasing"
        }

        set sorted [lsort {*}$sort_opts -index 0 $indexed]

        set result {}
        foreach item $sorted {
            lappend result [lindex $item 2]
        }
        return $result
    }

    proc group_by {records key_column agg_column agg_func} {
        set groups [dict create]
        foreach rec $records {
            set key [dict get $rec $key_column]
            set val [dict get $rec $agg_column]
            dict lappend groups $key $val
        }

        set result {}
        dict for {key values} $groups {
            set agg_result [apply_aggregate $agg_func $values]
            lappend result [dict create $key_column $key $agg_func $agg_result count [llength $values]]
        }
        return $result
    }

    proc apply_aggregate {func values} {
        switch $func {
            sum {
                set total 0
                foreach v $values {
                    set total [expr {$total + $v}]
                }
                return $total
            }
            avg {
                set total 0
                foreach v $values {
                    set total [expr {$total + $v}]
                }
                return [expr {double($total) / [llength $values]}]
            }
            min {
                set result [lindex $values 0]
                foreach v [lrange $values 1 end] {
                    if {$v < $result} { set result $v }
                }
                return $result
            }
            max {
                set result [lindex $values 0]
                foreach v [lrange $values 1 end] {
                    if {$v > $result} { set result $v }
                }
                return $result
            }
            count {
                return [llength $values]
            }
        }
    }

    proc format_table {records {max_width 20}} {
        if {[llength $records] == 0} {
            return "(empty result set)"
        }

        set columns [dict keys [lindex $records 0]]
        set widths [dict create]
        foreach col $columns {
            dict set widths $col [string length $col]
        }

        foreach rec $records {
            foreach col $columns {
                set val_len [string length [dict get $rec $col]]
                if {$val_len > [dict get $widths $col]} {
                    dict set widths $col [expr {min($val_len, $max_width)}]
                }
            }
        }

        set header ""
        set separator ""
        foreach col $columns {
            set w [dict get $widths $col]
            append header [format "| %-*s " $w $col]
            append separator "+-[string repeat "-" $w]-"
        }
        append header "|"
        append separator "+"

        set output "$separator\n$header\n$separator\n"
        foreach rec $records {
            set row ""
            foreach col $columns {
                set w [dict get $widths $col]
                set val [dict get $rec $col]
                if {[string length $val] > $max_width} {
                    set val "[string range $val 0 $max_width-4]..."
                }
                append row [format "| %-*s " $w $val]
            }
            append row "|"
            append output "$row\n"
        }
        append output $separator
        return $output
    }

    proc to_csv {records {delimiter ","}} {
        if {[llength $records] == 0} {
            return ""
        }

        set columns [dict keys [lindex $records 0]]
        set output [join $columns $delimiter]

        foreach rec $records {
            set values {}
            foreach col $columns {
                set val [dict get $rec $col]
                if {[string match "*$delimiter*" $val] || [string match "*\"*" $val] || [string match "*\n*" $val]} {
                    set val "\"[string map {"\"" "\"\""} $val]\""
                }
                lappend values $val
            }
            append output "\n[join $values $delimiter]"
        }
        return $output
    }
}

# =============================================================================
# Demo
# =============================================================================

set sample_csv {name,department,salary,years,city
Alice Johnson,Engineering,95000,5,Portland
Bob Smith,Marketing,72000,3,Seattle
Carol Davis,Engineering,105000,8,Portland
Dave Wilson,Sales,68000,2,Denver
Eve Brown,Engineering,98000,6,Seattle
Frank Lee,Marketing,75000,4,Portland
Grace Kim,Sales,71000,3,Seattle
Henry Park,Engineering,112000,10,Denver
Iris Chen,Marketing,82000,7,Portland
Jack Taylor,Sales,65000,1,Denver
}

puts "╔══════════════════════════════════════════════════╗"
puts "║          CSV Processor Demo                      ║"
puts "╚══════════════════════════════════════════════════╝\n"

puts "=== Parsing CSV Data ==="
set data [CSV::parse $sample_csv]
set records [CSV::to_dicts $data]
puts "Parsed [llength $records] records with columns: [dict get $data headers]\n"

puts "=== Full Table ==="
puts [CSV::format_table $records]

puts "\n\n=== SELECT name, department, salary ==="
set selected [CSV::select $records {name department salary}]
puts [CSV::format_table $selected]

puts "\n\n=== WHERE department == Engineering ==="
set engineers [CSV::where $records {$department eq "Engineering"}]
puts [CSV::format_table $engineers]

puts "\n\n=== WHERE salary > 80000 ==="
set high_salary [CSV::where $records {$salary > 80000}]
puts [CSV::format_table [CSV::select $high_salary {name salary department}]]

puts "\n\n=== ORDER BY salary DESC ==="
set sorted [CSV::order_by $records salary "desc" "-integer"]
puts [CSV::format_table [CSV::select $sorted {name department salary}]]

puts "\n\n=== GROUP BY department (avg salary) ==="
set dept_stats [CSV::group_by $records department salary avg]
set dept_stats [CSV::order_by $dept_stats avg "desc" "-real"]
foreach rec $dept_stats {
    dict set rec avg [format "%.0f" [dict get $rec avg]]
}
puts [CSV::format_table $dept_stats]

puts "\n\n=== GROUP BY city (count) ==="
set city_stats [CSV::group_by $records city salary count]
puts [CSV::format_table $city_stats]

puts "\n\n=== Chained: Engineering in Portland, sorted by salary ==="
set result [CSV::where $records {$department eq "Engineering" && $city eq "Portland"}]
set result [CSV::order_by $result salary "desc" "-integer"]
set result [CSV::select $result {name salary years}]
puts [CSV::format_table $result]

puts "\n\n=== Export back to CSV ==="
set csv_output [CSV::to_csv [CSV::select [lrange $records 0 2] {name department salary}]]
puts $csv_output
