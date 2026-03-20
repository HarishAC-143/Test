# Chapter 5: Regular Expressions

Regular expressions (regex) are one of Perl's greatest strengths. Perl's regex engine is so influential that most modern languages describe their regex support as "Perl-compatible" (PCRE).

## Basic Matching

The `=~` operator binds a string to a pattern. The `!~` operator negates the match.

```perl
#!/usr/bin/perl
use strict;
use warnings;

my $text = "The quick brown fox jumps over the lazy dog";

# Simple match
if ($text =~ /quick/) {
    print "Found 'quick'!\n";
}

# Negated match
if ($text !~ /cat/) {
    print "No cat found.\n";
}

# Match against $_
$_ = "Hello, World!";
if (/World/) {
    print "World found in \$_\n";
}
```

## Metacharacters and Character Classes

| Pattern | Matches |
|---------|---------|
| `.` | Any character except newline |
| `\d` | A digit `[0-9]` |
| `\D` | A non-digit `[^0-9]` |
| `\w` | A word character `[a-zA-Z0-9_]` |
| `\W` | A non-word character |
| `\s` | Whitespace `[ \t\n\r\f]` |
| `\S` | Non-whitespace |
| `\b` | Word boundary |
| `^` | Start of string (or line with `/m`) |
| `$` | End of string (or line with `/m`) |

```perl
my $phone = "Call me at 555-123-4567 today";

if ($phone =~ /\d{3}-\d{3}-\d{4}/) {
    print "Found a phone number!\n";
}

# Character classes
my $grade = "B+";
if ($grade =~ /^[A-F][+-]?$/) {
    print "Valid grade: $grade\n";
}

# Negated character class
if ($text =~ /[^aeiou ]{3,}/) {
    print "Found 3+ consonants in a row\n";
}
```

## Quantifiers

| Quantifier | Meaning |
|-----------|---------|
| `*` | 0 or more (greedy) |
| `+` | 1 or more (greedy) |
| `?` | 0 or 1 (optional) |
| `{n}` | Exactly n times |
| `{n,}` | n or more times |
| `{n,m}` | Between n and m times |
| `*?` | 0 or more (non-greedy / lazy) |
| `+?` | 1 or more (non-greedy) |
| `??` | 0 or 1 (non-greedy) |

```perl
my $html = '<b>bold</b> and <i>italic</i>';

# Greedy: matches as much as possible
if ($html =~ /<.+>/) {
    print "Greedy: $&\n";    # <b>bold</b> and <i>italic</i>
}

# Non-greedy: matches as little as possible
if ($html =~ /<.+?>/) {
    print "Non-greedy: $&\n";  # <b>
}
```

## Capturing Groups

Parentheses `()` capture matched text into numbered variables `$1`, `$2`, etc.

```perl
my $date = "2026-03-20";

if ($date =~ /(\d{4})-(\d{2})-(\d{2})/) {
    print "Year:  $1\n";   # 2026
    print "Month: $2\n";   # 03
    print "Day:   $3\n";   # 20
}

# Named captures (more readable)
if ($date =~ /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/) {
    print "Year:  $+{year}\n";
    print "Month: $+{month}\n";
    print "Day:   $+{day}\n";
}

# Non-capturing groups (when you need grouping but not capturing)
my $time = "14:30:59";
if ($time =~ /(?:\d{2}:){2}\d{2}/) {
    print "Valid time format\n";
}

# Capturing into a list
my $csv = "Alice,30,Engineer";
my ($name, $age, $job) = ($csv =~ /^(\w+),(\d+),(\w+)$/);
print "Name: $name, Age: $age, Job: $job\n";
```

## Alternation

The `|` operator provides alternatives.

```perl
my $pet = "I have a cat";

if ($pet =~ /cat|dog|bird/) {
    print "Found a pet!\n";
}

# Alternation within groups
if ($pet =~ /I have a (cat|dog|bird)/) {
    print "Pet type: $1\n";   # cat
}
```

## Modifiers

| Modifier | Effect |
|----------|--------|
| `i` | Case-insensitive matching |
| `g` | Global — find all matches |
| `m` | Multi-line: `^` and `$` match at line boundaries |
| `s` | Single-line: `.` matches newlines too |
| `x` | Extended: allows whitespace and comments in pattern |
| `e` | Evaluate replacement as Perl code |

```perl
# Case-insensitive
if ("Hello" =~ /hello/i) {
    print "Case-insensitive match!\n";
}

# Global matching — find all matches
my $text = "cat bat hat mat";
my @rhymes = ($text =~ /\b(\w)at\b/g);
print "Rhymes: @rhymes\n";   # c b h m

# Extended mode for complex patterns
my $email_re = qr/
    ^                   # start of string
    ([a-zA-Z0-9._%+-]+) # local part
    @                   # at sign
    ([a-zA-Z0-9.-]+)    # domain
    \.                  # dot
    ([a-zA-Z]{2,})      # TLD
    $                   # end of string
/x;

my $email = 'user@example.com';
if ($email =~ $email_re) {
    print "Valid email: user=$1 domain=$2 tld=$3\n";
}

# Multi-line
my $multiline = "first line\nsecond line\nthird line";
my @lines = ($multiline =~ /^(\w+)/gm);
print "First words: @lines\n";   # first second third
```

## Substitution

The `s///` operator finds and replaces text.

