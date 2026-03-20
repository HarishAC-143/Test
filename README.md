# Perl Programming Tutorial: From Basics to Advanced

A comprehensive, hands-on tutorial covering Perl programming from fundamentals through advanced topics. Each section includes clear explanations and runnable example scripts in the [`examples/`](examples/) directory.

---

## Table of Contents

1. [Introduction to Perl](#1-introduction-to-perl)
2. [Setting Up Perl](#2-setting-up-perl)
3. [Your First Perl Program](#3-your-first-perl-program)
4. [Variables and Data Types](#4-variables-and-data-types)
5. [Operators](#5-operators)
6. [Control Structures](#6-control-structures)
7. [Loops](#7-loops)
8. [Strings and String Functions](#8-strings-and-string-functions)
9. [Arrays](#9-arrays)
10. [Hashes](#10-hashes)
11. [Subroutines (Functions)](#11-subroutines-functions)
12. [Regular Expressions](#12-regular-expressions)
13. [File I/O](#13-file-io)
14. [Error Handling](#14-error-handling)
15. [References and Complex Data Structures](#15-references-and-complex-data-structures)
16. [Object-Oriented Perl](#16-object-oriented-perl)
17. [Modules and Packages](#17-modules-and-packages)
18. [Database Access with DBI](#18-database-access-with-dbi)
19. [Working with JSON and APIs](#19-working-with-json-and-apis)
20. [Advanced Regular Expressions](#20-advanced-regular-expressions)
21. [Process Management and System Interaction](#21-process-management-and-system-interaction)
22. [Best Practices and Coding Standards](#22-best-practices-and-coding-standards)
23. [Practical Projects](#23-practical-projects)

---

## 1. Introduction to Perl

Perl (Practical Extraction and Reporting Language) is a high-level, general-purpose programming language created by Larry Wall in 1987. It excels at:

- **Text processing** and pattern matching via powerful regular expressions
- **System administration** scripting
- **Web development** (CGI, modern frameworks like Mojolicious and Dancer)
- **Bioinformatics** and data analysis
- **Network programming**
- **Rapid prototyping**

Perl's motto is *"There's more than one way to do it"* (TMTOWTDI), giving programmers freedom to choose the approach that best fits the problem.

### Key Features

| Feature | Description |
|---|---|
| Dynamic typing | Variables don't need type declarations |
| Automatic memory management | Garbage collection via reference counting |
| CPAN | Over 200,000 modules available on the Comprehensive Perl Archive Network |
| Cross-platform | Runs on Unix/Linux, Windows, macOS, and more |
| C integration | XS interface for calling C code |
| Unicode support | Full native Unicode handling |

---

## 2. Setting Up Perl

### Check if Perl Is Installed

```bash
perl -v
```

### Installing Perl

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install perl
```

**macOS:** Perl comes pre-installed. For the latest version use [Homebrew](https://brew.sh/):
```bash
brew install perl
```

**Windows:** Install [Strawberry Perl](https://strawberryperl.com/) or [ActivePerl](https://www.activestate.com/products/perl/).

### Running Perl Scripts

```bash
# Run a script file
perl script.pl

# Run a one-liner
perl -e 'print "Hello, World!\n"'
```

---

## 3. Your First Perl Program

```perl
#!/usr/bin/perl
use strict;
use warnings;

print "Hello, World!\n";
```

### Line-by-line Breakdown

| Line | Purpose |
|---|---|
| `#!/usr/bin/perl` | Shebang line — tells the OS which interpreter to use |
| `use strict;` | Enforces good coding practices (must declare variables, etc.) |
| `use warnings;` | Enables helpful warning messages |
| `print "Hello, World!\n";` | Outputs text to the terminal; `\n` is a newline |

> **Rule of thumb:** Always start every script with `use strict;` and `use warnings;`.

---

## 4. Variables and Data Types

Perl has three main variable types, each identified by a **sigil** (prefix character).

### 4.1 Scalars (`$`)

A scalar holds a single value — a number, a string, or a reference.

```perl
my $name   = "Alice";       # string
my $age    = 30;             # integer
my $pi     = 3.14159;       # floating-point
my $active = 1;              # boolean-like (truthy)
```

Perl converts between strings and numbers automatically based on context:

```perl
my $x = "42";       # string "42"
my $y = $x + 8;     # $y is now 50 (numeric context)
my $z = $y . " kg"; # $z is "50 kg" (string context)
```

### 4.2 Arrays (`@`)

An ordered list of scalars, zero-indexed.

```perl
my @colors = ("red", "green", "blue");
print $colors[0];    # "red" — use $ for a single element
print scalar @colors; # 3 — number of elements
```

### 4.3 Hashes (`%`)

An unordered set of key-value pairs.

```perl
my %capital = (
    "France"  => "Paris",
    "Japan"   => "Tokyo",
    "Germany" => "Berlin",
);
print $capital{"Japan"};  # "Tokyo"
```

### 4.4 Special Variables

Perl has many built-in special variables:

| Variable | Meaning |
|---|---|
| `$_` | Default variable (used by many built-in functions) |
| `@_` | Subroutine arguments |
| `$0` | Name of the running script |
| `@ARGV` | Command-line arguments |
| `%ENV` | Environment variables |
| `$!` | System error message |
| `$/` | Input record separator (default: newline) |
| `$\` | Output record separator |

---

## 5. Operators

### 5.1 Arithmetic Operators

```perl
my $a = 15;
my $b = 4;

print $a + $b, "\n";   # 19  — addition
print $a - $b, "\n";   # 11  — subtraction
print $a * $b, "\n";   # 60  — multiplication
print $a / $b, "\n";   # 3.75 — division
print $a % $b, "\n";   # 3   — modulus
print $a ** $b, "\n";  # 50625 — exponentiation
```

### 5.2 String Operators

```perl
my $first = "Hello";
my $last  = "World";

print $first . " " . $last, "\n";   # Concatenation: "Hello World"
print $first x 3, "\n";             # Repetition: "HelloHelloHello"
```

### 5.3 Comparison Operators

| Numeric | String | Meaning |
|---|---|---|
| `==` | `eq` | Equal |
| `!=` | `ne` | Not equal |
| `<` | `lt` | Less than |
| `>` | `gt` | Greater than |
| `<=` | `le` | Less than or equal |
| `>=` | `ge` | Greater than or equal |
| `<=>` | `cmp` | Spaceship / three-way comparison |

```perl
print "equal\n" if 5 == 5;
print "equal\n" if "abc" eq "abc";
```

### 5.4 Logical Operators

```perl
# Symbolic          # English equivalents
&& and              and
|| or               or
!  not              not

# Short-circuit example
my $name = $input || "default";

# Defined-or operator (//) — Perl 5.10+
my $val = $maybe_undef // "fallback";
```

---

## 6. Control Structures

### 6.1 if / elsif / else

```perl
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
```

### 6.2 unless (Negated if)

```perl
my $logged_in = 0;
unless ($logged_in) {
    print "Please log in.\n";
}
```

### 6.3 given / when (Switch — Perl 5.10+)

```perl
use feature 'say';

my $day = "Monday";

if ($day eq "Monday")    { say "Start of work week" }
elsif ($day eq "Friday") { say "Almost weekend!" }
elsif ($day eq "Sunday") { say "Rest day" }
else                     { say "Regular day" }
```

### 6.4 Ternary Operator

```perl
my $age = 20;
my $status = ($age >= 18) ? "adult" : "minor";
print "Status: $status\n";
```

### 6.5 Postfix Conditionals

```perl
print "It's hot!\n" if $temp > 100;
print "It's cold!\n" unless $temp > 50;
```

---

## 7. Loops

### 7.1 for / foreach

```perl
# C-style for loop
for (my $i = 0; $i < 5; $i++) {
    print "i = $i\n";
}

# foreach (idiomatic Perl)
my @fruits = ("apple", "banana", "cherry");
foreach my $fruit (@fruits) {
    print "Fruit: $fruit\n";
}

# foreach with default variable $_
for (@fruits) {
    print "I like $_\n";
}
```

### 7.2 while / until

```perl
my $count = 5;
while ($count > 0) {
    print "Countdown: $count\n";
    $count--;
}

my $n = 1;
until ($n > 5) {
    print "n = $n\n";
    $n++;
}
```

### 7.3 do...while

```perl
my $input;
do {
    print "Enter 'quit' to exit: ";
    $input = <STDIN>;
    chomp $input;
} while ($input ne "quit");
```

### 7.4 Loop Control

```perl
for my $i (1..20) {
    next if $i % 2 == 0;   # skip even numbers
    last if $i > 15;        # stop after 15
    print "$i\n";
}

# redo — restarts the current iteration without re-checking the condition
# Labels — for controlling nested loops
OUTER: for my $i (1..3) {
    for my $j (1..3) {
        next OUTER if $j == 2;
        print "i=$i j=$j\n";
    }
}
```

---

## 8. Strings and String Functions

### 8.1 Quoting

```perl
my $name = "World";

# Double quotes — interpolation happens
print "Hello, $name!\n";          # Hello, World!

# Single quotes — literal text
print 'Hello, $name!\n';          # Hello, $name!\n

# Heredoc
my $text = <<END_TEXT;
Dear $name,
This is a multi-line string.
END_TEXT

# Heredoc with indentation (Perl 5.26+)
my $indented = <<~END;
    This text
    is indented neatly.
    END
```

### 8.2 Common String Functions

```perl
my $str = "  Hello, Perl World!  ";

print length($str), "\n";              # 23
print uc($str), "\n";                  # "  HELLO, PERL WORLD!  "
print lc($str), "\n";                  # "  hello, perl world!  "
print ucfirst("hello"), "\n";          # "Hello"
print lcfirst("HELLO"), "\n";          # "hELLO"

# Trimming (no built-in trim; use regex)
(my $trimmed = $str) =~ s/^\s+|\s+$//g;
print "[$trimmed]\n";                  # [Hello, Perl World!]

# Substring
print substr($str, 2, 5), "\n";       # "Hello"

# Index / Rindex
print index($str, "Perl"), "\n";      # 9
print rindex($str, "l"), "\n";        # 20

# Reverse
print reverse("abcde"), "\n";         # "edcba"

# Split and Join
my @words = split(/,\s*/, "a, b, c");
my $joined = join(" | ", @words);      # "a | b | c"
```

---

## 9. Arrays

### 9.1 Creating and Accessing

```perl
my @nums = (1, 2, 3, 4, 5);
my @mixed = ("hello", 42, 3.14, undef);

print $nums[0], "\n";       # 1 (first element)
print $nums[-1], "\n";      # 5 (last element)
print $nums[$#nums], "\n";  # 5 ($#array = last index)

# Array slice
my @subset = @nums[1, 3];   # (2, 4)
```

### 9.2 Array Manipulation

```perl
my @arr = (2, 3, 4);

# Add / remove at ends
push @arr, 5, 6;          # @arr = (2, 3, 4, 5, 6)
my $last = pop @arr;       # $last = 6; @arr = (2, 3, 4, 5)
unshift @arr, 0, 1;        # @arr = (0, 1, 2, 3, 4, 5)
my $first = shift @arr;    # $first = 0; @arr = (1, 2, 3, 4, 5)

# Splice — general-purpose insert/remove
splice(@arr, 2, 1);        # remove 1 element at index 2
splice(@arr, 1, 0, 99);    # insert 99 at index 1
```

### 9.3 Sorting

```perl
my @words = ("banana", "apple", "cherry");

# Default lexicographic sort
my @sorted = sort @words;                     # apple, banana, cherry

# Numeric sort
my @numbers = (42, 7, 13, 1);
my @num_sorted = sort { $a <=> $b } @numbers; # 1, 7, 13, 42

# Reverse sort
my @desc = sort { $b <=> $a } @numbers;       # 42, 13, 7, 1

# Case-insensitive sort
my @ci = sort { lc($a) cmp lc($b) } @words;
```

### 9.4 Array Utilities

```perl
# grep — filter elements
my @evens = grep { $_ % 2 == 0 } 1..20;

# map — transform elements
my @squares = map { $_ ** 2 } 1..5;           # (1, 4, 9, 16, 25)

# join
my $csv = join(",", @squares);                 # "1,4,9,16,25"

# Check if element exists
use List::Util 'any';
if (any { $_ eq "apple" } @words) {
    print "Found apple!\n";
}
```

---

## 10. Hashes

### 10.1 Creating and Accessing

```perl
my %ages = (
    Alice => 30,
    Bob   => 25,
    Carol => 28,
);

print $ages{"Alice"}, "\n";       # 30
$ages{"Dave"} = 35;               # add a new pair
delete $ages{"Bob"};              # remove a pair
```

### 10.2 Iterating

```perl
# keys / values
foreach my $name (sort keys %ages) {
    print "$name is $ages{$name} years old\n";
}

# each — returns (key, value) pairs
while (my ($k, $v) = each %ages) {
    print "$k => $v\n";
}
```

### 10.3 Hash Utilities

```perl
# Check if a key exists
if (exists $ages{"Alice"}) {
    print "Alice is in the hash\n";
}

# Check if a value is defined
if (defined $ages{"Alice"}) {
    print "Alice's age is defined\n";
}

# Hash slice
my @some_ages = @ages{"Alice", "Carol"};   # (30, 28)

# Merge hashes (later values win)
my %defaults = (color => "red", size => "medium");
my %custom   = (size => "large", weight => "heavy");
my %merged   = (%defaults, %custom);
# %merged = (color => "red", size => "large", weight => "heavy")

# Invert a hash
my %age_to_name = reverse %ages;
```

---

## 11. Subroutines (Functions)

### 11.1 Declaring and Calling

```perl
sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

print greet("Alice"), "\n";
```

### 11.2 Parameter Handling

```perl
# Multiple parameters
sub add {
    my ($a, $b) = @_;
    return $a + $b;
}

# Default values
sub connect {
    my (%opts) = @_;
    my $host = $opts{host} // "localhost";
    my $port = $opts{port} // 3306;
    print "Connecting to $host:$port\n";
}
connect(host => "db.example.com", port => 5432);

# Variable-length argument list
sub sum {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}
print sum(1, 2, 3, 4, 5), "\n";   # 15
```

### 11.3 Returning Multiple Values

```perl
sub min_max {
    my @sorted = sort { $a <=> $b } @_;
    return ($sorted[0], $sorted[-1]);
}

my ($min, $max) = min_max(5, 3, 9, 1, 7);
print "Min: $min, Max: $max\n";   # Min: 1, Max: 9
```

### 11.4 Anonymous Subroutines and Closures

```perl
# Anonymous sub stored in a scalar
my $square = sub { return $_[0] ** 2 };
print $square->(5), "\n";   # 25

# Closure — captures outer variable
sub make_counter {
    my $count = 0;
    return sub { return ++$count };
}
my $counter = make_counter();
print $counter->(), "\n";   # 1
print $counter->(), "\n";   # 2
print $counter->(), "\n";   # 3
```

---

## 12. Regular Expressions

Perl's regex engine is one of the most powerful and is the inspiration for regex in Python, Ruby, JavaScript, and PCRE.

### 12.1 Matching (`=~` and `m//`)

```perl
my $text = "The quick brown fox jumps over the lazy dog";

if ($text =~ /quick/) {
    print "Found 'quick'\n";
}

# Case-insensitive match
if ($text =~ /QUICK/i) {
    print "Found (case-insensitive)\n";
}

# Capture groups
if ($text =~ /(\w+)\s+fox/) {
    print "The word before 'fox' is: $1\n";   # brown
}
```

### 12.2 Substitution (`s///`)

```perl
my $str = "Hello World";
$str =~ s/World/Perl/;
print "$str\n";   # "Hello Perl"

# Global replacement
my $csv = "a,b,c,d";
$csv =~ s/,/ | /g;
print "$csv\n";   # "a | b | c | d"
```

### 12.3 Common Patterns

```perl
# Email validation (simplified)
my $email = 'user@example.com';
if ($email =~ /^[\w.+-]+\@[\w.-]+\.\w{2,}$/) {
    print "Valid email\n";
}

# Extract all numbers
my $data = "Order 42: 3 items at $9.99 each";
my @numbers = ($data =~ /(\d+\.?\d*)/g);
print join(", ", @numbers), "\n";   # 42, 3, 9.99

# Split on regex
my @sentences = split /\.\s*/, "Hello. World. Perl is great.";
```

### 12.4 Regex Modifiers

| Modifier | Meaning |
|---|---|
| `i` | Case-insensitive |
| `g` | Global (all matches) |
| `m` | Multi-line (`^`/`$` match line boundaries) |
| `s` | Single-line (`.` matches `\n`) |
| `x` | Extended (allows whitespace and comments) |

```perl
# Extended mode for readable regex
if ($text =~ /
    (\w+)     # capture a word
    \s+       # whitespace
    fox       # literal "fox"
/x) {
    print "Matched: $1\n";
}
```

---

## 13. File I/O

### 13.1 Reading Files

```perl
# Open and read line by line
open(my $fh, '<', 'input.txt') or die "Cannot open: $!";
while (my $line = <$fh>) {
    chomp $line;
    print "Line: $line\n";
}
close($fh);

# Slurp entire file into a string
open(my $fh, '<', 'input.txt') or die "Cannot open: $!";
my $content = do { local $/; <$fh> };
close($fh);

# Read into an array (one line per element)
open(my $fh, '<', 'input.txt') or die "Cannot open: $!";
my @lines = <$fh>;
chomp @lines;
close($fh);
```

### 13.2 Writing Files

```perl
# Write (overwrite)
open(my $fh, '>', 'output.txt') or die "Cannot open: $!";
print $fh "First line\n";
print $fh "Second line\n";
close($fh);

# Append
open(my $fh, '>>', 'log.txt') or die "Cannot open: $!";
print $fh "Log entry: " . localtime() . "\n";
close($fh);
```

### 13.3 File Tests

```perl
my $file = "data.txt";

print "Exists\n"     if -e $file;
print "Is a file\n"  if -f $file;
print "Is a dir\n"   if -d $file;
print "Readable\n"   if -r $file;
print "Writable\n"   if -w $file;
print "Non-empty\n"  if -s $file;    # returns size in bytes

my $size = -s $file;
print "Size: $size bytes\n";
```

### 13.4 Directory Operations

```perl
# List directory contents
opendir(my $dh, '.') or die "Cannot open directory: $!";
my @files = readdir($dh);
closedir($dh);

# Filter only .pl files
my @scripts = grep { /\.pl$/ } @files;

# Using glob
my @txt_files = glob("*.txt");

# Create / remove directories
use File::Path qw(make_path remove_tree);
make_path("path/to/new/dir");
remove_tree("path/to/old/dir");
```

---

## 14. Error Handling

### 14.1 die and warn

```perl
# die — terminate with an error message
open(my $fh, '<', 'missing.txt') or die "Cannot open file: $!\n";

# warn — print warning but continue
warn "This might be a problem\n";
```

### 14.2 eval for Exception Handling

```perl
eval {
    my $result = 10 / 0;
    print "Result: $result\n";
};
if ($@) {
    print "Caught error: $@\n";
}
```

### 14.3 Try::Tiny (CPAN Module)

```perl
use Try::Tiny;

try {
    die "Something went wrong!";
} catch {
    print "Error: $_\n";
} finally {
    print "Cleanup code runs here\n";
};
```

### 14.4 Custom Exception Objects

```perl
package Exception;
sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}
sub message { return $_[0]->{message} }
sub throw {
    my ($class, %args) = @_;
    die $class->new(%args);
}

package main;
eval {
    Exception->throw(message => "Disk full", code => 507);
};
if (ref $@ && $@->isa('Exception')) {
    print "Caught: ", $@->message(), "\n";
}
```

---

## 15. References and Complex Data Structures

References are Perl's mechanism for creating complex, nested data structures.

### 15.1 Creating References

```perl
# Scalar reference
my $name = "Alice";
my $ref  = \$name;
print $$ref, "\n";           # "Alice" (dereference)

# Array reference
my @nums = (1, 2, 3);
my $aref = \@nums;
print $aref->[0], "\n";      # 1

# Anonymous array reference
my $aref2 = [10, 20, 30];

# Hash reference
my %data = (x => 1, y => 2);
my $href = \%data;
print $href->{x}, "\n";      # 1

# Anonymous hash reference
my $href2 = { name => "Bob", age => 25 };
```

### 15.2 Nested Data Structures

```perl
# Array of hashes (common pattern: list of records)
my @students = (
    { name => "Alice", grade => "A", score => 95 },
    { name => "Bob",   grade => "B", score => 82 },
    { name => "Carol", grade => "A", score => 91 },
);

foreach my $s (@students) {
    print "$s->{name}: $s->{grade} ($s->{score})\n";
}

# Hash of arrays
my %courses = (
    math    => ["Alice", "Bob"],
    science => ["Carol", "Dave", "Eve"],
    english => ["Alice", "Carol"],
);

foreach my $course (sort keys %courses) {
    my $students = join(", ", @{$courses{$course}});
    print "$course: $students\n";
}

# Hash of hashes
my %config = (
    database => {
        host => "localhost",
        port => 5432,
        name => "myapp",
    },
    cache => {
        host => "redis.local",
        port => 6379,
    },
);
print "DB Host: $config{database}{host}\n";
```

### 15.3 ref() — Checking Reference Type

```perl
my $aref = [1, 2, 3];
my $href = { a => 1 };
my $sref = \"hello";

print ref($aref), "\n";   # ARRAY
print ref($href), "\n";   # HASH
print ref($sref), "\n";   # SCALAR
```

---

## 16. Object-Oriented Perl

### 16.1 Classic OO (bless-based)

```perl
package Animal;

sub new {
    my ($class, %args) = @_;
    my $self = {
        name  => $args{name}  // "Unknown",
        sound => $args{sound} // "...",
    };
    return bless $self, $class;
}

sub name  { return $_[0]->{name} }
sub sound { return $_[0]->{sound} }

sub speak {
    my ($self) = @_;
    printf "%s says %s!\n", $self->name(), $self->sound();
}

package Dog;
our @ISA = ('Animal');

sub new {
    my ($class, %args) = @_;
    $args{sound} //= "Woof";
    return $class->SUPER::new(%args);
}

sub fetch {
    my ($self) = @_;
    printf "%s fetches the ball!\n", $self->name();
}

package main;

my $dog = Dog->new(name => "Rex");
$dog->speak();    # Rex says Woof!
$dog->fetch();    # Rex fetches the ball!
```

### 16.2 Modern OO with Moo

[Moo](https://metacpan.org/pod/Moo) provides a lightweight, modern OO system.

```perl
package Person;
use Moo;

has name => (is => 'ro', required => 1);
has age  => (is => 'rw', default  => sub { 0 });

sub greet {
    my ($self) = @_;
    return sprintf "Hi, I'm %s, age %d.", $self->name, $self->age;
}

package Employee;
use Moo;
extends 'Person';

has company => (is => 'ro', required => 1);
has salary  => (is => 'rw', default  => sub { 50000 });

sub introduce {
    my ($self) = @_;
    return $self->greet() . " I work at " . $self->company . ".";
}

package main;

my $emp = Employee->new(
    name    => "Alice",
    age     => 30,
    company => "Acme Corp",
    salary  => 80000,
);
print $emp->introduce(), "\n";
```

### 16.3 Roles (with Moo::Role)

Roles are like interfaces with default implementations (similar to traits/mixins).

```perl
package Printable;
use Moo::Role;

requires 'to_string';

sub print_self {
    my ($self) = @_;
    print $self->to_string(), "\n";
}

package Report;
use Moo;
with 'Printable';

has title => (is => 'ro');
has body  => (is => 'ro');

sub to_string {
    my ($self) = @_;
    return sprintf "[%s]\n%s", $self->title, $self->body;
}

package main;
my $r = Report->new(title => "Q1 Sales", body => "Revenue: \$1.2M");
$r->print_self();
```

---

## 17. Modules and Packages

### 17.1 Creating a Module

**File: `lib/MathUtils.pm`**

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

1;   # Modules must return a true value
```

### 17.2 Using a Module

```perl
use lib 'lib';
use MathUtils qw(factorial fibonacci is_prime);

print "5! = ", factorial(5), "\n";                 # 120
print "Fib(8): ", join(", ", fibonacci(8)), "\n";  # 0, 1, 1, 2, 3, 5, 8, 13, 21
print "7 is prime? ", is_prime(7) ? "Yes" : "No", "\n";
```

### 17.3 Installing CPAN Modules

```bash
# Using cpanm (recommended)
cpanm JSON::XS
cpanm Moo
cpanm DBI

# Or using cpan
cpan install JSON::XS
```

---

## 18. Database Access with DBI

DBI is Perl's standard database interface.

```perl
use DBI;

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=test.db", "", "",
    { RaiseError => 1, AutoCommit => 1, PrintError => 0 }
) or die "Connection failed: $DBI::errstr";

# Create table
$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS users (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name  TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    age   INTEGER
)
SQL

# Insert with placeholders (prevents SQL injection)
my $sth = $dbh->prepare("INSERT INTO users (name, email, age) VALUES (?, ?, ?)");
$sth->execute("Alice", "alice@example.com", 30);
$sth->execute("Bob",   "bob@example.com",   25);

# Query
$sth = $dbh->prepare("SELECT * FROM users WHERE age > ?");
$sth->execute(20);
while (my $row = $sth->fetchrow_hashref) {
    print "$row->{name} ($row->{email}), age $row->{age}\n";
}

# Shortcut: selectall_arrayref
my $rows = $dbh->selectall_arrayref(
    "SELECT name, age FROM users ORDER BY age",
    { Slice => {} }
);
for my $row (@$rows) {
    print "$row->{name}: $row->{age}\n";
}

$dbh->disconnect;
```

---

## 19. Working with JSON and APIs

### 19.1 JSON Encoding/Decoding

```perl
use JSON;

my %data = (
    name   => "Alice",
    age    => 30,
    skills => ["Perl", "Python", "SQL"],
);

# Encode to JSON
my $json_text = encode_json(\%data);
print "$json_text\n";

# Decode from JSON
my $decoded = decode_json($json_text);
print "Name: $decoded->{name}\n";
print "Skills: ", join(", ", @{$decoded->{skills}}), "\n";
```

### 19.2 HTTP Requests

```perl
use LWP::UserAgent;
use JSON;

my $ua = LWP::UserAgent->new(timeout => 10);

# GET request
my $response = $ua->get('https://jsonplaceholder.typicode.com/posts/1');
if ($response->is_success) {
    my $post = decode_json($response->decoded_content);
    print "Title: $post->{title}\n";
} else {
    die "Request failed: " . $response->status_line;
}

# POST request
my $res = $ua->post(
    'https://jsonplaceholder.typicode.com/posts',
    Content_Type => 'application/json',
    Content      => encode_json({
        title  => "Test Post",
        body   => "Hello from Perl!",
        userId => 1,
    }),
);
print "Created: ", $res->decoded_content, "\n";
```

---

## 20. Advanced Regular Expressions

### 20.1 Lookaheads and Lookbehinds

```perl
my $text = "foo123bar456baz";

# Positive lookahead: digits followed by "bar"
if ($text =~ /(\d+)(?=bar)/) {
    print "Digits before 'bar': $1\n";   # 123
}

# Negative lookahead: digits NOT followed by "bar"
while ($text =~ /(\d+)(?!bar)/g) {
    print "Digits not before 'bar': $1\n";
}

# Positive lookbehind: digits preceded by "bar"
if ($text =~ /(?<=bar)(\d+)/) {
    print "Digits after 'bar': $1\n";    # 456
}
```

### 20.2 Named Captures

```perl
my $date = "2026-03-20";
if ($date =~ /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/) {
    print "Year: $+{year}, Month: $+{month}, Day: $+{day}\n";
}
```

### 20.3 Non-Greedy Matching

```perl
my $html = '<b>bold</b> and <i>italic</i>';

# Greedy (default) — matches as much as possible
if ($html =~ /<(.+)>/) {
    print "Greedy: $1\n";       # b>bold</b> and <i>italic</i
}

# Non-greedy — matches as little as possible
if ($html =~ /<(.+?)>/) {
    print "Non-greedy: $1\n";   # b
}
```

### 20.4 Code in Regex

```perl
my $text = "banana";
$text =~ s/([aeiou])/uc($1)/ge;
print "$text\n";   # bAnAnA
```

---

## 21. Process Management and System Interaction

### 21.1 Running External Commands

```perl
# system() — runs command, returns exit status
my $exit = system("ls", "-la");
print "Exit status: ", $exit >> 8, "\n";

# Backticks — capture output
my $output = `date`;
chomp $output;
print "Current date: $output\n";

# open with pipe
open(my $pipe, '-|', 'ls', '-1') or die "Cannot pipe: $!";
while (<$pipe>) {
    chomp;
    print "File: $_\n";
}
close($pipe);
```

### 21.2 Environment Variables

```perl
# Read
my $home = $ENV{HOME};
my $path = $ENV{PATH};

# Set (for this process and children)
$ENV{MY_VAR} = "hello";
system("echo \$MY_VAR");   # prints "hello"
```

### 21.3 Signal Handling

```perl
$SIG{INT} = sub {
    print "\nCaught Ctrl+C! Cleaning up...\n";
    exit 0;
};

$SIG{ALRM} = sub { die "Timeout!\n" };
alarm(5);   # set 5-second alarm

eval {
    # long-running operation
    sleep(10);
};
alarm(0);   # cancel alarm
print "Error: $@\n" if $@;
```

---

## 22. Best Practices and Coding Standards

### 22.1 Always Use

```perl
use strict;      # catch common mistakes at compile time
use warnings;    # get helpful runtime warnings
use utf8;        # source code is UTF-8
```

### 22.2 Style Guidelines

- Use **4-space indentation** (no tabs)
- Use **lowercase_with_underscores** for variable and function names
- Use **CamelCase** for package/module names
- Keep subroutines short and focused
- Use descriptive variable names

### 22.3 Security

```perl
# Always use placeholders in SQL queries
$sth = $dbh->prepare("SELECT * FROM users WHERE id = ?");
$sth->execute($user_id);

# Taint mode for user input (-T flag)
#!/usr/bin/perl -T
# Tainted data cannot be used in system calls until untainted

# Validate/sanitize input
if ($input =~ /^(\w{1,50})$/) {
    my $clean = $1;   # untainted via capture
}
```

### 22.4 Performance Tips

```perl
# Use hashes for lookups instead of grep on arrays
my %valid = map { $_ => 1 } @valid_items;
if ($valid{$item}) { ... }

# Precompile regex used in loops
my $pattern = qr/^\d{4}-\d{2}-\d{2}$/;
for my $date (@dates) {
    next unless $date =~ $pattern;
}

# Use Benchmark to measure
use Benchmark qw(cmpthese);
cmpthese(100000, {
    concat => sub { my $s = "a" . "b" . "c" },
    interp => sub { my $s = "abc" },
});
```

---

## 23. Practical Projects

The [`examples/`](examples/) directory contains complete, runnable scripts demonstrating each concept. Here is a summary:

| File | Description |
|---|---|
| [`01_hello.pl`](examples/01_hello.pl) | Hello World and basic I/O |
| [`02_variables.pl`](examples/02_variables.pl) | Scalars, arrays, and hashes |
| [`03_control_flow.pl`](examples/03_control_flow.pl) | Conditionals and loops |
| [`04_subroutines.pl`](examples/04_subroutines.pl) | Functions, closures, and callbacks |
| [`05_regex.pl`](examples/05_regex.pl) | Regular expressions |
| [`06_file_io.pl`](examples/06_file_io.pl) | File reading, writing, and directory ops |
| [`07_references.pl`](examples/07_references.pl) | References and nested data structures |
| [`08_oop.pl`](examples/08_oop.pl) | Object-oriented programming |
| [`09_text_analyzer.pl`](examples/09_text_analyzer.pl) | Practical project: Text file analyzer |
| [`10_csv_processor.pl`](examples/10_csv_processor.pl) | Practical project: CSV data processor |
| [`11_log_parser.pl`](examples/11_log_parser.pl) | Practical project: Log file parser |
| [`12_web_scraper.pl`](examples/12_web_scraper.pl) | Practical project: Simple web content fetcher |
| [`13_todo_app.pl`](examples/13_todo_app.pl) | Practical project: Command-line TODO manager |

---

## License

This tutorial is released under the [MIT License](LICENSE). Feel free to use, modify, and share.
