#!/usr/bin/env tclsh
# =============================================================================
# Example 9: Regular Expressions
# Demonstrates: regexp, regsub, capture groups, practical patterns
# =============================================================================

puts "=== Regular Expressions ===\n"

# --- Basic matching ---
puts "--- Basic Matching ---"
set text "The quick brown fox jumps over the lazy dog"

puts "  Contains 'fox'? [regexp {fox} $text]"
puts "  Contains 'cat'? [regexp {cat} $text]"
puts "  Starts with 'The'? [regexp {^The} $text]"
puts "  Ends with 'dog'? [regexp {dog$} $text]"

# --- Capture groups ---
puts "\n--- Capture Groups ---"
set line "Error 404: Page not found at /index.html"

if {[regexp {(\w+) (\d+): (.+) at (.+)} $line full type code msg path]} {
    puts "  Full match: $full"
    puts "  Type: $type"
    puts "  Code: $code"
    puts "  Message: $msg"
    puts "  Path: $path"
}

# --- Find all matches ---
puts "\n--- Find All Matches ---"
set text "Call 555-1234 or 555-5678 or 555-9999"
set phones [regexp -all -inline {\d{3}-\d{4}} $text]
puts "  Phone numbers found: $phones"
puts "  Count: [expr {[llength $phones]}]"

# --- Case-insensitive matching ---
puts "\n--- Case-Insensitive ---"
set text "Hello WORLD hello World"
set matches [regexp -all -inline -nocase {hello} $text]
puts "  'hello' matches (case-insensitive): $matches"

# --- Email validation ---
puts "\n--- Email Validation ---"
proc validate_email {email} {
    return [regexp {^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$} $email]
}

foreach email {"user@example.com" "bad-email" "test@sub.domain.org" "@missing.com" "a@b.c"} {
    set valid [validate_email $email]
    puts [format "  %-25s -> %s" $email [expr {$valid ? "VALID" : "INVALID"}]]
}

# --- IP Address validation ---
puts "\n--- IP Address Validation ---"
proc validate_ip {ip} {
    if {![regexp {^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$} $ip _ a b c d]} {
        return 0
    }
    foreach octet [list $a $b $c $d] {
        if {$octet > 255} { return 0 }
    }
    return 1
}

foreach ip {"192.168.1.1" "10.0.0.1" "256.1.2.3" "1.2.3" "127.0.0.1"} {
    puts [format "  %-20s -> %s" $ip [expr {[validate_ip $ip] ? "VALID" : "INVALID"}]]
}

# --- Date parsing ---
puts "\n--- Date Parsing ---"
set dates {
    "2024-01-15"
    "2024/06/30"
    "15-Jan-2024"
    "March 5, 2024"
}

foreach date $dates {
    puts -nonewline "  $date -> "
    if {[regexp {^(\d{4})-(\d{2})-(\d{2})$} $date _ y m d]} {
        puts "ISO format: year=$y month=$m day=$d"
    } elseif {[regexp {^(\d{4})/(\d{2})/(\d{2})$} $date _ y m d]} {
        puts "Slash format: year=$y month=$m day=$d"
    } elseif {[regexp {^(\d{2})-(\w{3})-(\d{4})$} $date _ d m y]} {
        puts "DD-Mon-YYYY: day=$d month=$m year=$y"
    } elseif {[regexp {^(\w+)\s+(\d+),\s+(\d{4})$} $date _ m d y]} {
        puts "Written: month=$m day=$d year=$y"
    } else {
        puts "Unknown format"
    }
}

# --- Log line parsing ---
puts "\n--- Log Line Parsing ---"
set log_lines {
    "2024-01-15 10:30:45 INFO  Server started on port 8080"
    "2024-01-15 10:31:02 WARN  High memory usage: 85%"
    "2024-01-15 10:31:15 ERROR Connection refused to database"
    "2024-01-15 10:32:00 INFO  Request processed in 150ms"
}

foreach line $log_lines {
    if {[regexp {(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\w+)\s+(.*)} $line _ date time level msg]} {
        puts [format "  \[%s\] %s %s: %s" $level $date $time $msg]
    }
}

# --- regsub: Search and Replace ---
puts "\n--- regsub (Search and Replace) ---"

# Basic replacement
set text "Hello, World!"
puts "  Replace World: [regsub {World} $text {TCL}]"

# Replace all
set text "aaa bbb aaa ccc aaa"
puts "  Replace all 'aaa': [regsub -all {aaa} $text {xxx}]"

# Backreferences
set name "John Smith"
puts "  Swap name: [regsub {(\w+)\s+(\w+)} $name {\2, \1}]"

# Remove HTML tags
set html "<h1>Title</h1><p>Hello <b>World</b></p>"
puts "  Strip HTML: [regsub -all {<[^>]+>} $html {}]"

# Normalize whitespace
set messy "  too   many    spaces   here  "
puts "  Normalize: '[string trim [regsub -all {\s+} $messy { }]]'"

# Mask sensitive data
set data "SSN: 123-45-6789, Phone: 555-123-4567"
puts "  Mask SSN: [regsub {\d{3}-\d{2}-\d{4}} $data {***-**-****}]"

# CamelCase to snake_case
proc camel_to_snake {str} {
    set result [regsub -all {([A-Z])} $str {_\1}]
    return [string tolower [string trimleft $result "_"]]
}
puts "  CamelCase: [camel_to_snake "myVariableName"]"
puts "  CamelCase: [camel_to_snake "HTTPServerResponse"]"

# --- URL parsing ---
puts "\n--- URL Parsing ---"
set url "https://www.example.com:8443/path/to/page?query=value&lang=en#section"

if {[regexp {^(\w+)://([^/:]+)(?::(\d+))?(/[^?#]*)?(?:\?([^#]*))?(?:#(.*))?$} \
        $url _ scheme host port path query fragment]} {
    puts "  Scheme:   $scheme"
    puts "  Host:     $host"
    puts "  Port:     [expr {$port ne "" ? $port : "(default)"}]"
    puts "  Path:     $path"
    puts "  Query:    $query"
    puts "  Fragment: $fragment"
}

puts "\nDone."
