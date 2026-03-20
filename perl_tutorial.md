# Perl Programming Tutorial: From Basics to Advanced

---

## Part 1 — Basics

---

### 1. Hello World & Program Structure

Every Perl script starts with a **shebang line** (on Unix-like systems) and typically enables **strict** and **warnings** pragmas to catch common mistakes.

```perl
#!/usr/bin/perl
use strict;
use warnings;

print "Hello, World!\n";
```

**Key points:**

- `#!/usr/bin/perl` — tells the OS to use the Perl interpreter.
- `use strict;` — enforces variable declarations and catches typos.
- `use warnings;` — reports suspicious constructs at runtime.
- Every statement ends with a semicolon (`;`).
- `\n` is the newline escape character.

**Running a script:**

```bash
perl hello.pl
# or make it executable:
chmod +x hello.pl
./hello.pl
```

---

### 2. Variables: Scalars, Arrays, and Hashes

Perl has three fundamental variable types, each with its own **sigil** (prefix character).

#### 2.1 Scalars (`$`)

A scalar holds a single value — a number, a string, or a reference.

```perl
my $name   = "Alice";        # string
my $age    = 30;              # integer
my $height = 5.7;             # floating-point
my $active = 1;               # boolean-like (truthy)

print "Name: $name, Age: $age\n";    # variable interpolation in double quotes
print 'Literal: $name\n';            # single quotes: no interpolation
```

**Output:**

```
Name: Alice, Age: 30
Literal: $name\n
```

**Truthiness in Perl:**

| Value | Boolean |
|-------|---------|
| `0` | false |
| `""` (empty string) | false |
| `"0"` | false |
| `undef` | false |
| Everything else | true |

#### 2.2 Arrays (`@`)

An ordered list of scalars, indexed starting at 0.

```perl
my @colors = ("red", "green", "blue");
my @numbers = (1, 2, 3, 4, 5);

# Accessing elements (use $ because each element is a scalar)
print $colors[0];      # "red"
print $colors[-1];     # "blue" (last element)

# Array length
my $length = scalar @colors;    # 3
# or implicitly: my $length = @colors;

# Array slices
my @subset = @colors[0, 2];    # ("red", "blue")

# Useful functions
push @colors, "yellow";        # append to end
pop @colors;                   # remove from end
unshift @colors, "white";      # prepend to beginning
shift @colors;                 # remove from beginning
my @sorted = sort @colors;     # alphabetical sort
my @reversed = reverse @colors;
my $joined = join(", ", @colors);  # "red, green, blue"
my @split_result = split(/,/, "a,b,c");  # ("a", "b", "c")
```

#### 2.3 Hashes (`%`)

An unordered set of key-value pairs (also called associative arrays or dictionaries).

```perl
my %person = (
    name => "Bob",
    age  => 25,
    city => "New York",
);

# Accessing values
print $person{name};       # "Bob"
print $person{"age"};      # 25

# Adding / modifying entries
$person{email} = "bob@example.com";
$person{age} = 26;

# Deleting a key
delete $person{email};

# Checking if a key exists
if (exists $person{name}) {
    print "Name exists\n";
}

# Getting all keys and values
my @keys   = keys %person;
my @values = values %person;

# Iterating
while (my ($key, $value) = each %person) {
    print "$key => $value\n";
}
```

---

### 3. Operators

#### 3.1 Arithmetic Operators

```perl
my $a = 15;
my $b = 4;

print $a + $b;     # 19   (addition)
print $a - $b;     # 11   (subtraction)
print $a * $b;     # 60   (multiplication)
print $a / $b;     # 3.75 (division)
print $a % $b;     # 3    (modulus)
print $a ** $b;    # 50625 (exponentiation)
```

#### 3.2 String Operators

```perl
my $greeting = "Hello" . " " . "World";   # concatenation
my $repeated = "Ha" x 3;                   # "HaHaHa" (repetition)
```

#### 3.3 Comparison Operators

| Numeric | String | Meaning |
|---------|--------|---------|
| `==` | `eq` | equal |
| `!=` | `ne` | not equal |
| `<` | `lt` | less than |
| `>` | `gt` | greater than |
| `<=` | `le` | less or equal |
| `>=` | `ge` | greater or equal |
| `<=>` | `cmp` | spaceship / compare |

```perl
print 5 == 5;        # 1 (true)
print "abc" eq "abc"; # 1
print 3 <=> 7;       # -1 (useful for sort)
```

