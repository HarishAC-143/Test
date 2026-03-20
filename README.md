# Perl Programming Tutorial

A comprehensive tutorial on Perl programming — from the absolute basics through advanced topics — with rich examples and hands-on exercises.

## Who This Is For

- Programmers new to Perl who want a structured learning path
- Developers from other languages looking to pick up Perl quickly
- System administrators wanting to leverage Perl for automation
- Anyone who needs to understand or maintain Perl codebases

## Table of Contents

### Fundamentals

| Chapter | Topic | What You'll Learn |
|---------|-------|-------------------|
| [1. Introduction](01-introduction.md) | Getting Started | Installing Perl, first program, running scripts, one-liners |
| [2. Variables & Data Types](02-variables-and-data-types.md) | Core Data Types | Scalars, arrays, hashes, context, special variables |
| [3. Operators & Control Structures](03-operators-and-control-structures.md) | Program Flow | Arithmetic, comparison, logic, if/else, loops, loop control |
| [4. Subroutines](04-subroutines.md) | Functions | Parameters, return values, scope, closures, dispatch tables |

### Core Skills

| Chapter | Topic | What You'll Learn |
|---------|-------|-------------------|
| [5. Regular Expressions](05-regular-expressions.md) | Pattern Matching | Matching, capturing, substitution, lookahead/behind, qr// |
| [6. References & Data Structures](06-references-and-data-structures.md) | Complex Data | References, nested structures, AoH/HoA/HoH, Data::Dumper |
| [7. File I/O](07-file-io.md) | File Operations | Reading, writing, file tests, directories, encoding, temp files |

### Advanced

| Chapter | Topic | What You'll Learn |
|---------|-------|-------------------|
| [8. Modules & CPAN](08-modules-and-cpan.md) | Code Reuse | Core modules, creating modules, Exporter, CPAN ecosystem |
| [9. Object-Oriented Perl](09-object-oriented-perl.md) | OOP | Classes, inheritance, Moo, roles, operator overloading |
| [10. Error Handling](10-error-handling.md) | Robustness | die/warn, eval, Try::Tiny, Carp, exception objects, retry patterns |
| [11. Advanced Topics](11-advanced-topics.md) | Pro Techniques | DBI, processes, testing, one-liners, profiling, networking |

### Practice

| Resource | Description |
|----------|-------------|
| [12. Practical Examples](12-practical-examples.md) | 7 complete real-world programs with full explanations |
| [Exercises](exercises/exercises.md) | 9 graded exercises (beginner → advanced) with hints |

## Runnable Example Scripts

The [`examples/`](examples/) directory contains standalone scripts you can run immediately:

| Script | Description | Key Concepts |
|--------|-------------|--------------|
| [`01_hello_world.pl`](examples/01_hello_world.pl) | First program, strings, output | `print`, interpolation, here-docs |
| [`02_variables_demo.pl`](examples/02_variables_demo.pl) | All variable types in action | Scalars, arrays, hashes, nested data |
| [`03_regex_toolkit.pl`](examples/03_regex_toolkit.pl) | Pattern matching showcase | Regex, captures, lookahead, validation |
| [`04_file_processing.pl`](examples/04_file_processing.pl) | Read, process, write files | File I/O, CSV, reports, file tests |
| [`05_oop_demo.pl`](examples/05_oop_demo.pl) | Bank account system | Classes, inheritance, methods |
| [`06_error_handling.pl`](examples/06_error_handling.pl) | Error handling patterns | eval, retry, validation, guard clauses |
| [`07_json_api_demo.pl`](examples/07_json_api_demo.pl) | JSON and HTTP APIs | JSON::PP, HTTP::Tiny, data processing |
| [`08_one_liners_reference.pl`](examples/08_one_liners_reference.pl) | One-liner techniques | Text processing, command-line Perl |

### Running Examples

```bash
# Run any example
perl examples/01_hello_world.pl

# Run the variables demo
perl examples/02_variables_demo.pl

# Run the OOP demo
perl examples/05_oop_demo.pl
```

## Quick Start

If you're new to Perl, start here:

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Variables
my $name = "World";
my @colors = ("red", "green", "blue");
my %ages = (Alice => 30, Bob => 25);

# Output
print "Hello, $name!\n";
print "Colors: @colors\n";
print "Alice is $ages{Alice} years old.\n";

# Loop
for my $color (@colors) {
    print "I like $color.\n";
}

# Regex
my $text = "Call 555-123-4567 today!";
if ($text =~ /(\d{3}-\d{3}-\d{4})/) {
    print "Found phone number: $1\n";
}
```

Save this as `quickstart.pl` and run it with `perl quickstart.pl`.

## Prerequisites

- Perl 5.16+ (check with `perl -v`)
- A text editor
- A terminal / command line

Most Linux and macOS systems have Perl pre-installed. For Windows, install [Strawberry Perl](https://strawberryperl.com/).

## License

This tutorial is provided for educational purposes. Feel free to use, modify, and share.