```perl
my $text = "Hello, World!";

# Basic substitution
(my $changed = $text) =~ s/World/Perl/;
print "$changed\n";   # Hello, Perl!

# Global substitution
my $str = "aabbbcccc";
$str =~ s/b/X/g;
print "$str\n";   # aaXXXcccc

# Using captured groups in replacement
my $name = "Smith, John";
$name =~ s/(\w+), (\w+)/$2 $1/;
print "$name\n";   # John Smith

# Using /e to evaluate Perl code in replacement
my $template = "Price: {100 * 1.08}";
$template =~ s/\{(.+?)\}/"${\(eval $1)}"/ge;
print "$template\n";   # Price: 108

# Case conversion in replacement
my $title = "the lord of the rings";
$title =~ s/\b(\w)/\u$1/g;
print "$title\n";   # The Lord Of The Rings

# Transliteration (not regex, but related)
my $msg = "Hello, World!";
(my $upper = $msg) =~ tr/a-z/A-Z/;
print "$upper\n";   # HELLO, WORLD!

my $count = ($msg =~ tr/l//);   # count occurrences of 'l'
print "Letter 'l' appears $count times\n";   # 3
```

## Lookahead and Lookbehind

Zero-width assertions that match a position without consuming characters.

| Pattern | Type | Meaning |
|---------|------|---------|
| `(?=...)` | Positive lookahead | Followed by ... |
| `(?!...)` | Negative lookahead | NOT followed by ... |
| `(?<=...)` | Positive lookbehind | Preceded by ... |
| `(?<!...)` | Negative lookbehind | NOT preceded by ... |

```perl
# Positive lookahead: find words followed by a comma
my $text = "apple, banana, cherry and date";
my @before_comma = ($text =~ /(\w+)(?=,)/g);
print "Before commas: @before_comma\n";   # apple banana

# Negative lookahead: find "foo" not followed by "bar"
my $str = "foobar foobaz foo";
my @matches = ($str =~ /foo(?!bar)\w*/g);
print "Not foobar: @matches\n";   # foobaz foo

# Positive lookbehind: find numbers preceded by $
my $prices = "Items cost $10 and $25 and 30 dollars";
my @amounts = ($prices =~ /(?<=\$)\d+/g);
print "Prices: @amounts\n";   # 10 25

# Practical: add commas to large numbers
my $number = "1234567890";
$number =~ s/(\d)(?=(\d{3})+$)/$1,/g;
print "Formatted: $number\n";   # 1,234,567,890
```

## Compiled Regex with qr//

The `qr//` operator compiles a regex pattern for reuse.

```perl
my $date_pattern = qr/\d{4}-\d{2}-\d{2}/;

my @dates = ("2026-03-20", "not-a-date", "2025-12-31");
for my $str (@dates) {
    if ($str =~ /^$date_pattern$/) {
        print "Valid date: $str\n";
    }
}

# Building complex patterns from parts
my $year  = qr/\d{4}/;
my $month = qr/(?:0[1-9]|1[0-2])/;
my $day   = qr/(?:0[1-9]|[12]\d|3[01])/;
my $iso_date = qr/^$year-$month-$day$/;

print "2026-03-20 valid\n" if "2026-03-20" =~ $iso_date;
print "2026-13-01 valid\n" if "2026-13-01" =~ $iso_date;   # won't print
```

## Practical Example: Log File Parser

```perl
#!/usr/bin/perl
use strict;
use warnings;

my $log_data = <<'END_LOG';
2026-03-20 10:15:32 [INFO] Server started on port 8080
2026-03-20 10:15:33 [INFO] Database connection established
2026-03-20 10:16:01 [WARN] High memory usage: 85%
2026-03-20 10:16:45 [ERROR] Failed to process request: timeout
2026-03-20 10:17:02 [INFO] Request completed in 230ms
2026-03-20 10:17:15 [ERROR] Database query failed: deadlock detected
2026-03-20 10:18:00 [INFO] Health check passed
END_LOG

my $log_pattern = qr/
    ^(\d{4}-\d{2}-\d{2})     # date
    \s+
    (\d{2}:\d{2}:\d{2})      # time
    \s+
    \[(\w+)\]                 # log level
    \s+
    (.+)$                     # message
/xm;

my %level_count;
my @errors;

while ($log_data =~ /$log_pattern/g) {
    my ($date, $time, $level, $message) = ($1, $2, $3, $4);
    $level_count{$level}++;

    if ($level eq "ERROR") {
        push @errors, {
            timestamp => "$date $time",
            message   => $message,
        };
    }
}

print "=== Log Summary ===\n";
for my $level (sort keys %level_count) {
    printf "%-8s %d\n", $level, $level_count{$level};
}

print "\n=== Errors ===\n";
for my $err (@errors) {
    print "[$err->{timestamp}] $err->{message}\n";
}
```

Output:

```
=== Log Summary ===
ERROR    2
INFO     4
WARN     1

=== Errors ===
[2026-03-20 10:16:45] Failed to process request: timeout
[2026-03-20 10:17:15] Database query failed: deadlock detected
```

## Chapter Summary

- Perl's regex engine is one of the most powerful available and has influenced all modern regex implementations.
- Use `=~` for matching and `s///` for substitution.
- Parentheses `()` capture matches into `$1`, `$2`, etc.; use `(?<name>...)` for named captures.
- Quantifiers are greedy by default; append `?` for non-greedy matching.
- Lookahead and lookbehind assert positions without consuming input.
- The `/x` modifier makes complex patterns readable with whitespace and comments.
- Compile reusable patterns with `qr//`.

---

**Previous**: [Chapter 4 — Subroutines](04-subroutines.md)
**Next**: [Chapter 6 — References and Data Structures](06-references-and-data-structures.md)
