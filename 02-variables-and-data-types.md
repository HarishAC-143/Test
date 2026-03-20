# Chapter 2: Variables and Data Types

Perl has three fundamental variable types, each identified by a special prefix character called a **sigil**.

| Sigil | Type | Stores |
|-------|------|--------|
| `$` | Scalar | A single value (number, string, or reference) |
| `@` | Array | An ordered list of scalars |
| `%` | Hash | An unordered set of key-value pairs |

## Scalars (`$`)

A scalar holds a single value. Perl automatically determines whether the value is a number or a string based on context.

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Strings
my $name    = "Alice";
my $greeting = 'Hello, World!';   # single quotes: no interpolation

# Numbers
my $age     = 30;
my $pi      = 3.14159;
my $hex     = 0xFF;      # 255 in hexadecimal
my $octal   = 0777;      # 511 in octal
my $binary  = 0b11111111; # 255 in binary
my $sci     = 6.022e23;  # scientific notation

# Undefined value
my $nothing;  # starts as undef

print "Name: $name\n";
print "Age: $age\n";
print "Pi: $pi\n";
```

### String Interpolation

Double-quoted strings interpolate variables and escape sequences. Single-quoted strings are literal.

```perl
my $user = "Bob";
my $count = 42;

# Double quotes: variables are interpolated
print "Hello, $user! You have $count messages.\n";
# Output: Hello, Bob! You have 42 messages.

# Single quotes: everything is literal
print 'Hello, $user! You have $count messages.\n';
# Output: Hello, $user! You have $count messages.\n

# Curly braces disambiguate variable names
my $fruit = "apple";
print "I like ${fruit}s\n";   # Output: I like apples
```

### Common Escape Sequences

| Sequence | Meaning |
|----------|---------|
| `\n` | Newline |
| `\t` | Tab |
| `\\` | Literal backslash |
| `\"` | Literal double quote |
| `\0` | Null character |
| `\x{263A}` | Unicode character (smiley face) |

### Here-Documents

For multi-line strings, use a here-document:

```perl
my $poem = <<END_POEM;
Roses are red,
Violets are blue,
Perl is powerful,
And so are you.
END_POEM

print $poem;

# Non-interpolating (like single quotes)
my $code = <<'END_CODE';
my $x = 10;
print "Value: $x\n";
END_CODE

# Indented here-doc (Perl 5.26+)
my $html = <<~HTML;
    <html>
        <body>
            <p>Hello</p>
        </body>
    </html>
    HTML
```

## Arrays (`@`)

An array is an ordered list of scalars, indexed starting at 0.

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Creating arrays
my @colors = ("red", "green", "blue");
my @numbers = (1, 2, 3, 4, 5);
my @mixed = ("hello", 42, 3.14, undef);

# qw() — quote words shortcut (splits on whitespace)
my @days = qw(Monday Tuesday Wednesday Thursday Friday Saturday Sunday);

# Accessing elements (note the $ sigil — accessing a single scalar)
print "First color: $colors[0]\n";     # red
print "Last color: $colors[-1]\n";     # blue (negative index counts from end)

# Array length
my $length = scalar @colors;           # 3
my $last_index = $#colors;             # 2 (index of last element)
print "Array has $length elements\n";

# Array slices (returns a list, so use @)
my @subset = @colors[0, 2];           # ("red", "blue")
my @range  = @numbers[1..3];          # (2, 3, 4)
```

### Modifying Arrays

```perl
my @fruits = qw(apple banana cherry);

# Add to the end
push @fruits, "date";                # (apple, banana, cherry, date)
push @fruits, "elderberry", "fig";   # can push multiple values

# Remove from the end
my $last = pop @fruits;              # removes and returns "fig"

# Add to the beginning
unshift @fruits, "apricot";          # (apricot, apple, banana, ...)

# Remove from the beginning
my $first = shift @fruits;           # removes and returns "apricot"

# Splice: remove/replace/insert at any position
# splice(@array, offset, length, replacement_list)
my @arr = (1, 2, 3, 4, 5);
my @removed = splice(@arr, 1, 2);    # removes (2, 3); @arr is now (1, 4, 5)
splice(@arr, 1, 0, 10, 20);          # insert 10, 20 at index 1; @arr is (1, 10, 20, 4, 5)
```

### Array Functions

```perl
my @nums = (5, 3, 8, 1, 9, 2);

# Sorting
my @sorted   = sort @nums;                   # (1, 2, 3, 5, 8, 9) — lexicographic
my @num_sort = sort { $a <=> $b } @nums;     # (1, 2, 3, 5, 8, 9) — numeric ascending
my @rev_sort = sort { $b <=> $a } @nums;     # (9, 8, 5, 3, 2, 1) — numeric descending

# Reversing
my @reversed = reverse @nums;

# Joining into a string
my $csv = join(",", @nums);           # "5,3,8,1,9,2"

