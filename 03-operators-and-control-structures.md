# Chapter 3: Operators and Control Structures

## Operators

### Arithmetic Operators

```perl
my $a = 15;
my $b = 4;

print $a + $b,  "\n";   # 19   Addition
print $a - $b,  "\n";   # 11   Subtraction
print $a * $b,  "\n";   # 60   Multiplication
print $a / $b,  "\n";   # 3.75 Division
print $a % $b,  "\n";   # 3    Modulus (remainder)
print $a ** $b, "\n";   # 50625 Exponentiation (15^4)

# Increment and decrement
my $x = 10;
$x++;    # 11  post-increment
$x--;    # 10  post-decrement
++$x;    # 11  pre-increment
--$x;    # 10  pre-decrement
```

### String Operators

```perl
my $first = "Hello";
my $last  = "World";

# Concatenation
my $full = $first . ", " . $last . "!";    # "Hello, World!"

# Repetition
my $line = "-" x 40;         # 40 dashes
my $ha   = "ha" x 3;        # "hahaha"

# Compound assignment
my $msg = "Hello";
$msg .= " World";            # "Hello World"
```

### Comparison Operators

Perl has separate operators for numeric and string comparisons — a common source of bugs for beginners.

| Operation | Numeric | String |
|-----------|---------|--------|
| Equal | `==` | `eq` |
| Not equal | `!=` | `ne` |
| Less than | `<` | `lt` |
| Greater than | `>` | `gt` |
| Less or equal | `<=` | `le` |
| Greater or equal | `>=` | `ge` |
| Spaceship/Compare | `<=>` | `cmp` |

```perl
# Numeric comparisons
print "yes\n" if 10 == 10;       # yes
print "yes\n" if 10 != 20;       # yes
print "yes\n" if 5 < 10;         # yes

# String comparisons
print "yes\n" if "abc" eq "abc";  # yes
print "yes\n" if "abc" lt "def";  # yes (alphabetical order)

# Spaceship operator returns -1, 0, or 1
my $result = 5 <=> 10;    # -1 (5 is less than 10)
my $cmp    = "b" cmp "a"; # 1  ("b" is greater than "a")

# Useful for custom sort
my @sorted = sort { $a <=> $b } (5, 3, 8, 1);  # (1, 3, 5, 8)
```

### Logical Operators

```perl
# C-style (higher precedence)
my $result1 = (1 && 0);   # 0 (AND)
my $result2 = (1 || 0);   # 1 (OR)
my $result3 = !1;          # "" (NOT — false)

# English-style (lower precedence, often used in flow control)
open(my $fh, "<", "file.txt") or die "Cannot open: $!";

if ($age >= 18 and $has_id) {
    print "Entry allowed\n";
}

unless ($logged_in or $is_admin) {
    print "Access denied\n";
}
```

### The Ternary Operator

```perl
my $age = 20;
my $status = ($age >= 18) ? "adult" : "minor";
print "Status: $status\n";   # "Status: adult"

# Can be nested (but use sparingly for readability)
my $grade = ($score >= 90) ? "A"
          : ($score >= 80) ? "B"
          : ($score >= 70) ? "C"
          : "F";
```

### Range Operator

```perl
my @digits = (0..9);          # (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
my @letters = ('a'..'z');     # all lowercase letters
my @alpha = ('A'..'Z', 'a'..'z');  # all letters

for my $i (1..5) {
    print "$i\n";
}
```

## Control Structures

### if / elsif / else

```perl
my $temp = 72;

if ($temp > 90) {
    print "It's hot!\n";
} elsif ($temp > 70) {
    print "It's pleasant.\n";
} elsif ($temp > 50) {
    print "It's cool.\n";
} else {
    print "It's cold!\n";
}

# Postfix form (for single statements)
print "Warm!\n" if $temp > 70;
```

### unless (Negated if)

```perl
my $logged_in = 0;

unless ($logged_in) {
    print "Please log in.\n";
}

# Equivalent to:
if (!$logged_in) {
    print "Please log in.\n";
}

# Postfix form
print "Please log in.\n" unless $logged_in;
```

### given / when (Switch-like)

```perl
use feature 'say';

# Note: given/when is experimental in modern Perl.
# For a stable alternative, use if/elsif chains or hash dispatch tables.

my $day = "Monday";

if ($day eq "Monday" || $day eq "Tuesday" || $day eq "Wednesday"
    || $day eq "Thursday" || $day eq "Friday") {
    say "Weekday";
} elsif ($day eq "Saturday" || $day eq "Sunday") {
    say "Weekend";
} else {
    say "Unknown day";
}

# Hash dispatch table (idiomatic Perl alternative to switch)
my %day_type = map { $_ => "Weekday" } qw(Monday Tuesday Wednesday Thursday Friday);
$day_type{Saturday} = "Weekend";
$day_type{Sunday}   = "Weekend";

say $day_type{$day} // "Unknown day";
```

