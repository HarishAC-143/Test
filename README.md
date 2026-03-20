# TCL Programming Tutorial

A comprehensive tutorial covering TCL (Tool Command Language) programming from basics to advanced topics, with practical real-world examples.

## Contents

The tutorial (`tcl_tutorial.md`) covers:

### Fundamentals
- Introduction and language overview
- Installation and setup
- Basic syntax, substitution rules, and grouping
- Variables, data types, and mathematical expressions
- Operators (arithmetic, comparison, logical, bitwise)
- Control flow (`if`, `switch`, `for`, `foreach`, `while`)

### Core Features
- String operations (search, match, format, classify)
- Lists (create, modify, search, sort, nested lists)
- Associative arrays
- Dictionaries (ordered key-value structures with filtering and mapping)
- Procedures (default/variable args, scope control with `upvar`/`uplevel`, recursion)
- File I/O (read, write, binary, directory operations)

### Advanced Topics
- Regular expressions (`regexp`, `regsub`)
- Error handling (`try`/`catch`/`throw`/`trap`)
- Namespaces and command ensembles
- Object-oriented programming with TclOO (classes, inheritance, mixins)
- Event-driven programming (`after`, `fileevent`, coroutines)
- Interprocess communication and OS interaction
- Packages and modules

### Practical Examples
1. **CSV File Parser** — handles quoted fields, custom delimiters
2. **Log File Analyzer** — statistics extraction, hourly activity breakdown
3. **Configuration File Manager** — INI-style config reader/writer
4. **Directory Tree Walker** — recursive traversal with file statistics
5. **HTTP Client** — GET/POST requests using the `http` package
6. **Task Scheduler / Job Queue** — priority-based job execution
7. **Text Processing Pipeline** — functional-style data transformations
8. **Unit Test Framework** — assertions, test suites, reporting
9. **EDA/FPGA Build Script** — synthesis automation workflow
10. **Interactive Calculator** — REPL with variables and history

## Quick Start

```bash
# Verify TCL is installed
tclsh <<< 'puts "TCL [info patchlevel] is working!"'

# Read the tutorial
# Open tcl_tutorial.md in your preferred viewer
```

## Requirements

- TCL 8.6 or later (for TclOO, coroutines, try/throw support)
