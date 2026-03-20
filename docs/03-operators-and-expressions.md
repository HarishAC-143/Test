# 3. Operators & Expressions

## The `expr` Command

All operators in Tcl live inside the `expr` command. Unlike many languages, operators are not part of the general syntax — they only work within `expr` (and commands that implicitly call `expr`, such as `if`, `while`, and `for`).

```tcl
# Always brace expr arguments
set result [expr {2 + 3 * 4}]   ;# → 14
```

> **Why brace?** Unbraced expressions are parsed twice (once by the Tcl parser, once by expr). Bracing prevents double substitution, improves performance via byte-compilation, and avoids injection vulnerabilities.

## Arithmetic Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `+`  | Addition          | `expr {7 + 3}`   | `10` |
| `-`  | Subtraction       | `expr {7 - 3}`   | `4` |
| `*`  | Multiplication    | `expr {7 * 3}`   | `21` |
| `/`  | Division          | `expr {7 / 3}`   | `2` |
| `%`  | Modulo            | `expr {7 % 3}`   | `1` |
| `**` | Exponentiation    | `expr {2 ** 10}` | `1024` |
| `-`  | Unary negation    | `expr {-$x}`     | `-x` |

### Integer vs. Floating-Point Division

```tcl
expr {7 / 3}       ;# → 2     (integer division)
expr {7.0 / 3}     ;# → 2.3333333333333335
expr {7 / 3.0}     ;# → 2.3333333333333335
expr {double(7)/3}  ;# → 2.3333333333333335
```

## Comparison Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `==` | Equal | `expr {5 == 5}` | `1` |
| `!=` | Not equal | `expr {5 != 3}` | `1` |
| `<`  | Less than | `expr {3 < 5}` | `1` |
| `>`  | Greater than | `expr {5 > 3}` | `1` |
| `<=` | Less or equal | `expr {5 <= 5}` | `1` |
| `>=` | Greater or equal | `expr {5 >= 3}` | `1` |

### String Comparison Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `eq` | String equal | `expr {"abc" eq "abc"}` | `1` |
| `ne` | String not equal | `expr {"abc" ne "def"}` | `1` |
| `lt` | String less than | `expr {"abc" lt "def"}` | `1` |
| `gt` | String greater than | `expr {"def" gt "abc"}` | `1` |
| `le` | String less or equal | `expr {"abc" le "abc"}` | `1` |
| `ge` | String greater or equal | `expr {"def" ge "abc"}` | `1` |

> **Important:** Use `eq`/`ne` for string comparison, `==`/`!=` for numeric. Using `==` with strings can produce unexpected results when values look like numbers.

```tcl
expr {"0x1" == "1"}    ;# → 1 (both parsed as numbers)
expr {"0x1" eq "1"}    ;# → 0 (compared as strings)
```

## Logical Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `&&` | Logical AND | `expr {1 && 0}` | `0` |
| `\|\|` | Logical OR | `expr {1 \|\| 0}` | `1` |
| `!`  | Logical NOT | `expr {!0}` | `1` |

```tcl
set age 25
set hasLicense true

if {$age >= 18 && $hasLicense} {
    puts "Can drive"
}
```

Short-circuit evaluation applies: `&&` stops if the left side is false, `||` stops if the left side is true.

## Bitwise Operators

| Operator | Description | Example | Result |
|----------|-------------|---------|--------|
| `&`  | Bitwise AND | `expr {0xFF & 0x0F}` | `15` |
| `\|` | Bitwise OR | `expr {0xF0 \| 0x0F}` | `255` |
| `^`  | Bitwise XOR | `expr {0xFF ^ 0x0F}` | `240` |
| `~`  | Bitwise NOT | `expr {~0xFF}` | `-256` |
| `<<` | Left shift | `expr {1 << 4}` | `16` |
| `>>` | Right shift | `expr {16 >> 2}` | `4` |

```tcl
# Setting and checking bit flags
set flags 0
set flags [expr {$flags | 0x01}]    ;# Set bit 0
set flags [expr {$flags | 0x04}]    ;# Set bit 2

if {$flags & 0x01} {
    puts "Bit 0 is set"
}

# Clear a bit
set flags [expr {$flags & ~0x04}]   ;# Clear bit 2
```

