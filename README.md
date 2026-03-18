# Comprehensive BASH Programming Tutorial

A complete, hands-on guide to Bash shell scripting with 20 in-depth topic sections and 10 practical, real-world example scripts.

## Overview

This tutorial takes you from the fundamentals of Bash scripting all the way through advanced techniques like signal handling, process substitution, and robust error handling. Every concept is paired with runnable code examples.

## Tutorial Contents

The main tutorial is in [`bash-programming-tutorial.md`](bash-programming-tutorial.md) and covers:

| # | Topic | What You'll Learn |
|---|-------|-------------------|
| 1 | **Introduction to Bash** | What Bash is, why it matters, comparison with other shells |
| 2 | **Getting Started** | Shebang lines, file permissions, running scripts, comments |
| 3 | **Variables** | Declaration, quoting, scope, `export`, special variables, parameter expansion |
| 4 | **User Input** | `read` command, timeouts, silent input, `select` menus |
| 5 | **Operators** | Arithmetic, comparison (integer & string), file tests, logical operators |
| 6 | **Conditional Statements** | `if`/`elif`/`else`, `[[ ]]` vs `[ ]`, `case`, ternary patterns |
| 7 | **Loops** | `for`, `while`, `until`, `break`, `continue`, nested loop control |
| 8 | **Functions** | Definition, arguments, return values, `local` variables, recursion |
| 9 | **Arrays** | Indexed arrays, associative arrays, slicing, sorting, searching |
| 10 | **String Manipulation** | Substrings, find/replace, case conversion, splitting, trimming |
| 11 | **File & Directory Operations** | Testing, reading, writing, temp files, `pushd`/`popd` |
| 12 | **I/O Redirection & Pipes** | File descriptors, redirection, custom FDs, pipes, `tee` |
| 13 | **Command & Process Substitution** | `$()`, `<()`, nested substitution |
| 14 | **Here Documents & Here Strings** | `<<EOF`, `<<-`, `<<<`, literal vs expanded |
| 15 | **Regular Expressions & Pattern Matching** | Globs, `=~`, `BASH_REMATCH`, `grep`/`sed`/`awk` |
| 16 | **Error Handling & Debugging** | Exit status, strict mode (`set -euo pipefail`), `trap`, debugging |
| 17 | **Signal Handling with `trap`** | Catching signals, cleanup patterns, `EXIT`/`INT`/`TERM`/`ERR` |
| 18 | **Subshells & Command Grouping** | `()` vs `{}`, parallel execution, `wait` |
| 19 | **Best Practices** | Strict mode, quoting, validation, ShellCheck, style conventions |
| 20 | **Practical Examples** | Links to 10 complete real-world scripts |

## Practical Example Scripts

The [`examples/`](examples/) directory contains 10 complete, production-style scripts that demonstrate real-world Bash programming:

| Script | Description | Key Concepts |
|--------|-------------|--------------|
| [`01_system_info.sh`](examples/01_system_info.sh) | System information reporter | Functions, `/proc` filesystem, formatting, CLI flags |
| [`02_backup_tool.sh`](examples/02_backup_tool.sh) | Compressed backup tool with retention | `tar`, argument parsing, logging, date arithmetic |
| [`03_log_analyzer.sh`](examples/03_log_analyzer.sh) | Log file parser and summarizer | Text processing, associative arrays, pattern matching |
| [`04_process_monitor.sh`](examples/04_process_monitor.sh) | Process and resource monitor | `/proc` parsing, `ps`, signal handling, real-time display |
| [`05_text_processor.sh`](examples/05_text_processor.sh) | CSV/text file processor | `awk`, field extraction, statistics, format conversion |
| [`06_network_utils.sh`](examples/06_network_utils.sh) | Network diagnostic toolkit | Port scanning, DNS, `/dev/tcp`, `curl`, `ss` |
| [`07_user_manager.sh`](examples/07_user_manager.sh) | Menu-driven user management | Interactive menus, input validation, `/etc/passwd` |
| [`08_file_organizer.sh`](examples/08_file_organizer.sh) | Automatic file organizer | Associative arrays, `find`, dry-run, undo support |
| [`09_deployment_script.sh`](examples/09_deployment_script.sh) | Application deployment automation | Multi-step workflows, rollback, health checks |
| [`10_database_backup.sh`](examples/10_database_backup.sh) | Database backup with rotation | `mysqldump`/`pg_dump`, compression, encryption |

## Quick Start

```bash
# Read the tutorial
less bash-programming-tutorial.md

# Run an example script
chmod +x examples/*.sh
./examples/01_system_info.sh --help
./examples/01_system_info.sh
./examples/01_system_info.sh --json

# Try the backup tool (dry run)
./examples/02_backup_tool.sh -s /etc -d /tmp/backups --dry-run

# Run the process monitor (single snapshot)
./examples/04_process_monitor.sh --snapshot

# Deploy a sample app (dry run)
./examples/09_deployment_script.sh --env dev --app myapp --dry-run
```

## Prerequisites

- **Bash 4.0+** (for associative arrays, `mapfile`, case conversion)
- Standard Unix tools: `grep`, `sed`, `awk`, `find`, `sort`, `cut`, `tr`
- Optional: `bc` (floating-point math), `curl` (HTTP), `jq` (JSON)

Check your Bash version:

```bash
bash --version
```

## License

This tutorial is provided as-is for educational purposes. Feel free to use, modify, and share.
