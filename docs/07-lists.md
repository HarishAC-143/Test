# 7. Lists

Lists are one of Tcl's most important data structures. A Tcl list is a string with a specific structure — elements separated by whitespace, with braces or quotes used for grouping.

## Creating Lists

```tcl
# Literal list
set colors {red green blue}

# Using the list command (handles special characters safely)
set data [list "hello world" foo {bar baz}]
# → {hello world} foo {bar baz}

# From a set of values
set nums [list 1 2 3 4 5]

# Empty list
set empty {}
set empty [list]
```

> **Best Practice:** Use the `list` command when constructing lists from variables, as it handles quoting automatically. Use brace notation for literal lists.

```tcl
set name "John Doe"
set bad_list "$name Alice"       ;# → "John Doe Alice" — 3 elements!
set good_list [list $name Alice]  ;# → "{John Doe} Alice" — 2 elements
```

## List Length

```tcl
llength {a b c d}        ;# → 4
llength {}                ;# → 0
llength {{a b} c {d e}}   ;# → 3
```

## Accessing Elements

```tcl
set fruits {apple banana cherry date elderberry}

lindex $fruits 0          ;# → apple
lindex $fruits 2          ;# → cherry
lindex $fruits end         ;# → elderberry
lindex $fruits end-1       ;# → date

# Nested list access
set matrix {{1 2 3} {4 5 6} {7 8 9}}
lindex $matrix 1 2        ;# → 6 (row 1, col 2)
```

## Sublists with `lrange`

```tcl
set nums {10 20 30 40 50 60}

lrange $nums 1 3          ;# → 20 30 40
lrange $nums 0 end-1      ;# → 10 20 30 40 50
lrange $nums 2 end        ;# → 30 40 50 60
```

## Modifying Lists

### Setting an Element

```tcl
set colors {red green blue}
lset colors 1 "lime"
puts $colors   ;# → red lime blue

# Nested modification
set matrix {{1 2} {3 4}}
lset matrix 0 1 99
puts $matrix   ;# → {1 99} {3 4}
```

### Appending Elements

```tcl
set fruits {apple banana}
lappend fruits cherry
lappend fruits date elderberry
puts $fruits   ;# → apple banana cherry date elderberry
```

### Inserting Elements

```tcl
set list {a b c d}
set list [linsert $list 2 X Y]
puts $list   ;# → a b X Y c d

# Insert at the beginning
set list [linsert $list 0 Z]
# → Z a b X Y c d

# Insert at the end (same as lappend)
set list [linsert $list end E]
```

### Replacing Elements

```tcl
set list {a b c d e f}

# Replace element at index 2
set list [lreplace $list 2 2 X]
puts $list   ;# → a b X d e f

# Replace range with new elements
set list [lreplace $list 1 3 P Q]
puts $list   ;# → a P Q e f

# Delete elements (replace with nothing)
set list [lreplace $list 1 2]
puts $list   ;# → a e f
```

## Searching Lists

```tcl
set colors {red green blue green yellow}

# Find first occurrence (returns index or -1)
lsearch $colors "blue"           ;# → 2
lsearch $colors "purple"         ;# → -1

# Find all occurrences
lsearch -all $colors "green"     ;# → 1 3

# Glob pattern search
lsearch -glob $colors "gr*"      ;# → 1

# Return the matched elements instead of indices
lsearch -all -inline $colors "gr*"   ;# → green green

# Sorted list search (binary search — much faster for large lists)
set sorted {apple banana cherry date elderberry}
lsearch -sorted $sorted "cherry"  ;# → 2

# Not matching
lsearch -all -inline -not $colors "green"   ;# → red blue yellow
```

## Sorting Lists

```tcl
set nums {3 1 4 1 5 9 2 6}

# Default: ASCII sort
lsort {banana apple cherry}      ;# → apple banana cherry

# Numeric sort
lsort -integer $nums             ;# → 1 1 2 3 4 5 6 9
lsort -real {3.14 1.0 2.72}      ;# → 1.0 2.72 3.14

# Reverse sort
lsort -integer -decreasing $nums ;# → 9 6 5 4 3 2 1 1

# Remove duplicates
lsort -unique -integer $nums     ;# → 1 2 3 4 5 6 9

# Sort by key (index in sublists)
set data {{Alice 90} {Bob 75} {Carol 95}}
lsort -index 1 -integer $data
# → {Bob 75} {Alice 90} {Carol 95}

# Custom sort with a comparison function
proc by_length {a b} {
    expr {[string length $a] - [string length $b]}
}
lsort -command by_length {cherry apple fig strawberry kiwi}
# → fig kiwi apple cherry strawberry
```

## Joining and Splitting

```tcl
# Join list elements with a separator
join {a b c} ", "          ;# → a, b, c
join {usr local bin} "/"   ;# → usr/local/bin
join {1 2 3} ""            ;# → 123

# Split a string into a list
split "a,b,c,d" ","        ;# → a b c d
split "one::two::three" "::" ;# → one {} two {} three
split "hello" ""           ;# → h e l l o
split "/usr/local/bin" "/" ;# → {} usr local bin
```

