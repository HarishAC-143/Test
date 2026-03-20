# Comprehensive TCL Programming Tutorial

A complete guide to learning **Tcl (Tool Command Language)** — from fundamentals to advanced techniques — with runnable example scripts and practical projects.

## Table of Contents

- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Part 1 — Basics](#part-1--basics)
  - [Hello World](#1-hello-world)
  - [Variables and Data Types](#2-variables-and-data-types)
  - [String Operations](#3-string-operations)
  - [Lists](#4-lists)
  - [Dictionaries](#5-dictionaries)
  - [Arrays](#6-arrays)
  - [Control Flow](#7-control-flow)
  - [Loops](#8-loops)
  - [Procedures (Functions)](#9-procedures-functions)
  - [Math and Expressions](#10-math-and-expressions)
- [Part 2 — Intermediate](#part-2--intermediate)
  - [File I/O](#11-file-io)
  - [Regular Expressions](#12-regular-expressions)
  - [Error Handling](#13-error-handling)
  - [String Formatting](#14-string-formatting)
  - [Command Substitution and Quoting](#15-command-substitution-and-quoting)
- [Part 3 — Advanced](#part-3--advanced)
  - [Namespaces](#16-namespaces)
  - [Object-Oriented Programming (TclOO)](#17-object-oriented-programming-tcloo)
  - [Event-Driven Programming](#18-event-driven-programming)
  - [Interprocess Communication](#19-interprocess-communication)
  - [Metaprogramming](#20-metaprogramming)
  - [Coroutines](#21-coroutines)
- [Part 4 — Practical Examples](#part-4--practical-examples)
- [Running the Examples](#running-the-examples)
- [Resources](#resources)

---

## Introduction

Tcl (Tool Command Language) is a dynamic, interpreted scripting language created by John Ousterhout in 1988. It is known for its simplicity, extensibility, and the "everything is a string" philosophy. Tcl is widely used in:

- **EDA/VLSI tools** (Synopsys, Cadence, Mentor)
- **Network testing** (Cisco IOS, Ixia, Spirent)
- **Embedded systems** and rapid prototyping
- **GUI development** via the Tk toolkit
- **Automated testing** frameworks

### Core Philosophy

Tcl has a remarkably simple syntax built on a single rule: **everything is a command**. A Tcl script is a sequence of commands separated by newlines or semicolons. Each command consists of words separated by whitespace, where the first word is the command name and the rest are arguments.

```
commandName arg1 arg2 arg3 ...
```

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Everything is a string** | All values — numbers, lists, even code blocks — are represented as strings |
| **Substitution rules** | `$var` for variable substitution, `[cmd]` for command substitution, `\n` for backslash substitution |
| **Braces vs Quotes** | `{...}` prevents substitution (like single quotes in bash); `"..."` allows substitution |
| **Dynamic typing** | Variables have no declared type; interpretation depends on context |
| **Extensible** | Easy to add new commands in C or Tcl itself |

---

## Getting Started

### Installation

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install tcl
```

**macOS:**
```bash
brew install tcl-tk
```

**Windows:**
Download ActiveTcl from [activestate.com](https://www.activestate.com/products/tcl/) or install Magicsplat Tcl/Tk.

### Running Tcl

**Interactive shell:**
```bash
tclsh
```

**Run a script:**
```bash
tclsh script.tcl
```

**Run the examples in this repo:**
```bash
tclsh examples/01_hello_world.tcl
```

---

## Part 1 — Basics

### 1. Hello World

The simplest Tcl program:

```tcl
puts "Hello, World!"
```

`puts` writes a string to standard output followed by a newline. That's it — no boilerplate, no imports, no main function.

```tcl
# Comments start with #
# puts writes to stdout; you can also write to stderr:
puts stderr "This goes to standard error"

# Print without a trailing newline using -nonewline:
puts -nonewline "Enter your name: "
flush stdout
```

> **See:** [`examples/01_hello_world.tcl`](examples/01_hello_world.tcl)

---

### 2. Variables and Data Types

Use `set` to create and assign variables. Access a variable's value with `$`:

```tcl
# Setting variables
set name "Alice"
set age 30
set pi 3.14159

# Accessing variables
puts "Name: $name"
puts "Age: $age"
puts "Pi: $pi"

# Variable substitution inside double quotes
puts "In 5 years, $name will be [expr {$age + 5}]"

# Braces prevent substitution
puts {This literal $name is not substituted}

# Unsetting a variable
unset age
```

Tcl has no explicit type declarations. A value is interpreted as a number, list, or string depending on the operation:

```tcl
set x "42"
# x is a string containing "42"

expr {$x + 8}
# Now Tcl interprets x as an integer → 50

string length $x
# Now Tcl treats x as a string → 2
```

> **See:** [`examples/02_variables.tcl`](examples/02_variables.tcl)

---

### 3. String Operations

Tcl has rich string manipulation commands:

```tcl
set str "Hello, Tcl World!"

# Length
puts "Length: [string length $str]"              ;# 17

# Indexing (0-based)
puts "First char: [string index $str 0]"         ;# H
puts "Last char: [string index $str end]"        ;# !

# Substring (range is inclusive)
puts "Substring: [string range $str 7 9]"        ;# Tcl

# Case conversion
puts "Upper: [string toupper $str]"
puts "Lower: [string tolower $str]"
puts "Title: [string totitle $str]"

# Searching
puts "Find 'Tcl': [string first "Tcl" $str]"    ;# 7
puts "Find last 'l': [string last "l" $str]"     ;# 15

# Comparison
string equal "abc" "abc"                          ;# 1 (true)
string compare "abc" "def"                        ;# -1 (abc < def)

# Pattern matching (glob-style)
string match "Hello*" $str                        ;# 1

# Trimming
string trim "  hello  "                           ;# "hello"
string trimleft "xxhello" "x"                     ;# "hello"

# Replacing
string replace $str 7 9 "Tcl/Tk"                 ;# "Hello, Tcl/Tk World!"

# Mapping (character-level replace)
string map {o 0 l 1} "hello world"               ;# "he110 w0r1d"

# Repeating
string repeat "ab" 3                              ;# "ababab"

# Reversing
string reverse "hello"                            ;# "olleh"
```

> **See:** [`examples/03_strings.tcl`](examples/03_strings.tcl)

---

### 4. Lists

Lists are fundamental in Tcl. A list is a string with elements separated by whitespace:

```tcl
# Creating lists
set fruits {apple banana cherry}
set nums [list 1 2 3 4 5]
set mixed [list "hello world" 42 {nested list}]

# Accessing elements (0-based)
puts [lindex $fruits 0]        ;# apple
puts [lindex $fruits end]      ;# cherry

# Length
puts [llength $fruits]         ;# 3

# Appending
lappend fruits "date" "elderberry"
puts $fruits                   ;# apple banana cherry date elderberry

# Inserting
set fruits [linsert $fruits 2 "blueberry"]

# Replacing
set fruits [lreplace $fruits 1 1 "blackberry"]

# Searching
puts [lsearch $fruits "cherry"]  ;# index or -1

# Sorting
set sorted [lsort $fruits]
set reverse_sorted [lsort -decreasing $fruits]
set num_sorted [lsort -integer {10 2 30 4}]  ;# 2 4 10 30

# Iterating
foreach fruit $fruits {
    puts "Fruit: $fruit"
}

# Iterating with index
foreach {idx fruit} [lmap i [lrepeat [llength $fruits] 0] f $fruits {list $f}] {
    # ...
}

# List joining and splitting
set csv [join $fruits ","]     ;# "apple,blackberry,blueberry,..."
set parts [split "a:b:c" ":"] ;# {a b c}

# Filtering with lsearch -all -inline
set long_names [lsearch -all -inline $fruits "?????*"]

# Mapping (Tcl 8.6+)
set upper_fruits [lmap f $fruits {string toupper $f}]

# Range (Tcl 8.6+)
set sub [lrange $fruits 1 3]
```

> **See:** [`examples/04_lists.tcl`](examples/04_lists.tcl)

---

### 5. Dictionaries

Dictionaries (Tcl 8.5+) are key-value data structures:

```tcl
# Creating a dict
set person [dict create name "Alice" age 30 city "Portland"]

# Accessing values
puts [dict get $person name]      ;# Alice

# Setting values
dict set person email "alice@example.com"

# Checking existence
dict exists $person phone         ;# 0 (false)

# Removing keys
dict unset person city

# Size
dict size $person                 ;# 3

# Keys and values
dict keys $person                 ;# name age email
dict values $person               ;# Alice 30 alice@example.com

# Iterating
dict for {key value} $person {
    puts "$key => $value"
}

# Nested dictionaries
set company [dict create \
    name "Acme Corp" \
    ceo [dict create name "Bob" age 50] \
    employees 100 \
]
puts [dict get $company ceo name]  ;# Bob

# Filtering
set filtered [dict filter $person key "a*"]

# Merging
set defaults [dict create color "red" size "medium"]
set overrides [dict create size "large"]
set config [dict merge $defaults $overrides]
```

> **See:** [`examples/05_dictionaries.tcl`](examples/05_dictionaries.tcl)

---

### 6. Arrays

Arrays in Tcl are **not** lists — they are associative hash tables (similar to dictionaries but with different semantics):

```tcl
# Setting array elements
set config(host) "localhost"
set config(port) 8080
set config(debug) true

# Accessing elements
puts $config(host)                ;# localhost
puts $config(port)                ;# 8080

# Array existence checks
array exists config               ;# 1
info exists config(host)          ;# 1
info exists config(missing)       ;# 0

# Getting all names and values
array names config                ;# host port debug (order not guaranteed)
array get config                  ;# flat key-value list
array size config                 ;# 3

# Iterating over an array
foreach {key value} [array get config] {
    puts "$key = $value"
}

# Or using array search
set search [array startsearch config]
while {[array anymore config $search]} {
    set key [array nextelement config $search]
    puts "$key -> $config($key)"
}
array donesearch config $search

# Unsetting elements
array unset config debug

# Converting between arrays and lists
array set colors {red #FF0000 green #00FF00 blue #0000FF}
set color_list [array get colors]
```

> **See:** [`examples/06_arrays.tcl`](examples/06_arrays.tcl)

---

### 7. Control Flow

```tcl
# if / elseif / else
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

# switch
set day "Monday"
switch $day {
    Monday  { puts "Start of work week" }
    Friday  { puts "TGIF!" }
    Saturday -
    Sunday  { puts "Weekend!" }
    default { puts "Midweek" }
}

# switch with -regexp matching
set input "error: file not found"
switch -regexp $input {
    {^error:}   { puts "Error detected" }
    {^warning:} { puts "Warning detected" }
    {^info:}    { puts "Info message" }
    default     { puts "Unknown message type" }
}

# Ternary-style expression
set status [expr {$score >= 60 ? "pass" : "fail"}]
```

> **See:** [`examples/07_control_flow.tcl`](examples/07_control_flow.tcl)

---

### 8. Loops

```tcl
# while loop
set i 0
while {$i < 5} {
    puts "i = $i"
    incr i
}

# for loop (C-style)
for {set i 0} {$i < 5} {incr i} {
    puts "i = $i"
}

# foreach — iterate over a list
foreach color {red green blue} {
    puts "Color: $color"
}

# foreach — multiple variables
foreach {key value} {name Alice age 30 city Portland} {
    puts "$key: $value"
}

# foreach — multiple lists simultaneously
foreach x {1 2 3} y {a b c} {
    puts "$x -> $y"
}

# break and continue
for {set i 0} {$i < 10} {incr i} {
    if {$i == 3} continue
    if {$i == 7} break
    puts "i = $i"
}
# Output: 0 1 2 4 5 6
```

> **See:** [`examples/08_loops.tcl`](examples/08_loops.tcl)

---

### 9. Procedures (Functions)

```tcl
# Basic procedure
proc greet {name} {
    puts "Hello, $name!"
}
greet "Alice"

# Procedure with return value
proc add {a b} {
    return [expr {$a + $b}]
}
puts [add 3 4]  ;# 7

# Default arguments
proc connect {host {port 80} {protocol "http"}} {
    puts "Connecting to $protocol://$host:$port"
}
connect "example.com"
connect "example.com" 443 "https"

# Variable number of arguments
proc sum {args} {
    set total 0
    foreach n $args {
        set total [expr {$total + $n}]
    }
    return $total
}
puts [sum 1 2 3 4 5]  ;# 15

# Accessing global variables
set counter 0
proc increment {} {
    global counter
    incr counter
}

# Using upvar to modify caller's variables
proc double_var {varName} {
    upvar 1 $varName var
    set var [expr {$var * 2}]
}
set x 5
double_var x
puts $x  ;# 10

# Recursive procedure
proc factorial {n} {
    if {$n <= 1} {return 1}
    return [expr {$n * [factorial [expr {$n - 1}]]}]
}
puts [factorial 10]  ;# 3628800
```

> **See:** [`examples/09_procedures.tcl`](examples/09_procedures.tcl)

---

### 10. Math and Expressions

All math in Tcl goes through the `expr` command:

```tcl
# Arithmetic operators
expr {10 + 3}    ;# 13
expr {10 - 3}    ;# 7
expr {10 * 3}    ;# 30
expr {10 / 3}    ;# 3 (integer division)
expr {10.0 / 3}  ;# 3.3333333333333335
expr {10 % 3}    ;# 1 (modulo)
expr {2 ** 10}   ;# 1024 (exponentiation)

# Comparison operators
expr {5 == 5}    ;# 1 (true)
expr {5 != 3}    ;# 1
expr {5 > 3}     ;# 1
expr {5 <= 3}    ;# 0

# Logical operators
expr {1 && 0}    ;# 0
expr {1 || 0}    ;# 1
expr {!0}        ;# 1

# Math functions
expr {abs(-42)}       ;# 42
expr {sqrt(144)}      ;# 12.0
expr {pow(2, 10)}     ;# 1024.0
expr {round(3.7)}     ;# 4
expr {int(3.9)}       ;# 3
expr {ceil(3.2)}      ;# 4.0
expr {floor(3.9)}     ;# 3.0
expr {log(100)}       ;# 4.605... (natural log)
expr {log10(100)}     ;# 2.0
expr {sin(3.14159)}   ;# ~0.0
expr {rand()}         ;# random float [0, 1)
expr {int(rand()*100)} ;# random int [0, 99]

# Important: always brace expressions for performance and safety
# GOOD:
expr {$x + $y}
# BAD (vulnerable to code injection, slower):
expr "$x + $y"
```

> **See:** [`examples/10_math.tcl`](examples/10_math.tcl)

---

## Part 2 — Intermediate

### 11. File I/O

```tcl
# Writing to a file
set fd [open "output.txt" w]
puts $fd "Line 1"
puts $fd "Line 2"
puts $fd "Line 3"
close $fd

# Reading an entire file
set fd [open "output.txt" r]
set contents [read $fd]
close $fd
puts $contents

# Reading line by line
set fd [open "output.txt" r]
while {[gets $fd line] >= 0} {
    puts "Read: $line"
}
close $fd

# Appending to a file
set fd [open "output.txt" a]
puts $fd "Line 4 (appended)"
close $fd

# File information
file exists "output.txt"        ;# 1
file size "output.txt"          ;# size in bytes
file extension "script.tcl"     ;# .tcl
file tail "/path/to/file.txt"   ;# file.txt
file dirname "/path/to/file.txt" ;# /path/to
file join "/path" "to" "file"   ;# /path/to/file
file readable "output.txt"      ;# 1

# Directory operations
file mkdir "new_directory"
set files [glob -nocomplain *.tcl]
foreach f $files {
    puts "Found: $f"
}

# Temporary file
set tmpfile [file tempfile tmpfd ".txt"]
puts $tmpfd "temporary data"
close $tmpfd
```

> **See:** [`examples/11_file_io.tcl`](examples/11_file_io.tcl)

---

### 12. Regular Expressions

```tcl
# Basic matching
set str "The year is 2026"
regexp {(\d{4})} $str match year
puts "Year: $year"  ;# 2026

# Case-insensitive matching
regexp -nocase {hello} "Hello World"  ;# 1

# Match all occurrences
set str "cat bat hat mat"
set matches [regexp -all -inline {[a-z]at} $str]
puts $matches  ;# cat bat hat mat

# Capture groups
set date "2026-03-20"
regexp {(\d{4})-(\d{2})-(\d{2})} $date \
    full_match year month day
puts "Year=$year Month=$month Day=$day"

# Substitution with regsub
set result [regsub -all {[aeiou]} "hello world" "*"]
puts $result  ;# h*ll* w*rld

# Named patterns and complex regex
set email "user@example.com"
if {[regexp {^([^@]+)@([^@]+\.[^@]+)$} $email match user domain]} {
    puts "User: $user, Domain: $domain"
}

# Using -indices to get match positions
regexp -indices {world} "hello world" match_pos
puts $match_pos  ;# 6 10
```

> **See:** [`examples/12_regex.tcl`](examples/12_regex.tcl)

---

### 13. Error Handling

```tcl
# try / on / finally (Tcl 8.6+)
try {
    set result [expr {10 / 0}]
} on error {msg opts} {
    puts "Error: $msg"
    # opts contains error code, stack trace, etc.
} finally {
    puts "Cleanup runs regardless"
}

# catch — older but still widely used
if {[catch {expr {10 / 0}} result opts]} {
    puts "Caught error: $result"
    puts "Error code: [dict get $opts -errorcode]"
} else {
    puts "Result: $result"
}

# Throwing errors
proc divide {a b} {
    if {$b == 0} {
        error "Division by zero" "" {ARITH DIVZERO}
    }
    return [expr {$a / $b}]
}

# throw (Tcl 8.6+)
proc validate_age {age} {
    if {![string is integer -strict $age]} {
        throw {VALIDATION TYPE} "Age must be an integer"
    }
    if {$age < 0 || $age > 150} {
        throw {VALIDATION RANGE} "Age must be between 0 and 150"
    }
    return $age
}

# Handling specific error codes
try {
    validate_age "abc"
} trap {VALIDATION TYPE} {msg} {
    puts "Type error: $msg"
} trap {VALIDATION RANGE} {msg} {
    puts "Range error: $msg"
}

# Getting the stack trace
catch {expr {1/0}} result opts
puts [dict get $opts -errorinfo]
```

> **See:** [`examples/13_error_handling.tcl`](examples/13_error_handling.tcl)

---

### 14. String Formatting

```tcl
# format — similar to C's sprintf
set name "Alice"
set age 30
set gpa 3.95

puts [format "Name: %-10s Age: %3d GPA: %.2f" $name $age $gpa]
# Output: Name: Alice      Age:  30 GPA: 3.95

# Common format specifiers:
#   %s  — string
#   %d  — integer
#   %f  — floating point
#   %e  — scientific notation
#   %x  — hexadecimal
#   %o  — octal
#   %b  — binary (Tcl 8.6+)
#   %c  — character from code point
#   %%  — literal percent sign

# Width and alignment
format "|%-20s|" "left"    ;# |left                |
format "|%20s|" "right"    ;# |               right|
format "|%020d|" 42        ;# |00000000000000000042|

# scan — the reverse of format (parsing)
set input "Alice 30 3.95"
scan $input "%s %d %f" name age gpa
puts "$name is $age with GPA $gpa"

# Parsing hex
scan "FF" "%x" decimal
puts $decimal  ;# 255

# subst — perform substitutions in a string
set template {Hello $name, you are $age years old}
set name "Bob"
set age 25
puts [subst $template]  ;# Hello Bob, you are 25 years old
```

> **See:** [`examples/14_string_formatting.tcl`](examples/14_string_formatting.tcl)

---

### 15. Command Substitution and Quoting

Understanding Tcl's substitution rules is critical:

```tcl
set x 10

# Double quotes: variable and command substitution happen
puts "x is $x"             ;# x is 10
puts "sum is [expr {$x+5}]" ;# sum is 15

# Braces: NO substitution (literal string)
puts {x is $x}             ;# x is $x
puts {sum is [expr {$x+5}]} ;# sum is [expr {$x+5}]

# Backslash substitution
puts "Line1\nLine2"        ;# two lines
puts "Tab\there"           ;# tab character
puts "A backslash: \\"     ;# A backslash: \

# Combining substitution types
set cmd "puts"
set msg "hello"
$cmd $msg                  ;# prints "hello" — the variable value IS the command

# eval — evaluate a string as a Tcl script
set script {puts "Evaluated!"}
eval $script

# {*} — expansion operator (Tcl 8.5+)
set args {1 2 3}
proc sum3 {a b c} { expr {$a+$b+$c} }
sum3 {*}$args              ;# equivalent to: sum3 1 2 3

# uplevel — execute code in caller's scope
proc debug_print {code} {
    puts "About to execute: $code"
    uplevel 1 $code
}
debug_print {set y 42}
puts $y  ;# 42
```

> **See:** [`examples/15_quoting.tcl`](examples/15_quoting.tcl)

---

## Part 3 — Advanced

### 16. Namespaces

Namespaces prevent name collisions and organize code into modules:

```tcl
# Defining a namespace
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

# Using namespace commands
puts [math::circle_area 5]          ;# 78.5398...
puts [math::circle_circumference 5] ;# 31.4159...
puts $math::pi                       ;# 3.14159...

# Nested namespaces
namespace eval app::db {
    proc connect {host} {
        puts "Connecting to $host"
    }
}
app::db::connect "localhost"

# Importing commands
namespace eval myapp {
    namespace import ::math::circle_area
    puts [circle_area 10]  ;# no prefix needed
}

# Exporting commands from a namespace
namespace eval utils {
    namespace export log warn error_msg
    proc log {msg} { puts "LOG: $msg" }
    proc warn {msg} { puts "WARN: $msg" }
    proc error_msg {msg} { puts "ERROR: $msg" }
    proc internal_helper {} { puts "not exported" }
}

# Ensemble commands — object-like syntax
namespace eval counter {
    variable count 0
    namespace export incr decr get reset
    namespace ensemble create

    proc incr {} {
        variable count
        ::incr count
    }
    proc decr {} {
        variable count
        ::incr count -1
    }
    proc get {} {
        variable count
        return $count
    }
    proc reset {} {
        variable count
        set count 0
    }
}

counter incr
counter incr
counter incr
puts [counter get]  ;# 3
counter reset
```

> **See:** [`examples/16_namespaces.tcl`](examples/16_namespaces.tcl)

---

### 17. Object-Oriented Programming (TclOO)

Tcl 8.6 introduced a built-in object system:

```tcl
package require TclOO

# Defining a class
oo::class create Animal {
    variable name species sound

    constructor {n s {snd ""}} {
        set name $n
        set species $s
        set sound $snd
    }

    method speak {} {
        if {$sound ne ""} {
            puts "$name says $sound!"
        } else {
            puts "$name is silent."
        }
    }

    method describe {} {
        puts "$name is a $species"
    }

    method get_name {} {
        return $name
    }
}

# Creating objects
set dog [Animal new "Rex" "Dog" "Woof"]
set cat [Animal new "Whiskers" "Cat" "Meow"]

$dog speak     ;# Rex says Woof!
$cat describe  ;# Whiskers is a Cat

# Inheritance
oo::class create Pet {
    superclass Animal
    variable owner

    constructor {name species sound owner_name} {
        next $name $species $sound
        set owner $owner_name
    }

    method owner_info {} {
        puts "[my get_name] belongs to $owner"
    }
}

set pet [Pet new "Buddy" "Dog" "Woof" "Alice"]
$pet speak        ;# Buddy says Woof!
$pet owner_info   ;# Buddy belongs to Alice

# Mixins — reusable behavior
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

oo::class create Point {
    variable x y
    constructor {px py} {
        set x $px
        set y $py
    }
    method coords {} { return [list $x $y] }
}

oo::define Point mixin Serializable
set p [Point new 3 4]
puts [$p to_string]  ;# x=3, y=4

# Destroying objects
$dog destroy
```

> **See:** [`examples/17_oop.tcl`](examples/17_oop.tcl)

---

### 18. Event-Driven Programming

Tcl has a built-in event loop supporting timers, file events, and idle callbacks:

```tcl
# After — schedule code to run after a delay (milliseconds)
proc tick {count} {
    puts "Tick $count at [clock format [clock seconds] -format %H:%M:%S]"
    if {$count < 5} {
        after 1000 [list tick [expr {$count + 1}]]
    } else {
        set ::done 1
    }
}

# Start the timer
after 0 [list tick 1]

# File events — react to readable/writable channels
# (commonly used for socket programming)

# Variable traces — react to variable changes
proc on_change {name1 name2 op} {
    upvar 1 $name1 var
    puts "Variable '$name1' was $op, new value: $var"
}
trace add variable myvar write on_change
set myvar 10   ;# triggers: Variable 'myvar' was write, new value: 10
set myvar 20   ;# triggers: Variable 'myvar' was write, new value: 20

# Command traces — react when commands are invoked
trace add execution puts enter {apply {{cmd op} {
    puts stderr "TRACE: puts called with: $cmd"
}}}
```

> **See:** [`examples/18_events.tcl`](examples/18_events.tcl)

---

### 19. Interprocess Communication

```tcl
# Running external commands
set result [exec ls -la]
puts $result

# Capturing command output
set date [exec date]
puts "Current date: $date"

# Piping commands
set count [exec cat /etc/passwd | wc -l]
puts "Users: $count"

# Running commands with error handling
if {[catch {exec grep "pattern" somefile.txt} result]} {
    puts "grep failed or no match: $result"
}

# Open a pipe for reading
set fd [open "|ls -1" r]
while {[gets $fd line] >= 0} {
    puts "File: $line"
}
close $fd

# Open a pipe for writing
set fd [open "|sort > sorted.txt" w]
puts $fd "banana"
puts $fd "apple"
puts $fd "cherry"
close $fd

# Two-way pipe
set fd [open "|cat -n" r+]
puts $fd "hello"
puts $fd "world"
flush $fd
close $fd write  ;# close write side
set result [read $fd]
close $fd
puts $result

# Socket server (TCP)
proc accept {chan addr port} {
    puts "Connection from $addr:$port"
    puts $chan "Hello from Tcl server!"
    close $chan
}
# socket -server accept 9000
# vwait forever

# Socket client
# set sock [socket localhost 9000]
# gets $sock line
# puts "Server said: $line"
# close $sock
```

> **See:** [`examples/19_ipc.tcl`](examples/19_ipc.tcl)

---

### 20. Metaprogramming

Tcl's flexibility makes metaprogramming natural:

```tcl
# info command — introspection
info commands puts       ;# check if command exists
info procs               ;# list all procs
info body greet          ;# get proc body
info args greet          ;# get proc arguments
info globals             ;# list global variables
info locals              ;# list local variables
info level               ;# call stack depth

# Dynamic command creation
proc make_greeter {language greeting} {
    proc greet_$language {name} [format {
        puts "%s, $name!"
    } $greeting]
}
make_greeter english "Hello"
make_greeter french "Bonjour"
make_greeter spanish "Hola"
greet_english "Alice"    ;# Hello, Alice!
greet_french "Bob"       ;# Bonjour, Bob!

# apply — anonymous procedures (lambdas)
set square [list {x} {expr {$x * $x}}]
puts [apply $square 5]   ;# 25

set adder [list {a b} {expr {$a + $b}}]
puts [apply $adder 3 4]  ;# 7

# Higher-order functions
proc map {func list} {
    set result {}
    foreach item $list {
        lappend result [apply $func $item]
    }
    return $result
}
puts [map {x {expr {$x * $x}}} {1 2 3 4 5}]  ;# 1 4 9 16 25

proc filter {func list} {
    set result {}
    foreach item $list {
        if {[apply $func $item]} {
            lappend result $item
        }
    }
    return $result
}
puts [filter {x {expr {$x > 3}}} {1 2 3 4 5}]  ;# 4 5

# unknown command handler — method_missing equivalent
proc unknown {cmd args} {
    puts "Unknown command '$cmd' called with args: $args"
    puts "Did you mean one of: [info commands ${cmd}*]"
}

# rename — intercept/wrap existing commands
rename puts original_puts
proc puts {args} {
    set timestamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    original_puts "\[$timestamp\] [join $args]"
}
# Restore original
rename puts {}
rename original_puts puts
```

> **See:** [`examples/20_metaprogramming.tcl`](examples/20_metaprogramming.tcl)

---

### 21. Coroutines

Tcl 8.6 introduced coroutines for cooperative multitasking:

```tcl
# Basic coroutine
proc counter {} {
    set i 0
    while 1 {
        yield $i
        incr i
    }
}

coroutine myCounter counter
puts [myCounter]  ;# 0
puts [myCounter]  ;# 1
puts [myCounter]  ;# 2

# Generator pattern — Fibonacci sequence
proc fibonacci {} {
    set a 0
    set b 1
    while 1 {
        yield $a
        lassign [list $b [expr {$a + $b}]] a b
    }
}

coroutine fib fibonacci
for {set i 0} {$i < 10} {incr i} {
    puts -nonewline "[fib] "
}
# 0 1 1 2 3 5 8 13 21 34

# Producer-consumer pattern
proc producer {consumer} {
    for {set i 1} {$i <= 5} {incr i} {
        puts "Producing: $i"
        $consumer $i
    }
    $consumer done
}

proc consumer {} {
    while 1 {
        set item [yield]
        if {$item eq "done"} break
        puts "Consuming: $item"
    }
    puts "Consumer finished"
}

coroutine myConsumer consumer
producer myConsumer
```

> **See:** [`examples/21_coroutines.tcl`](examples/21_coroutines.tcl)

---

## Part 4 — Practical Examples

The `practical/` directory contains complete, real-world-style Tcl programs:

| Script | Description |
|--------|-------------|
| [`practical/log_analyzer.tcl`](practical/log_analyzer.tcl) | Parse and analyze log files — count errors, extract patterns, generate reports |
| [`practical/config_manager.tcl`](practical/config_manager.tcl) | INI-style configuration file reader/writer with sections and key-value pairs |
| [`practical/calculator.tcl`](practical/calculator.tcl) | Interactive command-line calculator with history and variables |
| [`practical/test_framework.tcl`](practical/test_framework.tcl) | Minimal unit test framework with assertions, setup/teardown, and reporting |
| [`practical/csv_processor.tcl`](practical/csv_processor.tcl) | CSV file parser, transformer, and writer with filtering and aggregation |
| [`practical/task_manager.tcl`](practical/task_manager.tcl) | Command-line to-do/task manager with persistence |

---

## Running the Examples

All example scripts are self-contained and can be run individually:

```bash
# Basics
tclsh examples/01_hello_world.tcl
tclsh examples/02_variables.tcl
# ...

# Practical examples
tclsh practical/log_analyzer.tcl
tclsh practical/calculator.tcl
tclsh practical/test_framework.tcl
```

---

## Resources

- [Official Tcl Documentation](https://www.tcl.tk/doc/)
- [Tcl Wiki](https://wiki.tcl-lang.org/)
- [Tcl Tutorial (tcl.tk)](https://www.tcl.tk/man/tcl8.6/tutorial/tcltutorial.html)
- [TclOO Documentation](https://www.tcl.tk/man/tcl8.6/TclCmd/class.htm)
- [Tcler's Wiki — Book List](https://wiki.tcl-lang.org/page/Book+list)

---

*This tutorial is a living document. Contributions and improvements are welcome!*
