# 10. Regular Expressions

Tcl provides powerful regular expression support through the `regexp` and `regsub` commands, using Henry Spencer's regex engine (which influenced many others).

## Basic Pattern Matching with `regexp`

```tcl
# Returns 1 if pattern matches, 0 otherwise
regexp {hello} "hello world"      ;# → 1
regexp {xyz} "hello world"        ;# → 0
```

## Capturing Groups

```tcl
# Capture the full match and groups
regexp {(\w+)\s+(\w+)} "hello world" full first second
puts $full    ;# → hello world
puts $first   ;# → hello
puts $second  ;# → world
```

## Regex Metacharacters

| Pattern | Matches |
|---------|---------|
| `.` | Any single character (except newline) |
| `^` | Start of string |
| `$` | End of string |
| `*` | Zero or more of previous |
| `+` | One or more of previous |
| `?` | Zero or one of previous |
| `\|` | Alternation (or) |
| `()` | Grouping and capture |
| `[]` | Character class |
| `{}` | Repetition count |

## Character Classes

```tcl
# Built-in classes
regexp {[0-9]+} "abc 123 def" match        ;# match = "123"
regexp {[a-zA-Z]+} "123 abc 456" match     ;# match = "abc"
regexp {[^0-9]+} "123abc456" match         ;# match = "abc"

# POSIX character classes
regexp {[[:alpha:]]+} "123abc" match       ;# match = "abc"
regexp {[[:digit:]]+} "abc123" match       ;# match = "123"
regexp {[[:alnum:]]+} "!@# abc123" match   ;# match = "abc123"
regexp {[[:space:]]+} "hello world" match  ;# match = " "
```

### Available POSIX Classes

| Class | Matches |
|-------|---------|
| `[:alpha:]` | Letters |
| `[:digit:]` | Digits |
| `[:alnum:]` | Letters and digits |
| `[:upper:]` | Uppercase letters |
| `[:lower:]` | Lowercase letters |
| `[:space:]` | Whitespace |
| `[:punct:]` | Punctuation |
| `[:xdigit:]` | Hex digits |

## Shorthand Classes

| Shorthand | Equivalent | Matches |
|-----------|-----------|---------|
| `\d` | `[[:digit:]]` | Digit |
| `\D` | `[^[:digit:]]` | Non-digit |
| `\w` | `[[:alnum:]_]` | Word character |
| `\W` | `[^[:alnum:]_]` | Non-word character |
| `\s` | `[[:space:]]` | Whitespace |
| `\S` | `[^[:space:]]` | Non-whitespace |

## Quantifiers

```tcl
# Greedy (match as much as possible)
regexp {a.*b} "aXXbYYb" match    ;# match = "aXXbYYb"

# Non-greedy (match as little as possible)
regexp {a.*?b} "aXXbYYb" match   ;# match = "aXXb"

# Specific repetition
regexp {\d{3}} "12345" match             ;# match = "123"
regexp {\d{2,4}} "1234567" match         ;# match = "1234"
regexp {a{2,}} "aaa" match              ;# match = "aaa" (2 or more)
```

## Anchors and Boundaries

```tcl
# Start/end of string
regexp {^hello} "hello world" match    ;# Matches
regexp {^hello} "say hello" match      ;# No match

regexp {world$} "hello world" match    ;# Matches

# Word boundaries
regexp {\mcat\M} "the cat sat" match   ;# Matches "cat"
regexp {\mcat\M} "concatenate" match   ;# No match
# \m = start of word, \M = end of word, \y = either boundary
```

## Regexp Options

```tcl
# Case-insensitive matching
regexp -nocase {hello} "HELLO World" match   ;# match = "HELLO"

# Return all matches
regexp -all -inline {\d+} "a1 b22 c333"
# → 1 22 333

# Get match indices instead of text
regexp -indices {world} "hello world" idx
# idx = {6 10}

# Line-sensitive matching (^ and $ match line boundaries)
regexp -line {^line2$} "line1\nline2\nline3" match
# match = "line2"

# Expanded syntax (whitespace and comments in pattern)
regexp -expanded {
    (\d{4})    # year
    -          # separator
    (\d{2})    # month
    -          # separator
    (\d{2})    # day
} "2026-03-20" full year month day
```

