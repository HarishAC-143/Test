# TCL Programming Tutorial: From Basics to Advanced

A comprehensive, hands-on tutorial for learning **Tcl (Tool Command Language)** — a powerful, flexible scripting language widely used in EDA tools, embedded systems, network automation, testing frameworks, and rapid prototyping.

## Why Learn Tcl?

- **Simple syntax** — everything is a command, and every value is a string
- **Embeddable** — easily integrated into C/C++ applications as a scripting engine
- **Cross-platform** — runs on Linux, macOS, Windows, and many embedded systems
- **Industry standard** — dominant in EDA (Synopsys, Cadence, Mentor), network testing (Ixia, Spirent), and automation
- **Tk GUI toolkit** — build cross-platform GUIs with minimal code

## Prerequisites

- A Tcl interpreter installed on your system (`tclsh` or `wish` for GUI)
- Any text editor
- Basic programming concepts (helpful but not required)

### Installing Tcl

```bash
# Ubuntu / Debian
sudo apt-get install tcl

# macOS (Homebrew)
brew install tcl-tk

# Verify installation
tclsh <<< 'puts "Tcl [info patchlevel] is ready!"'
```

## Tutorial Contents

### Part 1: Foundations

| # | Topic | Description |
|---|-------|-------------|
| 1 | [Introduction & Basic Syntax](docs/01-introduction-and-syntax.md) | Commands, comments, quoting rules, and the Tcl evaluation model |
| 2 | [Variables & Data Types](docs/02-variables-and-data-types.md) | Scalars, type coercion, and variable operations |
| 3 | [Operators & Expressions](docs/03-operators-and-expressions.md) | Arithmetic, comparison, logical, and string operators |
| 4 | [Control Flow](docs/04-control-flow.md) | if/elseif/else, switch, for, while, foreach, break/continue |

### Part 2: Core Data Structures & Procedures

| # | Topic | Description |
|---|-------|-------------|
| 5 | [Procedures & Scope](docs/05-procedures-and-scope.md) | Defining procedures, arguments, defaults, variable-length args, scope |
| 6 | [String Operations](docs/06-string-operations.md) | String commands, formatting, pattern matching, unicode |
| 7 | [Lists](docs/07-lists.md) | List creation, manipulation, searching, sorting, iteration |
| 8 | [Arrays & Dictionaries](docs/08-arrays-and-dictionaries.md) | Associative arrays, nested dicts, data modeling |

### Part 3: Advanced Topics

| # | Topic | Description |
|---|-------|-------------|
| 9  | [File I/O & System Interaction](docs/09-file-io-and-system.md) | Reading/writing files, channels, exec, processes |
| 10 | [Regular Expressions](docs/10-regular-expressions.md) | Pattern matching, capture groups, substitution |
| 11 | [Error Handling](docs/11-error-handling.md) | catch, try/finally, custom errors, debugging |
| 12 | [Namespaces & Packages](docs/12-namespaces-and-packages.md) | Code organization, namespace ensembles, packages |
| 13 | [Object-Oriented Programming](docs/13-oop-with-tcloo.md) | TclOO classes, inheritance, mixins, design patterns |
| 14 | [Event-Driven Programming](docs/14-event-driven-programming.md) | Event loop, after, fileevent, coroutines |

### Part 4: Practical Examples

| # | Example | Description |
|---|---------|-------------|
| 1 | [Calculator](examples/calculator.tcl) | Interactive command-line calculator |
| 2 | [File Search Tool](examples/file_search.tcl) | Recursive file finder with pattern matching |
| 3 | [Config File Parser](examples/config_parser.tcl) | INI-style configuration file reader/writer |
| 4 | [Log Analyzer](examples/log_analyzer.tcl) | Parse and analyze log files with statistics |
| 5 | [TCP Chat Server](examples/chat_server.tcl) | Multi-client chat server using sockets |
| 6 | [JSON Parser](examples/json_parser.tcl) | Lightweight JSON to Tcl dict converter |
| 7 | [Unit Test Framework](examples/test_framework.tcl) | Minimal unit testing framework |
| 8 | [Task Manager](examples/task_manager.tcl) | CLI task/todo manager with file persistence |

## Quick Start

Run any example directly:

```bash
tclsh examples/calculator.tcl
tclsh examples/task_manager.tcl
```

Or start an interactive Tcl session:

```bash
tclsh
% puts "Hello, Tcl!"
Hello, Tcl!
% expr {2 + 3}
5
% exit
```

## License

This tutorial is released under the [MIT License](LICENSE).
