#!/usr/bin/env tclsh
# =============================================================================
# Example 6: Arrays and Dictionaries
# Demonstrates: associative arrays, dict operations, nested dicts, iteration
# =============================================================================

puts "=== Arrays and Dictionaries ===\n"

# =====================
# ARRAYS (Associative)
# =====================
puts "--- Associative Arrays ---"

# Creating arrays
set student(name) "Alice Johnson"
set student(id) "STU001"
set student(gpa) 3.85
set student(major) "Computer Science"

puts "Student Record:"
foreach key [lsort [array names student]] {
    puts [format "  %-10s: %s" $key $student($key)]
}

# array set (bulk initialization)
array set capitals {
    USA         "Washington D.C."
    UK          "London"
    France      "Paris"
    Japan       "Tokyo"
    Australia   "Canberra"
}

puts "\nWorld Capitals:"
puts "  Array size: [array size capitals]"
foreach country [lsort [array names capitals]] {
    puts [format "  %-12s -> %s" $country $capitals($country)]
}

# Pattern matching on array names
puts "\nCountries starting with 'U':"
foreach key [lsort [array names capitals "U*"]] {
    puts "  $key -> $capitals($key)"
}

# Checking existence
puts "\nExistence checks:"
puts "  capitals exists? [array exists capitals]"
puts "  Has USA? [info exists capitals(USA)]"
puts "  Has India? [info exists capitals(India)]"

# Counting word frequencies with arrays
puts "\n--- Word Counter (using arrays) ---"
set text "the cat sat on the mat the cat saw the hat on the mat"
array set word_count {}
foreach word [split $text] {
    if {[info exists word_count($word)]} {
        incr word_count($word)
    } else {
        set word_count($word) 1
    }
}

puts "Word frequencies:"
foreach word [lsort [array names word_count]] {
    puts [format "  %-8s: %d" $word $word_count($word)]
}

# Cleanup
unset student capitals word_count

# ==============
# DICTIONARIES
# ==============
puts "\n--- Dictionaries ---"

# Creating dictionaries
set person [dict create \
    name    "Bob Smith" \
    age     35 \
    email   "bob@example.com" \
    active  true \
]

puts "Person:"
dict for {key value} $person {
    puts [format "  %-10s: %s" $key $value]
}

puts "\nDict info:"
puts "  Size: [dict size $person]"
puts "  Keys: [dict keys $person]"
puts "  Has email? [dict exists $person email]"
puts "  Has phone? [dict exists $person phone]"

# Modifying
dict set person phone "555-1234"
dict set person age 36
dict unset person active
puts "\nAfter modification:"
dict for {key value} $person {
    puts [format "  %-10s: %s" $key $value]
}

# --- Nested Dictionaries ---
puts "\n--- Nested Dictionaries ---"
set company [dict create \
    name "TechCorp" \
    departments [dict create \
        engineering [dict create \
            head "Alice" \
            count 25 \
            budget 1000000 \
        ] \
        marketing [dict create \
            head "Bob" \
            count 12 \
            budget 500000 \
        ] \
        sales [dict create \
            head "Carol" \
            count 18 \
            budget 750000 \
        ] \
    ] \
]

puts "Company: [dict get $company name]"
puts "\nDepartments:"
dict for {dept info} [dict get $company departments] {
    puts [format "  %-15s Head: %-8s Staff: %2d  Budget: \$%s" \
        $dept \
        [dict get $info head] \
        [dict get $info count] \
        [dict get $info budget]]
}

# Modify nested value
dict set company departments engineering count 30
puts "\nEngineering now has [dict get $company departments engineering count] people."

# --- dict filter ---
puts "\n--- Dict Filtering ---"
set inventory [dict create \
    apples 50 bananas 30 cherries 15 \
    dates 42 elderberries 8 figs 35 \
]

puts "Full inventory:"
dict for {item count} $inventory {
    puts [format "  %-15s %3d" $item $count]
}

set low_stock [dict filter $inventory script {k v} {expr {$v < 20}}]
puts "\nLow stock (< 20):"
dict for {item count} $low_stock {
    puts [format "  %-15s %3d  ** REORDER **" $item $count]
}

# --- dict merge ---
puts "\n--- Dict Merge ---"
set defaults [dict create theme dark font_size 14 language en show_tips true]
set user_prefs [dict create theme light font_size 18]
set final [dict merge $defaults $user_prefs]

puts "Defaults:    $defaults"
puts "User prefs:  $user_prefs"
puts "Merged:      $final"

# --- Dict as a simple record system ---
puts "\n--- Student Records ---"
set students [list]
lappend students [dict create name "Alice" grade A gpa 3.9]
lappend students [dict create name "Bob" grade B gpa 3.2]
lappend students [dict create name "Carol" grade A gpa 3.8]
lappend students [dict create name "David" grade C gpa 2.7]

puts [format "  %-10s %-6s %-5s" "Name" "Grade" "GPA"]
puts "  [string repeat - 25]"
foreach student $students {
    puts [format "  %-10s %-6s %-5.1f" \
        [dict get $student name] \
        [dict get $student grade] \
        [dict get $student gpa]]
}

# Calculate average GPA
set total_gpa 0.0
foreach student $students {
    set total_gpa [expr {$total_gpa + [dict get $student gpa]}]
}
set avg_gpa [expr {$total_gpa / [llength $students]}]
puts [format "\n  Average GPA: %.2f" $avg_gpa]

puts "\nDone."
