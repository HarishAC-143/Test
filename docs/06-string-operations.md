# 6. String Operations

Since everything in Tcl is a string, string operations are among the most important and frequently used commands.

## The `string` Command

The `string` command provides a comprehensive set of subcommands for string manipulation.

## String Length

```tcl
string length "Hello, World!"   ;# → 13
string length ""                ;# → 0
string length {a b c}           ;# → 5
```

## String Indexing

Tcl uses 0-based indexing. Special indices: `end`, `end-N`:

```tcl
set str "Hello, World!"

string index $str 0        ;# → H
string index $str 4        ;# → o
string index $str end       ;# → !
string index $str end-5     ;# → o
```

## Substrings with `string range`

```tcl
set str "Hello, World!"

string range $str 0 4       ;# → Hello
string range $str 7 11      ;# → World
string range $str 7 end     ;# → World!
string range $str 0 end-1   ;# → Hello, World
```

## Case Conversion

```tcl
string toupper "hello"       ;# → HELLO
string tolower "HELLO"       ;# → hello
string totitle "hello world" ;# → Hello world

# Range-limited conversion
string toupper "hello world" 0 0   ;# → Hello world
```

## String Comparison

```tcl
string compare "abc" "def"    ;# → -1 (abc < def)
string compare "def" "abc"    ;# → 1  (def > abc)
string compare "abc" "abc"    ;# → 0  (equal)

# Case-insensitive
string compare -nocase "Hello" "hello"   ;# → 0

# Equality check
string equal "abc" "abc"              ;# → 1
string equal -nocase "Hello" "HELLO"  ;# → 1

# Length-limited comparison
string compare -length 3 "hello" "help"   ;# → 0 (first 3 chars equal)
```

## Searching in Strings

```tcl
set text "The quick brown fox jumps over the lazy dog"

# Find first occurrence (returns index or -1)
string first "fox" $text        ;# → 16
string first "cat" $text        ;# → -1

# Find last occurrence
string last "the" $text         ;# → 31

# Search starting from position
string first "o" $text 10       ;# → 17 (first 'o' after index 10)
```

## String Matching (Glob Patterns)

```tcl
string match "*.tcl" "script.tcl"       ;# → 1
string match "*.tcl" "script.py"        ;# → 0
string match "hello*" "hello world"     ;# → 1
string match {[a-z]*} "hello"           ;# → 1
string match {*[0-9]*} "abc123"         ;# → 1

# Case-insensitive matching
string match -nocase "HELLO*" "hello world"   ;# → 1
```

Glob pattern characters:
- `*` — matches any sequence of characters
- `?` — matches any single character
- `[chars]` — matches any character in the set
- `\x` — matches the literal character `x`

## String Replacement

```tcl
set str "Hello, World!"

string replace $str 7 11 "Tcl"    ;# → Hello, Tcl!
string replace $str 0 4 "Greetings"  ;# → Greetings, World!
```

## String Mapping (Find & Replace)

`string map` does simultaneous find-and-replace for multiple patterns:

```tcl
# Pairs of {old new old new ...}
string map {foo bar baz qux} "foo is not baz"
# → bar is not qux

# HTML escaping
proc html_escape {text} {
    return [string map {
        & "&amp;"
        < "&lt;"
        > "&gt;"
        \" "&quot;"
        ' "&#39;"
    } $text]
}

puts [html_escape {<script>alert("XSS")</script>}]
# → &lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;
```

## String Trimming

```tcl
string trim "  hello  "           ;# → "hello"
string trimleft "  hello  "       ;# → "hello  "
string trimright "  hello  "      ;# → "  hello"

# Trim specific characters
string trim "---hello---" "-"     ;# → "hello"
string trim "xxxhelloyyy" "xy"    ;# → "hello"
```

## String Repetition

```tcl
string repeat "ab" 3    ;# → ababab
string repeat "-" 40    ;# → ----------------------------------------
string repeat "Ha" 5    ;# → HaHaHaHaHa
```

## String Reversal

```tcl
string reverse "Hello"   ;# → olleH
string reverse "12345"   ;# → 54321
```

## String Type Testing

```tcl
string is integer -strict "42"       ;# → 1
string is integer -strict "42.5"     ;# → 0
string is double -strict "3.14"      ;# → 1
string is alpha -strict "hello"      ;# → 1
string is alpha -strict "hello123"   ;# → 0
string is alnum -strict "hello123"   ;# → 1
string is digit -strict "12345"      ;# → 1
string is upper -strict "HELLO"      ;# → 1
string is lower -strict "hello"      ;# → 1
string is space -strict "  \t\n"     ;# → 1
string is boolean -strict "yes"      ;# → 1
string is list "a {b c} d"          ;# → 1
string is list "a {b"               ;# → 0 (unbalanced brace)
```

