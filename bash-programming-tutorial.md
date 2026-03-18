# Comprehensive BASH Programming Tutorial

## Table of Contents

1. [Introduction to Bash](#1-introduction-to-bash)
2. [Getting Started](#2-getting-started)
3. [Variables](#3-variables)
4. [User Input](#4-user-input)
5. [Operators](#5-operators)
6. [Conditional Statements](#6-conditional-statements)
7. [Loops](#7-loops)
8. [Functions](#8-functions)
9. [Arrays](#9-arrays)
10. [String Manipulation](#10-string-manipulation)
11. [File and Directory Operations](#11-file-and-directory-operations)
12. [Input/Output Redirection and Pipes](#12-inputoutput-redirection-and-pipes)
13. [Command Substitution and Process Substitution](#13-command-substitution-and-process-substitution)
14. [Here Documents and Here Strings](#14-here-documents-and-here-strings)
15. [Regular Expressions and Pattern Matching](#15-regular-expressions-and-pattern-matching)
16. [Error Handling and Debugging](#16-error-handling-and-debugging)
17. [Signal Handling with `trap`](#17-signal-handling-with-trap)
18. [Subshells and Command Grouping](#18-subshells-and-command-grouping)
19. [Best Practices](#19-best-practices)
20. [Practical Examples](#20-practical-examples)

---

## 1. Introduction to Bash

**Bash** (Bourne Again SHell) is a command-line interpreter and scripting language for Unix-like operating systems. It is the default shell on most Linux distributions and macOS (prior to Catalina). Bash extends the original Bourne Shell (`sh`) with features from the Korn Shell (`ksh`) and C Shell (`csh`).

### Why Learn Bash?

- **Automation**: Automate repetitive tasks such as backups, deployments, and system monitoring.
- **System Administration**: Manage users, processes, services, and filesystems.
- **DevOps Pipelines**: Write CI/CD scripts, container entry points, and infrastructure automation.
- **Portability**: Bash is available on virtually every Unix/Linux system.
- **Glue Language**: Combine powerful command-line tools into cohesive workflows.

### Bash vs Other Shells

| Feature | Bash | Zsh | Fish | Dash |
|---------|------|-----|------|------|
| POSIX-compliant | Mostly | Mostly | No | Yes |
| Interactive features | Good | Excellent | Excellent | Minimal |
| Scripting power | Excellent | Excellent | Good | Basic |
| Startup speed | Fast | Moderate | Moderate | Very fast |
| Default on Linux | Yes (most) | No | No | Some (as `/bin/sh`) |

---

## 2. Getting Started

### The Shebang Line

Every Bash script should begin with a **shebang** (`#!`) that tells the system which interpreter to use:

```bash
#!/bin/bash
```

For better portability across systems where Bash may be installed in different locations:

```bash
#!/usr/bin/env bash
```

### Creating and Running Your First Script

**Step 1**: Create a file called `hello.sh`:

```bash
#!/usr/bin/env bash
echo "Hello, World!"
```

**Step 2**: Make it executable:

```bash
chmod +x hello.sh
```

**Step 3**: Run the script:

```bash
./hello.sh
```

You can also run a script without making it executable:

```bash
bash hello.sh
```

### Script File Conventions

- Use the `.sh` extension (optional but conventional).
- Use lowercase with hyphens or underscores for filenames: `backup-database.sh`, `deploy_app.sh`.
- Always include the shebang line.
- Set appropriate permissions (`chmod 700` for private scripts, `chmod 755` for shared ones).

### Comments

```bash
# This is a single-line comment

: '
This is a
multi-line comment
using the colon-space-quote idiom.
'
```

---

## 3. Variables

### Declaring Variables

Bash variables are untyped by default (treated as strings). **No spaces** around the `=` sign:

```bash
#!/usr/bin/env bash

name="Alice"
age=30
pi=3.14159

echo "Name: $name"
echo "Age: $age"
echo "Pi: $pi"
```

### Variable Naming Rules

- Must start with a letter or underscore.
- Can contain letters, digits, and underscores.
- Case-sensitive (`Name` and `name` are different).
- Convention: lowercase for local variables, UPPERCASE for environment/exported variables.

### Quoting

Quoting controls how the shell interprets special characters:

```bash
#!/usr/bin/env bash

name="World"

# Double quotes: variables ARE expanded
echo "Hello, $name"          # Hello, World

# Single quotes: variables are NOT expanded (literal)
echo 'Hello, $name'          # Hello, $name

# Backticks or $(): command substitution
echo "Today is $(date +%A)"  # Today is Wednesday

# Escape character
echo "The price is \$5.00"   # The price is $5.00
```

### Variable Scope and `export`

By default, variables are local to the current shell. Use `export` to make them available to child processes:

```bash
#!/usr/bin/env bash

local_var="I'm local"
export global_var="I'm exported"

# Child process can see global_var but NOT local_var
bash -c 'echo "global_var=$global_var, local_var=$local_var"'
# Output: global_var=I'm exported, local_var=
```

### Read-Only Variables

```bash
#!/usr/bin/env bash

readonly DB_HOST="localhost"
DB_HOST="remotehost"  # Error: DB_HOST: readonly variable
```

### Special Variables

| Variable | Description |
|----------|-------------|
| `$0` | Name of the script |
| `$1` to `$9` | Positional parameters (arguments) |
| `${10}` | 10th argument (braces required for 10+) |
| `$#` | Number of arguments |
| `$@` | All arguments as separate words |
| `$*` | All arguments as a single word |
| `$?` | Exit status of the last command |
| `$$` | PID of the current script |
| `$!` | PID of the last background process |
| `$_` | Last argument of the previous command |

```bash
#!/usr/bin/env bash

echo "Script name: $0"
echo "First argument: $1"
echo "All arguments: $@"
echo "Number of arguments: $#"
echo "Script PID: $$"
```

### Parameter Expansion

Bash provides powerful parameter expansion features:

```bash
#!/usr/bin/env bash

name="Bash Programming"

# Length of a variable
echo "${#name}"               # 16

# Default values
echo "${undefined_var:-default_value}"   # default_value (use default)
echo "${undefined_var:=default_value}"   # default_value (assign default)

# Substring extraction
echo "${name:0:4}"            # Bash (from position 0, length 4)
echo "${name:5}"              # Programming (from position 5 to end)

# Substitution
filepath="/home/user/docs/report.txt"
echo "${filepath%.txt}"       # /home/user/docs/report  (remove shortest suffix)
echo "${filepath%/*}"         # /home/user/docs         (directory part)
echo "${filepath##*/}"        # report.txt              (filename part)
echo "${filepath#*/}"         # home/user/docs/report.txt (remove shortest prefix)

# Pattern replacement
echo "${name/Programming/Scripting}"   # Bash Scripting (replace first)
echo "${name// /_}"                    # Bash_Programming (replace all spaces)

# Case conversion (Bash 4+)
echo "${name^^}"              # BASH PROGRAMMING (uppercase)
echo "${name,,}"              # bash programming (lowercase)
```

---

## 4. User Input

### Reading Input with `read`

```bash
#!/usr/bin/env bash

read -p "Enter your name: " username
echo "Hello, $username!"

# Read with a timeout (5 seconds)
read -t 5 -p "Quick! Enter a number: " num

# Silent input (for passwords)
read -s -p "Enter password: " password
echo  # newline after silent input
echo "Password accepted (length: ${#password})"

# Read into multiple variables
echo "Enter first and last name:"
read first last
echo "First: $first, Last: $last"

# Read with a default value
read -p "Enter shell [bash]: " shell
shell="${shell:-bash}"
echo "Selected shell: $shell"
```

### Reading a File Line by Line

```bash
#!/usr/bin/env bash

while IFS= read -r line; do
    echo "Line: $line"
done < "input.txt"
```

### The `select` Menu

```bash
#!/usr/bin/env bash

PS3="Choose a color: "
select color in Red Green Blue Quit; do
    case $color in
        Red)   echo "You chose red.";;
        Green) echo "You chose green.";;
        Blue)  echo "You chose blue.";;
        Quit)  echo "Goodbye!"; break;;
        *)     echo "Invalid option.";;
    esac
done
```

---

## 5. Operators

### Arithmetic Operators

Bash supports integer arithmetic using `(( ))` or `let`:

```bash
#!/usr/bin/env bash

a=15
b=4

echo "a + b = $(( a + b ))"     # 19
echo "a - b = $(( a - b ))"     # 11
echo "a * b = $(( a * b ))"     # 60
echo "a / b = $(( a / b ))"     # 3  (integer division)
echo "a % b = $(( a % b ))"     # 3  (modulus)
echo "a ** 2 = $(( a ** 2 ))"   # 225 (exponentiation)

# Increment and decrement
(( a++ ))
echo "After a++: $a"            # 16
(( b-- ))
echo "After b--: $b"            # 3

# Compound assignment
(( a += 10 ))
echo "After a += 10: $a"        # 26
```

For floating-point arithmetic, use `bc` or `awk`:

```bash
#!/usr/bin/env bash

result=$(echo "scale=2; 10 / 3" | bc)
echo "10 / 3 = $result"         # 3.33

result=$(awk "BEGIN {printf \"%.4f\", 22/7}")
echo "22 / 7 = $result"         # 3.1429
```

### Comparison Operators

#### Integer Comparison (inside `[[ ]]` or `[ ]`)

| Operator | Meaning |
|----------|---------|
| `-eq` | Equal |
| `-ne` | Not equal |
| `-gt` | Greater than |
| `-ge` | Greater or equal |
| `-lt` | Less than |
| `-le` | Less or equal |

```bash
#!/usr/bin/env bash

x=10
y=20

if [[ $x -lt $y ]]; then
    echo "$x is less than $y"
fi
```

#### Integer Comparison (inside `(( ))`)

Inside arithmetic evaluation, you can use C-style operators:

```bash
#!/usr/bin/env bash

x=10
y=20

if (( x < y )); then
    echo "$x is less than $y"
fi

if (( x == 10 && y == 20 )); then
    echo "Both conditions are true"
fi
```

#### String Comparison

| Operator | Meaning |
|----------|---------|
| `==` or `=` | Equal |
| `!=` | Not equal |
| `<` | Lexicographically less than |
| `>` | Lexicographically greater than |
| `-z` | String is empty |
| `-n` | String is non-empty |

```bash
#!/usr/bin/env bash

str1="hello"
str2="world"

if [[ "$str1" == "$str2" ]]; then
    echo "Strings are equal"
else
    echo "Strings are not equal"
fi

if [[ -z "$empty_var" ]]; then
    echo "Variable is empty or unset"
fi

if [[ -n "$str1" ]]; then
    echo "str1 is non-empty"
fi
```

### File Test Operators

| Operator | Meaning |
|----------|---------|
| `-e file` | File exists |
| `-f file` | Regular file exists |
| `-d dir` | Directory exists |
| `-r file` | File is readable |
| `-w file` | File is writable |
| `-x file` | File is executable |
| `-s file` | File is non-empty |
| `-L file` | File is a symbolic link |
| `-nt` | File is newer than |
| `-ot` | File is older than |

```bash
#!/usr/bin/env bash

if [[ -f "/etc/passwd" ]]; then
    echo "/etc/passwd exists and is a regular file"
fi

if [[ -d "$HOME" ]]; then
    echo "Home directory exists"
fi

if [[ -r "/etc/passwd" && -s "/etc/passwd" ]]; then
    echo "/etc/passwd is readable and non-empty"
fi
```

### Logical Operators

```bash
#!/usr/bin/env bash

age=25
name="Alice"

# AND: && (inside [[ ]]) or -a (inside [ ])
if [[ $age -gt 18 && "$name" == "Alice" ]]; then
    echo "Alice is an adult"
fi

# OR: || (inside [[ ]]) or -o (inside [ ])
if [[ $age -lt 13 || $age -gt 19 ]]; then
    echo "Not a teenager"
fi

# NOT: !
if [[ ! -f "/nonexistent" ]]; then
    echo "File does not exist"
fi
```

---

## 6. Conditional Statements

### `if` / `elif` / `else`

```bash
#!/usr/bin/env bash

score=75

if [[ $score -ge 90 ]]; then
    grade="A"
elif [[ $score -ge 80 ]]; then
    grade="B"
elif [[ $score -ge 70 ]]; then
    grade="C"
elif [[ $score -ge 60 ]]; then
    grade="D"
else
    grade="F"
fi

echo "Score: $score, Grade: $grade"
```

### `[[ ]]` vs `[ ]`

`[[ ]]` is a Bash built-in with several advantages over `[ ]`:

```bash
#!/usr/bin/env bash

file="my file.txt"

# [[ ]] handles word splitting automatically (no quoting needed, but recommended)
if [[ -f $file ]]; then
    echo "Found"
fi

# [[ ]] supports pattern matching
if [[ "hello123" == hello* ]]; then
    echo "Starts with hello"
fi

# [[ ]] supports regex matching
if [[ "user@example.com" =~ ^[a-zA-Z]+@[a-zA-Z]+\.[a-zA-Z]+$ ]]; then
    echo "Valid email format"
fi
```

### `case` Statement

The `case` statement is ideal for matching a value against multiple patterns:

```bash
#!/usr/bin/env bash

read -p "Enter a fruit: " fruit

case "$fruit" in
    apple|Apple)
        echo "Apples are \$2/kg"
        ;;
    banana|Banana)
        echo "Bananas are \$1/kg"
        ;;
    orange|Orange)
        echo "Oranges are \$3/kg"
        ;;
    *)
        echo "Unknown fruit: $fruit"
        ;;
esac
```

### Ternary-Style Expressions

Bash doesn't have a ternary operator, but you can emulate it:

```bash
#!/usr/bin/env bash

age=20

# Using && and ||
[[ $age -ge 18 ]] && status="adult" || status="minor"
echo "Status: $status"

# Using arithmetic ternary
max=$(( a > b ? a : b ))
```

---

## 7. Loops

### `for` Loop

```bash
#!/usr/bin/env bash

# Iterating over a list
for fruit in apple banana cherry; do
    echo "I like $fruit"
done

# C-style for loop
for (( i = 0; i < 5; i++ )); do
    echo "Iteration $i"
done

# Iterating over a range
for i in {1..10}; do
    echo "Number: $i"
done

# Range with step
for i in {0..100..10}; do
    echo "Value: $i"
done

# Iterating over files
for file in *.sh; do
    echo "Script: $file"
done

# Iterating over command output
for user in $(cut -d: -f1 /etc/passwd | head -5); do
    echo "User: $user"
done
```

### `while` Loop

```bash
#!/usr/bin/env bash

# Basic while loop
count=1
while [[ $count -le 5 ]]; do
    echo "Count: $count"
    (( count++ ))
done

# Infinite loop with break
while true; do
    read -p "Enter 'quit' to exit: " input
    if [[ "$input" == "quit" ]]; then
        break
    fi
    echo "You entered: $input"
done

# Reading a file line by line
while IFS= read -r line; do
    echo ">> $line"
done < /etc/hostname
```

### `until` Loop

The `until` loop runs **until** the condition becomes true (opposite of `while`):

```bash
#!/usr/bin/env bash

count=1
until [[ $count -gt 5 ]]; do
    echo "Count: $count"
    (( count++ ))
done
```

### Loop Control: `break` and `continue`

```bash
#!/usr/bin/env bash

# break: exit the loop entirely
for i in {1..10}; do
    if [[ $i -eq 6 ]]; then
        echo "Breaking at $i"
        break
    fi
    echo "i = $i"
done

# continue: skip to the next iteration
for i in {1..10}; do
    if (( i % 2 == 0 )); then
        continue
    fi
    echo "Odd: $i"
done

# Breaking out of nested loops (break N)
for i in {1..3}; do
    for j in {1..3}; do
        if [[ $i -eq 2 && $j -eq 2 ]]; then
            break 2  # break out of both loops
        fi
        echo "i=$i, j=$j"
    done
done
```

---

## 8. Functions

### Defining and Calling Functions

```bash
#!/usr/bin/env bash

# Method 1: using the function keyword
function greet {
    echo "Hello, $1!"
}

# Method 2: without the function keyword (POSIX-compatible)
say_goodbye() {
    echo "Goodbye, $1!"
}

greet "Alice"       # Hello, Alice!
say_goodbye "Bob"   # Goodbye, Bob!
```

### Function Arguments

Functions receive arguments via positional parameters, just like scripts:

```bash
#!/usr/bin/env bash

calculate() {
    local op="$1"
    local a="$2"
    local b="$3"

    case "$op" in
        add) echo $(( a + b )) ;;
        sub) echo $(( a - b )) ;;
        mul) echo $(( a * b )) ;;
        div)
            if [[ $b -eq 0 ]]; then
                echo "Error: division by zero" >&2
                return 1
            fi
            echo $(( a / b ))
            ;;
        *) echo "Unknown operation: $op" >&2; return 1 ;;
    esac
}

result=$(calculate add 10 5)
echo "10 + 5 = $result"

result=$(calculate div 20 4)
echo "20 / 4 = $result"
```

### Return Values

Functions can return an exit status (0-255) with `return`. To return data, use `echo` and capture with command substitution:

```bash
#!/usr/bin/env bash

# Returning exit status
is_even() {
    (( $1 % 2 == 0 ))   # implicit return of the expression result
}

if is_even 42; then
    echo "42 is even"
fi

# Returning data via stdout
get_hostname() {
    hostname
}

my_host=$(get_hostname)
echo "Hostname: $my_host"
```

### Local Variables

Use `local` to prevent variable leakage into the caller's scope:

```bash
#!/usr/bin/env bash

outer_function() {
    local message="I'm local to outer_function"
    echo "$message"
}

outer_function
echo "Outside: ${message:-variable not accessible}"
```

### Recursive Functions

```bash
#!/usr/bin/env bash

factorial() {
    local n=$1
    if (( n <= 1 )); then
        echo 1
    else
        local sub
        sub=$(factorial $(( n - 1 )))
        echo $(( n * sub ))
    fi
}

echo "5! = $(factorial 5)"   # 120
echo "10! = $(factorial 10)" # 3628800
```

---

## 9. Arrays

### Indexed Arrays

```bash
#!/usr/bin/env bash

# Declaration
fruits=("apple" "banana" "cherry" "date")

# Accessing elements (0-indexed)
echo "First: ${fruits[0]}"      # apple
echo "Third: ${fruits[2]}"      # cherry

# All elements
echo "All: ${fruits[@]}"

# Number of elements
echo "Count: ${#fruits[@]}"

# Length of a specific element
echo "Length of first element: ${#fruits[0]}"

# Adding elements
fruits+=("elderberry")

# Modifying elements
fruits[1]="blueberry"

# Removing elements
unset 'fruits[3]'

# Iterating
for fruit in "${fruits[@]}"; do
    echo "  - $fruit"
done

# Iterating with indices
for i in "${!fruits[@]}"; do
    echo "  [$i] = ${fruits[$i]}"
done

# Slicing
echo "Slice: ${fruits[@]:1:2}"  # elements at index 1 and 2
```

### Associative Arrays (Bash 4+)

```bash
#!/usr/bin/env bash

declare -A user
user[name]="Alice"
user[age]=30
user[email]="alice@example.com"

echo "Name: ${user[name]}"
echo "Age: ${user[age]}"

# All keys
echo "Keys: ${!user[@]}"

# All values
echo "Values: ${user[@]}"

# Check if key exists
if [[ -v user[name] ]]; then
    echo "Key 'name' exists"
fi

# Iterate over associative array
for key in "${!user[@]}"; do
    echo "  $key = ${user[$key]}"
done

# Declare with initial values
declare -A colors=(
    [red]="#FF0000"
    [green]="#00FF00"
    [blue]="#0000FF"
)
```

### Array Operations

```bash
#!/usr/bin/env bash

arr=(5 3 8 1 9 2 7 4 6)

# Sort an array (using external tools)
sorted=($(printf '%s\n' "${arr[@]}" | sort -n))
echo "Sorted: ${sorted[@]}"

# Reverse an array
reversed=()
for (( i = ${#arr[@]} - 1; i >= 0; i-- )); do
    reversed+=("${arr[$i]}")
done
echo "Reversed: ${reversed[@]}"

# Search in array
search="8"
for element in "${arr[@]}"; do
    if [[ "$element" == "$search" ]]; then
        echo "Found $search in array"
        break
    fi
done

# Join array elements with a delimiter
join_by() {
    local IFS="$1"
    shift
    echo "$*"
}
echo "Joined: $(join_by ', ' "${arr[@]}")"
```

---

## 10. String Manipulation

```bash
#!/usr/bin/env bash

str="Hello, World! Welcome to Bash Programming."

# String length
echo "Length: ${#str}"

# Substring
echo "Substring: ${str:7:5}"           # World

# Find and replace
echo "Replace first: ${str/World/Earth}"
echo "Replace all:   ${str// /_}"

# Remove pattern from beginning
path="/home/user/documents/file.tar.gz"
echo "Remove prefix: ${path#*/}"        # home/user/documents/file.tar.gz
echo "Remove longest prefix: ${path##*/}"  # file.tar.gz

# Remove pattern from end
echo "Remove suffix: ${path%.*}"        # /home/user/documents/file.tar
echo "Remove longest suffix: ${path%%.*}" # /home/user/documents/file

# Case conversion (Bash 4+)
echo "Uppercase: ${str^^}"
echo "Lowercase: ${str,,}"
echo "Capitalize first: ${str^}"

# Check if string contains substring
if [[ "$str" == *"Bash"* ]]; then
    echo "String contains 'Bash'"
fi

# String concatenation
first="Hello"
second="World"
combined="${first} ${second}!"
echo "$combined"

# Split string into array
IFS=',' read -ra parts <<< "one,two,three,four"
for part in "${parts[@]}"; do
    echo "  Part: $part"
done

# Trim whitespace
trimmed="   hello world   "
trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"   # trim leading
trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"   # trim trailing
echo "Trimmed: '$trimmed'"
```

---

## 11. File and Directory Operations

### Testing Files

```bash
#!/usr/bin/env bash

file="/etc/passwd"

[[ -e "$file" ]] && echo "Exists"
[[ -f "$file" ]] && echo "Is a regular file"
[[ -d "$file" ]] && echo "Is a directory"        # false for /etc/passwd
[[ -r "$file" ]] && echo "Is readable"
[[ -w "$file" ]] && echo "Is writable"
[[ -x "$file" ]] && echo "Is executable"
[[ -s "$file" ]] && echo "Is non-empty"
[[ -L "$file" ]] && echo "Is a symbolic link"
```

### Reading Files

```bash
#!/usr/bin/env bash

# Read entire file into a variable
content=$(<"/etc/hostname")
echo "Content: $content"

# Read file line by line
while IFS= read -r line; do
    echo "Line: $line"
done < "/etc/hostname"

# Read file into an array (one element per line)
mapfile -t lines < "/etc/hostname"
echo "First line: ${lines[0]}"
echo "Total lines: ${#lines[@]}"
```

### Writing Files

```bash
#!/usr/bin/env bash

# Overwrite a file
echo "First line" > /tmp/output.txt

# Append to a file
echo "Second line" >> /tmp/output.txt

# Write multiple lines
cat > /tmp/config.txt << 'EOF'
host=localhost
port=8080
debug=true
EOF

# Write using tee (also displays on stdout)
echo "Logged message" | tee /tmp/log.txt

# Append using tee
echo "Another message" | tee -a /tmp/log.txt
```

### Working with Directories

```bash
#!/usr/bin/env bash

# Create directories (including parents)
mkdir -p /tmp/project/{src,bin,docs,tests}

# Change directory and return
pushd /tmp/project > /dev/null
echo "Now in: $(pwd)"
popd > /dev/null
echo "Back to: $(pwd)"

# Find files recursively
find /tmp/project -type f -name "*.txt" 2>/dev/null

# Get absolute path of a file
realpath ./relative/path 2>/dev/null
```

### Temporary Files and Directories

```bash
#!/usr/bin/env bash

# Create a secure temporary file
tmpfile=$(mktemp)
echo "Temp file: $tmpfile"
echo "Some data" > "$tmpfile"

# Create a secure temporary directory
tmpdir=$(mktemp -d)
echo "Temp dir: $tmpdir"

# Clean up on exit
trap 'rm -rf "$tmpfile" "$tmpdir"' EXIT
```

---

## 12. Input/Output Redirection and Pipes

### File Descriptors

| FD | Name | Default |
|----|------|---------|
| 0 | stdin | Keyboard |
| 1 | stdout | Terminal |
| 2 | stderr | Terminal |

### Redirection

```bash
#!/usr/bin/env bash

# Redirect stdout to a file
ls -la > listing.txt

# Redirect stderr to a file
ls /nonexistent 2> errors.txt

# Redirect both stdout and stderr
command > output.txt 2>&1

# Modern syntax (Bash 4+)
command &> output.txt

# Redirect stdout and stderr to different files
command > stdout.txt 2> stderr.txt

# Discard output
command > /dev/null 2>&1

# Redirect stdin from a file
sort < unsorted.txt

# Append instead of overwrite
echo "new line" >> existing.txt
```

### Custom File Descriptors

```bash
#!/usr/bin/env bash

# Open FD 3 for writing
exec 3> /tmp/custom_log.txt

echo "This goes to the terminal"
echo "This goes to the log" >&3
echo "This also goes to the terminal"
echo "This also goes to the log" >&3

# Close FD 3
exec 3>&-

# Open FD 4 for reading
exec 4< /etc/hostname
read -r hostname_line <&4
echo "Read from FD 4: $hostname_line"
exec 4<&-
```

### Pipes

Pipes connect the stdout of one command to the stdin of another:

```bash
#!/usr/bin/env bash

# Basic pipe
ls -la | grep ".txt"

# Multiple pipes
cat /etc/passwd | cut -d: -f1 | sort | head -10

# Named pipes (FIFOs)
mkfifo /tmp/mypipe
echo "Hello through the pipe" > /tmp/mypipe &
cat /tmp/mypipe
rm /tmp/mypipe
```

### `tee` - Split Output

```bash
#!/usr/bin/env bash

# Write to both stdout and a file
ls -la | tee listing.txt

# Append to the file
ls -la | tee -a listing.txt

# Write to multiple files
echo "broadcast" | tee file1.txt file2.txt file3.txt
```

---

## 13. Command Substitution and Process Substitution

### Command Substitution

Captures the output of a command and uses it as a value:

```bash
#!/usr/bin/env bash

# Modern syntax (preferred)
current_date=$(date +%Y-%m-%d)
echo "Today: $current_date"

num_files=$(ls | wc -l)
echo "Files in current directory: $num_files"

# Nested command substitution
echo "Home dir size: $(du -sh "$(eval echo ~)" 2>/dev/null | cut -f1)"

# Legacy syntax (backticks) — avoid in new code
current_date=`date +%Y-%m-%d`
```

### Process Substitution

Treats command output as a file, which is useful for commands that expect filenames:

```bash
#!/usr/bin/env bash

# Compare output of two commands
diff <(ls /usr/bin) <(ls /usr/sbin) | head -20

# Feed command output as a file to another command
while IFS= read -r line; do
    echo "Process: $line"
done < <(ps aux | head -5)

# Sort and compare two unsorted files without modifying them
comm <(sort file1.txt) <(sort file2.txt)
```

---

## 14. Here Documents and Here Strings

### Here Documents

A here document feeds a block of text to a command:

```bash
#!/usr/bin/env bash

# Basic here document
cat << EOF
Welcome to the system!
Today is $(date).
Your home directory is $HOME.
EOF

# Indented here document (<<- strips leading tabs)
if true; then
	cat <<- EOF
	This text can be indented with tabs.
	The leading tabs are stripped.
	EOF
fi

# Literal here document (no variable expansion)
cat << 'EOF'
Variables like $HOME are NOT expanded here.
Neither is $(date) or `command`.
EOF
```

### Here Strings

A here string feeds a single string to a command's stdin:

```bash
#!/usr/bin/env bash

# Instead of: echo "Hello World" | grep "World"
grep "World" <<< "Hello World"

# Parse a string
read -r first second third <<< "one two three"
echo "First: $first, Second: $second, Third: $third"

# Feed a variable to a command
data="5 + 3"
result=$(bc <<< "$data")
echo "$data = $result"
```

---

## 15. Regular Expressions and Pattern Matching

### Glob Patterns

Glob patterns are used for filename matching:

```bash
#!/usr/bin/env bash

# * matches any string
ls *.txt

# ? matches any single character
ls file?.txt

# [abc] matches any character in the set
ls file[123].txt

# [a-z] matches a range
ls file[a-z].txt

# Extended globs (enable with shopt)
shopt -s extglob

# ?(pattern) - matches zero or one occurrence
ls file?(s).txt

# *(pattern) - matches zero or more occurrences
ls *(file|doc)*.txt

# +(pattern) - matches one or more occurrences
ls +(file)*.txt

# @(pattern) - matches exactly one occurrence
ls @(file|doc).txt

# !(pattern) - matches anything except the pattern
ls !(*.txt)
```

### Regular Expressions with `=~`

```bash
#!/usr/bin/env bash

# Email validation
email="user@example.com"
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "Valid email"
else
    echo "Invalid email"
fi

# IP address validation
ip="192.168.1.100"
if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Looks like an IP address"
fi

# Capture groups with BASH_REMATCH
version="v2.5.10-beta"
if [[ "$version" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)(-(.+))?$ ]]; then
    echo "Major: ${BASH_REMATCH[1]}"
    echo "Minor: ${BASH_REMATCH[2]}"
    echo "Patch: ${BASH_REMATCH[3]}"
    echo "Label: ${BASH_REMATCH[5]}"
fi

# Using regex in loops
log_line='2026-03-18 14:30:00 ERROR Connection timeout'
if [[ "$log_line" =~ ^([0-9-]+)\ ([0-9:]+)\ (ERROR|WARN|INFO)\ (.+)$ ]]; then
    echo "Date: ${BASH_REMATCH[1]}"
    echo "Time: ${BASH_REMATCH[2]}"
    echo "Level: ${BASH_REMATCH[3]}"
    echo "Message: ${BASH_REMATCH[4]}"
fi
```

### `grep`, `sed`, and `awk`

```bash
#!/usr/bin/env bash

# grep: search for patterns
grep -r "function" /path/to/scripts/    # recursive search
grep -i "error" logfile.txt             # case-insensitive
grep -c "warning" logfile.txt           # count matches
grep -n "TODO" *.sh                     # show line numbers
grep -v "^#" config.txt                 # invert match (exclude comments)
grep -E "error|warning|critical" log    # extended regex (OR)

# sed: stream editor
echo "Hello World" | sed 's/World/Bash/'         # substitute first
echo "aabbcc" | sed 's/b/B/g'                    # substitute all
sed -i 's/old/new/g' file.txt                    # in-place edit
sed -n '5,10p' file.txt                          # print lines 5-10
sed '/^$/d' file.txt                             # delete blank lines

# awk: pattern scanning and processing
echo "Alice 85" | awk '{print $1, "scored", $2}'  # field processing
awk -F: '{print $1}' /etc/passwd                   # custom delimiter
awk '/error/ {count++} END {print count}' log.txt  # count pattern matches
awk '{sum += $2} END {print "Average:", sum/NR}' scores.txt  # averages
```

---

## 16. Error Handling and Debugging

### Exit Status

Every command returns an exit status: `0` for success, non-zero for failure.

```bash
#!/usr/bin/env bash

ls /etc/passwd
echo "Exit status: $?"    # 0

ls /nonexistent 2>/dev/null
echo "Exit status: $?"    # 2 (file not found)

# Set custom exit status
exit_demo() {
    return 42
}
exit_demo
echo "Function returned: $?"
```

### Strict Mode

Enable strict mode to catch errors early:

```bash
#!/usr/bin/env bash
set -euo pipefail

# set -e   : Exit immediately on any command failure
# set -u   : Treat unset variables as errors
# set -o pipefail : Pipeline fails if any command in it fails
```

How each option helps:

```bash
#!/usr/bin/env bash

# Without -e, the script continues after an error
set -e
false           # script exits here
echo "Unreachable"

# Without -u, unset variables silently expand to empty
set -u
echo "$undefined_var"   # Error: undefined_var: unbound variable

# Without pipefail, pipeline exit status is the LAST command's status
set -o pipefail
false | true     # pipeline exit status is now 1 (from false), not 0
```

### Custom Error Handling

```bash
#!/usr/bin/env bash
set -euo pipefail

die() {
    echo "ERROR: $*" >&2
    exit 1
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Usage
[[ -f "$1" ]] || die "File '$1' not found"
log "Processing file: $1"
```

### Using `trap` for Cleanup

```bash
#!/usr/bin/env bash

cleanup() {
    echo "Cleaning up temporary files..."
    rm -f "$tmpfile"
}

trap cleanup EXIT

tmpfile=$(mktemp)
echo "Working with $tmpfile"
# Script can exit anywhere; cleanup always runs
```

### Debugging Techniques

```bash
#!/usr/bin/env bash

# Enable debug mode (prints each command before execution)
set -x
echo "This will show the command and its output"
set +x  # disable debug mode

# Debug a specific section
some_function() {
    local PS4='+ ${FUNCNAME[0]}:${LINENO}: '
    set -x
    # commands to debug
    local result=$(( 2 + 2 ))
    echo "$result"
    set +x
}

# Run an entire script in debug mode from the command line:
#   bash -x script.sh

# Trace with line numbers (customize PS4)
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
```

### Error Handling Patterns

```bash
#!/usr/bin/env bash

# Pattern 1: try/catch style
if ! output=$(some_command 2>&1); then
    echo "Command failed with output: $output" >&2
    exit 1
fi

# Pattern 2: error handler with trap
on_error() {
    echo "Error on line $1, exit status $2" >&2
}
trap 'on_error ${LINENO} $?' ERR

# Pattern 3: retry logic
retry() {
    local max_attempts=$1
    shift
    local attempt=1

    while (( attempt <= max_attempts )); do
        if "$@"; then
            return 0
        fi
        echo "Attempt $attempt/$max_attempts failed, retrying..." >&2
        (( attempt++ ))
        sleep $(( attempt * 2 ))
    done

    echo "All $max_attempts attempts failed" >&2
    return 1
}

# Usage: retry 3 curl -sf https://example.com
```

---

## 17. Signal Handling with `trap`

`trap` lets you intercept signals and execute commands when they occur:

```bash
#!/usr/bin/env bash

# Common signals:
#   EXIT (0)     - script exits (any reason)
#   HUP (1)      - terminal hangup
#   INT (2)       - Ctrl+C
#   QUIT (3)      - Ctrl+\
#   TERM (15)     - termination request
#   ERR           - any command returns non-zero (with set -e)
#   DEBUG         - before every command
#   RETURN        - when a function or sourced script returns

# Trap Ctrl+C
trap 'echo "Caught SIGINT! Use quit to exit."' INT

# Trap script exit for cleanup
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"; echo "Cleaned up $tmpdir"' EXIT

# Trap multiple signals
trap 'echo "Terminating..."; exit 1' INT TERM HUP

# Reset a trap to default
trap - INT

# Ignore a signal
trap '' INT   # Ctrl+C is now ignored

# Stack-safe cleanup pattern
cleanup_files=()
register_cleanup() {
    cleanup_files+=("$1")
}

do_cleanup() {
    for f in "${cleanup_files[@]}"; do
        rm -f "$f"
    done
}
trap do_cleanup EXIT
```

---

## 18. Subshells and Command Grouping

### Subshells `( )`

A subshell runs commands in a child process. Changes to variables, directory, etc., do not affect the parent:

```bash
#!/usr/bin/env bash

var="parent"

(
    var="child"
    cd /tmp
    echo "Inside subshell: var=$var, pwd=$(pwd)"
)

echo "Outside subshell: var=$var, pwd=$(pwd)"
```

### Command Groups `{ }`

Command groups run in the **current** shell (no subshell overhead):

```bash
#!/usr/bin/env bash

# Group commands and redirect their combined output
{
    echo "Header"
    echo "------"
    date
    uptime
} > /tmp/system_info.txt

# Conditional execution of a group
[[ -f /etc/os-release ]] && {
    source /etc/os-release
    echo "OS: $NAME $VERSION_ID"
}
```

### Parallel Execution

```bash
#!/usr/bin/env bash

# Run commands in the background
task1() { sleep 2; echo "Task 1 done"; }
task2() { sleep 3; echo "Task 2 done"; }
task3() { sleep 1; echo "Task 3 done"; }

task1 &
task2 &
task3 &

# Wait for all background jobs to finish
wait
echo "All tasks completed"

# Wait for a specific job
task1 &
pid1=$!
task2 &
pid2=$!

wait $pid1
echo "Task 1 finished with status $?"
wait $pid2
echo "Task 2 finished with status $?"
```

---

## 19. Best Practices

### 1. Always Use Strict Mode

```bash
#!/usr/bin/env bash
set -euo pipefail
```

### 2. Quote Your Variables

```bash
# Bad - breaks on spaces
for file in $(ls); do ...

# Good
for file in *; do
    [[ -e "$file" ]] || continue
    echo "$file"
done
```

### 3. Use `[[ ]]` Instead of `[ ]`

`[[ ]]` is safer (no word splitting), supports pattern matching and regex, and handles empty variables gracefully.

### 4. Use `local` in Functions

Always declare function variables with `local` to prevent polluting the global scope.

### 5. Use Meaningful Variable Names

```bash
# Bad
x=5; y="/tmp/f.txt"

# Good
max_retries=5; temp_config="/tmp/config.txt"
```

### 6. Handle Errors Gracefully

```bash
command_that_might_fail || {
    echo "Failed to run command" >&2
    exit 1
}
```

### 7. Use Functions for Reusable Logic

Break your script into small, focused functions with clear names.

### 8. Validate Input

```bash
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <filename>" >&2
    exit 1
fi

[[ -f "$1" ]] || { echo "File not found: $1" >&2; exit 1; }
```

### 9. Use `shellcheck`

[ShellCheck](https://www.shellcheck.net/) is a static analysis tool for shell scripts. Run it on all your scripts:

```bash
shellcheck myscript.sh
```

### 10. Prefer Built-in Features Over External Commands

```bash
# Bad: spawns an external process
length=$(echo -n "$str" | wc -c)

# Good: pure Bash
length=${#str}
```

---

## 20. Practical Examples

For complete, runnable practical examples, see the `examples/` directory:

| Script | Description |
|--------|-------------|
| [`01_system_info.sh`](examples/01_system_info.sh) | Gathers and displays system information |
| [`02_backup_tool.sh`](examples/02_backup_tool.sh) | Creates timestamped compressed backups |
| [`03_log_analyzer.sh`](examples/03_log_analyzer.sh) | Parses and summarizes log files |
| [`04_process_monitor.sh`](examples/04_process_monitor.sh) | Monitors system processes and resources |
| [`05_text_processor.sh`](examples/05_text_processor.sh) | CSV/text file processing utilities |
| [`06_network_utils.sh`](examples/06_network_utils.sh) | Network connectivity and diagnostic tools |
| [`07_user_manager.sh`](examples/07_user_manager.sh) | User account management (menu-driven) |
| [`08_file_organizer.sh`](examples/08_file_organizer.sh) | Organizes files by type/date/size |
| [`09_deployment_script.sh`](examples/09_deployment_script.sh) | Application deployment automation |
| [`10_database_backup.sh`](examples/10_database_backup.sh) | Database backup with rotation and logging |

---

## Further Resources

- **GNU Bash Manual**: https://www.gnu.org/software/bash/manual/
- **Advanced Bash-Scripting Guide**: https://tldp.org/LDP/abs/html/
- **ShellCheck**: https://www.shellcheck.net/
- **Bash Hackers Wiki**: https://wiki.bash-hackers.org/
- **Google Shell Style Guide**: https://google.github.io/styleguide/shellguide.html