# Splitting a string into an array
my @words = split(/,/, "one,two,three");  # ("one", "two", "three")

# Grep — filter elements
my @evens = grep { $_ % 2 == 0 } @nums;  # (8, 2)

# Map — transform elements
my @doubled = map { $_ * 2 } @nums;      # (10, 6, 16, 2, 18, 4)
```

## Hashes (`%`)

A hash stores unordered key-value pairs. Keys are always strings; values are scalars.

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Creating a hash
my %person = (
    name  => "Alice",
    age   => 30,
    email => "alice@example.com",
);

# Accessing values (note the $ sigil — single scalar value)
print "Name: $person{name}\n";
print "Age: $person{age}\n";

# Adding / modifying entries
$person{phone} = "555-1234";
$person{age} = 31;

# Deleting entries
delete $person{phone};

# Checking if a key exists
if (exists $person{email}) {
    print "Email is on file.\n";
}

# Check if a value is defined
if (defined $person{name}) {
    print "Name is defined.\n";
}
```

### Hash Operations

```perl
my %scores = (
    Alice => 95,
    Bob   => 87,
    Carol => 92,
    Dave  => 78,
);

# Get all keys and values
my @names  = keys %scores;      # ("Alice", "Bob", "Carol", "Dave") — order not guaranteed
my @grades = values %scores;    # (95, 87, 92, 78) — same order as keys

# Number of key-value pairs
my $count = scalar keys %scores;  # 4

# Iterating over a hash
while (my ($name, $score) = each %scores) {
    print "$name scored $score\n";
}

# Hash slice
my @selected = @scores{qw(Alice Carol)};   # (95, 92)

# Merging hashes (later values overwrite earlier ones)
my %defaults = (color => "blue", size => "medium");
my %custom   = (color => "red");
my %config   = (%defaults, %custom);
# %config is (color => "red", size => "medium")
```

## Context: Scalar vs List

Perl has a concept of **context** that affects how expressions behave. This is one of Perl's most important (and unique) concepts.

```perl
my @array = (10, 20, 30);

# List context: returns all elements
my @copy = @array;             # (10, 20, 30)

# Scalar context: returns the count of elements
my $count = @array;            # 3

# Forcing scalar context
print "Elements: ", scalar @array, "\n";

# Another example: localtime
my @time_parts = localtime();   # list of 9 values
my $time_str   = localtime();   # formatted string like "Fri Mar 20 12:30:00 2026"
```

## Special Variables

Perl has many built-in special variables. Here are the most commonly used:

| Variable | Purpose |
|----------|---------|
| `$_` | The default variable (used by many functions implicitly) |
| `@_` | Subroutine arguments |
| `@ARGV` | Command-line arguments |
| `$0` | The name of the current script |
| `$!` | System error message (like C's `errno`) |
| `$/` | Input record separator (default: newline) |
| `$\` | Output record separator |
| `$.` | Current line number of last filehandle read |
| `$,` | Output field separator for `print` |
| `%ENV` | Environment variables |

```perl
# $_ is used implicitly by many functions
my @names = qw(Alice Bob Carol);
for (@names) {
    print "Hello, $_!\n";   # $_ is each element in turn
}

# @ARGV: command-line arguments
# Run: perl script.pl arg1 arg2
print "Script name: $0\n";
print "Arguments: @ARGV\n";
print "First arg: $ARGV[0]\n";

# %ENV: environment variables
print "Home directory: $ENV{HOME}\n";
print "Path: $ENV{PATH}\n";
```

## Type Conversion

Perl converts between strings and numbers automatically based on context:

```perl
my $str = "42abc";
my $num = $str + 0;     # 42 (Perl extracts leading number)

my $val = "hello" + 0;  # 0 (no leading number)

my $n = 100;
my $s = "$n";            # "100" (number to string via interpolation)

# Comparison operators reflect context
# Numeric: ==  !=  <  >  <=  >=  <=>
# String:  eq  ne  lt  gt  le  ge  cmp

print "Equal!\n" if 42 == 42;       # numeric comparison
print "Equal!\n" if "hello" eq "hello";  # string comparison

# Common bug: using == for string comparison
# "abc" == "def" is TRUE (both are 0 numerically)
```

## Chapter Summary

- Perl has three variable types: scalars (`$`), arrays (`@`), and hashes (`%`).
- Double-quoted strings interpolate variables; single-quoted strings are literal.
- Arrays are ordered lists with powerful built-in functions like `push`, `pop`, `sort`, `grep`, and `map`.
- Hashes are key-value stores accessed with curly braces.
- Context (scalar vs list) affects how expressions behave — a uniquely Perl concept.
- Use `eq`/`ne` for string comparison and `==`/`!=` for numeric comparison.

---

**Previous**: [Chapter 1 — Introduction](01-introduction.md)
**Next**: [Chapter 3 — Operators and Control Structures](03-operators-and-control-structures.md)
