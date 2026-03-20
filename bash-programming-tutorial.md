# Comprehensive BASH Programming Tutorial

## Table of Contents

1. [Introduction to BASH](#1-introduction-to-bash)
2. [Getting Started](#2-getting-started)
3. [Variables](#3-variables)
4. [Quoting and Escaping](#4-quoting-and-escaping)
5. [User Input and Output](#5-user-input-and-output)
6. [Operators](#6-operators)
7. [Conditional Statements](#7-conditional-statements)
8. [Loops](#8-loops)
9. [Functions](#9-functions)
10. [Arrays](#10-arrays)
11. [String Manipulation](#11-string-manipulation)
12. [File and Directory Operations](#12-file-and-directory-operations)
13. [Regular Expressions](#13-regular-expressions)
14. [Process Management](#14-process-management)
15. [Input/Output Redirection and Pipes](#15-inputoutput-redirection-and-pipes)
16. [Error Handling and Debugging](#16-error-handling-and-debugging)
17. [Signals and Traps](#17-signals-and-traps)
18. [Subshells and Process Substitution](#18-subshells-and-process-substitution)
19. [Here Documents and Here Strings](#19-here-documents-and-here-strings)
20. [Advanced Parameter Expansion](#20-advanced-parameter-expansion)
21. [Associative Arrays](#21-associative-arrays)
22. [Command-Line Argument Parsing](#22-command-line-argument-parsing)
23. [Networking with BASH](#23-networking-with-bash)
24. [Performance and Best Practices](#24-performance-and-best-practices)
25. [Practical Examples](#25-practical-examples)

---

## 1. Introduction to BASH

**BASH** (Bourne Again SHell) is the default command-line interpreter on most Linux distributions and macOS. It is a superset of the original Bourne Shell (`sh`) and incorporates features from the Korn Shell (`ksh`) and C Shell (`csh`).

### Why Learn BASH?

- **System administration**: Automate server management, deployments, and monitoring.
- **DevOps**: Build CI/CD pipelines, infrastructure-as-code tooling, and container orchestration scripts.
- **Text processing**: Transform, filter, and analyze logs and data files.
- **Task automation**: Replace repetitive manual work with reliable scripts.
- **Portability**: BASH is available on virtually every Unix-like system.

### BASH vs. Other Shells

| Feature | BASH | Zsh | Fish | Dash |
|---------|------|-----|------|------|
| POSIX compliant | Mostly | Mostly | No | Yes |
| Arrays | Yes | Yes | Yes | No |
| Associative arrays | Yes (4.0+) | Yes | Yes | No |
| Programmable completion | Yes | Yes | Yes | No |
| Startup speed | Medium | Medium | Fast | Fast |

---

## 2. Getting Started

### Your First Script

Create a file called `hello.sh`:

```bash
#!/bin/bash
echo "Hello, World!"
```

### Making It Executable

```bash
chmod +x hello.sh
./hello.sh
```

### The Shebang Line

The first line `#!/bin/bash` is the **shebang** (or hashbang). It tells the kernel which interpreter to use. Common variants:

```bash
#!/bin/bash          # Use bash explicitly
#!/usr/bin/env bash  # Portable: finds bash via PATH
#!/bin/sh            # POSIX shell (may not be bash)
```

> **Best practice**: Use `#!/usr/bin/env bash` for portability across systems where bash may be installed in different locations.

### Running Scripts

```bash
# Method 1: Direct execution (requires +x permission)
./hello.sh

# Method 2: Explicit interpreter (no +x needed)
bash hello.sh

# Method 3: Source into current shell (variables persist)
source hello.sh
# or equivalently:
. hello.sh
```

### Script Exit Codes

Every command returns an exit code. `0` means success; anything else means failure.

```bash
#!/bin/bash
echo "This will succeed"
exit 0    # Explicit success

# exit 1  # Would indicate general error
# exit 2  # Would indicate misuse of shell builtins
```

Check the last exit code with `$?`:

```bash
ls /nonexistent 2>/dev/null
echo "Exit code: $?"   # Output: Exit code: 2
```

---

## 3. Variables

### Declaring Variables

Variables in BASH are untyped by default. **No spaces** around the `=` sign.

```bash
#!/bin/bash

name="Alice"
age=30
pi=3.14159

echo "Name: $name"
echo "Age: $age"
echo "Pi: $pi"
```

### Variable Naming Rules

- Must start with a letter or underscore
- Can contain letters, digits, and underscores
- Case-sensitive (`Name` and `name` are different)
- Convention: lowercase for local, UPPERCASE for exported/environment variables

```bash
valid_name="yes"
_also_valid="yes"
camelCase="works but not conventional"
EXPORTED_VAR="typically uppercase"

# Invalid:
# 2name="no"      # Cannot start with a digit
# my-var="no"     # Hyphens not allowed
# my var="no"     # Spaces not allowed
```

### Variable Types with `declare`

```bash
declare -i count=10      # Integer: arithmetic is automatic
count=count+5            # No need for $(( )), result is 15
echo "$count"

declare -r CONSTANT="immutable"
# CONSTANT="new value"  # Error: readonly variable

declare -l lower="HELLO" # Stored as lowercase
echo "$lower"            # Output: hello

declare -u upper="hello" # Stored as uppercase
echo "$upper"            # Output: HELLO

declare -x EXPORTED="visible to child processes"
```

### Environment Variables

```bash
# Export a variable so child processes can see it
export PATH="$PATH:/opt/myapp/bin"
export EDITOR="vim"

# View all environment variables
env
printenv

# Common built-in variables
echo "Home directory: $HOME"
echo "Current user:   $USER"
echo "Shell:          $SHELL"
echo "Working dir:    $PWD"
echo "Hostname:       $HOSTNAME"
echo "Process ID:     $$"
echo "Script name:    $0"
echo "Argument count: $#"
echo "All arguments:  $@"
echo "Last exit code: $?"
echo "Last bg PID:    $!"
```

### Special Variables Reference

| Variable | Description |
|----------|-------------|
| `$0` | Name of the script |
| `$1` to `$9` | Positional parameters (arguments) |
| `${10}` | 10th argument and beyond (braces required) |
| `$#` | Number of arguments |
| `$@` | All arguments as separate words |
| `$*` | All arguments as a single word |
| `$$` | PID of the current shell |
| `$!` | PID of the last background process |
| `$?` | Exit status of the last command |
| `$_` | Last argument of the previous command |
| `$-` | Current shell option flags |

### Command Substitution

```bash
# Modern syntax (preferred)
current_date=$(date +%Y-%m-%d)
file_count=$(ls -1 | wc -l)

# Legacy syntax (avoid in new code)
current_date=`date +%Y-%m-%d`

# Nesting is clean with $()
user_shell=$(basename $(getent passwd $USER | cut -d: -f7))
echo "Your shell is: $user_shell"
```

### Arithmetic

```bash
# $(( )) for integer arithmetic
a=10
b=3
echo "Sum:        $((a + b))"      # 13
echo "Difference: $((a - b))"      # 7
echo "Product:    $((a * b))"      # 30
echo "Division:   $((a / b))"      # 3 (integer division)
echo "Modulo:     $((a % b))"      # 1
echo "Power:      $((a ** b))"     # 1000

# Increment / decrement
((a++))
echo "After a++: $a"               # 11
((a--))
echo "After a--: $a"               # 10
((a += 5))
echo "After a+=5: $a"              # 15

# Ternary operator
max=$(( a > b ? a : b ))
echo "Max: $max"                   # 15
```

> **Note**: BASH only supports integer arithmetic natively. For floating-point, use `bc` or `awk`:

```bash
result=$(echo "scale=4; 10 / 3" | bc)
echo "10 / 3 = $result"   # 3.3333

result=$(awk "BEGIN {printf \"%.4f\", 10/3}")
echo "10 / 3 = $result"   # 3.3333
```

---

## 4. Quoting and Escaping

Understanding quoting is fundamental to writing correct BASH scripts.

### Double Quotes (`"..."`)

Variables and command substitutions are expanded. Word splitting and globbing are suppressed.

```bash
name="Alice"
echo "Hello, $name"           # Hello, Alice
echo "Files: $(ls | wc -l)"   # Files: 42
echo "Home is $HOME"          # Home is /home/alice

# Preserves whitespace
msg="  hello   world  "
echo "$msg"                    #   hello   world  
```

### Single Quotes (`'...'`)

Everything is literal. No expansion occurs.

```bash
echo 'Hello, $name'           # Hello, $name
echo 'No $(commands) here'    # No $(commands) here
echo 'Backslash: \n stays'    # Backslash: \n stays
```

### `$'...'` (ANSI-C Quoting)

Interprets escape sequences like `\n`, `\t`, `\\`.

```bash
echo $'Line 1\nLine 2'
# Output:
# Line 1
# Line 2

echo $'Column1\tColumn2'
# Output:
# Column1    Column2

echo $'It\'s a quote'
# Output:
# It's a quote
```

### Escaping

```bash
echo "The price is \$100"       # The price is $100
echo "She said \"hello\""       # She said "hello"
echo "Backslash: \\"            # Backslash: \
echo "New line: not \\n here"   # New line: not \n here
```

### When to Use Which

| Scenario | Quote Type |
|----------|-----------|
| Variable expansion needed | Double quotes `"..."` |
| Literal string, no expansion | Single quotes `'...'` |
| Escape sequences needed | `$'...'` |
| File paths with spaces | Double quotes `"$path"` |

> **Best practice**: Always quote your variables — `"$var"` — unless you intentionally want word splitting.

---

## 5. User Input and Output

### Reading Input

```bash
#!/bin/bash

# Simple read
echo -n "Enter your name: "
read name
echo "Hello, $name!"

# Read with prompt (no need for echo)
read -p "Enter your age: " age
echo "You are $age years old."

# Silent input (for passwords)
read -sp "Enter password: " password
echo    # Print newline after silent input
echo "Password length: ${#password}"

# Read with timeout (5 seconds)
read -t 5 -p "Quick! Enter something: " answer || echo "Too slow!"

# Read with character limit
read -n 1 -p "Press any key to continue..."
echo

# Read into an array
echo "Enter three words:"
read -a words
echo "First: ${words[0]}, Second: ${words[1]}, Third: ${words[2]}"

# Read from a file line by line
while IFS= read -r line; do
    echo "Line: $line"
done < /etc/hostname
```

### Output with `echo`

```bash
echo "Simple text"
echo -n "No newline at end"
echo -e "Tabs:\there\nNewlines:\nhere"   # Enable escape sequences
echo -E "No escapes: \n \t"              # Disable escape sequences (default)
```

### Output with `printf`

`printf` gives fine-grained control over formatting — it mirrors C's `printf`.

```bash
printf "Hello, %s! You are %d years old.\n" "Alice" 30
printf "Pi is approximately %.4f\n" 3.14159
printf "Hex: %x, Octal: %o\n" 255 255
printf "%20s | %10s | %5s\n" "Name" "Age" "Score"
printf "%20s | %10d | %5.1f\n" "Alice" 30 95.5
printf "%20s | %10d | %5.1f\n" "Bob" 25 88.3

# Padding and alignment
printf "%-20s %5d\n" "Left-aligned" 42
printf "%020d\n" 42                       # Zero-padded: 00000000000000000042
```

### Coloring Output

```bash
# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'  # No Color (reset)

echo -e "${RED}Error: Something went wrong${NC}"
echo -e "${GREEN}Success: Operation completed${NC}"
echo -e "${YELLOW}Warning: Disk space low${NC}"
echo -e "${BLUE}Info: Processing started${NC}"
echo -e "${BOLD}This is bold text${NC}"

# Practical: status messages
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; }

info "Starting deployment..."
success "Build completed"
warn "Cache is stale"
error "Connection refused"
```

---

## 6. Operators

### Comparison Operators (Integers)

Used inside `[ ]` or `[[ ]]`:

```bash
a=10
b=20

[ "$a" -eq "$b" ]   # Equal
[ "$a" -ne "$b" ]   # Not equal
[ "$a" -lt "$b" ]   # Less than
[ "$a" -le "$b" ]   # Less than or equal
[ "$a" -gt "$b" ]   # Greater than
[ "$a" -ge "$b" ]   # Greater than or equal
```

Inside `(( ))` you can use C-style operators:

```bash
(( a == b ))   # Equal
(( a != b ))   # Not equal
(( a < b ))    # Less than
(( a <= b ))   # Less than or equal
(( a > b ))    # Greater than
(( a >= b ))   # Greater than or equal
```

### String Operators

```bash
str1="hello"
str2="world"

[ "$str1" = "$str2" ]     # Equal (POSIX)
[ "$str1" == "$str2" ]    # Equal (bash extension)
[ "$str1" != "$str2" ]    # Not equal
[ -z "$str1" ]            # True if string is empty
[ -n "$str1" ]            # True if string is non-empty

# Pattern matching (only in [[ ]])
[[ "$str1" == h* ]]       # Glob pattern match
[[ "$str1" =~ ^hel ]]     # Regex match
```

### File Test Operators

```bash
file="/etc/passwd"

[ -e "$file" ]    # Exists
[ -f "$file" ]    # Is a regular file
[ -d "$file" ]    # Is a directory
[ -L "$file" ]    # Is a symbolic link
[ -r "$file" ]    # Is readable
[ -w "$file" ]    # Is writable
[ -x "$file" ]    # Is executable
[ -s "$file" ]    # Has size > 0
[ -p "$file" ]    # Is a named pipe (FIFO)
[ -S "$file" ]    # Is a socket
[ -b "$file" ]    # Is a block device
[ -c "$file" ]    # Is a character device

# File comparisons
[ "$file1" -nt "$file2" ]   # file1 is newer than file2
[ "$file1" -ot "$file2" ]   # file1 is older than file2
[ "$file1" -ef "$file2" ]   # Same inode (hard links)
```

### Logical Operators

```bash
# Inside [ ]
[ "$a" -gt 5 ] && [ "$a" -lt 15 ]   # AND
[ "$a" -lt 5 ] || [ "$a" -gt 15 ]   # OR
[ ! -f "$file" ]                      # NOT

# Inside [[ ]] (preferred)
[[ "$a" -gt 5 && "$a" -lt 15 ]]     # AND
[[ "$a" -lt 5 || "$a" -gt 15 ]]     # OR
[[ ! -f "$file" ]]                    # NOT

# Short-circuit evaluation
[[ -f "$file" ]] && echo "File exists"
[[ -f "$file" ]] || echo "File missing"
```

---

## 7. Conditional Statements

### `if` / `elif` / `else`

```bash
#!/bin/bash

read -p "Enter a number: " num

if (( num > 0 )); then
    echo "$num is positive"
elif (( num < 0 )); then
    echo "$num is negative"
else
    echo "$num is zero"
fi
```

### `[ ]` vs `[[ ]]`

`[[ ]]` is a BASH keyword (not a command) and provides several advantages:

```bash
file="my file.txt"

# [ ] requires quoting to avoid word splitting issues
if [ -f "$file" ]; then
    echo "Found"
fi

# [[ ]] handles unquoted variables safely (though quoting is still recommended)
if [[ -f $file ]]; then
    echo "Found"
fi

# [[ ]] supports && and || directly
if [[ -f "$file" && -r "$file" ]]; then
    echo "Readable file"
fi

# [[ ]] supports regex matching
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "Valid email format"
fi

# [[ ]] supports glob pattern matching
if [[ "$filename" == *.tar.gz ]]; then
    echo "It's a gzipped tarball"
fi
```

### `case` Statement

```bash
#!/bin/bash

read -p "Enter a fruit: " fruit

case "$fruit" in
    apple|Apple)
        echo "It's an apple!"
        ;;
    banana|Banana)
        echo "It's a banana!"
        ;;
    orange|Orange)
        echo "It's an orange!"
        ;;
    *)
        echo "Unknown fruit: $fruit"
        ;;
esac
```

Advanced `case` with patterns:

```bash
#!/bin/bash

read -p "Enter a filename: " file

case "$file" in
    *.tar.gz|*.tgz)
        echo "Gzipped tarball"
        tar -tzf "$file"
        ;;
    *.tar.bz2|*.tbz2)
        echo "Bzip2 tarball"
        tar -tjf "$file"
        ;;
    *.zip)
        echo "ZIP archive"
        unzip -l "$file"
        ;;
    *.jpg|*.jpeg|*.png|*.gif)
        echo "Image file"
        ;;
    *.sh)
        echo "Shell script"
        bash -n "$file" && echo "Syntax OK" || echo "Syntax errors found"
        ;;
    *)
        echo "Unknown file type"
        file "$file"
        ;;
esac
```

### `case` Fall-Through (BASH 4.0+)

```bash
case "$grade" in
    A)
        echo "Excellent"
        ;;&               # Continue testing patterns
    A|B)
        echo "Pass with honors"
        ;;&
    A|B|C)
        echo "Pass"
        ;;
    *)
        echo "Fail"
        ;;
esac

# With grade="A", output is:
# Excellent
# Pass with honors
# Pass
```

---

## 8. Loops

### `for` Loop

```bash
#!/bin/bash

# Iterating over a list
for fruit in apple banana cherry; do
    echo "I like $fruit"
done

# C-style for loop
for ((i = 0; i < 5; i++)); do
    echo "Iteration $i"
done

# Iterating over a range
for i in {1..10}; do
    echo "Number: $i"
done

# Range with step
for i in {0..100..10}; do
    echo "Tens: $i"
done

# Iterating over files
for file in /var/log/*.log; do
    [[ -f "$file" ]] || continue
    echo "Log file: $file ($(wc -l < "$file") lines)"
done

# Iterating over command output
for user in $(cut -d: -f1 /etc/passwd); do
    echo "User: $user"
done

# Iterating over array elements
colors=("red" "green" "blue" "yellow")
for color in "${colors[@]}"; do
    echo "Color: $color"
done

# Iterating with index
for i in "${!colors[@]}"; do
    echo "  colors[$i] = ${colors[$i]}"
done
```

### `while` Loop

```bash
#!/bin/bash

# Basic while loop
count=1
while (( count <= 5 )); do
    echo "Count: $count"
    ((count++))
done

# Reading a file line by line (the correct way)
while IFS= read -r line; do
    echo ">> $line"
done < /etc/hostname

# Infinite loop with break
while true; do
    read -p "Enter 'quit' to exit: " input
    [[ "$input" == "quit" ]] && break
    echo "You entered: $input"
done

# Reading from a pipe
find /tmp -maxdepth 1 -type f -name "*.tmp" 2>/dev/null | while read -r tmpfile; do
    echo "Temp file: $tmpfile"
done

# While loop with multiple conditions
x=0
y=10
while (( x < 5 && y > 0 )); do
    echo "x=$x, y=$y"
    ((x++))
    ((y -= 2))
done
```

### `until` Loop

Executes as long as the condition is **false** (opposite of `while`):

```bash
#!/bin/bash

count=1
until (( count > 5 )); do
    echo "Count: $count"
    ((count++))
done
```

### `select` Loop (Menu)

```bash
#!/bin/bash

PS3="Choose an option: "   # Custom prompt for select

select choice in "Start" "Stop" "Restart" "Status" "Quit"; do
    case "$choice" in
        Start)   echo "Starting service..."; ;;
        Stop)    echo "Stopping service..."; ;;
        Restart) echo "Restarting service..."; ;;
        Status)  echo "Service is running."; ;;
        Quit)    echo "Goodbye!"; break; ;;
        *)       echo "Invalid option. Try again."; ;;
    esac
done
```

### Loop Control

```bash
#!/bin/bash

# break: exit the loop entirely
for i in {1..10}; do
    (( i == 5 )) && break
    echo "i = $i"
done
# Output: 1 2 3 4

# continue: skip to next iteration
for i in {1..10}; do
    (( i % 2 == 0 )) && continue
    echo "Odd: $i"
done
# Output: 1 3 5 7 9

# Breaking out of nested loops
for i in {1..3}; do
    for j in {1..3}; do
        (( i == 2 && j == 2 )) && break 2   # Break both loops
        echo "i=$i, j=$j"
    done
done
```

---

## 9. Functions

### Defining Functions

```bash
#!/bin/bash

# Style 1: Preferred
greet() {
    echo "Hello, $1!"
}

# Style 2: Also valid
function farewell {
    echo "Goodbye, $1!"
}

greet "Alice"       # Hello, Alice!
farewell "Bob"      # Goodbye, Bob!
```

### Parameters and Return Values

```bash
#!/bin/bash

add() {
    local a=$1
    local b=$2
    echo $((a + b))   # "Return" by printing
}

result=$(add 10 20)
echo "10 + 20 = $result"

# Return codes (0-255 only)
is_even() {
    (( $1 % 2 == 0 ))   # Sets $? to 0 (true) or 1 (false)
}

if is_even 42; then
    echo "42 is even"
fi

# Multiple return values via a nameref (BASH 4.3+)
get_dimensions() {
    local -n _width=$1
    local -n _height=$2
    _width=1920
    _height=1080
}

get_dimensions w h
echo "Resolution: ${w}x${h}"
```

### Local Variables and Scope

```bash
#!/bin/bash

global_var="I'm global"

my_function() {
    local local_var="I'm local"
    global_var="Modified by function"
    echo "Inside: local_var=$local_var, global_var=$global_var"
}

my_function
echo "Outside: global_var=$global_var"
echo "Outside: local_var=${local_var:-undefined}"  # undefined
```

### Default Parameter Values

```bash
#!/bin/bash

deploy() {
    local env="${1:-production}"
    local version="${2:-latest}"
    local dry_run="${3:-false}"

    echo "Deploying version '$version' to '$env' (dry_run=$dry_run)"
}

deploy                          # production, latest, false
deploy "staging"                # staging, latest, false
deploy "dev" "v2.1.0" "true"   # dev, v2.1.0, true
```

### Recursive Functions

```bash
#!/bin/bash

factorial() {
    local n=$1
    if (( n <= 1 )); then
        echo 1
    else
        local sub
        sub=$(factorial $((n - 1)))
        echo $((n * sub))
    fi
}

echo "5! = $(factorial 5)"    # 120
echo "10! = $(factorial 10)"  # 3628800
```

### Function Libraries

You can organize reusable functions into a separate file and source it:

```bash
# lib/utils.sh
log() {
    local level=$1; shift
    printf "[%s] [%-5s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
}

die() {
    log "ERROR" "$@" >&2
    exit 1
}

require_command() {
    command -v "$1" &>/dev/null || die "Required command not found: $1"
}
```

```bash
# main.sh
#!/bin/bash
source "$(dirname "$0")/lib/utils.sh"

require_command "git"
log "INFO" "All dependencies satisfied"
```

---

## 10. Arrays

### Indexed Arrays

```bash
#!/bin/bash

# Declaration
fruits=("apple" "banana" "cherry" "date")

# Accessing elements
echo "First:  ${fruits[0]}"
echo "Second: ${fruits[1]}"
echo "Last:   ${fruits[-1]}"     # Negative indexing (BASH 4.2+)

# All elements
echo "All: ${fruits[@]}"
echo "All (as single string): ${fruits[*]}"

# Length
echo "Count: ${#fruits[@]}"
echo "Length of first element: ${#fruits[0]}"

# Adding elements
fruits+=("elderberry")
fruits+=("fig" "grape")

# Removing elements
unset 'fruits[1]'                # Removes "banana" (index 1 becomes empty)
echo "After unset [1]: ${fruits[@]}"

# Slicing
echo "Slice [1..3]: ${fruits[@]:1:3}"

# Iterating
for fruit in "${fruits[@]}"; do
    echo "  - $fruit"
done

# Iterating with indices
for i in "${!fruits[@]}"; do
    echo "  [$i] = ${fruits[$i]}"
done
```

### Array Operations

```bash
#!/bin/bash

arr=(3 1 4 1 5 9 2 6 5 3 5)

# Copy an array
copy=("${arr[@]}")

# Concatenate arrays
a=(1 2 3)
b=(4 5 6)
combined=("${a[@]}" "${b[@]}")
echo "Combined: ${combined[@]}"    # 1 2 3 4 5 6

# Search in array
contains() {
    local target=$1; shift
    for element in "$@"; do
        [[ "$element" == "$target" ]] && return 0
    done
    return 1
}

if contains "cherry" "${fruits[@]}"; then
    echo "Found cherry!"
fi

# Sort an array (using process substitution)
sorted=($(printf '%s\n' "${arr[@]}" | sort -n))
echo "Sorted: ${sorted[@]}"

# Unique elements
unique=($(printf '%s\n' "${arr[@]}" | sort -nu))
echo "Unique: ${unique[@]}"

# Join array elements
join_by() {
    local separator=$1; shift
    local first=$1; shift
    printf '%s' "$first" "${@/#/$separator}"
}
echo "Joined: $(join_by ', ' "${fruits[@]}")"
```

### Reading into Arrays

```bash
# From command output
mapfile -t lines < /etc/hostname       # BASH 4.0+
readarray -t lines < /etc/hostname     # Synonym for mapfile

# From a string
IFS=',' read -ra csv_fields <<< "field1,field2,field3"
echo "Fields: ${csv_fields[@]}"

# From command output
mapfile -t users < <(cut -d: -f1 /etc/passwd | head -5)
echo "First 5 users: ${users[@]}"
```

---

## 11. String Manipulation

### String Length

```bash
str="Hello, World!"
echo "Length: ${#str}"      # 13
```

### Substring Extraction

```bash
str="Hello, World!"
echo "${str:0:5}"     # Hello     (offset 0, length 5)
echo "${str:7}"       # World!    (offset 7, to end)
echo "${str: -6}"     # orld!     (last 6 chars — note the space before -)
echo "${str:7:5}"     # World     (offset 7, length 5)
```

### Search and Replace

```bash
str="Hello World Hello BASH"

# Replace first occurrence
echo "${str/Hello/Hi}"       # Hi World Hello BASH

# Replace all occurrences
echo "${str//Hello/Hi}"      # Hi World Hi BASH

# Replace at beginning
echo "${str/#Hello/Hi}"      # Hi World Hello BASH

# Replace at end
echo "${str/%BASH/Shell}"    # Hello World Hello Shell

# Delete (replace with nothing)
echo "${str// /}"            # HelloWorldHelloBASH
```

### Pattern Removal

```bash
path="/home/user/documents/report.tar.gz"

# Remove shortest match from beginning
echo "${path#*/}"        # home/user/documents/report.tar.gz

# Remove longest match from beginning
echo "${path##*/}"       # report.tar.gz  (like basename)

# Remove shortest match from end
echo "${path%.*}"        # /home/user/documents/report.tar

# Remove longest match from end
echo "${path%%.*}"       # /home/user/documents/report

# Practical: extract filename parts
filename="${path##*/}"           # report.tar.gz
directory="${path%/*}"           # /home/user/documents
extension="${filename##*.}"      # gz
name_no_ext="${filename%%.*}"    # report
```

### Case Conversion (BASH 4.0+)

```bash
str="Hello World"

echo "${str^^}"    # HELLO WORLD   (uppercase all)
echo "${str,,}"    # hello world   (lowercase all)
echo "${str^}"     # Hello World   (uppercase first char)
echo "${str,}"     # hello World   (lowercase first char)

# Selective conversion
echo "${str^^[aeiou]}"   # HEllO WOrld  (uppercase vowels only)
```

### Default Values

```bash
# Use default if variable is unset or empty
echo "${name:-Anonymous}"

# Assign default if variable is unset or empty
echo "${name:=Anonymous}"

# Error if unset or empty
# echo "${name:?Variable 'name' is required}"

# Use alternative value if variable IS set
echo "${name:+Name is: $name}"
```

---

## 12. File and Directory Operations

### Testing Files

```bash
#!/bin/bash

check_path() {
    local path=$1

    if [[ ! -e "$path" ]]; then
        echo "'$path' does not exist"
        return 1
    fi

    echo "Path: $path"
    echo "  Type: $(file -b "$path")"

    [[ -f "$path" ]] && echo "  Regular file"
    [[ -d "$path" ]] && echo "  Directory"
    [[ -L "$path" ]] && echo "  Symbolic link -> $(readlink -f "$path")"
    [[ -r "$path" ]] && echo "  Readable"
    [[ -w "$path" ]] && echo "  Writable"
    [[ -x "$path" ]] && echo "  Executable"

    if [[ -f "$path" ]]; then
        echo "  Size: $(stat --format='%s' "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null) bytes"
        echo "  Lines: $(wc -l < "$path")"
    fi
}

check_path "/etc/passwd"
check_path "/tmp"
```

### Reading and Writing Files

```bash
#!/bin/bash

# Write to a file (overwrite)
echo "First line" > output.txt

# Append to a file
echo "Second line" >> output.txt
date >> output.txt

# Write multiple lines
cat > config.txt << 'EOF'
host=localhost
port=8080
debug=false
EOF

# Read entire file into a variable
content=$(< output.txt)
echo "$content"

# Read file line by line
while IFS= read -r line; do
    echo "Processing: $line"
done < output.txt

# Read specific fields from a delimited file
while IFS=: read -r user _ uid gid _ home shell; do
    if (( uid >= 1000 )); then
        printf "%-15s UID=%-5s %s\n" "$user" "$uid" "$shell"
    fi
done < /etc/passwd
```

### Directory Traversal

```bash
#!/bin/bash

# Recursive directory listing
list_tree() {
    local dir="${1:-.}"
    local indent="${2:-}"

    for entry in "$dir"/*; do
        [[ -e "$entry" ]] || continue
        local name="${entry##*/}"

        if [[ -d "$entry" ]]; then
            echo "${indent}[DIR]  $name/"
            list_tree "$entry" "  $indent"
        else
            local size
            size=$(stat --format='%s' "$entry" 2>/dev/null || stat -f%z "$entry" 2>/dev/null)
            echo "${indent}[FILE] $name ($size bytes)"
        fi
    done
}

list_tree /etc/cron.d
```

### Temporary Files

```bash
#!/bin/bash

# Safely create temporary files
tmpfile=$(mktemp)
tmpdir=$(mktemp -d)

cleanup() {
    rm -f "$tmpfile"
    rm -rf "$tmpdir"
}
trap cleanup EXIT

echo "Working with temp file: $tmpfile"
echo "Working with temp dir:  $tmpdir"

echo "some data" > "$tmpfile"
cp important_data.txt "$tmpdir/" 2>/dev/null
```

---

## 13. Regular Expressions

### BASH Regex Matching with `=~`

```bash
#!/bin/bash

# Basic regex match
string="Error: file not found at line 42"

if [[ "$string" =~ ^Error ]]; then
    echo "Starts with 'Error'"
fi

# Capture groups via BASH_REMATCH
if [[ "$string" =~ line\ ([0-9]+) ]]; then
    echo "Line number: ${BASH_REMATCH[1]}"   # 42
fi

# Email validation
validate_email() {
    local email=$1
    local pattern='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if [[ "$email" =~ $pattern ]]; then
        echo "'$email' is valid"
        return 0
    else
        echo "'$email' is invalid"
        return 1
    fi
}

validate_email "user@example.com"    # valid
validate_email "not-an-email"        # invalid

# IP address validation
validate_ipv4() {
    local ip=$1
    local pattern='^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$'

    if [[ "$ip" =~ $pattern ]]; then
        for i in 1 2 3 4; do
            (( ${BASH_REMATCH[$i]} > 255 )) && return 1
        done
        return 0
    fi
    return 1
}

validate_ipv4 "192.168.1.1" && echo "Valid IP" || echo "Invalid IP"
validate_ipv4 "999.1.1.1"   && echo "Valid IP" || echo "Invalid IP"
```

### Using `grep` with Regex

```bash
# Basic grep
grep "error" /var/log/syslog 2>/dev/null

# Extended regex
grep -E "^(root|admin):" /etc/passwd

# Case-insensitive
grep -i "warning" logfile.txt 2>/dev/null

# Only print matching part
grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' access.log 2>/dev/null

# Count matches
grep -c "404" access.log 2>/dev/null

# Invert match (lines that DON'T match)
grep -v "^#" /etc/fstab 2>/dev/null  # Skip comment lines
```

### Using `sed` with Regex

```bash
# Replace first occurrence per line
echo "hello world hello" | sed 's/hello/hi/'

# Replace all occurrences
echo "hello world hello" | sed 's/hello/hi/g'

# Case-insensitive replace
echo "Hello HELLO hello" | sed 's/hello/hi/gi'

# Delete lines matching a pattern
sed '/^#/d' /etc/fstab 2>/dev/null       # Remove comment lines

# In-place editing
sed -i 's/old_value/new_value/g' config.txt 2>/dev/null

# Extract text using capture groups
echo "2025-01-15" | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/'
# Output: 15/01/2025

# Multi-command
echo "Hello World" | sed -e 's/Hello/Hi/' -e 's/World/BASH/'
```

### Using `awk` with Regex

```bash
# Print lines matching a pattern
awk '/error/' /var/log/syslog 2>/dev/null

# Print specific fields
echo "Alice 30 Engineer" | awk '{print $1, $3}'

# Field separator
awk -F: '{print $1, $3}' /etc/passwd | head -5

# Conditional processing
awk -F: '$3 >= 1000 {printf "%-15s UID=%s\n", $1, $3}' /etc/passwd

# Sum a column
echo -e "10\n20\n30" | awk '{sum += $1} END {print "Total:", sum}'

# Process CSV
echo -e "Alice,90\nBob,85\nCharlie,92" | \
    awk -F, '{sum+=$2; count++} END {printf "Average: %.1f\n", sum/count}'
```

---

## 14. Process Management

### Running Processes

```bash
# Run in background
long_running_command &
bg_pid=$!
echo "Background PID: $bg_pid"

# Wait for a background process
wait $bg_pid
echo "Process exited with status: $?"

# Wait for all background processes
wait

# Run multiple commands in parallel
for i in {1..5}; do
    process_item "$i" &
done
wait
echo "All items processed"
```

### Job Control

```bash
# List jobs
jobs

# Bring job to foreground
fg %1

# Send job to background
bg %1

# Suspend current foreground job: press Ctrl+Z

# Kill a job
kill %1
```

### Process Substitution

```bash
# Compare two command outputs
diff <(ls /dir1) <(ls /dir2)

# Use command output as a file
while IFS= read -r line; do
    echo "$line"
done < <(find /tmp -maxdepth 1 -type f)

# Feed into a command that requires a filename
paste <(cut -d: -f1 /etc/passwd) <(cut -d: -f3 /etc/passwd) | head -5
```

### Parallel Execution

```bash
#!/bin/bash

# Simple parallel with max jobs
max_jobs=4
job_count=0

for url in "${urls[@]}"; do
    curl -sO "$url" &
    ((job_count++))

    if (( job_count >= max_jobs )); then
        wait -n   # Wait for any single job to finish (BASH 4.3+)
        ((job_count--))
    fi
done
wait

# Using xargs for parallel execution
find . -name "*.jpg" -print0 | xargs -0 -P 4 -I {} convert {} -resize 50% "thumb_{}"
```

### Checking If a Process Is Running

```bash
is_running() {
    local process_name=$1
    pgrep -x "$process_name" &>/dev/null
}

if is_running "nginx"; then
    echo "Nginx is running"
else
    echo "Nginx is not running"
fi
```

---

## 15. Input/Output Redirection and Pipes

### File Descriptors

```bash
# Standard file descriptors:
# 0 = stdin
# 1 = stdout
# 2 = stderr

# Redirect stdout to file
echo "output" > file.txt

# Redirect stderr to file
command_that_fails 2> errors.txt

# Redirect both stdout and stderr
command &> all_output.txt       # BASH shorthand
command > output.txt 2>&1       # POSIX equivalent

# Append
echo "more" >> file.txt
command &>> all_output.txt

# Redirect stderr to stdout
command 2>&1

# Discard output
command > /dev/null 2>&1
command &> /dev/null             # BASH shorthand
```

### Custom File Descriptors

```bash
#!/bin/bash

# Open FD 3 for writing
exec 3> custom_output.txt
echo "Written to FD 3" >&3
echo "Also to FD 3" >&3
exec 3>&-   # Close FD 3

# Open FD 4 for reading
exec 4< /etc/hostname
read -r hostname <&4
exec 4<&-   # Close FD 4
echo "Hostname: $hostname"

# Open FD 5 for read/write
exec 5<> /tmp/rw_file.txt
echo "data" >&5
exec 5>&-
```

### Pipes

```bash
# Simple pipe
ls -la | grep "^d"                    # List only directories
cat /etc/passwd | cut -d: -f1 | sort  # Sorted usernames

# Named pipes (FIFOs)
mkfifo /tmp/mypipe
echo "data" > /tmp/mypipe &
cat /tmp/mypipe
rm /tmp/mypipe

# Pipeline exit status (PIPESTATUS array)
false | true | false
echo "Exit codes: ${PIPESTATUS[@]}"   # 1 0 1

# set -o pipefail makes pipe return the last non-zero exit
set -o pipefail
false | true
echo "Pipeline status: $?"            # 1
```

### `tee` — Write to File and stdout

```bash
# Write output to file AND display it
ls -la | tee directory_listing.txt

# Append mode
echo "log entry" | tee -a logfile.txt

# Write to multiple files
echo "broadcast" | tee file1.txt file2.txt file3.txt

# Use in a pipeline
cat data.txt | sort | tee sorted.txt | head -5
```

---

## 16. Error Handling and Debugging

### Strict Mode

```bash
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
```

What each flag does:

| Flag | Effect |
|------|--------|
| `-e` | Exit immediately on any command failure |
| `-u` | Treat unset variables as errors |
| `-o pipefail` | Pipeline fails if any command in it fails |
| `IFS=$'\n\t'` | Safer word splitting (only on newlines and tabs) |

### Error Handling Patterns

```bash
#!/bin/bash
set -euo pipefail

# Method 1: || with error handler
cd /some/directory || { echo "Failed to cd" >&2; exit 1; }

# Method 2: Custom die function
die() { echo "FATAL: $*" >&2; exit 1; }

[[ -f config.yaml ]] || die "config.yaml not found"

# Method 3: trap on ERR
on_error() {
    local exit_code=$?
    local line_no=$1
    echo "Error on line $line_no (exit code $exit_code)" >&2
}
trap 'on_error $LINENO' ERR

# Method 4: Comprehensive error trap
trap 'echo "Error at $BASH_SOURCE:$LINENO — command \"$BASH_COMMAND\" failed with exit code $?" >&2' ERR
```

### Debugging Techniques

```bash
#!/bin/bash

# Enable debug mode (prints each command before executing)
set -x
echo "This will be traced"
set +x   # Disable debug mode

# Debug specific sections
some_function() {
    local PS4='+ [${FUNCNAME[0]}:${LINENO}] '
    set -x
    # ... commands to debug ...
    set +x
}

# Run entire script in debug mode
# bash -x script.sh

# Print variable state
debug() {
    [[ "${DEBUG:-}" == "1" ]] && echo "DEBUG: $*" >&2
}
debug "var1=$var1, var2=$var2"

# Verbose mode
set -v   # Print lines as read
set +v   # Disable

# Syntax check without execution
# bash -n script.sh
```

### Retry Logic

```bash
#!/bin/bash

retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local attempt=1

    while (( attempt <= max_attempts )); do
        echo "Attempt $attempt/$max_attempts: $*"
        if "$@"; then
            return 0
        fi
        echo "Failed. Waiting ${delay}s before retry..."
        sleep "$delay"
        ((attempt++))
        delay=$((delay * 2))   # Exponential backoff
    done

    echo "All $max_attempts attempts failed" >&2
    return 1
}

retry 3 2 curl -sf "https://api.example.com/health"
```

---

## 17. Signals and Traps

### Common Signals

| Signal | Number | Description |
|--------|--------|-------------|
| `SIGHUP` | 1 | Terminal hangup |
| `SIGINT` | 2 | Interrupt (Ctrl+C) |
| `SIGQUIT` | 3 | Quit (Ctrl+\\) |
| `SIGTERM` | 15 | Termination request |
| `SIGKILL` | 9 | Force kill (cannot be caught) |
| `SIGSTOP` | 19 | Pause (cannot be caught) |
| `SIGUSR1` | 10 | User-defined signal 1 |
| `SIGUSR2` | 12 | User-defined signal 2 |
| `EXIT` | — | Pseudo-signal: script exit |

### Using `trap`

```bash
#!/bin/bash

# Cleanup on exit
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"; echo "Cleaned up $tmpdir"' EXIT

# Handle Ctrl+C gracefully
trap 'echo -e "\nInterrupted! Cleaning up..."; exit 130' INT

# Ignore a signal
trap '' TERM   # Ignore SIGTERM

# Reset to default handler
trap - INT     # Restore default SIGINT behavior

# Multiple traps
cleanup() {
    echo "Removing temp files..."
    rm -f /tmp/myapp_*
}

on_interrupt() {
    echo "Caught SIGINT, shutting down gracefully..."
    cleanup
    exit 130
}

trap cleanup EXIT
trap on_interrupt INT TERM
```

### Practical: Lockfile with Cleanup

```bash
#!/bin/bash

LOCKFILE="/tmp/myapp.lock"

acquire_lock() {
    if ! mkdir "$LOCKFILE" 2>/dev/null; then
        echo "Another instance is already running" >&2
        exit 1
    fi
    trap 'rm -rf "$LOCKFILE"' EXIT
}

acquire_lock
echo "Running with lock..."
sleep 10
echo "Done"
```

---

## 18. Subshells and Process Substitution

### Subshells

A subshell is a child copy of the current shell. Variable changes inside a subshell do not affect the parent.

```bash
#!/bin/bash

var="parent"

# Explicit subshell with ( )
(
    var="child"
    echo "Inside subshell: $var"    # child
)
echo "Outside subshell: $var"       # parent

# Pipes create subshells (important gotcha!)
count=0
echo -e "a\nb\nc" | while read -r line; do
    ((count++))
done
echo "Count: $count"   # 0! (the while loop ran in a subshell)

# Fix: use process substitution instead of pipe
count=0
while read -r line; do
    ((count++))
done < <(echo -e "a\nb\nc")
echo "Count: $count"   # 3
```

### Process Substitution

```bash
# <(...) provides a file-like path to a command's stdout
diff <(sort file1.txt) <(sort file2.txt)

# >(...) provides a file-like path for writing
tee >(gzip > output.gz) >(wc -l > line_count.txt) < input.txt > /dev/null

# Compare two directories
diff <(ls -la /dir1/) <(ls -la /dir2/)

# Multiple processing of the same data
cat data.csv | tee >(awk -F, '{sum+=$2} END {print "Sum:", sum}') \
                    >(wc -l | xargs echo "Lines:") \
                    > /dev/null
```

### Coprocesses (BASH 4.0+)

```bash
#!/bin/bash

# Start a coprocess
coproc BC { bc -l; }

# Send data to the coprocess
echo "scale=4; 22/7" >&${BC[1]}

# Read result from the coprocess
read -r result <&${BC[0]}
echo "22/7 = $result"

# Clean up
echo "quit" >&${BC[1]}
wait $BC_PID
```

---

## 19. Here Documents and Here Strings

### Here Documents

```bash
#!/bin/bash

# Basic here document
cat << EOF
Hello, $USER!
Today is $(date +%A).
Your home directory is $HOME.
EOF

# Quoted delimiter: no variable expansion
cat << 'EOF'
This is literal: $USER $(date)
No expansion happens here.
EOF

# Indented here document (strip leading tabs)
if true; then
    cat <<- EOF
	This line's leading tab is stripped.
	Indentation makes code readable.
	Variables like $USER still expand.
	EOF
fi

# Here document to a command
mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS myapp;
USE myapp;
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100)
);
EOF

# Here document to a variable
read -r -d '' html_template << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Report</title></head>
<body>
<h1>System Report</h1>
</body>
</html>
EOF
echo "$html_template"
```

### Here Strings

```bash
# Feed a string as stdin to a command
grep "hello" <<< "hello world"

# Use with read
read -r first rest <<< "Alice Bob Charlie"
echo "First: $first, Rest: $rest"

# Use with variable
data="field1:field2:field3"
IFS=: read -r a b c <<< "$data"
echo "a=$a b=$b c=$c"

# bc calculation
result=$(bc <<< "scale=2; 100/3")
echo "$result"   # 33.33
```

---

## 20. Advanced Parameter Expansion

### Indirect Expansion

```bash
var_name="greeting"
greeting="Hello, World!"

echo "${!var_name}"   # Hello, World!

# List variables matching a prefix
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="myapp"

for var in "${!DB_@}"; do
    echo "$var = ${!var}"
done
```

### Array Transformations

```bash
# Transform all array elements
files=("file1.txt" "file2.txt" "file3.txt")

# Get all elements with a substitution applied
echo "${files[@]/%.txt/.bak}"   # file1.bak file2.bak file3.bak

# Uppercase all elements
names=("alice" "bob" "charlie")
echo "${names[@]^^}"   # ALICE BOB CHARLIE
```

### Substring and Pattern Operations Summary

```bash
var="Hello.World.Bash.Script"

echo "${var#*.}"     # World.Bash.Script   (remove shortest from start)
echo "${var##*.}"    # Script              (remove longest from start)
echo "${var%.*}"     # Hello.World.Bash    (remove shortest from end)
echo "${var%%.*}"    # Hello               (remove longest from end)

echo "${var:6:5}"    # World               (substring: offset 6, length 5)
echo "${var:6}"      # World.Bash.Script   (substring: offset 6 to end)

echo "${#var}"       # 22                  (length)

echo "${var/World/Earth}"     # Hello.Earth.Bash.Script  (replace first)
echo "${var//./\/}"           # Hello/World/Bash/Script  (replace all)
```

---

## 21. Associative Arrays

Associative arrays (hash maps / dictionaries) are available in BASH 4.0+.

```bash
#!/bin/bash

# Declaration (declare -A is required)
declare -A user
user[name]="Alice"
user[age]=30
user[email]="alice@example.com"

# Alternative declaration
declare -A colors=(
    [red]="#FF0000"
    [green]="#00FF00"
    [blue]="#0000FF"
    [white]="#FFFFFF"
    [black]="#000000"
)

# Accessing values
echo "Name: ${user[name]}"
echo "Red:  ${colors[red]}"

# All keys
echo "Keys: ${!colors[@]}"

# All values
echo "Values: ${colors[@]}"

# Number of elements
echo "Count: ${#colors[@]}"

# Check if key exists
if [[ -v colors[red] ]]; then
    echo "Key 'red' exists"
fi

# Iterate over keys and values
for key in "${!colors[@]}"; do
    echo "$key => ${colors[$key]}"
done

# Delete an entry
unset 'colors[black]'

# Merge two associative arrays
declare -A defaults=(
    [host]="localhost"
    [port]="8080"
    [debug]="false"
)
declare -A overrides=(
    [port]="9090"
    [debug]="true"
)
declare -A config

for key in "${!defaults[@]}"; do
    config[$key]="${defaults[$key]}"
done
for key in "${!overrides[@]}"; do
    config[$key]="${overrides[$key]}"
done

for key in "${!config[@]}"; do
    echo "config[$key] = ${config[$key]}"
done
```

### Practical: Word Frequency Counter

```bash
#!/bin/bash

declare -A word_count

while read -r line; do
    for word in $line; do
        word="${word,,}"                  # Lowercase
        word="${word//[^a-z]/}"           # Remove non-alpha
        [[ -n "$word" ]] && ((word_count[$word]++))
    done
done < "${1:-/dev/stdin}"

for word in "${!word_count[@]}"; do
    printf "%6d %s\n" "${word_count[$word]}" "$word"
done | sort -rn | head -20
```

---

## 22. Command-Line Argument Parsing

### Manual Parsing

```bash
#!/bin/bash

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <input_file>

Options:
    -o, --output FILE    Output file (default: stdout)
    -v, --verbose        Enable verbose output
    -n, --count NUM      Number of items to process
    -h, --help           Show this help message

Example:
    $(basename "$0") -v -n 10 -o results.txt data.csv
EOF
    exit "${1:-0}"
}

verbose=false
output="/dev/stdout"
count=0
input_file=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            output="$2"
            shift 2
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -n|--count)
            count="$2"
            shift 2
            ;;
        -h|--help)
            usage 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage 1
            ;;
        *)
            input_file="$1"
            shift
            ;;
    esac
done

[[ -z "$input_file" ]] && { echo "Error: input file required" >&2; usage 1; }

$verbose && echo "Processing $input_file -> $output (count=$count)"
```

### Using `getopts` (Built-in)

```bash
#!/bin/bash

verbose=false
output=""
count=10

while getopts ":vo:n:h" opt; do
    case "$opt" in
        v) verbose=true ;;
        o) output="$OPTARG" ;;
        n) count="$OPTARG" ;;
        h) echo "Usage: $0 [-v] [-o output] [-n count] file"; exit 0 ;;
        :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

input_file="${1:?Error: input file required}"
echo "Settings: verbose=$verbose output=${output:-stdout} count=$count file=$input_file"
```

---

## 23. Networking with BASH

### HTTP Requests with `curl`

```bash
#!/bin/bash

# GET request
curl -s "https://httpbin.org/get"

# POST request with JSON
curl -s -X POST "https://httpbin.org/post" \
    -H "Content-Type: application/json" \
    -d '{"name": "Alice", "age": 30}'

# Download a file
curl -sLO "https://example.com/file.tar.gz"

# With authentication
curl -s -u "user:password" "https://api.example.com/data"

# Follow redirects, show response headers
curl -sLI "https://example.com"

# Upload a file
curl -s -F "file=@document.pdf" "https://upload.example.com"

# Check HTTP status code
status=$(curl -s -o /dev/null -w "%{http_code}" "https://example.com")
echo "HTTP Status: $status"
```

### TCP Connections with `/dev/tcp`

BASH has built-in TCP/UDP support via special `/dev/tcp` and `/dev/udp` paths:

```bash
#!/bin/bash

# Port check
check_port() {
    local host=$1
    local port=$2
    if (echo > /dev/tcp/"$host"/"$port") 2>/dev/null; then
        echo "$host:$port is OPEN"
    else
        echo "$host:$port is CLOSED"
    fi
}

check_port "localhost" 22
check_port "localhost" 80

# Simple HTTP request using /dev/tcp
exec 3<>/dev/tcp/example.com/80
echo -e "GET / HTTP/1.1\r\nHost: example.com\r\nConnection: close\r\n\r\n" >&3
cat <&3
exec 3>&-
```

### Monitoring URLs

```bash
#!/bin/bash

monitor_urls() {
    local urls=("$@")

    for url in "${urls[@]}"; do
        local start end status duration
        start=$(date +%s%N)
        status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null)
        end=$(date +%s%N)
        duration=$(( (end - start) / 1000000 ))

        if [[ "$status" == "200" ]]; then
            printf "  %-40s %s (%dms)\n" "$url" "OK" "$duration"
        else
            printf "  %-40s %s (HTTP %s)\n" "$url" "FAIL" "$status"
        fi
    done
}

echo "Health Check:"
monitor_urls "https://www.google.com" "https://github.com" "https://httpbin.org/status/503"
```

---

## 24. Performance and Best Practices

### Performance Tips

```bash
#!/bin/bash

# 1. Use built-in string operations instead of external commands
# Slow:
basename=$(echo "/path/to/file.txt" | sed 's/.*\///')
# Fast:
basename="${path##*/}"

# 2. Use [[ ]] instead of [ ] (it's a keyword, not a command)
# Slower:
[ "$a" = "$b" ]
# Faster:
[[ "$a" == "$b" ]]

# 3. Avoid unnecessary subshells
# Slow:
result=$(echo "$var" | tr '[:lower:]' '[:upper:]')
# Fast:
result="${var^^}"

# 4. Read files without cat
# Slow:
content=$(cat file.txt)
# Fast:
content=$(< file.txt)

# 5. Use printf instead of echo for complex output
# Unreliable across platforms:
echo -e "hello\tworld"
# Reliable:
printf "hello\tworld\n"

# 6. Avoid loops for line processing when awk/sed will do
# Slow:
while IFS= read -r line; do
    echo "$line" | grep -q "pattern" && echo "$line"
done < bigfile.txt
# Fast:
grep "pattern" bigfile.txt

# 7. Use mapfile for reading files into arrays
# Slow:
while IFS= read -r line; do
    lines+=("$line")
done < file.txt
# Fast:
mapfile -t lines < file.txt
```

### Best Practices Checklist

1. **Always use `set -euo pipefail`** at the top of scripts
2. **Quote all variables**: `"$var"` not `$var`
3. **Use `[[ ]]`** instead of `[ ]` for conditionals
4. **Use `$(...)` ** instead of backticks for command substitution
5. **Use `local`** for function variables
6. **Check for required commands** before using them
7. **Handle errors** explicitly with traps or `|| die`
8. **Use meaningful variable names**: `file_count` not `fc`
9. **Add a `usage()` function** for scripts with arguments
10. **Use `shellcheck`** to lint your scripts

### Script Template

```bash
#!/usr/bin/env bash
#
# script_name.sh — Brief description of what this script does
#
# Usage: script_name.sh [OPTIONS] <required_arg>
#

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# --- Logging ---
log()   { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
error() { printf '[%s] ERROR: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die()   { error "$@"; exit 1; }

# --- Cleanup ---
cleanup() {
    # Remove temp files, restore state, etc.
    :
}
trap cleanup EXIT

# --- Argument Parsing ---
usage() {
    cat << USAGE
Usage: $SCRIPT_NAME [OPTIONS] <arg>

Options:
    -v, --verbose    Enable verbose output
    -h, --help       Show this help

USAGE
    exit "${1:-0}"
}

verbose=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose) verbose=true; shift ;;
        -h|--help) usage 0 ;;
        --) shift; break ;;
        -*) die "Unknown option: $1" ;;
        *) break ;;
    esac
done

# --- Main Logic ---
main() {
    log "Starting $SCRIPT_NAME"

    # Your code here

    log "Finished successfully"
}

main "$@"
```

---

## 25. Practical Examples

The following practical examples demonstrate real-world uses of BASH scripting. Each one is also available as a standalone script in the `examples/` directory.

---

### Example 1: System Information Reporter

Gathers and displays key system metrics.

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly BOLD='\033[1m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

section() { printf "\n${BOLD}${CYAN}=== %s ===${NC}\n" "$1"; }

section "Hostname & OS"
printf "  Hostname: %s\n" "$(hostname)"
printf "  Kernel:   %s\n" "$(uname -r)"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    printf "  OS:       %s\n" "${PRETTY_NAME:-Unknown}"
fi

section "CPU"
if [[ -f /proc/cpuinfo ]]; then
    model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    cores=$(grep -c '^processor' /proc/cpuinfo)
    printf "  Model:  %s\n" "$model"
    printf "  Cores:  %s\n" "$cores"
fi
printf "  Load:   %s\n" "$(uptime | sed 's/.*load average: //')"

section "Memory"
if command -v free &>/dev/null; then
    free -h | awk '/^Mem:/ {printf "  Total: %s  Used: %s  Free: %s\n", $2, $3, $4}'
fi

section "Disk Usage"
df -h --output=source,size,used,avail,pcent,target 2>/dev/null | \
    grep '^/dev/' | \
    while read -r dev size used avail pct mount; do
        printf "  %-15s %5s used of %5s (%s) on %s\n" "$dev" "$used" "$size" "$pct" "$mount"
    done

section "Network Interfaces"
ip -brief addr show 2>/dev/null | while read -r iface state addrs; do
    printf "  %-12s %-6s %s\n" "$iface" "$state" "$addrs"
done

section "Uptime"
printf "  %s\n" "$(uptime -p 2>/dev/null || uptime)"

section "Top 5 Processes by Memory"
ps aux --sort=-%mem 2>/dev/null | head -6 | \
    awk 'NR==1 {printf "  %-10s %5s %5s %s\n", "USER", "%CPU", "%MEM", "COMMAND"}
         NR>1  {printf "  %-10s %5s %5s %s\n", $1, $3, $4, $11}'
```

---

### Example 2: Automated Backup Script

Creates compressed, timestamped backups with rotation.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
BACKUP_SOURCES=("$HOME/Documents" "$HOME/projects")
BACKUP_DIR="$HOME/backups"
MAX_BACKUPS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}.tar.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }

mkdir -p "$BACKUP_DIR"

log "Starting backup..."

# Build list of existing sources
sources=()
for src in "${BACKUP_SOURCES[@]}"; do
    if [[ -d "$src" ]]; then
        sources+=("$src")
        log "  Including: $src"
    else
        log "  Skipping (not found): $src"
    fi
done

if [[ ${#sources[@]} -eq 0 ]]; then
    log "No valid sources to back up. Exiting."
    exit 1
fi

# Create the backup
log "Creating archive: $BACKUP_NAME"
tar -czf "$BACKUP_DIR/$BACKUP_NAME" "${sources[@]}" 2>/dev/null || true

backup_size=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
log "Backup complete: $BACKUP_NAME ($backup_size)"

# Rotate old backups
backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -name 'backup_*.tar.gz' | wc -l)
if (( backup_count > MAX_BACKUPS )); then
    log "Rotating backups (keeping last $MAX_BACKUPS)..."
    find "$BACKUP_DIR" -maxdepth 1 -name 'backup_*.tar.gz' -printf '%T@ %p\n' | \
        sort -n | head -n -"$MAX_BACKUPS" | cut -d' ' -f2- | \
        while read -r old_backup; do
            log "  Deleting: $(basename "$old_backup")"
            rm -f "$old_backup"
        done
fi

log "Backup process finished."
```

---

### Example 3: Log Analyzer

Parses log files and produces a summary report.

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") <logfile>"
    echo "Analyzes a log file and prints a summary report."
    exit 1
}

[[ $# -lt 1 ]] && usage
logfile="$1"
[[ -f "$logfile" ]] || { echo "File not found: $logfile" >&2; exit 1; }

total_lines=$(wc -l < "$logfile")

declare -A level_count
while IFS= read -r line; do
    for level in ERROR WARN INFO DEBUG; do
        if [[ "$line" == *"$level"* ]]; then
            ((level_count[$level]++)) || true
            break
        fi
    done
done < "$logfile"

echo "===== Log Analysis Report ====="
echo "File:        $logfile"
echo "Total lines: $total_lines"
echo ""
echo "--- Log Level Summary ---"
for level in ERROR WARN INFO DEBUG; do
    count="${level_count[$level]:-0}"
    pct=0
    (( total_lines > 0 )) && pct=$(awk "BEGIN {printf \"%.1f\", ($count/$total_lines)*100}")
    printf "  %-8s %6d  (%s%%)\n" "$level" "$count" "$pct"
done

echo ""
echo "--- Most Recent Errors (last 10) ---"
grep "ERROR" "$logfile" 2>/dev/null | tail -10 | while IFS= read -r line; do
    echo "  $line"
done

echo ""
echo "--- Hourly Distribution ---"
if grep -oP '\d{2}:\d{2}:\d{2}' "$logfile" &>/dev/null; then
    grep -oP '\d{2}(?=:\d{2}:\d{2})' "$logfile" | sort | uniq -c | sort -rn | head -10 | \
        while read -r cnt hour; do
            printf "  %s:00  %d entries\n" "$hour" "$cnt"
        done
else
    echo "  (No timestamp pattern detected)"
fi

echo ""
echo "Report generated at $(date)"
```

---

### Example 4: Bulk File Renamer

Renames files in bulk using patterns, with preview and confirmation.

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <directory>

Rename files in bulk using search/replace patterns.

Options:
    -s, --search PATTERN     Pattern to search for (regex)
    -r, --replace STRING     Replacement string
    -e, --extension EXT      Only process files with this extension
    -d, --dry-run            Preview changes without renaming
    -h, --help               Show this help

Examples:
    $(basename "$0") -s ' ' -r '_' ~/photos
    $(basename "$0") -s 'IMG_' -r 'photo_' -e jpg ~/photos
    $(basename "$0") -d -s '\.jpeg$' -r '.jpg' ~/photos
EOF
    exit "${1:-0}"
}

search=""
replace=""
extension=""
dry_run=false
target_dir=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--search)  search="$2"; shift 2 ;;
        -r|--replace) replace="$2"; shift 2 ;;
        -e|--extension) extension="$2"; shift 2 ;;
        -d|--dry-run) dry_run=true; shift ;;
        -h|--help) usage 0 ;;
        -*) echo "Unknown option: $1" >&2; usage 1 ;;
        *) target_dir="$1"; shift ;;
    esac
done

[[ -z "$search" ]]     && { echo "Error: --search is required" >&2; usage 1; }
[[ -z "$target_dir" ]] && { echo "Error: directory is required" >&2; usage 1; }
[[ -d "$target_dir" ]] || { echo "Error: '$target_dir' is not a directory" >&2; exit 1; }

renamed=0
skipped=0

for filepath in "$target_dir"/*; do
    [[ -f "$filepath" ]] || continue

    filename="$(basename "$filepath")"

    if [[ -n "$extension" && "$filename" != *."$extension" ]]; then
        continue
    fi

    new_name=$(echo "$filename" | sed -E "s/$search/$replace/g")

    if [[ "$new_name" == "$filename" ]]; then
        ((skipped++))
        continue
    fi

    new_path="$target_dir/$new_name"

    if [[ -e "$new_path" ]]; then
        echo "SKIP (target exists): $filename -> $new_name"
        ((skipped++))
        continue
    fi

    if $dry_run; then
        echo "[DRY RUN] $filename -> $new_name"
    else
        mv "$filepath" "$new_path"
        echo "Renamed: $filename -> $new_name"
    fi
    ((renamed++))
done

echo ""
echo "Summary: $renamed renamed, $skipped skipped"
$dry_run && echo "(Dry-run mode — no files were actually changed)"
```

---

### Example 5: Interactive Database Menu (CSV-Based)

A simple CRUD interface for a CSV "database" file.

```bash
#!/usr/bin/env bash
set -euo pipefail

DB_FILE="${1:-contacts.csv}"

init_db() {
    if [[ ! -f "$DB_FILE" ]]; then
        echo "id,name,email,phone" > "$DB_FILE"
        echo "Database initialized: $DB_FILE"
    fi
}

next_id() {
    if [[ $(wc -l < "$DB_FILE") -le 1 ]]; then
        echo 1
    else
        tail -n +2 "$DB_FILE" | cut -d, -f1 | sort -n | tail -1 | awk '{print $1+1}'
    fi
}

list_records() {
    local count
    count=$(( $(wc -l < "$DB_FILE") - 1 ))
    if (( count <= 0 )); then
        echo "No records found."
        return
    fi
    echo ""
    printf "%-5s %-20s %-30s %-15s\n" "ID" "Name" "Email" "Phone"
    printf "%-5s %-20s %-30s %-15s\n" "---" "----" "-----" "-----"
    tail -n +2 "$DB_FILE" | while IFS=, read -r id name email phone; do
        printf "%-5s %-20s %-30s %-15s\n" "$id" "$name" "$email" "$phone"
    done
    echo ""
    echo "Total: $count record(s)"
}

add_record() {
    read -rp "Name:  " name
    read -rp "Email: " email
    read -rp "Phone: " phone
    local id
    id=$(next_id)
    echo "$id,$name,$email,$phone" >> "$DB_FILE"
    echo "Record added (ID: $id)"
}

search_records() {
    read -rp "Search term: " term
    echo ""
    printf "%-5s %-20s %-30s %-15s\n" "ID" "Name" "Email" "Phone"
    printf "%-5s %-20s %-30s %-15s\n" "---" "----" "-----" "-----"
    grep -i "$term" "$DB_FILE" | while IFS=, read -r id name email phone; do
        printf "%-5s %-20s %-30s %-15s\n" "$id" "$name" "$email" "$phone"
    done
}

delete_record() {
    read -rp "Enter ID to delete: " del_id
    if grep -q "^${del_id}," "$DB_FILE"; then
        local tmpfile
        tmpfile=$(mktemp)
        head -1 "$DB_FILE" > "$tmpfile"
        tail -n +2 "$DB_FILE" | grep -v "^${del_id}," >> "$tmpfile"
        mv "$tmpfile" "$DB_FILE"
        echo "Record $del_id deleted."
    else
        echo "Record not found."
    fi
}

init_db

PS3="Choose an action: "
select action in "List" "Add" "Search" "Delete" "Quit"; do
    case "$action" in
        List)   list_records ;;
        Add)    add_record ;;
        Search) search_records ;;
        Delete) delete_record ;;
        Quit)   echo "Goodbye!"; break ;;
        *)      echo "Invalid choice" ;;
    esac
done
```

---

### Example 6: Service Health Monitor with Alerts

Monitors multiple endpoints and reports their status.

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

declare -A ENDPOINTS=(
    [Google]="https://www.google.com"
    [GitHub]="https://github.com"
    [Example]="https://example.com"
)

TIMEOUT=10
LOGFILE="/tmp/health_monitor.log"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"
}

check_endpoint() {
    local name=$1
    local url=$2
    local start end status duration

    start=$(date +%s%N)
    status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))

    local color="$RED"
    local label="DOWN"
    if [[ "$status" =~ ^2 ]]; then
        color="$GREEN"
        label="UP"
    elif [[ "$status" =~ ^3 ]]; then
        color="$YELLOW"
        label="REDIRECT"
    fi

    printf "  ${color}%-12s${NC} %-30s HTTP %-3s  %4dms\n" "[$label]" "$name" "$status" "$duration"
    log "$label $name $url HTTP=$status ${duration}ms"
}

echo "================================"
echo "  Service Health Monitor"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================"
echo ""

for name in "${!ENDPOINTS[@]}"; do
    check_endpoint "$name" "${ENDPOINTS[$name]}"
done

echo ""
echo "Log: $LOGFILE"
```

---

### Example 7: Git Repository Statistics

Generates statistics for a Git repository.

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: not inside a Git repository" >&2
    exit 1
fi

repo_name=$(basename "$(git rev-parse --show-toplevel)")
branch=$(git branch --show-current 2>/dev/null || echo "detached")
total_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
first_commit=$(git log --reverse --format='%ai' 2>/dev/null | head -1)
latest_commit=$(git log -1 --format='%ai' 2>/dev/null)

echo "======================================="
echo "  Git Repository Statistics"
echo "======================================="
echo ""
echo "Repository:    $repo_name"
echo "Branch:        $branch"
echo "Total commits: $total_commits"
echo "First commit:  ${first_commit:-N/A}"
echo "Latest commit: ${latest_commit:-N/A}"

echo ""
echo "--- Top 10 Contributors ---"
git shortlog -sn --no-merges HEAD 2>/dev/null | head -10 | while read -r count author; do
    printf "  %4d  %s\n" "$count" "$author"
done

echo ""
echo "--- Commits by Day of Week ---"
git log --format='%ad' --date=format:'%A' 2>/dev/null | sort | uniq -c | sort -rn | \
    while read -r count day; do
        printf "  %-12s %d\n" "$day" "$count"
    done

echo ""
echo "--- File Type Distribution ---"
git ls-files 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15 | \
    while read -r count ext; do
        printf "  %-12s %d files\n" ".$ext" "$count"
    done

echo ""
echo "--- Recent Activity (last 10 commits) ---"
git log --oneline --format='  %h  %an  %s' -10 2>/dev/null

echo ""
echo "Report generated: $(date)"
```

---

### Example 8: Configuration File Parser

Parses INI-style configuration files into BASH variables.

```bash
#!/usr/bin/env bash
set -euo pipefail

parse_ini() {
    local ini_file=$1
    local current_section=""

    [[ -f "$ini_file" ]] || { echo "File not found: $ini_file" >&2; return 1; }

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"       # Remove comments
        line="${line%%";'*}"     # Remove inline comments
        line="${line#"${line%%[![:space:]]*}"}"   # Trim leading whitespace
        line="${line%"${line##*[![:space:]]}"}"   # Trim trailing whitespace

        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^\[([a-zA-Z0-9_]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            value="${value%\"}"
            value="${value#\"}"

            local var_name
            if [[ -n "$current_section" ]]; then
                var_name="${current_section}__${key}"
            else
                var_name="$key"
            fi

            declare -g "$var_name=$value"
        fi
    done < "$ini_file"
}

# Example usage with inline config
config_file=$(mktemp)
cat > "$config_file" << 'EOF'
# Application Configuration

[database]
host = localhost
port = 5432
name = myapp_db
user = admin

[server]
host = 0.0.0.0
port = 8080
workers = 4
debug = false

[logging]
level = INFO
file = /var/log/myapp.log
EOF

parse_ini "$config_file"

echo "Database: ${database__user}@${database__host}:${database__port}/${database__name}"
echo "Server:   ${server__host}:${server__port} (${server__workers} workers, debug=${server__debug})"
echo "Logging:  level=${logging__level}, file=${logging__file}"

rm -f "$config_file"
```

---

## Quick Reference Card

### Frequently Used One-Liners

```bash
# Find files modified in the last 24 hours
find /path -type f -mtime -1

# Count lines of code in a project (excluding blanks and comments)
find . -name '*.sh' -exec grep -cve '^\s*$' -e '^\s*#' {} + | awk -F: '{s+=$2} END {print s}'

# Watch a log file in real time
tail -f /var/log/syslog

# Find and kill a process by name
pkill -f "process_name"

# Replace text in all files recursively
find . -type f -name '*.txt' -exec sed -i 's/old/new/g' {} +

# Parallel download with curl
xargs -P 4 -I {} curl -sLO {} < url_list.txt

# Create a quick HTTP server (Python)
python3 -m http.server 8080

# Monitor disk usage of a directory
watch -n 5 'du -sh /path/to/dir'

# Quick CSV column extraction
cut -d',' -f2,4 data.csv

# Sort and deduplicate
sort -u file.txt

# Calculate file checksums
sha256sum *.tar.gz > checksums.txt

# Archive with progress
tar cf - /source/dir | pv | gzip > backup.tar.gz

# Test internet speed (download)
curl -o /dev/null -w "Speed: %{speed_download} bytes/sec\n" https://speed.hetzner.de/100MB.bin

# Generate a random password
openssl rand -base64 16

# List open ports
ss -tlnp
```

### Keyboard Shortcuts (Interactive Shell)

| Shortcut | Action |
|----------|--------|
| `Ctrl+C` | Interrupt current command |
| `Ctrl+D` | End of input / logout |
| `Ctrl+Z` | Suspend current process |
| `Ctrl+L` | Clear the screen |
| `Ctrl+R` | Reverse search history |
| `Ctrl+A` | Move cursor to start of line |
| `Ctrl+E` | Move cursor to end of line |
| `Ctrl+U` | Delete from cursor to start of line |
| `Ctrl+K` | Delete from cursor to end of line |
| `Ctrl+W` | Delete previous word |
| `Alt+.` | Insert last argument of previous command |
| `!!` | Repeat last command |
| `!$` | Last argument of previous command |
| `!^` | First argument of previous command |

---

## Further Reading

- **Official BASH Manual**: `man bash` or [GNU BASH Reference](https://www.gnu.org/software/bash/manual/)
- **Advanced Bash-Scripting Guide**: [tldp.org/LDP/abs](https://tldp.org/LDP/abs/html/)
- **ShellCheck**: [shellcheck.net](https://www.shellcheck.net/) — Static analysis for shell scripts
- **Bash Hackers Wiki**: [wiki.bash-hackers.org](https://wiki.bash-hackers.org/)
- **Google Shell Style Guide**: [google.github.io/styleguide/shellguide](https://google.github.io/styleguide/shellguide.html)
