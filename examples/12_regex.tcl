#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 12: Regular Expressions
# =============================================================================

puts "=== Basic Matching ==="
set str "The quick brown fox jumps over the lazy dog"
if {[regexp {fox} $str]} {
    puts "'fox' found in string"
}
if {![regexp {cat} $str]} {
    puts "'cat' not found in string"
}

puts "\n=== Capturing Groups ==="
set str "My phone number is 555-123-4567"
if {[regexp {(\d{3})-(\d{3})-(\d{4})} $str full area prefix number]} {
    puts "Full match: $full"
    puts "Area code: $area"
    puts "Prefix: $prefix"
    puts "Number: $number"
}

puts "\n=== Parsing a Date ==="
set date "2026-03-20"
regexp {^(\d{4})-(\d{2})-(\d{2})$} $date full year month day
puts "Year: $year, Month: $month, Day: $day"

puts "\n=== Case-Insensitive Matching ==="
set text "Hello WORLD"
if {[regexp -nocase {hello world} $text]} {
    puts "Case-insensitive match found"
}

puts "\n=== Match All Occurrences ==="
set str "cat bat hat mat sat fat"
set matches [regexp -all -inline {[a-z]at} $str]
puts "All '*at' words: $matches"
puts "Count: [regexp -all {[a-z]at} $str]"

puts "\n=== Getting Match Positions (-indices) ==="
set str "Hello World, Hello Tcl"
regexp -indices {Hello} $str pos
puts "First 'Hello' at indices: $pos (chars [string range $str [lindex $pos 0] [lindex $pos 1]])"

set all_positions {}
set offset 0
set temp $str
while {[regexp -indices {Hello} $temp pos]} {
    set start [expr {[lindex $pos 0] + $offset}]
    set end [expr {[lindex $pos 1] + $offset}]
    lappend all_positions [list $start $end]
    set offset [expr {$end + 1}]
    set temp [string range $str $offset end]
}
puts "All 'Hello' positions: $all_positions"

puts "\n=== Email Validation ==="
proc validate_email {email} {
    return [regexp {^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$} $email]
}
foreach email {"alice@example.com" "bob@test" "user.name+tag@domain.co.uk" "@invalid" "test@.com"} {
    puts [format "  %-30s : %s" $email [expr {[validate_email $email] ? "valid" : "invalid"}]]
}

puts "\n=== URL Parsing ==="
set url "https://www.example.com:8080/path/to/page?query=value&lang=tcl#section"
regexp {^(https?):\/\/([^/:]+)(?::(\d+))?([^?#]*)(\?[^#]*)?(#.*)?$} $url \
    full protocol host port path query fragment
puts "Protocol: $protocol"
puts "Host: $host"
puts "Port: [expr {$port ne {} ? $port : {(default)}}]"
puts "Path: $path"
puts "Query: $query"
puts "Fragment: $fragment"

puts "\n=== Substitution with regsub ==="
set text "Hello World, Hello Tcl, Hello Everyone"

set result [regsub {Hello} $text "Hi"]
puts "Replace first: $result"

set result [regsub -all {Hello} $text "Hi"]
puts "Replace all: $result"

puts "\n=== regsub with Back-references ==="
set text "John Smith"
regsub {(\w+) (\w+)} $text {\2, \1} result
puts "Name reversed: $result"

set text "2026-03-20"
regsub {(\d{4})-(\d{2})-(\d{2})} $text {\2/\3/\1} result
puts "Date reformatted: $result"

puts "\n=== Removing/Cleaning Strings ==="
set dirty "  Hello   World!   Extra    spaces  "
set clean [regsub -all {\s+} [string trim $dirty] " "]
puts "Cleaned: '$clean'"

set html "<p>Hello <b>World</b></p>"
set plain [regsub -all {<[^>]+>} $html ""]
puts "HTML stripped: '$plain'"

puts "\n=== Extracting Data from Text ==="
set log_lines {
    "2026-03-20 10:15:30 ERROR Connection timeout"
    "2026-03-20 10:15:31 INFO Retrying connection"
    "2026-03-20 10:15:35 ERROR Authentication failed"
    "2026-03-20 10:15:36 WARNING Low memory"
    "2026-03-20 10:15:40 INFO Connection established"
}

puts "Error messages:"
foreach line $log_lines {
    if {[regexp {(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) ERROR (.+)} $line _ timestamp msg]} {
        puts "  \[$timestamp\] $msg"
    }
}

puts "\n=== Common Regex Patterns ==="
set patterns {
    {IPv4 Address}    {^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$}
    {Hex Color}       {^#[0-9a-fA-F]{6}$}
    {US Zip Code}     {^\d{5}(-\d{4})?$}
    {Integer}         {^-?\d+$}
    {Float}           {^-?\d+\.\d+$}
}

set test_values {
    "192.168.1.1" "#FF00AA" "90210" "90210-1234"
    "-42" "3.14" "hello" "#GGG" "999.999.999.999"
}

puts "Testing patterns against values:"
foreach {pname pattern} $patterns {
    puts "\n  $pname ($pattern):"
    foreach val $test_values {
        if {[regexp $pattern $val]} {
            puts "    ✓ $val"
        }
    }
}