## The Ternary Operator

```tcl
set x 15
set category [expr {$x > 10 ? "large" : "small"}]
puts $category   ;# → large

# Nested ternary
set grade [expr {
    $score >= 90 ? "A" :
    $score >= 80 ? "B" :
    $score >= 70 ? "C" :
    $score >= 60 ? "D" : "F"
}]
```

## Math Functions

`expr` includes built-in math functions:

| Function | Description | Example |
|----------|-------------|---------|
| `abs(x)` | Absolute value | `expr {abs(-5)}` → `5` |
| `int(x)` | Convert to integer | `expr {int(3.9)}` → `3` |
| `double(x)` | Convert to float | `expr {double(3)}` → `3.0` |
| `round(x)` | Round to nearest integer | `expr {round(3.5)}` → `4` |
| `ceil(x)` | Ceiling | `expr {ceil(3.2)}` → `4.0` |
| `floor(x)` | Floor | `expr {floor(3.8)}` → `3.0` |
| `sqrt(x)` | Square root | `expr {sqrt(16)}` → `4.0` |
| `pow(x,y)` | Power | `expr {pow(2,10)}` → `1024.0` |
| `log(x)` | Natural log | `expr {log(2.718)}` → `~1.0` |
| `log10(x)` | Base-10 log | `expr {log10(100)}` → `2.0` |
| `sin(x)` | Sine (radians) | `expr {sin(3.14159/2)}` → `~1.0` |
| `cos(x)` | Cosine (radians) | `expr {cos(0)}` → `1.0` |
| `tan(x)` | Tangent (radians) | `expr {tan(0.785)}` → `~1.0` |
| `asin(x)` | Arc sine | `expr {asin(1.0)}` → `~1.5708` |
| `acos(x)` | Arc cosine | `expr {acos(0.0)}` → `~1.5708` |
| `atan(x)` | Arc tangent | `expr {atan(1.0)}` → `~0.7854` |
| `atan2(y,x)` | 2-arg arc tangent | `expr {atan2(1,1)}` → `~0.7854` |
| `exp(x)` | e^x | `expr {exp(1)}` → `~2.718` |
| `fmod(x,y)` | Float modulo | `expr {fmod(5.5, 2.0)}` → `1.5` |
| `hypot(x,y)` | Hypotenuse | `expr {hypot(3,4)}` → `5.0` |
| `max(x,y,...)` | Maximum | `expr {max(3,7,1,5)}` → `7` |
| `min(x,y,...)` | Minimum | `expr {min(3,7,1,5)}` → `1` |
| `rand()` | Random [0,1) | `expr {rand()}` → `0.xxx` |
| `srand(x)` | Seed random | `expr {srand(42)}` |
| `wide(x)` | 64-bit integer | `expr {wide(42)}` |
| `bool(x)` | Boolean conversion | `expr {bool("yes")}` → `1` |

### Example: Computing Distance Between Points

```tcl
proc distance {x1 y1 x2 y2} {
    return [expr {hypot($x2 - $x1, $y2 - $y1)}]
}

puts [distance 0 0 3 4]   ;# → 5.0
```

### Example: Random Number in Range

```tcl
proc rand_range {min max} {
    return [expr {int(rand() * ($max - $min + 1)) + $min}]
}

puts [rand_range 1 6]   ;# Random die roll
```

## Operator Precedence (Highest to Lowest)

| Precedence | Operators |
|------------|-----------|
| 1 | `- + ~ !` (unary) |
| 2 | `**` |
| 3 | `* / %` |
| 4 | `+ -` |
| 5 | `<< >>` |
| 6 | `< > <= >=` |
| 7 | `== != eq ne` |
| 8 | `&` |
| 9 | `^` |
| 10 | `\|` |
| 11 | `&&` |
| 12 | `\|\|` |
| 13 | `? :` (ternary) |

Use parentheses to override precedence:

```tcl
expr {(2 + 3) * 4}   ;# → 20 (not 14)
```

---

**Previous:** [Variables & Data Types](02-variables-and-data-types.md) | **Next:** [Control Flow](04-control-flow.md)
