# Bash Programming Tutorial

A comprehensive, hands-on tutorial covering Bash shell scripting from fundamentals to advanced techniques, with runnable example scripts and real-world projects.

## Tutorial

The full tutorial is in **[bash-programming-tutorial.md](bash-programming-tutorial.md)** — a single, self-contained document with explanations, code snippets, tables, and links to every example script.

## Repository Structure

```
├── bash-programming-tutorial.md       # Full tutorial document
├── examples/
│   ├── basics/                        # Part 1: Fundamentals
│   │   ├── 01_hello.sh                # Your first script
│   │   ├── 02_variables.sh            # Variables and special variables
│   │   ├── 03_quoting.sh              # Quoting and escaping
│   │   ├── 04_user_input.sh           # Reading user input
│   │   ├── 05_arithmetic.sh           # Arithmetic operations
│   │   ├── 06_conditionals.sh         # if/elif/else, case, test operators
│   │   ├── 07_loops.sh                # for, while, until, break, continue
│   │   ├── 08_functions.sh            # Functions, scope, recursion
│   │   ├── 09_arrays.sh              # Indexed arrays and operations
│   │   ├── 10_strings.sh             # String manipulation
│   │   ├── 11_file_operations.sh     # File create, read, write, test
│   │   ├── 12_arguments.sh           # Command-line arguments and getopts
│   │   ├── 13_exit_codes.sh          # Exit codes and error handling
│   │   └── 14_pipelines.sh           # Pipelines and redirection
│   │
│   ├── advanced/                      # Part 2: Advanced Topics
│   │   ├── 01_assoc_arrays.sh         # Associative arrays (hash maps)
│   │   ├── 02_parameter_expansion.sh  # Advanced parameter expansion
│   │   ├── 03_regex.sh               # Regular expressions and validation
│   │   ├── 04_heredoc.sh             # Here documents and here strings
│   │   ├── 05_process_substitution.sh # Process substitution <() >()
│   │   ├── 06_file_descriptors.sh    # Custom file descriptors
│   │   ├── 07_signals.sh             # Signal handling with trap
│   │   ├── 08_subshells.sh           # Subshells and command grouping
│   │   ├── 09_debugging.sh           # Debugging techniques
│   │   ├── 10_named_pipes.sh         # Named pipes (FIFOs)
│   │   ├── 11_locking.sh             # File locking and concurrency
│   │   ├── 12_performance.sh         # Performance optimization
│   │   └── 13_security.sh            # Security best practices
│   │
│   └── practical/                     # Part 3: Real-World Projects
│       ├── 01_log_analyzer.sh         # Web server log file analyzer
│       ├── 02_system_monitor.sh       # System health monitor with alerts
│       ├── 03_backup.sh              # Automated backup with rotation
│       ├── 04_batch_renamer.sh       # Batch file renamer
│       └── 05_task_manager.sh        # Interactive CLI task manager
```

## Getting Started

Clone the repository and make the scripts executable:

```bash
git clone <repository-url>
cd <repository-name>
chmod +x examples/**/*.sh
```

Run any example directly:

```bash
# Basic examples
./examples/basics/01_hello.sh

# Advanced examples
./examples/advanced/03_regex.sh

# Practical projects (with --demo flag for self-contained demo)
./examples/practical/01_log_analyzer.sh --demo
./examples/practical/02_system_monitor.sh
./examples/practical/03_backup.sh --demo
./examples/practical/04_batch_renamer.sh --demo
./examples/practical/05_task_manager.sh --demo
```

## Topics Covered

### Basics
Variables, quoting, user input, arithmetic, conditionals (`if`/`case`), loops (`for`/`while`/`until`), functions, arrays, string manipulation, file operations, command-line arguments, exit codes, pipelines, and redirection.

### Advanced
Associative arrays, advanced parameter expansion, regular expressions, here documents, process substitution, file descriptors, signal handling (`trap`), subshells, debugging, named pipes, file locking, concurrency, performance optimization, and security best practices.

### Practical Projects
| Project | Description |
|---------|-------------|
| Log Analyzer | Parse web server logs, count IPs, status codes, top URLs |
| System Monitor | Real-time CPU/memory/disk monitoring with alert thresholds |
| Backup Utility | Incremental backups with compression, verification, rotation |
| Batch Renamer | Rename files by pattern, case, sequence, or date stamp |
| Task Manager | Interactive CLI task tracker with add/list/complete/search |

## Prerequisites

- **Bash 4.0+** (for associative arrays, case modification, etc.)
- Standard Unix utilities: `awk`, `sed`, `grep`, `sort`, `cut`, `wc`, `rsync`, `bc`

Check your Bash version:

```bash
bash --version
```

## License

This tutorial is provided as-is for educational purposes.
