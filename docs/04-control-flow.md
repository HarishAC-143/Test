# 4. Control Flow

In Tcl, control-flow structures are regular commands, not special syntax. `if`, `while`, `for`, etc. are all ordinary Tcl commands that take script bodies in braces.

## if / elseif / else

```tcl
set temperature 75

if {$temperature > 90} {
    puts "It's hot!"
} elseif {$temperature > 70} {
    puts "It's warm."
} elseif {$temperature > 50} {
    puts "It's cool."
} else {
    puts "It's cold!"
}
# Output: It's warm.
```

> **Important:** The opening `{` must be on the same line as `if`, `elseif`, or `else`. Tcl's parser treats newlines as command separators, so a brace on the next line would be a syntax error.

```tcl
# WRONG — syntax error
if {$x > 5}
{
    puts "big"
}

# CORRECT
if {$x > 5} {
    puts "big"
}
```

### Single-Line if

```tcl
if {$debug} { puts "Debug mode on" }
set abs [expr {$x >= 0 ? $x : -$x}]
```

## switch

The `switch` command matches a value against patterns:

```tcl
set fruit "apple"

switch $fruit {
    "apple" {
        puts "It's an apple — \$1.50/lb"
    }
    "banana" {
        puts "It's a banana — \$0.75/lb"
    }
    "cherry" {
        puts "It's a cherry — \$4.00/lb"
    }
    default {
        puts "Unknown fruit: $fruit"
    }
}
```

### Switch with `-exact`, `-glob`, and `-regexp`

```tcl
set filename "report.pdf"

switch -glob $filename {
    "*.txt"  { puts "Text file" }
    "*.pdf"  { puts "PDF file" }
    "*.doc*" { puts "Word file" }
    default  { puts "Other: $filename" }
}
# Output: PDF file
```

```tcl
set input "Error: file not found"

switch -regexp $input {
    {^Error:}   { puts "Error message detected" }
    {^Warning:} { puts "Warning message" }
    {^Info:}    { puts "Info message" }
    default     { puts "Unknown format" }
}
```

### Fall-Through with `-`

```tcl
switch $day {
    "Saturday" -
    "Sunday" {
        puts "Weekend!"
    }
    default {
        puts "Weekday"
    }
}
```

## for Loop

C-style for loop:

```tcl
for {set i 0} {$i < 10} {incr i} {
    puts "i = $i"
}
```

### Counting Backwards

```tcl
for {set i 10} {$i > 0} {incr i -1} {
    puts "Countdown: $i"
}
puts "Liftoff!"
```

### Stepping by N

```tcl
for {set i 0} {$i <= 100} {incr i 10} {
    puts "i = $i"
}
```

## while Loop

```tcl
set n 1
while {$n <= 1024} {
    puts "2^? = $n"
    set n [expr {$n * 2}]
}
```

### Reading Input

```tcl
# Read lines until EOF
while {[gets stdin line] >= 0} {
    puts "You said: $line"
}
```

## foreach Loop

Iterate over a list:

```tcl
set colors {red green blue yellow}

foreach color $colors {
    puts "Color: $color"
}
```

### Multiple Variables

```tcl
set pairs {alice 90 bob 85 carol 95}

foreach {name score} $pairs {
    puts "$name scored $score"
}
# Output:
# alice scored 90
# bob scored 85
# carol scored 95
```

### Multiple Lists

```tcl
set names {Alice Bob Carol}
set ages  {30 25 35}

foreach name $names age $ages {
    puts "$name is $age years old"
}
```

### Iterating with Index

```tcl
set items {apple banana cherry}

for {set i 0} {$i < [llength $items]} {incr i} {
    puts "$i: [lindex $items $i]"
}
```

## break and continue

```tcl
# break — exit the loop entirely
for {set i 0} {$i < 100} {incr i} {
    if {$i > 5} break
    puts $i
}
# Output: 0 1 2 3 4 5

# continue — skip to the next iteration
for {set i 0} {$i < 10} {incr i} {
    if {$i % 2 == 0} continue
    puts $i
}
# Output: 1 3 5 7 9
```

## Nested Loops

```tcl
# Multiplication table
for {set i 1} {$i <= 5} {incr i} {
    set row ""
    for {set j 1} {$j <= 5} {incr j} {
        append row [format "%4d" [expr {$i * $j}]]
    }
    puts $row
}
# Output:
#    1   2   3   4   5
#    2   4   6   8  10
#    3   6   9  12  15
#    4   8  12  16  20
#    5  10  15  20  25
```

## Loop Patterns

### Accumulating Results

```tcl
set numbers {3 1 4 1 5 9 2 6}
set sum 0
foreach n $numbers {
    incr sum $n
}
puts "Sum: $sum"   ;# → 31
```

### Filtering

```tcl
set data {12 5 -3 8 -1 20 7}
set positives {}
foreach val $data {
    if {$val > 0} {
        lappend positives $val
    }
}
puts "Positives: $positives"   ;# → 12 5 8 20 7
```

### Transforming (Map)

```tcl
set words {hello world tcl programming}
set upper {}
foreach w $words {
    lappend upper [string toupper $w]
}
puts $upper   ;# → HELLO WORLD TCL PROGRAMMING
```

### Finding (Search)

```tcl
set data {45 12 78 34 90 23}
set max [lindex $data 0]
foreach val $data {
    if {$val > $max} {
        set max $val
    }
}
puts "Maximum: $max"   ;# → 90
```

## Infinite Loop Idiom

```tcl
# Common pattern for event-driven or interactive programs
while {1} {
    puts -nonewline "Enter command (quit to exit): "
    flush stdout
    gets stdin cmd
    if {$cmd eq "quit"} break
    puts "You entered: $cmd"
}
```

## Practical Example: FizzBuzz

```tcl
for {set i 1} {$i <= 30} {incr i} {
    if {$i % 15 == 0} {
        puts "FizzBuzz"
    } elseif {$i % 3 == 0} {
        puts "Fizz"
    } elseif {$i % 5 == 0} {
        puts "Buzz"
    } else {
        puts $i
    }
}
```

## Practical Example: Simple Menu System

```tcl
proc show_menu {} {
    puts "\n=== Main Menu ==="
    puts "1. Say hello"
    puts "2. Show date"
    puts "3. Calculate"
    puts "4. Exit"
    puts -nonewline "Choice: "
    flush stdout
}

while {1} {
    show_menu
    gets stdin choice
    switch $choice {
        1 { puts "Hello, World!" }
        2 { puts "Today: [clock format [clock seconds]]" }
        3 {
            puts -nonewline "Expression: "
            flush stdout
            gets stdin expression
            if {[catch {expr $expression} result]} {
                puts "Error: $result"
            } else {
                puts "Result: $result"
            }
        }
        4 {
            puts "Goodbye!"
            break
        }
        default {
            puts "Invalid choice."
        }
    }
}
```

---

**Previous:** [Operators & Expressions](03-operators-and-expressions.md) | **Next:** [Procedures & Scope](05-procedures-and-scope.md)
