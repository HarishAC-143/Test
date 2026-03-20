#!/usr/bin/env tclsh
#
# 05_file_io.tcl — Demonstrates file input/output operations
#

puts "=============================="
puts " File I/O Demo"
puts "=============================="
puts ""

set demo_dir "/tmp/tcl_file_demo"
file mkdir $demo_dir

# --- Writing Files ---
puts "--- Writing Files ---"

set filepath [file join $demo_dir "sample.txt"]
set fp [open $filepath w]
puts $fp "Line 1: Hello from TCL"
puts $fp "Line 2: File I/O is straightforward"
puts $fp "Line 3: This is the third line"
puts $fp "Line 4: TCL handles files well"
puts $fp "Line 5: Last line of the file"
close $fp
puts "Wrote 5 lines to $filepath"
puts ""

# --- Reading Entire File ---
puts "--- Reading Entire File ---"
set fp [open $filepath r]
set content [read $fp]
close $fp
puts "Content:"
puts $content

# --- Reading Line by Line ---
puts "--- Reading Line by Line ---"
set fp [open $filepath r]
set line_num 0
while {[gets $fp line] >= 0} {
    incr line_num
    puts [format "  %3d: %s" $line_num $line]
}
close $fp
puts ""

# --- Appending to a File ---
puts "--- Appending to a File ---"
set fp [open $filepath a]
puts $fp "Line 6: This was appended"
puts $fp "Line 7: Another appended line"
close $fp
puts "Appended 2 lines."
puts ""

# --- CSV File Generation and Parsing ---
puts "--- CSV File Operations ---"

set csv_file [file join $demo_dir "employees.csv"]
set fp [open $csv_file w]
puts $fp "name,department,salary,years"
puts $fp "Alice,Engineering,95000,5"
puts $fp "Bob,Marketing,78000,3"
puts $fp "Carol,Engineering,102000,8"
puts $fp "Dave,Sales,68000,2"
puts $fp "Eve,Engineering,88000,4"
puts $fp "Frank,Marketing,82000,6"
close $fp
puts "Created CSV: $csv_file"

proc read_csv {filename} {
    set fp [open $filename r]
    set header_line [gets $fp]
    set headers [split $header_line ","]
    set records [list]
    while {[gets $fp line] >= 0} {
        if {[string trim $line] eq ""} continue
        set values [split $line ","]
        set rec [dict create]
        foreach h $headers v $values {
            dict set rec $h $v
        }
        lappend records $rec
    }
    close $fp
    return $records
}

set employees [read_csv $csv_file]
puts "Read [llength $employees] employee records:"
puts ""
puts [format "  %-10s %-15s %8s %5s" "Name" "Department" "Salary" "Years"]
puts "  [string repeat "-" 42]"
foreach emp $employees {
    puts [format "  %-10s %-15s %8s %5s" \
        [dict get $emp name] \
        [dict get $emp department] \
        [dict get $emp salary] \
        [dict get $emp years]]
}
puts ""

# Analyze: average salary by department
puts "--- Average Salary by Department ---"
set dept_totals [dict create]
set dept_counts [dict create]
foreach emp $employees {
    set dept [dict get $emp department]
    set salary [dict get $emp salary]
    if {![dict exists $dept_totals $dept]} {
        dict set dept_totals $dept 0
        dict set dept_counts $dept 0
    }
    dict set dept_totals $dept [expr {[dict get $dept_totals $dept] + $salary}]
    dict incr dept_counts $dept
}
dict for {dept total} $dept_totals {
    set count [dict get $dept_counts $dept]
    set avg [expr {$total / $count}]
    puts [format "  %-15s \$%d (avg of %d employees)" $dept $avg $count]
}
puts ""

# --- File Information ---
puts "--- File Information ---"
puts [format "  %-20s %s" "File:" $filepath]
puts [format "  %-20s %d bytes" "Size:" [file size $filepath]]
puts [format "  %-20s %s" "Type:" [file type $filepath]]
puts [format "  %-20s %s" "Readable:" [expr {[file readable $filepath] ? "yes" : "no"}]]
puts [format "  %-20s %s" "Writable:" [expr {[file writable $filepath] ? "yes" : "no"}]]
puts [format "  %-20s %s" "Modified:" [clock format [file mtime $filepath] -format "%Y-%m-%d %H:%M:%S"]]
puts [format "  %-20s %s" "Extension:" [file extension $filepath]]
puts [format "  %-20s %s" "Tail:" [file tail $filepath]]
puts [format "  %-20s %s" "Directory:" [file dirname $filepath]]
puts ""

# --- Path Manipulation ---
puts "--- Path Manipulation ---"
set parts [list "/home" "user" "projects" "myapp" "src" "main.tcl"]
set full_path [file join {*}$parts]
puts "Joined:    $full_path"
puts "Dirname:   [file dirname $full_path]"
puts "Tail:      [file tail $full_path]"
puts "Root:      [file rootname [file tail $full_path]]"
puts "Extension: [file extension $full_path]"
puts ""

# --- Directory Listing ---
puts "--- Directory Listing ---"
set files [glob -nocomplain -directory $demo_dir *]
foreach f [lsort $files] {
    set type [file type $f]
    set size [file size $f]
    puts [format "  %-30s %6d bytes  (%s)" [file tail $f] $size $type]
}
puts ""

# --- Cleanup ---
puts "--- Cleanup ---"
file delete -force $demo_dir
puts "Removed demo directory: $demo_dir"
puts ""

puts "Done!"
