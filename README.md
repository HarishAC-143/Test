# Comprehensive BASH Programming Tutorial

A complete guide to BASH shell scripting, covering everything from basic syntax to advanced features, with runnable example scripts.

## Tutorial

The full tutorial is in [`bash_tutorial.md`](bash_tutorial.md). It covers:

| Section | Topics |
|---------|--------|
| **Basics** | Getting started, variables, quoting, input/output |
| **Operators** | Arithmetic, comparison, file tests, logical operators |
| **Control Flow** | if/elif/else, case, for/while/until loops, select menus |
| **Functions** | Arguments, return values, scope, recursion, arrays in functions |
| **Data Structures** | Indexed arrays, associative arrays, array operations |
| **String Manipulation** | Substring, search/replace, pattern removal, regex matching |
| **File Operations** | Reading, writing, testing, temporary files, file locking |
| **Text Processing** | grep, sed, awk with practical examples |
| **Process Management** | Background jobs, signal handling, parallel execution |
| **Redirection & Pipes** | stdin/stdout/stderr, here documents, process substitution |
| **Error Handling** | Exit codes, strict mode, trap, debugging techniques |
| **Advanced** | Subshells, coprocesses, extended globbing, getopts, nameref |
| **Real-World Examples** | Log analyzer, backup script, system monitor, CSV processor, and more |

## Example Scripts

The [`examples/`](examples/) directory contains runnable scripts that demonstrate each concept:

| Script | Topic |
|--------|-------|
| `01_hello_world.sh` | First script, basic output, system info |
| `02_variables_and_quoting.sh` | Variables, quoting, parameter expansion |
| `03_operators_and_arithmetic.sh` | Arithmetic, comparisons, file tests |
| `04_conditionals.sh` | if/elif/else, case, ternary patterns |
| `05_loops.sh` | for, while, until, loop control, nested loops |
| `06_functions.sh` | Functions, scope, recursion, array arguments |
| `07_arrays.sh` | Indexed/associative arrays, sorting, joining |
| `08_string_manipulation.sh` | Substring, pattern removal, regex, URL parsing |
| `09_file_operations.sh` | Read/write files, CSV processing, temp files |
| `10_text_processing.sh` | grep, sed, awk with log and CSV data |
| `11_error_handling.sh` | Exit codes, traps, retry pattern, validation |
| `12_advanced_features.sh` | Subshells, process substitution, getopts, nameref |
| `13_practical_log_analyzer.sh` | Generates and analyzes log files |
| `14_practical_system_monitor.sh` | Color-coded system health dashboard |
| `15_practical_backup.sh` | Backup with rotation, compression, and reporting |

### Running Examples

```bash
# Run any example directly
./examples/01_hello_world.sh

# Or with bash explicitly
bash examples/05_loops.sh

# Run all examples
for script in examples/*.sh; do
    echo "=== Running: $script ==="
    bash "$script"
    echo ""
done
```

## Requirements

- BASH 4.0 or later (check with `bash --version`)
- Standard Unix utilities: `grep`, `sed`, `awk`, `sort`, `bc`, `df`, `free`

## License

This tutorial is provided for educational purposes. Feel free to use, modify, and share.