#### 3.4 Logical Operators

```perl
# C-style
$a && $b;    # AND
$a || $b;    # OR
!$a;         # NOT

# English-style (lower precedence, useful in flow control)
$a and $b;
$a or $b;
not $a;

# Defined-or (Perl 5.10+)
my $val = $input // "default";   # use $input if defined, otherwise "default"
```

---

### 4. Control Flow

#### 4.1 Conditional Statements

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

# unless — the opposite of if
unless ($score < 60) {
    print "You passed!\n";
}

# Postfix form (for single statements)
print "Excellent!\n" if $score >= 90;
print "Study more\n" unless $score >= 60;
```

#### 4.2 Ternary Operator

```perl
my $status = ($score >= 60) ? "pass" : "fail";
```

#### 4.3 Given/When (Switch, Perl 5.10+)

```perl
use feature 'switch';
no warnings 'experimental';

given ($score) {
    when ($_ >= 90) { print "A\n" }
    when ($_ >= 80) { print "B\n" }
    when ($_ >= 70) { print "C\n" }
    default         { print "F\n" }
}
```

#### 4.4 Loops

**`for` loop (C-style):**

```perl
for (my $i = 0; $i < 10; $i++) {
    print "$i ";
}
```

**`foreach` loop:**

```perl
my @fruits = ("apple", "banana", "cherry");

foreach my $fruit (@fruits) {
    print "I like $fruit\n";
}

# $_ is the default variable when no loop variable is given
foreach (@fruits) {
    print "Fruit: $_\n";
}
```

**`while` loop:**

```perl
my $count = 5;
while ($count > 0) {
    print "$count ";
    $count--;
}
```

**`until` loop (opposite of while):**

```perl
my $n = 1;
until ($n > 5) {
    print "$n ";
    $n++;
}
```

**`do...while`:**

```perl
my $x = 0;
do {
    print "$x ";
    $x++;
} while ($x < 5);
```

**Loop control:**

```perl
for my $i (1..20) {
    next if $i % 2 == 0;   # skip even numbers
    last if $i > 15;       # exit loop when > 15
    print "$i ";
}
# Output: 1 3 5 7 9 11 13 15

# Loop labels for nested loops
OUTER: for my $i (1..5) {
    for my $j (1..5) {
        next OUTER if $j == 3;
        print "($i,$j) ";
    }
}
```

---

### 5. String Operations

```perl
my $str = "  Hello, Perl World!  ";

# Length
my $len = length($str);

# Substring
my $sub = substr($str, 2, 5);       # "Hello"
substr($str, 2, 5, "Greetings");    # replace in-place

# Case conversion
my $upper = uc($str);       # uppercase
my $lower = lc($str);       # lowercase
my $ucfirst = ucfirst("hello");  # "Hello"
my $lcfirst = lcfirst("Hello");  # "hello"

# Trimming whitespace (no built-in trim, use regex)
(my $trimmed = $str) =~ s/^\s+|\s+$//g;

# Index / rindex — find position of substring
my $pos  = index($str, "Perl");       # first occurrence
my $rpos = rindex($str, "l");         # last occurrence

# Repeat
my $line = "-" x 40;    # 40 dashes

# sprintf for formatted strings
my $formatted = sprintf("Name: %-10s Age: %03d", "Alice", 7);
# "Name: Alice      Age: 007"

# Heredoc for multi-line strings
my $text = <<END_TEXT;
This is a multi-line
string using a heredoc.
Variables like $len are interpolated.
END_TEXT

# Indented heredoc (Perl 5.26+)
my $indented = <<~END;
    This heredoc
    strips leading indentation
    END
```

---

### 6. Input and Output

#### 6.1 Standard I/O

```perl
# Reading from STDIN
print "Enter your name: ";
my $name = <STDIN>;
chomp $name;            # remove trailing newline

# Reading all lines
while (my $line = <STDIN>) {
    chomp $line;
    print "You said: $line\n";
}

# Print vs say (say adds newline automatically, Perl 5.10+)
use feature 'say';
say "Hello!";           # equivalent to print "Hello!\n";

# Printing to STDERR
print STDERR "Warning: something happened\n";
warn "This also goes to STDERR\n";
```

#### 6.2 Formatted Output

```perl
# printf — C-style formatted output
printf("%-15s %5d %8.2f\n", "Widget", 42, 19.99);

