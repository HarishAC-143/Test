#!/usr/bin/env tclsh
#
# 06_regex.tcl — Demonstrates regular expressions in TCL
#

puts "=============================="
puts " Regular Expressions Demo"
puts "=============================="
puts ""

# --- Basic Matching ---
puts "--- Basic Matching ---"
set text "The quick brown fox jumps over the lazy dog"

puts "Text: $text"
puts "Contains 'quick': [regexp {quick} $text]"
puts "Contains 'cat':   [regexp {cat} $text]"
puts "Starts with 'The': [regexp {^The} $text]"
puts "Ends with 'dog':   [regexp {dog$} $text]"
puts ""

# --- Capturing Groups ---
puts "--- Capturing Groups ---"
set log_entry "2026-03-20 14:30:45 ERROR Database connection failed"

if {[regexp {(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) (\w+) (.+)} \
        $log_entry -> date time level message]} {
    puts "Date:    $date"
    puts "Time:    $time"
    puts "Level:   $level"
    puts "Message: $message"
}
puts ""

# --- Finding All Matches ---
puts "--- Finding All Matches ---"
set data "Score: 85, Grade: A, Score: 92, Grade: A+, Score: 78, Grade: B+"
set scores [regexp -all -inline {Score: (\d+)} $data]
puts "Raw matches: $scores"
puts "Extracted scores:"
foreach {full score} $scores {
    puts "  $score"
}
puts ""

# --- Email Extraction ---
puts "--- Email Extraction ---"
set text "Contact us at support@example.com or admin@company.org for help. \
Personal: john.doe@mail.co.uk"

set emails [regexp -all -inline {[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}} $text]
puts "Found emails:"
foreach email $emails {
    puts "  $email"
}
puts ""

# --- URL Parsing ---
puts "--- URL Parsing ---"
set url "https://www.example.com:8080/path/to/page?key=value&foo=bar#section"

if {[regexp {^(https?|ftp)://([^/:]+)(?::(\d+))?(/[^?#]*)?(?:\?([^#]*))?(?:#(.*))?$} \
        $url -> scheme host port path query fragment]} {
    puts "URL:      $url"
    puts "Scheme:   $scheme"
    puts "Host:     $host"
    puts "Port:     [expr {$port eq "" ? "(default)" : $port}]"
    puts "Path:     $path"
    puts "Query:    $query"
    puts "Fragment: $fragment"
}
puts ""

# --- Substitution with regsub ---
puts "--- regsub (Substitution) ---"

set text "Today is 2026-03-20 and tomorrow is 2026-03-21"
set result [regsub -all {(\d{4})-(\d{2})-(\d{2})} $text {\2/\3/\1}]
puts "ISO to US dates: $result"

set html "Hello <b>World</b> and <i>TCL</i> is <b>great</b>"
set plain [regsub -all {<[^>]+>} $html ""]
puts "Strip HTML: $plain"

set text "  too   many    spaces   here  "
set clean [string trim [regsub -all {\s+} $text " "]]
puts "Normalize whitespace: '$clean'"

set camel "thisIsCamelCase"
set snake [regsub -all {[A-Z]} $camel {_\0}]
set snake [string tolower $snake]
puts "camelCase to snake_case: $camel -> $snake"
puts ""

# --- Validation Functions ---
puts "--- Validation Functions ---"

proc validate {label pattern value} {
    set result [expr {[regexp $pattern $value] ? "VALID" : "INVALID"}]
    puts [format "  %-20s %-25s %s" $label $value $result]
}

puts [format "  %-20s %-25s %s" "Type" "Value" "Result"]
puts "  [string repeat "-" 55]"

validate "IPv4 Address" {^(\d{1,3}\.){3}\d{1,3}$} "192.168.1.1"
validate "IPv4 Address" {^(\d{1,3}\.){3}\d{1,3}$} "999.1.1"
validate "Phone (US)" {^\(\d{3}\)\s?\d{3}-\d{4}$} "(555) 123-4567"
validate "Phone (US)" {^\(\d{3}\)\s?\d{3}-\d{4}$} "555-1234"
validate "Hex Color" {^#[0-9A-Fa-f]{6}$} "#FF5733"
validate "Hex Color" {^#[0-9A-Fa-f]{6}$} "#GGHHII"
validate "ISO Date" {^\d{4}-\d{2}-\d{2}$} "2026-03-20"
validate "ISO Date" {^\d{4}-\d{2}-\d{2}$} "20-03-2026"
validate "Strong Password" {^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$} "MyPass123"
validate "Strong Password" {^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$} "weak"
puts ""

# --- Log Parser Example ---
puts "--- Practical: Log Parser ---"
set log_lines [list \
    "2026-03-20 10:15:30 INFO  Server started on port 8080" \
    "2026-03-20 10:15:31 INFO  Database connected" \
    "2026-03-20 10:16:02 WARN  Slow query detected (1.5s)" \
    "2026-03-20 10:16:45 ERROR Connection timeout to redis:6379" \
    "2026-03-20 10:17:00 INFO  Request processed: GET /api/users (200)" \
    "2026-03-20 10:17:05 ERROR File not found: /static/missing.js" \
    "2026-03-20 10:17:30 INFO  Request processed: POST /api/data (201)" \
]

set error_count 0
set warn_count 0
puts "Errors and Warnings:"
foreach line $log_lines {
    if {[regexp {(\d{2}:\d{2}:\d{2}) (ERROR|WARN)\s+(.+)} $line -> time level msg]} {
        puts "  \[$time\] $level: $msg"
        if {$level eq "ERROR"} { incr error_count }
        if {$level eq "WARN"} { incr warn_count }
    }
}
puts ""
puts "Summary: $error_count errors, $warn_count warnings out of [llength $log_lines] log entries"
puts ""

puts "Done!"