## Finding All Matches

```tcl
# Count matches
regexp -all {\d+} "a1 b22 c333"   ;# → 3

# Get all matched strings
set matches [regexp -all -inline {\d+} "a1 b22 c333"]
# → 1 22 333

# All matches with groups
set text "John:30 Jane:25 Jim:35"
set matches [regexp -all -inline {(\w+):(\d+)} $text]
# → {John:30} John 30 {Jane:25} Jane 25 {Jim:35} Jim 35
# (full match, group1, group2, repeated for each match)
```

## Substitution with `regsub`

```tcl
# Replace first match
regsub {world} "hello world" "Tcl" result
puts $result   ;# → hello Tcl

# Replace all matches
regsub -all {\d} "a1b2c3" "X" result
puts $result   ;# → aXbXcX

# Back-references in replacement
regsub {(\w+)\s+(\w+)} "hello world" {\2 \1} result
puts $result   ;# → world hello

# Using & for the full match
regsub -all {\w+} "hello world" {[&]} result
puts $result   ;# → [hello] [world]

# In-place (Tcl 8.6+ — regsub returns count, modifies variable)
set text "Hello World"
set count [regsub -all {[aeiou]} $text "*" text]
puts "$count vowels replaced: $text"
# → 3 vowels replaced: H*ll* W*rld
```

## Lookahead and Lookbehind

```tcl
# Positive lookahead: match "foo" only if followed by "bar"
regexp {foo(?=bar)} "foobar" match     ;# match = "foo"
regexp {foo(?=bar)} "foobaz" match     ;# No match

# Negative lookahead: match "foo" only if NOT followed by "bar"
regexp {foo(?!bar)} "foobaz" match     ;# match = "foo"

# Positive lookbehind: match "bar" only if preceded by "foo"
regexp {(?<=foo)bar} "foobar" match    ;# match = "bar"

# Negative lookbehind: match "bar" only if NOT preceded by "foo"
regexp {(?<!foo)bar} "xyzbar" match    ;# match = "bar"
```

## Non-Capturing Groups

```tcl
# (?:...) groups without capturing
regexp {(?:ab)+} "ababab" match   ;# match = "ababab"

# Useful to avoid cluttering capture variables
regexp {(\w+)(?:\s*=\s*)(\w+)} "key = value" full key val
puts "key=$key, val=$val"   ;# key=key, val=value
```

## Practical Example: Email Validator

```tcl
proc validate_email {email} {
    set pattern {^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$}
    return [regexp $pattern $email]
}

foreach email {"user@example.com" "bad@" "test@sub.domain.org" "no-at-sign"} {
    if {[validate_email $email]} {
        puts "VALID:   $email"
    } else {
        puts "INVALID: $email"
    }
}
```

## Practical Example: Log Parser

```tcl
proc parse_log_line {line} {
    set pattern {^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+\[(\w+)\]\s+(.*)$}

    if {[regexp $pattern $line -> date time level message]} {
        return [dict create date $date time $time level $level message $message]
    }
    return {}
}

set log_lines {
    "2026-03-20 14:30:15 [INFO] Server started on port 8080"
    "2026-03-20 14:30:16 [WARNING] Config file not found, using defaults"
    "2026-03-20 14:30:20 [ERROR] Connection refused: database unreachable"
}

foreach line $log_lines {
    set parsed [parse_log_line $line]
    if {[dict size $parsed] > 0} {
        puts "[dict get $parsed level]: [dict get $parsed message]"
    }
}
```

## Practical Example: Text Transformer

```tcl
proc camel_to_snake {text} {
    regsub -all {([A-Z])} $text {_\1} result
    return [string tolower [string trimleft $result "_"]]
}

proc snake_to_camel {text} {
    set parts [split $text "_"]
    set result [lindex $parts 0]
    foreach part [lrange $parts 1 end] {
        append result [string totitle $part]
    }
    return $result
}

puts [camel_to_snake "myVariableName"]   ;# → my_variable_name
puts [snake_to_camel "my_variable_name"] ;# → myVariableName
```

---

**Previous:** [File I/O & System Interaction](09-file-io-and-system.md) | **Next:** [Error Handling](11-error-handling.md)
