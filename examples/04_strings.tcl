#!/usr/bin/env tclsh
# =============================================================================
# Example 4: String Operations
# Demonstrates: string commands, format, scan, pattern matching, manipulation
# =============================================================================

puts "=== String Operations ===\n"

set sample "Hello, World! Welcome to TCL Programming."

# --- Basic info ---
puts "--- Basic String Information ---"
puts "  String: \"$sample\""
puts "  Length: [string length $sample]"
puts "  First char: '[string index $sample 0]'"
puts "  Last char:  '[string index $sample end]'"
puts "  Chars 0-4:  '[string range $sample 0 4]'"

# --- Case conversion ---
puts "\n--- Case Conversion ---"
puts "  Upper: [string toupper $sample]"
puts "  Lower: [string tolower $sample]"
puts "  Title: [string totitle "hello world from tcl"]"

# --- Searching ---
puts "\n--- Searching ---"
puts "  First 'World': index [string first "World" $sample]"
puts "  First 'o': index [string first "o" $sample]"
puts "  Last 'o':  index [string last "o" $sample]"
puts "  Contains 'Python'? [expr {[string first "Python" $sample] >= 0 ? "No" : "Yes"}]"

# --- Comparison ---
puts "\n--- Comparison ---"
puts "  'abc' vs 'def': [string compare "abc" "def"]  (-1 = less)"
puts "  'abc' vs 'abc': [string compare "abc" "abc"]  (0 = equal)"
puts "  'ABC' eq 'abc' (case-sensitive): [string equal "ABC" "abc"]"
puts "  'ABC' eq 'abc' (case-insensitive): [string equal -nocase "ABC" "abc"]"

# --- Pattern matching ---
puts "\n--- Pattern Matching (glob) ---"
foreach {pattern str} {
    "*.tcl"    "script.tcl"
    "*.tcl"    "script.py"
    "H*o"      "Hello"
    "???"      "TCL"
    "???"      "JAVA"
} {
    set result [string match $pattern $str]
    puts "  match '$pattern' '$str' -> $result"
}

# --- Trim ---
puts "\n--- Trimming ---"
set padded "   Hello, World!   "
puts "  Original: '$padded'"
puts "  trim:      '[string trim $padded]'"
puts "  trimleft:  '[string trimleft $padded]'"
puts "  trimright: '[string trimright $padded]'"
puts "  trim 'x' from 'xxHelloxx': '[string trim "xxHelloxx" "x"]'"

# --- String manipulation ---
puts "\n--- Manipulation ---"
puts "  Repeat 'TCL ' x3: '[string repeat "TCL " 3]'"
puts "  Reverse 'Hello': '[string reverse "Hello"]'"
puts "  Replace: '[string replace "Hello, World!" 7 11 "TCL"]'"

# --- String map (translate characters) ---
puts "\n--- String Map ---"
set html_text "<p>Hello & World</p>"
set escaped [string map {& &amp; < &lt; > &gt;} $html_text]
puts "  HTML escape: $escaped"

set rot13 [string map {
    A N B O C P D Q E R F S G T H U I V J W K X L Y M Z
    N A O B P C Q D R E S F T G U H V I W J X K Y L Z M
    a n b o c p d q e r f s g t h u i v j w k x l y m z
    n a o b p c q d r e s f t g u h v i w j x k y l z m
} "Hello World"]
puts "  ROT13 of 'Hello World': $rot13"

# --- Format (printf-style) ---
puts "\n--- Formatting ---"
puts [format "  %-15s %5s %10s" "Name" "Age" "Score"]
puts [format "  %-15s %5d %10.2f" "Alice" 30 95.5]
puts [format "  %-15s %5d %10.2f" "Bob" 25 87.3]
puts [format "  %-15s %5d %10.2f" "Carol" 35 92.8]
puts ""
puts [format "  Hex: 0x%04X" 255]
puts [format "  Oct: 0%03o" 255]
puts [format "  Sci: %e" 123456.789]

# --- Scan (sscanf-style) ---
puts "\n--- Scanning ---"
set input "Alice 30 95.5"
scan $input "%s %d %f" name age score
puts "  Parsed: name=$name, age=$age, score=$score"

set date "2024-06-15"
scan $date "%d-%d-%d" year month day
puts "  Date: year=$year, month=$month, day=$day"

# --- String is (classification) ---
puts "\n--- Classification ---"
foreach {val} {"42" "3.14" "hello" "Hello123" "   " "TRUE"} {
    set types [list]
    if {[string is integer -strict $val]} { lappend types "integer" }
    if {[string is double -strict $val]}  { lappend types "double" }
    if {[string is alpha -strict $val]}   { lappend types "alpha" }
    if {[string is alnum -strict $val]}   { lappend types "alnum" }
    if {[string is digit -strict $val]}   { lappend types "digit" }
    if {[string is space -strict $val]}   { lappend types "space" }
    if {[string is upper -strict $val]}   { lappend types "upper" }
    if {[string is lower -strict $val]}   { lappend types "lower" }
    if {[llength $types] == 0} { set types "none" }
    puts [format "  %-12s -> %s" "'$val'" [join $types ", "]]
}

puts "\nDone."
