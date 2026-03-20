# Perl Programming Tutorial: From Basics to Advanced

A comprehensive, hands-on guide to learning Perl programming. This tutorial covers
everything from your first "Hello, World!" to advanced topics like object-oriented
programming, complex data structures, and real-world practical projects.

All example scripts are in the [`examples/`](examples/) directory, organized by topic.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Getting Started](#2-getting-started)
3. [Variables and Data Types](#3-variables-and-data-types)
4. [Operators](#4-operators)
5. [Control Structures](#5-control-structures)
6. [Strings and String Operations](#6-strings-and-string-operations)
7. [Subroutines (Functions)](#7-subroutines-functions)
8. [Input and Output](#8-input-and-output)
9. [File Handling](#9-file-handling)
10. [Regular Expressions](#10-regular-expressions)
11. [References and Complex Data Structures](#11-references-and-complex-data-structures)
12. [Object-Oriented Perl](#12-object-oriented-perl)
13. [Modules and Packages](#13-modules-and-packages)
14. [Error Handling](#14-error-handling)
15. [Advanced Topics](#15-advanced-topics)
16. [Practical Projects](#16-practical-projects)
17. [Best Practices](#17-best-practices)

---

## 1. Introduction

### What is Perl?

Perl (Practical Extraction and Reporting Language) is a high-level, general-purpose,
interpreted programming language created by Larry Wall in 1987. It excels at:

- **Text processing** and pattern matching
- **System administration** and automation
- **Web development** (CGI, web frameworks)
- **Bioinformatics** and data analysis
- **Network programming**
- **Database interaction**

### Why Learn Perl?

- Extremely powerful regular expression support built into the language
- The CPAN (Comprehensive Perl Archive Network) offers over 200,000 modules
- "There's more than one way to do it" (TMTOWTDI) philosophy gives you flexibility
- Runs on virtually every platform
- Battle-tested in production for decades

### Perl's Motto

> "Easy things should be easy, and hard things should be possible." — Larry Wall

---

## 2. Getting Started

### Installation

**Linux/macOS:** Perl comes pre-installed on most Unix-like systems.

```bash
perl -v          # Check if Perl is installed and its version
which perl       # Find where Perl is installed
```

**Install on Ubuntu/Debian:**

```bash
sudo apt-get update
sudo apt-get install perl
```

**Install on macOS (via Homebrew):**

```bash
brew install perl
```

**Windows:** Install [Strawberry Perl](https://strawberryperl.com/) or
[ActivePerl](https://www.activestate.com/products/perl/).

### Your First Perl Program

Create a file named `hello.pl`:

```perl
#!/usr/bin/perl
use strict;
use warnings;

print "Hello, World!\n";
```

Run it:

```bash
perl hello.pl
```

Or make it executable:

```bash
chmod +x hello.pl
./hello.pl
```

### Anatomy of a Perl Script

```perl
#!/usr/bin/perl          # Shebang line — tells the OS which interpreter to use
use strict;              # Enforces good coding practices (must declare variables)
use warnings;            # Enables helpful warning messages

# This is a single-line comment

=pod
This is a multi-line comment
(actually a POD documentation block)
=cut

print "Hello, World!\n"; # Statements end with a semicolon
```

> **Always use `use strict;` and `use warnings;` at the top of every script.**
> They catch common bugs early and save hours of debugging.

See: [`examples/01-basics/hello.pl`](examples/01-basics/hello.pl)

---

## 3. Variables and Data Types

Perl has three main variable types, each with its own sigil (prefix character):

| Sigil | Type   | Description                       | Example              |
|-------|--------|-----------------------------------|----------------------|
| `$`   | Scalar | Single value (number, string, ref)| `$name = "Alice";`   |
| `@`   | Array  | Ordered list of scalars           | `@colors = ("red");` |
| `%`   | Hash   | Unordered key-value pairs         | `%age = (bob => 30);`|

### 3.1 Scalars (`$`)

A scalar holds a single value — a number, a string, or a reference.

```perl
my $name   = "Alice";         # String
my $age    = 30;               # Integer
my $pi     = 3.14159;          # Floating point
my $big    = 1.5e10;           # Scientific notation
my $hex    = 0xFF;             # Hexadecimal (255)
my $oct    = 0777;             # Octal (511)
my $bin    = 0b11111111;       # Binary (255)
my $undef_var;                 # Undefined (undef)
```

Perl automatically converts between numbers and strings based on context:

```perl
my $num = "42";      # String "42"
my $result = $num + 8; # Numeric context: 50
print "Value: $result\n";

my $str = 100;
print "The number is $str\n"; # String context: interpolation works
```

### 3.2 Arrays (`@`)

Arrays are ordered lists of scalars, indexed starting at 0.

```perl
my @fruits = ("apple", "banana", "cherry");
my @numbers = (1, 2, 3, 4, 5);
my @mixed = ("hello", 42, 3.14, undef);

# Access elements (note: use $ for a single element)
print $fruits[0];    # "apple"
print $fruits[-1];   # "cherry" (last element)

# Array length
my $length = scalar @fruits;  # 3
my $last_index = $#fruits;    # 2 (index of last element)

# Array slices
my @subset = @fruits[0, 2];   # ("apple", "cherry")
my @range  = @numbers[1..3];  # (2, 3, 4)
```

**Common array operations:**

```perl
push @fruits, "date";         # Add to end
pop @fruits;                  # Remove from end
unshift @fruits, "avocado";   # Add to beginning
shift @fruits;                # Remove from beginning
splice @fruits, 1, 1;        # Remove 1 element at index 1

my @sorted = sort @fruits;           # Alphabetical sort
my @reversed = reverse @fruits;      # Reverse the array
my $joined = join(", ", @fruits);    # Join into a string
my @words = split(/,/, "a,b,c");    # Split string into array

# Check if array contains a value (Perl 5.10+)
use List::Util 'any';
if (any { $_ eq "apple" } @fruits) {
    print "Found apple!\n";
}
```

### 3.3 Hashes (`%`)

Hashes are unordered collections of key-value pairs.

```perl
my %person = (
    name  => "Alice",
    age   => 30,
    email => "alice@example.com",
);

# Access values (note: use $ for a single value)
print $person{name};     # "Alice"
print $person{age};      # 30

# Add or modify entries
$person{phone} = "555-1234";
$person{age} = 31;

# Delete an entry
delete $person{phone};

# Check if a key exists
if (exists $person{email}) {
    print "Email is set\n";
}

# Get all keys and values
my @keys   = keys %person;
my @values = values %person;

# Iterate over a hash
while (my ($key, $value) = each %person) {
    print "$key: $value\n";
}

# Hash slice
my @selected = @person{qw(name age)}; # ("Alice", 31)
```

See: [`examples/02-data-types/scalars.pl`](examples/02-data-types/scalars.pl),
[`examples/02-data-types/arrays.pl`](examples/02-data-types/arrays.pl),
[`examples/02-data-types/hashes.pl`](examples/02-data-types/hashes.pl)

---

## 4. Operators

### 4.1 Arithmetic Operators

```perl
my $a = 10;
my $b = 3;

$a + $b;     # 13  (addition)
$a - $b;     # 7   (subtraction)
$a * $b;     # 30  (multiplication)
$a / $b;     # 3.333... (division)
$a % $b;     # 1   (modulus)
$a ** $b;    # 1000 (exponentiation)
```

### 4.2 String Operators

```perl
my $first = "Hello";
my $last  = "World";

$first . " " . $last;  # "Hello World" (concatenation)
$first x 3;             # "HelloHelloHello" (repetition)
```

### 4.3 Comparison Operators

Perl has separate comparison operators for numbers and strings:

| Operation        | Numeric | String |
|------------------|---------|--------|
| Equal            | `==`    | `eq`   |
| Not equal        | `!=`    | `ne`   |
| Less than        | `<`     | `lt`   |
| Greater than     | `>`     | `gt`   |
| Less or equal    | `<=`    | `le`   |
| Greater or equal | `>=`    | `ge`   |
| Comparison       | `<=>`   | `cmp`  |

```perl
5 == 5;       # true (numeric)
"abc" eq "abc"; # true (string)

# The spaceship operator returns -1, 0, or 1
5 <=> 10;     # -1
10 <=> 10;    # 0
15 <=> 10;    # 1
```

### 4.4 Logical Operators

```perl
# C-style              # English-style
$a && $b;              $a and $b;     # AND
$a || $b;              $a or $b;      # OR
!$a;                   not $a;        # NOT

# Defined-or operator (Perl 5.10+)
my $val = $maybe_undef // "default";  # Use "default" if $maybe_undef is undef
```

### 4.5 Assignment Operators

```perl
$x  = 10;     # Assign
$x += 5;      # $x = $x + 5
$x -= 3;      # $x = $x - 3
$x *= 2;      # $x = $x * 2
$x /= 4;      # $x = $x / 4
$x .= " end"; # $x = $x . " end" (string append)
$x //= "val"; # $x = $x // "val" (assign if undef)
```

---

## 5. Control Structures

### 5.1 Conditional Statements

```perl
# if / elsif / else
my $score = 85;

if ($score >= 90) {
    print "Grade: A\n";
} elsif ($score >= 80) {
    print "Grade: B\n";
} elsif ($score >= 70) {
    print "Grade: C\n";
} else {
    print "Grade: F\n";
}

# unless (opposite of if)
unless ($score < 60) {
    print "You passed!\n";
}

# Postfix (statement modifier) form
print "Excellent!\n" if $score >= 90;
print "Try harder\n" unless $score >= 60;

# Ternary operator
my $status = ($score >= 60) ? "Pass" : "Fail";
```

### 5.2 Loops

```perl
# for loop (C-style)
for (my $i = 0; $i < 10; $i++) {
    print "$i ";
}

# foreach loop (iterate over a list)
my @colors = ("red", "green", "blue");
foreach my $color (@colors) {
    print "Color: $color\n";
}

# for and foreach are interchangeable
for my $color (@colors) {
    print "Color: $color\n";
}

# while loop
my $count = 0;
while ($count < 5) {
    print "Count: $count\n";
    $count++;
}

# until loop (opposite of while)
my $n = 10;
until ($n <= 0) {
    print "$n ";
    $n--;
}

# do-while equivalent
my $x = 0;
do {
    print "x = $x\n";
    $x++;
} while ($x < 3);

# Postfix loop
print "$_ " for 1..10;
print "$_ " foreach @colors;
```

### 5.3 Loop Control

```perl
# next — skip to the next iteration (like 'continue' in C)
for my $i (1..10) {
    next if $i % 2 == 0;  # Skip even numbers
    print "$i ";           # Prints: 1 3 5 7 9
}

# last — exit the loop (like 'break' in C)
for my $i (1..100) {
    last if $i > 5;        # Stop after 5
    print "$i ";            # Prints: 1 2 3 4 5
}

# redo — restart current iteration without re-checking condition
my $attempts = 0;
for my $item ("data") {
    $attempts++;
    redo if $attempts < 3; # Repeat without advancing
}

# Loop labels for nested loops
OUTER: for my $i (1..5) {
    for my $j (1..5) {
        next OUTER if $j == 3; # Skip to next iteration of OUTER loop
        print "($i,$j) ";
    }
}
```

### 5.4 Given/When (Switch Statement, Perl 5.10+)

```perl
use feature 'say';

my $fruit = "apple";

# Note: given/when is experimental in modern Perl.
# A simple if/elsif chain is often preferred.
if ($fruit eq "apple")    { say "It's an apple!" }
elsif ($fruit eq "banana") { say "It's a banana!" }
elsif ($fruit eq "cherry") { say "It's a cherry!" }
else                       { say "Unknown fruit" }
```

See: [`examples/03-control-flow/conditionals.pl`](examples/03-control-flow/conditionals.pl),
[`examples/03-control-flow/loops.pl`](examples/03-control-flow/loops.pl)

---

## 6. Strings and String Operations

### 6.1 String Quoting

```perl
# Double quotes — interpolation and escape sequences
my $name = "World";
print "Hello, $name!\n";         # Hello, World!
print "Tab:\there\n";            # Tab:   here
print "Unicode: \x{263A}\n";    # Unicode smiley

# Single quotes — literal, no interpolation
print 'Hello, $name!\n';        # Hello, $name!\n (literally)
print 'It\'s a literal string'; # Escape only \\ and \'

# Heredoc syntax (for multi-line strings)
my $html = <<HTML;
<html>
  <body>
    <h1>Hello, $name</h1>
  </body>
</html>
HTML

# Indented heredoc (Perl 5.26+)
my $text = <<~END;
    This is indented in source
    but leading whitespace is stripped.
    Name: $name
    END

# Quote-like operators
my $str = qq{This contains "quotes" and $name};  # Like double quotes
my $lit = q{No $interpolation here};              # Like single quotes
my @words = qw(apple banana cherry);              # Quote words into a list
```

### 6.2 Common String Functions

```perl
my $str = "Hello, Perl World!";

length($str);                    # 18
uc($str);                       # "HELLO, PERL WORLD!"
lc($str);                       # "hello, perl world!"
ucfirst("hello");               # "Hello"
lcfirst("Hello");               # "hello"

index($str, "Perl");            # 7 (position of first occurrence)
rindex($str, "l");              # 16 (position of last occurrence)
substr($str, 7, 4);             # "Perl" (extract substring)
substr($str, 7, 4, "Ruby");    # Replaces "Perl" with "Ruby"

reverse("Hello");               # "olleH"
chomp(my $input = "data\n");   # Removes trailing newline
chop($str);                    # Removes last character

# sprintf for formatted strings
my $formatted = sprintf("Name: %-10s Age: %03d", "Alice", 5);
# "Name: Alice      Age: 005"
```

---

## 7. Subroutines (Functions)

### 7.1 Defining and Calling Subroutines

```perl
# Define a subroutine
sub greet {
    my ($name) = @_;  # @_ contains the arguments
    return "Hello, $name!";
}

# Call it
my $message = greet("Alice");
print "$message\n";

# Multiple parameters
sub add {
    my ($a, $b) = @_;
    return $a + $b;
}

print add(3, 4), "\n";  # 7
```

### 7.2 Parameter Handling

```perl
# Default values
sub connect_db {
    my (%args) = @_;
    my $host = $args{host} // "localhost";
    my $port = $args{port} // 5432;
    my $db   = $args{db}   // "mydb";
    print "Connecting to $db on $host:$port\n";
}

connect_db(host => "dbserver", db => "production");

# Variable number of arguments
sub sum_all {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}

print sum_all(1, 2, 3, 4, 5), "\n";  # 15
```

### 7.3 Returning Values

```perl
# Return multiple values
sub min_max {
    my @sorted = sort { $a <=> $b } @_;
    return ($sorted[0], $sorted[-1]);
}

my ($min, $max) = min_max(5, 2, 9, 1, 7);
print "Min: $min, Max: $max\n";  # Min: 1, Max: 9

# Return a hash
sub get_config {
    return (
        debug   => 0,
        verbose => 1,
        timeout => 30,
    );
}

my %config = get_config();
```

### 7.4 Anonymous Subroutines and Closures

```perl
# Anonymous subroutine (code reference)
my $square = sub {
    my ($n) = @_;
    return $n * $n;
};

print $square->(5), "\n";  # 25

# Closure — captures lexical variables
sub make_counter {
    my $count = 0;
    return sub { return ++$count };
}

my $counter = make_counter();
print $counter->(), "\n";  # 1
print $counter->(), "\n";  # 2
print $counter->(), "\n";  # 3

# Passing subroutines as arguments
sub apply {
    my ($func, @values) = @_;
    return map { $func->($_) } @values;
}

my @squares = apply(sub { $_[0] ** 2 }, 1, 2, 3, 4);
print "@squares\n";  # 1 4 9 16
```

See: [`examples/04-subroutines/basic_subs.pl`](examples/04-subroutines/basic_subs.pl),
[`examples/04-subroutines/closures.pl`](examples/04-subroutines/closures.pl)

---

## 8. Input and Output

### 8.1 Standard I/O

```perl
# Print to standard output
print "Hello\n";                    # No newline unless specified
print STDOUT "To stdout\n";        # Explicit filehandle
print STDERR "Error message\n";    # Print to stderr

# say — like print but adds a newline (Perl 5.10+)
use feature 'say';
say "Hello";  # Equivalent to: print "Hello\n";

# Read from standard input
print "Enter your name: ";
my $name = <STDIN>;   # Reads one line, including the newline
chomp $name;           # Remove the trailing newline
say "Hello, $name!";

# Read all lines from stdin
my @lines = <STDIN>;
chomp @lines;
```

### 8.2 Formatted Output

```perl
# printf — formatted output
printf("Name: %-15s Age: %3d\n", "Alice", 30);
printf("Pi: %.4f\n", 3.14159);
printf("Hex: 0x%X\n", 255);

# Format specifiers:
# %s  — string
# %d  — integer
# %f  — float
# %e  — scientific notation
# %x  — hexadecimal
# %o  — octal
# %b  — binary
# %%  — literal %
```

---

## 9. File Handling

### 9.1 Opening and Reading Files

```perl
use strict;
use warnings;

# Modern three-argument open (always prefer this)
open(my $fh, '<', 'data.txt')
    or die "Cannot open data.txt: $!\n";

# Read line by line
while (my $line = <$fh>) {
    chomp $line;
    print "Line: $line\n";
}

close($fh);

# Read entire file into an array
open(my $fh2, '<', 'data.txt') or die "Cannot open: $!\n";
my @lines = <$fh2>;
chomp @lines;
close($fh2);

# Read entire file into a string (slurp)
open(my $fh3, '<', 'data.txt') or die "Cannot open: $!\n";
my $content = do { local $/; <$fh3> };
close($fh3);
```

### 9.2 Writing to Files

```perl
# Write mode (overwrites existing file)
open(my $out, '>', 'output.txt') or die "Cannot open: $!\n";
print $out "First line\n";
print $out "Second line\n";
close($out);

# Append mode
open(my $append, '>>', 'output.txt') or die "Cannot open: $!\n";
print $append "Appended line\n";
close($append);
```

### 9.3 File Tests

```perl
my $file = "data.txt";

if (-e $file) { print "File exists\n" }
if (-f $file) { print "Is a regular file\n" }
if (-d $file) { print "Is a directory\n" }
if (-r $file) { print "Is readable\n" }
if (-w $file) { print "Is writable\n" }
if (-z $file) { print "File is empty\n" }
if (-s $file) { print "File size: " . (-s $file) . " bytes\n" }
```

### 9.4 Directory Operations

```perl
# List files in a directory
opendir(my $dh, '.') or die "Cannot open directory: $!\n";
my @files = readdir($dh);
closedir($dh);

# Filter out . and ..
my @real_files = grep { $_ ne '.' && $_ ne '..' } @files;

# Using glob for pattern matching
my @perl_files = glob("*.pl");
my @all_text   = glob("*.txt *.csv");

# Create and remove directories
mkdir("new_dir", 0755) or die "Cannot create dir: $!\n";
rmdir("empty_dir")     or die "Cannot remove dir: $!\n";
```

See: [`examples/05-file-io/read_file.pl`](examples/05-file-io/read_file.pl),
[`examples/05-file-io/write_file.pl`](examples/05-file-io/write_file.pl)

---

## 10. Regular Expressions

Perl's regular expression support is one of its greatest strengths.

### 10.1 Pattern Matching

```perl
my $text = "The quick brown fox jumps over the lazy dog";

# Match with =~ operator
if ($text =~ /quick/) {
    print "Found 'quick'!\n";
}

# Negated match
if ($text !~ /cat/) {
    print "'cat' not found\n";
}

# Case-insensitive match
if ($text =~ /QUICK/i) {
    print "Found (case-insensitive)\n";
}
```

### 10.2 Metacharacters and Character Classes

```perl
# Metacharacters
# .     Any character (except newline)
# ^     Start of string/line
# $     End of string/line
# *     Zero or more
# +     One or more
# ?     Zero or one
# {n}   Exactly n times
# {n,m} Between n and m times
# |     Alternation (OR)

# Character classes
# [abc]   Any of a, b, or c
# [^abc]  Not a, b, or c
# [a-z]   Any lowercase letter
# [0-9]   Any digit

# Shorthand character classes
# \d    Digit [0-9]
# \D    Non-digit
# \w    Word character [a-zA-Z0-9_]
# \W    Non-word character
# \s    Whitespace [ \t\n\r\f]
# \S    Non-whitespace
# \b    Word boundary
```

### 10.3 Capturing Groups

```perl
my $date = "2026-03-20";

if ($date =~ /(\d{4})-(\d{2})-(\d{2})/) {
    my $year  = $1;
    my $month = $2;
    my $day   = $3;
    print "Year: $year, Month: $month, Day: $day\n";
}

# Named captures (Perl 5.10+)
if ($date =~ /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/) {
    print "Year: $+{year}\n";
    print "Month: $+{month}\n";
    print "Day: $+{day}\n";
}

# Non-capturing group
if ($text =~ /(?:quick|slow) brown/) {
    print "Matched!\n";
}
```

### 10.4 Substitution

```perl
my $str = "Hello, World!";

# Basic substitution
(my $new = $str) =~ s/World/Perl/;
print "$new\n";  # "Hello, Perl!"

# Global substitution
my $text = "aaa bbb aaa";
$text =~ s/aaa/xxx/g;  # "xxx bbb xxx"

# Using captured groups in replacement
my $name = "Smith, John";
$name =~ s/(\w+), (\w+)/$2 $1/;
print "$name\n";  # "John Smith"

# Using /e to evaluate replacement as code
my $str2 = "price: 100 dollars and 50 cents";
$str2 =~ s/(\d+)/$1 * 2/ge;
print "$str2\n";  # "price: 200 dollars and 100 cents"
```

### 10.5 Transliteration

```perl
my $str = "Hello, World!";

# tr/SEARCH/REPLACE/ — character-by-character translation
(my $copy = $str) =~ tr/a-z/A-Z/;  # Convert to uppercase
print "$copy\n";  # "HELLO, WORLD!"

# Count characters
my $vowels = ($str =~ tr/aeiouAEIOU//);
print "Vowel count: $vowels\n";  # 3

# Delete characters
(my $no_spaces = $str) =~ tr/ //d;
print "$no_spaces\n";  # "Hello,World!"

# Squeeze repeated characters
my $text = "aaabbbccc";
$text =~ tr/a-c/a-c/s;
print "$text\n";  # "abc"
```

### 10.6 Advanced Regex Features

```perl
# Lookahead and lookbehind
my $text = "foo123bar456baz";

# Positive lookahead: digits followed by "bar"
if ($text =~ /(\d+)(?=bar)/) {
    print "Digits before 'bar': $1\n";  # 123
}

# Positive lookbehind: digits preceded by "bar"
if ($text =~ /(?<=bar)(\d+)/) {
    print "Digits after 'bar': $1\n";   # 456
}

# Greedy vs. non-greedy
my $html = "<b>bold</b> and <i>italic</i>";
$html =~ /<(.+?)>/;   # Non-greedy: captures "b"
$html =~ /<(.+)>/;    # Greedy: captures "b>bold</b> and <i>italic</i"

# Global match in list context
my @numbers = ("abc123def456" =~ /(\d+)/g);
print "@numbers\n";  # 123 456
```

See: [`examples/06-regex/matching.pl`](examples/06-regex/matching.pl),
[`examples/06-regex/substitution.pl`](examples/06-regex/substitution.pl),
[`examples/06-regex/advanced_regex.pl`](examples/06-regex/advanced_regex.pl)

---

## 11. References and Complex Data Structures

References are like pointers in C — they allow you to build complex nested structures.

### 11.1 Creating References

```perl
# Scalar reference
my $name = "Alice";
my $ref = \$name;
print $$ref, "\n";     # "Alice" (dereference with $$)
print ${$ref}, "\n";   # Same thing, clearer syntax

# Array reference
my @colors = ("red", "green", "blue");
my $aref = \@colors;
print $aref->[0], "\n";     # "red" (arrow notation)
print $$aref[1], "\n";      # "green" (sigil notation)

# Hash reference
my %person = (name => "Alice", age => 30);
my $href = \%person;
print $href->{name}, "\n";  # "Alice"

# Anonymous references (create data directly)
my $aref2 = [1, 2, 3, 4, 5];          # Anonymous array ref
my $href2 = {name => "Bob", age => 25}; # Anonymous hash ref
my $cref  = sub { return $_[0] ** 2 };  # Anonymous code ref
```

### 11.2 Complex Data Structures

```perl
# Array of arrays (2D array)
my @matrix = (
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
);
print $matrix[1][2], "\n";  # 6

# Array of hashes
my @employees = (
    { name => "Alice", dept => "Engineering", salary => 95000 },
    { name => "Bob",   dept => "Marketing",   salary => 75000 },
    { name => "Carol", dept => "Engineering", salary => 102000 },
);

for my $emp (@employees) {
    printf "%-10s %-15s \$%d\n", $emp->{name}, $emp->{dept}, $emp->{salary};
}

# Hash of arrays
my %courses = (
    math    => ["Alice", "Bob", "Carol"],
    science => ["Bob", "Dave"],
    english => ["Alice", "Carol", "Eve"],
);

print "Math students: ", join(", ", @{$courses{math}}), "\n";

# Hash of hashes
my %company = (
    engineering => {
        manager => "Alice",
        count   => 15,
        budget  => 500000,
    },
    marketing => {
        manager => "Bob",
        count   => 8,
        budget  => 200000,
    },
);

print "Engineering manager: $company{engineering}{manager}\n";
```

### 11.3 The `ref` Function

```perl
my $scalar_ref = \42;
my $array_ref  = [1, 2, 3];
my $hash_ref   = {a => 1};
my $code_ref   = sub { 1 };

print ref($scalar_ref), "\n";  # SCALAR
print ref($array_ref), "\n";   # ARRAY
print ref($hash_ref), "\n";    # HASH
print ref($code_ref), "\n";    # CODE
```

See: [`examples/07-references/references.pl`](examples/07-references/references.pl),
[`examples/07-references/complex_structures.pl`](examples/07-references/complex_structures.pl)

---

## 12. Object-Oriented Perl

### 12.1 Classic Perl OOP (Blessed References)

In Perl, an object is a reference that has been associated with a class via `bless`.

```perl
package Animal;

sub new {
    my ($class, %args) = @_;
    my $self = {
        name   => $args{name}   // "Unknown",
        sound  => $args{sound}  // "...",
        legs   => $args{legs}   // 4,
    };
    return bless $self, $class;
}

sub name  { return $_[0]->{name} }
sub sound { return $_[0]->{sound} }
sub legs  { return $_[0]->{legs} }

sub speak {
    my ($self) = @_;
    printf "%s says %s!\n", $self->name(), $self->sound();
}

sub describe {
    my ($self) = @_;
    printf "%s has %d legs\n", $self->name(), $self->legs();
}

1;  # Modules must return a true value
```

**Using the class:**

```perl
use strict;
use warnings;

my $dog = Animal->new(name => "Rex", sound => "Woof", legs => 4);
my $cat = Animal->new(name => "Whiskers", sound => "Meow");

$dog->speak();     # Rex says Woof!
$cat->describe();  # Whiskers has 4 legs
```

### 12.2 Inheritance

```perl
package Dog;
use parent 'Animal';  # Inherit from Animal

sub new {
    my ($class, %args) = @_;
    $args{sound} //= "Woof";
    $args{legs}  //= 4;
    my $self = $class->SUPER::new(%args);
    $self->{tricks} = $args{tricks} // [];
    return $self;
}

sub learn_trick {
    my ($self, $trick) = @_;
    push @{$self->{tricks}}, $trick;
}

sub show_tricks {
    my ($self) = @_;
    my @tricks = @{$self->{tricks}};
    if (@tricks) {
        printf "%s knows: %s\n", $self->name(), join(", ", @tricks);
    } else {
        printf "%s doesn't know any tricks yet\n", $self->name();
    }
}

1;
```

### 12.3 Accessor Generation with Getters/Setters

```perl
package Person;

sub new {
    my ($class, %args) = @_;
    return bless {
        name  => $args{name},
        age   => $args{age},
        email => $args{email},
    }, $class;
}

# Combined getter/setter
sub name {
    my ($self, $new_val) = @_;
    $self->{name} = $new_val if defined $new_val;
    return $self->{name};
}

sub age {
    my ($self, $new_val) = @_;
    $self->{age} = $new_val if defined $new_val;
    return $self->{age};
}

1;
```

Usage:

```perl
my $p = Person->new(name => "Alice", age => 30);
print $p->name(), "\n";   # Alice (getter)
$p->name("Bob");           # (setter)
print $p->name(), "\n";   # Bob
```

See: [`examples/08-oop/animal.pl`](examples/08-oop/animal.pl),
[`examples/08-oop/inheritance.pl`](examples/08-oop/inheritance.pl)

---

## 13. Modules and Packages

### 13.1 Using Modules

```perl
# Load a module
use File::Basename;          # Functions for parsing file paths
use File::Path qw(make_path); # Import specific functions
use Cwd;                     # Current working directory
use POSIX qw(strftime);     # POSIX functions

# Load at runtime (conditional)
require Data::Dumper;

# Using module functions
my $filename = basename("/home/user/file.txt");  # "file.txt"
my $dirname  = dirname("/home/user/file.txt");   # "/home/user"
my $cwd = getcwd();
my $date = strftime("%Y-%m-%d %H:%M:%S", localtime);
```

### 13.2 Creating Your Own Module

Create a file `MathUtils.pm`:

```perl
package MathUtils;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(factorial fibonacci is_prime);

sub factorial {
    my ($n) = @_;
    return 1 if $n <= 1;
    return $n * factorial($n - 1);
}

sub fibonacci {
    my ($n) = @_;
    my @fib = (0, 1);
    for my $i (2 .. $n) {
        push @fib, $fib[-1] + $fib[-2];
    }
    return @fib[0 .. $n];
}

sub is_prime {
    my ($n) = @_;
    return 0 if $n < 2;
    for my $i (2 .. int(sqrt($n))) {
        return 0 if $n % $i == 0;
    }
    return 1;
}

1;
```

Use the module:

```perl
use MathUtils qw(factorial fibonacci is_prime);

print "5! = ", factorial(5), "\n";                # 120
print "Fib: ", join(", ", fibonacci(10)), "\n";   # 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55
print "7 is prime? ", is_prime(7) ? "Yes" : "No", "\n";  # Yes
```

### 13.3 Useful Built-in Modules

```perl
# Data::Dumper — debug/inspect data structures
use Data::Dumper;
my %data = (name => "Alice", scores => [90, 85, 92]);
print Dumper(\%data);

# Storable — serialize/deserialize data
use Storable qw(store retrieve);
store(\%data, 'data.dat');
my $loaded = retrieve('data.dat');

# Getopt::Long — command-line argument parsing
use Getopt::Long;
my ($verbose, $output, $count);
GetOptions(
    'verbose|v' => \$verbose,
    'output|o=s' => \$output,
    'count|c=i'  => \$count,
);

# JSON — JSON encoding/decoding (may need to install)
use JSON;
my $json_str = encode_json({name => "Alice", age => 30});
my $data_ref = decode_json($json_str);

# File::Slurp — read/write files easily
# use File::Slurp;
# my $text = read_file('input.txt');
# write_file('output.txt', $text);
```

See: [`examples/09-modules/math_utils_demo.pl`](examples/09-modules/math_utils_demo.pl),
[`examples/09-modules/MathUtils.pm`](examples/09-modules/MathUtils.pm)

---

## 14. Error Handling

### 14.1 Basic Error Handling

```perl
# die — terminate with an error message
open(my $fh, '<', 'nonexistent.txt')
    or die "Cannot open file: $!\n";
# $! contains the system error message

# warn — print a warning without terminating
warn "This might be a problem\n";

# Catching errors with eval
eval {
    my $result = 10 / 0;
};
if ($@) {
    print "Caught an error: $@\n";
}
```

### 14.2 Custom Error Handling

```perl
# Using die with references for structured errors
eval {
    die {
        type    => "ValidationError",
        message => "Invalid email format",
        field   => "email",
    };
};
if (my $err = $@) {
    if (ref $err eq 'HASH') {
        printf "Error [%s]: %s (field: %s)\n",
            $err->{type}, $err->{message}, $err->{field};
    } else {
        print "Error: $err\n";
    }
}

# Try::Tiny style (common CPAN module pattern)
# use Try::Tiny;
# try {
#     dangerous_operation();
# } catch {
#     warn "Caught error: $_";
# } finally {
#     cleanup();
# };
```

### 14.3 Error Handling Best Practices

```perl
# Always check return values of system calls
open(my $fh, '<', $filename)
    or die "Cannot open '$filename': $!\n";

chdir($directory)
    or die "Cannot change to '$directory': $!\n";

system("some_command") == 0
    or die "Command failed with status: $?\n";

# Use autodie for automatic error checking (Perl 5.10.1+)
use autodie;  # open, close, chdir, etc. will die on failure automatically

open(my $fh, '<', 'file.txt');  # No need for "or die" — autodie handles it
```

See: [`examples/10-error-handling/error_handling.pl`](examples/10-error-handling/error_handling.pl)

---

## 15. Advanced Topics

### 15.1 Map, Grep, and Sort

```perl
my @numbers = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

# map — transform each element
my @doubled = map { $_ * 2 } @numbers;      # (2,4,6,8,10,12,14,16,18,20)
my @squared = map { $_ ** 2 } @numbers;     # (1,4,9,16,25,36,49,64,81,100)

# grep — filter elements
my @evens = grep { $_ % 2 == 0 } @numbers;  # (2,4,6,8,10)
my @big   = grep { $_ > 5 } @numbers;       # (6,7,8,9,10)

# sort — custom sorting
my @sorted_num = sort { $a <=> $b } @numbers;  # Numeric ascending
my @sorted_desc = sort { $b <=> $a } @numbers; # Numeric descending
my @sorted_str = sort { lc($a) cmp lc($b) } @words; # Case-insensitive

# Chaining operations
my @result = sort { $a <=> $b }
             grep { $_ % 2 == 0 }
             map  { $_ ** 2 }
             @numbers;
# Squares of numbers, keep even ones, sort ascending
# (4, 16, 36, 64, 100)

# Schwartzian transform (efficient sort with computed keys)
my @files = ("file10.txt", "file2.txt", "file1.txt", "file20.txt");
my @natural_sorted =
    map  { $_->[0] }
    sort { $a->[1] <=> $b->[1] }
    map  { [$_, /(\d+)/] }
    @files;
# ("file1.txt", "file2.txt", "file10.txt", "file20.txt")
```

### 15.2 Dispatch Tables

```perl
my %dispatch = (
    add      => sub { $_[0] + $_[1] },
    subtract => sub { $_[0] - $_[1] },
    multiply => sub { $_[0] * $_[1] },
    divide   => sub { $_[1] != 0 ? $_[0] / $_[1] : "Error: division by zero" },
);

my $operation = "add";
my $result = $dispatch{$operation}->(10, 5);
print "Result: $result\n";  # 15
```

### 15.3 One-Liners

Perl is famous for powerful one-liners run from the command line:

```bash
# Print lines matching a pattern (like grep)
perl -ne 'print if /pattern/' file.txt

# In-place substitution (like sed)
perl -pi -e 's/old/new/g' file.txt

# Print specific fields (like awk)
perl -lane 'print $F[2]' file.txt

# Sum numbers in a file
perl -lane '$sum += $F[0]; END { print $sum }' numbers.txt

# Count lines (like wc -l)
perl -lne 'END { print $. }' file.txt

# Remove duplicate lines (preserving order)
perl -ne 'print unless $seen{$_}++' file.txt

# Print lines between two patterns
perl -ne 'print if /START/../END/' file.txt

# Convert CSV to TSV
perl -pe 's/,/\t/g' data.csv > data.tsv

# Reverse lines in a file
perl -e 'print reverse <>' file.txt

# Generate a random password
perl -le 'print map { ("a".."z","A".."Z",0..9)[rand 62] } 1..16'
```

### 15.4 Working with Dates and Times

```perl
use POSIX qw(strftime);
use Time::Piece;

# Current time
my $now = localtime;
print "Current time: $now\n";

# Formatted output
print strftime("%Y-%m-%d %H:%M:%S", localtime), "\n";

# Time::Piece (core module since Perl 5.10)
my $t = localtime;
print $t->ymd, "\n";        # 2026-03-20
print $t->hms, "\n";        # 14:30:00
print $t->epoch, "\n";      # Unix timestamp
print $t->day_of_week, "\n"; # 0=Sunday

# Date arithmetic
my $tomorrow = $t + 86400;  # Add one day (in seconds)
print "Tomorrow: ", $tomorrow->ymd, "\n";

# Parse a date string
my $parsed = Time::Piece->strptime("2026-03-20", "%Y-%m-%d");
print "Parsed: ", $parsed->strftime("%B %d, %Y"), "\n";  # March 20, 2026
```

### 15.5 System Interaction

```perl
# Execute system commands
system("ls -la");                      # Runs command, returns exit status
my $output = `date`;                   # Backticks capture output
my $output2 = qx(uname -a);           # qx() is equivalent to backticks

# Environment variables
my $home = $ENV{HOME};
my $path = $ENV{PATH};

# Process management
my $pid = fork();
if ($pid == 0) {
    # Child process
    exec("sleep", "5");
} else {
    # Parent process
    waitpid($pid, 0);
}

# Signal handling
$SIG{INT} = sub { print "\nCaught Ctrl+C!\n"; exit 0 };
$SIG{TERM} = sub { print "Terminating gracefully\n"; exit 0 };
```

---

## 16. Practical Projects

These complete, runnable projects demonstrate real-world Perl usage.

### 16.1 Log File Analyzer

Parses web server log files, extracts statistics, and generates reports.

See: [`examples/11-practical-projects/log_analyzer.pl`](examples/11-practical-projects/log_analyzer.pl)

### 16.2 CSV Data Processor

Reads, transforms, filters, and writes CSV data with support for various operations.

See: [`examples/11-practical-projects/csv_processor.pl`](examples/11-practical-projects/csv_processor.pl)

### 16.3 System Monitor

Monitors system resources (CPU, memory, disk) and reports on threshold violations.

See: [`examples/11-practical-projects/system_monitor.pl`](examples/11-practical-projects/system_monitor.pl)

### 16.4 Text Statistics Tool

Analyzes text files for word frequency, readability metrics, and more.

See: [`examples/11-practical-projects/text_stats.pl`](examples/11-practical-projects/text_stats.pl)

### 16.5 Simple Task Manager (To-Do List)

A command-line task manager with persistent file storage.

See: [`examples/11-practical-projects/task_manager.pl`](examples/11-practical-projects/task_manager.pl)

---

## 17. Best Practices

### Code Quality

```perl
use strict;          # Always
use warnings;        # Always
use utf8;            # If using Unicode in source
use feature 'say';   # Convenient output
use autodie;         # Auto-check system calls
```

### Style Guidelines

- Use **4-space indentation** (or consistent tab usage)
- Use **meaningful variable names** (`$customer_name`, not `$cn`)
- Use **lowercase with underscores** for variables and subroutines (`my_function`)
- Use **CamelCase** for package/module names (`MyModule`)
- Keep subroutines short and focused (under ~50 lines)
- Use the **three-argument form of `open`**: `open(my $fh, '<', $file)`

### Documentation with POD

```perl
=head1 NAME

MyModule - A brief description of the module

=head1 SYNOPSIS

    use MyModule;
    my $obj = MyModule->new();
    $obj->do_something();

=head1 DESCRIPTION

A longer description of what this module does.

=head1 METHODS

=head2 new

    my $obj = MyModule->new(%options);

Creates a new MyModule object.

=head2 do_something

    $obj->do_something($arg);

Does something with the given argument.

=head1 AUTHOR

Your Name <your.email@example.com>

=cut
```

### Testing

```perl
# Using Test::More (core module)
use Test::More tests => 3;

is(1 + 1, 2, "basic addition works");
ok(defined $result, "result is defined");
like($string, qr/expected/, "string matches pattern");

# Run tests: perl t/my_test.t
# Or:        prove t/
```

### Security

- Always use **taint mode** (`perl -T`) for CGI/web scripts
- Validate and sanitize all user input
- Use **parameterized queries** for database operations
- Never use user input directly in `system()`, `eval()`, or backticks

---

## Resources

- **Official Documentation:** `perldoc perl` or [perldoc.perl.org](https://perldoc.perl.org/)
- **CPAN:** [metacpan.org](https://metacpan.org/) — Search and browse Perl modules
- **Learn Perl:** [learn.perl.org](https://learn.perl.org/)
- **Perl Maven:** [perlmaven.com](https://perlmaven.com/)
- **Books:**
  - *Learning Perl* (the "Llama book") by Randal L. Schwartz
  - *Programming Perl* (the "Camel book") by Larry Wall
  - *Modern Perl* by chromatic (free online at [modernperlbooks.com](http://modernperlbooks.com/))
  - *Perl Cookbook* by Tom Christiansen and Nathan Torkington

---

## License

This tutorial is released under the [MIT License](LICENSE). Feel free to use, modify, and
share it.
