# 8. Arrays & Dictionaries

Tcl provides two associative data structures: **arrays** (a variable type with named elements) and **dictionaries** (a value type introduced in Tcl 8.5).

## Arrays

### Creating and Accessing Arrays

```tcl
# Set individual elements
set person(name) "Alice"
set person(age) 30
set person(city) "New York"

# Access elements
puts $person(name)   ;# → Alice
puts $person(age)    ;# → 30
```

### Array from a List

```tcl
array set config {
    host     localhost
    port     8080
    debug    false
    timeout  30
}

puts $config(host)     ;# → localhost
puts $config(port)     ;# → 8080
```

### Array Operations

```tcl
array set fruits {apple 1.50 banana 0.75 cherry 4.00}

# Check if array exists
array exists fruits       ;# → 1

# Get all element names
array names fruits        ;# → apple banana cherry (order not guaranteed)

# Get names matching a pattern
array names fruits "c*"   ;# → cherry

# Get size
array size fruits         ;# → 3

# Convert to flat list (name value pairs)
array get fruits          ;# → apple 1.50 banana 0.75 cherry 4.00

# Check if element exists
info exists fruits(apple)     ;# → 1
info exists fruits(grape)     ;# → 0

# Delete an element
unset fruits(banana)

# Delete entire array
unset fruits
```

### Iterating Over Arrays

```tcl
array set scores {Alice 90 Bob 85 Carol 95 Dave 78}

# Using array names
foreach name [lsort [array names scores]] {
    puts [format "%-10s %3d" $name $scores($name)]
}

# Using array get (pairs)
foreach {name score} [array get scores] {
    puts "$name: $score"
}

# Using array searching
set search [array startsearch scores]
while {[array anymore scores $search]} {
    set name [array nextelement scores $search]
    puts "$name: $scores($name)"
}
array donesearch scores $search
```

### Array as a Counter (Histogram)

```tcl
set words {the quick brown fox jumps over the lazy dog the fox}

array set count {}
foreach word $words {
    if {![info exists count($word)]} {
        set count($word) 0
    }
    incr count($word)
}

foreach word [lsort [array names count]] {
    puts [format "%-10s %s" $word [string repeat "#" $count($word)]]
}
# Output:
# brown      #
# dog        #
# fox        ##
# jumps      #
# lazy       #
# over       #
# quick      #
# the        ###
```

### Arrays Cannot Be Passed by Value

Arrays are not values — they are a special variable type. You cannot pass them directly to procedures:

```tcl
# WRONG — this does not work
# proc show {arr} { puts $arr(name) }
# show $person   ;# ERROR

# Correct — pass array name, use upvar
proc show_array {arrName} {
    upvar 1 $arrName arr
    foreach key [lsort [array names arr]] {
        puts [format "%-15s = %s" $key $arr($key)]
    }
}

array set person {name Alice age 30 city "New York"}
show_array person
```

## Dictionaries (Tcl 8.5+)

Dictionaries are **values** (unlike arrays), making them passable, nestable, and storable in lists. They are ordered key-value structures.

### Creating Dictionaries

```tcl
# Using dict create
set person [dict create name "Alice" age 30 city "New York"]

# Literal (keys and values alternate)
set config {host localhost port 8080 debug false}

# The format is the same as a flat list of key-value pairs
```

### Basic Dict Operations

```tcl
set d [dict create name "Alice" age 30]

# Get a value
dict get $d name          ;# → Alice
dict get $d age           ;# → 30

# Set a value (returns new dict)
set d [dict set d email "alice@example.com"]

# Check key existence
dict exists $d name       ;# → 1
dict exists $d phone      ;# → 0

# Remove a key
set d [dict remove $d age]

# Get size (number of key-value pairs)
dict size $d              ;# → 2

# Get all keys
dict keys $d              ;# → name email

# Get all values
dict values $d            ;# → Alice alice@example.com
```

### Modifying Dict Values

```tcl
set d [dict create count 0 name "test"]

# Increment a value
dict incr d count
dict incr d count 5
puts [dict get $d count]   ;# → 6

# Append to a value
dict append d name "_v2"
puts [dict get $d name]    ;# → test_v2

# Lappend to a value (treat value as list)
dict lappend d tags "important"
dict lappend d tags "urgent"
puts [dict get $d tags]    ;# → important urgent
```

### Iterating Over Dictionaries

```tcl
set person [dict create name "Alice" age 30 city "New York"]

# dict for — preserves insertion order
dict for {key value} $person {
    puts "$key: $value"
}
# Output:
# name: Alice
# age: 30
# city: New York
```

