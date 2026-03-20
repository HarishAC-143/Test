# 9. File I/O & System Interaction

## Opening and Closing Files

```tcl
# Open for reading (default)
set f [open "data.txt" r]

# Open for writing (truncates existing file)
set f [open "output.txt" w]

# Open for appending
set f [open "log.txt" a]

# Open for reading and writing
set f [open "data.txt" r+]

# Always close when done
close $f
```

### File Open Modes

| Mode | Description |
|------|-------------|
| `r`  | Read only (file must exist) |
| `w`  | Write only (truncates or creates) |
| `a`  | Append only (creates if needed) |
| `r+` | Read and write (file must exist) |
| `w+` | Read and write (truncates or creates) |
| `a+` | Read and append (creates if needed) |

## Reading Files

### Read Entire File

```tcl
set f [open "data.txt" r]
set contents [read $f]
close $f
puts $contents
```

### Read N Characters

```tcl
set f [open "data.txt" r]
set first100 [read $f 100]
close $f
```

### Read Line by Line

```tcl
set f [open "data.txt" r]
while {[gets $f line] >= 0} {
    puts "Line: $line"
}
close $f
```

`gets` returns the number of characters read (or -1 at EOF). The line content (without the newline) is placed in the variable.

### Read All Lines into a List

```tcl
set f [open "data.txt" r]
set lines [split [read $f] "\n"]
close $f

foreach line $lines {
    if {$line ne ""} {
        puts $line
    }
}
```

## Writing Files

```tcl
# Write text
set f [open "output.txt" w]
puts $f "First line"
puts $f "Second line"
puts -nonewline $f "No trailing newline"
close $f

# Append to file
set f [open "log.txt" a]
puts $f "[clock format [clock seconds]]: Event occurred"
close $f
```

## Safe File Handling with Patterns

### Try/Finally Pattern

```tcl
set f [open "data.txt" r]
try {
    while {[gets $f line] >= 0} {
        puts $line
    }
} finally {
    close $f
}
```

### One-Liner for Small Files

```tcl
proc read_file {filename} {
    set f [open $filename r]
    try {
        return [read $f]
    } finally {
        close $f
    }
}

proc write_file {filename content} {
    set f [open $filename w]
    try {
        puts -nonewline $f $content
    } finally {
        close $f
    }
}
```

## File System Operations

### File Information

```tcl
# Check existence
file exists "data.txt"          ;# → 1 or 0

# File type
file type "data.txt"            ;# → file, directory, link, etc.
file isfile "data.txt"          ;# → 1
file isdirectory "/tmp"         ;# → 1

# File size (bytes)
file size "data.txt"            ;# → 1234

# Modification time (epoch seconds)
file mtime "data.txt"
clock format [file mtime "data.txt"]

# Readable, writable, executable
file readable "data.txt"        ;# → 1 or 0
file writable "data.txt"
file executable "script.sh"
```

### Path Manipulation

```tcl
set path "/home/user/documents/report.pdf"

file dirname $path       ;# → /home/user/documents
file tail $path          ;# → report.pdf
file extension $path     ;# → .pdf
file rootname $path      ;# → /home/user/documents/report

# Join paths safely
file join "/home" "user" "documents" "file.txt"
# → /home/user/documents/file.txt

# Normalize a path
file normalize "~/documents/../downloads/file.txt"

# Split path into components
file split "/usr/local/bin"  ;# → / usr local bin
```

### File Operations

```tcl
# Copy
file copy "source.txt" "dest.txt"
file copy -force "source.txt" "dest.txt"

# Rename / Move
file rename "old.txt" "new.txt"
file rename -force "old.txt" "new.txt"

# Delete
file delete "temp.txt"
file delete -force "temp_dir"    ;# Recursive delete

# Create directory
file mkdir "new_directory"
file mkdir "path/to/nested/dir"  ;# Creates all intermediate dirs
```

### Temporary Files

```tcl
# Create a temp file
set tmpfile [file tempfile f ".txt"]
puts $f "temporary data"
close $f
puts "Temp file: $tmpfile"

# Clean up
file delete $tmpfile
```

## Directory Listing with `glob`

```tcl
# List all files in current directory
glob *

# List .tcl files
glob *.tcl

# List files in a specific directory
glob -directory /tmp *

# List hidden files
glob -directory /home/user .*

# Recursive search (with -type)
glob -type f *.tcl               ;# Files only
glob -type d */                   ;# Directories only

# Handle "no matches" gracefully
glob -nocomplain *.xyz           ;# Returns empty list if no matches
```

