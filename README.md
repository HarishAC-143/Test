# Comprehensive TCL Programming Tutorial

A complete guide to learning TCL (Tool Command Language) — from basic syntax to advanced techniques — with fully runnable example scripts.

## Tutorial

The full tutorial is in [`tcl_tutorial.md`](tcl_tutorial.md) and covers:

| Section | Topics |
|---|---|
| **Basics** | Syntax, variables, data types, operators, expressions |
| **Strings** | Indexing, search, formatting, `string map`, `format`, `scan` |
| **Lists** | Creation, manipulation, sorting, searching, `lmap`, nested lists |
| **Arrays** | Associative arrays, iteration, passing to procedures |
| **Dictionaries** | `dict` operations, nesting, filtering, `dict map` |
| **Control Flow** | `if/elseif/else`, `switch`, `for`, `while`, `foreach`, `break/continue` |
| **Procedures** | Arguments, defaults, `args`, `upvar`, `uplevel`, recursion, lambdas |
| **File I/O** | Reading, writing, file information, globbing, path manipulation |
| **Regular Expressions** | `regexp`, `regsub`, capturing groups, practical patterns |
| **Namespaces** | Nested namespaces, import/export, ensembles |
| **Error Handling** | `try/on/trap/finally`, `catch`, `throw`, custom error codes |
| **Packages** | Creating and using packages, `source` |
| **OOP (TclOO)** | Classes, inheritance, polymorphism, mixins |
| **Event-Driven** | `after`, `vwait`, `fileevent`, timers |
| **IPC** | `exec`, pipelines, socket programming |
| **Advanced** | Coroutines, interpreters, introspection, tracing, metaprogramming |
| **Practical Examples** | CSV parser, log analyzer, HTTP client, config manager, EDA scripting |

## Runnable Examples

The [`examples/`](examples/) directory contains self-contained scripts you can run directly:

| Script | Description |
|---|---|
| [`01_basics.tcl`](examples/01_basics.tcl) | Variables, arithmetic, strings, quoting, type checking |
| [`02_control_flow.tcl`](examples/02_control_flow.tcl) | if/else, switch, for, while, foreach, nested loops |
| [`03_lists_and_dicts.tcl`](examples/03_lists_and_dicts.tcl) | Lists, arrays, dictionaries, matrices, filtering |
| [`04_procedures.tcl`](examples/04_procedures.tcl) | Functions, recursion, upvar, lambdas, map/filter/reduce |
| [`05_file_io.tcl`](examples/05_file_io.tcl) | File read/write, CSV parsing, directory listing |
| [`06_regex.tcl`](examples/06_regex.tcl) | Pattern matching, capturing, substitution, validation |
| [`07_oop.tcl`](examples/07_oop.tcl) | Classes, inheritance, polymorphism, data structures |
| [`08_error_handling.tcl`](examples/08_error_handling.tcl) | try/catch, custom errors, retry pattern, assertions |
| [`09_namespaces_packages.tcl`](examples/09_namespaces_packages.tcl) | Namespaces, ensembles, stack/queue implementations |
| [`10_practical_projects.tcl`](examples/10_practical_projects.tcl) | Word counter, calculator, pipeline, state machine, template engine |

### Running the Examples

```bash
# Make sure TCL is installed
tclsh <<< 'puts [info patchlevel]'

# Run any example
tclsh examples/01_basics.tcl
tclsh examples/02_control_flow.tcl

# Run all examples
for f in examples/*.tcl; do echo "=== $f ==="; tclsh "$f"; echo; done
```

## Prerequisites

- **TCL 8.6+** (for TclOO, coroutines, `try/on/finally`, `lmap`, `dict map`)
- Any operating system (Linux, macOS, Windows)

### Install TCL

```bash
# Debian/Ubuntu
sudo apt-get install tcl

# RHEL/CentOS/Fedora
sudo dnf install tcl

# macOS
brew install tcl-tk
```

## License

This tutorial is provided as-is for educational purposes.
