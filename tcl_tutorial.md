# Comprehensive TCL Programming Tutorial

## Table of Contents

1.  [Introduction to TCL](#1-introduction-to-tcl)
2.  [Installation and Setup](#2-installation-and-setup)
3.  [Basic Syntax and Structure](#3-basic-syntax-and-structure)
4.  [Variables and Data Types](#4-variables-and-data-types)
5.  [Operators](#5-operators)
6.  [String Operations](#6-string-operations)
7.  [Lists](#7-lists)
8.  [Arrays (Associative Arrays)](#8-arrays-associative-arrays)
9.  [Dictionaries](#9-dictionaries)
10. [Control Flow](#10-control-flow)
11. [Procedures (Functions)](#11-procedures-functions)
12. [File I/O](#12-file-io)
13. [Regular Expressions](#13-regular-expressions)
14. [Namespaces](#14-namespaces)
15. [Error Handling](#15-error-handling)
16. [Packages and Modules](#16-packages-and-modules)
17. [Object-Oriented Programming (TclOO)](#17-object-oriented-programming-tcloo)
18. [Event-Driven Programming](#18-event-driven-programming)
19. [Interprocess Communication](#19-interprocess-communication)
20. [Advanced Techniques](#20-advanced-techniques)
21. [Practical Examples](#21-practical-examples)
22. [Best Practices and Style Guide](#22-best-practices-and-style-guide)
23. [Quick Reference](#23-quick-reference)

---

## 1. Introduction to TCL

### What is TCL?

**TCL** (Tool Command Language, pronounced "tickle") is a dynamic, interpreted scripting language created by John Ousterhout in 1988. It was designed to be a simple yet powerful language that can be easily embedded into applications.

### Key Characteristics

- **Everything is a string**: All values in TCL are strings. Even numbers are strings that happen to look like numbers.
- **Command-based syntax**: Every statement is a command followed by arguments.
- **Highly extensible**: TCL can be embedded in C/C++ applications and extended with new commands.
- **Cross-platform**: Runs on Linux, macOS, Windows, and many embedded systems.
- **Widely used in EDA**: TCL is the de-facto scripting language for Electronic Design Automation tools (Synopsys, Cadence, Mentor/Siemens, Intel/Altera Quartus, Xilinx/AMD Vivado).

### Why Learn TCL?

| Use Case | Description |
|---|---|
| **EDA/FPGA Tool Scripting** | Automate synthesis, place-and-route, timing analysis, and constraint flows |
| **Test Automation** | Build test harnesses and regression frameworks |
| **Rapid Prototyping** | Quick scripts for data processing and automation |
| **Embedded Scripting** | Extend C/C++ applications with a scriptable interface |
| **System Administration** | Automate system tasks and network management |
| **GUI Development** | Build cross-platform GUIs with Tk |

---

## 2. Installation and Setup

### Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install tcl tcl-dev
```

### Linux (RHEL/CentOS/Fedora)

```bash
sudo yum install tcl tcl-devel
# or on Fedora:
sudo dnf install tcl tcl-devel
```

### macOS

```bash
# TCL is pre-installed on macOS. For a newer version:
brew install tcl-tk
```

### Windows

Download ActiveTcl from [ActiveState](https://www.activestate.com/products/tcl/) or install via the Magicsplat Tcl/Tk distribution.

### Verify Installation

```bash
tclsh
# You should see a % prompt
% info patchlevel
8.6.13
% exit
```

### Running TCL Scripts

```bash
# Interactive mode
tclsh

# Run a script file
tclsh myscript.tcl

# Make a script executable (Linux/macOS)
#!/usr/bin/env tclsh
```

---

## 3. Basic Syntax and Structure

### The Fundamental Rule

TCL has one fundamental syntax rule: **every statement is a command followed by its arguments, separated by whitespace**.

```
commandName arg1 arg2 arg3 ...
```

### Hello World

```tcl
puts "Hello, World!"
```

Output:
```
Hello, World!
```

### Comments

```tcl
# This is a single-line comment

puts "Hello" ;# Inline comment (note the semicolon before #)

# TCL does not have native multi-line comments, but you can use:
if 0 {
    This block is never executed.
    It acts as a multi-line comment.
    Use it for documentation or disabling code.
}
```

### Command Separators

```tcl
# Newline separates commands
puts "First"
puts "Second"

# Semicolons also separate commands
puts "First" ; puts "Second"

# Backslash continues a command to the next line
set long_result [expr {1 + 2 + 3 + \
                       4 + 5 + 6}]
puts $long_result   ;# Output: 21
```

### Substitution Rules

TCL performs three types of substitution before executing a command:

```tcl
# 1. Variable substitution with $
set name "Alice"
puts "Hello, $name"           ;# Output: Hello, Alice

# 2. Command substitution with []
puts "Sum is [expr {2 + 3}]"  ;# Output: Sum is 5

# 3. Backslash substitution
puts "Line1\nLine2"           ;# Output on two lines
puts "Tab\there"              ;# Output with tab
puts "A quote: \""            ;# Escaped double quote
```

### Quoting

```tcl
# Double quotes: allow substitution
set x 10
puts "Value is $x"         ;# Output: Value is 10

# Curly braces: no substitution (literal)
puts {Value is $x}         ;# Output: Value is $x

# This distinction is critical in TCL!
```

### Grouping Rules Summary

| Syntax | Substitution | Use Case |
|---|---|---|
| `"..."` | Yes (variables, commands, backslash) | When you need interpolation |
| `{...}` | No (literal string) | Code blocks, patterns, deferred evaluation |
| `[...]` | Command substitution | Embed command results in arguments |

---

## 4. Variables and Data Types

### Setting and Reading Variables

```tcl
# Set a variable
set name "TCL Programming"
set count 42
set pi 3.14159

# Read a variable ($ prefix)
puts $name        ;# Output: TCL Programming
puts $count       ;# Output: 42

# Using 'set' with one argument reads the variable
puts [set name]   ;# Output: TCL Programming
```

### Variable Names

```tcl
# Simple names
set myVar 100
set my_var 200
set MyVar123 300

# Variable names with special characters (use braces)
set {my variable} "has spaces"
puts ${my variable}

# Namespace-qualified names
set ::global_var "I'm global"
```

### Checking Variable Existence

```tcl
set x 10

if {[info exists x]} {
    puts "x exists and equals $x"
}

if {![info exists y]} {
    puts "y does not exist"
}
```

### Unsetting Variables

```tcl
set temp "temporary"
puts $temp        ;# Output: temporary
unset temp
# puts $temp      ;# ERROR: can't read "temp": no such variable

# Unset with -nocomplain (no error if variable doesn't exist)
unset -nocomplain nonexistent
```

### Numeric Types

```tcl
# Integers
set int_val 42
set hex_val 0xFF        ;# 255
set oct_val 0o77        ;# 63
set bin_val 0b10101     ;# 21

# Floating-point
set float_val 3.14
set sci_val 2.5e10

# Boolean (TCL uses integers: 0=false, nonzero=true)
# Also accepts: true/false, yes/no, on/off
set flag true

# Type checking
puts [string is integer "42"]    ;# 1 (true)
puts [string is double "3.14"]   ;# 1 (true)
puts [string is alpha "hello"]   ;# 1 (true)
puts [string is boolean "yes"]   ;# 1 (true)
```

### The `expr` Command

All arithmetic in TCL must go through `expr`. Always brace the expression for safety and performance.

```tcl
# Basic arithmetic
set result [expr {10 + 5}]      ;# 15
set result [expr {10 - 5}]      ;# 5
set result [expr {10 * 5}]      ;# 50
set result [expr {10 / 3}]      ;# 3 (integer division)
set result [expr {10.0 / 3}]    ;# 3.3333333333333335
set result [expr {10 % 3}]      ;# 1 (modulo)
set result [expr {2 ** 10}]     ;# 1024 (power)

# Using variables in expressions
set a 10
set b 20
set sum [expr {$a + $b}]
puts "Sum: $sum"    ;# Output: Sum: 30

# Math functions
puts [expr {sqrt(144)}]          ;# 12.0
puts [expr {abs(-42)}]           ;# 42
puts [expr {round(3.7)}]         ;# 4
puts [expr {ceil(3.2)}]          ;# 4.0
puts [expr {floor(3.8)}]         ;# 3.0
puts [expr {sin(3.14159/2)}]     ;# ~1.0
puts [expr {log(100)}]           ;# 4.605 (natural log)
puts [expr {log10(100)}]         ;# 2.0
puts [expr {int(3.14)}]          ;# 3
puts [expr {double(42)}]         ;# 42.0
puts [expr {rand()}]             ;# Random float in [0, 1)
puts [expr {int(rand() * 100)}]  ;# Random integer 0-99

# IMPORTANT: Always brace expressions
set x 5
# Bad  (security risk, slower): expr $x + 1
# Good (safe, faster):          expr {$x + 1}
```

---

## 5. Operators

### Arithmetic Operators

```tcl
puts [expr {10 + 3}]    ;# 13   Addition
puts [expr {10 - 3}]    ;# 7    Subtraction
puts [expr {10 * 3}]    ;# 30   Multiplication
puts [expr {10 / 3}]    ;# 3    Integer division
puts [expr {10.0 / 3}]  ;# 3.33 Float division
puts [expr {10 % 3}]    ;# 1    Modulo
puts [expr {2 ** 8}]    ;# 256  Exponentiation
```

### Comparison Operators

```tcl
puts [expr {10 == 10}]   ;# 1 (true)
puts [expr {10 != 5}]    ;# 1 (true)
puts [expr {10 > 5}]     ;# 1 (true)
puts [expr {10 < 5}]     ;# 0 (false)
puts [expr {10 >= 10}]   ;# 1 (true)
puts [expr {10 <= 5}]    ;# 0 (false)

# String comparison in expr
puts [expr {"abc" eq "abc"}]  ;# 1 (true)
puts [expr {"abc" ne "xyz"}]  ;# 1 (true)
```

### Logical Operators

```tcl
puts [expr {1 && 1}]    ;# 1  Logical AND
puts [expr {1 || 0}]    ;# 1  Logical OR
puts [expr {!0}]        ;# 1  Logical NOT

# Short-circuit evaluation
set x 0
puts [expr {$x != 0 && 10 / $x > 2}]  ;# 0 (division never happens)
```

### Bitwise Operators

```tcl
puts [expr {0xFF & 0x0F}]   ;# 15   Bitwise AND
puts [expr {0xF0 | 0x0F}]   ;# 255  Bitwise OR
puts [expr {0xFF ^ 0x0F}]   ;# 240  Bitwise XOR
puts [expr {~0}]             ;# -1   Bitwise NOT
puts [expr {1 << 4}]         ;# 16   Left shift
puts [expr {256 >> 4}]       ;# 16   Right shift
```

### Ternary Operator

```tcl
set age 20
set status [expr {$age >= 18 ? "adult" : "minor"}]
puts $status   ;# Output: adult
```

---

## 6. String Operations

### String Length

```tcl
set str "Hello, TCL!"
puts [string length $str]   ;# 11
```

### String Indexing and Ranges

```tcl
set str "Hello, World!"

puts [string index $str 0]        ;# H
puts [string index $str end]      ;# !
puts [string index $str end-1]    ;# d

puts [string range $str 0 4]      ;# Hello
puts [string range $str 7 end]    ;# World!
```

### Case Conversion

```tcl
set str "Hello World"
puts [string toupper $str]       ;# HELLO WORLD
puts [string tolower $str]       ;# hello world
puts [string totitle $str]       ;# Hello World
puts [string totitle "hello"]    ;# Hello
```

### String Searching

```tcl
set str "Hello, World! Hello, TCL!"

puts [string first "Hello" $str]      ;# 0  (first occurrence)
puts [string first "Hello" $str 1]    ;# 14 (start searching from index 1)
puts [string last "Hello" $str]       ;# 14 (last occurrence)

puts [string match "*World*" $str]    ;# 1  (glob-style matching)
puts [string match -nocase "*world*" $str]  ;# 1
```

### String Comparison

```tcl
puts [string compare "abc" "abc"]     ;# 0  (equal)
puts [string compare "abc" "abd"]     ;# -1 (less)
puts [string compare "abd" "abc"]     ;# 1  (greater)
puts [string equal "abc" "abc"]       ;# 1  (true)
puts [string equal -nocase "ABC" "abc"]  ;# 1 (true)
```

### String Manipulation

```tcl
# Trimming
puts [string trim "  hello  "]          ;# "hello"
puts [string trimleft "  hello  "]      ;# "hello  "
puts [string trimright "  hello  "]     ;# "  hello"
puts [string trim "***hello***" "*"]    ;# "hello"

# Replacing
puts [string replace "Hello World" 5 5 ","]  ;# "Hello,World"

# Reversing
puts [string reverse "Hello"]  ;# "olleH"

# Repeating
puts [string repeat "ab" 3]   ;# "ababab"
puts [string repeat "=-" 20]  ;# "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"

# Mapping (character translation)
puts [string map {a A e E i I o O u U} "hello world"]  ;# "hEllO wOrld"
puts [string map {foo bar baz qux} "foo is not baz"]    ;# "bar is not qux"
```

### String Formatting

```tcl
# format (like C's sprintf)
puts [format "Name: %-10s Age: %3d" "Alice" 30]
# Output: Name: Alice      Age:  30

puts [format "Pi: %.4f" 3.14159]
# Output: Pi: 3.1416

puts [format "Hex: 0x%04X" 255]
# Output: Hex: 0x00FF

puts [format "%s has %d items worth $%.2f" "Cart" 5 49.99]
# Output: Cart has 5 items worth $49.99

# scan (like C's sscanf) — parse formatted strings
scan "Age: 25" "Age: %d" age
puts $age   ;# 25

scan "192.168.1.100" "%d.%d.%d.%d" a b c d
puts "$a.$b.$c.$d"   ;# 192.168.1.100

scan "FF" "%x" decimal
puts $decimal   ;# 255
```

### String Classification

```tcl
puts [string is integer "42"]       ;# 1
puts [string is double "3.14"]      ;# 1
puts [string is alpha "hello"]      ;# 1
puts [string is alnum "abc123"]     ;# 1
puts [string is digit "12345"]      ;# 1
puts [string is space "   "]        ;# 1
puts [string is upper "ABC"]        ;# 1
puts [string is lower "abc"]        ;# 1
puts [string is boolean "yes"]      ;# 1
```

### Subcommand: `append` and `concat`

```tcl
set str "Hello"
append str ", " "World" "!"
puts $str   ;# Hello, World!

set result [concat "Hello" "World"]
puts $result   ;# Hello World
```

---

## 7. Lists

Lists are one of TCL's most important data structures. A TCL list is an ordered sequence of elements separated by whitespace.

### Creating Lists

```tcl
# Simple list (whitespace-separated)
set colors "red green blue"

# Using the list command (preferred — handles special characters)
set fruits [list apple "passion fruit" banana orange]

# Using split
set csv_data [split "one,two,three" ","]
puts $csv_data   ;# one two three
```

### Accessing List Elements

```tcl
set mylist [list a b c d e f]

puts [lindex $mylist 0]       ;# a
puts [lindex $mylist end]     ;# f
puts [lindex $mylist end-1]   ;# e
puts [lindex $mylist 2]       ;# c

# Get list length
puts [llength $mylist]        ;# 6

# Get a range of elements
puts [lrange $mylist 1 3]     ;# b c d
puts [lrange $mylist 2 end]   ;# c d e f
```

### Modifying Lists

```tcl
set mylist [list a b c d e]

# Append elements
lappend mylist f g
puts $mylist   ;# a b c d e f g

# Insert elements
set mylist [linsert $mylist 2 X Y]
puts $mylist   ;# a b X Y c d e f g

# Replace elements
set mylist [lreplace $mylist 2 3 M N]
puts $mylist   ;# a b M N c d e f g

# Set element at index (modifies in place)
lset mylist 0 Z
puts $mylist   ;# Z b M N c d e f g

# Remove an element (replace with nothing)
set mylist [lreplace $mylist 2 2]
puts $mylist   ;# Z b N c d e f g
```

### Searching Lists

```tcl
set mylist [list apple banana cherry date elderberry fig]

# Find index of element
puts [lsearch $mylist "cherry"]       ;# 2
puts [lsearch $mylist "grape"]        ;# -1 (not found)

# Glob pattern matching
puts [lsearch -glob $mylist "ch*"]    ;# 2

# Return all matches
puts [lsearch -all $mylist "*e*"]     ;# 0 2 3 4

# Return matching values (not indices)
puts [lsearch -all -inline $mylist "*a*"]  ;# apple banana date
```

### Sorting Lists

```tcl
set nums [list 3 1 4 1 5 9 2 6]
puts [lsort $nums]                       ;# 1 1 2 3 4 5 6 9
puts [lsort -decreasing $nums]           ;# 9 6 5 4 3 2 1 1
puts [lsort -unique $nums]               ;# 1 2 3 4 5 6 9
puts [lsort -integer $nums]              ;# 1 1 2 3 4 5 6 9

set words [list Banana apple Cherry date]
puts [lsort $words]                       ;# Banana Cherry apple date
puts [lsort -nocase $words]               ;# apple Banana Cherry date

# Custom sort with a command
proc by_length {a b} {
    return [expr {[string length $a] - [string length $b]}]
}
set words [list "hi" "hello" "hey" "greetings"]
puts [lsort -command by_length $words]    ;# hi hey hello greetings
```

### Iterating Over Lists

```tcl
set colors [list red green blue yellow]

# foreach — single variable
foreach color $colors {
    puts "Color: $color"
}

# foreach — multiple variables
set pairs [list name Alice age 30 city Boston]
foreach {key value} $pairs {
    puts "$key = $value"
}

# foreach — multiple lists
set names [list Alice Bob Carol]
set ages  [list 30 25 35]
foreach name $names age $ages {
    puts "$name is $age years old"
}
```

### Joining Lists into Strings

```tcl
set mylist [list one two three four]
puts [join $mylist ", "]    ;# one, two, three, four
puts [join $mylist "-"]     ;# one-two-three-four
puts [join $mylist ""]      ;# onetwothreefour
```

### Nested Lists

```tcl
set matrix [list [list 1 2 3] [list 4 5 6] [list 7 8 9]]

# Access nested element
puts [lindex $matrix 1 2]   ;# 6  (row 1, col 2)
puts [lindex $matrix 0]     ;# 1 2 3 (entire first row)

# Iterate over a matrix
foreach row $matrix {
    foreach elem $row {
        puts -nonewline "$elem "
    }
    puts ""
}
# Output:
# 1 2 3
# 4 5 6
# 7 8 9
```

---

## 8. Arrays (Associative Arrays)

TCL arrays are **associative arrays** (hash maps). They map string keys to string values.

### Creating and Accessing Arrays

```tcl
# Set individual elements
set person(name)  "Alice"
set person(age)   30
set person(city)  "Boston"

# Read elements
puts $person(name)    ;# Alice
puts $person(age)     ;# 30

# Using array set (bulk assignment)
array set config {
    host     "localhost"
    port     8080
    debug    1
    logfile  "/var/log/app.log"
}
puts $config(host)    ;# localhost
puts $config(port)    ;# 8080
```

### Array Information

```tcl
array set data {x 10 y 20 z 30}

puts [array exists data]       ;# 1
puts [array size data]         ;# 3
puts [array names data]        ;# x y z (order may vary)
puts [array names data "x*"]   ;# x (glob pattern)
puts [array get data]          ;# x 10 y 20 z 30 (flat key-value list)
```

### Iterating Over Arrays

```tcl
array set scores {
    Alice   95
    Bob     87
    Carol   92
    Dave    78
}

# Method 1: foreach over names
foreach name [lsort [array names scores]] {
    puts "$name: $scores($name)"
}

# Method 2: array get + foreach with two variables
foreach {name score} [array get scores] {
    puts "$name scored $score"
}

# Method 3: array search iterator
set search [array startsearch scores]
while {[array anymore scores $search]} {
    set key [array nextelement scores $search]
    puts "$key = $scores($key)"
}
array donesearch scores $search
```

### Deleting Array Elements

```tcl
array set fruits {apple 1 banana 2 cherry 3}

unset fruits(banana)
puts [array names fruits]   ;# apple cherry

# Delete entire array
unset fruits
```

### Arrays vs. Lists

| Feature | List | Array |
|---|---|---|
| Access by | Integer index | String key |
| Ordered | Yes | No |
| Passable to procs | Yes (as value) | By name (upvar) |
| Nested | Yes | Simulated |
| Performance | O(n) search | O(1) lookup |

---

## 9. Dictionaries

Dictionaries (introduced in TCL 8.5) are ordered key-value structures that can be passed by value, unlike arrays.

### Creating Dictionaries

```tcl
# Using dict create
set person [dict create name "Alice" age 30 city "Boston"]

# From a flat list
set config [dict create host "localhost" port 8080 debug true]
```

### Accessing Values

```tcl
set person [dict create name "Alice" age 30 city "Boston"]

puts [dict get $person name]    ;# Alice
puts [dict get $person age]     ;# 30

# Check if key exists
puts [dict exists $person name]    ;# 1
puts [dict exists $person email]   ;# 0

# Size
puts [dict size $person]   ;# 3

# All keys
puts [dict keys $person]   ;# name age city

# All values
puts [dict values $person]   ;# Alice 30 Boston
```

### Modifying Dictionaries

```tcl
set person [dict create name "Alice" age 30]

# Set a key
dict set person city "Boston"
dict set person age 31

# Append to a value
dict append person name " Smith"
puts [dict get $person name]   ;# Alice Smith

# Increment a numeric value
dict incr person age
puts [dict get $person age]   ;# 32

# Remove a key
dict unset person city
puts [dict keys $person]   ;# name age

# Lappend to a value
dict lappend person hobbies "reading" "coding"
puts [dict get $person hobbies]   ;# reading coding
```

### Iterating Over Dictionaries

```tcl
set inventory [dict create apple 50 banana 30 cherry 75 date 20]

dict for {fruit count} $inventory {
    puts "$fruit: $count units"
}
# Output:
# apple: 50 units
# banana: 30 units
# cherry: 75 units
# date: 20 units
```

### Nested Dictionaries

```tcl
set employees [dict create]

dict set employees emp001 name "Alice"
dict set employees emp001 dept "Engineering"
dict set employees emp001 salary 95000

dict set employees emp002 name "Bob"
dict set employees emp002 dept "Marketing"
dict set employees emp002 salary 85000

# Access nested values
puts [dict get $employees emp001 name]     ;# Alice
puts [dict get $employees emp002 dept]     ;# Marketing

# Iterate with nested access
dict for {id info} $employees {
    puts "$id: [dict get $info name] in [dict get $info dept]"
}
```

### Dictionary Filtering and Transformation

```tcl
set data [dict create a 1 b 2 c 3 d 4 e 5]

# Filter by key pattern
puts [dict filter $data key {[a-c]}]    ;# a 1 b 2 c 3

# Filter by value
puts [dict filter $data value {[1-3]}]  ;# a 1 b 2 c 3

# Filter with a script
set result [dict filter $data script {k v} {
    expr {$v > 2}
}]
puts $result   ;# c 3 d 4 e 5

# Map (transform values)
set doubled [dict map {k v} $data {
    expr {$v * 2}
}]
puts $doubled   ;# a 2 b 4 c 6 d 8 e 10
```

---

## 10. Control Flow

### if / elseif / else

```tcl
set score 85

if {$score >= 90} {
    puts "Grade: A"
} elseif {$score >= 80} {
    puts "Grade: B"
} elseif {$score >= 70} {
    puts "Grade: C"
} else {
    puts "Grade: F"
}
# Output: Grade: B
```

> **Important**: The opening brace `{` must be on the same line as `if`, `elseif`, or `else`. This is because TCL is command-based — a newline terminates the command.

### switch

```tcl
set fruit "banana"

switch $fruit {
    "apple" {
        puts "It's an apple"
    }
    "banana" {
        puts "It's a banana"
    }
    "cherry" {
        puts "It's a cherry"
    }
    default {
        puts "Unknown fruit"
    }
}
# Output: It's a banana

# switch with -glob matching
set filename "report.csv"
switch -glob $filename {
    "*.txt"  { puts "Text file" }
    "*.csv"  { puts "CSV file" }
    "*.log"  { puts "Log file" }
    default  { puts "Other file" }
}

# switch with -regexp matching
set input "Error: file not found"
switch -regexp $input {
    {^Error:}   { puts "Error detected" }
    {^Warning:} { puts "Warning detected" }
    {^Info:}    { puts "Info message" }
    default     { puts "Unclassified" }
}
```

### while Loop

```tcl
set i 0
while {$i < 5} {
    puts "i = $i"
    incr i
}
# Output: i = 0, i = 1, i = 2, i = 3, i = 4

# Infinite loop with break
set count 0
while {1} {
    if {$count >= 3} break
    puts "count = $count"
    incr count
}
```

### for Loop

```tcl
for {set i 0} {$i < 5} {incr i} {
    puts "i = $i"
}

# Counting down
for {set i 10} {$i > 0} {incr i -1} {
    puts "$i..."
}
puts "Liftoff!"

# Stepping by 2
for {set i 0} {$i < 20} {incr i 2} {
    puts -nonewline "$i "
}
puts ""
# Output: 0 2 4 6 8 10 12 14 16 18
```

### foreach Loop

```tcl
# Basic foreach
foreach item [list apple banana cherry] {
    puts "Fruit: $item"
}

# With index tracking
set items [list alpha beta gamma delta]
set idx 0
foreach item $items {
    puts "  \[$idx\] $item"
    incr idx
}

# Multiple variables
foreach {first last} [list John Doe Jane Smith Bob Brown] {
    puts "$first $last"
}
```

### Loop Control: break and continue

```tcl
# break — exit the loop entirely
for {set i 0} {$i < 10} {incr i} {
    if {$i == 5} break
    puts $i
}
# Output: 0 1 2 3 4

# continue — skip to next iteration
for {set i 0} {$i < 10} {incr i} {
    if {$i % 2 == 0} continue
    puts $i
}
# Output: 1 3 5 7 9
```

---

## 11. Procedures (Functions)

### Defining Procedures

```tcl
proc greet {name} {
    puts "Hello, $name!"
}

greet "Alice"   ;# Output: Hello, Alice!
```

### Return Values

```tcl
proc add {a b} {
    return [expr {$a + $b}]
}

set result [add 10 20]
puts "Sum: $result"   ;# Sum: 30

proc max {a b} {
    if {$a > $b} {
        return $a
    }
    return $b
}
puts [max 15 42]   ;# 42
```

### Default Arguments

```tcl
proc connect {host {port 80} {protocol "http"}} {
    puts "Connecting to $protocol://$host:$port"
}

connect "example.com"                    ;# http://example.com:80
connect "example.com" 443                ;# http://example.com:443
connect "example.com" 443 "https"        ;# https://example.com:443
```

### Variable Arguments (args)

```tcl
proc log {level args} {
    puts "\[$level\] [join $args " "]"
}

log "INFO"  "Server started on port 8080"
log "ERROR" "Connection" "refused" "to" "host"
# Output:
# [INFO] Server started on port 8080
# [ERROR] Connection refused to host

# Processing args as key-value options
proc create_widget {type args} {
    puts "Creating $type widget"
    foreach {option value} $args {
        puts "  $option = $value"
    }
}
create_widget "button" -text "Click Me" -width 100 -height 30
```

### Variable Scope and upvar

```tcl
# Variables in procedures are local by default
set x 10

proc show_x {} {
    # puts $x  ;# ERROR — x is not in this scope
    puts "Cannot see outer x"
}

# Access global variables with 'global'
proc show_global {} {
    global x
    puts "Global x = $x"
}
show_global   ;# Output: Global x = 10

# upvar — reference a variable from the caller's scope
proc double_var {varName} {
    upvar 1 $varName localRef
    set localRef [expr {$localRef * 2}]
}

set myval 21
double_var myval
puts $myval   ;# 42

# upvar is essential for passing arrays to procedures
proc print_array {arrName} {
    upvar 1 $arrName arr
    foreach key [lsort [array names arr]] {
        puts "  $key = $arr($key)"
    }
}

array set data {x 10 y 20 z 30}
print_array data
```

### uplevel — Execute in Caller's Scope

```tcl
proc debug_exec {script} {
    puts "Executing: $script"
    uplevel 1 $script
}

set a 5
debug_exec {set a [expr {$a * 2}]}
puts $a   ;# 10
```

### Recursive Procedures

```tcl
proc factorial {n} {
    if {$n <= 1} {
        return 1
    }
    return [expr {$n * [factorial [expr {$n - 1}]]}]
}

puts [factorial 10]   ;# 3628800

proc fibonacci {n} {
    if {$n <= 1} {
        return $n
    }
    return [expr {[fibonacci [expr {$n - 1}]] + [fibonacci [expr {$n - 2}]]}]
}

puts [fibonacci 10]   ;# 55
```

### Procedures as First-Class Values

```tcl
proc apply_op {op a b} {
    return [$op $a $b]
}

proc add {a b} { return [expr {$a + $b}] }
proc mul {a b} { return [expr {$a * $b}] }

puts [apply_op add 3 4]   ;# 7
puts [apply_op mul 3 4]   ;# 12
```

### Lambda (Anonymous Procedures)

```tcl
# Using 'apply' with anonymous procedures (TCL 8.5+)
set square [list {x} {expr {$x * $x}}]
puts [apply $square 5]   ;# 25

set add [list {a b} {expr {$a + $b}}]
puts [apply $add 3 7]    ;# 10

# Lambda in higher-order functions
set numbers [list 1 2 3 4 5]
set doubled [lmap x $numbers {expr {$x * 2}}]
puts $doubled   ;# 2 4 6 8 10

# Filter using lmap (TCL 8.6+)
set evens [lmap x $numbers {
    if {$x % 2 == 0} {set x} else {continue}
}]
puts $evens   ;# 2 4
```

---

## 12. File I/O

### Reading Files

```tcl
# Read entire file at once
set fp [open "input.txt" r]
set content [read $fp]
close $fp
puts $content

# Read line by line
set fp [open "input.txt" r]
while {[gets $fp line] >= 0} {
    puts "Line: $line"
}
close $fp

# Read into a list of lines
set fp [open "input.txt" r]
set lines [split [read $fp] "\n"]
close $fp
foreach line $lines {
    puts $line
}
```

### Writing Files

```tcl
# Write to a file (overwrite)
set fp [open "output.txt" w]
puts $fp "Hello, World!"
puts $fp "Second line"
close $fp

# Append to a file
set fp [open "output.txt" a]
puts $fp "Appended line"
close $fp

# Write without trailing newline
set fp [open "output.txt" w]
puts -nonewline $fp "No newline at end"
close $fp
```

### File Modes

| Mode | Description |
|---|---|
| `r` | Read only (default). File must exist. |
| `w` | Write only. Creates or truncates. |
| `a` | Append. Creates if doesn't exist. |
| `r+` | Read and write. File must exist. |
| `w+` | Read and write. Creates or truncates. |
| `a+` | Read and append. Creates if doesn't exist. |

### Channel Configuration

```tcl
set fp [open "data.bin" rb]

# Configure encoding
fconfigure $fp -encoding utf-8

# Configure end-of-line translation
fconfigure $fp -translation binary

# Configure buffering
fconfigure $fp -buffering full -buffersize 8192

close $fp
```

### File Operations

```tcl
# Check if file exists
if {[file exists "myfile.txt"]} {
    puts "File exists"
}

# File information
puts [file size "myfile.txt"]         ;# File size in bytes
puts [file mtime "myfile.txt"]        ;# Modification time (epoch)
puts [file type "myfile.txt"]         ;# "file", "directory", "link"
puts [file readable "myfile.txt"]     ;# 1 if readable
puts [file writable "myfile.txt"]     ;# 1 if writable
puts [file extension "report.csv"]    ;# .csv
puts [file tail "/path/to/file.txt"]  ;# file.txt
puts [file dirname "/path/to/file.txt"]   ;# /path/to
puts [file rootname "report.csv"]     ;# report
puts [file normalize "~/docs/../file"]    ;# Full normalized path

# File path manipulation
set path [file join "/home" "user" "docs" "file.txt"]
puts $path   ;# /home/user/docs/file.txt

# Copy, rename, delete
file copy "source.txt" "dest.txt"
file copy -force "source.txt" "dest.txt"
file rename "old.txt" "new.txt"
file delete "temp.txt"
file delete -force "temp_dir"

# Create directories
file mkdir "new_dir/sub_dir"
```

### Globbing (File Pattern Matching)

```tcl
# Find all .tcl files in current directory
set tcl_files [glob *.tcl]
puts $tcl_files

# Find recursively with -nocomplain (no error if no match)
set all_files [glob -nocomplain -directory "/path/to/dir" *.txt]

# Find with types filter
set dirs [glob -type d *]        ;# Directories only
set files [glob -type f *.log]   ;# Regular files only
```

### Safe File Handling with try/finally

```tcl
try {
    set fp [open "data.txt" r]
    set content [read $fp]
    # Process content...
    puts "Read [string length $content] characters"
} on error {msg} {
    puts "Error: $msg"
} finally {
    if {[info exists fp]} {
        close $fp
    }
}
```

---

## 13. Regular Expressions

### Basic Matching

```tcl
set text "The quick brown fox jumps over the lazy dog"

# regexp — returns 1 if match found, 0 otherwise
if {[regexp {quick} $text]} {
    puts "Found 'quick'"
}

# Case-insensitive matching
if {[regexp -nocase {QUICK} $text]} {
    puts "Found (case-insensitive)"
}
```

### Capturing Groups

```tcl
set text "Name: Alice, Age: 30"

regexp {Name: (\w+), Age: (\d+)} $text -> name age
puts "Name: $name"   ;# Alice
puts "Age: $age"     ;# 30

# The -> variable holds the full match
set text "2026-03-20"
regexp {(\d{4})-(\d{2})-(\d{2})} $text full year month day
puts "Full: $full"     ;# 2026-03-20
puts "Year: $year"     ;# 2026
puts "Month: $month"   ;# 03
puts "Day: $day"       ;# 20
```

### Finding All Matches

```tcl
set text "apple 42, banana 17, cherry 88"

# Find all numbers
set matches [regexp -all -inline {\d+} $text]
puts $matches   ;# 42 17 88

# Count matches
set count [regexp -all {\d+} $text]
puts "Found $count numbers"   ;# Found 3 numbers
```

### Substitution with regsub

```tcl
set text "Hello World Hello TCL"

# Replace first occurrence
set result [regsub {Hello} $text "Hi"]
puts $result   ;# Hi World Hello TCL

# Replace all occurrences
set result [regsub -all {Hello} $text "Hi"]
puts $result   ;# Hi World Hi TCL

# Using back-references
set text "John Smith"
set result [regsub {(\w+) (\w+)} $text {\2, \1}]
puts $result   ;# Smith, John

# Complex substitution
set csv_line "field1,field2,field3"
set tsv_line [regsub -all {,} $csv_line "\t"]
puts $tsv_line   ;# field1	field2	field3
```

### Common Regex Patterns

```tcl
# Email validation
proc is_email {str} {
    return [regexp {^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$} $str]
}
puts [is_email "user@example.com"]   ;# 1
puts [is_email "not-an-email"]       ;# 0

# IP address validation
proc is_ipv4 {str} {
    if {![regexp {^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$} $str -> a b c d]} {
        return 0
    }
    foreach octet [list $a $b $c $d] {
        if {$octet > 255} { return 0 }
    }
    return 1
}
puts [is_ipv4 "192.168.1.1"]     ;# 1
puts [is_ipv4 "999.1.1.1"]       ;# 0

# Extract URLs
set html {Visit <a href="https://example.com">here</a> and <a href="https://tcl.tk">TCL</a>}
set urls [regexp -all -inline {href="([^"]+)"} $html]
foreach {full url} $urls {
    puts "URL: $url"
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
puts $math::pi                        ;# 3.14159...
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

        proc query {sql} {
            variable connection
            puts "Executing on $connection: $sql"
        }
    }

    namespace eval ui {
        proc show_message {msg} {
            puts "UI Message: $msg"
        }
    }
}

app::db::connect "localhost" 5432
app::db::query "SELECT * FROM users"
app::ui::show_message "Welcome!"
```

### Importing and Exporting

```tcl
namespace eval utils {
    namespace export log_info log_error

    proc log_info {msg} {
        puts "INFO: $msg"
    }

    proc log_error {msg} {
        puts "ERROR: $msg"
    }

    proc internal_helper {} {
        puts "This is internal"
    }
}

# Import specific commands
namespace import utils::log_info utils::log_error

log_info "Application started"
log_error "Something went wrong"
# internal_helper  ;# ERROR — not exported

# Import all exported commands
namespace import utils::*
```

### Namespace Ensemble

```tcl
namespace eval counter {
    variable count 0

    namespace export reset increment value

    namespace ensemble create

    proc reset {} {
        variable count
        set count 0
    }

    proc increment {{amount 1}} {
        variable count
        incr count $amount
    }

    proc value {} {
        variable count
        return $count
    }
}

counter reset
counter increment
counter increment
counter increment 5
puts [counter value]   ;# 7
```

---

## 15. Error Handling

### try / on / trap / finally (TCL 8.6+)

```tcl
# Basic try-on-finally
try {
    set result [expr {10 / 0}]
} on error {msg opts} {
    puts "Error: $msg"
    # opts is a dictionary with error details
    puts "Error code: [dict get $opts -errorcode]"
} finally {
    puts "Cleanup here"
}

# Trap specific error codes
try {
    set fp [open "nonexistent.txt" r]
} trap {POSIX ENOENT} {msg} {
    puts "File not found: $msg"
} trap {POSIX EACCES} {msg} {
    puts "Permission denied: $msg"
} on error {msg} {
    puts "Other error: $msg"
}
```

### catch (Classic Error Handling)

```tcl
# catch returns 0 on success, 1 on error
if {[catch {expr {10 / 0}} result]} {
    puts "Error: $result"
} else {
    puts "Result: $result"
}

# catch with options
if {[catch {open "nofile.txt" r} result opts]} {
    puts "Error code: [dict get $opts -errorcode]"
    puts "Error message: $result"
}

# Using catch for graceful degradation
proc safe_divide {a b} {
    if {[catch {expr {$a / $b}} result]} {
        return "Error: division by zero"
    }
    return $result
}
puts [safe_divide 10 3]   ;# 3
puts [safe_divide 10 0]   ;# Error: division by zero
```

### Raising Errors

```tcl
# Basic error
proc validate_age {age} {
    if {![string is integer $age] || $age < 0 || $age > 150} {
        error "Invalid age: $age (must be 0-150)"
    }
    return $age
}

try {
    validate_age 200
} on error {msg} {
    puts "Validation failed: $msg"
}

# Error with code
proc open_config {path} {
    if {![file exists $path]} {
        error "Config file not found: $path" "" {CONFIG NOT_FOUND}
    }
    # ... process file
}

try {
    open_config "/etc/myapp.conf"
} trap {CONFIG NOT_FOUND} {msg} {
    puts "Config error: $msg"
}

# return -code error (from within procedures)
proc require_positive {n} {
    if {$n <= 0} {
        return -code error "Expected positive number, got $n"
    }
    return $n
}
```

### throw (TCL 8.6+)

```tcl
proc process_data {data} {
    if {$data eq ""} {
        throw {APP EMPTY_DATA} "Data cannot be empty"
    }
    if {[string length $data] > 1000} {
        throw {APP DATA_TOO_LARGE} "Data exceeds 1000 character limit"
    }
    return "Processed: $data"
}

try {
    process_data ""
} trap {APP EMPTY_DATA} {msg} {
    puts "Empty: $msg"
} trap {APP DATA_TOO_LARGE} {msg} {
    puts "Too large: $msg"
}
```

---

## 16. Packages and Modules

### Using Packages

```tcl
# Load a package
package require Tcl 8.6
package require http
package require json

# Check available packages
puts [package names]

# Check version
puts [package require Tcl]   ;# e.g., 8.6.13
```

### Creating a Package

```tcl
# File: mymath/mymath.tcl
package provide mymath 1.0

namespace eval mymath {
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

```tcl
# File: mymath/pkgIndex.tcl
package ifneeded mymath 1.0 [list source [file join $dir mymath.tcl]]
```

```tcl
# Using the package
lappend auto_path "/path/to/packages"
package require mymath 1.0

puts [mymath::add 10 20]        ;# 30
puts [mymath::divide 22 7]      ;# 3.142857142857143
```

### Source Files

```tcl
# source — execute another TCL script in the current interpreter
source "utils.tcl"
source [file join $env(HOME) "scripts" "config.tcl"]
```

---

## 17. Object-Oriented Programming (TclOO)

TCL 8.6 introduced TclOO, a native object-oriented system.

### Defining Classes

```tcl
oo::class create Animal {
    variable name species sound

    constructor {n s {snd "..."}} {
        set name $n
        set species $s
        set sound $snd
    }

    method speak {} {
        puts "$name the $species says: $sound"
    }

    method get_name {} {
        return $name
    }

    method describe {} {
        puts "Name: $name, Species: $species"
    }
}

set dog [Animal new "Rex" "Dog" "Woof!"]
set cat [Animal new "Whiskers" "Cat" "Meow!"]

$dog speak      ;# Rex the Dog says: Woof!
$cat speak      ;# Whiskers the Cat says: Meow!
$dog describe   ;# Name: Rex, Species: Dog
```

### Inheritance

```tcl
oo::class create Shape {
    variable color

    constructor {{c "black"}} {
        set color $c
    }

    method get_color {} {
        return $color
    }

    method area {} {
        error "area must be implemented by subclass"
    }

    method describe {} {
        puts "[info object class [self]] - Color: $color, Area: [my area]"
    }
}

oo::class create Circle {
    superclass Shape
    variable radius

    constructor {r {c "black"}} {
        next $c
        set radius $r
    }

    method area {} {
        return [expr {3.14159 * $radius * $radius}]
    }

    method circumference {} {
        return [expr {2 * 3.14159 * $radius}]
    }
}

oo::class create Rectangle {
    superclass Shape
    variable width height

    constructor {w h {c "black"}} {
        next $c
        set width $w
        set height $h
    }

    method area {} {
        return [expr {$width * $height}]
    }

    method perimeter {} {
        return [expr {2 * ($width + $height)}]
    }
}

set c [Circle new 5 "red"]
$c describe   ;# ::Circle - Color: red, Area: 78.53975

set r [Rectangle new 4 6 "blue"]
$r describe   ;# ::Rectangle - Color: blue, Area: 24
```

### Mixins

```tcl
oo::class create Printable {
    method to_string {} {
        set result {}
        foreach var [info object vars [self]] {
            my variable $var
            lappend result "$var=[set $var]"
        }
        return [join $result ", "]
    }
}

oo::class create Serializable {
    method to_dict {} {
        set d [dict create]
        foreach var [info object vars [self]] {
            my variable $var
            dict set d $var [set $var]
        }
        return $d
    }
}

oo::class create User {
    mixin Printable Serializable
    variable username email

    constructor {u e} {
        set username $u
        set email $e
    }
}

set user [User new "alice" "alice@example.com"]
puts [$user to_string]   ;# username=alice, email=alice@example.com
puts [$user to_dict]      ;# username alice email alice@example.com
```

---

## 18. Event-Driven Programming

### The Event Loop

```tcl
# after — schedule code to run after a delay (milliseconds)
proc tick {} {
    puts "Tick at [clock format [clock seconds] -format %H:%M:%S]"
    after 1000 tick   ;# Reschedule
}

tick
vwait forever   ;# Enter the event loop (blocks until 'forever' is set)
```

### Timer Events

```tcl
# One-shot timer
after 2000 {puts "This runs after 2 seconds"}

# Repeating timer
proc heartbeat {} {
    puts "Heartbeat: [clock seconds]"
    after 5000 heartbeat
}

# Cancel a timer
set timer_id [after 10000 {puts "This will be cancelled"}]
after cancel $timer_id

# after idle — run when the event loop is idle
after idle {puts "Running during idle time"}
```

### File Events

```tcl
# Monitor a channel for readability
proc handle_input {chan} {
    if {[eof $chan]} {
        close $chan
        set ::done 1
        return
    }
    gets $chan line
    puts "Received: $line"
}

set fp [open "|tail -f /var/log/syslog" r]
fconfigure $fp -blocking 0 -buffering line
fileevent $fp readable [list handle_input $fp]

vwait done
```

---

## 19. Interprocess Communication

### Running External Commands

```tcl
# exec — run an external command and capture output
set result [exec ls -la]
puts $result

# Capture command output into variable
set date [exec date]
puts "Current date: $date"

# Pipe commands
set result [exec ps aux | grep tclsh]

# Redirect stderr
catch {exec some_command 2>@1} output

# Background execution
exec long_running_command &
```

### Open Process Pipelines

```tcl
# Open a pipeline for reading
set fp [open "|ls -la" r]
while {[gets $fp line] >= 0} {
    puts $line
}
close $fp

# Open a pipeline for writing
set fp [open "|mail user@example.com" w]
puts $fp "Subject: Test"
puts $fp ""
puts $fp "This is a test email."
close $fp

# Bidirectional pipeline
set fp [open "|sort" r+]
puts $fp "banana"
puts $fp "apple"
puts $fp "cherry"
close $fp write
while {[gets $fp line] >= 0} {
    puts $line
}
close $fp
```

### Socket Programming

```tcl
# TCP Server
proc accept {chan addr port} {
    puts "Connection from $addr:$port"
    fconfigure $chan -buffering line
    fileevent $chan readable [list handle_client $chan]
}

proc handle_client {chan} {
    if {[eof $chan] || [catch {gets $chan line}]} {
        close $chan
        return
    }
    puts "Client says: $line"
    puts $chan "Echo: $line"
}

set server [socket -server accept 9000]
puts "Server listening on port 9000"
vwait forever
```

```tcl
# TCP Client
set sock [socket "localhost" 9000]
fconfigure $sock -buffering line
puts $sock "Hello, Server!"
gets $sock response
puts "Server responded: $response"
close $sock
```

---

## 20. Advanced Techniques

### Coroutines (TCL 8.6+)

```tcl
# A coroutine is a procedure that can suspend and resume execution
proc counter_body {} {
    set i 0
    while {1} {
        yield $i
        incr i
    }
}

coroutine counter counter_body
puts [counter]   ;# 0
puts [counter]   ;# 1
puts [counter]   ;# 2
puts [counter]   ;# 3

# Generator pattern
proc fibonacci_gen {} {
    set a 0
    set b 1
    yield
    while {1} {
        yield $a
        lassign [list $b [expr {$a + $b}]] a b
    }
}

coroutine fib fibonacci_gen
for {set i 0} {$i < 10} {incr i} {
    puts -nonewline "[fib] "
}
puts ""
# Output: 0 1 1 2 3 5 8 13 21 34
```

### Interpreters (Safe Interpreters)

```tcl
# Create a child interpreter
set child [interp create]

# Execute code in the child
interp eval $child {
    set x 42
    proc hello {} { puts "Hello from child!" }
}
interp eval $child hello

# Create a safe interpreter (restricted)
set safe [interp create -safe]

# Expose limited commands
interp expose $safe puts

# The safe interpreter cannot access the filesystem or exec commands

# Delete interpreters
interp delete $child
interp delete $safe
```

### Introspection

```tcl
# Information about commands
puts [info commands string*]          ;# All commands matching string*
puts [info procs]                      ;# User-defined procedures
puts [info body my_proc]              ;# Body of a procedure
puts [info args my_proc]              ;# Arguments of a procedure
puts [info default my_proc arg defVar] ;# Default value

# Information about variables
puts [info vars]          ;# All variables in current scope
puts [info globals]       ;# All global variables
puts [info locals]        ;# All local variables
puts [info exists myvar]  ;# Does variable exist?

# Information about the interpreter
puts [info patchlevel]    ;# TCL version
puts [info hostname]      ;# Hostname
puts [info script]        ;# Current script file
puts [info nameofexecutable]  ;# Path to tclsh
puts [info library]       ;# TCL library path
```

### Tracing Variables and Commands

```tcl
# Trace variable reads and writes
proc on_var_change {name1 name2 op} {
    upvar 1 $name1 var
    puts "Variable '$name1' was $op, value: $var"
}

set x 10
trace add variable x {write read} on_var_change

set x 20     ;# Output: Variable 'x' was write, value: 20
puts $x       ;# Output: Variable 'x' was read, value: 20

# Trace command execution
proc on_cmd_exec {cmd args} {
    puts "Command '$cmd' called with: $args"
}

trace add execution puts enter on_cmd_exec

# Remove traces
trace remove variable x {write read} on_var_change
```

### String Representation and Binary Data

```tcl
# Binary format and scan
set packed [binary format "iii" 1 2 3]
binary scan $packed "iii" a b c
puts "$a $b $c"   ;# 1 2 3

# Pack/unpack network data
set packet [binary format "Sca*" 0x1234 5 "hello"]
binary scan $packet "Sca5" header count data
puts [format "Header: 0x%04X, Count: %d, Data: %s" $header $count $data]

# Encoding/decoding
set utf8 [encoding convertto utf-8 "Hello Wörld"]
set back [encoding convertfrom utf-8 $utf8]
```

### Command Aliases and Renaming

```tcl
# Rename a command
rename puts original_puts

proc puts {args} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    original_puts "\[$timestamp\] [join $args]"
}

puts "This message has a timestamp"

# Restore original
rename puts {}
rename original_puts puts

# interp alias — create command aliases
interp alias {} log {} puts
log "This is a log message"
```

### Metaprogramming: Creating Commands Dynamically

```tcl
# Create getter/setter methods dynamically
proc create_property {class_name prop_name} {
    oo::define $class_name method get_$prop_name {} "
        variable $prop_name
        return \[set $prop_name\]
    "
    oo::define $class_name method set_$prop_name {value} "
        variable $prop_name
        set $prop_name \$value
    "
}

oo::class create Person {
    variable name age

    constructor {n a} {
        set name $n
        set age $a
    }
}

create_property Person name
create_property Person age

set p [Person new "Alice" 30]
puts [$p get_name]   ;# Alice
$p set_age 31
puts [$p get_age]    ;# 31
```

---

## 21. Practical Examples

### Example 1: CSV File Parser

```tcl
proc parse_csv {filename {delimiter ","}} {
    set fp [open $filename r]
    set header_line [gets $fp]
    set headers [split $header_line $delimiter]

    set records [list]
    while {[gets $fp line] >= 0} {
        if {[string trim $line] eq ""} continue
        set values [split $line $delimiter]
        set record [dict create]
        foreach h $headers v $values {
            dict set record [string trim $h] [string trim $v]
        }
        lappend records $record
    }
    close $fp
    return $records
}

proc write_csv {filename records {delimiter ","}} {
    set fp [open $filename w]
    if {[llength $records] == 0} {
        close $fp
        return
    }
    set headers [dict keys [lindex $records 0]]
    puts $fp [join $headers $delimiter]
    foreach rec $records {
        set values [list]
        foreach h $headers {
            lappend values [dict get $rec $h]
        }
        puts $fp [join $values $delimiter]
    }
    close $fp
}

# Usage:
# set data [parse_csv "employees.csv"]
# dict for {k v} [lindex $data 0] { puts "$k: $v" }
# write_csv "output.csv" $data
```

### Example 2: Log File Analyzer

```tcl
proc analyze_log {logfile} {
    set levels [dict create INFO 0 WARNING 0 ERROR 0 DEBUG 0]
    set error_messages [list]
    set total 0

    set fp [open $logfile r]
    while {[gets $fp line] >= 0} {
        incr total
        foreach level [dict keys $levels] {
            if {[regexp "\\b$level\\b" $line]} {
                dict incr levels $level
                if {$level eq "ERROR"} {
                    lappend error_messages $line
                }
                break
            }
        }
    }
    close $fp

    puts "=== Log Analysis Report ==="
    puts "Total lines: $total"
    puts ""
    puts "Level Breakdown:"
    dict for {level count} $levels {
        set pct [expr {$total > 0 ? double($count) / $total * 100 : 0}]
        puts [format "  %-10s %5d  (%5.1f%%)" $level $count $pct]
    }

    if {[llength $error_messages] > 0} {
        puts "\nRecent Errors (last 5):"
        foreach msg [lrange $error_messages end-4 end] {
            puts "  $msg"
        }
    }
}

# Usage: analyze_log "application.log"
```

### Example 3: Simple HTTP Client

```tcl
package require http
package require tls

http::register https 443 [list ::tls::socket -autoservername true]

proc http_get {url} {
    set token [http::geturl $url -timeout 10000]
    set status [http::status $token]
    set code [http::ncode $token]
    set body [http::data $token]
    http::cleanup $token

    if {$status ne "ok"} {
        error "HTTP request failed: $status"
    }

    return [dict create status $code body $body]
}

# Usage:
# set response [http_get "https://api.example.com/data"]
# puts "Status: [dict get $response status]"
# puts "Body: [dict get $response body]"
```

### Example 4: Configuration File Manager

```tcl
namespace eval config {
    variable data [dict create]
    variable filename ""

    proc load {path} {
        variable data
        variable filename
        set filename $path
        set data [dict create]

        if {![file exists $path]} {
            return
        }

        set fp [open $path r]
        set section "default"

        while {[gets $fp line] >= 0} {
            set line [string trim $line]

            if {$line eq "" || [string index $line 0] eq "#"} {
                continue
            }

            if {[regexp {^\[(.+)\]$} $line -> sec]} {
                set section $sec
                continue
            }

            if {[regexp {^([^=]+)=(.*)$} $line -> key value]} {
                dict set data $section [string trim $key] [string trim $value]
            }
        }
        close $fp
    }

    proc get {section key {default ""}} {
        variable data
        if {[dict exists $data $section $key]} {
            return [dict get $data $section $key]
        }
        return $default
    }

    proc set_value {section key value} {
        variable data
        dict set data $section $key $value
    }

    proc save {{path ""}} {
        variable data
        variable filename
        if {$path eq ""} { set path $filename }

        set fp [open $path w]
        dict for {section entries} $data {
            puts $fp "\[$section\]"
            dict for {key value} $entries {
                puts $fp "$key = $value"
            }
            puts $fp ""
        }
        close $fp
    }

    proc dump {} {
        variable data
        dict for {section entries} $data {
            puts "\[$section\]"
            dict for {key value} $entries {
                puts "  $key = $value"
            }
        }
    }
}

# Usage:
# config::load "app.ini"
# set port [config::get "server" "port" "8080"]
# config::set_value "server" "host" "0.0.0.0"
# config::save
# config::dump
```

### Example 5: Directory Tree Walker

```tcl
proc walk_dir {dir {indent 0} {pattern "*"}} {
    set prefix [string repeat "  " $indent]
    set entries [lsort [glob -nocomplain -directory $dir *]]

    foreach entry $entries {
        set name [file tail $entry]

        if {[file type $entry] eq "directory"} {
            puts "${prefix}[format "%-40s  <DIR>" $name]"
            walk_dir $entry [expr {$indent + 1}] $pattern
        } else {
            if {[string match $pattern $name]} {
                set size [file size $entry]
                set mtime [clock format [file mtime $entry] -format "%Y-%m-%d %H:%M"]
                puts [format "%s%-40s  %8d  %s" $prefix $name $size $mtime]
            }
        }
    }
}

proc dir_stats {dir} {
    set total_files 0
    set total_size 0
    set extensions [dict create]

    proc _scan {dir} {
        upvar total_files tf total_size ts extensions ext
        foreach entry [glob -nocomplain -directory $dir *] {
            if {[file type $entry] eq "directory"} {
                _scan $entry
            } else {
                incr tf
                incr ts [file size $entry]
                set e [file extension $entry]
                if {$e eq ""} { set e "(none)" }
                dict incr ext $e
            }
        }
    }

    _scan $dir

    puts "=== Directory Statistics: $dir ==="
    puts "Total files: $total_files"
    puts "Total size:  [format "%.2f MB" [expr {$total_size / 1048576.0}]]"
    puts "\nFile types:"
    foreach {ext count} [lsort -stride 2 -index 1 -integer -decreasing [dict get $extensions]] {
        puts [format "  %-10s %d files" $ext $count]
    }

    rename _scan {}
}

# Usage:
# walk_dir "/path/to/project"
# walk_dir "/path/to/project" 0 "*.tcl"
# dir_stats "/path/to/project"
```

### Example 6: Task Scheduler

```tcl
namespace eval scheduler {
    variable tasks [dict create]
    variable next_id 0

    proc add {name interval_ms command} {
        variable tasks
        variable next_id
        set id [incr next_id]
        dict set tasks $id [dict create \
            name     $name \
            interval $interval_ms \
            command  $command \
            runs     0 \
        ]
        schedule $id
        puts "Scheduled task '$name' (ID: $id) every ${interval_ms}ms"
        return $id
    }

    proc schedule {id} {
        variable tasks
        if {![dict exists $tasks $id]} return
        set interval [dict get $tasks $id interval]
        after $interval [list [namespace current]::run $id]
    }

    proc run {id} {
        variable tasks
        if {![dict exists $tasks $id]} return
        set name [dict get $tasks $id name]
        set command [dict get $tasks $id command]
        dict incr tasks $id runs

        if {[catch {uplevel #0 $command} result]} {
            puts "Task '$name' failed: $result"
        }

        schedule $id
    }

    proc cancel {id} {
        variable tasks
        if {[dict exists $tasks $id]} {
            set name [dict get $tasks $id name]
            dict unset tasks $id
            puts "Cancelled task '$name' (ID: $id)"
        }
    }

    proc status {} {
        variable tasks
        puts "=== Scheduled Tasks ==="
        dict for {id info} $tasks {
            dict with info {
                puts [format "  ID:%d  %-20s  every %dms  (ran %d times)" \
                    $id $name $interval $runs]
            }
        }
    }
}

# Usage:
# scheduler::add "heartbeat" 5000 {puts "alive at [clock seconds]"}
# scheduler::add "cleanup"   60000 {puts "cleaning up..."}
# scheduler::status
# vwait forever
```

### Example 7: Simple Test Framework

```tcl
namespace eval tunit {
    variable tests [list]
    variable passed 0
    variable failed 0
    variable errors [list]

    proc test {name body} {
        variable tests
        lappend tests [list $name $body]
    }

    proc assert_equal {expected actual {msg ""}} {
        if {$expected ne $actual} {
            if {$msg eq ""} {
                set msg "Expected '$expected' but got '$actual'"
            }
            error $msg
        }
    }

    proc assert_true {condition {msg ""}} {
        if {!$condition} {
            if {$msg eq ""} { set msg "Assertion failed: expected true" }
            error $msg
        }
    }

    proc assert_false {condition {msg ""}} {
        if {$condition} {
            if {$msg eq ""} { set msg "Assertion failed: expected false" }
            error $msg
        }
    }

    proc assert_match {pattern actual {msg ""}} {
        if {![string match $pattern $actual]} {
            if {$msg eq ""} {
                set msg "Expected '$actual' to match pattern '$pattern'"
            }
            error $msg
        }
    }

    proc assert_error {body {pattern "*"}} {
        if {![catch {uplevel 1 $body} result]} {
            error "Expected error but none was raised"
        }
        if {![string match $pattern $result]} {
            error "Error '$result' does not match pattern '$pattern'"
        }
    }

    proc run {} {
        variable tests
        variable passed
        variable failed
        variable errors

        set passed 0
        set failed 0
        set errors [list]
        set start [clock milliseconds]

        puts "Running [llength $tests] tests...\n"

        foreach test_case $tests {
            lassign $test_case name body
            puts -nonewline "  $name ... "
            if {[catch {uplevel #0 $body} result]} {
                incr failed
                puts "FAIL"
                lappend errors [list $name $result]
            } else {
                incr passed
                puts "OK"
            }
        }

        set elapsed [expr {[clock milliseconds] - $start}]
        puts "\n[string repeat "=" 50]"
        puts "Results: $passed passed, $failed failed ([llength $tests] total)"
        puts "Time: ${elapsed}ms"

        if {[llength $errors] > 0} {
            puts "\nFailures:"
            foreach err $errors {
                lassign $err name msg
                puts "  $name: $msg"
            }
        }

        set tests [list]
        return [expr {$failed == 0}]
    }
}

# Usage:
# tunit::test "addition" {
#     tunit::assert_equal 5 [expr {2 + 3}]
# }
# tunit::test "string ops" {
#     tunit::assert_equal "HELLO" [string toupper "hello"]
# }
# tunit::test "list operations" {
#     set lst [list a b c]
#     tunit::assert_equal 3 [llength $lst]
#     tunit::assert_equal "b" [lindex $lst 1]
# }
# tunit::run
```

### Example 8: EDA/FPGA Tool Scripting Examples

```tcl
# Common patterns used in EDA tool flows (Synopsys, Cadence, Xilinx, Intel)

# --- Timing constraint generation ---
proc create_clock_constraints {clocks_dict output_file} {
    set fp [open $output_file w]
    puts $fp "# Auto-generated clock constraints"
    puts $fp "# Generated: [clock format [clock seconds]]"
    puts $fp ""

    dict for {clk_name clk_info} $clocks_dict {
        set period [dict get $clk_info period]
        set port   [dict get $clk_info port]
        set waveform_rise 0.0
        set waveform_fall [expr {$period / 2.0}]

        puts $fp "create_clock -name $clk_name -period $period \\"
        puts $fp "  -waveform {$waveform_rise $waveform_fall} \\"
        puts $fp "  \[get_ports $port\]"
        puts $fp ""

        if {[dict exists $clk_info uncertainty]} {
            set unc [dict get $clk_info uncertainty]
            puts $fp "set_clock_uncertainty $unc \[get_clocks $clk_name\]"
        }
        if {[dict exists $clk_info latency]} {
            set lat [dict get $clk_info latency]
            puts $fp "set_clock_latency $lat \[get_clocks $clk_name\]"
        }
        puts $fp ""
    }
    close $fp
    puts "Wrote constraints to $output_file"
}

# Usage:
# set clocks [dict create \
#     sys_clk [dict create period 10.0 port CLK uncertainty 0.1] \
#     pci_clk [dict create period 30.0 port PCI_CLK latency 0.5] \
# ]
# create_clock_constraints $clocks "timing.sdc"

# --- Filelist generator ---
proc generate_filelist {src_dir extensions output_file} {
    set fp [open $output_file w]
    puts $fp "// Auto-generated filelist"

    foreach ext $extensions {
        foreach f [lsort [glob -nocomplain -directory $src_dir *.$ext]] {
            puts $fp [file normalize $f]
        }
    }

    close $fp
    puts "Generated filelist: $output_file"
}

# Usage:
# generate_filelist "./rtl" {v sv} "filelist.f"

# --- Report parser ---
proc parse_timing_report {report_file} {
    set fp [open $report_file r]
    set worst_slack 999999.0
    set violations 0
    set paths [list]

    while {[gets $fp line] >= 0} {
        if {[regexp {slack\s*\(.*?\)\s+([-\d.]+)} $line -> slack]} {
            if {$slack < $worst_slack} {
                set worst_slack $slack
            }
            if {$slack < 0} {
                incr violations
            }
            lappend paths [dict create slack $slack line $line]
        }
    }
    close $fp

    puts "=== Timing Report Summary ==="
    puts "Worst slack:     $worst_slack"
    puts "Violations:      $violations"
    puts "Paths analyzed:  [llength $paths]"
    puts "Status:          [expr {$violations == 0 ? "PASS" : "FAIL"}]"

    return [dict create worst_slack $worst_slack violations $violations paths $paths]
}

# Usage:
# set result [parse_timing_report "timing_report.rpt"]
```

---

## 22. Best Practices and Style Guide

### Code Formatting

```tcl
# Use 4-space indentation (most common in TCL)
proc well_formatted {args} {
    foreach arg $args {
        if {[string length $arg] > 0} {
            puts "Arg: $arg"
        }
    }
}

# Opening braces on the same line (REQUIRED in TCL)
# CORRECT:
if {$x > 0} {
    puts "positive"
}

# WRONG (will not work):
# if {$x > 0}
# {
#     puts "positive"
# }
```

### Naming Conventions

```tcl
# snake_case for variables and procedures (most common)
set my_variable 42
proc calculate_sum {a b} { expr {$a + $b} }

# PascalCase for classes (TclOO)
oo::class create MyApplication { ... }

# UPPER_CASE for constants
set MAX_RETRIES 3
set DEFAULT_TIMEOUT 30000

# Namespace-qualified names
namespace eval my_app {
    proc start {} { ... }
}
```

### Performance Tips

```tcl
# 1. Always brace expressions
expr {$a + $b}          ;# Fast (compiled)
# expr "$a + $b"        ;# Slow (interpreted each time)

# 2. Use lappend instead of concat for building lists
set result [list]
lappend result $item    ;# O(1) amortized
# set result [concat $result [list $item]]  ;# O(n) — copies entire list

# 3. Use append for building strings
set str ""
append str "part1" "part2"    ;# Efficient
# set str "$str$part"          ;# Creates new string each time

# 4. Use dict instead of array when possible (dicts are values)
set d [dict create key1 val1 key2 val2]

# 5. Use lmap instead of foreach + lappend (TCL 8.6+)
set doubled [lmap x $list {expr {$x * 2}}]

# 6. Avoid unnecessary string operations in tight loops
# 7. Use [info exists] before accessing potentially unset variables
# 8. Prefer [string equal] over [string compare] == 0 for clarity
```

### Defensive Programming

```tcl
# Validate inputs
proc process_file {filename} {
    if {![file exists $filename]} {
        error "File not found: $filename"
    }
    if {![file readable $filename]} {
        error "File not readable: $filename"
    }
    # ... process
}

# Use catch/try for operations that can fail
proc safe_read {filename} {
    try {
        set fp [open $filename r]
        set content [read $fp]
        close $fp
        return $content
    } on error {msg} {
        puts stderr "Failed to read $filename: $msg"
        return ""
    }
}

# Initialize variables with defaults
proc get_config {key} {
    global config
    if {[info exists config($key)]} {
        return $config($key)
    }
    switch $key {
        "timeout"  { return 30 }
        "retries"  { return 3 }
        "verbose"  { return 0 }
        default    { return "" }
    }
}
```

---

## 23. Quick Reference

### Essential Commands

| Command | Description | Example |
|---|---|---|
| `set` | Set/get variable | `set x 10` |
| `puts` | Print output | `puts "Hello"` |
| `expr` | Evaluate expression | `expr {2 + 3}` |
| `incr` | Increment integer | `incr x 5` |
| `append` | Append to string | `append s "more"` |
| `info` | Introspection | `info exists x` |
| `proc` | Define procedure | `proc f {x} {...}` |
| `return` | Return from proc | `return $val` |
| `if` | Conditional | `if {$x > 0} {...}` |
| `for` | For loop | `for {set i 0} {$i<10} {incr i} {...}` |
| `foreach` | Iterate list | `foreach x $list {...}` |
| `while` | While loop | `while {$i < 10} {...}` |
| `switch` | Multi-branch | `switch $val {...}` |
| `break` | Exit loop | `break` |
| `continue` | Next iteration | `continue` |
| `catch` | Catch errors | `catch {cmd} result` |
| `try` | Try/catch (8.6) | `try {...} on error {...}` |
| `error` | Raise error | `error "msg"` |
| `source` | Execute file | `source "lib.tcl"` |
| `exec` | Run external cmd | `exec ls -la` |
| `open/close` | File I/O | `set f [open "x" r]` |
| `gets` | Read line | `gets $f line` |
| `read` | Read all | `read $f` |
| `regexp` | Regex match | `regexp {\d+} $str` |
| `regsub` | Regex replace | `regsub {a} $s "b"` |
| `clock` | Date/time | `clock seconds` |
| `after` | Delayed exec | `after 1000 {cmd}` |
| `glob` | File patterns | `glob *.tcl` |
| `file` | File operations | `file exists $f` |
| `package` | Package mgmt | `package require http` |
| `namespace` | Namespace mgmt | `namespace eval ns {...}` |

### String Subcommands

| Subcommand | Description |
|---|---|
| `string length` | Length of string |
| `string index` | Character at index |
| `string range` | Substring |
| `string first` | Find first occurrence |
| `string last` | Find last occurrence |
| `string match` | Glob matching |
| `string map` | Character mapping |
| `string trim` | Remove whitespace |
| `string toupper` | Uppercase |
| `string tolower` | Lowercase |
| `string replace` | Replace range |
| `string reverse` | Reverse string |
| `string repeat` | Repeat string |
| `string is` | Type checking |
| `string compare` | Compare strings |
| `string equal` | Equality check |

### List Subcommands

| Subcommand | Description |
|---|---|
| `list` | Create a list |
| `llength` | List length |
| `lindex` | Element at index |
| `lrange` | Sublist |
| `lappend` | Append elements |
| `linsert` | Insert elements |
| `lreplace` | Replace elements |
| `lset` | Set element at index |
| `lsort` | Sort list |
| `lsearch` | Search list |
| `lmap` | Transform list (8.6) |
| `lreverse` | Reverse list |
| `lrepeat` | Repeat elements |
| `lassign` | Assign to variables |
| `join` | Join into string |
| `split` | Split string to list |
| `concat` | Concatenate lists |

### Dict Subcommands

| Subcommand | Description |
|---|---|
| `dict create` | Create dictionary |
| `dict get` | Get value |
| `dict set` | Set value |
| `dict exists` | Check key exists |
| `dict unset` | Remove key |
| `dict keys` | All keys |
| `dict values` | All values |
| `dict size` | Number of entries |
| `dict for` | Iterate |
| `dict map` | Transform (8.6) |
| `dict filter` | Filter entries |
| `dict incr` | Increment value |
| `dict append` | Append to value |
| `dict lappend` | List-append to value |
| `dict merge` | Merge dictionaries |
| `dict with` | Access dict vars |

---

## Further Resources

- **Official TCL Documentation**: [https://www.tcl.tk/doc/](https://www.tcl.tk/doc/)
- **TCL Wiki**: [https://wiki.tcl-lang.org/](https://wiki.tcl-lang.org/)
- **TCL Tutorial**: [https://www.tcl.tk/man/tcl/tutorial/tcltutorial.html](https://www.tcl.tk/man/tcl/tutorial/tcltutorial.html)
- **TclOO Documentation**: [https://www.tcl.tk/man/tcl8.6/TclCmd/class.html](https://www.tcl.tk/man/tcl8.6/TclCmd/class.html)
- **Tcler's Wiki**: [https://wiki.tcl-lang.org/page/Tcl+Tutorial+Lesson+0](https://wiki.tcl-lang.org/page/Tcl+Tutorial+Lesson+0)