### Recursive File Finder

```tcl
proc find_files {dir pattern} {
    set results {}
    foreach f [glob -nocomplain -directory $dir -type f $pattern] {
        lappend results $f
    }
    foreach d [glob -nocomplain -directory $dir -type d *] {
        lappend results {*}[find_files $d $pattern]
    }
    return $results
}

set tcl_files [find_files "." "*.tcl"]
foreach f $tcl_files {
    puts $f
}
```

## Channel Configuration

```tcl
set f [open "data.txt" r]

# Set encoding
fconfigure $f -encoding utf-8

# Set line ending translation
fconfigure $f -translation auto    ;# auto, lf, cr, crlf

# Binary mode
fconfigure $f -translation binary

# Buffering
fconfigure $f -buffering full      ;# full, line, none
fconfigure $f -buffersize 8192

# Query configuration
puts [fconfigure $f -encoding]

close $f
```

### Reading Binary Files

```tcl
set f [open "image.png" rb]       ;# 'b' flag for binary
set data [read $f]
close $f

# Or configure after opening
set f [open "image.png" r]
fconfigure $f -translation binary
set data [read $f]
close $f
```

## Standard Channels

```tcl
# stdin, stdout, stderr are always open
puts stdout "Normal output"
puts stderr "Error output"

# Read from stdin
puts -nonewline "Enter name: "
flush stdout
gets stdin name
```

## Executing External Commands

### The `exec` Command

```tcl
# Run a command and capture output
set output [exec ls -la]
puts $output

# Redirect stderr
set output [exec ls nonexistent 2>@1]

# Pipe commands
set count [exec wc -l < "data.txt"]
set sorted [exec sort "data.txt" | uniq]

# Ignore exit status
catch {exec grep "pattern" "file.txt"} result

# Run in background
set pid [exec long_command &]
```

### The `open` Command with Pipes

```tcl
# Read from a command's output
set pipe [open "| ls -la" r]
while {[gets $pipe line] >= 0} {
    puts $line
}
close $pipe

# Write to a command's input
set pipe [open "| sort > sorted.txt" w]
puts $pipe "banana"
puts $pipe "apple"
puts $pipe "cherry"
close $pipe
```

## Process Information

```tcl
# Current process ID
pid

# Process ID of a pipeline
set pipe [open "| sleep 10" r]
set child_pid [pid $pipe]
puts "Child PID: $child_pid"
close $pipe
```

## Practical Example: CSV File Reader

```tcl
proc read_csv {filename {delimiter ","}} {
    set f [open $filename r]
    set result {}
    set headers {}

    set line_num 0
    while {[gets $f line] >= 0} {
        if {[string trim $line] eq ""} continue
        set fields [split $line $delimiter]
        set fields [lmap field $fields { string trim $field }]

        if {$line_num == 0} {
            set headers $fields
        } else {
            set record [dict create]
            foreach h $headers v $fields {
                dict set record $h $v
            }
            lappend result $record
        }
        incr line_num
    }
    close $f
    return $result
}

proc write_csv {filename data {delimiter ","}} {
    if {[llength $data] == 0} return

    set f [open $filename w]
    set headers [dict keys [lindex $data 0]]
    puts $f [join $headers $delimiter]

    foreach record $data {
        set values [lmap h $headers { dict get $record $h }]
        puts $f [join $values $delimiter]
    }
    close $f
}
```

## Practical Example: File Backup Utility

```tcl
proc backup_file {filepath} {
    if {![file exists $filepath]} {
        error "File not found: $filepath"
    }

    set timestamp [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]
    set dir [file dirname $filepath]
    set name [file rootname [file tail $filepath]]
    set ext [file extension $filepath]

    set backup "${dir}/${name}_backup_${timestamp}${ext}"
    file copy $filepath $backup
    puts "Backed up: $filepath → $backup"
    return $backup
}

proc cleanup_backups {dir pattern {keep 5}} {
    set files [lsort [glob -nocomplain -directory $dir $pattern]]
    set count [llength $files]
    if {$count > $keep} {
        set to_delete [lrange $files 0 end-$keep]
        foreach f $to_delete {
            file delete $f
            puts "Deleted old backup: $f"
        }
    }
}
```

---

**Previous:** [Arrays & Dictionaries](08-arrays-and-dictionaries.md) | **Next:** [Regular Expressions](10-regular-expressions.md)
