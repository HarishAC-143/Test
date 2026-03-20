#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 05: Dictionaries
# =============================================================================

puts "=== Creating Dictionaries ==="
set person [dict create name "Alice" age 30 city "Portland" email "alice@example.com"]
puts "Person: $person"

puts "\n=== Accessing Values ==="
puts "Name: [dict get $person name]"
puts "Age: [dict get $person age]"
puts "City: [dict get $person city]"

puts "\n=== Setting Values ==="
dict set person phone "555-1234"
dict set person age 31
puts "Updated: $person"

puts "\n=== Checking Existence ==="
puts "Has 'name'? [dict exists $person name]"
puts "Has 'salary'? [dict exists $person salary]"

puts "\n=== Removing Keys ==="
dict unset person phone
puts "After removing 'phone': $person"

puts "\n=== Size, Keys, Values ==="
puts "Size: [dict size $person]"
puts "Keys: [dict keys $person]"
puts "Values: [dict values $person]"

puts "\n=== Iterating ==="
dict for {key value} $person {
    puts [format "  %-8s => %s" $key $value]
}

puts "\n=== Nested Dictionaries ==="
set company [dict create \
    name "Acme Corp" \
    founded 1990 \
    ceo [dict create \
        name "Bob Smith" \
        age 55 \
        email "bob@acme.com" \
    ] \
    departments [dict create \
        engineering 50 \
        marketing 20 \
        sales 30 \
    ] \
]

puts "Company: [dict get $company name]"
puts "CEO: [dict get $company ceo name]"
puts "CEO Email: [dict get $company ceo email]"
puts "Engineering headcount: [dict get $company departments engineering]"

puts "\n=== Modifying Nested Values ==="
dict set company ceo age 56
dict set company departments hr 10
puts "CEO age now: [dict get $company ceo age]"
puts "HR added: [dict get $company departments hr]"

puts "\n=== Filtering ==="
set long_keys [dict filter $person key "????*"]
puts "Keys with 4+ chars: $long_keys"

set string_vals [dict filter $person value {[a-zA-Z]*}]
puts "Values starting with a letter: $string_vals"

set filtered [dict filter $person script {k v} {
    expr {[string length $v] > 3}
}]
puts "Values longer than 3 chars: $filtered"

puts "\n=== Dict Merge ==="
set defaults [dict create color "red" size "medium" verbose false]
set user_prefs [dict create size "large" verbose true]
set config [dict merge $defaults $user_prefs]
puts "Merged config: $config"

puts "\n=== Dict Replace ==="
set updated [dict replace $person name "Alice Johnson" age 32]
puts "Replaced: $updated"

puts "\n=== Dict Increment (dict incr) ==="
set scores [dict create alice 10 bob 20 charlie 15]
dict incr scores alice 5
dict incr scores bob -3
puts "Scores after incr: $scores"

puts "\n=== Dict lappend ==="
set tags [dict create]
dict lappend tags alice "python"
dict lappend tags alice "tcl"
dict lappend tags bob "java"
dict lappend tags bob "go"
puts "Tags: $tags"
puts "Alice's tags: [dict get $tags alice]"

puts "\n=== Using Dict as a Simple Record ==="
proc create_point {x y} {
    return [dict create x $x y $y]
}

proc point_distance {p1 p2} {
    set dx [expr {[dict get $p1 x] - [dict get $p2 x]}]
    set dy [expr {[dict get $p1 y] - [dict get $p2 y]}]
    return [expr {sqrt($dx*$dx + $dy*$dy)}]
}

set p1 [create_point 0 0]
set p2 [create_point 3 4]
puts "Point 1: $p1"
puts "Point 2: $p2"
puts "Distance: [point_distance $p1 $p2]"