# format / write — Perl's report generation
format STDOUT =
@<<<<<<<<<<<<< @>>>> @####.##
$name,         $age, $salary
.
# (called with: write;)
```

---

### 7. Subroutines (Functions)

```perl
# Basic subroutine
sub greet {
    my ($name) = @_;    # @_ holds all arguments
    return "Hello, $name!";
}

print greet("Alice");   # "Hello, Alice!"

# Multiple parameters
sub add {
    my ($a, $b) = @_;
    return $a + $b;
}

# Default values
sub connect {
    my (%args) = @_;
    my $host = $args{host} // "localhost";
    my $port = $args{port} // 3306;
    return "Connecting to $host:$port";
}

print connect(host => "db.example.com", port => 5432);

# Returning multiple values
sub min_max {
    my @nums = sort { $a <=> $b } @_;
    return ($nums[0], $nums[-1]);
}

my ($min, $max) = min_max(4, 2, 9, 1, 7);
print "Min: $min, Max: $max\n";   # Min: 1, Max: 9

# Prototypes (rarely needed, but available)
sub my_sum (\@) {
    my ($array_ref) = @_;
    my $total = 0;
    $total += $_ for @$array_ref;
    return $total;
}
```

---

## Part 2 — Intermediate

---

### 8. Regular Expressions

Regular expressions are one of Perl's greatest strengths.

#### 8.1 Matching

```perl
my $text = "The quick brown fox jumps over the lazy dog";

# Basic match
if ($text =~ /quick/) {
    print "Found 'quick'\n";
}

# Case-insensitive match
if ($text =~ /QUICK/i) {
    print "Found (case-insensitive)\n";
}

# Negated match
if ($text !~ /cat/) {
    print "No cat found\n";
}

# Capture groups
if ($text =~ /(\w+)\s+fox/) {
    print "Word before fox: $1\n";    # "brown"
}

# Named captures
if ($text =~ /(?<color>\w+)\s+fox/) {
    print "Color: $+{color}\n";       # "brown"
}

# Multiple captures
my @words = ($text =~ /(\w+)/g);     # all words
```

#### 8.2 Substitution

```perl
my $str = "Hello World";

# Replace first occurrence
(my $new = $str) =~ s/World/Perl/;
# $new is "Hello Perl"

# Replace all occurrences
my $data = "aabbaabb";
$data =~ s/a/x/g;    # "xxbbxxbb"

# Using captured groups in replacement
my $date = "2025-03-15";
$date =~ s/(\d{4})-(\d{2})-(\d{2})/$3\/$2\/$1/;
# "15/03/2025"

# Using /e to evaluate replacement as code
my $text = "price is 100 dollars";
$text =~ s/(\d+)/$1 * 1.1/e;
# "price is 110 dollars"
```

#### 8.3 Common Patterns

```perl
# Email validation (simplified)
my $email_re = qr/^[\w.+-]+@[\w-]+\.[\w.]+$/;

# IP address
my $ip_re = qr/^(\d{1,3}\.){3}\d{1,3}$/;

# Extracting all numbers
my @numbers = ("abc 42 def 99 ghi 7" =~ /(\d+)/g);
# (42, 99, 7)

# Split with regex
my @parts = split /\s*,\s*/, "one , two , three";
# ("one", "two", "three")
```

#### 8.4 Regex Modifiers

| Modifier | Meaning |
|----------|---------|
| `i` | Case-insensitive |
| `g` | Global (all matches) |
| `m` | Multi-line (`^`/`$` match line boundaries) |
| `s` | Single-line (`.` matches `\n`) |
| `x` | Extended (allows comments and whitespace) |
| `e` | Evaluate replacement as Perl code |

```perl
# Extended mode for readable regexes
my $phone_re = qr/
    ^(\d{3})      # area code
    [-.\s]?       # optional separator
    (\d{3})       # exchange
    [-.\s]?       # optional separator
    (\d{4})$      # subscriber
/x;
```

---

### 9. File Handling

#### 9.1 Opening and Reading Files

```perl
# Modern three-argument open
open(my $fh, '<', 'input.txt')
    or die "Cannot open input.txt: $!\n";

# Read line by line
while (my $line = <$fh>) {
    chomp $line;
    print "$line\n";
}

close($fh);

# Read entire file into an array
open(my $fh2, '<', 'input.txt') or die "Cannot open: $!\n";
my @lines = <$fh2>;
chomp @lines;
close($fh2);

