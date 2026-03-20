# Comprehensive BASH Programming Tutorial

## Table of Contents

1. [Introduction to BASH](#1-introduction-to-bash)
2. [Getting Started](#2-getting-started)
3. [Variables](#3-variables)
4. [User Input and Output](#4-user-input-and-output)
5. [Operators](#5-operators)
6. [Conditional Statements](#6-conditional-statements)
7. [Loops](#7-loops)
8. [Functions](#8-functions)
9. [Arrays](#9-arrays)
10. [String Manipulation](#10-string-manipulation)
11. [File and Directory Operations](#11-file-and-directory-operations)
12. [Regular Expressions and Text Processing](#12-regular-expressions-and-text-processing)
13. [Process Management](#13-process-management)
14. [Redirection and Pipes](#14-redirection-and-pipes)
15. [Error Handling and Debugging](#15-error-handling-and-debugging)
16. [Advanced Topics](#16-advanced-topics)
17. [Practical Real-World Examples](#17-practical-real-world-examples)

---

## 1. Introduction to BASH

**BASH** (Bourne Again SHell) is a Unix shell and command-line interpreter written as a free software replacement for the Bourne shell (`sh`). It is the default login shell on most Linux distributions and macOS (prior to Catalina).

### Why Learn BASH?

- **Automation**: Automate repetitive system administration tasks.
- **System Administration**: Manage servers, deploy software, monitor systems.
- **DevOps/CI-CD**: Write build scripts, deployment pipelines, and infrastructure automation.
- **Data Processing**: Process text files, logs, and CSV data quickly.
- **Universality**: Available on virtually every Unix/Linux system without installing anything.

### Checking Your BASH Version

```bash
bash --version
echo $BASH_VERSION
```

---

## 2. Getting Started

### 2.1 Your First Script

Create a file called `hello.sh`:

```bash
#!/bin/bash
echo "Hello, World!"
```

The first line `#!/bin/bash` is called a **shebang** (or hashbang). It tells the operating system which interpreter to use to execute the script.

### 2.2 Making the Script Executable

```bash
chmod +x hello.sh
./hello.sh
```

Alternatively, you can run it directly with BASH:

```bash
bash hello.sh
```

### 2.3 Script Structure Best Practices

A well-structured script follows this pattern:

```bash
#!/bin/bash
#
# Script Name: example.sh
# Description: Brief description of what this script does
# Author: Your Name
# Date: 2026-03-20
#

set -euo pipefail    # Strict mode (explained in Section 15)

# --- Constants ---
readonly LOG_DIR="/var/log/myapp"
readonly MAX_RETRIES=3

# --- Functions ---
main() {
    echo "Script started"
    # ... main logic ...
}

# --- Entry Point ---
main "$@"
```

### 2.4 Comments

```bash
# This is a single-line comment

: '
This is a
multi-line comment
block using the colon-space-quote idiom
'
```

---

## 3. Variables

### 3.1 Variable Assignment

In BASH, variables are assigned **without spaces** around the `=` sign:

```bash
#!/bin/bash

name="Alice"
age=30
city="New York"

echo "Name: $name"
echo "Age: $age"
echo "City: $city"
```

> **Important**: `name = "Alice"` (with spaces) will NOT work. BASH will treat `name` as a command.

### 3.2 Variable Types

BASH variables are untyped by default (everything is a string), but you can declare types:

```bash
#!/bin/bash

declare -i number=42       # Integer — arithmetic is applied automatically
declare -r constant="PI"   # Read-only (constant)
declare -l lower="HELLO"   # Convert to lowercase on assignment
declare -u upper="hello"   # Convert to uppercase on assignment
declare -a array           # Indexed array
declare -A hashmap         # Associative array

echo "$number"    # 42
echo "$constant"  # PI
echo "$lower"     # hello
echo "$upper"     # HELLO
```

### 3.3 Quoting Rules

Understanding quoting is essential in BASH:

```bash
#!/bin/bash

name="World"

echo "Hello, $name"     # Double quotes: variables ARE expanded   → Hello, World
echo 'Hello, $name'     # Single quotes: variables are NOT expanded → Hello, $name
echo "Path: ~/docs"     # Tilde is NOT expanded inside quotes
echo ~"/docs"           # Tilde IS expanded before the quote starts

echo "She said \"hi\""  # Escaping double quotes within double quotes
echo 'It'\''s done'     # Escaping single quotes within single quotes
```

### 3.4 Command Substitution

Capture the output of a command into a variable:

```bash
#!/bin/bash

current_date=$(date +%Y-%m-%d)
file_count=$(ls -1 | wc -l)
kernel=$(uname -r)

echo "Date: $current_date"
echo "Files in current directory: $file_count"
echo "Kernel version: $kernel"

# Legacy syntax using backticks (avoid — harder to nest)
old_style=`date`
```

### 3.5 Environment Variables vs. Local Variables

```bash
#!/bin/bash

local_var="I'm local to this shell"
export GLOBAL_VAR="I'm available to child processes"

echo "$local_var"
echo "$GLOBAL_VAR"

# Common environment variables
echo "Home directory: $HOME"
echo "Current user: $USER"
echo "Shell: $SHELL"
echo "Path: $PATH"
echo "Current directory: $PWD"
echo "Hostname: $HOSTNAME"
```

### 3.6 Special Variables

```bash
#!/bin/bash

echo "Script name: $0"
echo "First argument: $1"
echo "Second argument: $2"
echo "All arguments (as separate words): $@"
echo "All arguments (as single string): $*"
echo "Number of arguments: $#"
echo "Exit status of last command: $?"
echo "PID of current script: $$"
echo "PID of last background process: $!"
```

### 3.7 Parameter Expansion (Default Values)

```bash
#!/bin/bash

# Use default value if variable is unset or empty
echo "${name:-Anonymous}"        # Uses "Anonymous" if $name is unset/empty

# Assign default value if variable is unset or empty
echo "${name:=Anonymous}"        # Assigns AND uses "Anonymous"

# Display error if variable is unset or empty
echo "${name:?'name is required'}"  # Exits with error if $name is unset

# Use alternative value if variable IS set
echo "${name:+Hello $name}"     # Uses "Hello $name" only if $name is set

# String length
greeting="Hello, World!"
echo "Length: ${#greeting}"     # 13

# Substring extraction
echo "${greeting:0:5}"         # Hello   (from position 0, length 5)
echo "${greeting:7}"           # World!  (from position 7 to end)
```

---

## 4. User Input and Output

### 4.1 Reading User Input

```bash
#!/bin/bash

read -p "Enter your name: " username
echo "Hello, $username!"

# Read with a timeout (5 seconds)
read -t 5 -p "Quick! Enter something: " quick_input

# Silent input (for passwords)
read -s -p "Enter password: " password
echo    # Print newline after silent read
echo "Password length: ${#password}"

# Read into multiple variables
echo "Enter first and last name:"
read first last
echo "First: $first, Last: $last"

# Read with a default value
read -p "Enter color [blue]: " color
color="${color:-blue}"
echo "Color: $color"
```

### 4.2 Output Formatting

```bash
#!/bin/bash

# echo — basic output
echo "Simple output"
echo -e "Tab:\there\nNewline above"   # -e enables escape sequences
echo -n "No trailing newline"          # -n suppresses newline

# printf — formatted output (more portable and powerful)
printf "Name: %s, Age: %d\n" "Alice" 30
printf "Pi: %.4f\n" 3.14159
printf "Hex: %x, Octal: %o\n" 255 255
printf "%-20s %10s\n" "Item" "Price"      # Left-align, right-align
printf "%-20s %10.2f\n" "Widget" 19.99
printf "%-20s %10.2f\n" "Gadget" 149.50
```

### 4.3 Here Documents and Here Strings

```bash
#!/bin/bash

# Here Document — multi-line input to a command
cat << EOF
This is a multi-line
document. Variables like $HOME
are expanded.
EOF

# Here Document with quoting — suppress variable expansion
cat << 'EOF'
This is literal text.
$HOME will NOT be expanded.
EOF

# Here Document with indentation stripping (use <<-)
cat <<- EOF
	This leading tab will be removed.
	Useful for indented scripts.
EOF

# Here String — pass a single string as stdin
grep "hello" <<< "hello world"
```

---

## 5. Operators

### 5.1 Arithmetic Operators

```bash
#!/bin/bash

a=20
b=7

# Using $(( )) for arithmetic
echo "Addition:       $((a + b))"      # 27
echo "Subtraction:    $((a - b))"      # 13
echo "Multiplication: $((a * b))"      # 140
echo "Division:       $((a / b))"      # 2  (integer division)
echo "Modulus:        $((a % b))"      # 6
echo "Exponentiation: $((a ** 2))"     # 400

# Increment/Decrement
((a++))
echo "After a++: $a"   # 21
((a--))
echo "After a--: $a"   # 20

# Compound assignment
((a += 5))
echo "After a+=5: $a"  # 25

# Using let
let "result = a * b"
echo "let result: $result"

# Using expr (legacy, external command)
result=$(expr $a + $b)
echo "expr result: $result"

# Floating-point arithmetic requires bc or awk
result=$(echo "scale=2; 22/7" | bc)
echo "Pi approx: $result"   # 3.14
```

### 5.2 Comparison Operators

#### Integer Comparisons

| Operator | Meaning                  |
|----------|--------------------------|
| `-eq`    | Equal                    |
| `-ne`    | Not equal                |
| `-gt`    | Greater than             |
| `-ge`    | Greater than or equal    |
| `-lt`    | Less than                |
| `-le`    | Less than or equal       |

```bash
#!/bin/bash

a=10
b=20

if [ "$a" -eq "$b" ]; then echo "Equal"; fi
if [ "$a" -lt "$b" ]; then echo "$a is less than $b"; fi

# Inside [[ ]], you can also use < > == !=
if [[ $a -gt 5 && $b -lt 30 ]]; then
    echo "Both conditions met"
fi
```

#### String Comparisons

| Operator  | Meaning                          |
|-----------|----------------------------------|
| `=` / `==`| Equal (use `==` inside `[[ ]]`) |
| `!=`      | Not equal                        |
| `<`       | Less than (lexicographic)        |
| `>`       | Greater than (lexicographic)     |
| `-z`      | String is empty                  |
| `-n`      | String is not empty              |

```bash
#!/bin/bash

str1="hello"
str2="world"

if [[ "$str1" == "$str2" ]]; then
    echo "Strings are equal"
else
    echo "Strings are different"
fi

if [[ -z "$str1" ]]; then
    echo "String is empty"
fi

if [[ -n "$str1" ]]; then
    echo "String is not empty"
fi

# Pattern matching with ==
if [[ "$str1" == h* ]]; then
    echo "Starts with h"
fi

# Regex matching with =~
if [[ "$str1" =~ ^[a-z]+$ ]]; then
    echo "All lowercase letters"
fi
```

### 5.3 File Test Operators

| Operator  | Meaning                                |
|-----------|----------------------------------------|
| `-e`      | File exists                            |
| `-f`      | Is a regular file                      |
| `-d`      | Is a directory                         |
| `-r`      | Is readable                            |
| `-w`      | Is writable                            |
| `-x`      | Is executable                          |
| `-s`      | File exists and is not empty           |
| `-L`      | Is a symbolic link                     |
| `-nt`     | File1 is newer than file2              |
| `-ot`     | File1 is older than file2              |

```bash
#!/bin/bash

file="/etc/passwd"

if [[ -e "$file" ]]; then echo "$file exists"; fi
if [[ -f "$file" ]]; then echo "$file is a regular file"; fi
if [[ -r "$file" ]]; then echo "$file is readable"; fi
if [[ -s "$file" ]]; then echo "$file is not empty"; fi

# Combining tests
if [[ -f "$file" && -r "$file" ]]; then
    echo "$file is a readable file"
fi
```

### 5.4 Logical Operators

```bash
#!/bin/bash

a=10

# Inside [[ ]]
if [[ $a -gt 5 && $a -lt 20 ]]; then
    echo "a is between 5 and 20"
fi

if [[ $a -lt 5 || $a -gt 8 ]]; then
    echo "a is outside range 5-8"
fi

if [[ ! $a -eq 20 ]]; then
    echo "a is not 20"
fi

# Inside [ ] (POSIX)
if [ "$a" -gt 5 ] && [ "$a" -lt 20 ]; then
    echo "POSIX style: a is between 5 and 20"
fi
```

---

## 6. Conditional Statements

### 6.1 if / elif / else

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

### 6.2 Nested if

```bash
#!/bin/bash

read -p "Enter your age: " age

if [[ $age -ge 0 ]]; then
    if [[ $age -lt 13 ]]; then
        echo "Child"
    elif [[ $age -lt 20 ]]; then
        echo "Teenager"
    elif [[ $age -lt 65 ]]; then
        echo "Adult"
    else
        echo "Senior"
    fi
else
    echo "Invalid age"
fi
```

### 6.3 case Statement

The `case` statement is ideal for matching a value against multiple patterns:

```bash
#!/bin/bash

read -p "Enter a fruit: " fruit

case "$fruit" in
    apple|Apple)
        echo "It's an apple — red or green!"
        ;;
    banana|Banana)
        echo "It's a banana — yellow and curved!"
        ;;
    orange|Orange)
        echo "It's an orange — citrusy!"
        ;;
    *)
        echo "Unknown fruit: $fruit"
        ;;
esac
```

#### Advanced case with Patterns

```bash
#!/bin/bash

read -p "Enter a filename: " filename

case "$filename" in
    *.tar.gz | *.tgz)
        echo "Gzipped tar archive"
        tar -tzf "$filename"
        ;;
    *.tar.bz2)
        echo "Bzip2 tar archive"
        tar -tjf "$filename"
        ;;
    *.zip)
        echo "ZIP archive"
        unzip -l "$filename"
        ;;
    *.jpg | *.jpeg | *.png | *.gif)
        echo "Image file"
        ;;
    *.sh)
        echo "Shell script"
        ;;
    *)
        echo "Unknown file type"
        ;;
esac
```

### 6.4 Ternary-style Expressions

BASH doesn't have a true ternary operator, but you can simulate it:

```bash
#!/bin/bash

age=20

# Using && and ||
[[ $age -ge 18 ]] && echo "Adult" || echo "Minor"

# Using arithmetic ternary
status=$(( age >= 18 ? 1 : 0 ))
echo "Adult status: $status"
```

---

## 7. Loops

### 7.1 for Loop

```bash
#!/bin/bash

# C-style for loop
for ((i = 1; i <= 5; i++)); do
    echo "Iteration $i"
done

# For loop with a list
for color in red green blue yellow; do
    echo "Color: $color"
done

# For loop with a range
for i in {1..10}; do
    echo "Number: $i"
done

# Range with step
for i in {0..100..10}; do
    echo "Value: $i"
done

# For loop over files
for file in /etc/*.conf; do
    echo "Config file: $file"
done

# For loop over command output
for user in $(cut -d: -f1 /etc/passwd | head -5); do
    echo "User: $user"
done
```

### 7.2 while Loop

```bash
#!/bin/bash

# Basic while loop
count=1
while [[ $count -le 5 ]]; do
    echo "Count: $count"
    ((count++))
done

# Reading a file line by line
while IFS= read -r line; do
    echo "Line: $line"
done < /etc/hostname

# Infinite loop with break
while true; do
    read -p "Enter 'quit' to exit: " input
    if [[ "$input" == "quit" ]]; then
        break
    fi
    echo "You entered: $input"
done

# While loop with a counter and continue
i=0
while [[ $i -lt 10 ]]; do
    ((i++))
    if (( i % 2 == 0 )); then
        continue    # Skip even numbers
    fi
    echo "Odd: $i"
done
```

### 7.3 until Loop

The `until` loop runs *until* the condition becomes true (opposite of `while`):

```bash
#!/bin/bash

count=1
until [[ $count -gt 5 ]]; do
    echo "Count: $count"
    ((count++))
done
```

### 7.4 select Loop (Menu)

```bash
#!/bin/bash

PS3="Choose an option: "   # Custom prompt for select

select option in "Start" "Stop" "Status" "Quit"; do
    case "$option" in
        Start)  echo "Starting service..." ;;
        Stop)   echo "Stopping service..." ;;
        Status) echo "Service is running" ;;
        Quit)   echo "Goodbye!"; break ;;
        *)      echo "Invalid option" ;;
    esac
done
```

### 7.5 Loop Control

```bash
#!/bin/bash

# break — exit the loop
for i in {1..10}; do
    if [[ $i -eq 5 ]]; then
        echo "Breaking at $i"
        break
    fi
    echo "$i"
done

# continue — skip to next iteration
for i in {1..10}; do
    if (( i % 3 == 0 )); then
        continue
    fi
    echo "$i"
done

# break with nested loops (break N exits N levels)
for i in {1..3}; do
    for j in {1..3}; do
        if [[ $j -eq 2 ]]; then
            break 2   # Break out of both loops
        fi
        echo "i=$i, j=$j"
    done
done
```

---

## 8. Functions

### 8.1 Defining and Calling Functions

```bash
#!/bin/bash

# Method 1: function keyword
function greet() {
    echo "Hello, $1!"
}

# Method 2: without function keyword (POSIX compatible)
add() {
    echo $(( $1 + $2 ))
}

greet "Alice"
result=$(add 10 20)
echo "Sum: $result"
```

### 8.2 Function Arguments

```bash
#!/bin/bash

show_info() {
    echo "Function name: ${FUNCNAME[0]}"
    echo "Argument count: $#"
    echo "All arguments: $@"
    echo "First arg: $1"
    echo "Second arg: $2"
}

show_info "hello" "world" "foo" "bar"
```

### 8.3 Return Values

Functions in BASH can only return exit codes (0-255). To return data, use `echo` and command substitution:

```bash
#!/bin/bash

# Return exit code
is_even() {
    if (( $1 % 2 == 0 )); then
        return 0    # success/true
    else
        return 1    # failure/false
    fi
}

# Return data via echo
get_greeting() {
    local name="$1"
    echo "Hello, $name! Today is $(date +%A)."
}

if is_even 42; then
    echo "42 is even"
fi

message=$(get_greeting "Bob")
echo "$message"
```

### 8.4 Local Variables

```bash
#!/bin/bash

my_func() {
    local local_var="I'm local"
    global_var="I'm global"
    echo "Inside function: $local_var"
}

my_func
echo "Outside function: $local_var"     # Empty — local scope ended
echo "Outside function: $global_var"    # "I'm global"
```

### 8.5 Recursive Functions

```bash
#!/bin/bash

factorial() {
    local n=$1
    if (( n <= 1 )); then
        echo 1
    else
        local sub=$(factorial $(( n - 1 )))
        echo $(( n * sub ))
    fi
}

echo "5! = $(factorial 5)"    # 120
echo "10! = $(factorial 10)"  # 3628800
```

### 8.6 Passing Arrays to Functions

```bash
#!/bin/bash

print_array() {
    local arr=("$@")
    for element in "${arr[@]}"; do
        echo "  - $element"
    done
}

fruits=("apple" "banana" "cherry" "date")
echo "Fruits:"
print_array "${fruits[@]}"

sum_array() {
    local total=0
    for num in "$@"; do
        (( total += num ))
    done
    echo $total
}

numbers=(10 20 30 40 50)
echo "Sum: $(sum_array "${numbers[@]}")"   # 150
```

---

## 9. Arrays

### 9.1 Indexed Arrays

```bash
#!/bin/bash

# Declaration methods
fruits=("apple" "banana" "cherry")
declare -a vegetables
vegetables[0]="carrot"
vegetables[1]="potato"
vegetables[2]="tomato"

# Accessing elements
echo "First fruit: ${fruits[0]}"
echo "Second fruit: ${fruits[1]}"
echo "All fruits: ${fruits[@]}"
echo "Number of fruits: ${#fruits[@]}"

# Iterating
for fruit in "${fruits[@]}"; do
    echo "Fruit: $fruit"
done

# Iterating with indices
for i in "${!fruits[@]}"; do
    echo "Index $i: ${fruits[$i]}"
done

# Appending elements
fruits+=("date")
fruits+=("elderberry" "fig")
echo "After append: ${fruits[@]}"

# Removing elements
unset 'fruits[1]'    # Removes "banana" — index is NOT re-numbered
echo "After unset: ${fruits[@]}"

# Slicing
echo "Slice [1..2]: ${fruits[@]:1:2}"
```

### 9.2 Associative Arrays

```bash
#!/bin/bash

declare -A capitals

capitals["France"]="Paris"
capitals["Japan"]="Tokyo"
capitals["India"]="New Delhi"
capitals["Brazil"]="Brasilia"

echo "Capital of Japan: ${capitals["Japan"]}"

# All keys
echo "Countries: ${!capitals[@]}"

# All values
echo "Capitals: ${capitals[@]}"

# Iterating
for country in "${!capitals[@]}"; do
    echo "$country => ${capitals[$country]}"
done

# Check if key exists
if [[ -v capitals["France"] ]]; then
    echo "France exists in the map"
fi

# Delete an entry
unset 'capitals["Brazil"]'
```

### 9.3 Array Operations

```bash
#!/bin/bash

arr=(5 3 8 1 9 2 7 4 6)

# Sort an array (using external sort command)
sorted=($(printf '%s\n' "${arr[@]}" | sort -n))
echo "Sorted: ${sorted[@]}"

# Reverse
reversed=($(printf '%s\n' "${arr[@]}" | sort -nr))
echo "Reversed: ${reversed[@]}"

# Find unique elements
data=(1 2 2 3 3 3 4 5 5)
unique=($(printf '%s\n' "${data[@]}" | sort -u))
echo "Unique: ${unique[@]}"

# Check if array contains a value
contains() {
    local target="$1"
    shift
    for element in "$@"; do
        [[ "$element" == "$target" ]] && return 0
    done
    return 1
}

if contains 8 "${arr[@]}"; then
    echo "Array contains 8"
fi

# Join array elements with a delimiter
join_by() {
    local IFS="$1"
    shift
    echo "$*"
}
echo "Joined: $(join_by ',' "${arr[@]}")"
```

---

## 10. String Manipulation

### 10.1 Basic String Operations

```bash
#!/bin/bash

str="Hello, Beautiful World!"

# Length
echo "Length: ${#str}"                        # 23

# Substring
echo "Substring: ${str:7:9}"                  # Beautiful

# Uppercase / Lowercase (BASH 4+)
echo "Uppercase: ${str^^}"                    # HELLO, BEAUTIFUL WORLD!
echo "Lowercase: ${str,,}"                    # hello, beautiful world!
echo "First char upper: ${str^}"              # Hello, Beautiful World!
echo "First char lower: ${str,}"              # hello, Beautiful World!
```

### 10.2 Search and Replace

```bash
#!/bin/bash

path="/home/user/documents/file.txt"

# Remove shortest match from front
echo "${path#*/}"         # home/user/documents/file.txt

# Remove longest match from front
echo "${path##*/}"        # file.txt  (basename)

# Remove shortest match from back
echo "${path%/*}"         # /home/user/documents  (dirname)

# Remove longest match from back
echo "${path%%/*}"        # (empty, since path starts with /)

# Substitution (first occurrence)
msg="Hello World World"
echo "${msg/World/BASH}"       # Hello BASH World

# Substitution (all occurrences)
echo "${msg//World/BASH}"      # Hello BASH BASH

# Replace at beginning
echo "${msg/#Hello/Goodbye}"   # Goodbye World World

# Replace at end
echo "${msg/%World/BASH}"      # Hello World BASH
```

### 10.3 String Splitting

```bash
#!/bin/bash

# Using IFS (Internal Field Separator)
csv_line="Alice,30,Engineer,New York"
IFS=',' read -ra fields <<< "$csv_line"
echo "Name: ${fields[0]}"
echo "Age: ${fields[1]}"
echo "Job: ${fields[2]}"
echo "City: ${fields[3]}"

# Using cut
echo "$csv_line" | cut -d',' -f1    # Alice
echo "$csv_line" | cut -d',' -f3    # Engineer

# Using awk
echo "$csv_line" | awk -F',' '{print $2}'   # 30
```

### 10.4 String Comparison and Patterns

```bash
#!/bin/bash

email="user@example.com"

# Regex matching
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "Valid email: $email"
fi

# Extract matched groups
if [[ "$email" =~ ^([^@]+)@(.+)$ ]]; then
    echo "Username: ${BASH_REMATCH[1]}"
    echo "Domain: ${BASH_REMATCH[2]}"
fi

# Glob patterns
filename="report_2026.csv"
if [[ "$filename" == *.csv ]]; then
    echo "It's a CSV file"
fi

if [[ "$filename" == report_????.* ]]; then
    echo "Report file with 4-digit year"
fi
```

---

## 11. File and Directory Operations

### 11.1 File Testing

```bash
#!/bin/bash

check_file() {
    local f="$1"

    if [[ ! -e "$f" ]]; then
        echo "'$f' does not exist"
        return 1
    fi

    echo "=== Info for: $f ==="
    [[ -f "$f" ]] && echo "  Type: regular file"
    [[ -d "$f" ]] && echo "  Type: directory"
    [[ -L "$f" ]] && echo "  Type: symbolic link"
    [[ -r "$f" ]] && echo "  Readable: yes"
    [[ -w "$f" ]] && echo "  Writable: yes"
    [[ -x "$f" ]] && echo "  Executable: yes"
    [[ -s "$f" ]] && echo "  Non-empty: yes"

    echo "  Size: $(stat --format='%s bytes' "$f" 2>/dev/null || stat -f'%z bytes' "$f" 2>/dev/null)"
    echo "  Owner: $(stat --format='%U' "$f" 2>/dev/null || stat -f'%Su' "$f" 2>/dev/null)"
}

check_file "/etc/hostname"
check_file "/usr/bin/bash"
```

### 11.2 Reading Files

```bash
#!/bin/bash

# Read entire file into a variable
content=$(< /etc/hostname)
echo "File content: $content"

# Read file line by line
while IFS= read -r line; do
    echo "Line: $line"
done < /etc/hostname

# Read file into an array (one element per line)
mapfile -t lines < /etc/passwd
echo "Total lines: ${#lines[@]}"
echo "First line: ${lines[0]}"
echo "Last line: ${lines[-1]}"

# Process specific columns from a file
while IFS=: read -r user _ uid gid _ home shell; do
    if (( uid >= 1000 )); then
        printf "User: %-15s UID: %-6s Shell: %s\n" "$user" "$uid" "$shell"
    fi
done < /etc/passwd
```

### 11.3 Writing Files

```bash
#!/bin/bash

# Write (overwrite)
echo "First line" > output.txt

# Append
echo "Second line" >> output.txt

# Write multiple lines
cat > config.txt << EOF
[settings]
debug=false
log_level=info
max_connections=100
EOF

# Write with tee (also prints to stdout)
echo "This goes to file and screen" | tee logged.txt

# Append with tee
echo "Appended line" | tee -a logged.txt
```

### 11.4 Temporary Files

```bash
#!/bin/bash

# Create a temporary file
tmpfile=$(mktemp)
echo "Temp file: $tmpfile"

# Create a temporary directory
tmpdir=$(mktemp -d)
echo "Temp dir: $tmpdir"

# Ensure cleanup on exit
cleanup() {
    rm -f "$tmpfile"
    rm -rf "$tmpdir"
}
trap cleanup EXIT

# Use the temporary file
echo "some data" > "$tmpfile"
cat "$tmpfile"
```

### 11.5 File Locking

```bash
#!/bin/bash

lockfile="/tmp/myscript.lock"

acquire_lock() {
    if ! mkdir "$lockfile" 2>/dev/null; then
        echo "Another instance is running. Exiting."
        exit 1
    fi
    trap 'rm -rf "$lockfile"' EXIT
}

acquire_lock
echo "Running exclusively..."
sleep 5
echo "Done."
```

---

## 12. Regular Expressions and Text Processing

### 12.1 grep

```bash
#!/bin/bash

# Basic search
grep "root" /etc/passwd

# Case insensitive
grep -i "error" /var/log/syslog 2>/dev/null

# Extended regex
grep -E "^(root|nobody):" /etc/passwd

# Show line numbers
grep -n "bash" /etc/passwd

# Count matches
grep -c "nologin" /etc/passwd

# Invert match (lines that DON'T match)
grep -v "nologin" /etc/passwd

# Recursive search in directories
grep -r "TODO" /workspace/ --include="*.sh" 2>/dev/null

# Only filenames
grep -rl "function" /workspace/ --include="*.sh" 2>/dev/null

# Context (lines before/after)
grep -B 2 -A 2 "root" /etc/passwd
```

### 12.2 sed (Stream Editor)

```bash
#!/bin/bash

# Substitute first occurrence on each line
echo "hello world world" | sed 's/world/BASH/'

# Substitute all occurrences
echo "hello world world" | sed 's/world/BASH/g'

# Delete lines matching a pattern
sed '/^#/d' /etc/fstab 2>/dev/null    # Remove comments

# Delete empty lines
echo -e "a\n\nb\n\nc" | sed '/^$/d'

# Print specific lines
sed -n '1,5p' /etc/passwd              # Lines 1-5

# In-place editing (modifies the file)
# sed -i 's/old/new/g' file.txt
# sed -i.bak 's/old/new/g' file.txt   # Creates backup

# Multiple operations
echo "Hello World" | sed -e 's/Hello/Goodbye/' -e 's/World/BASH/'

# Insert a line before/after a match
echo -e "line1\nline3" | sed '/line1/a line2'    # After
echo -e "line2\nline3" | sed '/line2/i line1'    # Before
```

### 12.3 awk

```bash
#!/bin/bash

# Print specific columns
echo "Alice 30 Engineer" | awk '{print $1, $3}'     # Alice Engineer

# Custom field separator
awk -F: '{print $1, $3}' /etc/passwd | head -5

# Formatted output
awk -F: '{printf "%-15s UID: %s\n", $1, $3}' /etc/passwd | head -5

# Conditional processing
awk -F: '$3 >= 1000 {print $1, $3}' /etc/passwd

# Sum a column
echo -e "10\n20\n30\n40" | awk '{sum += $1} END {print "Sum:", sum}'

# Count lines
awk 'END {print NR, "lines"}' /etc/passwd

# Pattern ranges
awk '/^root/,/^daemon/' /etc/passwd

# BEGIN and END blocks
awk 'BEGIN {print "=== User Report ==="} 
     {print NR": "$0} 
     END {print "=== Total:", NR, "lines ==="}' /etc/hostname
```

---

## 13. Process Management

### 13.1 Running Processes

```bash
#!/bin/bash

# Run a command in the background
sleep 10 &
bg_pid=$!
echo "Background PID: $bg_pid"

# Wait for background process
wait $bg_pid
echo "Background process finished with exit code: $?"

# Run multiple background processes and wait for all
for i in {1..5}; do
    sleep $i &
done
wait
echo "All background processes complete"

# Check if a process is running
if kill -0 $bg_pid 2>/dev/null; then
    echo "Process $bg_pid is still running"
else
    echo "Process $bg_pid has finished"
fi
```

### 13.2 Job Control

```bash
#!/bin/bash

# List jobs
jobs

# Move last background job to foreground
# fg %1

# Send job to background
# bg %1

# Disown a job (detach from shell)
sleep 100 &
disown $!
```

### 13.3 Signal Handling with trap

```bash
#!/bin/bash

cleanup() {
    echo "Cleaning up..."
    rm -f /tmp/my_app_*.tmp
    echo "Done."
    exit 0
}

# Trap signals
trap cleanup SIGINT SIGTERM     # Ctrl+C and kill
trap 'echo "Caught HUP"' SIGHUP

echo "Running... (PID: $$)"
echo "Press Ctrl+C to stop"

while true; do
    echo "Working... $(date +%T)"
    sleep 2
done
```

### 13.4 Parallel Execution

```bash
#!/bin/bash

# Using & and wait
process_file() {
    local file="$1"
    echo "Processing $file..."
    sleep 1
    echo "Done: $file"
}

files=("file1.txt" "file2.txt" "file3.txt" "file4.txt")

for f in "${files[@]}"; do
    process_file "$f" &
done
wait
echo "All files processed"

# Using xargs for parallel execution
# echo "${files[@]}" | xargs -n1 -P4 -I{} bash -c 'echo "Processing {}"; sleep 1'

# Limiting concurrent processes
max_jobs=3
for f in "${files[@]}"; do
    while (( $(jobs -rp | wc -l) >= max_jobs )); do
        sleep 0.1
    done
    process_file "$f" &
done
wait
```

---

## 14. Redirection and Pipes

### 14.1 Standard Streams

| Stream | File Descriptor | Default   |
|--------|-----------------|-----------|
| stdin  | 0               | Keyboard  |
| stdout | 1               | Terminal  |
| stderr | 2               | Terminal  |

### 14.2 Output Redirection

```bash
#!/bin/bash

# Redirect stdout to file (overwrite)
echo "hello" > output.txt

# Redirect stdout to file (append)
echo "world" >> output.txt

# Redirect stderr to file
ls /nonexistent 2> errors.txt

# Redirect both stdout and stderr to same file
command_that_might_fail > all_output.txt 2>&1

# Modern syntax (BASH 4+)
command_that_might_fail &> all_output.txt

# Redirect stdout and stderr to different files
command 1> stdout.txt 2> stderr.txt

# Discard output
command > /dev/null 2>&1
command &> /dev/null
```

### 14.3 Input Redirection

```bash
#!/bin/bash

# Read input from file
wc -l < /etc/passwd

# Here document as input
sort << EOF
banana
apple
cherry
date
EOF

# Here string as input
wc -w <<< "count the words in this sentence"
```

### 14.4 Pipes

```bash
#!/bin/bash

# Basic pipe
cat /etc/passwd | grep "bash" | wc -l

# Pipeline with multiple stages
ps aux | sort -nrk 4 | head -5    # Top 5 memory-consuming processes

# Named pipes (FIFOs)
fifo="/tmp/my_fifo"
mkfifo "$fifo" 2>/dev/null

# Writer (in background)
echo "data through fifo" > "$fifo" &

# Reader
cat < "$fifo"
rm -f "$fifo"

# Process substitution (treats output as a file)
diff <(sort file1.txt 2>/dev/null) <(sort file2.txt 2>/dev/null) 2>/dev/null
```

### 14.5 tee — Split Output

```bash
#!/bin/bash

# Send output to both screen and file
ls -la | tee directory_listing.txt

# Append mode
echo "appended" | tee -a directory_listing.txt

# Multiple files
echo "multi" | tee file1.txt file2.txt file3.txt

# Mid-pipeline tee
cat /etc/passwd | tee /tmp/passwd_copy.txt | grep "root"
```

---

## 15. Error Handling and Debugging

### 15.1 Exit Codes

```bash
#!/bin/bash

# Every command returns an exit code: 0 = success, non-zero = failure
ls /etc/passwd
echo "Exit code: $?"    # 0

ls /nonexistent_file 2>/dev/null
echo "Exit code: $?"    # 2 (no such file)

# Set your own exit code
exit_demo() {
    if [[ -z "$1" ]]; then
        echo "Error: argument required" >&2
        return 1
    fi
    echo "Argument: $1"
    return 0
}

exit_demo
echo "Exit code: $?"    # 1

exit_demo "hello"
echo "Exit code: $?"    # 0
```

### 15.2 Strict Mode

```bash
#!/bin/bash
set -euo pipefail

# set -e           : Exit on any command failure
# set -u           : Treat unset variables as errors
# set -o pipefail  : Pipeline fails if ANY command fails (not just the last)

# These can also be combined:
# set -euo pipefail

# To temporarily disable strict mode for a command that may fail:
set +e
might_fail_command
result=$?
set -e
echo "Command exited with: $result"
```

### 15.3 Error Handling Patterns

```bash
#!/bin/bash

# Pattern 1: || operator for error handling
cd /some/directory || { echo "Failed to cd" >&2; exit 1; }

# Pattern 2: Custom error function
die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ -f "config.txt" ]] || die "config.txt not found"

# Pattern 3: trap ERR
on_error() {
    echo "Error on line $1, command: $2" >&2
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

# Pattern 4: Comprehensive error trap
set -euo pipefail
trap 'echo "Script failed at line $LINENO (exit code $?)" >&2' ERR
```

### 15.4 Debugging Techniques

```bash
#!/bin/bash

# Enable debug mode (prints each command before execution)
set -x
echo "This command will be shown before executing"
set +x    # Disable debug mode

# Debug a specific section
debug_section() {
    set -x
    local result=$(( 2 + 2 ))
    echo "Result: $result"
    set +x
}

# Run entire script in debug mode from command line:
# bash -x script.sh

# Use PS4 to customize debug prefix
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
echo "Enhanced debug output"
set +x

# Log to a file for debugging
exec 3>&1 4>&2                       # Save stdout/stderr
exec 1> /tmp/debug.log 2>&1          # Redirect to log
echo "This goes to the log file"
exec 1>&3 2>&4                       # Restore stdout/stderr
echo "This goes to the terminal"
```

---

## 16. Advanced Topics

### 16.1 Subshells and Command Grouping

```bash
#!/bin/bash

# Subshell: runs in a child process; changes don't affect the parent
var="parent"
(
    var="child"
    cd /tmp
    echo "In subshell: var=$var, pwd=$PWD"
)
echo "In parent: var=$var, pwd=$PWD"

# Command group: runs in the SAME shell
{
    echo "Line 1"
    echo "Line 2"
    echo "Line 3"
} > grouped_output.txt

# Practical use: group error output
{
    command1
    command2
    command3
} 2> errors.log
```

### 16.2 Process Substitution

```bash
#!/bin/bash

# Compare output of two commands as if they were files
diff <(ls /usr/bin | sort) <(ls /usr/sbin | sort) | head -20

# Feed output of a command as a file to a program that expects files
while IFS= read -r line; do
    echo "Process: $line"
done < <(ps aux | grep bash)

# Write to multiple commands simultaneously
echo "broadcast" | tee >(grep "broad" > /tmp/match.txt) >(wc -c > /tmp/count.txt) > /dev/null
sleep 0.1
cat /tmp/match.txt
cat /tmp/count.txt
```

### 16.3 Coprocesses

```bash
#!/bin/bash

# Start a coprocess (interactive background process)
coproc BC { bc -l; }

# Send commands to the coprocess
echo "scale=4; 22/7" >&"${BC[1]}"
read -r result <&"${BC[0]}"
echo "Pi ≈ $result"

echo "sqrt(2)" >&"${BC[1]}"
read -r result <&"${BC[0]}"
echo "√2 ≈ $result"

# Close the coprocess
exec {BC[1]}>&-
wait $BC_PID 2>/dev/null
```

### 16.4 Eval and Indirect References

```bash
#!/bin/bash

# eval — execute a dynamically constructed command string
cmd="echo Hello from eval"
eval "$cmd"

# Indirect variable reference
var_name="greeting"
greeting="Hello, World!"
echo "${!var_name}"           # Prints: Hello, World!

# Dynamic variable names using nameref (BASH 4.3+)
declare -n ref=greeting
echo "$ref"                    # Prints: Hello, World!
ref="Modified!"
echo "$greeting"               # Prints: Modified!
```

### 16.5 Extended Globbing

```bash
#!/bin/bash

# Enable extended globbing
shopt -s extglob

# ?(pattern) — matches zero or one occurrence
# *(pattern) — matches zero or more occurrences
# +(pattern) — matches one or more occurrences
# @(pattern) — matches exactly one occurrence
# !(pattern) — matches anything EXCEPT the pattern

# Examples (assuming files exist)
# ls *.!(txt)         # All files EXCEPT .txt files
# ls +(ab)            # Files like "ab", "abab", "ababab"

# Practical: remove all files except .sh and .md
# rm !(*.sh|*.md)

# Globstar — recursive matching
shopt -s globstar
# ls **/*.sh           # All .sh files in any subdirectory
```

### 16.6 Here Document Tricks

```bash
#!/bin/bash

# Use a here document to create a function dynamically
generate_report() {
    cat << EOF
=====================================
       SYSTEM REPORT
=====================================
Hostname: $(hostname)
Date:     $(date)
Uptime:   $(uptime -p 2>/dev/null || uptime)
Users:    $(who | wc -l) logged in
Memory:   $(free -h 2>/dev/null | awk '/^Mem:/{print $3 "/" $2}' || echo "N/A")
Disk:     $(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 " used)"}')
=====================================
EOF
}

generate_report
```

### 16.7 Handling Options with getopts

```bash
#!/bin/bash

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] FILE

Options:
    -v          Verbose output
    -o FILE     Output file (default: stdout)
    -n NUM      Number of lines (default: 10)
    -h          Show this help message

Example:
    $(basename "$0") -v -n 20 -o result.txt input.txt
EOF
}

verbose=false
output="/dev/stdout"
num_lines=10

while getopts ":vho:n:" opt; do
    case "$opt" in
        v) verbose=true ;;
        o) output="$OPTARG" ;;
        n) num_lines="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
        ?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Remaining arguments
input_file="${1:-}"
[[ -z "$input_file" ]] && { usage; exit 1; }

$verbose && echo "Processing $input_file with $num_lines lines..."
head -n "$num_lines" "$input_file" > "$output"
$verbose && echo "Done."
```

### 16.8 Long Options with Manual Parsing

```bash
#!/bin/bash

verbose=false
output=""
config=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            verbose=true
            shift
            ;;
        --output|-o)
            output="$2"
            shift 2
            ;;
        --config=*)
            config="${1#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--output FILE] [--config=FILE]"
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

echo "Verbose: $verbose"
echo "Output: $output"
echo "Config: $config"
echo "Remaining args: $@"
```

---

## 17. Practical Real-World Examples

### 17.1 Log File Analyzer

Analyzes a log file for patterns, counts errors, and produces a summary report.

```bash
#!/bin/bash
set -euo pipefail

LOG_FILE="${1:?Usage: $0 <logfile>}"

[[ -f "$LOG_FILE" ]] || { echo "File not found: $LOG_FILE" >&2; exit 1; }

total_lines=$(wc -l < "$LOG_FILE")
error_count=$(grep -ci "error" "$LOG_FILE" || true)
warn_count=$(grep -ci "warn" "$LOG_FILE" || true)
info_count=$(grep -ci "info" "$LOG_FILE" || true)

first_entry=$(head -1 "$LOG_FILE")
last_entry=$(tail -1 "$LOG_FILE")

cat << EOF
╔══════════════════════════════════════╗
║         LOG FILE ANALYSIS            ║
╠══════════════════════════════════════╣
  File:       $LOG_FILE
  Total Lines: $total_lines

  ERROR count: $error_count
  WARN  count: $warn_count
  INFO  count: $info_count

  First entry: ${first_entry:0:60}
  Last entry:  ${last_entry:0:60}
╚══════════════════════════════════════╝
EOF

if (( error_count > 0 )); then
    echo ""
    echo "=== Last 5 Errors ==="
    grep -i "error" "$LOG_FILE" | tail -5
fi
```

### 17.2 Backup Script with Rotation

Creates compressed backups with automatic rotation (keeps the last N backups).

```bash
#!/bin/bash
set -euo pipefail

SOURCE_DIR="${1:?Usage: $0 <source_dir> [backup_dir] [max_backups]}"
BACKUP_DIR="${2:-/tmp/backups}"
MAX_BACKUPS="${3:-5}"

readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_NAME="backup_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating backup of '$SOURCE_DIR'..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

backup_size=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}" | cut -f1)
echo "Backup created: ${BACKUP_NAME} (${backup_size})"

backup_count=$(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | wc -l)
if (( backup_count > MAX_BACKUPS )); then
    remove_count=$(( backup_count - MAX_BACKUPS ))
    echo "Rotating: removing $remove_count old backup(s)..."
    ls -1t "$BACKUP_DIR"/backup_*.tar.gz | tail -n "$remove_count" | while read -r old; do
        echo "  Removing: $(basename "$old")"
        rm -f "$old"
    done
fi

echo ""
echo "Current backups:"
ls -lh "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}'
echo "Total: $(ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | wc -l) / $MAX_BACKUPS"
```

### 17.3 System Health Monitor

Monitors CPU, memory, disk, and network and provides color-coded output.

```bash
#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

color_by_threshold() {
    local value=$1 warn=$2 crit=$3
    if (( value >= crit )); then
        echo -e "${RED}${value}%${NC}"
    elif (( value >= warn )); then
        echo -e "${YELLOW}${value}%${NC}"
    else
        echo -e "${GREEN}${value}%${NC}"
    fi
}

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       SYSTEM HEALTH MONITOR          ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC} Hostname: $(hostname)"
echo -e "${BLUE}║${NC} Date:     $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BLUE}║${NC} Uptime:   $(uptime -p 2>/dev/null || uptime | sed 's/.*up/up/')"
echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"

# CPU
if command -v mpstat &>/dev/null; then
    cpu_idle=$(mpstat 1 1 2>/dev/null | awk '/Average/ {print $NF}' | head -1)
    cpu_used=$(echo "100 - ${cpu_idle:-0}" | bc 2>/dev/null | cut -d. -f1)
else
    cpu_used=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2)}')
fi
cpu_used=${cpu_used:-0}
echo -e "${BLUE}║${NC} CPU Usage:    $(color_by_threshold "$cpu_used" 70 90)"

# Memory
if command -v free &>/dev/null; then
    mem_info=$(free | awk '/^Mem:/ {printf "%d %d %d", $2, $3, $3*100/$2}')
    read -r mem_total mem_used mem_pct <<< "$mem_info"
    echo -e "${BLUE}║${NC} Memory:       $(color_by_threshold "$mem_pct" 70 90)  ($(free -h | awk '/^Mem:/{print $3 "/" $2}'))"
fi

# Disk
disk_pct=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
echo -e "${BLUE}║${NC} Disk (/) :    $(color_by_threshold "$disk_pct" 70 90)  ($(df -h / | awk 'NR==2{print $3 "/" $2}'))"

# Load average
load=$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || uptime | awk -F'load average:' '{print $2}')
echo -e "${BLUE}║${NC} Load Avg:     $load"

# Network connectivity
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "${BLUE}║${NC} Internet:     ${GREEN}Connected${NC}"
else
    echo -e "${BLUE}║${NC} Internet:     ${RED}Disconnected${NC}"
fi

# Top processes by CPU
echo -e "${BLUE}╠══════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC} Top 5 Processes (CPU):"
ps aux --sort=-%cpu 2>/dev/null | head -6 | awk 'NR>1 {printf "  %-12s %5s%% CPU  %5s%% MEM\n", $11, $3, $4}'

echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
```

### 17.4 Batch File Renamer

Renames files in bulk using patterns, with preview and undo support.

```bash
#!/bin/bash
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: batch_rename.sh [OPTIONS] <directory>

Options:
    -p PATTERN     Search pattern (regex)
    -r REPLACE     Replacement string
    -e EXTENSION   Filter by extension (e.g., "jpg")
    -l             Convert filenames to lowercase
    -u             Convert filenames to uppercase
    -d             Dry run (preview changes)
    -h             Show this help

Examples:
    batch_rename.sh -p "IMG_" -r "photo_" -d /photos
    batch_rename.sh -l -e jpg /photos
    batch_rename.sh -p '\s+' -r '_' /documents
EOF
}

pattern=""
replace=""
extension=""
lowercase=false
uppercase=false
dry_run=false

while getopts ":p:r:e:ludh" opt; do
    case "$opt" in
        p) pattern="$OPTARG" ;;
        r) replace="$OPTARG" ;;
        e) extension="$OPTARG" ;;
        l) lowercase=true ;;
        u) uppercase=true ;;
        d) dry_run=true ;;
        h) usage; exit 0 ;;
        *) echo "Unknown option: -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

target_dir="${1:-.}"
[[ -d "$target_dir" ]] || { echo "Directory not found: $target_dir" >&2; exit 1; }

count=0
undo_script="$target_dir/.undo_rename.sh"
$dry_run || echo "#!/bin/bash" > "$undo_script"

find "$target_dir" -maxdepth 1 -type f | while read -r filepath; do
    dir=$(dirname "$filepath")
    filename=$(basename "$filepath")

    # Filter by extension
    if [[ -n "$extension" ]]; then
        [[ "$filename" == *."$extension" ]] || continue
    fi

    new_name="$filename"

    # Apply pattern replacement
    if [[ -n "$pattern" ]]; then
        new_name=$(echo "$new_name" | sed -E "s/$pattern/$replace/g")
    fi

    # Apply case conversion
    $lowercase && new_name="${new_name,,}"
    $uppercase && new_name="${new_name^^}"

    # Skip if name unchanged
    [[ "$new_name" == "$filename" ]] && continue

    ((count++)) || true
    if $dry_run; then
        echo "[DRY RUN] $filename -> $new_name"
    else
        mv "$filepath" "$dir/$new_name"
        echo "mv '$dir/$new_name' '$dir/$filename'" >> "$undo_script"
        echo "Renamed: $filename -> $new_name"
    fi
done

echo ""
echo "Total: $count file(s) ${dry_run:+would be }renamed"
$dry_run || { chmod +x "$undo_script"; echo "Undo script: $undo_script"; }
```

### 17.5 CSV Processor

Reads, filters, sorts, and summarizes CSV data.

```bash
#!/bin/bash
set -euo pipefail

CSV_FILE="${1:?Usage: $0 <csv_file> [column_number] [filter_value]}"
COLUMN="${2:-}"
FILTER="${3:-}"

[[ -f "$CSV_FILE" ]] || { echo "File not found: $CSV_FILE" >&2; exit 1; }

header=$(head -1 "$CSV_FILE")
separator=","

# Detect separator
if [[ "$header" == *$'\t'* ]]; then
    separator=$'\t'
elif [[ "$header" == *";"* ]]; then
    separator=";"
fi

IFS="$separator" read -ra columns <<< "$header"
num_columns=${#columns[@]}
num_rows=$(( $(wc -l < "$CSV_FILE") - 1 ))

echo "╔══════════════════════════════════════╗"
echo "║          CSV FILE SUMMARY            ║"
echo "╠══════════════════════════════════════╣"
echo "  File:    $CSV_FILE"
echo "  Rows:    $num_rows"
echo "  Columns: $num_columns"
echo ""
echo "  Column Headers:"
for i in "${!columns[@]}"; do
    echo "    [$((i+1))] ${columns[$i]}"
done
echo "╚══════════════════════════════════════╝"

# Show data preview
echo ""
echo "=== Data Preview (first 5 rows) ==="
head -6 "$CSV_FILE" | column -t -s"$separator" 2>/dev/null || head -6 "$CSV_FILE"

# Filter by column value if specified
if [[ -n "$COLUMN" && -n "$FILTER" ]]; then
    echo ""
    echo "=== Filtered Results (column $COLUMN = '$FILTER') ==="
    awk -F"$separator" -v col="$COLUMN" -v val="$FILTER" \
        'NR==1 || $col ~ val' "$CSV_FILE" | column -t -s"$separator" 2>/dev/null
fi

# Numeric column summary
if [[ -n "$COLUMN" && -z "$FILTER" ]]; then
    echo ""
    echo "=== Statistics for Column $COLUMN (${columns[$((COLUMN-1))]}) ==="
    awk -F"$separator" -v col="$COLUMN" '
    NR > 1 && $col ~ /^[0-9.]+$/ {
        sum += $col
        count++
        if (count == 1 || $col < min) min = $col
        if (count == 1 || $col > max) max = $col
    }
    END {
        if (count > 0) {
            printf "  Count: %d\n", count
            printf "  Sum:   %.2f\n", sum
            printf "  Avg:   %.2f\n", sum/count
            printf "  Min:   %.2f\n", min
            printf "  Max:   %.2f\n", max
        } else {
            print "  No numeric data found in this column"
        }
    }' "$CSV_FILE"
fi
```

### 17.6 Multi-Server Command Executor

Runs a command on multiple remote servers (requires SSH access).

```bash
#!/bin/bash
set -euo pipefail

SERVERS_FILE="${1:?Usage: $0 <servers_file> <command>}"
REMOTE_CMD="${2:?Usage: $0 <servers_file> <command>}"
TIMEOUT="${SSH_TIMEOUT:-10}"
MAX_PARALLEL="${MAX_PARALLEL:-5}"

[[ -f "$SERVERS_FILE" ]] || { echo "Servers file not found: $SERVERS_FILE" >&2; exit 1; }

results_dir=$(mktemp -d)
trap 'rm -rf "$results_dir"' EXIT

run_on_server() {
    local server="$1"
    local output_file="$results_dir/$(echo "$server" | tr '@:' '_').out"
    local status_file="$results_dir/$(echo "$server" | tr '@:' '_').status"

    if timeout "$TIMEOUT" ssh -o ConnectTimeout=5 \
         -o StrictHostKeyChecking=no \
         -o BatchMode=yes \
         "$server" "$REMOTE_CMD" > "$output_file" 2>&1; then
        echo "SUCCESS" > "$status_file"
    else
        echo "FAILED" > "$status_file"
    fi
}

echo "Executing on remote servers: $REMOTE_CMD"
echo "========================================"

while IFS= read -r server; do
    [[ -z "$server" || "$server" == \#* ]] && continue

    while (( $(jobs -rp | wc -l) >= MAX_PARALLEL )); do
        sleep 0.1
    done

    run_on_server "$server" &
    echo "  [STARTED] $server"
done < "$SERVERS_FILE"

wait

echo ""
echo "========================================"
echo "Results:"
echo "========================================"

success=0
failed=0

while IFS= read -r server; do
    [[ -z "$server" || "$server" == \#* ]] && continue

    safe_name=$(echo "$server" | tr '@:' '_')
    status=$(cat "$results_dir/${safe_name}.status" 2>/dev/null || echo "UNKNOWN")
    output=$(cat "$results_dir/${safe_name}.out" 2>/dev/null || echo "No output")

    if [[ "$status" == "SUCCESS" ]]; then
        echo -e "\033[32m[OK]\033[0m $server"
        ((success++))
    else
        echo -e "\033[31m[FAIL]\033[0m $server"
        ((failed++))
    fi
    echo "     $output" | head -3
    echo ""
done < "$SERVERS_FILE"

echo "========================================"
echo "Summary: $success succeeded, $failed failed"
```

### 17.7 Interactive Database Menu

A menu-driven script for managing a simple flat-file database.

```bash
#!/bin/bash
set -euo pipefail

DB_FILE="${1:-contacts.db}"
touch "$DB_FILE"

add_record() {
    read -p "Name: " name
    read -p "Email: " email
    read -p "Phone: " phone
    echo "${name}|${email}|${phone}|$(date +%Y-%m-%d)" >> "$DB_FILE"
    echo "Record added successfully."
}

list_records() {
    if [[ ! -s "$DB_FILE" ]]; then
        echo "No records found."
        return
    fi
    echo ""
    printf "%-5s %-20s %-30s %-15s %-12s\n" "ID" "Name" "Email" "Phone" "Added"
    printf "%s\n" "$(printf '─%.0s' {1..85})"
    local id=0
    while IFS='|' read -r name email phone date; do
        ((id++))
        printf "%-5s %-20s %-30s %-15s %-12s\n" "$id" "$name" "$email" "$phone" "$date"
    done < "$DB_FILE"
    echo ""
    echo "Total records: $id"
}

search_records() {
    read -p "Search term: " term
    echo ""
    local found=0
    while IFS='|' read -r name email phone date; do
        if echo "$name$email$phone" | grep -qi "$term"; then
            printf "Name: %s | Email: %s | Phone: %s | Added: %s\n" "$name" "$email" "$phone" "$date"
            ((found++))
        fi
    done < "$DB_FILE"
    echo ""
    echo "Found: $found record(s)"
}

delete_record() {
    list_records
    read -p "Enter record ID to delete: " id
    if [[ "$id" =~ ^[0-9]+$ ]]; then
        local total
        total=$(wc -l < "$DB_FILE")
        if (( id >= 1 && id <= total )); then
            sed -i "${id}d" "$DB_FILE"
            echo "Record $id deleted."
        else
            echo "Invalid ID."
        fi
    else
        echo "Please enter a valid number."
    fi
}

export_csv() {
    local csv_file="${DB_FILE%.db}.csv"
    echo "Name,Email,Phone,DateAdded" > "$csv_file"
    sed 's/|/,/g' "$DB_FILE" >> "$csv_file"
    echo "Exported to: $csv_file"
}

while true; do
    echo ""
    echo "╔══════════════════════════════╗"
    echo "║    CONTACT MANAGER v1.0      ║"
    echo "╠══════════════════════════════╣"
    echo "║  1. Add Contact              ║"
    echo "║  2. List Contacts            ║"
    echo "║  3. Search Contacts          ║"
    echo "║  4. Delete Contact           ║"
    echo "║  5. Export to CSV            ║"
    echo "║  6. Quit                     ║"
    echo "╚══════════════════════════════╝"

    read -p "Choose [1-6]: " choice
    case "$choice" in
        1) add_record ;;
        2) list_records ;;
        3) search_records ;;
        4) delete_record ;;
        5) export_csv ;;
        6) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done
```

### 17.8 Automated Deployment Script

Deploys an application with health checks, rollback support, and notifications.

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="${APP_NAME:-myapp}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/$APP_NAME}"
RELEASE_DIR="${DEPLOY_DIR}/releases"
SHARED_DIR="${DEPLOY_DIR}/shared"
CURRENT_LINK="${DEPLOY_DIR}/current"
KEEP_RELEASES="${KEEP_RELEASES:-5}"
LOG_FILE="${DEPLOY_DIR}/deploy.log"

readonly TIMESTAMP=$(date +%Y%m%d%H%M%S)
readonly RELEASE_PATH="${RELEASE_DIR}/${TIMESTAMP}"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

rollback() {
    log "ROLLBACK: Deployment failed, rolling back..."
    local previous
    previous=$(ls -1t "$RELEASE_DIR" 2>/dev/null | sed -n '2p')
    if [[ -n "$previous" ]]; then
        ln -sfn "${RELEASE_DIR}/${previous}" "$CURRENT_LINK"
        log "Rolled back to release: $previous"
    else
        log "No previous release available for rollback"
    fi
    rm -rf "$RELEASE_PATH"
    exit 1
}

trap rollback ERR

health_check() {
    local url="${1:-http://localhost:8080/health}"
    local retries="${2:-5}"
    local delay="${3:-3}"

    log "Running health check: $url"
    for (( i=1; i<=retries; i++ )); do
        if curl -sf "$url" > /dev/null 2>&1; then
            log "Health check passed (attempt $i/$retries)"
            return 0
        fi
        log "Health check attempt $i/$retries failed, retrying in ${delay}s..."
        sleep "$delay"
    done
    log "Health check FAILED after $retries attempts"
    return 1
}

cleanup_old_releases() {
    local count
    count=$(ls -1 "$RELEASE_DIR" 2>/dev/null | wc -l)
    if (( count > KEEP_RELEASES )); then
        local remove=$(( count - KEEP_RELEASES ))
        log "Cleaning up $remove old release(s)..."
        ls -1t "$RELEASE_DIR" | tail -n "$remove" | while read -r old; do
            rm -rf "${RELEASE_DIR}/${old}"
            log "  Removed: $old"
        done
    fi
}

log "╔══════════════════════════════════════╗"
log "║       DEPLOYMENT STARTING           ║"
log "╠══════════════════════════════════════╣"
log "║ App:     $APP_NAME"
log "║ Release: $TIMESTAMP"
log "╚══════════════════════════════════════╝"

# Step 1: Setup directories
log "Step 1: Setting up directories..."
mkdir -p "$RELEASE_PATH" "$SHARED_DIR/log" "$SHARED_DIR/config"

# Step 2: Deploy code (copy from current directory as example)
log "Step 2: Deploying code..."
# In practice: git clone, download artifact, etc.
# cp -r /path/to/build/* "$RELEASE_PATH/"

# Step 3: Link shared resources
log "Step 3: Linking shared resources..."
ln -sfn "$SHARED_DIR/log" "$RELEASE_PATH/log" 2>/dev/null || true
ln -sfn "$SHARED_DIR/config" "$RELEASE_PATH/config" 2>/dev/null || true

# Step 4: Switch to new release
log "Step 4: Switching symlink to new release..."
ln -sfn "$RELEASE_PATH" "$CURRENT_LINK"

# Step 5: Restart services (example)
log "Step 5: Restarting services..."
# systemctl restart "$APP_NAME" 2>/dev/null || true

# Step 6: Health check
# log "Step 6: Running health check..."
# health_check

# Step 7: Cleanup old releases
log "Step 7: Cleaning up old releases..."
cleanup_old_releases

log "╔══════════════════════════════════════╗"
log "║    DEPLOYMENT SUCCESSFUL!            ║"
log "╚══════════════════════════════════════╝"
```

---

## Quick Reference Cheat Sheet

### Variable Operations

| Operation                    | Syntax                         |
|------------------------------|--------------------------------|
| Assign                       | `var="value"`                  |
| Access                       | `$var` or `${var}`             |
| Default value                | `${var:-default}`              |
| Assign default               | `${var:=default}`              |
| Error if unset               | `${var:?error_msg}`            |
| String length                | `${#var}`                      |
| Substring                    | `${var:offset:length}`         |
| Replace first                | `${var/pattern/replacement}`   |
| Replace all                  | `${var//pattern/replacement}`  |
| Remove front (shortest)      | `${var#pattern}`               |
| Remove front (longest)       | `${var##pattern}`              |
| Remove back (shortest)       | `${var%pattern}`               |
| Remove back (longest)        | `${var%%pattern}`              |
| Uppercase                    | `${var^^}`                     |
| Lowercase                    | `${var,,}`                     |

### Test Conditions

| Category   | Test                       | Meaning                       |
|------------|---------------------------|-------------------------------|
| File       | `-e file`                  | Exists                        |
| File       | `-f file`                  | Regular file                  |
| File       | `-d file`                  | Directory                     |
| File       | `-r file`                  | Readable                      |
| File       | `-w file`                  | Writable                      |
| File       | `-x file`                  | Executable                    |
| File       | `-s file`                  | Non-empty                     |
| String     | `-z str`                   | Empty                         |
| String     | `-n str`                   | Non-empty                     |
| String     | `str1 == str2`             | Equal                         |
| String     | `str1 != str2`             | Not equal                     |
| Integer    | `n1 -eq n2`                | Equal                         |
| Integer    | `n1 -ne n2`                | Not equal                     |
| Integer    | `n1 -gt n2`                | Greater than                  |
| Integer    | `n1 -ge n2`                | Greater or equal              |
| Integer    | `n1 -lt n2`                | Less than                     |
| Integer    | `n1 -le n2`                | Less or equal                 |

### Common Patterns

```bash
# Safe file reading
while IFS= read -r line; do
    process "$line"
done < file.txt

# Find and process files
find . -name "*.log" -exec gzip {} \;

# Check command availability
command -v docker &>/dev/null || { echo "docker not found"; exit 1; }

# Retry pattern
retry() {
    local n=1 max=3 delay=2
    while true; do
        "$@" && break || {
            if (( n >= max )); then
                echo "Failed after $n attempts" >&2
                return 1
            fi
            echo "Attempt $n/$max failed. Retrying in ${delay}s..."
            ((n++))
            sleep $delay
            ((delay *= 2))
        }
    done
}

# Mutex / lock file
exec 200>/tmp/myscript.lock
flock -n 200 || { echo "Already running"; exit 1; }

# Timestamp logging
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
```

---

## Further Reading

- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [ShellCheck](https://www.shellcheck.net/) — Online shell script linter
- [Bash Hackers Wiki](https://wiki.bash-hackers.org/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

---

*This tutorial covers BASH version 4.0+ features. Some features (associative arrays, `${var,,}`, `${var^^}`, `coproc`, `mapfile`) require BASH 4.0 or later. Check your version with `bash --version`.*
