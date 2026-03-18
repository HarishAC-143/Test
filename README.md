# TCL Programming: A Comprehensive Tutorial with Examples

**TCL (Tool Command Language)** is a dynamic, interpreted scripting language created by John Ousterhout in 1988. Known for its simplicity, extensibility, and embeddability, TCL is widely used in EDA (Electronic Design Automation) tools, network testing, rapid prototyping, and GUI development (via Tk). This tutorial covers TCL from fundamentals through advanced topics, with practical examples throughout.

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Basic Syntax and Commands](#2-basic-syntax-and-commands)
3. [Variables and Data Types](#3-variables-and-data-types)
4. [Operators and Expressions](#4-operators-and-expressions)
5. [Control Flow](#5-control-flow)
6. [String Operations](#6-string-operations)
7. [Lists](#7-lists)
8. [Arrays (Associative)](#8-arrays-associative)
9. [Dictionaries](#9-dictionaries)
10. [Procedures](#10-procedures)
11. [File I/O](#11-file-io)
12. [Regular Expressions](#12-regular-expressions)
13. [Error Handling](#13-error-handling)
14. [Namespaces](#14-namespaces)
15. [Packages](#15-packages)
16. [Event-Driven Programming](#16-event-driven-programming)
17. [Practical Examples](#17-practical-examples)
18. [Quick Reference](#18-quick-reference)

---

## 1. Getting Started

### What is TCL?

TCL treats **everything as a string**. Commands, variables, data — all are strings that get interpreted in context. This "everything is a string" philosophy makes TCL remarkably flexible and consistent.

### Installation

**Linux (Debian/Ubuntu):**

```bash
sudo apt-get install tcl
```

**Linux (RHEL/CentOS):**

```bash
sudo yum install tcl
```

**macOS (Homebrew):**

```bash
brew install tcl-tk
```

**Verify installation:**

```bash
tclsh
# You should see a '%' prompt
```

### Running TCL Scripts

**Interactive mode:**

```bash
tclsh
% puts "Hello, World!"
Hello, World!
```

**Script file:**

```bash
# Save as hello.tcl
tclsh hello.tcl
```

**With shebang:**

```tcl
#!/usr/bin/env tclsh
puts "Hello, World!"
```

```bash
chmod +x hello.tcl
./hello.tcl
```

---

## 2. Basic Syntax and Commands

### The Fundamental Rule

Every TCL statement follows the same structure:

```
command arg1 arg2 arg3 ...
```

The first word is the **command name**, and everything that follows is an **argument**. Words are separated by whitespace. This uniform syntax applies to everything — there are no special statement forms.

### Comments

```tcl
# This is a comment (must be the first non-whitespace on a line or after a semicolon)

set x 10  ;# This is an inline comment (note the semicolon)
```

### Quoting and Substitution

TCL has three quoting mechanisms, each with different substitution rules:

```tcl
# Double quotes: allow variable and command substitution
set name "World"
puts "Hello, $name"          ;# Output: Hello, World
puts "2 + 3 = [expr {2+3}]" ;# Output: 2 + 3 = 5

# Curly braces: no substitution (literal string)
puts {Hello, $name}          ;# Output: Hello, $name
puts {No [substitution] here} ;# Output: No [substitution] here

# Backslash: escape special characters
puts "She said \"hello\""    ;# Output: She said "hello"
puts "Line1\nLine2"          ;# Output on two lines
puts "Tab\there"             ;# Output with tab
```

### Command Substitution

Square brackets `[...]` evaluate the enclosed command and substitute its result:

```tcl
set now [clock seconds]
puts "Epoch time: $now"

set formatted [clock format $now -format "%Y-%m-%d %H:%M:%S"]
puts "Current time: $formatted"

# Nesting is allowed
puts "Length of name: [string length [set name "Tcl"]]"
```

### Multi-line Commands

Use a backslash at the end of a line to continue on the next:

```tcl
set long_result [expr { 1 + 2 + 3 + \
                        4 + 5 + 6 }]

# Or use braces (the opening brace keeps the command open)
if {$x > 5} {
    puts "x is greater than 5"
}
```

### Multiple Commands on One Line

Separate commands with a semicolon:

```tcl
set a 10; set b 20; puts "$a + $b = [expr {$a + $b}]"
```

---

## 3. Variables and Data Types

### Setting and Reading Variables

```tcl
# set assigns a value; $ reads it
set greeting "Hello"
set count 42
set pi 3.14159

puts $greeting   ;# Hello
puts $count      ;# 42
puts $pi         ;# 3.14159

# 'set' with one argument returns the current value
puts [set count] ;# 42 (equivalent to $count)
```

### Variable Substitution Details

```tcl
set fruit "apple"
puts "I like ${fruit}s"     ;# Braces delimit the variable name -> "I like apples"
puts "I like $fruit!!!"     ;# '!' is not alphanumeric, so $fruit resolves -> "I like apple!!!"
```

### Checking Variable Existence

```tcl
set x 10

if {[info exists x]} {
    puts "x exists and is $x"
}

if {![info exists y]} {
    puts "y does not exist"
}
```

### Unsetting Variables

```tcl
set temp "temporary"
unset temp
# puts $temp  ;# Error: can't read "temp": no such variable
```

### Environment Variables

```tcl
# Read environment variables
puts "Home directory: $::env(HOME)"
puts "Path: $::env(PATH)"

# Set environment variables
set ::env(MY_VAR) "my_value"
```

### Numeric Types

TCL stores everything as a string internally but interprets values as numbers when needed:

```tcl
set int_val 42
set float_val 3.14
set hex_val 0xFF       ;# 255 in decimal
set octal_val 0o77     ;# 63 in decimal
set binary_val 0b1010  ;# 10 in decimal
set sci_val 1.5e3      ;# 1500.0

puts [expr {$int_val + $float_val}]   ;# 45.14
puts [expr {$hex_val}]                ;# 255
```

### Boolean Values

TCL recognizes several boolean representations:

```tcl
# True: 1, true, yes, on (case-insensitive)
# False: 0, false, no, off (case-insensitive)

set flag true
if {$flag} {
    puts "Flag is true"
}

set enabled "yes"
if {$enabled} {
    puts "Enabled"
}
```

---

## 4. Operators and Expressions

All arithmetic and logical operations are performed inside the `expr` command. Always **brace your expressions** for safety and performance.

### Arithmetic Operators

```tcl
set a 15
set b 4

puts [expr {$a + $b}]    ;# 19   Addition
puts [expr {$a - $b}]    ;# 11   Subtraction
puts [expr {$a * $b}]    ;# 60   Multiplication
puts [expr {$a / $b}]    ;# 3    Integer division
puts [expr {$a % $b}]    ;# 3    Modulo
puts [expr {$a ** $b}]   ;# 50625  Exponentiation
puts [expr {double($a) / $b}]  ;# 3.75  Floating-point division
```

### Comparison Operators

```tcl
set x 10
set y 20

puts [expr {$x == $y}]   ;# 0 (false)
puts [expr {$x != $y}]   ;# 1 (true)
puts [expr {$x < $y}]    ;# 1
puts [expr {$x > $y}]    ;# 0
puts [expr {$x <= $y}]   ;# 1
puts [expr {$x >= $y}]   ;# 0
```

### Logical Operators

```tcl
set p 1
set q 0

puts [expr {$p && $q}]   ;# 0  Logical AND
puts [expr {$p || $q}]   ;# 1  Logical OR
puts [expr {!$p}]        ;# 0  Logical NOT
```

### Bitwise Operators

```tcl
set m 0b1100   ;# 12
set n 0b1010   ;# 10

puts [expr {$m & $n}]    ;# 8   (1000) AND
puts [expr {$m | $n}]    ;# 14  (1110) OR
puts [expr {$m ^ $n}]    ;# 6   (0110) XOR
puts [expr {~$m}]        ;# -13         NOT
puts [expr {$m << 2}]    ;# 48  Left shift
puts [expr {$m >> 1}]    ;# 6   Right shift
```

### Ternary Operator

```tcl
set age 20
set status [expr {$age >= 18 ? "adult" : "minor"}]
puts $status  ;# adult
```

### Math Functions

```tcl
puts [expr {abs(-42)}]        ;# 42
puts [expr {round(3.7)}]      ;# 4
puts [expr {int(3.9)}]        ;# 3  (truncates)
puts [expr {ceil(3.2)}]       ;# 4.0
puts [expr {floor(3.9)}]      ;# 3.0
puts [expr {sqrt(144)}]       ;# 12.0
puts [expr {pow(2, 10)}]      ;# 1024.0
puts [expr {log(100)}]        ;# 4.605... (natural log)
puts [expr {log10(100)}]      ;# 2.0
puts [expr {sin(3.14159/2)}]  ;# ~1.0
puts [expr {max(3, 7, 1, 9)}] ;# 9
puts [expr {min(3, 7, 1, 9)}] ;# 1
puts [expr {rand()}]          ;# Random float [0, 1)
puts [expr {int(rand()*100)}] ;# Random integer [0, 99]
```

---

## 5. Control Flow

### if / elseif / else

```tcl
set score 85

if {$score >= 90} {
    puts "Grade: A"
} elseif {$score >= 80} {
    puts "Grade: B"
} elseif {$score >= 70} {
    puts "Grade: C"
} elseif {$score >= 60} {
    puts "Grade: D"
} else {
    puts "Grade: F"
}
# Output: Grade: B
```

> **Important:** The opening brace `{` **must** be on the same line as `if`, `elseif`, or `else`. TCL's parser sees the newline as a command terminator, so placing braces on the next line causes a syntax error.

### switch

```tcl
set color "green"

switch $color {
    "red"    { puts "Stop" }
    "yellow" { puts "Caution" }
    "green"  { puts "Go" }
    default  { puts "Unknown color" }
}
# Output: Go
```

**Pattern matching with switch:**

```tcl
set input "hello123"

switch -regexp $input {
    {^[0-9]+$}    { puts "All digits" }
    {^[a-z]+$}    { puts "All lowercase" }
    {^[a-z]+[0-9]+$} { puts "Letters followed by digits" }
    default       { puts "Other pattern" }
}
# Output: Letters followed by digits
```

**Glob matching:**

```tcl
set filename "report.pdf"

switch -glob $filename {
    *.txt  { puts "Text file" }
    *.pdf  { puts "PDF file" }
    *.csv  { puts "CSV file" }
    default { puts "Other file type" }
}
# Output: PDF file
```

### while Loop

```tcl
set i 0
while {$i < 5} {
    puts "i = $i"
    incr i
}
# Output: i = 0, i = 1, i = 2, i = 3, i = 4
```

### for Loop

```tcl
for {set i 0} {$i < 5} {incr i} {
    puts "Iteration $i"
}
```

**Counting backwards:**

```tcl
for {set i 10} {$i > 0} {incr i -2} {
    puts "Countdown: $i"
}
# Output: 10, 8, 6, 4, 2
```

### foreach Loop

```tcl
# Iterate over a list
set fruits {apple banana cherry date}
foreach fruit $fruits {
    puts "Fruit: $fruit"
}

# Multiple variables
set pairs {name Alice age 30 city Boston}
foreach {key value} $pairs {
    puts "$key => $value"
}
# Output: name => Alice, age => 30, city => Boston

# Multiple lists
set names {Alice Bob Carol}
set ages  {30 25 35}
foreach name $names age $ages {
    puts "$name is $age years old"
}
```

### Loop Control: break and continue

```tcl
# break exits the loop
for {set i 0} {$i < 10} {incr i} {
    if {$i == 5} {
        break
    }
    puts $i
}
# Output: 0 1 2 3 4

# continue skips to the next iteration
for {set i 0} {$i < 10} {incr i} {
    if {$i % 2 == 0} {
        continue
    }
    puts $i
}
# Output: 1 3 5 7 9
```

---

## 6. String Operations

### Basic String Commands

```tcl
set str "Hello, World!"

# Length
puts [string length $str]   ;# 13

# Index (0-based)
puts [string index $str 0]  ;# H
puts [string index $str end] ;# !

# Range (substring)
puts [string range $str 0 4]     ;# Hello
puts [string range $str 7 end]   ;# World!
```

### Case Conversion

```tcl
set str "Hello, World!"

puts [string toupper $str]     ;# HELLO, WORLD!
puts [string tolower $str]     ;# hello, world!
puts [string totitle $str]     ;# Hello, world!
puts [string totitle "hello world"]  ;# Hello world
```

### Searching

```tcl
set str "Hello, World! Hello, TCL!"

# First occurrence (returns index or -1)
puts [string first "Hello" $str]      ;# 0
puts [string first "Hello" $str 1]    ;# 14 (start searching from index 1)
puts [string first "Python" $str]     ;# -1

# Last occurrence
puts [string last "Hello" $str]       ;# 14
```

### String Comparison

```tcl
# Case-sensitive comparison (returns -1, 0, or 1)
puts [string compare "abc" "def"]     ;# -1 (abc < def)
puts [string compare "abc" "abc"]     ;# 0  (equal)
puts [string compare "def" "abc"]     ;# 1  (def > abc)

# Case-insensitive comparison
puts [string compare -nocase "ABC" "abc"]  ;# 0

# Equality check
puts [string equal "hello" "hello"]        ;# 1
puts [string equal -nocase "Hello" "hello"] ;# 1
```

### Pattern Matching

```tcl
# Glob-style matching
puts [string match "*.tcl" "script.tcl"]    ;# 1
puts [string match "H*" "Hello"]            ;# 1
puts [string match {[A-Z]*} "Hello"]        ;# 1
puts [string match "???" "TCL"]             ;# 1 (? matches single char)

# Case-insensitive matching
puts [string match -nocase "hello" "HELLO"] ;# 1
```

### String Manipulation

```tcl
# Replace
set str "Hello, World!"
puts [string replace $str 7 11 "TCL"]  ;# Hello, TCL!!

# Repeat
puts [string repeat "ab" 3]            ;# ababab
puts [string repeat "=-" 20]           ;# =-=-=-=-=-=-...

# Reverse
puts [string reverse "Hello"]          ;# olleH

# Trim
puts [string trim "  Hello  "]         ;# "Hello"
puts [string trimleft "  Hello  "]     ;# "Hello  "
puts [string trimright "  Hello  "]    ;# "  Hello"
puts [string trim "xxHelloxx" "x"]     ;# "Hello"

# Map (character translation)
puts [string map {H h W w} "Hello, World!"]  ;# hello, world!
puts [string map {& &amp; < &lt; > &gt;} "<p>Hello & World</p>"]
# Output: &lt;p&gt;Hello &amp; World&lt;/p&gt;
```

### String Classification

```tcl
puts [string is integer "42"]       ;# 1
puts [string is integer "3.14"]     ;# 0
puts [string is double "3.14"]      ;# 1
puts [string is alpha "Hello"]      ;# 1
puts [string is alnum "Hello123"]   ;# 1
puts [string is digit "12345"]      ;# 1
puts [string is space "  \t\n"]     ;# 1
puts [string is upper "HELLO"]      ;# 1
puts [string is lower "hello"]      ;# 1
```

### Format and Scan

```tcl
# format (like sprintf in C)
set name "Alice"
set age 30
puts [format "Name: %-10s Age: %03d" $name $age]
# Output: Name: Alice      Age: 030

puts [format "Pi = %.4f" 3.14159]   ;# Pi = 3.1416
puts [format "Hex: 0x%04X" 255]     ;# Hex: 0x00FF

# scan (like sscanf in C)
set input "Alice 30 3.14"
scan $input "%s %d %f" name age score
puts "Name=$name, Age=$age, Score=$score"
```

### append and String Building

```tcl
set result ""
append result "Hello"
append result ", "
append result "World!"
puts $result  ;# Hello, World!

# append is more efficient than: set result "$result more text"
```

---

## 7. Lists

Lists are one of TCL's most important data structures. A list is an ordered collection of elements.

### Creating Lists

```tcl
# Literal list (space-separated inside braces)
set fruits {apple banana cherry}

# Using list command (handles special characters properly)
set items [list "hello world" {curly braces} normal]

# From split
set csv_data "alice,bob,carol"
set names [split $csv_data ","]
puts $names  ;# alice bob carol
```

### Accessing List Elements

```tcl
set colors {red green blue yellow purple}

puts [lindex $colors 0]     ;# red
puts [lindex $colors 2]     ;# blue
puts [lindex $colors end]   ;# purple
puts [lindex $colors end-1] ;# yellow

# Length
puts [llength $colors]      ;# 5
```

### Modifying Lists

```tcl
set fruits {apple banana cherry}

# lappend: add elements to the end (modifies in place)
lappend fruits "date" "elderberry"
puts $fruits  ;# apple banana cherry date elderberry

# linsert: insert at a position (returns new list)
set fruits [linsert $fruits 2 "blueberry"]
puts $fruits  ;# apple banana blueberry cherry date elderberry

# lreplace: replace elements (returns new list)
set fruits [lreplace $fruits 1 1 "BANANA"]
puts $fruits  ;# apple BANANA blueberry cherry date elderberry

# lreplace to delete (empty replacement)
set fruits [lreplace $fruits 2 2]
puts $fruits  ;# apple BANANA cherry date elderberry

# lset: set element at index (modifies in place)
lset fruits 0 "apricot"
puts $fruits  ;# apricot BANANA cherry date elderberry
```

### List Searching

```tcl
set animals {cat dog bird fish cat dog}

# lsearch: find the first matching index
puts [lsearch $animals "bird"]       ;# 2
puts [lsearch $animals "snake"]      ;# -1 (not found)

# Find all matches
puts [lsearch -all $animals "cat"]   ;# 0 4

# Glob pattern matching
puts [lsearch -glob $animals "d*"]   ;# 1

# Return value instead of index
puts [lsearch -inline $animals "f*"] ;# fish
```

### List Sorting

```tcl
set numbers {3 1 4 1 5 9 2 6}
puts [lsort $numbers]                    ;# 1 1 2 3 4 5 6 9

# Numeric sort
puts [lsort -integer $numbers]           ;# 1 1 2 3 4 5 6 9

# Descending order
puts [lsort -integer -decreasing $numbers] ;# 9 6 5 4 3 2 1 1

# Remove duplicates
puts [lsort -unique $numbers]            ;# 1 2 3 4 5 6 9

# Sort strings case-insensitively
set words {banana Apple cherry Date}
puts [lsort -nocase $words]              ;# Apple banana cherry Date
```

### List Iteration and Transformation

```tcl
set numbers {1 2 3 4 5}

# foreach
foreach num $numbers {
    puts "Number: $num"
}

# lmap: transform each element (Tcl 8.6+)
set doubled [lmap n $numbers {expr {$n * 2}}]
puts $doubled  ;# 2 4 6 8 10

# Filter with lmap (return empty to exclude)
set evens [lmap n $numbers {
    if {$n % 2 == 0} {set n} else {continue}
}]
puts $evens  ;# 2 4
```

### List Joining and Splitting

```tcl
set parts {usr local bin}
set path [join $parts "/"]
puts $path  ;# usr/local/bin

set csv "alice,30,engineer"
set fields [split $csv ","]
puts $fields              ;# alice 30 engineer
puts [lindex $fields 0]   ;# alice

# Split into individual characters
set chars [split "Hello" ""]
puts $chars  ;# H e l l o
```

### Nested Lists

```tcl
set matrix {{1 2 3} {4 5 6} {7 8 9}}

# Access nested element
puts [lindex $matrix 1]          ;# 4 5 6
puts [lindex [lindex $matrix 1] 2]  ;# 6
puts [lindex $matrix 1 2]        ;# 6 (shorthand for nested access)
```

### List Range

```tcl
set colors {red orange yellow green blue indigo violet}
puts [lrange $colors 2 4]    ;# yellow green blue
puts [lrange $colors 3 end]  ;# green blue indigo violet
```

---

## 8. Arrays (Associative)

TCL arrays are **associative arrays** (hash maps). Unlike lists, arrays cannot be passed by value — they are always accessed by name.

### Creating and Accessing Arrays

```tcl
# Set individual elements
set person(name) "Alice"
set person(age) 30
set person(city) "Boston"

# Access elements
puts $person(name)   ;# Alice
puts $person(age)    ;# 30
```

### Array Operations

```tcl
# Initialize from a list of key-value pairs
array set config {
    host     "localhost"
    port     8080
    debug    true
    timeout  30
}

# Get all names (keys)
puts [array names config]           ;# host port debug timeout (order not guaranteed)
puts [array names config "d*"]      ;# debug (glob pattern)

# Check if array exists
puts [array exists config]          ;# 1
puts [array exists nonexistent]     ;# 0

# Size (number of elements)
puts [array size config]            ;# 4

# Get as a flat list
puts [array get config]             ;# host localhost port 8080 debug true timeout 30

# Convert to sorted key-value output
foreach key [lsort [array names config]] {
    puts "$key = $config($key)"
}
```

### Iterating Over Arrays

```tcl
array set scores {
    Alice   95
    Bob     87
    Carol   92
    David   78
}

# Using array names
foreach student [lsort [array names scores]] {
    puts "$student: $scores($student)"
}

# Using foreach with array get
foreach {name score} [array get scores] {
    puts "$name scored $score"
}

# Using array search iterator
set sid [array startsearch scores]
while {[array anymore scores $sid]} {
    set key [array nextelement scores $sid]
    if {$key ne ""} {
        puts "$key => $scores($key)"
    }
}
array donesearch scores $sid
```

### Unsetting Array Elements

```tcl
array set data {a 1 b 2 c 3}
unset data(b)
puts [array names data]  ;# a c

# Unset entire array
unset data
```

---

## 9. Dictionaries

Dictionaries (Tcl 8.5+) are key-value data structures that, unlike arrays, can be **passed by value** and **nested**.

### Creating Dictionaries

```tcl
# Using dict create
set person [dict create name "Alice" age 30 city "Boston"]

# From a flat list
set config {host localhost port 8080 debug true}
```

### Accessing Dictionary Values

```tcl
set person [dict create name "Alice" age 30 city "Boston"]

puts [dict get $person name]    ;# Alice
puts [dict get $person age]     ;# 30

# Check if key exists
puts [dict exists $person name]    ;# 1
puts [dict exists $person email]   ;# 0

# Size
puts [dict size $person]           ;# 3

# Get all keys
puts [dict keys $person]           ;# name age city

# Get all values
puts [dict values $person]         ;# Alice 30 Boston
```

### Modifying Dictionaries

```tcl
set person [dict create name "Alice" age 30]

# Set or update a key
dict set person email "alice@example.com"
dict set person age 31

# Remove a key
dict unset person email

# Increment a numeric value
dict incr person age
puts [dict get $person age]  ;# 32

# Append to a value
dict append person name " Smith"
puts [dict get $person name]  ;# Alice Smith

# lappend to a dict value (treat value as a list)
dict lappend person hobbies "reading" "coding"
puts [dict get $person hobbies]  ;# reading coding
```

### Iterating Over Dictionaries

```tcl
set inventory [dict create apples 50 bananas 30 oranges 45 grapes 20]

dict for {fruit count} $inventory {
    puts "$fruit: $count"
}

# Filter with dict filter
set plenty [dict filter $inventory script {k v} {expr {$v >= 40}}]
puts $plenty  ;# apples 50 oranges 45

# Filter by key pattern
set a_fruits [dict filter $inventory key "a*"]
puts $a_fruits  ;# apples 50
```

### Nested Dictionaries

```tcl
set company [dict create \
    engineering [dict create \
        lead "Alice" \
        members 15 \
        budget 500000 \
    ] \
    marketing [dict create \
        lead "Bob" \
        members 8 \
        budget 200000 \
    ] \
]

# Access nested values
puts [dict get $company engineering lead]      ;# Alice
puts [dict get $company marketing budget]      ;# 200000

# Modify nested values
dict set company engineering members 18
puts [dict get $company engineering members]   ;# 18
```

### dict map and dict merge

```tcl
# dict map: transform values (Tcl 8.6+)
set prices [dict create apple 1.50 banana 0.75 cherry 3.00]
set doubled [dict map {fruit price} $prices {
    expr {$price * 2}
}]
puts $doubled  ;# apple 3.0 banana 1.5 cherry 6.0

# dict merge: merge multiple dicts (last value wins)
set defaults [dict create color "blue" size "medium" shape "circle"]
set overrides [dict create color "red" size "large"]
set final [dict merge $defaults $overrides]
puts $final  ;# color red size large shape circle
```

---

## 10. Procedures

### Defining Procedures

```tcl
proc greet {name} {
    puts "Hello, $name!"
}

greet "Alice"  ;# Hello, Alice!
```

### Return Values

```tcl
proc add {a b} {
    return [expr {$a + $b}]
}

set sum [add 3 7]
puts "Sum: $sum"  ;# Sum: 10

proc max_of_three {a b c} {
    if {$a >= $b && $a >= $c} {
        return $a
    } elseif {$b >= $c} {
        return $b
    } else {
        return $c
    }
}

puts [max_of_three 7 3 9]  ;# 9
```

### Default Arguments

```tcl
proc connect {host {port 80} {protocol "http"}} {
    puts "Connecting to $protocol://$host:$port"
}

connect "example.com"              ;# http://example.com:80
connect "example.com" 443          ;# http://example.com:443
connect "example.com" 443 "https"  ;# https://example.com:443
```

### Variable-Length Arguments

```tcl
proc sum {args} {
    set total 0
    foreach n $args {
        set total [expr {$total + $n}]
    }
    return $total
}

puts [sum 1 2 3 4 5]  ;# 15

# Mixed fixed and variable arguments
proc log {level args} {
    set msg [join $args " "]
    puts "\[$level\] $msg"
}

log "INFO" "Server" "started" "on" "port" "8080"
# Output: [INFO] Server started on port 8080
```

### Variable Scope and upvar

```tcl
# Variables inside a proc are local by default
proc demo {} {
    set local_var "I'm local"
    puts $local_var
}
demo
# puts $local_var  ;# Error: no such variable

# global: access global variables
set counter 0
proc increment {} {
    global counter
    incr counter
}
increment
increment
puts $counter  ;# 2

# upvar: reference a variable from the caller's scope
proc double_var {varName} {
    upvar 1 $varName var
    set var [expr {$var * 2}]
}

set myval 21
double_var myval
puts $myval  ;# 42
```

### Recursive Procedures

```tcl
proc factorial {n} {
    if {$n <= 1} {
        return 1
    }
    return [expr {$n * [factorial [expr {$n - 1}]]}]
}

puts [factorial 10]  ;# 3628800

proc fibonacci {n} {
    if {$n <= 1} {
        return $n
    }
    return [expr {[fibonacci [expr {$n-1}]] + [fibonacci [expr {$n-2}]]}]
}

puts [fibonacci 10]  ;# 55
```

### Renaming and Deleting Procedures

```tcl
proc hello {} { puts "Hello!" }

# Rename
rename hello greet_user
greet_user  ;# Hello!

# Delete (rename to empty string)
rename greet_user ""
# greet_user  ;# Error: invalid command
```

---

## 11. File I/O

### Reading Files

```tcl
# Read entire file
set fp [open "data.txt" r]
set content [read $fp]
close $fp
puts $content

# Read line by line
set fp [open "data.txt" r]
while {[gets $fp line] >= 0} {
    puts "Line: $line"
}
close $fp

# Read into a list of lines
set fp [open "data.txt" r]
set lines [split [read $fp] "\n"]
close $fp
foreach line $lines {
    puts $line
}
```

### Writing Files

```tcl
# Write (overwrite)
set fp [open "output.txt" w]
puts $fp "First line"
puts $fp "Second line"
close $fp

# Append
set fp [open "output.txt" a]
puts $fp "Third line"
close $fp

# Write without trailing newline
set fp [open "output.txt" w]
puts -nonewline $fp "No newline at end"
close $fp
```

### File Operations

```tcl
# Check file existence
if {[file exists "data.txt"]} {
    puts "File exists"
}

# File information
puts [file size "data.txt"]           ;# Size in bytes
puts [file type "data.txt"]           ;# file, directory, link, etc.
puts [file extension "script.tcl"]    ;# .tcl
puts [file tail "/usr/local/bin/tcl"] ;# tcl
puts [file dirname "/usr/local/bin"]  ;# /usr/local
puts [file rootname "script.tcl"]     ;# script
puts [file join "/usr" "local" "bin"] ;# /usr/local/bin

# File permissions
puts [file readable "data.txt"]
puts [file writable "data.txt"]
puts [file executable "script.tcl"]

# Copy, rename, delete
file copy "source.txt" "dest.txt"
file rename "old.txt" "new.txt"
file delete "temp.txt"
file delete -force "temp_dir"

# Create directories
file mkdir "new_directory"
file mkdir -p "path/to/nested/dir"
```

### Binary File I/O

```tcl
# Read binary data
set fp [open "image.bin" rb]
set data [read $fp]
close $fp

# Write binary data
set fp [open "output.bin" wb]
puts -nonewline $fp $data
close $fp
```

### File Globbing

```tcl
# Find files matching a pattern
set tcl_files [glob *.tcl]
set all_files [glob -directory /tmp *]

# With error handling for no matches
set files [glob -nocomplain *.xyz]
if {[llength $files] == 0} {
    puts "No .xyz files found"
}

# Recursive search (Tcl 8.6+)
set files [glob -directory /path -type f -- **/*.tcl]
```

---

## 12. Regular Expressions

### regexp: Match and Extract

```tcl
# Basic match (returns 1 if match, 0 otherwise)
set str "Hello, World! 42 is the answer."

puts [regexp {World} $str]         ;# 1
puts [regexp {Python} $str]        ;# 0

# Capture groups
regexp {(\d+) is the (\w+)} $str full num word
puts "Full match: $full"   ;# 42 is the answer
puts "Number: $num"        ;# 42
puts "Word: $word"         ;# answer

# Case-insensitive match
regexp -nocase {hello} $str  ;# 1

# Find all matches
set text "cat bat hat mat sat"
set matches [regexp -all -inline {[a-z]at} $text]
puts $matches  ;# cat bat hat mat sat
```

### Common Patterns

```tcl
# Email validation
proc is_valid_email {email} {
    return [regexp {^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$} $email]
}
puts [is_valid_email "user@example.com"]  ;# 1
puts [is_valid_email "invalid-email"]     ;# 0

# IP address validation
proc is_valid_ip {ip} {
    if {![regexp {^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$} $ip _ a b c d]} {
        return 0
    }
    foreach octet [list $a $b $c $d] {
        if {$octet > 255} { return 0 }
    }
    return 1
}
puts [is_valid_ip "192.168.1.1"]   ;# 1
puts [is_valid_ip "999.999.999.999"]  ;# 0

# Extract data
set log "2024-01-15 14:30:45 ERROR: Connection timeout"
regexp {(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) (\w+): (.+)} $log \
    _ date time level message
puts "Date: $date, Time: $time, Level: $level, Msg: $message"
```

### regsub: Search and Replace

```tcl
# Replace first occurrence
set str "Hello, World!"
set result [regsub {World} $str "TCL"]
puts $result  ;# Hello, TCL!

# Replace all occurrences
set str "aaa bbb aaa ccc aaa"
set result [regsub -all {aaa} $str "xxx"]
puts $result  ;# xxx bbb xxx ccc xxx

# Backreferences
set str "John Smith"
set result [regsub {(\w+) (\w+)} $str {\2, \1}]
puts $result  ;# Smith, John

# Remove HTML tags
set html "<p>Hello <b>World</b></p>"
set plain [regsub -all {<[^>]+>} $html ""]
puts $plain  ;# Hello World
```

---

## 13. Error Handling

### try / on / trap (Tcl 8.6+)

```tcl
# Modern error handling
try {
    set result [expr {10 / 0}]
} on error {msg opts} {
    puts "Error: $msg"
} finally {
    puts "Cleanup complete"
}

# trap specific error codes
try {
    set fp [open "nonexistent.txt" r]
} trap {POSIX ENOENT} {msg} {
    puts "File not found: $msg"
} on error {msg} {
    puts "Other error: $msg"
}
```

### catch (Traditional)

```tcl
# catch returns 0 on success, 1 on error
if {[catch {expr {10 / 0}} result]} {
    puts "Error caught: $result"
} else {
    puts "Result: $result"
}

# catch with options dictionary
if {[catch {open "missing.txt" r} result options]} {
    puts "Error: $result"
    puts "Error code: [dict get $options -errorcode]"
    puts "Error info: [dict get $options -errorinfo]"
}
```

### Generating Errors

```tcl
proc divide {a b} {
    if {$b == 0} {
        error "Division by zero" "divide: $a / $b" {ARITH DIVZERO}
    }
    return [expr {double($a) / $b}]
}

try {
    puts [divide 10 0]
} trap {ARITH DIVZERO} {msg} {
    puts "Caught: $msg"
}
```

### Custom Error Handling Patterns

```tcl
proc safe_read_file {filename} {
    if {![file exists $filename]} {
        return -code error -errorcode {FILE NOTFOUND} \
            "File '$filename' does not exist"
    }
    if {![file readable $filename]} {
        return -code error -errorcode {FILE NOPERM} \
            "File '$filename' is not readable"
    }
    set fp [open $filename r]
    set content [read $fp]
    close $fp
    return $content
}

try {
    set data [safe_read_file "/etc/shadow"]
} trap {FILE NOTFOUND} {msg} {
    puts "Not found: $msg"
} trap {FILE NOPERM} {msg} {
    puts "Permission denied: $msg"
} on error {msg} {
    puts "Unexpected error: $msg"
}
```

---

## 14. Namespaces

Namespaces prevent name collisions and organize code into logical groups.

### Creating Namespaces

```tcl
namespace eval math {
    variable pi 3.14159265358979

    proc circle_area {radius} {
        variable pi
        return [expr {$pi * $radius * $radius}]
    }

    proc circle_circumference {radius} {
        variable pi
        return [expr {2 * $pi * $radius}]
    }
}

puts [math::circle_area 5]           ;# 78.5398...
puts [math::circle_circumference 5]  ;# 31.4159...
puts $math::pi                       ;# 3.14159...
```

### Nested Namespaces

```tcl
namespace eval app {
    namespace eval db {
        variable connection ""

        proc connect {host port} {
            variable connection
            set connection "$host:$port"
            puts "Connected to $connection"
        }

        proc disconnect {} {
            variable connection
            set connection ""
            puts "Disconnected"
        }
    }

    namespace eval log {
        proc info {msg} {
            puts "\[INFO\] $msg"
        }

        proc error {msg} {
            puts "\[ERROR\] $msg"
        }
    }
}

app::db::connect "localhost" 5432
app::log::info "Database connected"
app::db::disconnect
```

### Importing and Exporting

```tcl
namespace eval utils {
    namespace export capitalize trim_all

    proc capitalize {str} {
        return [string toupper [string index $str 0]][string range $str 1 end]
    }

    proc trim_all {str} {
        return [regsub -all {\s+} $str " "]
    }

    proc _internal_helper {} {
        # Not exported; private by convention
    }
}

# Import specific procedures
namespace import utils::capitalize
puts [capitalize "hello"]  ;# Hello

# Import all exported
namespace import utils::*
puts [trim_all "  hello    world  "]  ;# hello world
```

### Namespace Introspection

```tcl
namespace eval demo {
    variable x 10
    proc hello {} { puts "hello" }
    proc world {} { puts "world" }
}

puts [namespace children ::]          ;# Lists all top-level namespaces
puts [namespace exists ::demo]        ;# 1
puts [info procs ::demo::*]           ;# ::demo::hello ::demo::world
puts [info vars ::demo::*]            ;# ::demo::x
```

---

## 15. Packages

### Creating a Package

```tcl
# File: mymath.tcl
package provide mymath 1.0

namespace eval ::mymath {
    namespace export add subtract multiply divide

    proc add {a b} { return [expr {$a + $b}] }
    proc subtract {a b} { return [expr {$a - $b}] }
    proc multiply {a b} { return [expr {$a * $b}] }
    proc divide {a b} {
        if {$b == 0} { error "Division by zero" }
        return [expr {double($a) / $b}]
    }
}
```

Create a `pkgIndex.tcl`:

```tcl
# pkgIndex.tcl
package ifneeded mymath 1.0 [list source [file join $dir mymath.tcl]]
```

### Using a Package

```tcl
# Add the package directory to the search path
lappend auto_path "/path/to/package/dir"

# Require and use
package require mymath 1.0

puts [mymath::add 3 4]       ;# 7
puts [mymath::divide 10 3]   ;# 3.3333...
```

### Package Information

```tcl
# List loaded packages
puts [package names]

# Get version of loaded package
puts [package require Tcl]     ;# Shows Tcl version
puts [package versions mymath] ;# 1.0
```

---

## 16. Event-Driven Programming

### after: Delayed Execution

```tcl
# Execute after a delay (milliseconds)
proc delayed_greeting {} {
    puts "Hello after 2 seconds!"
}

after 2000 delayed_greeting

# Cancel a scheduled event
set id [after 5000 {puts "This might be cancelled"}]
after cancel $id

# Periodic execution
proc tick {count} {
    if {$count <= 0} return
    puts "Tick! ($count remaining)"
    after 1000 [list tick [expr {$count - 1}]]
}

tick 5
vwait forever  ;# Enter the event loop
```

### fileevent: File Event Handlers

```tcl
# Non-blocking I/O with event handlers
proc handle_input {chan} {
    if {[gets $chan line] >= 0} {
        puts "Received: $line"
    } elseif {[eof $chan]} {
        puts "Connection closed"
        close $chan
    }
}

# Read stdin with events
fconfigure stdin -blocking 0 -buffering line
fileevent stdin readable [list handle_input stdin]
vwait forever
```

### Simple TCP Server

```tcl
proc accept {chan addr port} {
    puts "Connection from $addr:$port"
    fconfigure $chan -buffering line
    fileevent $chan readable [list handle_client $chan]
}

proc handle_client {chan} {
    if {[gets $chan line] >= 0} {
        puts "Client says: $line"
        puts $chan "Echo: $line"
    } elseif {[eof $chan]} {
        puts "Client disconnected"
        close $chan
    }
}

set server [socket -server accept 9999]
puts "Server listening on port 9999"
vwait forever
```

---

## 17. Practical Examples

### Example 1: Configuration File Parser

```tcl
proc parse_config {filename} {
    set config [dict create]

    if {![file exists $filename]} {
        error "Config file '$filename' not found"
    }

    set fp [open $filename r]
    set section "default"

    while {[gets $fp line] >= 0} {
        set line [string trim $line]

        # Skip empty lines and comments
        if {$line eq "" || [string index $line 0] eq "#"} {
            continue
        }

        # Section header [section_name]
        if {[regexp {^\[(\w+)\]$} $line _ name]} {
            set section $name
            continue
        }

        # Key = Value pairs
        if {[regexp {^(\w+)\s*=\s*(.*)$} $line _ key value]} {
            dict set config $section $key [string trim $value]
        }
    }
    close $fp
    return $config
}

proc get_config_value {config section key {default ""}} {
    if {[dict exists $config $section $key]} {
        return [dict get $config $section $key]
    }
    return $default
}
```

### Example 2: Log File Analyzer

```tcl
proc analyze_log {filename} {
    set stats [dict create total 0 errors 0 warnings 0 info 0]
    set error_messages [list]

    set fp [open $filename r]
    while {[gets $fp line] >= 0} {
        dict incr stats total

        if {[regexp -nocase {ERROR} $line]} {
            dict incr stats errors
            lappend error_messages $line
        } elseif {[regexp -nocase {WARN} $line]} {
            dict incr stats warnings
        } elseif {[regexp -nocase {INFO} $line]} {
            dict incr stats info
        }
    }
    close $fp

    puts "=== Log Analysis Report ==="
    puts "Total lines:  [dict get $stats total]"
    puts "INFO lines:   [dict get $stats info]"
    puts "WARN lines:   [dict get $stats warnings]"
    puts "ERROR lines:  [dict get $stats errors]"

    if {[llength $error_messages] > 0} {
        puts "\n--- Error Details ---"
        foreach err $error_messages {
            puts "  $err"
        }
    }
}
```

### Example 3: Simple Calculator REPL

```tcl
proc calculator {} {
    puts "=== TCL Calculator ==="
    puts "Enter expressions (type 'quit' to exit)"
    puts "Supports: +, -, *, /, **, sqrt(), sin(), cos(), etc.\n"

    set history [list]

    while {1} {
        puts -nonewline "calc> "
        flush stdout

        if {[gets stdin input] < 0} break
        set input [string trim $input]

        if {$input eq "quit" || $input eq "exit"} {
            puts "Goodbye!"
            break
        }

        if {$input eq "history"} {
            foreach {expr result} $history {
                puts "  $expr = $result"
            }
            continue
        }

        if {$input eq ""} continue

        try {
            set result [expr $input]
            puts "  = $result"
            lappend history $input $result
        } on error {msg} {
            puts "  Error: $msg"
        }
    }
}
```

### Example 4: Word Frequency Counter

```tcl
proc count_words {filename} {
    set fp [open $filename r]
    set text [read $fp]
    close $fp

    set text [string tolower $text]
    set text [regsub -all {[^a-z0-9\s]} $text ""]

    array set freq {}
    foreach word [split $text] {
        if {$word eq ""} continue
        if {[info exists freq($word)]} {
            incr freq($word)
        } else {
            set freq($word) 1
        }
    }

    set pairs [list]
    foreach word [array names freq] {
        lappend pairs [list $word $freq($word)]
    }

    set sorted [lsort -index 1 -integer -decreasing $pairs]

    puts "=== Word Frequency Report ==="
    puts [format "%-20s %s" "Word" "Count"]
    puts [string repeat "-" 30]

    set count 0
    foreach pair $sorted {
        lassign $pair word freq
        puts [format "%-20s %d" $word $freq]
        incr count
        if {$count >= 20} {
            puts "... (showing top 20)"
            break
        }
    }
}
```

### Example 5: Directory Tree Printer

```tcl
proc print_tree {dir {prefix ""} {is_last 1}} {
    set name [file tail $dir]
    if {$prefix eq ""} {
        puts $name
    } else {
        set connector [expr {$is_last ? "└── " : "├── "}]
        puts "${prefix}${connector}${name}"
    }

    if {[file isdirectory $dir]} {
        set entries [lsort [glob -nocomplain -directory $dir *]]
        set count [llength $entries]
        set idx 0

        foreach entry $entries {
            incr idx
            set new_prefix $prefix
            if {$prefix ne "" || $idx > 0} {
                append new_prefix [expr {$is_last ? "    " : "│   "}]
            }
            print_tree $entry $new_prefix [expr {$idx == $count}]
        }
    }
}

# Usage: print_tree "/path/to/directory"
```

### Example 6: CSV File Processor

```tcl
proc parse_csv_line {line {delimiter ","}} {
    set fields [list]
    set current ""
    set in_quotes 0

    foreach char [split $line ""] {
        if {$char eq "\"" } {
            set in_quotes [expr {!$in_quotes}]
        } elseif {$char eq $delimiter && !$in_quotes} {
            lappend fields [string trim $current]
            set current ""
        } else {
            append current $char
        }
    }
    lappend fields [string trim $current]
    return $fields
}

proc read_csv {filename {delimiter ","}} {
    set fp [open $filename r]
    set records [list]

    # First line is header
    gets $fp header_line
    set headers [parse_csv_line $header_line $delimiter]

    while {[gets $fp line] >= 0} {
        if {[string trim $line] eq ""} continue
        set values [parse_csv_line $line $delimiter]
        set record [dict create]
        foreach h $headers v $values {
            dict set record $h $v
        }
        lappend records $record
    }
    close $fp
    return [list headers $headers records $records]
}

proc csv_summary {data} {
    set headers [dict get $data headers]
    set records [dict get $data records]

    puts "=== CSV Summary ==="
    puts "Columns: [join $headers {, }]"
    puts "Rows: [llength $records]"
    puts ""

    foreach record $records {
        dict for {key value} $record {
            puts -nonewline [format "%-15s" $value]
        }
        puts ""
    }
}
```

### Example 7: Simple Unit Testing Framework

```tcl
namespace eval ::tcltest_mini {
    variable pass_count 0
    variable fail_count 0
    variable test_results [list]

    proc assert_equal {expected actual {msg ""}} {
        variable pass_count
        variable fail_count
        variable test_results

        if {$expected eq $actual} {
            incr pass_count
            lappend test_results [list PASS $msg]
        } else {
            incr fail_count
            lappend test_results [list FAIL "$msg: expected '$expected', got '$actual'"]
        }
    }

    proc assert_true {condition {msg ""}} {
        assert_equal 1 [expr {bool($condition)}] $msg
    }

    proc assert_false {condition {msg ""}} {
        assert_equal 0 [expr {bool($condition)}] $msg
    }

    proc run_test {name body} {
        puts -nonewline "Running: $name ... "
        try {
            uplevel 1 $body
            puts "OK"
        } on error {msg} {
            variable fail_count
            incr fail_count
            puts "EXCEPTION: $msg"
        }
    }

    proc report {} {
        variable pass_count
        variable fail_count
        variable test_results

        puts "\n[string repeat = 40]"
        puts "Test Results"
        puts [string repeat = 40]

        foreach result $test_results {
            lassign $result status msg
            puts "  \[$status\] $msg"
        }

        puts [string repeat - 40]
        set total [expr {$pass_count + $fail_count}]
        puts "Total: $total | Passed: $pass_count | Failed: $fail_count"

        if {$fail_count > 0} {
            puts "STATUS: SOME TESTS FAILED"
        } else {
            puts "STATUS: ALL TESTS PASSED"
        }
    }
}

# Example usage of the testing framework
namespace import ::tcltest_mini::*

run_test "String operations" {
    assert_equal "HELLO" [string toupper "hello"] "toupper"
    assert_equal 5 [string length "Hello"] "length"
    assert_true {[string match "H*" "Hello"]} "match"
}

run_test "Math operations" {
    assert_equal 4 [expr {2 + 2}] "addition"
    assert_equal 6 [expr {2 * 3}] "multiplication"
    assert_true {[expr {10 > 5}]} "comparison"
}

report
```

### Example 8: JSON-like Data Serialization

```tcl
proc dict_to_json {d {indent 0}} {
    set items [list]
    set pad [string repeat "  " $indent]
    set inner_pad [string repeat "  " [expr {$indent + 1}]]

    dict for {key value} $d {
        if {[string is integer -strict $value] || [string is double -strict $value]} {
            lappend items "${inner_pad}\"$key\": $value"
        } elseif {$value eq "true" || $value eq "false" || $value eq "null"} {
            lappend items "${inner_pad}\"$key\": $value"
        } elseif {[string index $value 0] eq "\{" && [llength $value] > 1 && [llength $value] % 2 == 0} {
            set nested [dict_to_json $value [expr {$indent + 1}]]
            lappend items "${inner_pad}\"$key\": $nested"
        } else {
            set escaped [string map {\" \\\" \\ \\\\ \n \\n \t \\t} $value]
            lappend items "${inner_pad}\"$key\": \"$escaped\""
        }
    }

    set body [join $items ",\n"]
    return "${pad}\{\n${body}\n${pad}\}"
}

# Example
set person [dict create \
    name "Alice Johnson" \
    age 30 \
    active true \
    address [dict create \
        street "123 Main St" \
        city "Boston" \
        state "MA" \
    ] \
]

puts [dict_to_json $person]
```

---

## 18. Quick Reference

### Essential Commands at a Glance

| Category | Command | Description |
|----------|---------|-------------|
| **Output** | `puts ?-nonewline? ?chan? string` | Print a string |
| **Variables** | `set varName ?value?` | Set or read a variable |
| | `unset varName` | Delete a variable |
| | `incr varName ?amount?` | Increment an integer |
| | `append varName string` | Append to a string variable |
| **Expressions** | `expr expression` | Evaluate a math/logic expression |
| **Strings** | `string length str` | Length of a string |
| | `string index str idx` | Character at index |
| | `string range str first last` | Substring |
| | `string match pattern str` | Glob-style match |
| | `string map mapping str` | Character substitution |
| | `string trim str ?chars?` | Trim whitespace/chars |
| | `format fmtStr ?args?` | Formatted string (sprintf) |
| | `scan str fmt ?vars?` | Parse formatted string (sscanf) |
| **Lists** | `list ?args?` | Create a list |
| | `llength list` | Number of elements |
| | `lindex list idx` | Element at index |
| | `lrange list first last` | Sub-list |
| | `lappend varName ?vals?` | Append to list |
| | `linsert list idx ?vals?` | Insert elements |
| | `lreplace list first last ?vals?` | Replace elements |
| | `lsort ?opts? list` | Sort a list |
| | `lsearch ?opts? list pattern` | Search in a list |
| | `lmap varName list body` | Transform a list |
| | `join list ?sep?` | Join into string |
| | `split str ?chars?` | Split into list |
| **Dicts** | `dict create ?key val ...?` | Create a dict |
| | `dict get dict ?key ...?` | Get a value |
| | `dict set dictVar key ?...? val` | Set a value |
| | `dict exists dict key ?...?` | Check for key |
| | `dict for {k v} dict body` | Iterate |
| | `dict keys dict ?pattern?` | Get keys |
| | `dict values dict ?pattern?` | Get values |
| | `dict merge ?dicts?` | Merge dicts |
| **Arrays** | `array set arrName list` | Initialize array |
| | `array get arrName ?pattern?` | Get as list |
| | `array names arrName ?pattern?` | Get keys |
| | `array size arrName` | Count elements |
| **Control** | `if {cond} body ?elseif ...? ?else?` | Conditional |
| | `switch ?opts? val {patterns}` | Multi-way branch |
| | `while {cond} body` | While loop |
| | `for {init} {cond} {step} body` | For loop |
| | `foreach var list body` | For-each loop |
| | `break` | Exit loop |
| | `continue` | Skip iteration |
| **Procedures** | `proc name args body` | Define procedure |
| | `return ?-code? ?val?` | Return from proc |
| | `global varName` | Access global var |
| | `upvar ?level? var localVar` | Reference caller var |
| **File I/O** | `open name ?mode?` | Open file |
| | `close chan` | Close file |
| | `read chan ?size?` | Read data |
| | `gets chan ?varName?` | Read a line |
| | `puts ?-nonewline? ?chan? str` | Write data |
| | `file exists name` | Check existence |
| | `file join ?parts?` | Build path |
| | `glob ?opts? pattern` | Find files |
| **Regex** | `regexp ?opts? exp str ?vars?` | Match pattern |
| | `regsub ?opts? exp str sub ?var?` | Replace pattern |
| **Errors** | `catch script ?resultVar? ?optVar?` | Catch errors |
| | `try body ?handlers? ?finally?` | Modern error handling |
| | `error msg ?info? ?code?` | Raise an error |
| **Namespaces** | `namespace eval ns body` | Define namespace |
| | `namespace import ?pattern?` | Import procs |
| | `namespace export ?pattern?` | Export procs |
| **Misc** | `info exists varName` | Variable existence |
| | `info procs ?pattern?` | List procedures |
| | `info body procName` | Procedure body |
| | `clock seconds` | Current epoch time |
| | `clock format secs ?opts?` | Format time |
| | `after ms ?script?` | Delayed execution |

### Common Escape Sequences

| Sequence | Meaning |
|----------|---------|
| `\n` | Newline |
| `\t` | Tab |
| `\\` | Literal backslash |
| `\"` | Literal double quote |
| `\a` | Bell (alert) |
| `\b` | Backspace |
| `\xHH` | Hex character |
| `\uHHHH` | Unicode character |

---

## Further Resources

- [Official Tcl Documentation](https://www.tcl.tk/doc/)
- [Tcl Wiki](https://wiki.tcl-lang.org/)
- [Tcl Tutorial (tcl.tk)](https://www.tcl.tk/man/tcl/tutorial/tcltutorial.html)
- [Tcler's Wiki - Cookbook](https://wiki.tcl-lang.org/page/Category+Cookbook)

---

*This tutorial covers Tcl 8.6+. Some features like `lmap`, `dict`, `try/on/trap` may not be available in older versions.*
