#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 14: String Formatting
# =============================================================================

puts "=== format — Basic Specifiers ==="
puts [format "String: %s" "hello"]
puts [format "Integer: %d" 42]
puts [format "Float: %f" 3.14159]
puts [format "Scientific: %e" 123456.789]
puts [format "Shorter of f/e: %g" 123456.789]
puts [format "Hex: %x" 255]
puts [format "Hex (upper): %X" 255]
puts [format "Octal: %o" 255]
puts [format "Character: %c" 65]
puts [format "Percent: 100%%"]

puts "\n=== Width and Precision ==="
puts [format "|%10s|" "right"]
puts [format "|%-10s|" "left"]
puts [format "|%10d|" 42]
puts [format "|%-10d|" 42]
puts [format "|%010d|" 42]
puts [format "|%10.3f|" 3.14159]
puts [format "|%-10.3f|" 3.14159]
puts [format "|%.5s|" "Hello World"]

puts "\n=== Formatting a Table ==="
set header [format "%-15s %8s %10s %6s" "Name" "Age" "Salary" "Dept"]
set separator [string repeat "-" [string length $header]]
puts $header
puts $separator

set employees {
    {"Alice Johnson" 30 75000.50 "Eng"}
    {"Bob Smith" 45 92000.00 "Mgmt"}
    {"Carol Davis" 28 68500.75 "Eng"}
    {"Dave Wilson" 35 81000.25 "Sales"}
    {"Eve Brown" 52 105000.00 "Exec"}
}

foreach emp $employees {
    lassign $emp name age salary dept
    puts [format "%-15s %8d %10.2f %6s" $name $age $salary $dept]
}

puts "\n=== scan — Parsing Strings ==="
set input "Alice 30 3.95"
set count [scan $input "%s %d %f" name age gpa]
puts "Parsed $count fields: name=$name age=$age gpa=$gpa"

puts "\n--- Parsing hex and octal ---"
scan "FF" "%x" decimal
puts "0xFF = $decimal"

scan "377" "%o" decimal
puts "0o377 = $decimal"

puts "\n--- Parsing multiple items ---"
set date_str "2026/03/20"
scan $date_str "%d/%d/%d" year month day
puts "Year=$year Month=$month Day=$day"

set color "#1A2B3C"
scan $color "#%2x%2x%2x" r g b
puts "RGB: ($r, $g, $b)"

puts "\n=== subst — Template Substitution ==="
set name "Alice"
set age 30
set role "Engineer"

set template {Dear $name,

As a $age-year-old $role, you have been selected.

Today's date: [clock format [clock seconds] -format {%Y-%m-%d}]
}

puts "Template result:"
puts [subst $template]

puts "=== Practical: Generating Reports ==="
proc generate_report {title data} {
    set width 50
    set bar [string repeat "=" $width]

    set report "$bar\n"
    append report [format "  %s\n" [string toupper $title]]
    append report "$bar\n\n"

    set total 0
    set max_val 0
    set max_name ""

    dict for {name value} $data {
        append report [format "  %-20s : %8.2f\n" $name $value]
        set total [expr {$total + $value}]
        if {$value > $max_val} {
            set max_val $value
            set max_name $name
        }
    }

    append report "\n[string repeat "-" $width]\n"
    append report [format "  %-20s : %8.2f\n" "TOTAL" $total]
    append report [format "  %-20s : %8.2f\n" "AVERAGE" [expr {$total / [dict size $data]}]]
    append report [format "  %-20s : %s (%8.2f)\n" "HIGHEST" $max_name $max_val]
    append report "$bar\n"

    return $report
}

set sales_data [dict create \
    "North Region" 125000.50 \
    "South Region" 98500.75 \
    "East Region"  142300.00 \
    "West Region"  110750.25 \
]

puts [generate_report "Quarterly Sales Report" $sales_data]

puts "=== Number Formatting Utilities ==="
proc format_currency {amount {symbol "$"}} {
    if {$amount < 0} {
        return "-$symbol[format "%.2f" [expr {abs($amount)}]]"
    }
    return "$symbol[format "%.2f" $amount]"
}

proc format_with_commas {num} {
    set str [format "%.0f" $num]
    set result ""
    set len [string length $str]
    for {set i 0} {$i < $len} {incr i} {
        if {$i > 0 && ($len - $i) % 3 == 0} {
            append result ","
        }
        append result [string index $str $i]
    }
    return $result
}

proc format_bytes {bytes} {
    set units {B KB MB GB TB}
    set idx 0
    set size [expr {double($bytes)}]
    while {$size >= 1024 && $idx < [llength $units] - 1} {
        set size [expr {$size / 1024.0}]
        incr idx
    }
    return [format "%.2f %s" $size [lindex $units $idx]]
}

puts "Currency: [format_currency 1234.5]"
puts "Currency (neg): [format_currency -99.99]"
puts "With commas: [format_with_commas 1234567890]"
puts "Bytes: [format_bytes 1536]"
puts "Bytes: [format_bytes 1048576]"
puts "Bytes: [format_bytes 5368709120]"