## Loops

### for / foreach

```perl
# C-style for loop
for (my $i = 0; $i < 10; $i++) {
    print "$i ";
}
print "\n";
# Output: 0 1 2 3 4 5 6 7 8 9

# foreach loop (iterating over a list)
my @fruits = qw(apple banana cherry);
foreach my $fruit (@fruits) {
    print "I like $fruit\n";
}

# "for" and "foreach" are interchangeable in Perl
for my $fruit (@fruits) {
    print "Eating $fruit\n";
}

# Using the default variable $_
for (@fruits) {
    print "Fruit: $_\n";
}

# Iterating over a range
for my $n (1..10) {
    print "$n squared is ", $n ** 2, "\n";
}

# Iterating over hash keys
my %ages = (Alice => 30, Bob => 25, Carol => 28);
for my $name (sort keys %ages) {
    print "$name is $ages{$name} years old\n";
}
```

### while

```perl
my $count = 5;
while ($count > 0) {
    print "Countdown: $count\n";
    $count--;
}

# Reading lines from a file (extremely common pattern)
open(my $fh, "<", "data.txt") or die "Cannot open: $!";
while (my $line = <$fh>) {
    chomp $line;    # remove trailing newline
    print "Line: $line\n";
}
close $fh;

# Reading from standard input
# while (my $input = <STDIN>) {
#     chomp $input;
#     last if $input eq "quit";
#     print "You said: $input\n";
# }
```

### until (Negated while)

```perl
my $n = 1;
until ($n > 10) {
    print "$n ";
    $n++;
}
print "\n";
# Output: 1 2 3 4 5 6 7 8 9 10
```

### do...while

```perl
my $tries = 0;
do {
    $tries++;
    print "Attempt $tries\n";
} while ($tries < 3);
# Always executes at least once
```

### Loop Control

```perl
# last — exit the loop immediately (like "break" in C)
for my $n (1..100) {
    last if $n > 5;
    print "$n ";
}
print "\n";  # Output: 1 2 3 4 5

# next — skip to the next iteration (like "continue" in C)
for my $n (1..10) {
    next if $n % 2 == 0;   # skip even numbers
    print "$n ";
}
print "\n";  # Output: 1 3 5 7 9

# redo — restart the current iteration (rarely used)
my $attempts = 0;
for my $task ("deploy") {
    $attempts++;
    if ($attempts < 3) {
        print "Attempt $attempts failed, retrying...\n";
        redo;
    }
    print "Attempt $attempts succeeded.\n";
}

# Loop labels — control outer loops from inner loops
OUTER: for my $i (1..5) {
    for my $j (1..5) {
        next OUTER if $j == 3;    # skip to next iteration of OUTER
        print "($i,$j) ";
    }
}
print "\n";
```

### Postfix Loops

```perl
# Compact single-statement loops
print "$_ " for 1..5;                         # 1 2 3 4 5
print "\n";

print "$_\n" for qw(apple banana cherry);

my @evens = grep { $_ % 2 == 0 } 1..20;
print "$_ " for @evens;
print "\n";
```

## Practical Example: Number Guessing Game

```perl
#!/usr/bin/perl
use strict;
use warnings;

my $secret = int(rand(100)) + 1;
my $guesses = 0;
my $max_guesses = 7;

print "I'm thinking of a number between 1 and 100.\n";
print "You have $max_guesses guesses.\n\n";

while ($guesses < $max_guesses) {
    $guesses++;
    print "Guess #$guesses: ";
    my $guess = <STDIN>;
    chomp $guess;

    unless ($guess =~ /^\d+$/) {
        print "Please enter a valid number.\n";
        $guesses--;
        next;
    }

    if ($guess == $secret) {
        print "Correct! You guessed it in $guesses tries!\n";
        exit 0;
    } elsif ($guess < $secret) {
        print "Too low!\n";
    } else {
        print "Too high!\n";
    }

    my $remaining = $max_guesses - $guesses;
    print "($remaining guesses remaining)\n\n" if $remaining > 0;
}

print "Out of guesses! The number was $secret.\n";
```

## Chapter Summary

- Perl has rich arithmetic, string, comparison, and logical operators.
- Use numeric operators (`==`, `<=>`) for numbers and string operators (`eq`, `cmp`) for strings.
- Control structures include `if`/`elsif`/`else`, `unless`, `while`, `until`, `for`, and `foreach`.
- Loop control keywords: `last` (break), `next` (continue), `redo` (restart iteration).
- Loop labels allow controlling outer loops from nested inner loops.
- Postfix syntax provides concise one-line control flow.

---

**Previous**: [Chapter 2 — Variables and Data Types](02-variables-and-data-types.md)
**Next**: [Chapter 4 — Subroutines](04-subroutines.md)
