# BASH Programming Tutorial

A comprehensive tutorial covering BASH scripting from fundamentals to advanced techniques, with fully worked practical examples.

## Contents

### Tutorial

The main tutorial is in [`bash-programming-tutorial.md`](bash-programming-tutorial.md) and covers 25 topics:

| # | Topic | Level |
|---|-------|-------|
| 1 | Introduction to BASH | Beginner |
| 2 | Getting Started | Beginner |
| 3 | Variables | Beginner |
| 4 | Quoting and Escaping | Beginner |
| 5 | User Input and Output | Beginner |
| 6 | Operators | Beginner |
| 7 | Conditional Statements | Beginner |
| 8 | Loops | Beginner |
| 9 | Functions | Intermediate |
| 10 | Arrays | Intermediate |
| 11 | String Manipulation | Intermediate |
| 12 | File and Directory Operations | Intermediate |
| 13 | Regular Expressions | Intermediate |
| 14 | Process Management | Intermediate |
| 15 | I/O Redirection and Pipes | Intermediate |
| 16 | Error Handling and Debugging | Intermediate |
| 17 | Signals and Traps | Advanced |
| 18 | Subshells and Process Substitution | Advanced |
| 19 | Here Documents and Here Strings | Advanced |
| 20 | Advanced Parameter Expansion | Advanced |
| 21 | Associative Arrays | Advanced |
| 22 | Command-Line Argument Parsing | Advanced |
| 23 | Networking with BASH | Advanced |
| 24 | Performance and Best Practices | Advanced |
| 25 | Practical Examples | All Levels |

### Example Scripts

Ready-to-run scripts are in the [`examples/`](examples/) directory:

| Script | Description |
|--------|-------------|
| `01_system_info.sh` | Gathers and displays system information (CPU, memory, disk, network) |
| `02_backup.sh` | Automated compressed backups with timestamp and rotation |
| `03_log_analyzer.sh` | Parses log files and produces a summary report |
| `04_bulk_renamer.sh` | Renames files in bulk using regex search/replace |
| `05_csv_database.sh` | Interactive CRUD interface for a CSV "database" |
| `06_health_monitor.sh` | Monitors HTTP endpoints and reports status |
| `07_git_stats.sh` | Generates statistics for a Git repository |
| `08_config_parser.sh` | Parses INI-style config files into BASH variables |

## Quick Start

```bash
# Clone and enter the repository
git clone <repo-url>
cd <repo-name>

# Read the tutorial
less bash-programming-tutorial.md

# Run an example script
cd examples
chmod +x *.sh
./01_system_info.sh
```

## Prerequisites

- BASH 4.0 or later (check with `bash --version`)
- Standard Linux/macOS utilities (`coreutils`, `grep`, `awk`, `sed`, `curl`)

## License

This tutorial is provided for educational purposes.