### Nested Dictionaries

```tcl
set employees [dict create \
    alice [dict create \
        title "Engineer" \
        department "R&D" \
        salary 95000] \
    bob [dict create \
        title "Manager" \
        department "Sales" \
        salary 85000] \
    carol [dict create \
        title "Director" \
        department "R&D" \
        salary 120000]]

# Access nested values with multiple keys
dict get $employees alice title      ;# → Engineer
dict get $employees bob salary       ;# → 85000

# Modify nested values
dict set employees alice salary 100000

# Check nested existence
dict exists $employees carol department   ;# → 1
```

### Filtering Dictionaries

```tcl
set data [dict create a 1 b 2 c 3 d 4 e 5]

# Filter keys matching pattern
dict filter $data key {[a-c]}
# → a 1 b 2 c 3

# Filter by value
dict filter $data value {[1-3]}
# → a 1 b 2 c 3

# Filter with a script
dict filter $data script {k v} {
    expr {$v > 2}
}
# → c 3 d 4 e 5
```

### Dict Merge

```tcl
set defaults [dict create color blue size medium debug false]
set overrides [dict create color red debug true]

set config [dict merge $defaults $overrides]
# → color red size medium debug true
```

### Dict Map (Tcl 8.6+)

```tcl
set prices [dict create apple 1.50 banana 0.75 cherry 4.00]

# Apply 10% discount
set discounted [dict map {fruit price} $prices {
    format "%.2f" [expr {$price * 0.9}]
}]
# → apple 1.35 banana 0.68 cherry 3.60
```

### Dict Update and With

```tcl
set person [dict create name "Alice" age 30]

# dict update — bind dict values to local variables
dict update person name n age a {
    set n [string toupper $n]
    incr a
}
puts $person   ;# → name ALICE age 31

# dict with — simpler syntax
dict with person {
    puts "Name: $name, Age: $age"
}
```

## Arrays vs. Dictionaries

| Feature | Arrays | Dictionaries |
|---------|--------|--------------|
| **Type** | Variable type | Value type |
| **Pass to proc** | By name (upvar) | By value |
| **Nestable** | No | Yes |
| **Store in list** | No | Yes |
| **Order** | Unordered | Ordered |
| **Syntax** | `$arr(key)` | `dict get $d key` |
| **Traces** | Yes | No |
| **Performance** | Faster for large datasets | Faster for small datasets |
| **Use case** | Global state, caches | Structured data, configs |

## Practical Example: Configuration Manager

```tcl
proc config_new {} {
    return [dict create]
}

proc config_load {filename} {
    set config [dict create]
    set f [open $filename r]
    set section ""
    while {[gets $f line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string index $line 0] eq "#"} continue

        if {[regexp {^\[(.+)\]$} $line -> sec]} {
            set section $sec
        } elseif {[regexp {^(\w+)\s*=\s*(.*)$} $line -> key val]} {
            if {$section ne ""} {
                dict set config $section $key [string trim $val]
            } else {
                dict set config $key [string trim $val]
            }
        }
    }
    close $f
    return $config
}

proc config_get {config args} {
    if {[dict exists $config {*}$args]} {
        return [dict get $config {*}$args]
    }
    return ""
}
```

## Practical Example: Student Records Database

```tcl
set students [dict create]

proc add_student {name age grade} {
    upvar 1 students db
    set id [dict size $db]
    dict set db $id [dict create \
        name $name age $age grade $grade \
        enrolled [clock format [clock seconds] -format "%Y-%m-%d"]]
    return $id
}

proc find_by_grade {db min_grade} {
    set results {}
    dict for {id record} $db {
        if {[dict get $record grade] >= $min_grade} {
            lappend results $record
        }
    }
    return $results
}

proc print_students {db} {
    puts [format "%-4s %-15s %-5s %-6s %-12s" ID Name Age Grade Enrolled]
    puts [string repeat "-" 48]
    dict for {id record} $db {
        dict with record {
            puts [format "%-4s %-15s %-5s %-6.1f %-12s" $id $name $age $grade $enrolled]
        }
    }
}

add_student "Alice" 20 3.8
add_student "Bob" 22 3.2
add_student "Carol" 21 3.9
add_student "Dave" 23 2.8

puts "All Students:"
print_students $students

puts "\nHonor Roll (GPA >= 3.5):"
foreach record [find_by_grade $students 3.5] {
    puts "  [dict get $record name]: [dict get $record grade]"
}
```

---

**Previous:** [Lists](07-lists.md) | **Next:** [File I/O & System Interaction](09-file-io-and-system.md)
