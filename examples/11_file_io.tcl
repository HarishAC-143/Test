#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 11: File I/O
# =============================================================================

set test_dir "/tmp/tcl_file_io_demo"
file mkdir $test_dir

puts "=== Writing to a File ==="
set filepath "$test_dir/sample.txt"
set fd [open $filepath w]
puts $fd "Line 1: Hello from Tcl"
puts $fd "Line 2: File I/O is straightforward"
puts $fd "Line 3: This is the third line"
puts $fd "Line 4: Almost done"
puts $fd "Line 5: Final line"
close $fd
puts "Wrote 5 lines to $filepath"

puts "\n=== Reading Entire File ==="
set fd [open $filepath r]
set contents [read $fd]
close $fd
puts "File contents:"
puts $contents

puts "=== Reading Line by Line ==="
set fd [open $filepath r]
set line_num 0
while {[gets $fd line] >= 0} {
    incr line_num
    puts [format "  %3d | %s" $line_num $line]
}
close $fd

puts "\n=== Reading into a List of Lines ==="
set fd [open $filepath r]
set all_lines [split [read $fd] "\n"]
close $fd
puts "Total lines (including empty): [llength $all_lines]"

puts "\n=== Appending to a File ==="
set fd [open $filepath a]
puts $fd "Line 6: Appended later"
puts $fd "Line 7: Also appended"
close $fd

set fd [open $filepath r]
puts "After appending:"
while {[gets $fd line] >= 0} {
    puts "  $line"
}
close $fd

puts "\n=== Writing with -nonewline ==="
set fd [open "$test_dir/no_newline.txt" w]
puts -nonewline $fd "No trailing newline here"
close $fd

puts "\n=== Binary File Operations ==="
set fd [open "$test_dir/binary.dat" wb]
set data [binary format i4 {1 2 3 4}]
puts -nonewline $fd $data
close $fd

set fd [open "$test_dir/binary.dat" rb]
set raw [read $fd]
close $fd
binary scan $raw i4 values
puts "Binary read back: $values"

puts "\n=== File Information ==="
puts "  exists '$filepath': [file exists $filepath]"
puts "  size: [file size $filepath] bytes"
puts "  readable: [file readable $filepath]"
puts "  writable: [file writable $filepath]"
puts "  type: [file type $filepath]"

set mtime [file mtime $filepath]
puts "  modified: [clock format $mtime -format {%Y-%m-%d %H:%M:%S}]"

puts "\n=== Path Manipulation ==="
set path "/home/user/documents/report.pdf"
puts "  dirname:    [file dirname $path]"
puts "  tail:       [file tail $path]"
puts "  extension:  [file extension $path]"
puts "  rootname:   [file rootname [file tail $path]]"
puts "  join:       [file join "/home" "user" "docs" "file.txt"]"
puts "  normalize:  [file normalize "~/documents/../downloads/file.txt"]"

puts "\n=== Directory Operations ==="
file mkdir "$test_dir/subdir1"
file mkdir "$test_dir/subdir2"

set fd [open "$test_dir/subdir1/a.txt" w]; puts $fd "file a"; close $fd
set fd [open "$test_dir/subdir1/b.tcl" w]; puts $fd "file b"; close $fd
set fd [open "$test_dir/subdir2/c.txt" w]; puts $fd "file c"; close $fd

puts "Files in $test_dir:"
foreach item [lsort [glob -directory $test_dir *]] {
    set type [file type $item]
    puts [format "  %-40s [%s]" [file tail $item] $type]
}

puts "\nText files in tree:"
foreach f [lsort [glob -directory $test_dir -type f **/*.txt *.txt]] {
    puts "  $f"
}

puts "\n=== Copying and Renaming Files ==="
file copy -force "$test_dir/subdir1/a.txt" "$test_dir/a_copy.txt"
puts "Copied a.txt to a_copy.txt"

file rename -force "$test_dir/a_copy.txt" "$test_dir/a_renamed.txt"
puts "Renamed a_copy.txt to a_renamed.txt"

puts "\n=== Cleanup ==="
file delete -force $test_dir
puts "Removed test directory: $test_dir"
puts "Exists after delete: [file exists $test_dir]"
