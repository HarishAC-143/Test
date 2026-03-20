# Comprehensive BASH Programming Tutorial

A complete guide to Bash shell scripting — from foundational concepts to advanced techniques — with runnable examples and real-world projects.

---

## Table of Contents

### Part 1: Basics

1. [What Is Bash?](#1-what-is-bash)
2. [Your First Script](#2-your-first-script)
3. [Variables](#3-variables)
4. [Quoting and Escaping](#4-quoting-and-escaping)
5. [User Input](#5-user-input)
6. [Arithmetic Operations](#6-arithmetic-operations)
7. [Conditional Statements](#7-conditional-statements)
8. [Loops](#8-loops)
9. [Functions](#9-functions)
10. [Arrays](#10-arrays)
11. [String Manipulation](#11-string-manipulation)
12. [File Operations](#12-file-operations)
13. [Command-Line Arguments](#13-command-line-arguments)
14. [Exit Codes and Error Handling](#14-exit-codes-and-error-handling)
15. [Pipelines and Redirection](#15-pipelines-and-redirection)

### Part 2: Advanced

16. [Associative Arrays](#16-associative-arrays)
17. [Advanced Parameter Expansion](#17-advanced-parameter-expansion)
18. [Regular Expressions](#18-regular-expressions)
19. [Here Documents and Here Strings](#19-here-documents-and-here-strings)
20. [Process Substitution](#20-process-substitution)
21. [File Descriptors and Advanced Redirection](#21-file-descriptors-and-advanced-redirection)
22. [Signal Handling with `trap`](#22-signal-handling-with-trap)
23. [Subshells and Command Grouping](#23-subshells-and-command-grouping)
24. [Debugging Techniques](#24-debugging-techniques)
25. [Named Pipes (FIFOs)](#25-named-pipes-fifos)
26. [File Locking and Concurrency](#26-file-locking-and-concurrency)
27. [Performance Optimization](#27-performance-optimization)
28. [Security Best Practices](#28-security-best-practices)

### Part 3: Practical Projects

29. [Project 1 — Log File Analyzer](#29-project-1--log-file-analyzer)
30. [Project 2 — System Health Monitor](#30-project-2--system-health-monitor)
31. [Project 3 — Automated Backup Utility](#31-project-3--automated-backup-utility)
32. [Project 4 — Batch File Renamer](#32-project-4--batch-file-renamer)
33. [Project 5 — Interactive Task Manager](#33-project-5--interactive-task-manager)

---

## Part 1: Basics

---

### 1. What Is Bash?

**Bash** (Bourne Again SHell) is the default command-line interpreter on most Linux distributions and macOS. It is both an interactive shell and a powerful scripting language that lets you automate system administration tasks, process text, orchestrate programs, and much more.

**Why learn Bash scripting?**

- Available on virtually every Unix/Linux system — no installation required.
- Perfect for gluing together existing command-line tools.
- Essential for DevOps, system administration, and CI/CD pipelines.
- Scripts are plain text — easy to version-control, review, and share.

Check your Bash version:

```bash
bash --version
```

---

### 2. Your First Script

Create a file called `hello.sh`:

```bash
#!/bin/bash
# A simple greeting script

echo "Hello, World!"
echo "Today is $(date +%A), $(date +%B) $(date +%d), $(date +%Y)."
```

**Key concepts:**

| Element | Purpose |
|---------|---------|
| `#!/bin/bash` | The **shebang** — tells the OS which interpreter to use. |
| `#` | Comment (ignored by the interpreter). |
| `echo` | Prints text to standard output. |
| `$(command)` | **Command substitution** — runs `command` and inserts its output. |

**Running the script:**

```bash
# Method 1: Make it executable
chmod +x hello.sh
./hello.sh

# Method 2: Pass it to bash explicitly
bash hello.sh
```

> **See:** [`examples/basics/01_hello.sh`](examples/basics/01_hello.sh)

---

### 3. Variables

Variables store data for later use. Bash variables are **untyped** — they are treated as strings by default.

```bash
#!/bin/bash

# Assignment (no spaces around '=')
name="Alice"
age=30
distro="Ubuntu"

# Reading a variable
echo "Name: $name"
echo "Age: $age"
echo "Distro: ${distro}"   # braces disambiguate

# Read-only variable
readonly PI=3.14159
echo "Pi is approximately $PI"
# PI=3.0   # This would produce an error

# Environment variables (exported to child processes)
export APP_ENV="production"

# Unsetting a variable
temp="delete me"
unset temp
echo "temp is now: '$temp'"   # empty
```

**Rules for variable names:**

- Start with a letter or underscore.
- Contain letters, digits, and underscores.
- Case-sensitive (`Name` and `name` are different).

**Special variables:**

| Variable | Meaning |
|----------|---------|
| `$0` | Script name |
| `$1`–`$9` | Positional parameters (arguments) |
| `$#` | Number of arguments |
| `$@` | All arguments (individually quoted) |
| `$*` | All arguments (as a single word) |
| `$?` | Exit status of the last command |
| `$$` | PID of the current script |
| `$!` | PID of the last background process |

> **See:** [`examples/basics/02_variables.sh`](examples/basics/02_variables.sh)

---

### 4. Quoting and Escaping

Understanding quoting is critical in Bash. Quotes control how the shell interprets special characters.

```bash
#!/bin/bash

name="World"

# Double quotes — variable expansion and command substitution happen
echo "Hello, $name"          # Hello, World
echo "Date: $(date +%Y)"    # Date: 2026

# Single quotes — everything is literal
echo 'Hello, $name'          # Hello, $name
echo 'Date: $(date +%Y)'    # Date: $(date +%Y)

# Backslash — escape a single character
echo "The cost is \$100"     # The cost is $100
echo "She said \"hi\""       # She said "hi"

# $'...' — ANSI-C quoting (interpret escape sequences)
echo $'Tab:\there'           # Tab:   here
echo $'Newline:\nhere'       # Newline:
                              # here

# Difference between $@ and $*
set -- "arg one" "arg two" "arg three"

echo '--- Using "$@" ---'
for arg in "$@"; do echo "  [$arg]"; done

echo '--- Using "$*" ---'
for arg in "$*"; do echo "  [$arg]"; done
```

**Output of `$@` vs `$*`:**

```
--- Using "$@" ---
  [arg one]
  [arg two]
  [arg three]
--- Using "$*" ---
  [arg one arg two arg three]
```

> **See:** [`examples/basics/03_quoting.sh`](examples/basics/03_quoting.sh)

---

### 5. User Input

```bash
#!/bin/bash

# Basic input
read -p "Enter your name: " username
echo "Hello, $username!"

# Silent input (for passwords)
read -sp "Enter password: " password
echo
echo "Password length: ${#password}"

# Input with a default value
read -p "Enter shell [/bin/bash]: " shell
shell="${shell:-/bin/bash}"
echo "Shell set to: $shell"

# Reading multiple values
read -p "Enter first and last name: " first last
echo "First: $first, Last: $last"

# Timeout (wait 5 seconds)
if read -t 5 -p "Quick! Enter something: " answer; then
    echo "You entered: $answer"
else
    echo
    echo "Too slow!"
fi

# Reading into an array
echo "Enter three colors (space-separated):"
read -a colors
echo "Color 1: ${colors[0]}"
echo "Color 2: ${colors[1]}"
echo "Color 3: ${colors[2]}"
```

> **See:** [`examples/basics/04_user_input.sh`](examples/basics/04_user_input.sh)

---

### 6. Arithmetic Operations

Bash supports integer arithmetic natively. For floating-point math, use external tools like `bc` or `awk`.

```bash
#!/bin/bash

a=15
b=4

# Method 1: $(( )) — arithmetic expansion (preferred)
echo "Addition:       $((a + b))"      # 19
echo "Subtraction:    $((a - b))"      # 11
echo "Multiplication: $((a * b))"      # 60
echo "Division:       $((a / b))"      # 3 (integer division)
echo "Modulus:        $((a % b))"      # 3
echo "Exponentiation: $((a ** 2))"     # 225

# Increment / Decrement
count=0
((count++))
echo "After increment: $count"          # 1
((count += 10))
echo "After += 10: $count"             # 11

# Method 2: let
let "result = a * b + 2"
echo "let result: $result"             # 62

# Method 3: expr (legacy — avoid in new scripts)
result=$(expr $a + $b)
echo "expr result: $result"            # 19

# Floating-point with bc
echo "Float division: $(echo "scale=4; $a / $b" | bc)"   # 3.7500

# Floating-point with awk
echo "Square root of $a: $(awk "BEGIN {printf \"%.4f\", sqrt($a)}")"

# Bitwise operations
echo "AND:  $((a & b))"   # 4
echo "OR:   $((a | b))"   # 15
echo "XOR:  $((a ^ b))"   # 11
echo "NOT:  $((~a))"      # -16
echo "Left shift:  $((a << 2))"   # 60
echo "Right shift: $((a >> 2))"   # 3

# Ternary operator
max=$(( a > b ? a : b ))
echo "Max of $a and $b: $max"     # 15
```

> **See:** [`examples/basics/05_arithmetic.sh`](examples/basics/05_arithmetic.sh)

---

### 7. Conditional Statements

#### `if` / `elif` / `else`

```bash
#!/bin/bash

read -p "Enter a number: " num

if [[ $num -gt 0 ]]; then
    echo "$num is positive"
elif [[ $num -lt 0 ]]; then
    echo "$num is negative"
else
    echo "$num is zero"
fi
```

#### Test operators

| Category | Operator | Meaning |
|----------|----------|---------|
| **Integer** | `-eq`, `-ne` | Equal, not equal |
| | `-lt`, `-le` | Less than, less or equal |
| | `-gt`, `-ge` | Greater than, greater or equal |
| **String** | `=`, `==` | Equal |
| | `!=` | Not equal |
| | `-z` | String is empty |
| | `-n` | String is non-empty |
| **File** | `-e` | File exists |
| | `-f` | Is a regular file |
| | `-d` | Is a directory |
| | `-r`, `-w`, `-x` | Readable, writable, executable |
| | `-s` | File is non-empty |
| **Logical** | `&&` | AND (inside `[[ ]]`) |
| | `\|\|` | OR (inside `[[ ]]`) |
| | `!` | NOT |

#### `[[ ]]` vs `[ ]`

```bash
file="/etc/passwd"

# [[ ]] — modern, preferred: supports && || and pattern matching
if [[ -f "$file" && -r "$file" ]]; then
    echo "$file exists and is readable"
fi

# [ ] — POSIX-compatible but more limited
if [ -f "$file" ] && [ -r "$file" ]; then
    echo "$file exists and is readable"
fi

# Pattern matching with [[ ]]
name="hello.tar.gz"
if [[ "$name" == *.tar.gz ]]; then
    echo "It's a gzipped tarball"
fi

# Regex matching with =~
email="user@example.com"
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "Valid email format"
fi
```

#### `case` statement

```bash
read -p "Enter a fruit: " fruit

case "$fruit" in
    apple|Apple)
        echo "An apple a day keeps the doctor away."
        ;;
    banana|Banana)
        echo "Bananas are rich in potassium."
        ;;
    orange|Orange)
        echo "Oranges are full of Vitamin C."
        ;;
    *)
        echo "Unknown fruit: $fruit"
        ;;
esac
```

> **See:** [`examples/basics/06_conditionals.sh`](examples/basics/06_conditionals.sh)

---

### 8. Loops

#### `for` loop

```bash
#!/bin/bash

# Iterate over a list
for color in red green blue yellow; do
    echo "Color: $color"
done

# C-style for loop
for ((i = 1; i <= 5; i++)); do
    echo "Iteration $i"
done

# Iterate over a range
for i in {1..10}; do
    echo -n "$i "
done
echo

# Iterate over a range with step
for i in {0..100..10}; do
    echo -n "$i "
done
echo

# Iterate over files
for file in /etc/*.conf; do
    echo "Config file: $(basename "$file")"
done

# Iterate over command output
for user in $(cut -d: -f1 /etc/passwd | head -5); do
    echo "User: $user"
done
```

#### `while` loop

```bash
# Counter-based
count=1
while [[ $count -le 5 ]]; do
    echo "Count: $count"
    ((count++))
done

# Read a file line by line
while IFS= read -r line; do
    echo "Line: $line"
done < /etc/hostname

# Infinite loop with break
while true; do
    read -p "Enter 'quit' to exit: " input
    if [[ "$input" == "quit" ]]; then
        break
    fi
    echo "You said: $input"
done
```

#### `until` loop

```bash
# Runs until the condition becomes TRUE
num=1
until [[ $num -gt 5 ]]; do
    echo "Number: $num"
    ((num++))
done
```

#### Loop control

```bash
# 'continue' skips the rest of the current iteration
for i in {1..10}; do
    if (( i % 2 == 0 )); then
        continue
    fi
    echo "Odd: $i"
done

# 'break' exits the loop entirely
for i in {1..100}; do
    if (( i > 5 )); then
        break
    fi
    echo "Value: $i"
done
```

> **See:** [`examples/basics/07_loops.sh`](examples/basics/07_loops.sh)

---

### 9. Functions

```bash
#!/bin/bash

# Basic function
greet() {
    echo "Hello, $1! Welcome to $2."
}
greet "Alice" "Bash scripting"

# Function with return value (exit code: 0-255)
is_even() {
    if (( $1 % 2 == 0 )); then
        return 0   # true
    else
        return 1   # false
    fi
}

if is_even 42; then
    echo "42 is even"
fi

# Return data via stdout (preferred for strings/numbers)
add() {
    echo $(( $1 + $2 ))
}
result=$(add 17 25)
echo "17 + 25 = $result"

# Local variables
outer_var="I'm global"
demo_scope() {
    local inner_var="I'm local"
    echo "Inside function: outer_var=$outer_var, inner_var=$inner_var"
}
demo_scope
echo "Outside function: outer_var=$outer_var, inner_var=$inner_var"

# Default parameter values
create_user() {
    local name="${1:?Error: name is required}"
    local role="${2:-viewer}"
    local active="${3:-true}"
    echo "Creating user: name=$name, role=$role, active=$active"
}
create_user "bob"
create_user "carol" "admin" "false"

# Recursive function: factorial
factorial() {
    if (( $1 <= 1 )); then
        echo 1
    else
        local prev
        prev=$(factorial $(( $1 - 1 )))
        echo $(( $1 * prev ))
    fi
}
echo "5! = $(factorial 5)"    # 120
echo "10! = $(factorial 10)"  # 3628800

# Passing arrays to functions
print_array() {
    local -n arr=$1   # nameref (Bash 4.3+)
    for item in "${arr[@]}"; do
        echo "  - $item"
    done
}
fruits=("apple" "banana" "cherry")
echo "Fruits:"
print_array fruits
```

> **See:** [`examples/basics/08_functions.sh`](examples/basics/08_functions.sh)

---

### 10. Arrays

```bash
#!/bin/bash

# Indexed array
fruits=("apple" "banana" "cherry" "date" "elderberry")

# Access elements
echo "First:  ${fruits[0]}"
echo "Third:  ${fruits[2]}"
echo "Last:   ${fruits[-1]}"

# All elements
echo "All:    ${fruits[@]}"

# Array length
echo "Count:  ${#fruits[@]}"

# Length of a specific element
echo "Length of 'banana': ${#fruits[1]}"

# Add elements
fruits+=("fig" "grape")

# Modify an element
fruits[1]="blueberry"

# Delete an element (leaves a gap)
unset 'fruits[3]'

# Slice (offset:length)
echo "Slice [1..3]: ${fruits[@]:1:3}"

# Iterate
for fruit in "${fruits[@]}"; do
    echo "  Fruit: $fruit"
done

# Iterate with index
for i in "${!fruits[@]}"; do
    echo "  [$i] = ${fruits[$i]}"
done

# Array from command output
files=($(ls /etc/*.conf 2>/dev/null | head -5))
echo "Config files found: ${#files[@]}"

# Array from string splitting
IFS=',' read -ra csv <<< "one,two,three,four"
echo "CSV items: ${csv[@]}"

# Check if array contains an element
contains() {
    local target="$1"
    shift
    for item in "$@"; do
        [[ "$item" == "$target" ]] && return 0
    done
    return 1
}
if contains "cherry" "${fruits[@]}"; then
    echo "Found cherry!"
fi
```

> **See:** [`examples/basics/09_arrays.sh`](examples/basics/09_arrays.sh)

---

### 11. String Manipulation

```bash
#!/bin/bash

str="Hello, Beautiful World!"

# Length
echo "Length: ${#str}"                    # 23

# Substring (offset:length)
echo "Substring: ${str:7:9}"             # Beautiful

# From offset to end
echo "From 7: ${str:7}"                  # Beautiful World!

# From the end
echo "Last 6: ${str: -6}"                # orld!  (note the space before -)

# Search and replace
echo "Replace first: ${str/o/0}"         # Hell0, Beautiful World!
echo "Replace all:   ${str//o/0}"        # Hell0, Beautiful W0rld!

# Delete pattern
echo "Delete 'Beautiful ': ${str/Beautiful /}"  # Hello, World!

# Prefix removal
filepath="/home/user/documents/report.tar.gz"
echo "Remove shortest prefix: ${filepath#*/}"   # home/user/documents/report.tar.gz
echo "Remove longest prefix:  ${filepath##*/}"  # report.tar.gz (basename)

# Suffix removal
echo "Remove shortest suffix: ${filepath%.*}"   # /home/user/documents/report.tar
echo "Remove longest suffix:  ${filepath%%.*}"  # /home/user/documents/report

# Case conversion (Bash 4+)
echo "Uppercase first: ${str^}"           # Hello, Beautiful World!
echo "Uppercase all:   ${str^^}"          # HELLO, BEAUTIFUL WORLD!
lower="HELLO"
echo "Lowercase first: ${lower,}"         # hELLO
echo "Lowercase all:   ${lower,,}"        # hello

# String concatenation
first="Hello"
second="World"
combined="${first}, ${second}!"
echo "$combined"

# Check if string contains substring
if [[ "$str" == *"Beautiful"* ]]; then
    echo "Contains 'Beautiful'"
fi

# Check prefix and suffix
if [[ "$str" == Hello* ]]; then
    echo "Starts with 'Hello'"
fi
if [[ "$str" == *'!' ]]; then
    echo "Ends with '!'"
fi
```

> **See:** [`examples/basics/10_strings.sh`](examples/basics/10_strings.sh)

---

### 12. File Operations

```bash
#!/bin/bash

testdir="/tmp/bash_tutorial_test"
mkdir -p "$testdir"

# Create files
echo "Hello World" > "$testdir/file1.txt"
echo "Bash Tutorial" > "$testdir/file2.txt"
date > "$testdir/timestamp.txt"

# Check file existence and type
for f in "$testdir/file1.txt" "$testdir/nonexistent" "/tmp"; do
    if [[ -e "$f" ]]; then
        if [[ -f "$f" ]]; then
            echo "'$f' is a regular file (size: $(wc -c < "$f") bytes)"
        elif [[ -d "$f" ]]; then
            echo "'$f' is a directory"
        fi
    else
        echo "'$f' does not exist"
    fi
done

# Read file line by line
echo "--- Contents of file1.txt ---"
while IFS= read -r line; do
    echo "  > $line"
done < "$testdir/file1.txt"

# Read file into a variable
content=$(<"$testdir/file2.txt")
echo "file2 content: $content"

# Append to a file
echo "Appended line" >> "$testdir/file1.txt"

# Copy, move, remove
cp "$testdir/file1.txt" "$testdir/file1_backup.txt"
mv "$testdir/timestamp.txt" "$testdir/time.txt"
rm "$testdir/file2.txt"

# List directory contents
echo "--- Files in $testdir ---"
for f in "$testdir"/*; do
    echo "  $(basename "$f")"
done

# Find files by pattern
echo "--- .txt files ---"
for f in "$testdir"/*.txt; do
    [[ -f "$f" ]] && echo "  $f"
done

# Get file information
file="$testdir/file1.txt"
echo "File: $file"
echo "  Size: $(stat --format='%s' "$file" 2>/dev/null || stat -f'%z' "$file" 2>/dev/null) bytes"
echo "  Permissions: $(stat --format='%a' "$file" 2>/dev/null || stat -f'%Lp' "$file" 2>/dev/null)"

# Temporary files (safe creation)
tmpfile=$(mktemp)
echo "Temp file created: $tmpfile"
echo "temporary data" > "$tmpfile"
rm "$tmpfile"

# Cleanup
rm -rf "$testdir"
echo "Cleaned up test directory"
```

> **See:** [`examples/basics/11_file_operations.sh`](examples/basics/11_file_operations.sh)

---

### 13. Command-Line Arguments

```bash
#!/bin/bash

# Script name
echo "Script: $0"

# Argument count
echo "Number of arguments: $#"

# Individual arguments
echo "Arg 1: $1"
echo "Arg 2: $2"
echo "Arg 3: $3"

# All arguments
echo "All args (\$@): $@"

# Shift — discards $1 and shifts everything down
echo "--- Before shift ---"
echo "  \$1=$1  \$2=$2  \$3=$3"
shift
echo "--- After shift ---"
echo "  \$1=$1  \$2=$2  \$3=$3"

# Parsing options with getopts
usage() {
    echo "Usage: $0 [-v] [-o output_file] [-n count] input_file"
    exit 1
}

verbose=false
output=""
count=1

# Reset OPTIND for this example
OPTIND=1

while getopts "vo:n:h" opt; do
    case "$opt" in
        v) verbose=true ;;
        o) output="$OPTARG" ;;
        n) count="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

echo "--- Parsed options ---"
echo "  verbose=$verbose"
echo "  output=$output"
echo "  count=$count"
echo "  remaining args: $@"
```

**Example invocations:**

```bash
./13_arguments.sh -v -o result.txt -n 5 input.txt
./13_arguments.sh -h
```

> **See:** [`examples/basics/12_arguments.sh`](examples/basics/12_arguments.sh)

---

### 14. Exit Codes and Error Handling

Every command returns an **exit code**: `0` means success, non-zero means failure.

```bash
#!/bin/bash

# Check exit codes
ls /etc/passwd > /dev/null 2>&1
echo "ls /etc/passwd exit code: $?"   # 0

ls /nonexistent 2>/dev/null
echo "ls /nonexistent exit code: $?"  # non-zero

# Logical operators based on exit codes
mkdir -p /tmp/test_dir && echo "Directory created (or already exists)"
ls /nonexistent 2>/dev/null || echo "Command failed, running fallback"

# set -e: exit immediately on error
demonstrate_set_e() {
    set -e
    echo "This runs"
    true
    echo "This also runs"
    # false   # Uncommenting this would cause the function to exit
    echo "This runs too"
    set +e
}
demonstrate_set_e

# Custom exit codes
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This operation requires root privileges" >&2
        return 1
    fi
    return 0
}

# Trap errors
error_handler() {
    echo "Error occurred on line $1 (exit code: $2)" >&2
}
trap 'error_handler $LINENO $?' ERR

# Best practice: die function
die() {
    echo "FATAL: $*" >&2
    exit 1
}

# Validate prerequisites
command -v bash > /dev/null 2>&1 || die "bash is required"
echo "All prerequisites satisfied"

# Pipeline exit status (PIPESTATUS array)
set -o pipefail
echo "hello" | grep "hello" | wc -l > /dev/null
echo "Pipeline exit codes: ${PIPESTATUS[@]}"
```

> **See:** [`examples/basics/13_exit_codes.sh`](examples/basics/13_exit_codes.sh)

---

### 15. Pipelines and Redirection

```bash
#!/bin/bash

# Standard streams:
#   stdin  (0) — input
#   stdout (1) — normal output
#   stderr (2) — error output

# Redirect stdout to a file
echo "Hello" > /tmp/output.txt         # overwrite
echo "World" >> /tmp/output.txt        # append

# Redirect stderr
ls /nonexistent 2> /tmp/errors.txt
ls /nonexistent 2>> /tmp/errors.txt    # append

# Redirect both stdout and stderr
ls /etc/passwd /nonexistent > /tmp/all.txt 2>&1   # traditional
ls /etc/passwd /nonexistent &> /tmp/all.txt        # shorthand (Bash)

# Discard output
ls /nonexistent 2>/dev/null            # discard stderr
command_that_might_fail > /dev/null 2>&1  # discard everything

# Pipes — connect stdout of one command to stdin of another
cat /etc/passwd | cut -d: -f1 | sort | head -5

# Pipe to while loop
cat /etc/passwd | head -3 | while IFS=: read -r user _ uid _; do
    echo "User: $user (UID: $uid)"
done

# tee — write to file AND stdout
echo "Logged message" | tee /tmp/log.txt

# Process multiple files
cat /tmp/output.txt /tmp/errors.txt 2>/dev/null | sort -u

# Here string as input
grep "hello" <<< "hello world"

# Redirect input from a file
wc -l < /etc/passwd

# Cleanup
rm -f /tmp/output.txt /tmp/errors.txt /tmp/all.txt /tmp/log.txt
```

> **See:** [`examples/basics/14_pipelines.sh`](examples/basics/14_pipelines.sh)

---

## Part 2: Advanced

---

### 16. Associative Arrays

Associative arrays (hash maps) use arbitrary strings as keys instead of integers. Available in **Bash 4.0+**.

```bash
#!/bin/bash

# Declare an associative array
declare -A user_info
user_info[name]="Alice"
user_info[email]="alice@example.com"
user_info[role]="admin"
user_info[active]="true"

# Access values
echo "Name: ${user_info[name]}"
echo "Email: ${user_info[email]}"

# All keys
echo "Keys: ${!user_info[@]}"

# All values
echo "Values: ${user_info[@]}"

# Number of entries
echo "Count: ${#user_info[@]}"

# Iterate
for key in "${!user_info[@]}"; do
    echo "  $key => ${user_info[$key]}"
done

# Check if a key exists
if [[ -v user_info[email] ]]; then
    echo "Email key exists"
fi

# Delete a key
unset 'user_info[active]'

# Practical example: word frequency counter
declare -A word_count
text="the cat sat on the mat the cat"
for word in $text; do
    ((word_count[$word]++))
done
echo "--- Word frequencies ---"
for word in "${!word_count[@]}"; do
    printf "  %-10s %d\n" "$word" "${word_count[$word]}"
done

# Inline initialization (Bash 4.0+)
declare -A http_codes=(
    [200]="OK"
    [301]="Moved Permanently"
    [404]="Not Found"
    [500]="Internal Server Error"
)
echo "HTTP 404: ${http_codes[404]}"
```

> **See:** [`examples/advanced/01_assoc_arrays.sh`](examples/advanced/01_assoc_arrays.sh)

---

### 17. Advanced Parameter Expansion

Parameter expansion goes far beyond `$var`. Here is a comprehensive reference:

```bash
#!/bin/bash

# --- Default Values ---
unset name
echo "${name:-default}"      # Use default if unset/empty (doesn't assign)
echo "${name:=default}"      # Assign default if unset/empty
echo "${name:+replacement}"  # Use replacement if set and non-empty
# ${name:?error message}     # Exit with error if unset/empty

# --- Indirect Expansion ---
var_name="greeting"
greeting="Hello, World!"
echo "${!var_name}"           # Hello, World!

# --- Substring Expansion ---
str="abcdefghij"
echo "${str:3}"               # defghij
echo "${str:3:4}"             # defg
echo "${str: -3}"             # hij       (note space before -)
echo "${str: -3:2}"           # hi

# --- Pattern-Based Removal ---
path="/usr/local/bin/script.sh"
echo "${path#*/}"             # usr/local/bin/script.sh  (shortest from start)
echo "${path##*/}"            # script.sh                (longest from start)
echo "${path%/*}"             # /usr/local/bin            (shortest from end)
echo "${path%%/*}"            #                           (longest from end)

# --- Pattern Substitution ---
str="foo-bar-baz-foo"
echo "${str/foo/FOO}"         # FOO-bar-baz-foo   (first match)
echo "${str//foo/FOO}"        # FOO-bar-baz-FOO   (all matches)
echo "${str/#foo/FOO}"        # FOO-bar-baz-foo   (match at start)
echo "${str/%foo/FOO}"        # foo-bar-baz-FOO   (match at end)

# --- Case Modification (Bash 4.0+) ---
str="hello world"
echo "${str^}"                # Hello world   (first char upper)
echo "${str^^}"               # HELLO WORLD   (all upper)
str="HELLO WORLD"
echo "${str,}"                # hELLO WORLD   (first char lower)
echo "${str,,}"               # hello world   (all lower)

# --- Length ---
str="Hello"
echo "${#str}"                # 5

# --- Array Transformations ---
arr=(apple banana cherry)
echo "${arr[@]^}"             # Apple Banana Cherry
echo "${arr[@]^^}"            # APPLE BANANA CHERRY
echo "${arr[@]/a/A}"          # Apple bAnana cherry

# --- Practical: parse a config line ---
config_line="database_host = 192.168.1.100"
key="${config_line%% =*}"
value="${config_line##*= }"
echo "Key: '$key', Value: '$value'"
```

> **See:** [`examples/advanced/02_parameter_expansion.sh`](examples/advanced/02_parameter_expansion.sh)

---

### 18. Regular Expressions

Bash has built-in regex support via the `=~` operator inside `[[ ]]`.

```bash
#!/bin/bash

# Basic regex match
string="Error: file not found on line 42"
if [[ "$string" =~ [0-9]+ ]]; then
    echo "Found number: ${BASH_REMATCH[0]}"    # 42
fi

# Capture groups
timestamp="2026-03-20 14:30:45"
if [[ "$timestamp" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})\ ([0-9]{2}):([0-9]{2}):([0-9]{2})$ ]]; then
    echo "Full match: ${BASH_REMATCH[0]}"
    echo "Year:   ${BASH_REMATCH[1]}"
    echo "Month:  ${BASH_REMATCH[2]}"
    echo "Day:    ${BASH_REMATCH[3]}"
    echo "Hour:   ${BASH_REMATCH[4]}"
    echo "Minute: ${BASH_REMATCH[5]}"
    echo "Second: ${BASH_REMATCH[6]}"
fi

# Validate input
validate_ip() {
    local ip="$1"
    local octet="([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"
    local regex="^${octet}\.${octet}\.${octet}\.${octet}$"
    if [[ "$ip" =~ $regex ]]; then
        echo "'$ip' is a valid IPv4 address"
        return 0
    else
        echo "'$ip' is NOT a valid IPv4 address"
        return 1
    fi
}
validate_ip "192.168.1.1"
validate_ip "256.1.1.1"
validate_ip "10.0.0.255"

# Extract all email addresses from text
text="Contact alice@example.com or bob.smith@company.co.uk for details."
regex='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
while [[ "$text" =~ $regex ]]; do
    echo "Found email: ${BASH_REMATCH[0]}"
    text="${text/${BASH_REMATCH[0]}/}"
done

# Regex with grep -P (Perl-compatible)
echo "Hello World 123" | grep -oP '\d+'
```

> **See:** [`examples/advanced/03_regex.sh`](examples/advanced/03_regex.sh)

---

### 19. Here Documents and Here Strings

#### Here Documents

A **here document** feeds a block of text as stdin to a command.

```bash
#!/bin/bash

# Basic here document
cat << EOF
This is a here document.
Variables are expanded: HOME=$HOME
Commands work too: $(date +%Y)
Special characters need no escaping: $, ", '
EOF

# Quoted delimiter — no expansion
cat << 'EOF'
This is literal text.
$HOME is not expanded here.
$(date) is not executed.
EOF

# Indented here document with <<-
# (strips leading TABS — not spaces)
if true; then
	cat <<-EOF
	This text is indented with tabs.
	The leading tabs are stripped from the output.
	EOF
fi

# Write to a file
cat << EOF > /tmp/config.ini
[database]
host=localhost
port=5432
name=myapp
EOF

echo "Config written:"
cat /tmp/config.ini
rm /tmp/config.ini

# Here document in a function
generate_html() {
    local title="$1"
    local body="$2"
    cat << EOF
<!DOCTYPE html>
<html>
<head><title>$title</title></head>
<body>
<h1>$title</h1>
<p>$body</p>
</body>
</html>
EOF
}
generate_html "My Page" "Hello from Bash!"
```

#### Here Strings

A **here string** feeds a single string as stdin.

```bash
# Here string
grep "hello" <<< "hello world"

# Variable as input
data="line1
line2
line3"
wc -l <<< "$data"   # 3

# Useful for avoiding a pipe (preserves variable scope)
count=0
while IFS= read -r line; do
    ((count++))
done <<< "$data"
echo "Lines: $count"   # 3
```

> **See:** [`examples/advanced/04_heredoc.sh`](examples/advanced/04_heredoc.sh)

---

### 20. Process Substitution

Process substitution treats a command's output (or input) as a file, using `<(command)` or `>(command)`.

```bash
#!/bin/bash

# Compare output of two commands side by side
diff <(ls /usr/bin | head -10) <(ls /usr/sbin | head -10)

# Read from process substitution
while IFS= read -r line; do
    echo "Process: $line"
done < <(ps aux | head -5)

# Feed to multiple commands simultaneously
echo "Hello World" | tee >(wc -w > /tmp/wc_out.txt) >(tr '[:lower:]' '[:upper:]' > /tmp/upper_out.txt) > /dev/null
sleep 0.1
echo "Word count: $(cat /tmp/wc_out.txt)"
echo "Uppercase:  $(cat /tmp/upper_out.txt)"
rm -f /tmp/wc_out.txt /tmp/upper_out.txt

# Compare sorted and unsorted versions of a file
echo -e "cherry\napple\nbanana" > /tmp/fruits.txt
diff /tmp/fruits.txt <(sort /tmp/fruits.txt)
rm /tmp/fruits.txt

# Merge two sorted streams
paste <(seq 1 5) <(seq 6 10)
```

**Key difference from pipes:** Process substitution does not create a subshell for the reading command, so variable changes persist in the current shell.

```bash
# Pipe creates subshell — count is lost
count=0
echo -e "a\nb\nc" | while read -r line; do ((count++)); done
echo "With pipe: count=$count"   # 0 (subshell!)

# Process substitution — count is preserved
count=0
while read -r line; do ((count++)); done < <(echo -e "a\nb\nc")
echo "With proc sub: count=$count"   # 3
```

> **See:** [`examples/advanced/05_process_substitution.sh`](examples/advanced/05_process_substitution.sh)

---

### 21. File Descriptors and Advanced Redirection

Beyond stdin/stdout/stderr, you can open custom file descriptors (3–9).

```bash
#!/bin/bash

# Open fd 3 for writing
exec 3> /tmp/fd_output.txt
echo "Written to fd 3" >&3
echo "Also to fd 3" >&3
exec 3>&-   # close fd 3
cat /tmp/fd_output.txt

# Open fd 4 for reading
echo -e "line1\nline2\nline3" > /tmp/fd_input.txt
exec 4< /tmp/fd_input.txt
read -r first_line <&4
read -r second_line <&4
exec 4<&-   # close fd 4
echo "First: $first_line, Second: $second_line"

# Read and write on the same fd
exec 5<> /tmp/fd_rw.txt
echo "Hello from fd 5" >&5
exec 5<&-

# Swap stdout and stderr
{
    echo "This goes to stdout"
    echo "This goes to stderr" >&2
} 3>&1 1>&2 2>&3 3>&-

# Log to file while still showing on screen
log_file="/tmp/script.log"
exec > >(tee -a "$log_file") 2>&1
echo "This appears on screen AND in $log_file"

# Cleanup
rm -f /tmp/fd_output.txt /tmp/fd_input.txt /tmp/fd_rw.txt /tmp/script.log
```

> **See:** [`examples/advanced/06_file_descriptors.sh`](examples/advanced/06_file_descriptors.sh)

---

### 22. Signal Handling with `trap`

`trap` lets you run commands when the script receives a signal or exits.

```bash
#!/bin/bash

# Cleanup on exit
tmpdir=$(mktemp -d)
cleanup() {
    echo "Cleaning up temp directory: $tmpdir"
    rm -rf "$tmpdir"
}
trap cleanup EXIT

# Handle Ctrl+C (SIGINT)
trap 'echo "Caught SIGINT — use Ctrl+\\ to force quit"; exit 1' INT

# Handle SIGTERM
trap 'echo "Caught SIGTERM — shutting down gracefully"; exit 0' TERM

# Ignore SIGHUP
trap '' HUP

# List all traps currently set
trap -p

# Practical: ensure cleanup of lock files
LOCKFILE="/tmp/myscript.lock"
acquire_lock() {
    if [[ -f "$LOCKFILE" ]]; then
        echo "Script is already running (lock file exists)" >&2
        exit 1
    fi
    echo $$ > "$LOCKFILE"
    trap 'rm -f "$LOCKFILE"; exit' EXIT INT TERM
}

release_lock() {
    rm -f "$LOCKFILE"
}

# Trap on ERR — runs when any command fails (with set -e or ERR trap)
trap 'echo "Error on line $LINENO: command exited with status $?"' ERR

# Trap on DEBUG — runs before every command (useful for tracing)
# trap 'echo "DEBUG: executing $BASH_COMMAND"' DEBUG

echo "Script is running in $tmpdir"
echo "Press Ctrl+C to test signal handling"
sleep 2
echo "Done!"
```

> **See:** [`examples/advanced/07_signals.sh`](examples/advanced/07_signals.sh)

---

### 23. Subshells and Command Grouping

```bash
#!/bin/bash

# Subshell — runs in a child process; variable changes don't affect the parent
x=10
(
    x=20
    echo "Inside subshell: x=$x"      # 20
    cd /tmp
    echo "Subshell pwd: $(pwd)"        # /tmp
)
echo "Outside subshell: x=$x"          # 10
echo "Parent pwd: $(pwd)"              # unchanged

# Command grouping with { } — runs in the CURRENT shell
x=10
{
    x=20
    echo "Inside group: x=$x"          # 20
}
echo "Outside group: x=$x"             # 20 (changed!)

# Redirect a group
{
    echo "Line 1"
    echo "Line 2"
    echo "Line 3"
} > /tmp/grouped_output.txt
cat /tmp/grouped_output.txt
rm /tmp/grouped_output.txt

# Subshell for isolation
original_path="$PATH"
(
    export PATH="/custom/bin:$PATH"
    echo "Modified PATH in subshell"
)
echo "PATH unchanged: $( [[ "$PATH" == "$original_path" ]] && echo yes || echo no )"

# Parallel execution with subshells
start=$SECONDS
(
    sleep 1
    echo "Task A done"
) &
(
    sleep 1
    echo "Task B done"
) &
(
    sleep 1
    echo "Task C done"
) &
wait   # wait for all background jobs
elapsed=$((SECONDS - start))
echo "All tasks completed in ${elapsed}s (parallel)"

# Coprocess — a background process with connected pipes (Bash 4.0+)
coproc COUNTER {
    local n=0
    while read -r cmd; do
        case "$cmd" in
            inc) ((n++)); echo "$n" ;;
            get) echo "$n" ;;
            quit) break ;;
        esac
    done
}

echo "inc" >&"${COUNTER[1]}"
read -r result <&"${COUNTER[0]}"
echo "Counter after inc: $result"

echo "inc" >&"${COUNTER[1]}"
echo "inc" >&"${COUNTER[1]}"
echo "get" >&"${COUNTER[1]}"
read -r result <&"${COUNTER[0]}"
read -r result <&"${COUNTER[0]}"
read -r result <&"${COUNTER[0]}"
echo "Counter after 2 more incs: $result"

echo "quit" >&"${COUNTER[1]}"
wait "$COUNTER_PID" 2>/dev/null
```

> **See:** [`examples/advanced/08_subshells.sh`](examples/advanced/08_subshells.sh)

---

### 24. Debugging Techniques

```bash
#!/bin/bash

# --- Method 1: set flags ---

# Print each command before executing it
set -x
echo "This command is traced"
ls /tmp > /dev/null
set +x

# Exit on any error
set -e
echo "Errors will stop the script"
set +e

# Treat unset variables as errors
set -u
# echo "$undefined_var"   # would cause an error
set +u

# Fail on pipe errors
set -o pipefail
# false | true   # with pipefail, this reports failure
set +o pipefail

# Combine: strict mode (recommended for production scripts)
# set -euo pipefail

# --- Method 2: DEBUG trap ---
debug_mode=false
if $debug_mode; then
    trap 'echo "[DEBUG] Line $LINENO: $BASH_COMMAND"' DEBUG
fi

# --- Method 3: Custom logging ---
LOG_LEVEL="${LOG_LEVEL:-INFO}"

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    declare -A levels=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
    local current_level="${levels[$LOG_LEVEL]:-1}"
    local msg_level="${levels[$level]:-1}"

    if (( msg_level >= current_level )); then
        printf "[%s] [%-5s] %s\n" "$timestamp" "$level" "$*" >&2
    fi
}

log INFO "Script started"
log DEBUG "This only shows if LOG_LEVEL=DEBUG"
log WARN "Something might be wrong"
log ERROR "Something IS wrong"

# --- Method 4: Trace a specific function ---
calculate() {
    local -
    set -x
    local a=$1 b=$2
    local sum=$((a + b))
    local product=$((a * b))
    echo "sum=$sum product=$product"
}
result=$(calculate 3 7)
echo "Result: $result"

# --- Method 5: bashdb (if installed) ---
# bash --debugger script.sh

# --- Method 6: PS4 customization for better trace output ---
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
echo "Enhanced trace output"
set +x
```

> **See:** [`examples/advanced/09_debugging.sh`](examples/advanced/09_debugging.sh)

---

### 25. Named Pipes (FIFOs)

Named pipes allow unrelated processes to communicate.

```bash
#!/bin/bash

FIFO="/tmp/my_fifo_$$"

# Create a named pipe
mkfifo "$FIFO"

# Writer in background
(
    echo "Message 1" > "$FIFO"
    echo "Message 2" > "$FIFO"
    echo "DONE" > "$FIFO"
) &

# Reader
while true; do
    if read -r line < "$FIFO"; then
        echo "Received: $line"
        [[ "$line" == "DONE" ]] && break
    fi
done

wait
rm -f "$FIFO"
echo "Named pipe cleaned up"

# Practical: producer-consumer pattern
FIFO2="/tmp/producer_consumer_$$"
mkfifo "$FIFO2"

# Producer
(
    for i in {1..5}; do
        echo "item_$i"
        sleep 0.2
    done
) > "$FIFO2" &

# Consumer
while IFS= read -r item; do
    echo "Processing: $item"
done < "$FIFO2"

wait
rm -f "$FIFO2"
```

> **See:** [`examples/advanced/10_named_pipes.sh`](examples/advanced/10_named_pipes.sh)

---

### 26. File Locking and Concurrency

```bash
#!/bin/bash

LOCKFILE="/tmp/myapp.lock"

# Method 1: mkdir-based locking (atomic and portable)
acquire_lock_mkdir() {
    if mkdir "$LOCKFILE.d" 2>/dev/null; then
        echo $$ > "$LOCKFILE.d/pid"
        trap 'rm -rf "$LOCKFILE.d"' EXIT
        return 0
    else
        local owner
        owner=$(cat "$LOCKFILE.d/pid" 2>/dev/null)
        echo "Lock held by PID $owner" >&2
        return 1
    fi
}

# Method 2: flock-based locking (Linux, most robust)
run_with_flock() {
    (
        flock -n 200 || { echo "Cannot acquire lock" >&2; exit 1; }
        echo "Locked! PID=$$ running critical section..."
        sleep 2
        echo "Done with critical section."
    ) 200>"$LOCKFILE"
}

# Method 3: Parallel task execution with controlled concurrency
MAX_PARALLEL=3
run_parallel() {
    local pids=()
    local tasks=("task1" "task2" "task3" "task4" "task5" "task6")

    for task in "${tasks[@]}"; do
        while (( ${#pids[@]} >= MAX_PARALLEL )); do
            local new_pids=()
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    new_pids+=("$pid")
                fi
            done
            pids=("${new_pids[@]}")
            sleep 0.1
        done

        (
            echo "Starting $task (PID=$$)"
            sleep $((RANDOM % 3 + 1))
            echo "Finished $task"
        ) &
        pids+=($!)
    done

    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    echo "All tasks completed"
}

run_parallel

# Cleanup
rm -f "$LOCKFILE"
rm -rf "$LOCKFILE.d"
```

> **See:** [`examples/advanced/11_locking.sh`](examples/advanced/11_locking.sh)

---

### 27. Performance Optimization

```bash
#!/bin/bash

# --- Tip 1: Avoid unnecessary external commands ---

# Slow: forking 'cut' for each line
# for line in $(cat file); do echo "$line" | cut -d: -f1; done

# Fast: use parameter expansion
while IFS=: read -r field rest; do
    echo "$field"
done < /etc/passwd > /dev/null

# --- Tip 2: Use built-in string operations ---
path="/home/user/documents/file.txt"

# Slow
basename_slow=$(basename "$path")
dirname_slow=$(dirname "$path")

# Fast
basename_fast="${path##*/}"
dirname_fast="${path%/*}"

# --- Tip 3: Use printf instead of echo for portability and speed ---
printf "Name: %s, Age: %d\n" "Alice" 30

# --- Tip 4: Read entire file at once ---
# Slow: line by line if you need the whole thing
# Fast:
content=$(<"/etc/hostname")

# --- Tip 5: Batch operations ---
# Slow: multiple greps
# grep "pattern1" file; grep "pattern2" file; grep "pattern3" file

# Fast: single grep with alternation
# grep -E "pattern1|pattern2|pattern3" file

# --- Tip 6: Use arrays instead of repeated string parsing ---
items=()
for i in {1..1000}; do
    items+=("item_$i")
done
echo "Array has ${#items[@]} items"

# --- Tip 7: Benchmark with time ---
echo "--- Benchmarking external basename ---"
time (for i in {1..1000}; do basename "/path/to/file.txt" > /dev/null; done)

echo "--- Benchmarking parameter expansion ---"
time (for i in {1..1000}; do x="${path##*/}"; done)

# --- Tip 8: Use mapfile/readarray for bulk file reading ---
mapfile -t lines < /etc/passwd
echo "Read ${#lines[@]} lines with mapfile"

# --- Tip 9: Avoid subshells in loops ---
# Slow (subshell per iteration):
# cat file | while read line; do ...; done

# Fast (no subshell):
# while read line; do ...; done < file
```

> **See:** [`examples/advanced/12_performance.sh`](examples/advanced/12_performance.sh)

---

### 28. Security Best Practices

```bash
#!/bin/bash

# --- 1. Always quote your variables ---
# Prevents word splitting and glob expansion
file="my file with spaces.txt"
# rm $file       # DANGEROUS: removes 'my', 'file', 'with', 'spaces.txt'
# rm "$file"     # CORRECT: removes 'my file with spaces.txt'

# --- 2. Use [[ ]] instead of [ ] ---
# [[ ]] is safer: no word splitting, no glob expansion
name=""
if [[ -z "$name" ]]; then
    echo "Name is empty (safe check)"
fi

# --- 3. Validate and sanitize input ---
sanitize_input() {
    local input="$1"
    # Remove potentially dangerous characters
    input="${input//[^a-zA-Z0-9._-]/}"
    echo "$input"
}

user_input="hello; rm -rf /"
clean=$(sanitize_input "$user_input")
echo "Sanitized: $clean"   # helloRM-RF

# --- 4. Use set -euo pipefail (strict mode) ---
# set -euo pipefail
# IFS=$'\n\t'

# --- 5. Never use eval with untrusted input ---
# eval "$user_input"   # EXTREMELY DANGEROUS

# --- 6. Use mktemp for temporary files ---
tmpfile=$(mktemp)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpfile" "$tmpdir"' EXIT

# --- 7. Restrict PATH ---
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# --- 8. Check commands exist before using them ---
require_cmd() {
    command -v "$1" > /dev/null 2>&1 || {
        echo "Required command '$1' not found" >&2
        exit 1
    }
}
require_cmd bash
require_cmd ls

# --- 9. Use -- to end option parsing ---
# Prevents filenames starting with - from being treated as options
# grep -- "-pattern" file
# rm -- "-dangerous-filename"

# --- 10. Secure file permissions ---
umask 077   # new files: owner-only access
echo "secret" > "$tmpfile"
ls -la "$tmpfile"

echo "Security checks passed."
```

> **See:** [`examples/advanced/13_security.sh`](examples/advanced/13_security.sh)

---

## Part 3: Practical Projects

---

### 29. Project 1 — Log File Analyzer

A script that parses web server log files and produces a summary report.

**Features:**
- Counts total requests, unique IPs, and HTTP status codes.
- Identifies the top-N most visited URLs and most active clients.
- Supports custom time-range filtering.

> **See:** [`examples/practical/01_log_analyzer.sh`](examples/practical/01_log_analyzer.sh)

```bash
#!/bin/bash
# Usage: ./01_log_analyzer.sh [-n top_count] [-s start_date] [-e end_date] logfile

set -euo pipefail

TOP_N=10
START_DATE=""
END_DATE=""

usage() {
    cat << EOF
Log File Analyzer — Analyze Apache/Nginx access logs

Usage: $(basename "$0") [OPTIONS] LOGFILE

Options:
    -n NUM    Show top NUM results (default: 10)
    -s DATE   Start date filter (format: DD/Mon/YYYY)
    -e DATE   End date filter (format: DD/Mon/YYYY)
    -h        Show this help

Example:
    $(basename "$0") -n 20 /var/log/nginx/access.log
EOF
    exit 0
}

while getopts "n:s:e:h" opt; do
    case "$opt" in
        n) TOP_N="$OPTARG" ;;
        s) START_DATE="$OPTARG" ;;
        e) END_DATE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

LOGFILE="${1:?Error: log file path required. Use -h for help.}"
[[ -f "$LOGFILE" ]] || { echo "Error: '$LOGFILE' not found" >&2; exit 1; }

total_lines=$(wc -l < "$LOGFILE")
unique_ips=$(awk '{print $1}' "$LOGFILE" | sort -u | wc -l)

echo "============================================"
echo "   LOG FILE ANALYSIS REPORT"
echo "============================================"
echo "File:        $LOGFILE"
echo "Total Lines: $total_lines"
echo "Unique IPs:  $unique_ips"
echo

echo "--- Top $TOP_N IP Addresses ---"
awk '{print $1}' "$LOGFILE" | sort | uniq -c | sort -rn | head -"$TOP_N" | \
    awk '{printf "  %-20s %s requests\n", $2, $1}'
echo

echo "--- HTTP Status Code Distribution ---"
awk '{print $9}' "$LOGFILE" | grep -E '^[0-9]+$' | sort | uniq -c | sort -rn | \
    awk '{printf "  HTTP %-4s %s occurrences\n", $2, $1}'
echo

echo "--- Top $TOP_N Requested URLs ---"
awk '{print $7}' "$LOGFILE" | sort | uniq -c | sort -rn | head -"$TOP_N" | \
    awk '{printf "  %-50s %s hits\n", $2, $1}'
echo

echo "--- Requests by Hour ---"
awk -F'[\\[:]' '{print $3}' "$LOGFILE" | sort | uniq -c | \
    awk '{printf "  Hour %s: %s requests\n", $2, $1}'
echo

echo "--- Top $TOP_N User Agents ---"
awk -F'"' '{print $6}' "$LOGFILE" | sort | uniq -c | sort -rn | head -"$TOP_N" | \
    awk '{agent=$0; sub(/^ *[0-9]+ /, "", agent); printf "  %s\n", agent}'
echo

echo "============================================"
echo "   Report generated at $(date)"
echo "============================================"
```

---

### 30. Project 2 — System Health Monitor

A script that monitors CPU, memory, disk usage, and network status, with alerting thresholds.

> **See:** [`examples/practical/02_system_monitor.sh`](examples/practical/02_system_monitor.sh)

```bash
#!/bin/bash
# Usage: ./02_system_monitor.sh [-i interval] [-c cpu_threshold] [-m mem_threshold] [-d disk_threshold]

set -euo pipefail

INTERVAL=5
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=90
REPORT_FILE="/tmp/system_health_$(date +%Y%m%d).log"
ITERATIONS=0
MAX_ITERATIONS="${MAX_ITER:-0}"  # 0 = infinite

usage() {
    cat << EOF
System Health Monitor

Usage: $(basename "$0") [OPTIONS]

Options:
    -i SEC   Check interval in seconds (default: 5)
    -c PCT   CPU alert threshold % (default: 80)
    -m PCT   Memory alert threshold % (default: 80)
    -d PCT   Disk alert threshold % (default: 90)
    -h       Show this help
EOF
    exit 0
}

while getopts "i:c:m:d:h" opt; do
    case "$opt" in
        i) INTERVAL="$OPTARG" ;;
        c) CPU_THRESHOLD="$OPTARG" ;;
        m) MEM_THRESHOLD="$OPTARG" ;;
        d) DISK_THRESHOLD="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

log_msg() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] %s\n" "$timestamp" "$*" | tee -a "$REPORT_FILE"
}

alert() {
    log_msg "ALERT: $*"
}

get_cpu_usage() {
    local idle
    idle=$(top -bn1 2>/dev/null | awk '/^%?Cpu/{gsub(/,/,"."); for(i=1;i<=NF;i++) if($i~/id/) print $(i-1)}')
    if [[ -n "$idle" ]]; then
        awk "BEGIN {printf \"%.1f\", 100 - $idle}"
    else
        echo "N/A"
    fi
}

get_memory_info() {
    if [[ -f /proc/meminfo ]]; then
        awk '/MemTotal/{total=$2} /MemAvailable/{avail=$2}
             END {
                 used=total-avail
                 pct=used/total*100
                 printf "%.0f %.0f %.1f", total/1024, used/1024, pct
             }' /proc/meminfo
    else
        echo "0 0 0.0"
    fi
}

get_disk_usage() {
    df -h / 2>/dev/null | awk 'NR==2 {
        gsub(/%/,"",$5)
        printf "%s %s %s %s", $2, $3, $4, $5
    }'
}

get_load_average() {
    if [[ -f /proc/loadavg ]]; then
        awk '{print $1, $2, $3}' /proc/loadavg
    else
        uptime | awk -F'load average:' '{print $2}' | tr -d ' '
    fi
}

display_header() {
    clear 2>/dev/null || true
    echo "╔══════════════════════════════════════════════════╗"
    echo "║          SYSTEM HEALTH MONITOR                  ║"
    echo "║   $(date '+%Y-%m-%d %H:%M:%S')                            ║"
    echo "╠══════════════════════════════════════════════════╣"
}

display_bar() {
    local pct="${1%.*}"
    local width=30
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local color

    if (( pct >= 90 )); then color="\033[31m"      # red
    elif (( pct >= 70 )); then color="\033[33m"     # yellow
    else color="\033[32m"                            # green
    fi

    printf "${color}["
    printf '%0.s#' $(seq 1 $filled 2>/dev/null) 2>/dev/null || true
    printf '%0.s-' $(seq 1 $empty 2>/dev/null) 2>/dev/null || true
    printf "] %3d%%\033[0m" "$pct"
}

check_health() {
    display_header

    # CPU
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    printf "║  CPU Usage:    "
    if [[ "$cpu_usage" != "N/A" ]]; then
        display_bar "${cpu_usage%.*}"
        echo "    ║"
        if (( ${cpu_usage%.*} > CPU_THRESHOLD )); then
            alert "CPU usage is ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
        fi
    else
        echo "N/A                                  ║"
    fi

    # Memory
    local mem_info
    mem_info=$(get_memory_info)
    read -r mem_total mem_used mem_pct <<< "$mem_info"
    printf "║  Memory:       "
    display_bar "${mem_pct%.*}"
    echo "    ║"
    printf "║    Total: %s MB / Used: %s MB              \n" "$mem_total" "$mem_used"
    if (( ${mem_pct%.*} > MEM_THRESHOLD )); then
        alert "Memory usage is ${mem_pct}% (threshold: ${MEM_THRESHOLD}%)"
    fi

    # Disk
    local disk_info
    disk_info=$(get_disk_usage)
    read -r disk_total disk_used disk_avail disk_pct <<< "$disk_info"
    printf "║  Disk (/):     "
    display_bar "$disk_pct"
    echo "    ║"
    printf "║    Total: %s / Used: %s / Avail: %s        \n" "$disk_total" "$disk_used" "$disk_avail"
    if (( disk_pct > DISK_THRESHOLD )); then
        alert "Disk usage is ${disk_pct}% (threshold: ${DISK_THRESHOLD}%)"
    fi

    # Load average
    local load_avg
    load_avg=$(get_load_average)
    printf "║  Load Average: %-34s║\n" "$load_avg"

    # Active processes
    local proc_count
    proc_count=$(ps aux 2>/dev/null | wc -l)
    printf "║  Processes:    %-34s║\n" "$proc_count"

    echo "╚══════════════════════════════════════════════════╝"
    echo "  Log: $REPORT_FILE"
    echo "  Press Ctrl+C to stop"
}

trap 'echo; echo "Monitor stopped."; exit 0' INT TERM

log_msg "System Health Monitor started (CPU>${CPU_THRESHOLD}% MEM>${MEM_THRESHOLD}% DISK>${DISK_THRESHOLD}%)"

while true; do
    check_health
    ((ITERATIONS++))
    if (( MAX_ITERATIONS > 0 && ITERATIONS >= MAX_ITERATIONS )); then
        log_msg "Reached maximum iterations ($MAX_ITERATIONS). Exiting."
        break
    fi
    sleep "$INTERVAL"
done
```

---

### 31. Project 3 — Automated Backup Utility

A script that creates incremental backups with rotation, compression, and verification.

> **See:** [`examples/practical/03_backup.sh`](examples/practical/03_backup.sh)

```bash
#!/bin/bash
# Usage: ./03_backup.sh -s /path/to/source -d /path/to/backups [-k keep_count] [-c]

set -euo pipefail

SOURCE=""
DEST=""
KEEP=7
COMPRESS=false
LOG_FILE=""
BACKUP_NAME=""

usage() {
    cat << EOF
Automated Backup Utility

Usage: $(basename "$0") [OPTIONS]

Options:
    -s PATH   Source directory to back up (required)
    -d PATH   Destination directory for backups (required)
    -k NUM    Number of backups to keep (default: 7)
    -c        Compress backup with gzip
    -h        Show this help

Examples:
    $(basename "$0") -s /home/user/projects -d /mnt/backup -k 14 -c
    $(basename "$0") -s /etc -d /backup/configs
EOF
    exit 0
}

while getopts "s:d:k:ch" opt; do
    case "$opt" in
        s) SOURCE="$OPTARG" ;;
        d) DEST="$OPTARG" ;;
        k) KEEP="$OPTARG" ;;
        c) COMPRESS=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

[[ -z "$SOURCE" ]] && { echo "Error: source (-s) is required" >&2; usage; }
[[ -z "$DEST" ]]   && { echo "Error: destination (-d) is required" >&2; usage; }
[[ -d "$SOURCE" ]] || { echo "Error: source '$SOURCE' does not exist" >&2; exit 1; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}"
LOG_FILE="${DEST}/backup.log"

mkdir -p "$DEST"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

log "========================================="
log "Backup started"
log "Source:      $SOURCE"
log "Destination: $DEST/$BACKUP_NAME"
log "Compression: $COMPRESS"
log "Keep last:   $KEEP"

# Determine the latest existing backup for incremental rsync
LATEST_LINK=""
latest_backup=$(ls -1d "$DEST"/backup_* 2>/dev/null | sort | tail -1)
if [[ -n "$latest_backup" && -d "$latest_backup" ]]; then
    LATEST_LINK="--link-dest=$latest_backup"
    log "Incremental from: $latest_backup"
else
    log "Full backup (no previous backup found)"
fi

# Perform backup
BACKUP_PATH="${DEST}/${BACKUP_NAME}"
log "Running rsync..."

rsync_opts=(-av --delete --stats)
[[ -n "$LATEST_LINK" ]] && rsync_opts+=("$LATEST_LINK")

rsync "${rsync_opts[@]}" "$SOURCE/" "$BACKUP_PATH/" 2>&1 | tee -a "$LOG_FILE"
rsync_exit=$?

if [[ $rsync_exit -ne 0 ]]; then
    log "ERROR: rsync failed with exit code $rsync_exit"
    exit 1
fi

# Compress if requested
if $COMPRESS; then
    log "Compressing backup..."
    tar -czf "${BACKUP_PATH}.tar.gz" -C "$DEST" "$BACKUP_NAME" 2>&1 | tee -a "$LOG_FILE"
    rm -rf "$BACKUP_PATH"
    BACKUP_PATH="${BACKUP_PATH}.tar.gz"
    log "Compressed to: $BACKUP_PATH"
fi

# Verify
backup_size=$(du -sh "$BACKUP_PATH" 2>/dev/null | awk '{print $1}')
log "Backup size: $backup_size"

# Rotate old backups
rotate_backups() {
    local count=0
    local all_backups

    if $COMPRESS; then
        all_backups=$(ls -1t "$DEST"/backup_*.tar.gz 2>/dev/null)
    else
        all_backups=$(ls -1dt "$DEST"/backup_*/ 2>/dev/null | sed 's:/$::')
    fi

    while IFS= read -r old_backup; do
        ((count++))
        if (( count > KEEP )); then
            log "Rotating out: $(basename "$old_backup")"
            rm -rf "$old_backup"
        fi
    done <<< "$all_backups"
}

rotate_backups
log "Backup completed successfully: $BACKUP_PATH"
log "========================================="
```

---

### 32. Project 4 — Batch File Renamer

A flexible script to rename files using patterns, regex, sequencing, and date stamps.

> **See:** [`examples/practical/04_batch_renamer.sh`](examples/practical/04_batch_renamer.sh)

```bash
#!/bin/bash
# Usage: ./04_batch_renamer.sh [OPTIONS] directory

set -euo pipefail

MODE=""
PATTERN=""
REPLACEMENT=""
PREFIX=""
SUFFIX=""
EXTENSION=""
DRY_RUN=true
RECURSIVE=false
TARGET_DIR=""

usage() {
    cat << EOF
Batch File Renamer

Usage: $(basename "$0") [OPTIONS] DIRECTORY

Modes:
    -r PAT:REP    Search and replace in filenames (PAT -> REP)
    -p PREFIX     Add prefix to all filenames
    -x SUFFIX     Add suffix (before extension) to all filenames
    -e EXT        Change file extension to EXT
    -s SEQ        Sequential rename (e.g., photo_001, photo_002, ...)
    -l            Convert filenames to lowercase
    -u            Convert filenames to uppercase
    -d            Add date prefix (YYYYMMDD_)

Options:
    --execute     Actually rename (default is dry-run)
    --recursive   Process subdirectories
    -h            Show this help

Examples:
    $(basename "$0") -r "IMG:photo" ./pictures
    $(basename "$0") -l --execute ./Documents
    $(basename "$0") -p "2026_" -e jpg ./photos
    $(basename "$0") -s "vacation_" --execute ./album
EOF
    exit 0
}

SEQUENTIAL_NAME=""
TO_LOWER=false
TO_UPPER=false
ADD_DATE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r)
            MODE="replace"
            IFS=: read -r PATTERN REPLACEMENT <<< "$2"
            shift 2
            ;;
        -p) MODE="prefix"; PREFIX="$2"; shift 2 ;;
        -x) MODE="suffix"; SUFFIX="$2"; shift 2 ;;
        -e) MODE="extension"; EXTENSION="$2"; shift 2 ;;
        -s) MODE="sequential"; SEQUENTIAL_NAME="$2"; shift 2 ;;
        -l) MODE="lowercase"; TO_LOWER=true; shift ;;
        -u) MODE="uppercase"; TO_UPPER=true; shift ;;
        -d) MODE="date"; ADD_DATE=true; shift ;;
        --execute) DRY_RUN=false; shift ;;
        --recursive) RECURSIVE=true; shift ;;
        -h|--help) usage ;;
        *)
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
            else
                echo "Error: unexpected argument '$1'" >&2
                usage
            fi
            shift
            ;;
    esac
done

[[ -z "$MODE" ]]       && { echo "Error: no rename mode specified" >&2; usage; }
[[ -z "$TARGET_DIR" ]] && { echo "Error: directory required" >&2; usage; }
[[ -d "$TARGET_DIR" ]] || { echo "Error: '$TARGET_DIR' is not a directory" >&2; exit 1; }

if $DRY_RUN; then
    echo "[DRY RUN] No files will be renamed. Use --execute to apply."
    echo
fi

renamed=0
skipped=0
errors=0
counter=1

process_file() {
    local filepath="$1"
    local dir
    dir=$(dirname "$filepath")
    local filename
    filename=$(basename "$filepath")
    local name="${filename%.*}"
    local ext="${filename##*.}"

    [[ "$name" == "$ext" ]] && ext=""
    [[ -n "$ext" ]] && ext=".$ext"

    local new_name="$filename"

    case "$MODE" in
        replace)
            new_name="${filename//$PATTERN/$REPLACEMENT}"
            ;;
        prefix)
            new_name="${PREFIX}${filename}"
            ;;
        suffix)
            new_name="${name}${SUFFIX}${ext}"
            ;;
        extension)
            new_name="${name}.${EXTENSION}"
            ;;
        sequential)
            new_name=$(printf "%s%03d%s" "$SEQUENTIAL_NAME" "$counter" "$ext")
            ((counter++))
            ;;
        lowercase)
            new_name="${filename,,}"
            ;;
        uppercase)
            new_name="${filename^^}"
            ;;
        date)
            local date_prefix
            date_prefix=$(date +%Y%m%d)
            new_name="${date_prefix}_${filename}"
            ;;
    esac

    if [[ "$new_name" == "$filename" ]]; then
        ((skipped++))
        return
    fi

    local new_path="${dir}/${new_name}"

    if [[ -e "$new_path" ]]; then
        echo "  SKIP (exists): $filename -> $new_name"
        ((skipped++))
        return
    fi

    if $DRY_RUN; then
        echo "  WOULD RENAME: $filename -> $new_name"
    else
        if mv "$filepath" "$new_path"; then
            echo "  RENAMED: $filename -> $new_name"
            ((renamed++))
        else
            echo "  ERROR: $filename" >&2
            ((errors++))
        fi
    fi
}

if $RECURSIVE; then
    find "$TARGET_DIR" -type f | sort | while IFS= read -r file; do
        process_file "$file"
    done
else
    for file in "$TARGET_DIR"/*; do
        [[ -f "$file" ]] || continue
        process_file "$file"
    done
fi

echo
echo "--- Summary ---"
echo "  Renamed: $renamed"
echo "  Skipped: $skipped"
echo "  Errors:  $errors"
if $DRY_RUN; then
    echo "  (Dry run — no files were actually changed)"
fi
```

---

### 33. Project 5 — Interactive Task Manager

A terminal-based task manager with add, list, complete, delete, and search functionality.

> **See:** [`examples/practical/05_task_manager.sh`](examples/practical/05_task_manager.sh)

```bash
#!/bin/bash
# A simple interactive CLI task manager

set -euo pipefail

TASK_FILE="${TASK_FILE:-$HOME/.bash_tasks.json}"
VERSION="1.0.0"

init_task_file() {
    if [[ ! -f "$TASK_FILE" ]]; then
        echo '[]' > "$TASK_FILE"
    fi
}

generate_id() {
    date +%s%N | sha256sum | head -c 8
}

add_task() {
    local title="$1"
    local priority="${2:-medium}"
    local category="${3:-general}"
    local id
    id=$(generate_id)
    local created
    created=$(date '+%Y-%m-%d %H:%M:%S')

    local task="{\"id\":\"$id\",\"title\":\"$title\",\"priority\":\"$priority\",\"category\":\"$category\",\"status\":\"pending\",\"created\":\"$created\"}"

    local tasks
    tasks=$(<"$TASK_FILE")
    if [[ "$tasks" == "[]" ]]; then
        echo "[$task]" > "$TASK_FILE"
    else
        # Remove trailing ] and add new task
        tasks="${tasks%]}"
        echo "${tasks},$task]" > "$TASK_FILE"
    fi

    echo "Task added: [$id] $title (priority: $priority, category: $category)"
}

list_tasks() {
    local filter="${1:-all}"
    init_task_file

    if ! command -v python3 &>/dev/null; then
        echo "Listing tasks (raw format — install python3 for formatted output):"
        cat "$TASK_FILE"
        return
    fi

    python3 << PYEOF
import json, sys

with open("$TASK_FILE") as f:
    tasks = json.load(f)

if not tasks:
    print("No tasks found. Use 'add' to create one.")
    sys.exit(0)

filter_status = "$filter"
if filter_status != "all":
    tasks = [t for t in tasks if t.get("status") == filter_status]

if not tasks:
    print(f"No {filter_status} tasks found.")
    sys.exit(0)

priority_colors = {"high": "\033[31m", "medium": "\033[33m", "low": "\033[32m"}
status_icons = {"pending": "[ ]", "done": "[x]", "in_progress": "[~]"}
reset = "\033[0m"

print(f"\n{'='*60}")
print(f"  TASK LIST ({len(tasks)} tasks)")
print(f"{'='*60}")
for t in tasks:
    color = priority_colors.get(t.get("priority", "medium"), "")
    icon = status_icons.get(t.get("status", "pending"), "[ ]")
    print(f"  {icon} {color}[{t['id']}] {t['title']}{reset}")
    print(f"      Priority: {t.get('priority','?')} | Category: {t.get('category','?')} | Created: {t.get('created','?')}")
print(f"{'='*60}\n")
PYEOF
}

complete_task() {
    local task_id="$1"

    if ! command -v python3 &>/dev/null; then
        echo "Error: python3 required for task management" >&2
        return 1
    fi

    python3 << PYEOF
import json

with open("$TASK_FILE") as f:
    tasks = json.load(f)

found = False
for t in tasks:
    if t["id"] == "$task_id":
        t["status"] = "done"
        found = True
        print(f"Task [{t['id']}] marked as done: {t['title']}")
        break

if not found:
    print(f"Task '$task_id' not found.")
else:
    with open("$TASK_FILE", "w") as f:
        json.dump(tasks, f, indent=2)
PYEOF
}

delete_task() {
    local task_id="$1"

    python3 << PYEOF
import json

with open("$TASK_FILE") as f:
    tasks = json.load(f)

original_count = len(tasks)
tasks = [t for t in tasks if t["id"] != "$task_id"]

if len(tasks) == original_count:
    print(f"Task '$task_id' not found.")
else:
    with open("$TASK_FILE", "w") as f:
        json.dump(tasks, f, indent=2)
    print(f"Task '$task_id' deleted.")
PYEOF
}

search_tasks() {
    local query="$1"

    python3 << PYEOF
import json

with open("$TASK_FILE") as f:
    tasks = json.load(f)

query = "$query".lower()
results = [t for t in tasks if query in t.get("title", "").lower() or query in t.get("category", "").lower()]

if not results:
    print(f"No tasks matching '{query}'.")
else:
    print(f"\nFound {len(results)} task(s) matching '{query}':")
    for t in results:
        status = "[x]" if t["status"] == "done" else "[ ]"
        print(f"  {status} [{t['id']}] {t['title']} ({t['priority']})")
PYEOF
}

show_help() {
    cat << EOF
Bash Task Manager v${VERSION}

Usage: $(basename "$0") COMMAND [ARGS]

Commands:
    add TITLE [PRIORITY] [CATEGORY]    Add a new task
                                        Priority: high, medium (default), low
    list [STATUS]                       List tasks (all, pending, done)
    done TASK_ID                        Mark a task as completed
    delete TASK_ID                      Delete a task
    search QUERY                        Search tasks by title or category
    interactive                         Launch interactive mode
    help                                Show this help

Examples:
    $(basename "$0") add "Write report" high work
    $(basename "$0") list pending
    $(basename "$0") done a1b2c3d4
    $(basename "$0") search "report"
EOF
}

interactive_mode() {
    echo "Bash Task Manager v${VERSION} — Interactive Mode"
    echo "Type 'help' for available commands, 'quit' to exit."
    echo

    while true; do
        read -p "tasks> " -ra cmd || break
        [[ ${#cmd[@]} -eq 0 ]] && continue

        case "${cmd[0]}" in
            add)
                if [[ ${#cmd[@]} -lt 2 ]]; then
                    echo "Usage: add TITLE [PRIORITY] [CATEGORY]"
                else
                    add_task "${cmd[1]}" "${cmd[2]:-medium}" "${cmd[3]:-general}"
                fi
                ;;
            list|ls)    list_tasks "${cmd[1]:-all}" ;;
            done)
                if [[ ${#cmd[@]} -lt 2 ]]; then
                    echo "Usage: done TASK_ID"
                else
                    complete_task "${cmd[1]}"
                fi
                ;;
            delete|rm)
                if [[ ${#cmd[@]} -lt 2 ]]; then
                    echo "Usage: delete TASK_ID"
                else
                    delete_task "${cmd[1]}"
                fi
                ;;
            search|find)
                if [[ ${#cmd[@]} -lt 2 ]]; then
                    echo "Usage: search QUERY"
                else
                    search_tasks "${cmd[1]}"
                fi
                ;;
            help|h)     show_help ;;
            quit|exit|q) echo "Goodbye!"; break ;;
            *)          echo "Unknown command: ${cmd[0]}. Type 'help'." ;;
        esac
    done
}

# Main dispatch
init_task_file

case "${1:-interactive}" in
    add)
        shift
        add_task "${1:?Error: title required}" "${2:-medium}" "${3:-general}"
        ;;
    list|ls)        list_tasks "${2:-all}" ;;
    done)           complete_task "${2:?Error: task ID required}" ;;
    delete|rm)      delete_task "${2:?Error: task ID required}" ;;
    search|find)    search_tasks "${2:?Error: search query required}" ;;
    interactive)    interactive_mode ;;
    help|-h|--help) show_help ;;
    *)              echo "Unknown command: $1"; show_help; exit 1 ;;
esac
```

---

## Quick Reference Cheat Sheet

### Variable Operations

| Syntax | Description |
|--------|-------------|
| `${var:-default}` | Use default if unset/empty |
| `${var:=default}` | Assign default if unset/empty |
| `${var:+alt}` | Use alt if set |
| `${var:?error}` | Error if unset/empty |
| `${#var}` | Length of string |
| `${var:offset:len}` | Substring |
| `${var#pattern}` | Remove shortest prefix match |
| `${var##pattern}` | Remove longest prefix match |
| `${var%pattern}` | Remove shortest suffix match |
| `${var%%pattern}` | Remove longest suffix match |
| `${var/pat/rep}` | Replace first match |
| `${var//pat/rep}` | Replace all matches |
| `${var^}` | Uppercase first char |
| `${var^^}` | Uppercase all |
| `${var,}` | Lowercase first char |
| `${var,,}` | Lowercase all |

### Test Operators

| Test | Meaning |
|------|---------|
| `-e file` | File exists |
| `-f file` | Regular file |
| `-d file` | Directory |
| `-s file` | Non-empty file |
| `-r file` | Readable |
| `-w file` | Writable |
| `-x file` | Executable |
| `-z str` | String is empty |
| `-n str` | String is non-empty |
| `s1 == s2` | Strings are equal |
| `n1 -eq n2` | Numbers are equal |
| `n1 -lt n2` | Less than |
| `n1 -gt n2` | Greater than |

### Common Patterns

```bash
# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Read file line by line
while IFS= read -r line; do ...; done < file

# Process command output without subshell
while IFS= read -r line; do ...; done < <(command)

# Safe temporary file
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

# Check command exists
command -v cmd &>/dev/null || { echo "cmd required" >&2; exit 1; }

# Parse options
while getopts "abc:d:" opt; do
    case "$opt" in
        a) flag_a=true ;;
        b) flag_b=true ;;
        c) val_c="$OPTARG" ;;
        d) val_d="$OPTARG" ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
```

---

## Further Reading

- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Bash Hackers Wiki (archived)](https://web.archive.org/web/2023/https://wiki.bash-hackers.org/)
- [ShellCheck](https://www.shellcheck.net/) — static analysis tool for shell scripts
- [Advanced Bash-Scripting Guide (TLDP)](https://tldp.org/LDP/abs/html/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

---

*This tutorial is part of the Bash Programming Tutorial repository. All example scripts in the `examples/` directory are independently runnable.*
