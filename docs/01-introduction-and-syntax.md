# 1. Introduction & Basic Syntax

## What is Tcl?

Tcl (Tool Command Language, pronounced "tickle") was created by John Ousterhout in 1988 at UC Berkeley. It follows a radically simple philosophy: **everything is a command**, and **every value is a string**. This simplicity makes Tcl remarkably consistent and easy to learn.

## The Tcl Evaluation Model

Tcl processes scripts in two steps:

1. **Parsing** — the interpreter breaks each line into words (command name + arguments)
2. **Execution** — the first word is treated as a command, the rest are its arguments

```tcl
# command  arg1    arg2
puts       "Hello" 
expr       {2 + 3}
set        name    "Alice"
```

Every Tcl command follows this pattern. There are no special syntactic forms — `if`, `while`, and `for` are all regular commands.

## Comments

Comments begin with `#` and extend to the end of the line. A `#` only starts a comment where a command could begin:

```tcl
# This is a full-line comment

set x 10  ;# Semicolon terminates the command, then comment follows

# WRONG — this does NOT work:
# set x 10  # Not a comment — Tcl sees "#" as a third argument
```

## Quoting Rules

Tcl has three quoting mechanisms, each with distinct behavior:

### 1. No Quoting — Word Splitting

Without quotes, each whitespace-separated token is a separate argument:

```tcl
set name Alice
# "set" receives two arguments: "name" and "Alice"
```

### 2. Double Quotes — Grouping with Substitution

Double quotes group text into a single argument while allowing substitutions:

```tcl
set name "Alice"
puts "Hello, $name!"          ;# → Hello, Alice!
puts "2 + 3 = [expr {2+3}]"   ;# → 2 + 3 = 5
puts "Tab:\there"              ;# → Tab:	here
```

Substitutions inside double quotes:
- `$varName` — variable substitution
- `[command]` — command substitution (result replaces the brackets)
- `\n`, `\t`, `\\` — backslash substitution

### 3. Curly Braces — Grouping without Substitution

Braces group text but prevent all substitution (like single quotes in shell scripting):

```tcl
set name "Alice"
puts {Hello, $name!}          ;# → Hello, $name!  (literal)
puts {No [substitution] here} ;# → No [substitution] here
```

Braces are essential for:
- Passing code bodies to control structures (`if`, `while`, `proc`)
- Protecting `expr` expressions from double substitution
- Literal text with special characters

```tcl
# Braces delay evaluation — the if command evaluates the body when needed
if {$x > 5} {
    puts "x is large"
}

# Always brace expr arguments for safety and performance
expr {$x * 2 + 1}
```

## Substitution Rules

### Variable Substitution

```tcl
set fruit "apple"
puts $fruit           ;# → apple
puts ${fruit}s        ;# → apples (braces delimit the variable name)
puts "I like $fruit"  ;# → I like apple
```

### Command Substitution

Square brackets execute a command and substitute the result:

```tcl
set len [string length "hello"]   ;# len = 5
puts "Today is [clock format [clock seconds] -format %A]"
```

### Backslash Substitution

| Sequence | Meaning         |
|----------|-----------------|
| `\n`     | Newline         |
| `\t`     | Tab             |
| `\\`     | Literal `\`     |
| `\$`     | Literal `$`     |
| `\[`     | Literal `[`     |
| `\"`     | Literal `"`     |
| `\xHH`   | Hex character   |
| `\uHHHH` | Unicode character |

```tcl
puts "Line 1\nLine 2"
puts "Price: \$9.99"
puts "Brackets: \[not a command\]"
```

## Command Separators

Commands are separated by newlines or semicolons:

```tcl
set x 10
set y 20

# Equivalent using semicolons
set x 10; set y 20
```

## Line Continuation

A backslash at the very end of a line joins it with the next line:

```tcl
set long_string "This is a very \
    long string that spans \
    multiple lines"
# Result: "This is a very long string that spans multiple lines"
```

## The `puts` Command

`puts` writes to standard output (with a trailing newline by default):

```tcl
puts "Hello, World!"          ;# Print to stdout
puts -nonewline "Enter: "     ;# Print without newline
puts stderr "Error occurred"  ;# Print to stderr
```

## The `set` Command

`set` assigns and reads variables:

```tcl
set x 42         ;# Assign 42 to x, returns "42"
set x            ;# Read x, returns "42"
puts [set x]     ;# Same as puts $x
```

## The `expr` Command

`expr` evaluates mathematical and logical expressions:

```tcl
expr {2 + 3}           ;# → 5
expr {10 / 3}          ;# → 3 (integer division)
expr {10.0 / 3}        ;# → 3.3333333333333335
expr {2 ** 10}         ;# → 1024
expr {sin(3.14159)}    ;# → ~0.0
expr {$x > 0 ? "pos" : "non-pos"}
```

> **Best Practice:** Always brace `expr` arguments with `{}`. Unbraced expressions are slower (double substitution) and can be a security risk if variables contain user input.

## Summary

| Concept | Syntax | Example |
|---------|--------|---------|
| Command | `cmdName arg1 arg2 ...` | `puts "hello"` |
| Comment | `# text` | `# This is a comment` |
| Variable substitution | `$name` or `${name}` | `puts $x` |
| Command substitution | `[command]` | `set n [llength $list]` |
| Grouping with substitution | `"text"` | `"Hello $name"` |
| Grouping without substitution | `{text}` | `{$name}` |
| Line continuation | `\` at end of line | `set x \` (continues) |

---

**Next:** [Variables & Data Types](02-variables-and-data-types.md)