## The `format` Command (printf-style)

```tcl
# Basic formatting
format "Name: %s, Age: %d" "Alice" 30
# → Name: Alice, Age: 30

# Width and alignment
format "%-20s %5d" "Alice" 95      ;# Left-align, right-align
format "%020d" 42                   ;# Zero-padded: 00000000000000000042

# Floating point
format "%.2f" 3.14159              ;# → 3.14
format "%10.3f" 3.14159            ;# →      3.142
format "%e" 12345.6789             ;# → 1.234568e+04

# Hex, octal, binary
format "0x%04X" 255                ;# → 0x00FF
format "%o" 255                    ;# → 377
format "%c" 65                     ;# → A (character from code point)
```

### Format Specifiers

| Specifier | Description | Example |
|-----------|-------------|---------|
| `%s` | String | `format "%s" "hello"` → `hello` |
| `%d` | Decimal integer | `format "%d" 42` → `42` |
| `%f` | Floating point | `format "%.2f" 3.14` → `3.14` |
| `%e` | Scientific notation | `format "%e" 1234` → `1.234e+03` |
| `%g` | Shorter of `%f` and `%e` | `format "%g" 0.001` → `0.001` |
| `%x` / `%X` | Hexadecimal | `format "%x" 255` → `ff` |
| `%o` | Octal | `format "%o" 8` → `10` |
| `%b` | Binary | `format "%b" 10` → `1010` |
| `%c` | Character (from code) | `format "%c" 65` → `A` |
| `%%` | Literal `%` | `format "100%%"` → `100%` |

## The `scan` Command (Parsing)

`scan` is the inverse of `format` — it parses a string according to a format:

```tcl
scan "Alice 30" "%s %d" name age
puts "$name is $age"   ;# → Alice is 30

scan "FF" "%x" decimal
puts $decimal   ;# → 255

scan "192.168.1.100" "%d.%d.%d.%d" a b c d
puts "$a.$b.$c.$d"   ;# → 192.168.1.100

# scan returns the number of successfully matched items
set count [scan "42 3.14 hello" "%d %f %s" i f s]
puts "Matched $count items: int=$i float=$f string=$s"
```

## String Concatenation

```tcl
# Using append (most efficient for building strings)
set result ""
append result "Hello"
append result ", " "World" "!"
puts $result   ;# → Hello, World!

# Using string concatenation in double quotes
set first "Hello"
set second "World"
set combined "$first, $second!"

# Using concat (for lists, but works for strings)
set str [concat "hello" "world"]   ;# → hello world
```

## Practical Example: Word Counter

```tcl
proc count_words {text} {
    set words [regexp -all -inline {\S+} $text]
    return [llength $words]
}

proc word_frequency {text} {
    array set freq {}
    foreach word [regexp -all -inline {\S+} [string tolower $text]] {
        set word [string trim $word ".,;:!?\"'()"]
        if {$word ne ""} {
            if {![info exists freq($word)]} {
                set freq($word) 0
            }
            incr freq($word)
        }
    }
    return [array get freq]
}

set text "The quick brown fox jumps over the lazy dog. The dog barked."
puts "Word count: [count_words $text]"

array set frequencies [word_frequency $text]
foreach word [lsort [array names frequencies]] {
    puts [format "  %-10s %d" $word $frequencies($word)]
}
```

## Practical Example: String Padding and Alignment

```tcl
proc center {text width {fill " "}} {
    set len [string length $text]
    if {$len >= $width} { return $text }
    set pad [expr {$width - $len}]
    set left [expr {$pad / 2}]
    set right [expr {$pad - $left}]
    return "[string repeat $fill $left]$text[string repeat $fill $right]"
}

proc table_row {cols widths} {
    set parts {}
    foreach col $cols w $widths {
        lappend parts [format "%-${w}s" $col]
    }
    return "| [join $parts " | "] |"
}

puts [center "Title" 40 "="]
puts [table_row {Name Age City} {15 5 15}]
puts [table_row {Alice 30 "New York"} {15 5 15}]
puts [table_row {Bob 25 London} {15 5 15}]
```

---

**Previous:** [Procedures & Scope](05-procedures-and-scope.md) | **Next:** [Lists](07-lists.md)