## List Iteration

```tcl
set items {apple banana cherry}

# Basic foreach
foreach item $items {
    puts "Item: $item"
}

# With index
set idx 0
foreach item $items {
    puts "$idx: $item"
    incr idx
}

# Multiple variables
set pairs {key1 val1 key2 val2 key3 val3}
foreach {key val} $pairs {
    puts "$key = $val"
}

# Parallel lists
set names {Alice Bob Carol}
set scores {90 85 95}
foreach name $names score $scores {
    puts "$name: $score"
}
```

## List Operations with `lmap` (Tcl 8.6+)

`lmap` (list map) transforms each element:

```tcl
set nums {1 2 3 4 5}

# Square each number
lmap n $nums { expr {$n * $n} }
# → 1 4 9 16 25

# Convert to uppercase
lmap word {hello world tcl} { string toupper $word }
# → HELLO WORLD TCL

# Filter (return empty to exclude)
lmap n {1 2 3 4 5 6 7 8 9 10} {
    if {$n % 2 == 0} { set n } else { continue }
}
# → 2 4 6 8 10

# Multiple variables
lmap {name score} {Alice 90 Bob 85 Carol 95} {
    format "%s: %d%%" $name $score
}
# → {Alice: 90%} {Bob: 85%} {Carol: 95%}
```

## Checking List Membership

```tcl
set fruits {apple banana cherry}

# Using lsearch
if {[lsearch -exact $fruits "banana"] >= 0} {
    puts "banana is in the list"
}

# Using 'in' operator (Tcl 8.5+)
if {"banana" in $fruits} {
    puts "banana is in the list"
}

if {"grape" ni $fruits} {
    puts "grape is not in the list"
}
```

## List as a Stack

```tcl
set stack {}

# Push
lappend stack "first"
lappend stack "second"
lappend stack "third"

# Peek
puts [lindex $stack end]   ;# → third

# Pop
set top [lindex $stack end]
set stack [lrange $stack 0 end-1]
puts $top   ;# → third
puts $stack ;# → first second
```

## List as a Queue

```tcl
set queue {}

# Enqueue
lappend queue "first"
lappend queue "second"
lappend queue "third"

# Dequeue
set front [lindex $queue 0]
set queue [lrange $queue 1 end]
puts $front   ;# → first
puts $queue   ;# → second third
```

## Practical Example: List Statistics

```tcl
proc list_stats {numbers} {
    set sorted [lsort -real $numbers]
    set n [llength $sorted]

    set sum 0.0
    foreach num $numbers {
        set sum [expr {$sum + $num}]
    }
    set mean [expr {$sum / $n}]

    if {$n % 2 == 0} {
        set mid [expr {$n / 2}]
        set median [expr {([lindex $sorted $mid-1] + [lindex $sorted $mid]) / 2.0}]
    } else {
        set median [lindex $sorted [expr {$n / 2}]]
    }

    set min [lindex $sorted 0]
    set max [lindex $sorted end]

    set var_sum 0.0
    foreach num $numbers {
        set var_sum [expr {$var_sum + ($num - $mean) ** 2}]
    }
    set stddev [expr {sqrt($var_sum / $n)}]

    return [dict create \
        count $n sum $sum mean $mean \
        median $median min $min max $max \
        stddev [format "%.4f" $stddev]]
}

set data {23 45 12 67 34 89 56 78 90 11}
set stats [list_stats $data]
dict for {key val} $stats {
    puts [format "  %-8s: %s" $key $val]
}
```

## Practical Example: Matrix Operations

```tcl
proc matrix_create {rows cols {init 0}} {
    set m {}
    for {set r 0} {$r < $rows} {incr r} {
        set row {}
        for {set c 0} {$c < $cols} {incr c} {
            lappend row $init
        }
        lappend m $row
    }
    return $m
}

proc matrix_print {m} {
    foreach row $m {
        set formatted [lmap val $row { format "%6.1f" $val }]
        puts "| [join $formatted " "] |"
    }
}

proc matrix_multiply {a b} {
    set rows_a [llength $a]
    set cols_a [llength [lindex $a 0]]
    set cols_b [llength [lindex $b 0]]

    set result [matrix_create $rows_a $cols_b]
    for {set i 0} {$i < $rows_a} {incr i} {
        for {set j 0} {$j < $cols_b} {incr j} {
            set sum 0.0
            for {set k 0} {$k < $cols_a} {incr k} {
                set sum [expr {$sum + [lindex $a $i $k] * [lindex $b $k $j]}]
            }
            lset result $i $j $sum
        }
    }
    return $result
}

set A {{1 2} {3 4}}
set B {{5 6} {7 8}}
puts "A × B ="
matrix_print [matrix_multiply $A $B]
# | 19.0  22.0 |
# | 43.0  50.0 |
```

---

**Previous:** [String Operations](06-string-operations.md) | **Next:** [Arrays & Dictionaries](08-arrays-and-dictionaries.md)