# Read entire file into a scalar (slurp)
open(my $fh3, '<', 'input.txt') or die "Cannot open: $!\n";
my $content = do { local $/; <$fh3> };
close($fh3);
```

#### 9.2 Writing Files

```perl
# Write mode (overwrites)
open(my $out, '>', 'output.txt') or die "Cannot open: $!\n";
print $out "Line 1\n";
print $out "Line 2\n";
close($out);

# Append mode
open(my $append, '>>', 'log.txt') or die "Cannot open: $!\n";
print $append "New log entry\n";
close($append);
```

#### 9.3 File Tests

```perl
my $file = "test.txt";

print "Exists\n"     if -e $file;
print "Is file\n"    if -f $file;
print "Is dir\n"     if -d $file;
print "Readable\n"   if -r $file;
print "Writable\n"   if -w $file;
print "Non-empty\n"  if -s $file;     # returns size in bytes
print "Is text\n"    if -T $file;

# File age
my $age_days = -M $file;    # days since last modification
```

#### 9.4 Directory Operations

```perl
# Reading a directory
opendir(my $dh, '/tmp') or die "Cannot opendir: $!\n";
my @files = readdir($dh);
closedir($dh);

# Filtering out . and ..
my @real_files = grep { $_ !~ /^\.\.?$/ } @files;

# Using glob
my @txt_files = glob("*.txt");
my @all_files = glob("data/*.*");

# Creating and removing directories
use File::Path qw(make_path remove_tree);
make_path("path/to/new/dir");
remove_tree("path/to/old/dir");
```

---

### 10. References and Complex Data Structures

References are Perl's mechanism for creating complex, nested data structures.

#### 10.1 Creating References

```perl
# Scalar reference
my $name = "Alice";
my $name_ref = \$name;
print $$name_ref;          # "Alice" (dereference)

# Array reference
my @colors = ("red", "green", "blue");
my $colors_ref = \@colors;
print $colors_ref->[0];    # "red"
print $$colors_ref[1];     # "green" (alternative syntax)

# Anonymous array reference
my $nums = [1, 2, 3, 4, 5];

# Hash reference
my %person = (name => "Bob", age => 30);
my $person_ref = \%person;
print $person_ref->{name};  # "Bob"

# Anonymous hash reference
my $config = {
    host => "localhost",
    port => 8080,
};
```

#### 10.2 Complex Data Structures

```perl
# Array of arrays (2D matrix)
my @matrix = (
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
);
print $matrix[1][2];    # 6

# Array of hashes (like a database result set)
my @employees = (
    { name => "Alice", dept => "Engineering", salary => 95000 },
    { name => "Bob",   dept => "Marketing",   salary => 75000 },
    { name => "Carol", dept => "Engineering", salary => 105000 },
);

foreach my $emp (@employees) {
    printf "%-10s %-15s \$%d\n", $emp->{name}, $emp->{dept}, $emp->{salary};
}

# Hash of arrays
my %courses = (
    math    => ["Alice", "Bob", "Carol"],
    science => ["Dave", "Eve"],
    english => ["Frank", "Grace", "Heidi", "Ivan"],
);

foreach my $course (sort keys %courses) {
    my $count = scalar @{ $courses{$course} };
    print "$course: $count students\n";
}

# Hash of hashes (nested config)
my %config = (
    database => {
        host     => "db.example.com",
        port     => 5432,
        name     => "myapp",
    },
    cache => {
        host     => "cache.example.com",
        port     => 6379,
    },
);

print "DB Host: $config{database}{host}\n";
```

#### 10.3 Data::Dumper for Debugging

```perl
use Data::Dumper;

my $complex = {
    users => [
        { name => "Alice", roles => ["admin", "user"] },
        { name => "Bob",   roles => ["user"] },
    ],
};

print Dumper($complex);
```

---

### 11. Modules and Packages

#### 11.1 Using Modules

```perl
# Core modules
use File::Basename;
use File::Copy;
use Cwd;
use POSIX qw(strftime);
use List::Util qw(sum min max reduce);

my $filename = basename("/home/user/document.txt");  # "document.txt"
my $dir      = dirname("/home/user/document.txt");   # "/home/user"
my $now      = strftime("%Y-%m-%d %H:%M:%S", localtime);
my $total    = sum(1, 2, 3, 4, 5);                  # 15
```

#### 11.2 Creating a Module

**File: `MyUtils.pm`**

```perl
package MyUtils;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(trim capitalize format_currency);

