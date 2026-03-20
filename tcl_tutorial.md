# Comprehensive TCL Programming Tutorial

## Table of Contents

1. [Introduction to TCL](#1-introduction-to-tcl)
2. [Installation and Setup](#2-installation-and-setup)
3. [Basic Syntax and Structure](#3-basic-syntax-and-structure)
4. [Variables and Data Types](#4-variables-and-data-types)
5. [Operators](#5-operators)
6. [Control Flow](#6-control-flow)
7. [String Operations](#7-string-operations)
8. [Lists](#8-lists)
9. [Arrays (Associative)](#9-arrays-associative)
10. [Dictionaries](#10-dictionaries)
11. [Procedures (Functions)](#11-procedures-functions)
12. [File I/O](#12-file-io)
13. [Regular Expressions](#13-regular-expressions)
14. [Error Handling](#14-error-handling)
15. [Namespaces](#15-namespaces)
16. [Object-Oriented Programming (TclOO)](#16-object-oriented-programming-tcloo)
17. [Event-Driven Programming](#17-event-driven-programming)
18. [Interprocess Communication and OS Interaction](#18-interprocess-communication-and-os-interaction)
19. [Packages and Modules](#19-packages-and-modules)
20. [Practical Examples](#20-practical-examples)

---

## 1. Introduction to TCL

**TCL** (Tool Command Language, pronounced "tickle") is a dynamic, interpreted scripting language created by John Ousterhout in 1988. It is widely used for:

- **EDA (Electronic Design Automation)**: FPGA synthesis, ASIC flows, timing constraints (SDC is TCL-based)
- **Rapid prototyping and scripting**: Automating repetitive tasks
- **Embedded scripting**: Providing a scripting engine inside C/C++ applications
- **Network programming**: Protocol testing, network automation
- **GUI development**: Via the Tk toolkit (Tkinter in Python is based on Tk)
- **Testing and automation**: Test harnesses, regression frameworks

### Key Features

| Feature | Description |
|---|---|
| **Everything is a string** | All values in TCL are strings; they are interpreted as other types only when needed |
| **Command-based** | Every statement is a command followed by arguments |
| **Embeddable** | Easily embedded into C/C++ applications as a scripting engine |
| **Cross-platform** | Runs on Linux, macOS, Windows, and many embedded platforms |
| **Extensible** | Supports packages, C extensions, and object-oriented programming |
| **Event-driven** | Built-in event loop for asynchronous programming |

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
# or
sudo dnf install tcl tcl-devel
```

### macOS

```bash
brew install tcl-tk
```

### Windows

Download ActiveTcl from [https://www.activestate.com/products/tcl/](https://www.activestate.com/products/tcl/) or use the Magicsplat Tcl/Tk distribution.

### Verifying Installation

```bash
tclsh
# You should see a '%' prompt
% info patchlevel
8.6.13
% exit
```

### Running TCL Scripts

```bash
# Interactive shell
tclsh

# Run a script file
tclsh script.tcl

# Make a script executable (Linux/macOS)
#!/usr/bin/env tclsh
```

---

## 3. Basic Syntax and Structure

### The Fundamental Rule

TCL has one simple syntax rule: **everything is a command**. A command consists of a command name followed by its arguments, all separated by whitespace.

```tcl
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

puts "Hello" ;# Inline comment (semicolon required before #)

# TCL does not have native multi-line comments, but you can use
# if {0} block as a convention:
if {0} {
    This is a multi-line
    comment block. Nothing
    inside here will be executed.
}
```

### Command Separators

Commands are separated by newlines or semicolons:

```tcl
puts "First command"
puts "Second command"

puts "Third" ; puts "Fourth"   ;# Two commands on one line
```

### Substitution Rules

TCL performs three types of substitution before executing a command:

**1. Variable substitution** with `$`:

```tcl
set name "Alice"
puts "Hello, $name"           ;# Output: Hello, Alice
```

**2. Command substitution** with `[]`:

```tcl
puts "The time is [clock format [clock seconds]]"
```

**3. Backslash substitution**:

```tcl
puts "Tab:\there"              ;# Tab character
puts "Newline:\nSecond line"   ;# Newline
puts "Dollar sign: \$"        ;# Literal $
puts "Bracket: \["             ;# Literal [
puts "Backslash: \\"           ;# Literal \
```

### Grouping with Braces and Quotes

- **Double quotes `""`**: Allow substitution inside

```tcl
set x 42
puts "The value is $x"        ;# Output: The value is 42
```

- **Curly braces `{}`**: Prevent all substitution (literal)

```tcl
set x 42
puts {The value is $x}        ;# Output: The value is $x
```

This distinction is critical and is one of the most important concepts in TCL.

---

## 4. Variables and Data Types

### Setting and Reading Variables

```tcl
set myVar "Hello"              ;# Set a variable
puts $myVar                    ;# Read with $ substitution
puts [set myVar]               ;# Alternative: read using set command

set count 100
set pi 3.14159
set flag true
```

### Variable Names

```tcl
set simple_var 10
set CamelCase "text"
set var123 "mixed"
set _private "underscore ok"

# Access with curly braces for complex names
set my(var) "value"
puts ${my(var)}
```

### The `set` Command

`set` with one argument returns the variable's value; with two arguments it assigns:

```tcl
set x 10                       ;# Assign 10 to x
set x                          ;# Returns 10 (same as $x)
```

### Unsetting Variables

```tcl
set temp "delete me"
unset temp
# puts $temp   ;# Error: can't read "temp": no such variable
```

### Checking if a Variable Exists

```tcl
set x 10
if {[info exists x]} {
    puts "x exists and equals $x"
}
if {![info exists y]} {
    puts "y does not exist"
}
```

### Dynamic Typing

TCL has no explicit types. Everything is a string, but values are interpreted contextually:

```tcl
set val "42"
expr {$val + 8}                ;# 50 — interpreted as integer
string length $val             ;# 2  — interpreted as string
```

### Mathematical Expressions with `expr`

```tcl
set a 10
set b 3

puts [expr {$a + $b}]         ;# 13
puts [expr {$a - $b}]         ;# 7
puts [expr {$a * $b}]         ;# 30
puts [expr {$a / $b}]         ;# 3 (integer division)
puts [expr {$a % $b}]         ;# 1
puts [expr {double($a) / $b}] ;# 3.3333333333333335
puts [expr {$a ** $b}]        ;# 1000 (exponentiation)

# Always brace your expressions for safety and performance
puts [expr {2 + 3 * 4}]       ;# 14 (standard precedence)
puts [expr {(2 + 3) * 4}]     ;# 20
```

### Math Functions

```tcl
puts [expr {sqrt(144)}]       ;# 12.0
puts [expr {abs(-7)}]         ;# 7
puts [expr {round(3.7)}]      ;# 4
puts [expr {int(3.9)}]        ;# 3
puts [expr {ceil(3.2)}]       ;# 4.0
puts [expr {floor(3.9)}]      ;# 3.0
puts [expr {sin(3.14159/2)}]  ;# ~1.0
puts [expr {log(100)}]        ;# 4.605 (natural log)
puts [expr {log10(100)}]      ;# 2.0
puts [expr {pow(2, 10)}]      ;# 1024.0
puts [expr {rand()}]          ;# Random float [0, 1)
puts [expr {int(rand() * 100)}] ;# Random integer [0, 99]
```

---

## 5. Operators

### Arithmetic Operators

| Operator | Description | Example |
|---|---|---|
| `+` | Addition | `expr {5 + 3}` → 8 |
| `-` | Subtraction | `expr {5 - 3}` → 2 |
| `*` | Multiplication | `expr {5 * 3}` → 15 |
| `/` | Division | `expr {5 / 3}` → 1 |
| `%` | Modulo | `expr {5 % 3}` → 2 |
| `**` | Exponentiation | `expr {2 ** 8}` → 256 |

### Comparison Operators

| Operator | Description | Example |
|---|---|---|
| `==` | Equal (numeric) | `expr {5 == 5}` → 1 |
| `!=` | Not equal (numeric) | `expr {5 != 3}` → 1 |
| `<` | Less than | `expr {3 < 5}` → 1 |
| `>` | Greater than | `expr {5 > 3}` → 1 |
| `<=` | Less or equal | `expr {3 <= 3}` → 1 |
| `>=` | Greater or equal | `expr {5 >= 5}` → 1 |
| `eq` | String equal | `expr {"abc" eq "abc"}` → 1 |
| `ne` | String not equal | `expr {"abc" ne "def"}` → 1 |

### Logical Operators

| Operator | Description | Example |
|---|---|---|
| `&&` | Logical AND | `expr {1 && 0}` → 0 |
| `\|\|` | Logical OR | `expr {1 \|\| 0}` → 1 |
| `!` | Logical NOT | `expr {!0}` → 1 |

### Bitwise Operators

| Operator | Description | Example |
|---|---|---|
| `&` | Bitwise AND | `expr {0xFF & 0x0F}` → 15 |
| `\|` | Bitwise OR | `expr {0xF0 \| 0x0F}` → 255 |
| `^` | Bitwise XOR | `expr {0xFF ^ 0x0F}` → 240 |
| `~` | Bitwise NOT | `expr {~0}` → -1 |
| `<<` | Left shift | `expr {1 << 4}` → 16 |
| `>>` | Right shift | `expr {16 >> 2}` → 4 |

### Ternary Operator

```tcl
set x 10
set result [expr {$x > 5 ? "big" : "small"}]
puts $result  ;# big
```

---

## 6. Control Flow

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
```

Output:

```
Grade: B
```

> **Important**: The opening brace `{` must be on the same line as `if`, `elseif`, and `else`. This is because TCL parses newlines as command terminators.

### switch

```tcl
set fruit "apple"

switch $fruit {
    "apple" {
        puts "It's an apple"
    }
    "banana" {
        puts "It's a banana"
    }
    "cherry" -
    "grape" {
        puts "It's cherry or grape (fall-through)"
    }
    default {
        puts "Unknown fruit"
    }
}
```

Switch with `-glob` matching:

```tcl
set filename "report.txt"

switch -glob $filename {
    *.txt  { puts "Text file" }
    *.csv  { puts "CSV file" }
    *.log  { puts "Log file" }
    default { puts "Other file type" }
}
```

Switch with `-regexp` matching:

```tcl
set input "Error: file not found"

switch -regexp $input {
    {^Error:}   { puts "Error detected" }
    {^Warning:} { puts "Warning detected" }
    {^Info:}    { puts "Info message" }
    default     { puts "Unknown message type" }
}
```

### while Loop

```tcl
set i 0
while {$i < 5} {
    puts "i = $i"
    incr i
}
```

Output:

```
i = 0
i = 1
i = 2
i = 3
i = 4
```

### for Loop

```tcl
for {set i 0} {$i < 5} {incr i} {
    puts "Iteration $i"
}
```

### foreach Loop

```tcl
# Iterate over a list
set colors {red green blue yellow}
foreach color $colors {
    puts "Color: $color"
}

# Multiple variables per iteration
set pairs {a 1 b 2 c 3}
foreach {letter number} $pairs {
    puts "$letter => $number"
}

# Iterate over multiple lists simultaneously
set names {Alice Bob Charlie}
set ages  {25 30 35}
foreach name $names age $ages {
    puts "$name is $age years old"
}
```

### Loop Control: break and continue

```tcl
# break exits the loop
for {set i 0} {$i < 10} {incr i} {
    if {$i == 5} break
    puts $i
}
# Output: 0 1 2 3 4

# continue skips to the next iteration
for {set i 0} {$i < 10} {incr i} {
    if {$i % 2 == 0} continue
    puts $i
}
# Output: 1 3 5 7 9
```

---

## 7. String Operations

Strings are the fundamental data type in TCL. The `string` command provides a rich set of subcommands.

### String Length and Index

```tcl
set str "Hello, TCL!"

puts [string length $str]       ;# 11
puts [string index $str 0]      ;# H
puts [string index $str end]    ;# !
puts [string index $str end-1]  ;# L
```

### String Range (Substring)

```tcl
set str "Hello, World!"

puts [string range $str 0 4]    ;# Hello
puts [string range $str 7 end]  ;# World!
```

### String Case Conversion

```tcl
set str "Hello World"

puts [string toupper $str]      ;# HELLO WORLD
puts [string tolower $str]      ;# hello world
puts [string totitle $str]      ;# Hello World
```

### String Comparison

```tcl
set a "apple"
set b "banana"

puts [string compare $a $b]       ;# -1 (a < b)
puts [string equal $a $b]         ;# 0 (not equal)
puts [string equal -nocase "ABC" "abc"]  ;# 1 (equal, case-insensitive)
```

### String Search

```tcl
set str "Hello, World! Hello, TCL!"

puts [string first "Hello" $str]    ;# 0 (first occurrence)
puts [string last "Hello" $str]     ;# 14 (last occurrence)
puts [string first "xyz" $str]      ;# -1 (not found)
```

### String Matching (Glob-style)

```tcl
puts [string match "*.tcl" "script.tcl"]   ;# 1
puts [string match "*.tcl" "script.txt"]   ;# 0
puts [string match {[Hh]ello} "Hello"]     ;# 1
puts [string match "H?llo" "Hello"]        ;# 1
```

### String Manipulation

```tcl
# Replace
set str "Hello, World!"
puts [string replace $str 7 11 "TCL"]     ;# Hello, TCL!!

# Reverse
puts [string reverse "Hello"]              ;# olleH

# Repeat
puts [string repeat "abc" 3]              ;# abcabcabc

# Trim whitespace
puts [string trim "  Hello  "]            ;# "Hello"
puts [string trimleft "  Hello  "]        ;# "Hello  "
puts [string trimright "  Hello  "]       ;# "  Hello"
puts [string trim "xxHelloxx" "x"]        ;# "Hello"

# Map (character translation)
puts [string map {a @ e 3 o 0} "hello"]   ;# h3ll0
```

### String Classification

```tcl
puts [string is integer "42"]     ;# 1
puts [string is integer "hello"]  ;# 0
puts [string is double "3.14"]    ;# 1
puts [string is alpha "Hello"]    ;# 1
puts [string is alnum "abc123"]   ;# 1
puts [string is space "  \t\n"]   ;# 1
puts [string is upper "ABC"]      ;# 1
puts [string is lower "abc"]      ;# 1
```

### format and scan

```tcl
# format — like C's sprintf
set msg [format "Name: %-10s Age: %3d GPA: %.2f" "Alice" 22 3.856]
puts $msg  ;# Name: Alice      Age:  22 GPA: 3.86

set hex [format "0x%08X" 255]
puts $hex  ;# 0x000000FF

# scan — like C's sscanf
set input "Alice 22 3.856"
scan $input "%s %d %f" name age gpa
puts "Name=$name Age=$age GPA=$gpa"
```

### String Concatenation

```tcl
set a "Hello"
set b "World"

# Method 1: append command (most efficient for building strings)
append a ", " $b "!"
puts $a  ;# Hello, World!

# Method 2: Double-quote substitution
set result "$a And more"

# Method 3: string cat (Tcl 8.6.2+)
set result [string cat "Hello" ", " "World" "!"]
```

---

## 8. Lists

Lists are ordered collections and one of TCL's most powerful features. A list is simply a specially formatted string.

### Creating Lists

```tcl
# Space-separated values
set fruits {apple banana cherry}

# Using list command (handles special characters properly)
set items [list "hello world" {curly braces} simple]

# Empty list
set empty {}
set empty [list]
```

### List Information

```tcl
set fruits {apple banana cherry date elderberry}

puts [llength $fruits]           ;# 5
puts [lindex $fruits 0]          ;# apple
puts [lindex $fruits end]        ;# elderberry
puts [lindex $fruits 2]          ;# cherry
puts [lrange $fruits 1 3]        ;# banana cherry date
```

### Modifying Lists

```tcl
set fruits {apple banana cherry}

# Append to end
lappend fruits "date"
puts $fruits  ;# apple banana cherry date

# Insert at position
set fruits [linsert $fruits 1 "blueberry"]
puts $fruits  ;# apple blueberry banana cherry date

# Replace elements
set fruits [lreplace $fruits 2 2 "blackberry"]
puts $fruits  ;# apple blueberry blackberry cherry date

# Remove an element (replace with nothing)
set fruits [lreplace $fruits 1 1]
puts $fruits  ;# apple blackberry cherry date

# Concatenate lists
set more {elderberry fig grape}
set all [concat $fruits $more]
puts $all
```

### Searching Lists

```tcl
set colors {red green blue yellow green purple}

puts [lsearch $colors "blue"]         ;# 2 (index of first match)
puts [lsearch $colors "orange"]       ;# -1 (not found)
puts [lsearch -all $colors "green"]   ;# 1 4 (all matching indices)
puts [lsearch -glob $colors "gr*"]    ;# 1 (first glob match)
puts [lsearch -regexp $colors {^b.*}] ;# 2 (first regex match)
```

### Sorting Lists

```tcl
set nums {3 1 4 1 5 9 2 6}
puts [lsort $nums]                      ;# 1 1 2 3 4 5 6 9
puts [lsort -decreasing $nums]          ;# 9 6 5 4 3 2 1 1
puts [lsort -unique $nums]              ;# 1 2 3 4 5 6 9
puts [lsort -integer $nums]             ;# 1 1 2 3 4 5 6 9

set words {banana Apple cherry apple Banana}
puts [lsort $words]                      ;# Apple Banana apple banana cherry
puts [lsort -nocase $words]              ;# apple Apple banana Banana cherry

# Custom sorting
set data {{Alice 25} {Bob 30} {Charlie 20}}
puts [lsort -index 1 -integer $data]    ;# {Charlie 20} {Alice 25} {Bob 30}
```

### Iterating Over Lists

```tcl
set languages {TCL Python Perl Ruby}
foreach lang $languages {
    puts "Language: $lang"
}
```

### List as Stack and Queue

```tcl
# Stack (LIFO)
set stack {}
lappend stack "a" "b" "c"
set top [lindex $stack end]
set stack [lreplace $stack end end]
puts "Popped: $top, Remaining: $stack"

# Queue (FIFO)
set queue {}
lappend queue "first" "second" "third"
set front [lindex $queue 0]
set queue [lreplace $queue 0 0]
puts "Dequeued: $front, Remaining: $queue"
```

### Nested Lists

```tcl
set matrix {{1 2 3} {4 5 6} {7 8 9}}

puts [lindex $matrix 0]         ;# 1 2 3 (first row)
puts [lindex $matrix 1 2]       ;# 6 (row 1, column 2)
puts [lindex $matrix end end]   ;# 9
```

### join and split

```tcl
# join: list → string
set words {Hello World from TCL}
puts [join $words ", "]           ;# Hello, World, from, TCL
puts [join $words ""]             ;# HelloWorldfromTCL

# split: string → list
set csv "Alice,25,Engineer"
set fields [split $csv ","]
puts $fields                      ;# Alice 25 Engineer
puts [lindex $fields 1]           ;# 25

# Split on every character
set chars [split "Hello" ""]
puts $chars                       ;# H e l l o
```

---

## 9. Arrays (Associative)

TCL arrays are hash maps (associative arrays). They are **not** ordered and **cannot** be passed by value—they are always accessed by name.

### Creating and Accessing Arrays

```tcl
set person(name)  "Alice"
set person(age)   25
set person(email) "alice@example.com"

puts $person(name)              ;# Alice
puts $person(age)               ;# 25
```

### Array Operations

```tcl
# Check if array exists
puts [array exists person]      ;# 1

# Get all keys
puts [array names person]       ;# name age email (unordered)

# Get size
puts [array size person]        ;# 3

# Get key-value pairs as a flat list
puts [array get person]         ;# name Alice age 25 email alice@example.com

# Set from a flat list
array set config {
    host   "localhost"
    port   8080
    debug  true
}
puts $config(host)              ;# localhost

# Check if a key exists
puts [info exists person(name)]  ;# 1
puts [info exists person(phone)] ;# 0
```

### Iterating Over Arrays

```tcl
array set scores {
    Alice   95
    Bob     87
    Charlie 92
}

foreach {name score} [array get scores] {
    puts "$name scored $score"
}

# Sorted iteration
foreach name [lsort [array names scores]] {
    puts "$name: $scores($name)"
}
```

### Unsetting Array Elements

```tcl
array set data {x 1 y 2 z 3}
unset data(y)
puts [array names data]          ;# x z

# Unset entire array
unset data
```

### Using Arrays with Procedures

```tcl
proc print_array {arrayName} {
    upvar 1 $arrayName arr
    foreach key [lsort [array names arr]] {
        puts "  $key = $arr($key)"
    }
}

array set config {host localhost port 8080}
print_array config
```

---

## 10. Dictionaries

Dictionaries (introduced in Tcl 8.5) are ordered key-value structures that can be passed by value, unlike arrays.

### Creating Dictionaries

```tcl
set person [dict create name "Alice" age 25 city "New York"]

# Or directly
set person {name Alice age 25 city {New York}}
```

### Accessing Values

```tcl
set person [dict create name "Alice" age 25 city "New York"]

puts [dict get $person name]     ;# Alice
puts [dict get $person age]      ;# 25

# Check if key exists
puts [dict exists $person name]  ;# 1
puts [dict exists $person phone] ;# 0
```

### Modifying Dictionaries

```tcl
set person [dict create name "Alice" age 25]

# Set/update a value
dict set person age 26
dict set person email "alice@example.com"

# Remove a key
dict unset person email

# Increment a numeric value
dict incr person age

puts $person  ;# name Alice age 27
```

### Dictionary Information

```tcl
set d [dict create a 1 b 2 c 3]

puts [dict size $d]              ;# 3
puts [dict keys $d]              ;# a b c
puts [dict values $d]            ;# 1 2 3
```

### Iterating Over Dictionaries

```tcl
set scores [dict create Alice 95 Bob 87 Charlie 92]

dict for {name score} $scores {
    puts "$name: $score"
}
```

### Nested Dictionaries

```tcl
set company [dict create \
    CEO [dict create name "Alice" age 45] \
    CTO [dict create name "Bob" age 40]   \
]

puts [dict get $company CEO name]   ;# Alice
dict set company CFO name "Charlie"
dict set company CFO age 38
```

### Dictionary Filtering and Mapping

```tcl
set scores [dict create Alice 95 Bob 60 Charlie 85 Dave 55]

# Filter keys matching a pattern
set a_names [dict filter $scores key "A*"]
puts $a_names  ;# Alice 95

# Filter by value using a script
set passing [dict filter $scores script {name score} {
    expr {$score >= 70}
}]
puts $passing  ;# Alice 95 Charlie 85

# Map (transform values)
set doubled [dict map {name score} $scores {
    expr {$score * 2}
}]
puts $doubled  ;# Alice 190 Bob 120 Charlie 170 Dave 110
```

### Dictionaries vs. Arrays

| Feature | Arrays | Dictionaries |
|---|---|---|
| Ordered | No | Yes (insertion order) |
| Pass by value | No (pass by name) | Yes |
| Nesting | No | Yes (native) |
| Syntax | `$arr(key)` | `dict get $d key` |
| Introduced | Tcl 7.x | Tcl 8.5 |
| Best for | Global state, large lookup tables | Structured data, function args |

---

## 11. Procedures (Functions)

### Basic Procedures

```tcl
proc greet {name} {
    puts "Hello, $name!"
}

greet "Alice"    ;# Hello, Alice!
```

### Return Values

```tcl
proc add {a b} {
    return [expr {$a + $b}]
}

set sum [add 3 7]
puts "Sum: $sum"  ;# Sum: 10
```

### Default Arguments

```tcl
proc greet {name {greeting "Hello"}} {
    puts "$greeting, $name!"
}

greet "Alice"              ;# Hello, Alice!
greet "Bob" "Good morning" ;# Good morning, Bob!
```

### Variable-Length Arguments (args)

```tcl
proc sum {args} {
    set total 0
    foreach num $args {
        set total [expr {$total + $num}]
    }
    return $total
}

puts [sum 1 2 3 4 5]  ;# 15
```

### Local vs. Global Variables

```tcl
set count 0

proc increment {} {
    global count
    incr count
}

increment
increment
puts $count  ;# 2
```

### upvar — Accessing Caller's Variables

```tcl
proc double_var {varName} {
    upvar 1 $varName var
    set var [expr {$var * 2}]
}

set x 5
double_var x
puts $x  ;# 10
```

### uplevel — Executing in Caller's Scope

```tcl
proc do_in_caller {script} {
    uplevel 1 $script
}

set x 10
do_in_caller {set x [expr {$x + 5}]}
puts $x  ;# 15
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
```

### Procedure Introspection

```tcl
proc example {a b {c 10}} {
    return [expr {$a + $b + $c}]
}

puts [info args example]    ;# a b c
puts [info body example]    ;# return [expr {$a + $b + $c}]
puts [info default example c defaultVal]  ;# 1 (defaultVal set to 10)
```

---

## 12. File I/O

### Reading Files

```tcl
# Read entire file
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
```

### Writing Files

```tcl
# Write to a file (overwrite)
set fp [open "output.txt" w]
puts $fp "First line"
puts $fp "Second line"
close $fp

# Append to a file
set fp [open "output.txt" a]
puts $fp "Third line"
close $fp

# Write without trailing newline
set fp [open "output.txt" w]
puts -nonewline $fp "No newline at end"
close $fp
```

### File Modes

| Mode | Description |
|---|---|
| `r` | Read only (default), file must exist |
| `w` | Write only, creates or truncates |
| `a` | Append, creates if needed |
| `r+` | Read/write, file must exist |
| `w+` | Read/write, creates or truncates |
| `a+` | Read/append, creates if needed |

### Binary File I/O

```tcl
set fp [open "image.bin" rb]
set data [read $fp]
close $fp

set fp [open "copy.bin" wb]
puts -nonewline $fp $data
close $fp
```

### File and Directory Operations

```tcl
# File information
puts [file exists "test.txt"]         ;# 1 or 0
puts [file size "test.txt"]           ;# file size in bytes
puts [file type "test.txt"]           ;# file, directory, link
puts [file readable "test.txt"]       ;# 1 or 0
puts [file writable "test.txt"]       ;# 1 or 0
puts [file extension "test.txt"]      ;# .txt
puts [file tail "/path/to/test.txt"]  ;# test.txt
puts [file dirname "/path/to/test.txt"] ;# /path/to
puts [file rootname "test.txt"]       ;# test
puts [file join "/path" "to" "file"]  ;# /path/to/file

# Modification time
puts [clock format [file mtime "test.txt"]]

# Directory operations
file mkdir "newdir"
file delete "oldfile.txt"
file delete -force "directory"
file rename "old.txt" "new.txt"
file copy "source.txt" "dest.txt"

# List files in a directory
set files [glob -nocomplain *.tcl]
foreach f $files {
    puts $f
}

# Recursive glob
set all_tcl [glob -nocomplain -directory /project **/*.tcl]
```

### Safe File Handling with try/finally

```tcl
set fp [open "data.txt" r]
try {
    while {[gets $fp line] >= 0} {
        puts $line
    }
} finally {
    close $fp
}
```

---

## 13. Regular Expressions

TCL has built-in regular expression support with `regexp` and `regsub`.

### Basic Matching

```tcl
set str "The quick brown fox"

if {[regexp {quick} $str]} {
    puts "Found 'quick'"
}

# Case-insensitive
if {[regexp -nocase {QUICK} $str]} {
    puts "Found (case-insensitive)"
}
```

### Capturing Groups

```tcl
set str "Date: 2026-03-20"

if {[regexp {(\d{4})-(\d{2})-(\d{2})} $str match year month day]} {
    puts "Full match: $match"
    puts "Year: $year, Month: $month, Day: $day"
}
# Output:
# Full match: 2026-03-20
# Year: 2026, Month: 03, Day: 20
```

### Finding All Matches

```tcl
set str "cat bat rat hat"

set count [regexp -all -inline {[a-z]at} $str]
puts $count  ;# cat bat rat hat
```

### Substitution with regsub

```tcl
set str "Hello World Hello TCL"

# Replace first occurrence
regsub {Hello} $str "Hi" result
puts $result  ;# Hi World Hello TCL

# Replace all occurrences
regsub -all {Hello} $str "Hi" result
puts $result  ;# Hi World Hi TCL

# Using backreferences
set str "John Smith"
regsub {(\w+) (\w+)} $str {\2, \1} result
puts $result  ;# Smith, John

# In-place (Tcl 8.6.7+, same variable as source and target)
set email "user@example.com"
regsub {@.*} $email "" username
puts $username  ;# user
```

### Common Regex Patterns

```tcl
# Email validation
proc is_email {str} {
    regexp {^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$} $str
}

# IP address validation
proc is_ipv4 {str} {
    if {![regexp {^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$} $str \
              match a b c d]} {
        return 0
    }
    foreach octet [list $a $b $c $d] {
        if {$octet > 255} { return 0 }
    }
    return 1
}

puts [is_email "test@example.com"]  ;# 1
puts [is_ipv4 "192.168.1.1"]       ;# 1
puts [is_ipv4 "999.1.1.1"]         ;# 0
```

### Regex Syntax Reference

| Pattern | Meaning |
|---|---|
| `.` | Any character |
| `\d` | Digit `[0-9]` |
| `\w` | Word character `[a-zA-Z0-9_]` |
| `\s` | Whitespace |
| `^` | Start of string |
| `$` | End of string |
| `*` | Zero or more |
| `+` | One or more |
| `?` | Zero or one |
| `{n,m}` | Between n and m repetitions |
| `[abc]` | Character class |
| `(...)` | Capturing group |
| `(?:...)` | Non-capturing group |
| `\|` | Alternation (OR) |

---

## 14. Error Handling

### try / on / trap / finally (Tcl 8.6+)

```tcl
try {
    set result [expr {10 / 0}]
} on error {msg opts} {
    puts "Error: $msg"
} finally {
    puts "Cleanup done"
}
```

### catch

```tcl
if {[catch {expr {10 / 0}} result opts]} {
    puts "Error caught: $result"
    puts "Error code: [dict get $opts -errorcode]"
    puts "Error info: [dict get $opts -errorinfo]"
} else {
    puts "Result: $result"
}
```

### Generating Errors

```tcl
proc divide {a b} {
    if {$b == 0} {
        error "Division by zero" "" {ARITH DIVZERO}
    }
    return [expr {double($a) / $b}]
}

try {
    puts [divide 10 0]
} on error {msg} {
    puts "Caught: $msg"
}
```

### Custom Error Codes with trap

```tcl
proc open_config {path} {
    if {![file exists $path]} {
        error "Config file not found: $path" "" {CONFIG MISSING}
    }
    set fp [open $path r]
    set data [read $fp]
    close $fp
    return $data
}

try {
    set cfg [open_config "/nonexistent/file.cfg"]
} trap {CONFIG MISSING} {msg} {
    puts "Configuration error: $msg"
} on error {msg} {
    puts "General error: $msg"
}
```

### throw (Tcl 8.6+)

```tcl
proc validate_age {age} {
    if {![string is integer -strict $age]} {
        throw {VALIDATION TYPE} "Age must be an integer"
    }
    if {$age < 0 || $age > 150} {
        throw {VALIDATION RANGE} "Age must be between 0 and 150"
    }
    return $age
}

try {
    validate_age "abc"
} trap {VALIDATION TYPE} {msg} {
    puts "Type error: $msg"
} trap {VALIDATION RANGE} {msg} {
    puts "Range error: $msg"
}
```

---

## 15. Namespaces

Namespaces prevent naming collisions and organize code into logical modules.

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
            set connection "connected to $host:$port"
            return $connection
        }
    }

    namespace eval ui {
        proc show_status {} {
            puts "DB: $::app::db::connection"
        }
    }
}

app::db::connect "localhost" 5432
app::ui::show_status
```

### Importing and Exporting

```tcl
namespace eval utils {
    namespace export log warn
    
    proc log {msg} {
        puts "LOG: $msg"
    }
    
    proc warn {msg} {
        puts "WARN: $msg"
    }
    
    proc _internal {} {
        puts "This is private"
    }
}

namespace import utils::log utils::warn
log "Application started"
warn "Low memory"
```

### namespace ensemble — Command Ensembles

```tcl
namespace eval counter {
    variable count 0

    namespace export reset incr get
    namespace ensemble create

    proc reset {} {
        variable count
        set count 0
    }

    proc incr {} {
        variable count
        ::incr count
    }

    proc get {} {
        variable count
        return $count
    }
}

counter reset
counter incr
counter incr
counter incr
puts [counter get]  ;# 3
```

---

## 16. Object-Oriented Programming (TclOO)

TclOO (introduced in Tcl 8.6) provides a modern object-oriented system.

### Basic Class Definition

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
        puts "I am $name, a $species"
    }
}

set dog [Animal new "Rex" "Dog" "Woof!"]
$dog speak     ;# Rex the Dog says: Woof!
$dog describe  ;# I am Rex, a Dog
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
        puts "A $color shape with area [my area]"
    }
}

oo::class create Circle {
    superclass Shape
    variable radius

    constructor {r {color "red"}} {
        next $color
        set radius $r
    }

    method area {} {
        expr {3.14159 * $radius * $radius}
    }
}

oo::class create Rectangle {
    superclass Shape
    variable width height

    constructor {w h {color "blue"}} {
        next $color
        set width $w
        set height $h
    }

    method area {} {
        expr {$width * $height}
    }
}

set c [Circle new 5 "green"]
$c describe  ;# A green shape with area 78.53975

set r [Rectangle new 4 6]
$r describe  ;# A blue shape with area 24
```

### Mixins

```tcl
oo::class create Serializable {
    method to_string {} {
        set result {}
        foreach var [info object vars [self]] {
            my variable $var
            lappend result "$var=[set $var]"
        }
        return [join $result ", "]
    }
}

oo::class create Printable {
    method print {} {
        puts "[info object class [self]]: [my to_string]"
    }
}

oo::class create Person {
    mixin Serializable Printable
    variable name age

    constructor {n a} {
        set name $n
        set age $a
    }
}

set p [Person new "Alice" 30]
puts [$p to_string]  ;# name=Alice, age=30
$p print             ;# ::Person: name=Alice, age=30
```

### Class Methods and Destruction

```tcl
oo::class create Connection {
    variable host port status

    constructor {h p} {
        set host $h
        set port $p
        set status "connected"
        puts "Connected to $host:$port"
    }

    destructor {
        puts "Disconnecting from $host:$port"
        set status "disconnected"
    }

    method query {sql} {
        if {$status ne "connected"} {
            error "Not connected"
        }
        puts "Executing: $sql"
        return "results"
    }
}

set conn [Connection new "localhost" 5432]
$conn query "SELECT * FROM users"
$conn destroy  ;# Calls destructor
```

---

## 17. Event-Driven Programming

TCL has a built-in event loop, making it excellent for asynchronous programming.

### after — Timer Events

```tcl
proc tick {count} {
    puts "Tick $count at [clock format [clock seconds] -format %H:%M:%S]"
    if {$count < 5} {
        after 1000 [list tick [expr {$count + 1}]]
    } else {
        set ::done 1
    }
}

tick 1
vwait done
puts "Timer finished"
```

### fileevent — I/O Events

```tcl
proc handle_readable {chan} {
    if {[eof $chan]} {
        close $chan
        set ::done 1
        return
    }
    gets $chan line
    puts "Received: $line"
}

set fp [open "| ls -la" r]
fconfigure $fp -blocking 0 -buffering line
fileevent $fp readable [list handle_readable $fp]
vwait done
```

### coroutine (Tcl 8.6+)

```tcl
proc counter_body {} {
    set i 0
    while {1} {
        yield $i
        incr i
    }
}

coroutine counter counter_body
puts [counter]  ;# 0
puts [counter]  ;# 1
puts [counter]  ;# 2
puts [counter]  ;# 3
rename counter {}
```

### Coroutine-Based Generator

```tcl
proc fibonacci_body {} {
    set a 0
    set b 1
    while {1} {
        yield $a
        lassign [list $b [expr {$a + $b}]] a b
    }
}

coroutine fib fibonacci_body
for {set i 0} {$i < 10} {incr i} {
    puts -nonewline "[fib] "
}
puts ""
# Output: 0 1 1 2 3 5 8 13 21 34
rename fib {}
```

### Simple TCP Server

```tcl
proc accept {chan addr port} {
    puts "Connection from $addr:$port"
    fconfigure $chan -buffering line
    fileevent $chan readable [list handle_client $chan]
}

proc handle_client {chan} {
    if {[eof $chan] || [catch {gets $chan line}]} {
        puts "Client disconnected"
        close $chan
        return
    }
    puts "Client says: $line"
    puts $chan "Echo: $line"
}

# Start server on port 9000
set server [socket -server accept 9000]
puts "Server listening on port 9000"
# vwait forever  ;# Uncomment to run the event loop
```

---

## 18. Interprocess Communication and OS Interaction

### Running External Commands

```tcl
# exec — capture output of external commands
set result [exec ls -la]
puts $result

# Capture with error handling
if {[catch {exec grep "pattern" somefile.txt} output]} {
    puts "grep returned non-zero or error: $output"
} else {
    puts "Matches: $output"
}

# Piping commands
set result [exec cat /etc/passwd | grep root | head -1]
puts $result
```

### Pipeline with open

```tcl
# Read from a pipeline
set fp [open "| ps aux" r]
while {[gets $fp line] >= 0} {
    puts $line
}
close $fp

# Write to a pipeline
set fp [open "| sort > sorted.txt" w]
puts $fp "banana"
puts $fp "apple"
puts $fp "cherry"
close $fp
```

### Environment Variables

```tcl
# Read environment variables
puts $::env(HOME)
puts $::env(PATH)

# Set environment variables (for child processes)
set ::env(MY_VAR) "my_value"

# Check if environment variable exists
if {[info exists ::env(EDITOR)]} {
    puts "Editor: $::env(EDITOR)"
}

# Iterate over all environment variables
foreach {name value} [array get ::env] {
    puts "$name = $value"
}
```

### Process and System Information

```tcl
puts "PID: [pid]"
puts "Platform: $::tcl_platform(os)"
puts "OS Version: $::tcl_platform(osVersion)"
puts "Machine: $::tcl_platform(machine)"
puts "Tcl Version: [info patchlevel]"
puts "Hostname: [info hostname]"
```

### Clock and Time

```tcl
# Current time
set now [clock seconds]
puts "Epoch: $now"
puts "Formatted: [clock format $now]"
puts "ISO: [clock format $now -format {%Y-%m-%dT%H:%M:%S}]"
puts "Date: [clock format $now -format {%B %d, %Y}]"

# Parse a date string
set t [clock scan "2026-03-20" -format {%Y-%m-%d}]
puts "Parsed: [clock format $t]"

# Measure elapsed time
set start [clock milliseconds]
after 100
set elapsed [expr {[clock milliseconds] - $start}]
puts "Elapsed: ${elapsed}ms"
```

---

## 19. Packages and Modules

### Using Packages

```tcl
# Load a package
package require Tcl 8.6
package require http
package require tls

# Check available version
puts [package versions http]
```

### Creating a Package

File: `mathutils/mathutils.tcl`

```tcl
package provide mathutils 1.0

namespace eval ::mathutils {
    namespace export factorial fibonacci gcd

    proc factorial {n} {
        if {$n <= 1} { return 1 }
        expr {$n * [factorial [expr {$n - 1}]]}
    }

    proc fibonacci {n} {
        set a 0; set b 1
        set result {}
        for {set i 0} {$i < $n} {incr i} {
            lappend result $a
            lassign [list $b [expr {$a + $b}]] a b
        }
        return $result
    }

    proc gcd {a b} {
        while {$b != 0} {
            lassign [list $b [expr {$a % $b}]] a b
        }
        return $a
    }
}
```

File: `mathutils/pkgIndex.tcl`

```tcl
package ifneeded mathutils 1.0 [list source [file join $dir mathutils.tcl]]
```

Using the package:

```tcl
lappend auto_path /path/to/parent/directory
package require mathutils 1.0

puts [mathutils::factorial 10]
puts [mathutils::fibonacci 10]
puts [mathutils::gcd 48 18]
```

### source — Including Other Files

```tcl
source "config.tcl"
source [file join $::env(HOME) ".myapp" "settings.tcl"]
```

---

## 20. Practical Examples

### Example 1: CSV File Parser

A reusable CSV parser that handles quoted fields, commas within quotes, and various delimiters.

```tcl
proc parse_csv_line {line {delimiter ","}} {
    set fields {}
    set current ""
    set in_quotes 0
    set chars [split $line ""]
    set len [llength $chars]
    
    for {set i 0} {$i < $len} {incr i} {
        set ch [lindex $chars $i]
        
        if {$in_quotes} {
            if {$ch eq "\""} {
                if {$i + 1 < $len && [lindex $chars [expr {$i+1}]] eq "\""} {
                    append current "\""
                    incr i
                } else {
                    set in_quotes 0
                }
            } else {
                append current $ch
            }
        } else {
            if {$ch eq "\""} {
                set in_quotes 1
            } elseif {$ch eq $delimiter} {
                lappend fields $current
                set current ""
            } else {
                append current $ch
            }
        }
    }
    lappend fields $current
    return $fields
}

proc read_csv {filename {has_header 1} {delimiter ","}} {
    set fp [open $filename r]
    set result [dict create]
    set headers {}
    set rows {}
    set line_num 0
    
    while {[gets $fp line] >= 0} {
        if {[string trim $line] eq ""} continue
        set fields [parse_csv_line $line $delimiter]
        
        if {$line_num == 0 && $has_header} {
            set headers $fields
        } else {
            lappend rows $fields
        }
        incr line_num
    }
    close $fp
    
    dict set result headers $headers
    dict set result rows $rows
    dict set result row_count [llength $rows]
    return $result
}

proc csv_to_dicts {csv_data} {
    set headers [dict get $csv_data headers]
    set records {}
    foreach row [dict get $csv_data rows] {
        set record [dict create]
        foreach h $headers v $row {
            dict set record $h $v
        }
        lappend records $record
    }
    return $records
}

# Usage example:
# set data [read_csv "employees.csv"]
# set records [csv_to_dicts $data]
# foreach rec $records {
#     puts "[dict get $rec Name]: [dict get $rec Department]"
# }
```

---

### Example 2: Log File Analyzer

Parses log files, extracts statistics, and generates a summary report.

```tcl
proc analyze_log {logfile} {
    set fp [open $logfile r]
    
    set total_lines 0
    set error_count 0
    set warn_count 0
    set info_count 0
    set errors_by_type [dict create]
    set hourly_counts [dict create]
    
    while {[gets $fp line] >= 0} {
        incr total_lines
        
        if {[regexp {(\d{2}):(\d{2}):(\d{2})} $line -> hour min sec]} {
            dict incr hourly_counts $hour
        }
        
        if {[regexp -nocase {ERROR:?\s*(.*)} $line -> msg]} {
            incr error_count
            set error_type [string range [string trim $msg] 0 49]
            dict incr errors_by_type $error_type
        } elseif {[regexp -nocase {WARN} $line]} {
            incr warn_count
        } elseif {[regexp -nocase {INFO} $line]} {
            incr info_count
        }
    }
    close $fp
    
    puts "========== Log Analysis Report =========="
    puts "File: $logfile"
    puts "Total lines:    $total_lines"
    puts "Errors:         $error_count"
    puts "Warnings:       $warn_count"
    puts "Info messages:  $info_count"
    puts ""
    
    if {[dict size $errors_by_type] > 0} {
        puts "--- Error Breakdown ---"
        dict for {type count} $errors_by_type {
            puts [format "  %-50s : %d" $type $count]
        }
        puts ""
    }
    
    if {[dict size $hourly_counts] > 0} {
        puts "--- Activity by Hour ---"
        foreach hour [lsort [dict keys $hourly_counts]] {
            set count [dict get $hourly_counts $hour]
            set bar [string repeat "#" [expr {$count / 10 + 1}]]
            puts [format "  %s:00  %5d  %s" $hour $count $bar]
        }
    }
    puts "========================================"
}

# Usage: analyze_log "application.log"
```

---

### Example 3: Configuration File Manager

Reads, writes, and manages INI-style configuration files.

```tcl
namespace eval config {
    variable data [dict create]

    proc load {filename} {
        variable data
        set data [dict create]
        set current_section "default"
        
        if {![file exists $filename]} {
            return -code error "Config file not found: $filename"
        }
        
        set fp [open $filename r]
        set line_num 0
        
        while {[gets $fp line] >= 0} {
            incr line_num
            set line [string trim $line]
            
            if {$line eq "" || [string index $line 0] eq "#" || 
                [string index $line 0] eq ";"} {
                continue
            }
            
            if {[regexp {^\[(\w+)\]$} $line -> section]} {
                set current_section $section
                continue
            }
            
            if {[regexp {^(\w[\w.]*)\s*=\s*(.*)$} $line -> key value]} {
                set value [string trim $value]
                if {[string index $value 0] eq "\"" && 
                    [string index $value end] eq "\""} {
                    set value [string range $value 1 end-1]
                }
                dict set data $current_section $key $value
            } else {
                puts stderr "Warning: Invalid syntax at line $line_num: $line"
            }
        }
        close $fp
        return $data
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

    proc save {filename} {
        variable data
        set fp [open $filename w]
        
        dict for {section keys} $data {
            puts $fp "\[$section\]"
            dict for {key value} $keys {
                if {[string first " " $value] >= 0} {
                    puts $fp "$key = \"$value\""
                } else {
                    puts $fp "$key = $value"
                }
            }
            puts $fp ""
        }
        close $fp
    }

    proc dump {} {
        variable data
        dict for {section keys} $data {
            puts "\[$section\]"
            dict for {key value} $keys {
                puts "  $key = $value"
            }
        }
    }
}

# Usage:
# config::load "app.ini"
# set db_host [config::get "database" "host" "localhost"]
# config::set_value "database" "port" "5432"
# config::save "app.ini"
# config::dump
```

Sample config file (`app.ini`):

```ini
[database]
host = localhost
port = 3306
name = myapp
user = admin
password = "secret password"

[server]
host = 0.0.0.0
port = 8080
debug = true

[logging]
level = info
file = /var/log/myapp.log
```

---

### Example 4: Directory Tree Walker

Recursively walks a directory tree and performs analysis.

```tcl
proc walk_directory {dir {indent 0} {stats_var ""}} {
    if {$stats_var ne ""} {
        upvar 1 $stats_var stats
    } else {
        set stats [dict create files 0 dirs 0 total_size 0 by_ext [dict create]]
    }
    
    set prefix [string repeat "  " $indent]
    set dirname [file tail $dir]
    puts "${prefix}[format "%-40s" "$dirname/"]"
    
    dict incr stats dirs
    
    set entries [lsort [glob -nocomplain -directory $dir *]]
    
    foreach entry $entries {
        if {[file isdirectory $entry]} {
            walk_directory $entry [expr {$indent + 1}] stats
        } else {
            set fname [file tail $entry]
            set size [file size $entry]
            set ext [file extension $entry]
            if {$ext eq ""} { set ext "(none)" }
            
            puts "${prefix}  [format "%-38s %8s" $fname [format_size $size]]"
            
            dict incr stats files
            dict set stats total_size [expr {[dict get $stats total_size] + $size}]
            
            set by_ext [dict get $stats by_ext]
            if {![dict exists $by_ext $ext]} {
                dict set by_ext $ext [dict create count 0 size 0]
            }
            dict with by_ext $ext {
                incr count
                set size_total [expr {$size_total + $size}]
            }
            dict set stats by_ext $by_ext
        }
    }
    
    return $stats
}

proc format_size {bytes} {
    if {$bytes < 1024} {
        return "${bytes} B"
    } elseif {$bytes < 1048576} {
        return [format "%.1f KB" [expr {$bytes / 1024.0}]]
    } elseif {$bytes < 1073741824} {
        return [format "%.1f MB" [expr {$bytes / 1048576.0}]]
    } else {
        return [format "%.1f GB" [expr {$bytes / 1073741824.0}]]
    }
}

# Usage:
# set stats [walk_directory "/path/to/project"]
# puts "\n=== Summary ==="
# puts "Total files: [dict get $stats files]"
# puts "Total dirs:  [dict get $stats dirs]"
# puts "Total size:  [format_size [dict get $stats total_size]]"
```

---

### Example 5: Simple HTTP Client

A lightweight HTTP client using TCL's built-in `http` package.

```tcl
package require http
package require tls

::http::register https 443 [list ::tls::socket -autoservername true]

proc http_get {url {headers {}}} {
    set token [::http::geturl $url -headers $headers -timeout 10000]
    set status [::http::status $token]
    set code [::http::ncode $token]
    set data [::http::data $token]
    set meta [::http::meta $token]
    ::http::cleanup $token
    
    return [dict create \
        status $status \
        code $code \
        body $data \
        headers $meta \
    ]
}

proc http_post {url body {content_type "application/json"} {headers {}}} {
    lappend headers Content-Type $content_type
    set token [::http::geturl $url \
        -query $body \
        -headers $headers \
        -method POST \
        -timeout 10000]
    set result [dict create \
        status [::http::status $token] \
        code [::http::ncode $token] \
        body [::http::data $token] \
    ]
    ::http::cleanup $token
    return $result
}

# Simple JSON parser for flat objects
proc json_parse_flat {json} {
    set json [string trim $json " \t\n\r{}"]
    set result [dict create]
    foreach pair [split $json ","] {
        if {[regexp {"(\w+)"\s*:\s*"?([^",}]*)"?} $pair -> key value]} {
            dict set result $key [string trim $value "\" "]
        }
    }
    return $result
}

# Usage:
# set response [http_get "https://httpbin.org/get"]
# puts "Status: [dict get $response code]"
# puts "Body: [dict get $response body]"
```

---

### Example 6: Task Scheduler / Job Queue

A simple in-memory job scheduler with priority support.

```tcl
namespace eval scheduler {
    variable jobs [list]
    variable job_id 0

    proc add_job {name command {priority 5} {delay_ms 0}} {
        variable jobs
        variable job_id
        incr job_id
        
        set run_at [expr {[clock milliseconds] + $delay_ms}]
        
        lappend jobs [dict create \
            id $job_id \
            name $name \
            command $command \
            priority $priority \
            run_at $run_at \
            status "pending" \
            result "" \
        ]
        
        puts "Job #$job_id '$name' scheduled (priority: $priority)"
        return $job_id
    }

    proc run_all {} {
        variable jobs
        
        set sorted [lsort -command compare_jobs $jobs]
        set completed 0
        set failed 0
        
        foreach job $sorted {
            set name [dict get $job name]
            set id [dict get $job id]
            set cmd [dict get $job command]
            
            set now [clock milliseconds]
            set run_at [dict get $job run_at]
            if {$now < $run_at} {
                set wait [expr {$run_at - $now}]
                puts "Waiting ${wait}ms for job #$id..."
                after $wait
            }
            
            puts -nonewline "Running job #$id '$name'... "
            
            if {[catch {uplevel #0 $cmd} result]} {
                puts "FAILED: $result"
                incr failed
            } else {
                puts "OK"
                if {$result ne ""} {
                    puts "  Result: $result"
                }
                incr completed
            }
        }
        
        puts "\nScheduler complete: $completed succeeded, $failed failed"
    }

    proc compare_jobs {a b} {
        set pa [dict get $a priority]
        set pb [dict get $b priority]
        if {$pa != $pb} {
            return [expr {$pa - $pb}]
        }
        set ta [dict get $a run_at]
        set tb [dict get $b run_at]
        return [expr {$ta - $tb}]
    }

    proc clear {} {
        variable jobs [list]
        variable job_id 0
    }
}

# Usage:
# scheduler::add_job "Backup DB" {exec pg_dump mydb > backup.sql} 1
# scheduler::add_job "Clean Temp" {file delete -force /tmp/myapp/*} 3
# scheduler::add_job "Send Report" {exec mail -s "Report" admin@co.com < report.txt} 5
# scheduler::run_all
```

---

### Example 7: Text Processing Pipeline

A functional-style text processing pipeline for transforming data.

```tcl
proc pipeline {data args} {
    set result $data
    foreach cmd $args {
        set result [uplevel 1 [list {*}$cmd $result]]
    }
    return $result
}

proc filter_lines {pattern data} {
    set result {}
    foreach line [split $data "\n"] {
        if {[regexp $pattern $line]} {
            lappend result $line
        }
    }
    return [join $result "\n"]
}

proc transform_lines {script data} {
    set result {}
    foreach line [split $data "\n"] {
        lappend result [uplevel 1 [list apply [list {line} $script] $line]]
    }
    return [join $result "\n"]
}

proc sort_lines {data} {
    return [join [lsort [split $data "\n"]] "\n"]
}

proc unique_lines {data} {
    return [join [lsort -unique [split $data "\n"]] "\n"]
}

proc head_lines {n data} {
    return [join [lrange [split $data "\n"] 0 [expr {$n - 1}]] "\n"]
}

proc count_lines {data} {
    return [llength [split $data "\n"]]
}

proc word_frequency {data} {
    set freq [dict create]
    foreach word [regexp -all -inline {\w+} [string tolower $data]] {
        dict incr freq $word
    }
    set pairs {}
    dict for {word count} $freq {
        lappend pairs [list $word $count]
    }
    return [lsort -index 1 -integer -decreasing $pairs]
}

# Usage:
# set data [read [set fp [open "data.txt" r]]][close $fp]
#
# set result [pipeline $data \
#     {filter_lines {ERROR|WARN}} \
#     {transform_lines {string toupper $line}} \
#     sort_lines \
#     unique_lines \
# ]
# puts $result
#
# set freq [word_frequency $data]
# foreach pair [lrange $freq 0 9] {
#     lassign $pair word count
#     puts [format "%-20s %d" $word $count]
# }
```

---

### Example 8: Unit Test Framework

A minimal but functional unit testing framework built entirely in TCL.

```tcl
namespace eval tunit {
    variable tests [list]
    variable pass_count 0
    variable fail_count 0
    variable error_count 0
    variable current_suite ""

    proc suite {name body} {
        variable current_suite
        set current_suite $name
        puts "\n=== Test Suite: $name ==="
        uplevel 1 $body
        set current_suite ""
    }

    proc test {name body} {
        variable pass_count
        variable fail_count
        variable error_count
        variable current_suite
        
        set full_name "$current_suite :: $name"
        
        if {[catch {uplevel 1 $body} result opts]} {
            set errinfo [dict get $opts -errorinfo]
            if {[string match "ASSERTION*" $result]} {
                incr fail_count
                puts "  FAIL  $full_name"
                puts "        $result"
            } else {
                incr error_count
                puts "  ERROR $full_name"
                puts "        $result"
            }
        } else {
            incr pass_count
            puts "  PASS  $full_name"
        }
    }

    proc assert_equal {expected actual {msg ""}} {
        if {$expected ne $actual} {
            set message "ASSERTION FAILED: Expected '$expected', got '$actual'"
            if {$msg ne ""} { append message " ($msg)" }
            error $message
        }
    }

    proc assert_true {expr {msg ""}} {
        if {![uplevel 1 [list expr $expr]]} {
            set message "ASSERTION FAILED: Expression is false: $expr"
            if {$msg ne ""} { append message " ($msg)" }
            error $message
        }
    }

    proc assert_false {expr {msg ""}} {
        if {[uplevel 1 [list expr $expr]]} {
            set message "ASSERTION FAILED: Expression is true: $expr"
            if {$msg ne ""} { append message " ($msg)" }
            error $message
        }
    }

    proc assert_error {body {pattern "*"}} {
        if {![catch {uplevel 1 $body} result]} {
            error "ASSERTION FAILED: Expected error, but got: $result"
        }
        if {![string match $pattern $result]} {
            error "ASSERTION FAILED: Error '$result' doesn't match '$pattern'"
        }
    }

    proc summary {} {
        variable pass_count
        variable fail_count
        variable error_count
        set total [expr {$pass_count + $fail_count + $error_count}]
        puts "\n========================================="
        puts "Results: $total total, $pass_count passed, $fail_count failed, $error_count errors"
        if {$fail_count == 0 && $error_count == 0} {
            puts "ALL TESTS PASSED"
        } else {
            puts "SOME TESTS FAILED"
        }
        puts "========================================="
        return [expr {$fail_count == 0 && $error_count == 0}]
    }
}

# Usage example:
tunit::suite "String Operations" {
    tunit::test "string length" {
        tunit::assert_equal 5 [string length "Hello"]
    }
    
    tunit::test "string toupper" {
        tunit::assert_equal "HELLO" [string toupper "hello"]
    }
    
    tunit::test "string reverse" {
        tunit::assert_equal "olleH" [string reverse "Hello"]
    }
}

tunit::suite "Math Operations" {
    tunit::test "addition" {
        tunit::assert_equal 5 [expr {2 + 3}]
    }
    
    tunit::test "division by zero raises error" {
        tunit::assert_error {expr {1/0}}
    }
    
    tunit::test "floating point" {
        tunit::assert_true {abs([expr {0.1 + 0.2}] - 0.3) < 0.0001}
    }
}

tunit::summary
```

---

### Example 9: EDA/FPGA Build Script

A practical script for automating FPGA synthesis — the domain where TCL is most heavily used.

```tcl
namespace eval fpga_build {
    variable project_name ""
    variable top_module ""
    variable device ""
    variable src_files [list]
    variable constraints [list]
    variable build_dir "build"
    variable log_file ""

    proc configure {args} {
        variable project_name
        variable top_module
        variable device
        variable build_dir
        
        dict for {key value} $args {
            switch -- $key {
                -project { set project_name $value }
                -top     { set top_module $value }
                -device  { set device $value }
                -outdir  { set build_dir $value }
                default  { error "Unknown option: $key" }
            }
        }
    }

    proc add_sources {args} {
        variable src_files
        foreach pattern $args {
            foreach f [glob -nocomplain $pattern] {
                if {[lsearch -exact $src_files $f] == -1} {
                    lappend src_files $f
                    log "Added source: $f"
                }
            }
        }
    }

    proc add_constraints {args} {
        variable constraints
        foreach pattern $args {
            foreach f [glob -nocomplain $pattern] {
                if {[lsearch -exact $constraints $f] == -1} {
                    lappend constraints $f
                    log "Added constraint: $f"
                }
            }
        }
    }

    proc log {msg} {
        variable log_file
        set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
        set entry "\[$timestamp\] $msg"
        puts $entry
        if {$log_file ne ""} {
            set fp [open $log_file a]
            puts $fp $entry
            close $fp
        }
    }

    proc run_build {} {
        variable project_name
        variable top_module
        variable device
        variable src_files
        variable constraints
        variable build_dir
        variable log_file
        
        file mkdir $build_dir
        set log_file [file join $build_dir "${project_name}_build.log"]
        
        log "===== Build Started: $project_name ====="
        log "Top module: $top_module"
        log "Target device: $device"
        log "Source files: [llength $src_files]"
        log "Constraint files: [llength $constraints]"
        
        set steps {
            {synthesis  "Running Synthesis"}
            {placement  "Running Placement"}
            {routing    "Running Routing"}
            {bitstream  "Generating Bitstream"}
        }
        
        set start_time [clock seconds]
        
        foreach step $steps {
            lassign $step step_name step_desc
            log "--- $step_desc ---"
            set step_start [clock milliseconds]
            
            if {[catch {run_step $step_name} result]} {
                log "FAILED at $step_name: $result"
                log "Build failed after [elapsed $start_time]"
                return -code error "Build failed at $step_name"
            }
            
            set step_time [expr {[clock milliseconds] - $step_start}]
            log "$step_name completed in ${step_time}ms"
        }
        
        log "===== Build Completed in [elapsed $start_time] ====="
    }

    proc run_step {step_name} {
        variable build_dir
        log "  Step '$step_name' would execute EDA tool commands here"
        # In a real implementation, this would call:
        # - Vivado: synth_design, place_design, route_design, write_bitstream
        # - Quartus: quartus_map, quartus_fit, quartus_asm
    }

    proc elapsed {start} {
        set seconds [expr {[clock seconds] - $start}]
        return [format "%dm %ds" [expr {$seconds / 60}] [expr {$seconds % 60}]]
    }

    proc generate_report {} {
        variable project_name
        variable top_module
        variable device
        variable src_files
        variable build_dir
        
        set report_file [file join $build_dir "${project_name}_report.txt"]
        set fp [open $report_file w]
        
        puts $fp "===== Build Report: $project_name ====="
        puts $fp "Top Module: $top_module"
        puts $fp "Device: $device"
        puts $fp "Generated: [clock format [clock seconds]]"
        puts $fp ""
        puts $fp "Source Files:"
        foreach f $src_files {
            puts $fp "  - $f ([file size $f] bytes)"
        }
        
        close $fp
        log "Report written to $report_file"
    }
}

# Usage:
# fpga_build::configure \
#     -project "my_design" \
#     -top "top_module" \
#     -device "xc7a35t" \
#     -outdir "build"
#
# fpga_build::add_sources "src/*.v" "src/*.sv"
# fpga_build::add_constraints "constraints/*.xdc"
# fpga_build::run_build
# fpga_build::generate_report
```

---

### Example 10: Interactive Command-Line Application

A complete command-line calculator with history and help.

```tcl
namespace eval calc {
    variable history [list]
    variable variables [dict create]
    variable running 1

    proc start {} {
        variable running
        
        puts "=============================="
        puts "  TCL Calculator v1.0"
        puts "  Type 'help' for commands"
        puts "=============================="
        
        while {$running} {
            puts -nonewline "calc> "
            flush stdout
            
            if {[gets stdin input] < 0} {
                break
            }
            
            set input [string trim $input]
            if {$input eq ""} continue
            
            process_input $input
        }
        
        puts "Goodbye!"
    }

    proc process_input {input} {
        variable history
        variable variables
        variable running
        
        lappend history $input
        
        switch -glob -- $input {
            "help" {
                show_help
            }
            "history" {
                show_history
            }
            "vars" {
                show_variables
            }
            "clear" {
                set history [list]
                puts "History cleared."
            }
            "quit" - "exit" {
                set running 0
            }
            "let *" {
                if {[regexp {^let\s+(\w+)\s*=\s*(.+)$} $input -> var expr_str]} {
                    if {[catch {evaluate $expr_str} result]} {
                        puts "Error: $result"
                    } else {
                        dict set variables $var $result
                        puts "$var = $result"
                    }
                } else {
                    puts "Usage: let <variable> = <expression>"
                }
            }
            default {
                if {[catch {evaluate $input} result]} {
                    puts "Error: $result"
                } else {
                    puts "= $result"
                }
            }
        }
    }

    proc evaluate {expr_str} {
        variable variables
        
        set substituted $expr_str
        dict for {name value} $variables {
            regsub -all "\\m$name\\M" $substituted $value substituted
        }
        
        return [expr $substituted]
    }

    proc show_help {} {
        puts {
Commands:
  <expression>          Evaluate a math expression
  let <var> = <expr>    Assign result to a variable
  vars                  Show all variables
  history               Show command history
  clear                 Clear history
  help                  Show this help
  quit / exit           Exit calculator

Examples:
  2 + 3 * 4
  sqrt(144)
  let x = 10
  x * 2 + 1
  sin(3.14159 / 2)
        }
    }

    proc show_history {} {
        variable history
        set i 1
        foreach cmd $history {
            puts [format "  %3d  %s" $i $cmd]
            incr i
        }
    }

    proc show_variables {} {
        variable variables
        if {[dict size $variables] == 0} {
            puts "  No variables defined."
            return
        }
        dict for {name value} $variables {
            puts [format "  %-10s = %s" $name $value]
        }
    }
}

# Usage: calc::start
```

---

## Quick Reference Card

### Essential Commands

| Command | Description | Example |
|---|---|---|
| `set` | Set/get variable | `set x 10` |
| `puts` | Print output | `puts "hello"` |
| `expr` | Evaluate expression | `expr {2 + 3}` |
| `proc` | Define procedure | `proc add {a b} { expr {$a+$b} }` |
| `if` | Conditional | `if {$x > 0} { puts "positive" }` |
| `for` | C-style loop | `for {set i 0} {$i<10} {incr i} {...}` |
| `foreach` | Iterate list | `foreach item $list { puts $item }` |
| `while` | While loop | `while {$x > 0} { incr x -1 }` |
| `switch` | Multi-branch | `switch $val { a {...} b {...} }` |
| `list` | Create list | `list a b c` |
| `dict` | Dictionary ops | `dict create k1 v1 k2 v2` |
| `string` | String ops | `string length "hello"` |
| `regexp` | Regex match | `regexp {\d+} $str match` |
| `regsub` | Regex replace | `regsub {old} $str new result` |
| `open` | Open file/pipe | `set fp [open "f.txt" r]` |
| `close` | Close channel | `close $fp` |
| `catch` | Catch errors | `catch {cmd} result` |
| `try` | Try/catch | `try {...} on error {m} {...}` |
| `exec` | Run OS command | `exec ls -la` |
| `source` | Include file | `source "lib.tcl"` |
| `package` | Load package | `package require http` |
| `namespace` | Namespace ops | `namespace eval ns {...}` |
| `info` | Introspection | `info exists varName` |
| `incr` | Increment int | `incr counter` |
| `append` | Append string | `append str "more"` |
| `lappend` | Append to list | `lappend mylist item` |
| `format` | Format string | `format "%05d" 42` |
| `scan` | Parse string | `scan "42" "%d" num` |
| `clock` | Date/time | `clock seconds` |
| `after` | Timer event | `after 1000 {puts hi}` |
| `glob` | File matching | `glob *.tcl` |
| `file` | File operations | `file exists "f.txt"` |

---

## Further Reading

- **Official Tcl Documentation**: [https://www.tcl-lang.org/man/tcl/](https://www.tcl-lang.org/man/tcl/)
- **Tcl Wiki**: [https://wiki.tcl-lang.org/](https://wiki.tcl-lang.org/)
- **Tcl Tutorial**: [https://www.tcl-lang.org/man/tcl/tutorial/tcltutorial.html](https://www.tcl-lang.org/man/tcl/tutorial/tcltutorial.html)
- **TclOO Documentation**: [https://www.tcl-lang.org/man/tcl/TclCmd/class.html](https://www.tcl-lang.org/man/tcl/TclCmd/class.html)
- **Tcl Style Guide**: [https://wiki.tcl-lang.org/page/Tcl+Style+Guide](https://wiki.tcl-lang.org/page/Tcl+Style+Guide)

---

*This tutorial covers TCL 8.6+. Some features (like TclOO, coroutines, try/throw) require Tcl 8.6 or later.*
