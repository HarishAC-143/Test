# 2. Variables & Data Types

## Everything is a String

Tcl's fundamental rule: **every value is a string**. Numbers, booleans, lists — they are all represented as strings and converted to internal types only when needed. This is called **dual-porting**: a value has both a string representation and a cached internal representation.

```tcl
set x 42          ;# The string "42" — also an integer
set y 3.14        ;# The string "3.14" — also a float
set z true        ;# The string "true" — also a boolean
set w {a b c}     ;# The string "a b c" — also a list
```

## Setting and Reading Variables

```tcl
# set variableName ?value?
set name "Grace Hopper"    ;# Create/assign variable
set name                   ;# Read variable — returns "Grace Hopper"
puts $name                 ;# Use variable with $ prefix
```

### Variable Name Delimiters

When `$name` is ambiguous, use `${name}` braces:

```tcl
set item "apple"
set count 5
puts "${count}_${item}s"   ;# → 5_apples
puts "$count$item"          ;# → 5apple
```

## Unsetting Variables

```tcl
set temp "temporary"
unset temp                  ;# Variable no longer exists
unset -nocomplain temp      ;# No error if variable doesn't exist
```

## Checking Variable Existence

```tcl
set x 10

if {[info exists x]} {
    puts "x exists and equals $x"
}

if {![info exists y]} {
    puts "y does not exist"
}
```

## Numeric Types

Although everything is a string, Tcl distinguishes numeric types inside `expr`:

```tcl
# Integers (arbitrary precision)
set a 42
set b 0xFF          ;# Hexadecimal → 255
set c 0o77          ;# Octal → 63
set d 0b1010        ;# Binary → 10
set big 99999999999999999999999  ;# Arbitrary precision

# Floating point (IEEE 754 double)
set pi 3.14159265358979
set sci 6.022e23    ;# Scientific notation
set inf Inf         ;# Infinity
set nan NaN         ;# Not a Number

# Integer arithmetic stays exact
expr {10 / 3}       ;# → 3
expr {10 % 3}       ;# → 1

# Force floating-point with a decimal point
expr {10.0 / 3}     ;# → 3.3333333333333335
expr {double(10) / 3}  ;# Same result
```

## Booleans

Tcl accepts several boolean representations:

```tcl
# True values:  1, true, yes, on
# False values: 0, false, no, off

set flag true
if {$flag} {
    puts "flag is true"
}

# Convert explicitly
set b [string is true -strict "yes"]   ;# → 1
set b [string is false -strict "off"]  ;# → 1
```

## Type Checking with `string is`

```tcl
string is integer -strict "42"      ;# → 1
string is integer -strict "hello"   ;# → 0
string is double -strict "3.14"     ;# → 1
string is boolean -strict "yes"     ;# → 1
string is alpha -strict "hello"     ;# → 1
string is digit -strict "12345"     ;# → 1
string is space -strict "  \t\n"    ;# → 1
string is list "a b {c d}"         ;# → 1
```

## Variable Introspection

```tcl
set greeting "hello"
set numbers {1 2 3}

# Get all variable names in current scope
puts [info vars]

# Get all global variables matching a pattern
puts [info globals *path*]

# Check the type of internal representation (for debugging)
# Note: this is implementation-dependent
```

## The `append` Command

Efficiently concatenate strings onto a variable:

```tcl
set result ""
append result "Hello"
append result ", "
append result "World!"
puts $result   ;# → Hello, World!

# append is more efficient than: set result "$result more text"
```

## The `incr` Command

Increment integer variables:

```tcl
set counter 0
incr counter        ;# counter = 1
incr counter 5      ;# counter = 6
incr counter -2     ;# counter = 4

# incr creates the variable if it doesn't exist (starting from 0)
incr new_var        ;# new_var = 1
```

## Variable Traces

Traces let you watch for variable reads, writes, and deletions:

```tcl
proc on_write {name1 name2 op} {
    upvar 1 $name1 var
    puts "Variable '$name1' was $op, new value: $var"
}

set x 10
trace add variable x write on_write

set x 20    ;# Prints: Variable 'x' was write, new value: 20
set x 30    ;# Prints: Variable 'x' was write, new value: 30

# Remove the trace
trace remove variable x write on_write
```

### Trace for Read-Only Variables

```tcl
proc readonly {name1 name2 op} {
    error "Variable '$name1' is read-only"
}

set PI 3.14159265358979
trace add variable PI write readonly

# set PI 3.0  ;# ERROR: Variable 'PI' is read-only
```

## Environment Variables

Access system environment variables through the global `env` array:

```tcl
# Read environment variables
puts $::env(HOME)
puts $::env(PATH)

# Check if environment variable exists
if {[info exists ::env(EDITOR)]} {
    puts "Editor: $::env(EDITOR)"
}

# Set an environment variable (affects child processes)
set ::env(MY_VAR) "my_value"
```

## Summary

| Operation | Command | Example |
|-----------|---------|---------|
| Assign | `set var value` | `set x 42` |
| Read | `$var` or `set var` | `puts $x` |
| Delete | `unset var` | `unset x` |
| Exists? | `info exists var` | `if {[info exists x]} ...` |
| Append | `append var text` | `append s "more"` |
| Increment | `incr var ?amount?` | `incr count` |
| Trace | `trace add variable ...` | See examples above |

---

**Previous:** [Introduction & Basic Syntax](01-introduction-and-syntax.md) | **Next:** [Operators & Expressions](03-operators-and-expressions.md)
