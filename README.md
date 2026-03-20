# Perl Programming Tutorial: From Basics to Advanced

A comprehensive, hands-on guide to learning Perl — covering fundamentals, intermediate techniques, advanced features, and practical real-world examples.

## Table of Contents

- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Tutorial Contents](#tutorial-contents)
- [Running the Examples](#running-the-examples)
- [Resources](#resources)

## Introduction

Perl is a high-level, general-purpose, interpreted programming language originally developed by Larry Wall in 1987. Known for its powerful text-processing capabilities, Perl remains a vital tool for system administration, web development, network programming, bioinformatics, and automation.

This tutorial provides a structured path from absolute beginner to advanced Perl programmer, complete with runnable example scripts in the `examples/` directory.

## Getting Started

### Prerequisites

- Perl 5.10 or later (check with `perl -v`)
- A text editor or IDE
- A terminal / command line

### Installing Perl

**Linux/macOS:** Perl is typically pre-installed. Verify with:

```bash
perl -v
```

**Windows:** Install [Strawberry Perl](https://strawberryperl.com/) or [ActivePerl](https://www.activestate.com/products/perl/).

## Tutorial Contents

The full tutorial is in [`perl_tutorial.md`](perl_tutorial.md) and covers:

### Part 1 — Basics
1. Hello World & Program Structure
2. Variables: Scalars, Arrays, Hashes
3. Operators
4. Control Flow (if/elsif/else, unless, loops)
5. String Operations
6. Input and Output
7. Subroutines (Functions)

### Part 2 — Intermediate
8. Regular Expressions
9. File Handling
10. References and Complex Data Structures
11. Modules and Packages
12. Error Handling
13. Object-Oriented Programming (OOP)

### Part 3 — Advanced
14. Advanced Regular Expressions
15. Closures and Higher-Order Functions
16. Database Access with DBI
17. Network Programming
18. Multithreading and Forking
19. One-Liners and Command-Line Perl
20. Best Practices and Modern Perl

### Practical Examples
- Text log analyzer
- CSV data processor
- Web scraper
- System administration toolkit
- File duplicate finder

## Running the Examples

Each example in the `examples/` directory is a self-contained Perl script:

```bash
cd examples
perl 01_hello_world.pl
perl 02_variables.pl
# ... and so on
```

## Resources

- [Official Perl Documentation](https://perldoc.perl.org/)
- [CPAN — Comprehensive Perl Archive Network](https://www.cpan.org/)
- [Learn Perl in about 2 hours 30 minutes](https://qntm.org/perl_en)
- [Perl Maven](https://perlmaven.com/)
- [Modern Perl (free book)](http://modernperlbooks.com/)