sub trim {
    my ($str) = @_;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub capitalize {
    my ($str) = @_;
    return join(' ', map { ucfirst lc } split /\s+/, $str);
}

sub format_currency {
    my ($amount, $symbol) = @_;
    $symbol //= '$';
    return sprintf("%s%.2f", $symbol, $amount);
}

1;    # modules must return a true value
```

**Using the module:**

```perl
use lib '.';    # add current directory to module search path
use MyUtils qw(trim capitalize format_currency);

print trim("  hello  ");              # "hello"
print capitalize("john doe smith");   # "John Doe Smith"
print format_currency(1234.5);        # "$1234.50"
```

#### 11.3 Installing CPAN Modules

```bash
# Using cpanm (recommended)
cpanm JSON
cpanm DBI
cpanm LWP::UserAgent

# Or using cpan
cpan install JSON
```

---

### 12. Error Handling

#### 12.1 die, warn, and eval

```perl
# die — terminate with an error
open(my $fh, '<', 'missing.txt')
    or die "Cannot open file: $!\n";

# warn — print warning but continue
warn "This might be a problem\n";

# eval — catch exceptions (like try/catch)
eval {
    my $result = 10 / 0;
};
if ($@) {
    print "Caught error: $@\n";
}
```

#### 12.2 Try::Tiny (CPAN, cleaner syntax)

```perl
use Try::Tiny;

try {
    die "Something went wrong";
} catch {
    print "Error: $_\n";
} finally {
    print "Cleanup code runs here\n";
};
```

#### 12.3 Custom Exceptions

```perl
package MyApp::Error;

sub new {
    my ($class, %args) = @_;
    return bless {
        message => $args{message} // "Unknown error",
        code    => $args{code}    // 500,
    }, $class;
}

sub message { return $_[0]->{message} }
sub code    { return $_[0]->{code} }
sub throw   { die $_[0]->new(@_[1..$#_]) }

package main;

eval {
    MyApp::Error->throw(message => "Not found", code => 404);
};
if (ref $@ && $@->isa('MyApp::Error')) {
    printf "Error %d: %s\n", $@->code, $@->message;
}
```

---

### 13. Object-Oriented Programming (OOP)

#### 13.1 Classic Perl OOP (bless)

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

sub name  { return $_[0]->{name} }
sub sound { return $_[0]->{sound} }
sub legs  { return $_[0]->{legs} }

sub speak {
    my ($self) = @_;
    return sprintf("%s says %s!", $self->name, $self->sound);
}

# Inheritance
package Dog;
use parent -norequire, 'Animal';

sub new {
    my ($class, %args) = @_;
    $args{sound} //= "Woof";
    my $self = $class->SUPER::new(%args);
    $self->{tricks} = $args{tricks} // [];
    return $self;
}

sub learn_trick {
    my ($self, $trick) = @_;
    push @{ $self->{tricks} }, $trick;
}

sub show_tricks {
    my ($self) = @_;
    return join(", ", @{ $self->{tricks} });
}

package main;

my $dog = Dog->new(name => "Rex");
$dog->learn_trick("sit");
$dog->learn_trick("shake");
print $dog->speak() . "\n";          # "Rex says Woof!"
print $dog->show_tricks() . "\n";    # "sit, shake"
```

#### 13.2 Moose (Modern OOP Framework)

```perl
package Person;
use Moose;

has 'name' => (is => 'ro', isa => 'Str', required => 1);
has 'age'  => (is => 'rw', isa => 'Int', default  => 0);
has 'email' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_email',
);

sub greet {
    my ($self) = @_;
    return "Hi, I'm " . $self->name . ", age " . $self->age;
}

around 'age' => sub {
    my ($orig, $self, @args) = @_;
    if (@args && $args[0] < 0) {
        die "Age cannot be negative";
    }
    return $self->$orig(@args);
};

__PACKAGE__->meta->make_immutable;

package Employee;
use Moose;
extends 'Person';

has 'company'  => (is => 'ro', isa => 'Str', required => 1);
has 'salary'   => (is => 'rw', isa => 'Num', default  => 0);

sub introduce {
    my ($self) = @_;
    return $self->greet() . ", working at " . $self->company;
}

__PACKAGE__->meta->make_immutable;
```

---

## Part 3 — Advanced

---

### 14. Advanced Regular Expressions

#### 14.1 Lookahead and Lookbehind

```perl
my $text = "price: $100 and $200";

# Positive lookahead: digits followed by a space
my @prices = ($text =~ /\$(\d+)(?=\s)/g);   # (100)

# Negative lookahead: digits NOT followed by '0'
my @matches = ("12 120 13 130" =~ /\b(\d+)(?!0)\b/g);

# Positive lookbehind: digits preceded by $
my @amounts = ($text =~ /(?<=\$)\d+/g);     # (100, 200)

# Negative lookbehind: words NOT preceded by 'un'
my @words = ("happy unhappy kind unkind" =~ /(?<!un)(\w+)/g);
```

#### 14.2 Non-Greedy Matching

```perl
my $html = "<b>bold</b> and <i>italic</i>";

# Greedy (default): matches as much as possible
my ($greedy) = ($html =~ /(<.*>)/);
# "<b>bold</b> and <i>italic</i>"

# Non-greedy: matches as little as possible
my ($lazy) = ($html =~ /(<.*?>)/);
# "<b>"

# Extract all tags
my @tags = ($html =~ /(<[^>]+>)/g);
# ("<b>", "</b>", "<i>", "</i>")
```

#### 14.3 Recursive Patterns

```perl
# Match balanced parentheses
my $balanced_re = qr/
    \(              # opening paren
    (?:
        [^()]+      # non-parens
        |
        (?-1)       # recurse into this pattern
    )*
    \)              # closing paren
/x;

my $expr = "func(a, (b + c), d)";
if ($expr =~ /($balanced_re)/) {
    print "Balanced: $1\n";    # "(a, (b + c), d)"
}
```

---

### 15. Closures and Higher-Order Functions

#### 15.1 Closures

A closure is a subroutine that captures variables from its enclosing scope.

```perl
sub make_counter {
    my $count = 0;
    return sub { return ++$count };
}

my $counter = make_counter();
print $counter->();    # 1
print $counter->();    # 2
print $counter->();    # 3

# Closure as a configurable function factory
sub make_multiplier {
    my ($factor) = @_;
    return sub { return $_[0] * $factor };
}

my $double = make_multiplier(2);
my $triple = make_multiplier(3);

print $double->(5);    # 10
print $triple->(5);    # 15
```

#### 15.2 Higher-Order Functions

```perl
# map — transform each element
my @nums = (1, 2, 3, 4, 5);
my @squared = map { $_ ** 2 } @nums;     # (1, 4, 9, 16, 25)

# grep — filter elements
my @evens = grep { $_ % 2 == 0 } @nums;  # (2, 4)

# sort with custom comparator
my @sorted = sort { $b <=> $a } @nums;   # (5, 4, 3, 2, 1)

# reduce
use List::Util qw(reduce);
my $product = reduce { $a * $b } @nums;  # 120

# Chaining operations
my @result = sort { $a <=> $b }
             grep { $_ > 10 }
             map  { $_ ** 2 } @nums;
# (16, 25)

# Custom higher-order function
sub apply_to_each {
    my ($func, @list) = @_;
    return map { $func->($_) } @list;
}

my @lengths = apply_to_each(sub { length($_[0]) }, "hello", "world", "hi");
# (5, 5, 2)
```

#### 15.3 Memoization

```perl
sub memoize {
    my ($func) = @_;
    my %cache;
    return sub {
        my $key = join(",", @_);
        unless (exists $cache{$key}) {
            $cache{$key} = $func->(@_);
        }
        return $cache{$key};
    };
}

my $fib;
$fib = memoize(sub {
    my ($n) = @_;
    return $n if $n <= 1;
    return $fib->($n - 1) + $fib->($n - 2);
});

print $fib->(30);    # 832040 (fast, thanks to memoization)
```

---

### 16. Database Access with DBI

```perl
use DBI;

# Connect to a database
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=myapp.db",
    "", "",
    {
        RaiseError => 1,
        AutoCommit => 1,
        PrintError => 0,
    }
) or die "Connection failed: $DBI::errstr\n";

# Create a table
$dbh->do(<<'SQL');
    CREATE TABLE IF NOT EXISTS users (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT NOT NULL,
        email TEXT UNIQUE,
        age   INTEGER
    )
SQL

# Insert with placeholders (prevents SQL injection)
my $sth = $dbh->prepare("INSERT INTO users (name, email, age) VALUES (?, ?, ?)");
$sth->execute("Alice", "alice@example.com", 30);
$sth->execute("Bob",   "bob@example.com",   25);

# Query data
$sth = $dbh->prepare("SELECT * FROM users WHERE age > ?");
$sth->execute(20);

while (my $row = $sth->fetchrow_hashref) {
    printf "ID: %d, Name: %s, Email: %s, Age: %d\n",
        $row->{id}, $row->{name}, $row->{email}, $row->{age};
}

# Fetch all rows at once
my $all_users = $dbh->selectall_arrayref(
    "SELECT name, age FROM users ORDER BY name",
    { Slice => {} }
);

foreach my $user (@$all_users) {
    print "$user->{name} is $user->{age} years old\n";
}

# Transactions
eval {
    $dbh->begin_work;
    $dbh->do("UPDATE users SET age = age + 1 WHERE name = ?", undef, "Alice");
    $dbh->do("UPDATE users SET age = age + 1 WHERE name = ?", undef, "Bob");
    $dbh->commit;
};
if ($@) {
    $dbh->rollback;
    warn "Transaction failed: $@\n";
}

$dbh->disconnect;
```

---

### 17. Network Programming

#### 17.1 HTTP Client with LWP

```perl
use LWP::UserAgent;
use JSON;

my $ua = LWP::UserAgent->new(
    timeout => 30,
    agent   => 'PerlTutorialBot/1.0',
);

# Simple GET request
my $response = $ua->get('https://httpbin.org/get');

if ($response->is_success) {
    print $response->decoded_content;
} else {
    die "Request failed: " . $response->status_line;
}

# POST with JSON body
my $json = JSON->new->utf8;
my $post_response = $ua->post(
    'https://httpbin.org/post',
    Content_Type => 'application/json',
    Content      => $json->encode({ name => "Alice", age => 30 }),
);
```

#### 17.2 Socket Programming

```perl
use IO::Socket::INET;

# TCP Server
my $server = IO::Socket::INET->new(
    LocalPort => 8080,
    Proto     => 'tcp',
    Listen    => 5,
    Reuse     => 1,
) or die "Cannot create server: $!\n";

print "Server listening on port 8080\n";

while (my $client = $server->accept()) {
    my $peer = $client->peerhost();
    print "Connection from $peer\n";

    while (my $line = <$client>) {
        chomp $line;
        print $client "Echo: $line\n";
        last if $line eq 'quit';
    }
    close($client);
}

# TCP Client
my $socket = IO::Socket::INET->new(
    PeerAddr => 'localhost',
    PeerPort => 8080,
    Proto    => 'tcp',
) or die "Cannot connect: $!\n";

print $socket "Hello Server\n";
my $reply = <$socket>;
print "Server replied: $reply";
close($socket);
```

---

### 18. Multithreading and Forking

#### 18.1 Forking

```perl
use POSIX qw(:sys_wait_h);

my @tasks = ("task_a", "task_b", "task_c", "task_d");
my @pids;

foreach my $task (@tasks) {
    my $pid = fork();

    if (!defined $pid) {
        die "Fork failed: $!\n";
    } elsif ($pid == 0) {
        # Child process
        print "[$$] Processing $task...\n";
        sleep(rand(3));
        print "[$$] Finished $task\n";
        exit(0);
    } else {
        push @pids, $pid;
    }
}

# Wait for all children
foreach my $pid (@pids) {
    waitpid($pid, 0);
}
print "All tasks complete\n";
```

#### 18.2 Threads

```perl
use threads;
use threads::shared;

my $counter :shared = 0;

sub worker {
    my ($id) = @_;
    for (1..1000) {
        lock($counter);
        $counter++;
    }
    return "Worker $id done";
}

my @threads;
for my $i (1..4) {
    push @threads, threads->create(\&worker, $i);
}

foreach my $thr (@threads) {
    my $result = $thr->join();
    print "$result\n";
}

print "Counter: $counter\n";    # 4000
```

---

### 19. One-Liners and Command-Line Perl

Perl's `-e` (and `-E`) flags let you run Perl code directly from the command line.

```bash
# Print lines matching a pattern (like grep)
perl -ne 'print if /error/i' logfile.txt

# Replace text in-place (like sed)
perl -pi -e 's/foo/bar/g' file.txt

# Print specific fields (like awk)
perl -ane 'print "$F[0] $F[2]\n"' data.txt

# Sum a column of numbers
perl -ane '$sum += $F[0]; END { print "$sum\n" }' numbers.txt

# Print line numbers
perl -ne 'printf "%4d: %s", $., $_' file.txt

# Remove duplicate lines (preserving order)
perl -ne 'print unless $seen{$_}++' file.txt

# Convert CSV to TSV
perl -pe 's/,/\t/g' data.csv > data.tsv

# JSON pretty-print
perl -MJSON -e 'print JSON->new->pretty->encode(decode_json(do{local $/;<STDIN>}))'

# Count word frequencies
perl -ane '$w{lc $_}++ for @F; END { printf "%5d %s\n", $w{$_}, $_ for sort { $w{$b}<=>$w{$a} } keys %w }' book.txt

# Base64 encode/decode
echo "Hello" | perl -MMIME::Base64 -ne 'print encode_base64($_)'
echo "SGVsbG8K" | perl -MMIME::Base64 -ne 'print decode_base64($_)'
```

**Useful flags:**

| Flag | Meaning |
|------|---------|
| `-e` | Execute code from command line |
| `-E` | Like `-e` but enables feature bundle |
| `-n` | Wrap code in `while (<>) { ... }` loop |
| `-p` | Like `-n` but also prints `$_` |
| `-i` | Edit files in-place |
| `-a` | Auto-split mode (populates `@F`) |
| `-l` | Auto-chomp input, add newline to output |
| `-w` | Enable warnings |

---

### 20. Best Practices and Modern Perl

#### 20.1 Always Use Strict and Warnings

```perl
use strict;
use warnings;
use feature 'say';     # enables say, given/when, state, etc.
# Or use a version declaration:
use v5.20;             # enables all features for Perl 5.20
```

#### 20.2 Use Modern Idioms

```perl
# Defined-or for defaults
my $name = $input // "anonymous";

# Chained string operations with /r (non-destructive)
my $clean = $raw =~ s/^\s+//r =~ s/\s+$//r;

# State variables (persist across calls)
sub next_id {
    state $id = 0;
    return ++$id;
}

# Postfix dereferencing (Perl 5.20+)
my $ref = [1, 2, 3];
for my $item ($ref->@*) {
    say $item;
}

my $href = { a => 1, b => 2 };
for my $key ($href->%*) {
    say $key;
}
```

#### 20.3 Code Organization Tips

1. **One package per file** — keep modules small and focused.
2. **Use named parameters** — pass hashes for functions with many arguments.
3. **Return early** — avoid deep nesting with guard clauses.
4. **Avoid global variables** — use lexical (`my`) variables.
5. **Use `Carp` instead of `die`** — for better error messages from modules.
6. **Write tests** — use `Test::More` for unit testing.

```perl
use Carp qw(croak confess);

sub divide {
    my ($a, $b) = @_;
    croak "Division by zero" if $b == 0;
    return $a / $b;
}
```

#### 20.4 Testing with Test::More

```perl
use Test::More tests => 5;

# Basic tests
ok(1 + 1 == 2, "basic arithmetic");
is(length("hello"), 5, "string length");
isnt("foo", "bar", "strings differ");
like("Hello World", qr/World/, "pattern match");

# Structured comparison
is_deeply(
    [1, 2, 3],
    [1, 2, 3],
    "arrays are equal"
);
```

---

## Practical Examples

The `examples/` directory contains runnable scripts demonstrating real-world usage. See each file for detailed inline documentation.

| File | Description |
|------|-------------|
| `01_hello_world.pl` | Basic program structure |
| `02_variables.pl` | Scalars, arrays, and hashes |
| `03_control_flow.pl` | Conditionals and loops |
| `04_subroutines.pl` | Functions and parameter handling |
| `05_regex.pl` | Regular expression matching and substitution |
| `06_file_handling.pl` | Reading, writing, and processing files |
| `07_references.pl` | References and complex data structures |
| `08_oop.pl` | Object-oriented programming |
| `09_log_analyzer.pl` | Practical: analyze a log file |
| `10_csv_processor.pl` | Practical: process CSV data |
| `11_file_dedup.pl` | Practical: find duplicate files |
| `12_text_statistics.pl` | Practical: text analysis tool |
| `13_sysadmin_toolkit.pl` | Practical: system administration tasks |
