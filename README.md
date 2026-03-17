# Comprehensive Perl Programming Tutorial

A hands-on guide to learning Perl programming from the ground up, with practical examples and clear explanations.

## Table of Contents

1. [Introduction to Perl](#1-introduction-to-perl)
2. [Setting Up Perl](#2-setting-up-perl)
3. [Hello World and Basic Syntax](#3-hello-world-and-basic-syntax)
4. [Variables and Data Types](#4-variables-and-data-types)
5. [Operators](#5-operators)
6. [Control Structures](#6-control-structures)
7. [Loops](#7-loops)
8. [Strings and String Operations](#8-strings-and-string-operations)
9. [Arrays](#9-arrays)
10. [Hashes](#10-hashes)
11. [Subroutines (Functions)](#11-subroutines-functions)
12. [Regular Expressions](#12-regular-expressions)
13. [File Handling](#13-file-handling)
14. [Error Handling](#14-error-handling)
15. [Modules and Packages](#15-modules-and-packages)
16. [Object-Oriented Perl](#16-object-oriented-perl)
17. [References and Complex Data Structures](#17-references-and-complex-data-structures)
18. [Practical Examples](#18-practical-examples)
19. [Best Practices](#19-best-practices)
20. [Further Resources](#20-further-resources)

---

## 1. Introduction to Perl

Perl (Practical Extraction and Reporting Language) is a high-level, general-purpose, interpreted programming language created by Larry Wall in 1987. It combines features from C, sed, awk, and shell scripting, making it extremely powerful for text processing, system administration, web development, and rapid prototyping.

**Key characteristics:**

- Powerful text processing and regular expression support
- Cross-platform compatibility
- CPAN (Comprehensive Perl Archive Network) — one of the largest open-source library ecosystems
- "There's more than one way to do it" (TMTOWTDI) philosophy
- Excellent support for Unicode, databases, and networking

---

## 2. Setting Up Perl

### Check if Perl is installed

```bash
perl -v
```

### Install Perl

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get update
sudo apt-get install perl
```

**Linux (RHEL/CentOS/Fedora):**
```bash
sudo yum install perl
# or
sudo dnf install perl
```

**macOS:** Perl comes pre-installed. For the latest version use [Homebrew](https://brew.sh):
```bash
brew install perl
```

**Windows:** Download and install [Strawberry Perl](https://strawberryperl.com/) or [ActivePerl](https://www.activestate.com/products/perl/).

### Running a Perl script

```bash
perl script.pl
```

Or make the script executable:
```bash
chmod +x script.pl
./script.pl
```

---

## 3. Hello World and Basic Syntax

> See [`examples/01_hello_world.pl`](examples/01_hello_world.pl)

```perl
#!/usr/bin/perl
use strict;
use warnings;

print "Hello, World!\n";
```

**Key points:**

| Element | Purpose |
|---|---|
| `#!/usr/bin/perl` | Shebang line — tells the OS which interpreter to use |
| `use strict;` | Enforces good coding practices (e.g., variable declarations) |
| `use warnings;` | Enables helpful warning messages |
| `print` | Built-in function to output text |
| `\n` | Newline character |
| `;` | Every statement ends with a semicolon |

---

## 4. Variables and Data Types

Perl has three main variable types, each identified by a **sigil** (prefix character).

| Sigil | Type | Stores |
|---|---|---|
| `$` | Scalar | Single value (number, string, reference) |
| `@` | Array | Ordered list of scalars |
| `%` | Hash | Unordered set of key-value pairs |

> See [`examples/02_variables.pl`](examples/02_variables.pl)

### Scalars (`$`)

```perl
my $name   = "Alice";        # string
my $age    = 30;              # integer
my $pi     = 3.14159;         # floating-point
my $active = 1;               # boolean (truthy)
```

Perl automatically converts between strings and numbers based on context:

```perl
my $num_str = "42";
my $result  = $num_str + 8;   # 50 — string auto-converted to number
```

### Arrays (`@`)

```perl
my @colors = ("red", "green", "blue");
my @nums   = (1, 2, 3, 4, 5);
my @mixed  = ("hello", 42, 3.14);

print $colors[0];    # "red" — access single element with $
print scalar @nums;  # 5 — number of elements
```

### Hashes (`%`)

```perl
my %person = (
    name => "Bob",
    age  => 25,
    city => "London",
);

print $person{name};    # "Bob"
```

### Special variables

Perl has many built-in special variables:

| Variable | Meaning |
|---|---|
| `$_` | Default variable (used implicitly by many functions) |
| `@_` | Subroutine arguments |
| `@ARGV` | Command-line arguments |
| `$0` | Program name |
| `$!` | System error message |
| `$/` | Input record separator (default: newline) |

---

## 5. Operators

> See [`examples/03_operators.pl`](examples/03_operators.pl)

### Arithmetic operators

```perl
my $a = 10;
my $b = 3;

print $a + $b, "\n";    # 13  — addition
print $a - $b, "\n";    # 7   — subtraction
print $a * $b, "\n";    # 30  — multiplication
print $a / $b, "\n";    # 3.33... — division
print $a % $b, "\n";    # 1   — modulus
print $a ** $b, "\n";   # 1000 — exponentiation
```

### String operators

```perl
my $first = "Hello";
my $last  = "World";

print $first . " " . $last, "\n";   # "Hello World" — concatenation
print $first x 3, "\n";             # "HelloHelloHello" — repetition
```

### Comparison operators

Perl has **separate** comparison operators for numbers and strings:

| Operation | Numeric | String |
|---|---|---|
| Equal | `==` | `eq` |
| Not equal | `!=` | `ne` |
| Less than | `<` | `lt` |
| Greater than | `>` | `gt` |
| Less or equal | `<=` | `le` |
| Greater or equal | `>=` | `ge` |
| Comparison | `<=>` | `cmp` |

```perl
if (5 == 5)          { print "Numeric equal\n"; }
if ("abc" eq "abc")  { print "String equal\n"; }
```

### Logical operators

```perl
# Symbolic          # English equivalent
&& # and            and
|| # or             or
!  # not            not
```

---

## 6. Control Structures

> See [`examples/04_control_structures.pl`](examples/04_control_structures.pl)

### if / elsif / else

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

### unless (opposite of if)

```perl
my $logged_in = 0;

unless ($logged_in) {
    print "Please log in.\n";
}
```

### Postfix conditionals (idiomatic Perl)

```perl
print "Adult\n" if $age >= 18;
print "Minor\n" unless $age >= 18;
```

### given/when (switch-like, Perl 5.10+)

```perl
use feature 'say';

my $day = "Monday";

given ($day) {
    when ("Monday")   { say "Start of the work week"; }
    when ("Friday")   { say "Almost weekend!"; }
    when ("Saturday")  { say "Weekend!"; }
    when ("Sunday")    { say "Weekend!"; }
    default            { say "Midweek"; }
}
```

### Ternary operator

```perl
my $status = ($age >= 18) ? "adult" : "minor";
```

---

## 7. Loops

> See [`examples/05_loops.pl`](examples/05_loops.pl)

### for loop (C-style)

```perl
for (my $i = 0; $i < 5; $i++) {
    print "i = $i\n";
}
```

### foreach loop

```perl
my @fruits = ("apple", "banana", "cherry");

foreach my $fruit (@fruits) {
    print "I like $fruit\n";
}
```

### while loop

```perl
my $count = 5;
while ($count > 0) {
    print "Countdown: $count\n";
    $count--;
}
```

### do-while loop

```perl
my $input;
do {
    print "Enter 'quit' to exit: ";
    $input = <STDIN>;
    chomp $input;
} while ($input ne "quit");
```

### until loop (opposite of while)

```perl
my $n = 1;
until ($n > 10) {
    print "$n ";
    $n++;
}
print "\n";
```

### Loop control

```perl
for my $i (1..20) {
    next if $i % 2 == 0;    # skip even numbers
    last if $i > 15;         # stop after 15
    print "$i ";
}
# Output: 1 3 5 7 9 11 13 15
```

---

## 8. Strings and String Operations

> See [`examples/06_strings.pl`](examples/06_strings.pl)

### Quoting

```perl
my $single = 'No interpolation here: $var \n';   # literal
my $double = "Interpolation works: $name\n";       # variable interpolated
my $qq     = qq{She said "hello" to $name};        # alternative double-quote
my $q      = q{No $interpolation here};            # alternative single-quote
```

### Heredoc

```perl
my $text = <<END_TEXT;
This is a multi-line string.
Variables like $name are interpolated.
Useful for long blocks of text.
END_TEXT
```

### Common string functions

```perl
my $str = "  Hello, Perl World!  ";

print length($str), "\n";               # 23
print uc($str), "\n";                   # "  HELLO, PERL WORLD!  "
print lc($str), "\n";                   # "  hello, perl world!  "
print ucfirst("hello"), "\n";           # "Hello"

my $trimmed = $str;
$trimmed =~ s/^\s+|\s+$//g;            # trim whitespace
print "'$trimmed'\n";                   # "'Hello, Perl World!'"

print index($str, "Perl"), "\n";        # 9 — find substring position
print substr($str, 2, 5), "\n";        # "Hello"
print reverse("abcde"), "\n";          # "edcba"

my @words = split(/,\s*/, "one, two, three");
print join(" | ", @words), "\n";        # "one | two | three"
```

---

## 9. Arrays

> See [`examples/07_arrays.pl`](examples/07_arrays.pl)

### Creating and accessing arrays

```perl
my @animals = ("cat", "dog", "bird", "fish");

print $animals[0], "\n";     # "cat" — first element
print $animals[-1], "\n";    # "fish" — last element
print scalar @animals, "\n"; # 4 — array length
```

### Array slices

```perl
my @subset = @animals[1, 3];        # ("dog", "fish")
my @range  = @animals[0..2];        # ("cat", "dog", "bird")
```

### Modifying arrays

```perl
push @animals, "hamster";            # add to end
unshift @animals, "snake";           # add to beginning
my $last  = pop @animals;            # remove from end
my $first = shift @animals;          # remove from beginning
splice @animals, 1, 1, "parrot";     # replace element at index 1
```

### Sorting

```perl
my @sorted   = sort @animals;                        # alphabetical
my @num_sort = sort { $a <=> $b } (5, 2, 8, 1, 9);  # numeric ascending
my @rev_sort = sort { $b <=> $a } (5, 2, 8, 1, 9);  # numeric descending
```

### Iterating with map and grep

```perl
my @nums = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

my @doubled = map  { $_ * 2 } @nums;           # (2, 4, 6, ..., 20)
my @evens   = grep { $_ % 2 == 0 } @nums;      # (2, 4, 6, 8, 10)
```

---

## 10. Hashes

> See [`examples/08_hashes.pl`](examples/08_hashes.pl)

### Creating and accessing hashes

```perl
my %capitals = (
    France  => "Paris",
    Germany => "Berlin",
    Japan   => "Tokyo",
    Brazil  => "Brasilia",
);

print $capitals{France}, "\n";       # "Paris"
```

### Checking existence and deleting

```perl
if (exists $capitals{Japan}) {
    print "Japan's capital is $capitals{Japan}\n";
}

delete $capitals{Brazil};
```

### Iterating over hashes

```perl
# Using each
while (my ($country, $capital) = each %capitals) {
    print "$country => $capital\n";
}

# Using keys
foreach my $country (sort keys %capitals) {
    print "$country: $capitals{$country}\n";
}

# Using values
foreach my $capital (values %capitals) {
    print "Capital: $capital\n";
}
```

### Hash slices

```perl
my @some_capitals = @capitals{qw(France Japan)};    # ("Paris", "Tokyo")
```

### Merging hashes

```perl
my %defaults = (color => "blue", size => "medium", shape => "circle");
my %custom   = (color => "red", weight => "heavy");
my %merged   = (%defaults, %custom);
# color => "red", size => "medium", shape => "circle", weight => "heavy"
```

---

## 11. Subroutines (Functions)

> See [`examples/09_subroutines.pl`](examples/09_subroutines.pl)

### Defining and calling subroutines

```perl
sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

print greet("Alice"), "\n";     # "Hello, Alice!"
```

### Multiple parameters and return values

```perl
sub calculate {
    my ($a, $b) = @_;
    my $sum  = $a + $b;
    my $diff = $a - $b;
    my $prod = $a * $b;
    return ($sum, $diff, $prod);
}

my ($s, $d, $p) = calculate(10, 3);
print "Sum=$s, Diff=$d, Product=$p\n";    # Sum=13, Diff=7, Product=30
```

### Default parameter values

```perl
sub connect_db {
    my (%args) = @_;
    my $host = $args{host} // "localhost";
    my $port = $args{port} // 5432;
    my $db   = $args{database} // "mydb";

    print "Connecting to $db on $host:$port\n";
}

connect_db(database => "production", port => 3306);
```

### Anonymous subroutines and closures

```perl
my $square = sub { return $_[0] ** 2; };
print $square->(5), "\n";    # 25

sub make_counter {
    my $count = 0;
    return sub { return ++$count; };
}

my $counter = make_counter();
print $counter->(), "\n";    # 1
print $counter->(), "\n";    # 2
print $counter->(), "\n";    # 3
```

---

## 12. Regular Expressions

Perl's regex engine is one of its most powerful features.

> See [`examples/10_regex.pl`](examples/10_regex.pl)

### Matching (`=~` and `m//`)

```perl
my $text = "The quick brown fox jumps over the lazy dog";

if ($text =~ /quick/) {
    print "Found 'quick'!\n";
}
```

### Common regex metacharacters

| Pattern | Matches |
|---|---|
| `.` | Any single character (except newline) |
| `\d` | Digit `[0-9]` |
| `\w` | Word character `[a-zA-Z0-9_]` |
| `\s` | Whitespace `[ \t\n\r\f]` |
| `\b` | Word boundary |
| `^` | Start of string |
| `$` | End of string |
| `*` | Zero or more |
| `+` | One or more |
| `?` | Zero or one |
| `{n,m}` | Between n and m times |
| `(...)` | Capture group |
| `[...]` | Character class |
| `\|` | Alternation |

### Capturing groups

```perl
my $date = "2026-03-17";

if ($date =~ /(\d{4})-(\d{2})-(\d{2})/) {
    print "Year: $1, Month: $2, Day: $3\n";
}
```

### Substitution (`s///`)

```perl
my $sentence = "I love cats and cats are great";
(my $modified = $sentence) =~ s/cats/dogs/g;
print "$modified\n";    # "I love dogs and dogs are great"
```

### Regex modifiers

| Modifier | Effect |
|---|---|
| `i` | Case-insensitive |
| `g` | Global (all occurrences) |
| `m` | Multi-line mode (`^`/`$` match line boundaries) |
| `s` | Single-line mode (`.` matches `\n`) |
| `x` | Extended mode (allows comments and whitespace) |

### Named captures and extended patterns

```perl
my $log = "2026-03-17 ERROR: Disk full";

if ($log =~ /(?<date>\d{4}-\d{2}-\d{2})\s+(?<level>\w+):\s+(?<msg>.+)/) {
    print "Date:    $+{date}\n";
    print "Level:   $+{level}\n";
    print "Message: $+{msg}\n";
}
```

---

## 13. File Handling

> See [`examples/11_file_handling.pl`](examples/11_file_handling.pl)

### Opening and reading files

```perl
# Read entire file
open(my $fh, '<', 'data.txt') or die "Cannot open file: $!";
while (my $line = <$fh>) {
    chomp $line;
    print "Line: $line\n";
}
close($fh);
```

### Reading all lines at once

```perl
open(my $fh, '<', 'data.txt') or die "Cannot open: $!";
my @lines = <$fh>;
chomp @lines;
close($fh);
```

### Writing to files

```perl
# Write (overwrite)
open(my $fh, '>', 'output.txt') or die "Cannot open: $!";
print $fh "First line\n";
print $fh "Second line\n";
close($fh);

# Append
open(my $fh_append, '>>', 'output.txt') or die "Cannot open: $!";
print $fh_append "Appended line\n";
close($fh_append);
```

### File tests

```perl
my $file = "test.txt";

print "Exists\n"     if -e $file;
print "Is file\n"    if -f $file;
print "Is dir\n"     if -d $file;
print "Readable\n"   if -r $file;
print "Writable\n"   if -w $file;
print "Non-empty\n"  if -s $file;
```

### Working with directories

```perl
opendir(my $dh, '.') or die "Cannot open directory: $!";
my @files = grep { -f $_ } readdir($dh);
closedir($dh);

print "Files in current directory:\n";
print "  $_\n" for sort @files;
```

---

## 14. Error Handling

> See [`examples/12_error_handling.pl`](examples/12_error_handling.pl)

### die and warn

```perl
open(my $fh, '<', 'missing.txt') or die "Error: $!\n";
open(my $fh2, '<', 'maybe.txt')  or warn "Warning: $!\n";
```

### eval for exception handling

```perl
eval {
    my $result = 10 / 0;
    print "Result: $result\n";
};
if ($@) {
    print "Caught error: $@\n";
}
```

### Using Try::Tiny (recommended module)

```perl
use Try::Tiny;

try {
    die "Something went wrong!";
} catch {
    print "Caught: $_\n";
} finally {
    print "Cleanup done.\n";
};
```

### Custom error handling with Carp

```perl
use Carp;

sub validate_age {
    my ($age) = @_;
    croak "Age must be positive" if $age < 0;
    carp  "Age seems unusually high" if $age > 150;
    return $age;
}
```

---

## 15. Modules and Packages

> See [`examples/13_modules/`](examples/13_modules/)

### Using modules

```perl
use File::Basename;
use List::Util qw(sum min max);
use POSIX qw(ceil floor);

my $path = "/home/user/documents/report.txt";
print basename($path), "\n";     # "report.txt"
print dirname($path), "\n";      # "/home/user/documents"

my @values = (4, 2, 9, 1, 7);
print "Sum: ", sum(@values), "\n";    # 23
print "Min: ", min(@values), "\n";    # 1
print "Max: ", max(@values), "\n";    # 9
```

### Creating your own module

**`MathHelper.pm`:**
```perl
package MathHelper;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(factorial fibonacci);

sub factorial {
    my ($n) = @_;
    return 1 if $n <= 1;
    return $n * factorial($n - 1);
}

sub fibonacci {
    my ($n) = @_;
    my @fib = (0, 1);
    for my $i (2..$n) {
        push @fib, $fib[-1] + $fib[-2];
    }
    return @fib[0..$n];
}

1;    # modules must return a true value
```

**Using the module:**
```perl
use lib '.';
use MathHelper qw(factorial fibonacci);

print "5! = ", factorial(5), "\n";                 # 120
print "Fibonacci: ", join(", ", fibonacci(8)), "\n"; # 0, 1, 1, 2, 3, 5, 8, 13, 21
```

### Installing CPAN modules

```bash
cpan install JSON
cpan install LWP::UserAgent
cpan install DBI
```

Or using `cpanm` (recommended):
```bash
cpanm JSON LWP::UserAgent DBI
```

---

## 16. Object-Oriented Perl

> See [`examples/14_oop/`](examples/14_oop/)

### Basic class

```perl
package Animal;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = {
        name   => $args{name}   // "Unknown",
        sound  => $args{sound}  // "...",
        legs   => $args{legs}   // 4,
    };
    return bless $self, $class;
}

sub name  { return $_[0]->{name}; }
sub sound { return $_[0]->{sound}; }
sub legs  { return $_[0]->{legs}; }

sub speak {
    my ($self) = @_;
    printf "%s says %s!\n", $self->name(), $self->sound();
}

sub describe {
    my ($self) = @_;
    printf "%s has %d legs.\n", $self->name(), $self->legs();
}

1;
```

### Inheritance

```perl
package Dog;
use strict;
use warnings;
use parent 'Animal';

sub new {
    my ($class, %args) = @_;
    $args{sound} //= "Woof";
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
        printf "%s doesn't know any tricks yet.\n", $self->name();
    }
}

1;
```

### Usage

```perl
use Animal;
use Dog;

my $cat = Animal->new(name => "Whiskers", sound => "Meow");
$cat->speak();        # Whiskers says Meow!
$cat->describe();     # Whiskers has 4 legs.

my $dog = Dog->new(name => "Rex");
$dog->speak();        # Rex says Woof!
$dog->learn_trick("sit");
$dog->learn_trick("shake");
$dog->show_tricks();  # Rex knows: sit, shake
```

---

## 17. References and Complex Data Structures

> See [`examples/15_references.pl`](examples/15_references.pl)

### Scalar references

```perl
my $name = "Alice";
my $ref  = \$name;         # create reference

print $$ref, "\n";          # dereference: "Alice"
print ref($ref), "\n";     # "SCALAR"
```

### Array and hash references

```perl
my @colors = ("red", "green", "blue");
my $aref = \@colors;                       # reference to existing array
my $anon = ["cyan", "magenta", "yellow"];   # anonymous array reference

print $aref->[0], "\n";     # "red"
print $anon->[2], "\n";     # "yellow"

my %person = (name => "Bob", age => 30);
my $href = \%person;                          # reference to existing hash
my $anon_h = { city => "NYC", zip => "10001" };  # anonymous hash reference

print $href->{name}, "\n";     # "Bob"
print $anon_h->{city}, "\n";   # "NYC"
```

### Complex nested structures

```perl
my $company = {
    name      => "TechCorp",
    employees => [
        { name => "Alice", role => "Engineer",  skills => ["Perl", "Python"] },
        { name => "Bob",   role => "Designer",  skills => ["CSS", "Figma"] },
        { name => "Carol", role => "Manager",   skills => ["Leadership", "Agile"] },
    ],
    address   => {
        street => "123 Main St",
        city   => "San Francisco",
        state  => "CA",
    },
};

print "Company: $company->{name}\n";
print "First employee: $company->{employees}[0]{name}\n";
print "City: $company->{address}{city}\n";

for my $emp (@{$company->{employees}}) {
    printf "  %s (%s): %s\n", $emp->{name}, $emp->{role},
           join(", ", @{$emp->{skills}});
}
```

---

## 18. Practical Examples

The `examples/` directory contains runnable scripts for every topic above plus the following real-world applications:

| Script | Description |
|---|---|
| [`examples/practical/log_analyzer.pl`](examples/practical/log_analyzer.pl) | Parse and summarize web server log files |
| [`examples/practical/csv_processor.pl`](examples/practical/csv_processor.pl) | Read, filter, and transform CSV data |
| [`examples/practical/word_frequency.pl`](examples/practical/word_frequency.pl) | Count word frequencies in a text file |
| [`examples/practical/todo_app.pl`](examples/practical/todo_app.pl) | Command-line to-do list manager with file persistence |
| [`examples/practical/file_renamer.pl`](examples/practical/file_renamer.pl) | Batch rename files using regex patterns |
| [`examples/practical/report_generator.pl`](examples/practical/report_generator.pl) | Generate formatted text reports from data |

---

## 19. Best Practices

1. **Always use `strict` and `warnings`** — they catch the majority of common bugs.
2. **Declare variables with `my`** — lexical scoping prevents accidental globals.
3. **Use descriptive variable names** — `$employee_count` over `$ec`.
4. **Check return values** — especially for `open`, `close`, and system calls.
5. **Use three-argument `open`** — `open(my $fh, '<', $file)` is safer than two-argument form.
6. **Prefer lexical filehandles** — `my $fh` over bareword `FH`.
7. **Use `chomp`** to remove trailing newlines from input.
8. **Comment intent, not mechanics** — explain *why*, not *what*.
9. **Use CPAN** — don't reinvent the wheel; thousands of battle-tested modules exist.
10. **Run `perl -c script.pl`** to syntax-check without executing.
11. **Use `perltidy`** to auto-format your code consistently.
12. **Write tests** — `Test::More` and `Test::Simple` are built into Perl.

---

## 20. Further Resources

- [Official Perl Documentation](https://perldoc.perl.org/) — comprehensive built-in docs
- [Learn Perl in about 2 hours 30 minutes](https://qntm.org/perl_en) — concise tutorial
- [Modern Perl (free book)](http://modernperlbooks.com/) — best practices for contemporary Perl
- [CPAN](https://metacpan.org/) — the Perl module repository
- [PerlMonks](https://www.perlmonks.org/) — community Q&A
- [Perl Maven](https://perlmaven.com/) — tutorials and articles
- [Regex101](https://regex101.com/) — online regex tester (supports Perl flavor)

---

## License

This tutorial is released under the [MIT License](LICENSE). Feel free to use, modify, and share.
