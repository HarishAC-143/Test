# Comprehensive BASH Programming Tutorial

A complete guide to BASH shell scripting, covering fundamentals through advanced topics with hands-on examples.

## What You'll Learn

| Part | Topic | Description |
|------|-------|-------------|
| **1** | [Foundations](bash-tutorial.md#part-1-foundations) | Variables, data types, quoting, arithmetic, user input |
| **2** | [Control Flow](bash-tutorial.md#part-2-control-flow) | if/elif/else, test expressions, case, for/while/until loops |
| **3** | [Functions](bash-tutorial.md#part-3-functions) | Definitions, arguments, return values, scope, recursion |
| **4** | [Arrays & Strings](bash-tutorial.md#part-4-arrays-and-strings) | Indexed/associative arrays, string manipulation, pattern matching |
| **5** | [File & I/O Operations](bash-tutorial.md#part-5-file-and-io-operations) | File tests, reading/writing, redirection, pipes, here documents |
| **6** | [Advanced Topics](bash-tutorial.md#part-6-advanced-topics) | Regex, process management, signals, debugging, error handling, sed/awk |
| **7** | [Practical Examples](bash-tutorial.md#part-7-practical-examples) | Real-world scripts: system info, backups, log analysis, and more |

## Runnable Example Scripts

All examples in the `examples/` directory are self-contained and executable:

| Script | Description |
|--------|-------------|
| [`01_hello_world.sh`](examples/01_hello_world.sh) | First script, echo, variables, command substitution |
| [`02_variables_and_input.sh`](examples/02_variables_and_input.sh) | Variable assignment, quoting, parameter expansion |
| [`03_control_flow.sh`](examples/03_control_flow.sh) | if/elif/else, loops, case statements, break/continue |
| [`04_functions.sh`](examples/04_functions.sh) | Functions, arguments, scope, recursion, higher-order patterns |
| [`05_arrays_and_strings.sh`](examples/05_arrays_and_strings.sh) | Indexed/associative arrays, string ops, regex matching |
| [`06_file_operations.sh`](examples/06_file_operations.sh) | File I/O, redirection, pipes, process substitution |
| [`07_advanced_topics.sh`](examples/07_advanced_topics.sh) | Processes, signals, traps, debugging, namerefs |
| [`08_system_info.sh`](examples/08_system_info.sh) | Practical: System information reporter |
| [`09_backup_tool.sh`](examples/09_backup_tool.sh) | Practical: Automated backup with rotation |
| [`10_text_processing.sh`](examples/10_text_processing.sh) | Practical: CSV/log analysis with sed and awk |

### Running the Examples

```bash
# Make all scripts executable (already done)
chmod +x examples/*.sh

# Run any example
./examples/01_hello_world.sh
./examples/01_hello_world.sh "Your Name"

# Run the system info reporter
./examples/08_system_info.sh
./examples/08_system_info.sh -o report.txt

# Run the backup tool
./examples/09_backup_tool.sh --source /path/to/dir --dest /path/to/backups --keep 5

# Run text processing examples
./examples/10_text_processing.sh
```

## Prerequisites

- BASH 4.0+ (for associative arrays, `${var,,}`, `${var^^}`, etc.)
- Standard Unix utilities: `awk`, `sed`, `grep`, `sort`, `find`, `bc`

Check your version:

```bash
bash --version
```

## Quick Start

If you're new to BASH, start with the [tutorial](bash-tutorial.md) from Part 1 and run the corresponding example scripts as you go. Each script is designed to reinforce the concepts from that section of the tutorial.

## Repository Structure

```
.
├── README.md              # This file
├── bash-tutorial.md       # Complete tutorial document
└── examples/
    ├── 01_hello_world.sh
    ├── 02_variables_and_input.sh
    ├── 03_control_flow.sh
    ├── 04_functions.sh
    ├── 05_arrays_and_strings.sh
    ├── 06_file_operations.sh
    ├── 07_advanced_topics.sh
    ├── 08_system_info.sh
    ├── 09_backup_tool.sh
    └── 10_text_processing.sh
```
