# Comprehensive BASH Programming Tutorial

## Table of Contents

- [Part 1: Foundations](#part-1-foundations)
  - [1.1 What is BASH?](#11-what-is-bash)
  - [1.2 Your First Script](#12-your-first-script)
  - [1.3 Variables](#13-variables)
  - [1.4 Data Types and Quoting](#14-data-types-and-quoting)
  - [1.5 Arithmetic Operations](#15-arithmetic-operations)
  - [1.6 User Input](#16-user-input)
- [Part 2: Control Flow](#part-2-control-flow)
  - [2.1 Conditional Statements (if/elif/else)](#21-conditional-statements-ifelifelse)
  - [2.2 Test Expressions](#22-test-expressions)
  - [2.3 Case Statements](#23-case-statements)
  - [2.4 Loops (for, while, until)](#24-loops-for-while-until)
  - [2.5 Loop Control (break, continue)](#25-loop-control-break-continue)
- [Part 3: Functions](#part-3-functions)
  - [3.1 Defining and Calling Functions](#31-defining-and-calling-functions)
  - [3.2 Function Arguments](#32-function-arguments)
  - [3.3 Return Values](#33-return-values)
  - [3.4 Variable Scope (local vs global)](#34-variable-scope-local-vs-global)
  - [3.5 Recursive Functions](#35-recursive-functions)
- [Part 4: Arrays and Strings](#part-4-arrays-and-strings)
  - [4.1 Indexed Arrays](#41-indexed-arrays)
  - [4.2 Associative Arrays](#42-associative-arrays)
  - [4.3 String Operations](#43-string-operations)
  - [4.4 Pattern Matching and Globbing](#44-pattern-matching-and-globbing)
- [Part 5: File and I/O Operations](#part-5-file-and-io-operations)
  - [5.1 File Test Operators](#51-file-test-operators)
  - [5.2 Reading and Writing Files](#52-reading-and-writing-files)
  - [5.3 I/O Redirection](#53-io-redirection)
  - [5.4 Pipes and Command Substitution](#54-pipes-and-command-substitution)
  - [5.5 Here Documents and Here Strings](#55-here-documents-and-here-strings)
- [Part 6: Advanced Topics](#part-6-advanced-topics)
  - [6.1 Regular Expressions](#61-regular-expressions)
  - [6.2 Process Management](#62-process-management)
  - [6.3 Signal Handling (trap)](#63-signal-handling-trap)
  - [6.4 Subshells and Command Grouping](#64-subshells-and-command-grouping)
  - [6.5 Debugging Techniques](#65-debugging-techniques)
  - [6.6 Error Handling](#66-error-handling)
  - [6.7 Working with sed and awk](#67-working-with-sed-and-awk)
- [Part 7: Practical Examples](#part-7-practical-examples)
  - [7.1 System Information Reporter](#71-system-information-reporter)
  - [7.2 Log File Analyzer](#72-log-file-analyzer)
  - [7.3 Automated Backup Script](#73-automated-backup-script)
  - [7.4 Directory Synchronizer](#74-directory-synchronizer)
  - [7.5 Service Health Monitor](#75-service-health-monitor)
  - [7.6 CSV Data Processor](#76-csv-data-processor)
  - [7.7 Interactive Menu System](#77-interactive-menu-system)
  - [7.8 Batch File Renamer](#78-batch-file-renamer)

---

## Part 1: Foundations

### 1.1 What is BASH?

**BASH** (Bourne Again SHell) is a command-line interpreter and scripting language for Unix-like operating systems. It is the default shell on most Linux distributions and macOS (prior to Catalina). BASH extends the original Bourne Shell (`sh`) with features from the Korn Shell (`ksh`) and C Shell (`csh`).

Key characteristics:
- **Interpreted language** -- scripts are executed line by line without compilation
- **Built-in commands** -- provides `cd`, `echo`, `read`, `test`, and many more
- **Scripting capabilities** -- variables, loops, conditionals, functions, and arrays
- **Job control** -- background processes, foreground/background switching
- **Command history and tab completion** -- interactive productivity features

Check your BASH version:

```bash
bash --version
echo "$BASH_VERSION"
```

### 1.2 Your First Script

Create a file named `hello.sh`:

```bash
#!/bin/bash
# This is a comment -- the line above is called a "shebang"

echo "Hello, World!"
echo "Today is $(date)"
echo "You are logged in as: $USER"
echo "Your home directory is: $HOME"
```

**The shebang (`#!/bin/bash`)** tells the operating system which interpreter to use. Without it, the system uses the current shell, which may not be BASH.

Make the script executable and run it:

```bash
chmod +x hello.sh
./hello.sh
```

Alternatively, you can run any script explicitly with:

```bash
bash hello.sh
```

### 1.3 Variables

BASH variables are untyped by default -- they store strings, and numeric operations are handled through special syntax.

#### Variable Assignment

```bash
#!/bin/bash

# Assignment: NO spaces around the '=' sign
name="Alice"
age=30
greeting="Hello, $name"

echo "$greeting"
echo "Age: $age"

# WRONG -- this will fail:
# name = "Alice"    # BASH interprets 'name' as a command
```

#### Variable Types

```bash
#!/bin/bash

# Regular variables
filename="report.txt"

# Read-only variables (constants)
declare -r PI=3.14159
# PI=3.0    # This would cause an error

# Integer variables
declare -i count=0
count=count+1       # Arithmetic without $(( )) because of -i
echo "Count: $count"  # Output: 1

# Environment variables (exported to child processes)
export DATABASE_URL="localhost:5432/mydb"

# Special variables
echo "Script name: $0"
echo "First argument: $1"
echo "All arguments: $@"
echo "Number of arguments: $#"
echo "Exit status of last command: $?"
echo "PID of current script: $$"
echo "PID of last background process: $!"
```

#### Variable Expansion

```bash
#!/bin/bash

name="World"

# Basic expansion
echo "Hello, $name"
echo "Hello, ${name}"    # Braces disambiguate the variable name

# Default values
echo "${unset_var:-default_value}"   # Use default if unset
echo "${unset_var:=default_value}"   # Assign default if unset
echo "${unset_var:+alt_value}"       # Use alt_value if SET
echo "${unset_var:?Error message}"   # Exit with error if unset

# String length
str="Hello, World!"
echo "Length: ${#str}"    # Output: 13

# Substring extraction
echo "${str:0:5}"    # Output: Hello
echo "${str:7}"      # Output: World!

# Variable indirection
var_name="greeting"
greeting="Hi there"
echo "${!var_name}"  # Output: Hi there
```

### 1.4 Data Types and Quoting

BASH treats almost everything as a string. Understanding quoting is critical.

```bash
#!/bin/bash

name="Alice"

# Double quotes: allow variable expansion and command substitution
echo "Hello, $name"          # Output: Hello, Alice
echo "Date: $(date +%F)"    # Output: Date: 2026-03-20

# Single quotes: everything is literal
echo 'Hello, $name'          # Output: Hello, $name
echo 'Date: $(date +%F)'    # Output: Date: $(date +%F)

# No quotes: word splitting and globbing occur
files=*.txt                   # Glob pattern NOT expanded during assignment
echo $files                   # Expands glob at echo time
echo "$files"                 # Output: *.txt (literal)

# Escaping special characters
echo "She said \"hello\""    # Output: She said "hello"
echo "Price: \$9.99"         # Output: Price: $9.99
echo "Backslash: \\"         # Output: Backslash: \

# $'...' ANSI-C quoting
echo $'Tab:\there'            # Inserts a literal tab
echo $'Line1\nLine2'          # Inserts a literal newline

# Preserving whitespace
text="  hello   world  "
echo $text                    # Output: hello world (whitespace collapsed)
echo "$text"                  # Output:   hello   world   (preserved)
```

### 1.5 Arithmetic Operations

```bash
#!/bin/bash

# $(( )) arithmetic expansion (preferred)
a=15
b=4

echo "Addition:       $((a + b))"      # 19
echo "Subtraction:    $((a - b))"      # 11
echo "Multiplication: $((a * b))"      # 60
echo "Division:       $((a / b))"      # 3 (integer division)
echo "Modulo:         $((a % b))"      # 3
echo "Exponentiation: $((a ** 2))"     # 225

# Increment and decrement
((a++))
echo "After increment: $a"             # 16
((a--))
echo "After decrement: $a"             # 15

# Compound assignment
((a += 10))
echo "After += 10: $a"                 # 25

# Bitwise operations
echo "AND:    $((12 & 10))"   # 8
echo "OR:     $((12 | 10))"   # 14
echo "XOR:    $((12 ^ 10))"   # 6
echo "NOT:    $((~12))"       # -13
echo "Shift:  $((1 << 4))"   # 16

# Ternary operator
x=10
result=$(( x > 5 ? 1 : 0 ))
echo "Ternary result: $result"         # 1

# Floating-point arithmetic (BASH only supports integers; use bc or awk)
result=$(echo "scale=4; 22/7" | bc)
echo "Pi approx: $result"              # 3.1428

result=$(awk "BEGIN {printf \"%.4f\", 22/7}")
echo "Pi approx: $result"              # 3.1429
```

### 1.6 User Input

```bash
#!/bin/bash

# Basic input
read -p "Enter your name: " name
echo "Hello, $name!"

# Silent input (for passwords)
read -sp "Enter password: " password
echo    # Print newline after silent input
echo "Password length: ${#password}"

# Input with timeout
if read -t 5 -p "Quick! Enter something (5 sec): " response; then
    echo "You entered: $response"
else
    echo "Too slow!"
fi

# Reading into multiple variables
echo "Enter first and last name:"
read first last
echo "First: $first, Last: $last"

# Reading with a custom delimiter
read -d ";" -p "Enter text (end with ;): " text
echo "You entered: $text"

# Reading into an array
echo "Enter three words:"
read -a words
echo "First word: ${words[0]}"
echo "All words: ${words[@]}"
```

---

## Part 2: Control Flow

### 2.1 Conditional Statements (if/elif/else)

```bash
#!/bin/bash

# Basic if statement
age=25

if [[ $age -ge 18 ]]; then
    echo "You are an adult."
fi

# if-else
if [[ $age -ge 65 ]]; then
    echo "Senior citizen."
else
    echo "Not a senior citizen."
fi

# if-elif-else
score=75

if [[ $score -ge 90 ]]; then
    echo "Grade: A"
elif [[ $score -ge 80 ]]; then
    echo "Grade: B"
elif [[ $score -ge 70 ]]; then
    echo "Grade: C"
elif [[ $score -ge 60 ]]; then
    echo "Grade: D"
else
    echo "Grade: F"
fi

# Combining conditions
name="Alice"
age=25

if [[ $name == "Alice" && $age -ge 18 ]]; then
    echo "$name is an adult."
fi

if [[ $name == "Bob" || $name == "Alice" ]]; then
    echo "Name is Bob or Alice."
fi

# Negation
if [[ ! -f "/tmp/nonexistent" ]]; then
    echo "File does not exist."
fi
```

### 2.2 Test Expressions

BASH provides several test constructs. Prefer `[[ ]]` over `[ ]` for BASH scripts.

```bash
#!/bin/bash

# String comparisons
str1="hello"
str2="world"

[[ $str1 == $str2 ]]  && echo "Equal"     || echo "Not equal"
[[ $str1 != $str2 ]]  && echo "Different" || echo "Same"
[[ $str1 < $str2 ]]   && echo "str1 sorts before str2"
[[ -z "$str1" ]]      && echo "Empty"     || echo "Not empty"
[[ -n "$str1" ]]      && echo "Not empty" || echo "Empty"

# Numeric comparisons
a=10
b=20

[[ $a -eq $b ]]  && echo "Equal"
[[ $a -ne $b ]]  && echo "Not equal"
[[ $a -lt $b ]]  && echo "a < b"
[[ $a -le $b ]]  && echo "a <= b"
[[ $a -gt $b ]]  && echo "a > b"
[[ $a -ge $b ]]  && echo "a >= b"

# Using (( )) for numeric comparisons (cleaner syntax)
if (( a < b )); then
    echo "$a is less than $b"
fi

# Pattern matching with [[ ]]
filename="report_2026.csv"
if [[ $filename == *.csv ]]; then
    echo "It's a CSV file."
fi

# Regex matching with =~
email="user@example.com"
if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "Valid email format."
fi
```

**Difference between `[ ]`, `[[ ]]`, and `(( ))`:**

| Feature | `[ ]` (test) | `[[ ]]` | `(( ))` |
|---|---|---|---|
| POSIX compliant | Yes | No (BASH) | No (BASH) |
| Word splitting | Yes | No | No |
| Pattern matching | No | `==`, `!=` | No |
| Regex | No | `=~` | No |
| Logical operators | `-a`, `-o` | `&&`, `\|\|` | `&&`, `\|\|` |
| Arithmetic | No | No | Yes |

### 2.3 Case Statements

```bash
#!/bin/bash

# Basic case statement
read -p "Enter a fruit: " fruit

case "$fruit" in
    apple)
        echo "Apples are red or green."
        ;;
    banana)
        echo "Bananas are yellow."
        ;;
    orange|tangerine)
        echo "Citrus fruit!"
        ;;
    *)
        echo "Unknown fruit: $fruit"
        ;;
esac

# Case with patterns
read -p "Enter a filename: " file

case "$file" in
    *.tar.gz|*.tgz)
        echo "Gzipped tarball"
        ;;
    *.tar.bz2)
        echo "Bzipped tarball"
        ;;
    *.zip)
        echo "ZIP archive"
        ;;
    *.jpg|*.jpeg|*.png|*.gif)
        echo "Image file"
        ;;
    *.sh)
        echo "Shell script"
        ;;
    *)
        echo "Unknown file type"
        ;;
esac

# Case with fall-through (;;&) and resume (;&)
value="yes"

case "$value" in
    y|yes)
        echo "Matched yes"
        ;;&                  # Continue testing remaining patterns
    y*)
        echo "Starts with y"
        ;;
esac
# Output:
#   Matched yes
#   Starts with y
```

### 2.4 Loops (for, while, until)

```bash
#!/bin/bash

# --- FOR LOOPS ---

# C-style for loop
for ((i = 0; i < 5; i++)); do
    echo "Iteration: $i"
done

# For-in loop with list
for color in red green blue yellow; do
    echo "Color: $color"
done

# Loop over a range (brace expansion)
for i in {1..10}; do
    echo "Number: $i"
done

# Range with step
for i in {0..100..10}; do
    echo "Value: $i"
done

# Loop over command output
for file in $(ls *.sh 2>/dev/null); do
    echo "Script: $file"
done

# Loop over array elements
fruits=("apple" "banana" "cherry" "date")
for fruit in "${fruits[@]}"; do
    echo "Fruit: $fruit"
done

# Loop over files (safer than parsing ls)
for file in /etc/*.conf; do
    [[ -f "$file" ]] && echo "Config: $file"
done

# --- WHILE LOOPS ---

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
    [[ $input == "quit" ]] && break
    echo "You said: $input"
done

# While with pipe (runs in subshell!)
count=0
echo -e "a\nb\nc" | while read -r line; do
    ((count++))
done
echo "Count: $count"  # 0! (subshell loses state)

# Fix: use process substitution
count=0
while read -r line; do
    ((count++))
done < <(echo -e "a\nb\nc")
echo "Count: $count"  # 3

# --- UNTIL LOOPS ---

# Until loop (runs while condition is FALSE)
x=1
until [[ $x -gt 5 ]]; do
    echo "x = $x"
    ((x++))
done
```

### 2.5 Loop Control (break, continue)

```bash
#!/bin/bash

# break -- exit the loop
for i in {1..10}; do
    if [[ $i -eq 6 ]]; then
        echo "Breaking at $i"
        break
    fi
    echo "i = $i"
done

# continue -- skip to next iteration
for i in {1..10}; do
    if (( i % 2 == 0 )); then
        continue
    fi
    echo "Odd: $i"
done

# break N -- break out of N nested loops
for i in {1..3}; do
    for j in {1..3}; do
        if [[ $i -eq 2 && $j -eq 2 ]]; then
            break 2   # Break out of both loops
        fi
        echo "i=$i, j=$j"
    done
done

# Labeled-loop pattern (using functions)
outer_loop() {
    for i in {1..5}; do
        for j in {1..5}; do
            if (( i * j > 10 )); then
                return
            fi
            echo "$i * $j = $((i * j))"
        done
    done
}
outer_loop
```

---

## Part 3: Functions

### 3.1 Defining and Calling Functions

```bash
#!/bin/bash

# Method 1: function keyword
function greet {
    echo "Hello from greet!"
}

# Method 2: parentheses syntax (preferred, POSIX-compatible)
say_goodbye() {
    echo "Goodbye!"
}

# Calling functions (no parentheses needed)
greet
say_goodbye
```

### 3.2 Function Arguments

```bash
#!/bin/bash

print_info() {
    echo "Function name: ${FUNCNAME[0]}"
    echo "Argument count: $#"
    echo "All arguments: $@"
    echo "First argument: $1"
    echo "Second argument: $2"
}

print_info "Alice" "30" "Engineer"

# Passing arrays to functions
process_array() {
    local -a arr=("$@")
    echo "Array has ${#arr[@]} elements"
    for item in "${arr[@]}"; do
        echo "  - $item"
    done
}

my_array=("one" "two" "three" "four")
process_array "${my_array[@]}"
```

### 3.3 Return Values

```bash
#!/bin/bash

# Return status (0-255 only; 0 = success)
is_even() {
    if (( $1 % 2 == 0 )); then
        return 0   # true/success
    else
        return 1   # false/failure
    fi
}

if is_even 42; then
    echo "42 is even"
fi

# Returning strings via stdout (command substitution captures them)
get_greeting() {
    local name="$1"
    echo "Hello, $name!"    # This is the "return value"
}

message=$(get_greeting "Alice")
echo "$message"

# Returning multiple values
get_dimensions() {
    echo "1920 1080"
}

read -r width height <<< "$(get_dimensions)"
echo "Width: $width, Height: $height"

# Returning via global variable (use sparingly)
divide() {
    if (( $2 == 0 )); then
        _result=""
        return 1
    fi
    _result=$(echo "scale=4; $1 / $2" | bc)
    return 0
}

if divide 22 7; then
    echo "Result: $_result"
fi
```

### 3.4 Variable Scope (local vs global)

```bash
#!/bin/bash

global_var="I'm global"

my_function() {
    local local_var="I'm local"
    global_var="Modified by function"
    echo "Inside function: local_var=$local_var"
    echo "Inside function: global_var=$global_var"
}

echo "Before: global_var=$global_var"
my_function
echo "After: global_var=$global_var"
echo "After: local_var=$local_var"   # Empty -- local_var is scoped to the function

# Dynamic scoping: local variables are visible in called functions
outer() {
    local x="from outer"
    inner
}

inner() {
    echo "inner sees x='$x'"   # Can see outer's local x
}

outer   # Output: inner sees x='from outer'

# Use local -n for nameref (pass by reference, BASH 4.3+)
swap() {
    local -n ref1=$1
    local -n ref2=$2
    local tmp="$ref1"
    ref1="$ref2"
    ref2="$tmp"
}

a="first"
b="second"
swap a b
echo "a=$a, b=$b"   # a=second, b=first
```

### 3.5 Recursive Functions

```bash
#!/bin/bash

# Factorial
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

# Fibonacci
fibonacci() {
    local n=$1
    if (( n <= 0 )); then
        echo 0
    elif (( n == 1 )); then
        echo 1
    else
        local a b
        a=$(fibonacci $((n - 1)))
        b=$(fibonacci $((n - 2)))
        echo $((a + b))
    fi
}

echo "fib(10) = $(fibonacci 10)"  # 55

# Recursive directory tree
print_tree() {
    local dir="$1"
    local indent="${2:-}"

    for entry in "$dir"/*; do
        [[ -e "$entry" ]] || continue
        local base
        base=$(basename "$entry")
        if [[ -d "$entry" ]]; then
            echo "${indent}+-- $base/"
            print_tree "$entry" "${indent}|   "
        else
            echo "${indent}+-- $base"
        fi
    done
}

# Usage: print_tree /some/directory
```

---

## Part 4: Arrays and Strings

### 4.1 Indexed Arrays

```bash
#!/bin/bash

# Declaration
fruits=("apple" "banana" "cherry" "date")

# Or individually
colors[0]="red"
colors[1]="green"
colors[2]="blue"

# Using declare
declare -a numbers=(10 20 30 40 50)

# Accessing elements
echo "First fruit: ${fruits[0]}"
echo "Third fruit: ${fruits[2]}"
echo "Last fruit: ${fruits[-1]}"

# All elements
echo "All fruits: ${fruits[@]}"
echo "All fruits (as single string): ${fruits[*]}"

# Array length
echo "Number of fruits: ${#fruits[@]}"

# Length of specific element
echo "Length of 'banana': ${#fruits[1]}"

# Slicing
echo "From index 1, 2 elements: ${fruits[@]:1:2}"   # banana cherry

# Adding elements
fruits+=("elderberry")
fruits+=("fig" "grape")

# Removing elements
unset 'fruits[1]'    # Removes "banana" (leaves a gap!)
echo "After unset: ${fruits[@]}"

# Iterating
for fruit in "${fruits[@]}"; do
    echo "  Fruit: $fruit"
done

# Iterating with index
for i in "${!fruits[@]}"; do
    echo "  fruits[$i] = ${fruits[$i]}"
done

# Copying an array
copy=("${fruits[@]}")

# Searching
if [[ " ${fruits[*]} " == *" cherry "* ]]; then
    echo "Found cherry!"
fi

# Sorting (via external command)
sorted=($(printf '%s\n' "${fruits[@]}" | sort))
echo "Sorted: ${sorted[@]}"
```

### 4.2 Associative Arrays

Associative arrays require BASH 4.0+.

```bash
#!/bin/bash

# Declaration (declare -A is required)
declare -A user
user[name]="Alice"
user[age]="30"
user[role]="Engineer"

# Or inline
declare -A config=(
    [host]="localhost"
    [port]="8080"
    [debug]="true"
)

# Accessing values
echo "Name: ${user[name]}"
echo "Port: ${config[port]}"

# All keys
echo "User keys: ${!user[@]}"

# All values
echo "User values: ${user[@]}"

# Number of entries
echo "Config entries: ${#config[@]}"

# Check if key exists
if [[ -v config[debug] ]]; then
    echo "debug key exists"
fi

# Iterating
for key in "${!config[@]}"; do
    echo "  $key = ${config[$key]}"
done

# Removing a key
unset 'config[debug]'

# Practical example: counting word frequencies
declare -A word_count
text="the cat sat on the mat the cat"
for word in $text; do
    ((word_count[$word]++))
done

for word in "${!word_count[@]}"; do
    echo "  '$word' appears ${word_count[$word]} time(s)"
done
```

### 4.3 String Operations

```bash
#!/bin/bash

str="Hello, World! Welcome to BASH programming."

# Length
echo "Length: ${#str}"

# Substring
echo "Substring: ${str:7:5}"       # World

# Search and replace
echo "Replace first: ${str/World/Universe}"
echo "Replace all:   ${str//o/0}"

# Remove pattern from beginning
filepath="/home/user/documents/report.tar.gz"
echo "Remove prefix: ${filepath#*/}"       # home/user/documents/report.tar.gz
echo "Remove long prefix: ${filepath##*/}" # report.tar.gz

# Remove pattern from end
echo "Remove suffix: ${filepath%.*}"       # /home/user/documents/report.tar
echo "Remove long suffix: ${filepath%%.*}" # /home/user/documents/report

# Extracting filename and extension
filename="${filepath##*/}"
extension="${filename##*.}"
name_only="${filename%%.*}"
directory="${filepath%/*}"

echo "Directory: $directory"
echo "Filename:  $filename"
echo "Name:      $name_only"
echo "Extension: $extension"

# Case conversion (BASH 4.0+)
str="Hello World"
echo "Uppercase: ${str^^}"        # HELLO WORLD
echo "Lowercase: ${str,,}"        # hello world
echo "First upper: ${str^}"       # Hello World
echo "Toggle first: ${str~}"      # hello World (toggles first char)

# String concatenation
first="Hello"
second="World"
combined="$first, $second!"
echo "$combined"

# Repeat a string
printf '=%.0s' {1..40}
echo   # newline
printf 'abc%.0s' {1..5}
echo   # Output: abcabcabcabcabc
```

### 4.4 Pattern Matching and Globbing

```bash
#!/bin/bash

# Standard globs
echo *.txt         # All .txt files
echo file?.txt     # file1.txt, fileA.txt, etc.
echo file[0-9].txt # file0.txt through file9.txt

# Extended globs (enable with shopt)
shopt -s extglob

# ?(pattern) -- zero or one occurrence
echo file?(s).txt      # file.txt or files.txt

# *(pattern) -- zero or more
echo *(.[0-9])         # Matches ".1", ".12", etc.

# +(pattern) -- one or more
echo +(file|report)*   # Starts with "file" or "report"

# @(pattern) -- exactly one
echo @(file|report).txt  # file.txt or report.txt

# !(pattern) -- anything except
echo !(*.bak)            # Everything except .bak files

# Case-insensitive globbing
shopt -s nocaseglob
echo *.TXT             # Matches .txt, .TXT, .Txt, etc.
shopt -u nocaseglob

# Null glob (no error if no match)
shopt -s nullglob
for f in *.xyz; do
    echo "$f"          # No output if no .xyz files exist
done
shopt -u nullglob

# Glob in [[ ]] for pattern matching
file="report_2026_Q1.csv"
if [[ $file == report_????_Q[1-4].csv ]]; then
    echo "Matches quarterly report pattern"
fi
```

---

## Part 5: File and I/O Operations

### 5.1 File Test Operators

```bash
#!/bin/bash

file="/etc/passwd"
dir="/tmp"
link="/usr/bin/python"

# File existence
[[ -e "$file" ]] && echo "$file exists"
[[ -f "$file" ]] && echo "$file is a regular file"
[[ -d "$dir" ]]  && echo "$dir is a directory"
[[ -L "$link" ]] && echo "$link is a symbolic link"

# Permissions
[[ -r "$file" ]] && echo "$file is readable"
[[ -w "$file" ]] && echo "$file is writable"
[[ -x "$file" ]] && echo "$file is executable"

# File properties
[[ -s "$file" ]] && echo "$file is non-empty"
[[ -O "$file" ]] && echo "You own $file"
[[ -G "$file" ]] && echo "You're in the group of $file"

# Comparisons
file1="/etc/passwd"
file2="/etc/shadow"
[[ "$file1" -nt "$file2" ]] && echo "$file1 is newer"
[[ "$file1" -ot "$file2" ]] && echo "$file1 is older"
[[ "$file1" -ef "$file2" ]] && echo "Same file (hardlink)"
```

### 5.2 Reading and Writing Files

```bash
#!/bin/bash

# Writing to a file
echo "Line 1" > output.txt          # Overwrite
echo "Line 2" >> output.txt         # Append

# Writing multiple lines
cat > config.txt << 'EOF'
host=localhost
port=8080
debug=false
EOF

# Reading entire file into a variable
content=$(<output.txt)
echo "$content"

# Reading line by line
while IFS= read -r line; do
    echo "Read: $line"
done < output.txt

# Reading with line numbers
line_num=0
while IFS= read -r line; do
    ((line_num++))
    printf "%4d: %s\n" "$line_num" "$line"
done < output.txt

# Reading specific fields (CSV-like)
while IFS='=' read -r key value; do
    echo "Key: '$key', Value: '$value'"
done < config.txt

# Reading into an array
mapfile -t lines < output.txt
echo "Total lines: ${#lines[@]}"
echo "Second line: ${lines[1]}"

# Processing a file with awk-like field splitting
while read -r col1 col2 col3; do
    echo "Columns: $col1 | $col2 | $col3"
done <<< "alpha beta gamma
one two three"

# Safe temporary files
tmpfile=$(mktemp)
echo "Temp file: $tmpfile"
echo "some data" > "$tmpfile"
# ... process the file ...
rm -f "$tmpfile"

# Temporary file with trap for cleanup
cleanup() { rm -f "$TMPFILE"; }
trap cleanup EXIT
TMPFILE=$(mktemp)
```

### 5.3 I/O Redirection

```bash
#!/bin/bash

# Standard file descriptors:
#   0 = stdin
#   1 = stdout
#   2 = stderr

# Redirect stdout
echo "hello" > stdout.txt

# Redirect stderr
ls /nonexistent 2> stderr.txt

# Redirect both
command > stdout.txt 2> stderr.txt

# Redirect stderr to stdout (combine)
command > all_output.txt 2>&1

# Modern syntax for combining (BASH 4+)
command &> all_output.txt

# Append
echo "more" >> stdout.txt
command >> output.txt 2>&1

# Discard output
command > /dev/null          # Discard stdout
command 2> /dev/null         # Discard stderr
command &> /dev/null         # Discard all

# Redirect stdin
sort < unsorted.txt

# Custom file descriptors
exec 3> custom_output.txt    # Open FD 3 for writing
echo "line 1" >&3
echo "line 2" >&3
exec 3>&-                   # Close FD 3

exec 4< /etc/hostname       # Open FD 4 for reading
read -r hostname <&4
exec 4<&-                   # Close FD 4
echo "Hostname: $hostname"

# Read/write file descriptor
exec 5<> readwrite.txt       # Open FD 5 for read/write
echo "data" >&5
exec 5<&-

# Swap stdout and stderr
command 3>&1 1>&2 2>&3 3>&-
```

### 5.4 Pipes and Command Substitution

```bash
#!/bin/bash

# Pipes: stdout of one command becomes stdin of the next
cat /etc/passwd | grep "root" | cut -d: -f1

# Multiple pipes
ps aux | sort -k4 -rn | head -5   # Top 5 processes by memory

# Named pipes (FIFOs)
mkfifo /tmp/mypipe
echo "Hello through pipe" > /tmp/mypipe &
cat /tmp/mypipe                    # Reads the data
rm /tmp/mypipe

# Command substitution: $() captures stdout of a command
today=$(date +%Y-%m-%d)
echo "Today is $today"

file_count=$(ls -1 | wc -l)
echo "Files in directory: $file_count"

# Nested command substitution
echo "Kernel: $(uname -r) on $(uname -s)"

# Backtick syntax (older, less readable, harder to nest)
today=`date +%Y-%m-%d`

# Process substitution: <() creates a temporary file-like object
diff <(ls /usr/bin) <(ls /usr/sbin)

# Comparing sorted outputs
comm <(sort file1.txt) <(sort file2.txt)

# Using process substitution to avoid subshell
while read -r line; do
    echo "$line"
done < <(find /tmp -maxdepth 1 -type f)

# PIPESTATUS: exit codes of all pipe components
false | true | false
echo "Exit codes: ${PIPESTATUS[0]} ${PIPESTATUS[1]} ${PIPESTATUS[2]}"
# Output: 1 0 1

# pipefail: make pipe return the last non-zero exit code
set -o pipefail
false | true
echo "Pipe exit code: $?"  # 1 (without pipefail it would be 0)
set +o pipefail
```

### 5.5 Here Documents and Here Strings

```bash
#!/bin/bash

# Here document: multi-line input
cat << EOF
Hello, $USER!
Today is $(date +%A).
Your home directory is $HOME.
EOF

# Here document with suppressed expansion (quoted delimiter)
cat << 'EOF'
This $variable won't expand.
Neither will $(this command).
Everything is literal.
EOF

# Here document with indentation stripping (<<-)
if true; then
    cat <<-EOF
	This is indented with tabs.
	The tabs before text are stripped.
	EOF
fi

# Here string: single-line input
read -r first rest <<< "Hello World BASH"
echo "First word: $first"     # Hello
echo "Rest: $rest"            # World BASH

# Practical: feeding a string into a command
bc <<< "scale=4; 22/7"

# Feeding a variable into a loop
data="line1
line2
line3"
while read -r line; do
    echo "Processing: $line"
done <<< "$data"

# Here document into a variable
read -r -d '' html << 'EOF'
<html>
<head><title>Test</title></head>
<body><h1>Hello</h1></body>
</html>
EOF
echo "$html"
```

---

## Part 6: Advanced Topics

### 6.1 Regular Expressions

```bash
#!/bin/bash

# BASH regex with [[ =~ ]]
string="Error: file not found at line 42"

if [[ $string =~ ^Error:\ (.+)\ at\ line\ ([0-9]+)$ ]]; then
    echo "Full match: ${BASH_REMATCH[0]}"
    echo "Message: ${BASH_REMATCH[1]}"
    echo "Line number: ${BASH_REMATCH[2]}"
fi

# Validating an IP address
validate_ip() {
    local ip=$1
    local octet="(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
    local regex="^${octet}\.${octet}\.${octet}\.${octet}$"

    if [[ $ip =~ $regex ]]; then
        echo "$ip is a valid IPv4 address"
        return 0
    else
        echo "$ip is NOT a valid IPv4 address"
        return 1
    fi
}

validate_ip "192.168.1.100"
validate_ip "256.1.2.3"
validate_ip "10.0.0.1"

# Extracting data from structured text
log_entry='2026-03-20 14:30:15 [WARNING] Disk usage at 85%'

if [[ $log_entry =~ ^([0-9-]+)\ ([0-9:]+)\ \[([A-Z]+)\]\ (.+)$ ]]; then
    echo "Date: ${BASH_REMATCH[1]}"
    echo "Time: ${BASH_REMATCH[2]}"
    echo "Level: ${BASH_REMATCH[3]}"
    echo "Message: ${BASH_REMATCH[4]}"
fi

# Using regex in a loop for validation
valid_usernames=()
for name in "alice" "bob_123" "inv@lid" "root" "bad name" "charlie"; do
    if [[ $name =~ ^[a-z][a-z0-9_]{2,15}$ ]]; then
        valid_usernames+=("$name")
    fi
done
echo "Valid usernames: ${valid_usernames[*]}"
```

### 6.2 Process Management

```bash
#!/bin/bash

# Running a process in the background
sleep 60 &
bg_pid=$!
echo "Background process PID: $bg_pid"

# Wait for a specific process
wait "$bg_pid"
echo "Process $bg_pid finished with status $?"

# Wait for all background processes
for i in {1..5}; do
    sleep $((RANDOM % 3 + 1)) &
done
wait
echo "All background processes complete"

# Job control
sleep 100 &
jobs               # List background jobs
# kill %1          # Kill job number 1

# Process information
echo "Current PID: $$"
echo "Parent PID: $PPID"

# Check if a process is running
is_running() {
    kill -0 "$1" 2>/dev/null
}

sleep 5 &
pid=$!
if is_running "$pid"; then
    echo "Process $pid is running"
fi

# Parallel execution with wait
parallel_tasks() {
    local pids=()

    task1() { sleep 2; echo "Task 1 done"; }
    task2() { sleep 1; echo "Task 2 done"; }
    task3() { sleep 3; echo "Task 3 done"; }

    task1 &
    pids+=($!)
    task2 &
    pids+=($!)
    task3 &
    pids+=($!)

    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done

    echo "Finished: $failed task(s) failed"
}

parallel_tasks

# Coprocesses (BASH 4+)
coproc bc_proc { bc -l; }
echo "scale=4; 22/7" >&"${bc_proc[1]}"
read -r result <&"${bc_proc[0]}"
echo "Pi: $result"
kill "$bc_proc_PID" 2>/dev/null
```

### 6.3 Signal Handling (trap)

```bash
#!/bin/bash

# Trap syntax: trap 'commands' SIGNAL [SIGNAL ...]

# Cleanup on exit
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"; echo "Cleaned up."' EXIT

echo "Working with $tmpfile"
echo "data" > "$tmpfile"
# tmpfile is automatically removed when the script exits

# Trap multiple signals
trap 'echo "Caught SIGINT (Ctrl+C)"; exit 1' INT
trap 'echo "Caught SIGTERM"; exit 1' TERM
trap 'echo "Caught SIGHUP"' HUP

# Ignore a signal
trap '' INT     # Ctrl+C is now ignored

# Reset a trap to default behavior
trap - INT      # Restore default SIGINT behavior

# Trap ERR for error handling
trap 'echo "Error at line $LINENO, command: $BASH_COMMAND"' ERR

# Practical: graceful shutdown
shutdown_requested=false

handle_shutdown() {
    echo "Shutdown requested..."
    shutdown_requested=true
}

trap handle_shutdown SIGTERM SIGINT

while ! $shutdown_requested; do
    echo "Working... (PID: $$)"
    sleep 2
done

echo "Gracefully shutting down."

# Trap DEBUG: runs before every command
trap 'echo "+ $BASH_COMMAND"' DEBUG
# This acts like set -x but with more control
```

### 6.4 Subshells and Command Grouping

```bash
#!/bin/bash

# Subshell: commands in ( ) run in a child process
x=10
(
    x=20
    echo "Inside subshell: x=$x"    # 20
)
echo "Outside subshell: x=$x"       # 10 (unchanged)

# Subshell for temporary state changes
(
    cd /tmp
    export LANG=C
    # Changes to directory and environment are local to the subshell
    pwd
)
pwd   # Back to original directory

# Command grouping with { }: runs in current shell
{
    echo "Line 1"
    echo "Line 2"
    echo "Line 3"
} > output.txt    # Redirect all output together

# Combining output
{
    echo "=== Report ==="
    date
    echo "=== Uptime ==="
    uptime
} | tee report.txt

# Subshell vs grouping: variable behavior
val="original"

# Subshell (won't modify parent)
( val="subshell"; echo "In (): $val" )
echo "After (): $val"     # original

# Grouping (modifies current shell)
{ val="grouped"; echo "In {}: $val"; }
echo "After {}: $val"     # grouped

# Practical: isolating failures
(
    set -e
    false     # This will cause the subshell to exit
    echo "This won't print"
)
echo "Script continues after subshell failure"
```

### 6.5 Debugging Techniques

```bash
#!/bin/bash

# Enable debug mode for the entire script
# set -x         # Print each command before execution
# set -v         # Print each line as read

# Enable for a section only
set -x
echo "This command is traced"
ls /tmp > /dev/null
set +x
echo "This is not traced"

# Using PS4 for better debug output
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x
echo "Enhanced debug output"
set +x

# Debug a specific function
debug_function() {
    local orig_opts="$-"
    set -x

    echo "Step 1"
    echo "Step 2"
    local result=$((2 + 2))
    echo "Result: $result"

    # Restore original options
    [[ "$orig_opts" != *x* ]] && set +x
}

# Conditional debugging
DEBUG=${DEBUG:-false}

debug_log() {
    if $DEBUG; then
        echo "[DEBUG] $*" >&2
    fi
}

debug_log "This is a debug message"
# Run with: DEBUG=true ./script.sh

# Using trap for line-by-line tracing
trace() {
    echo "TRACE: Line $1: $2" >&2
}
# trap 'trace $LINENO "$BASH_COMMAND"' DEBUG

# Assert function for testing assumptions
assert() {
    local condition=$1
    local message=${2:-"Assertion failed"}

    if ! eval "$condition"; then
        echo "ASSERTION FAILED: $message" >&2
        echo "  Condition: $condition" >&2
        echo "  Location: ${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >&2
        return 1
    fi
}

x=5
assert '[[ $x -eq 5 ]]' "x should be 5"
assert '[[ $x -gt 0 ]]' "x should be positive"
```

### 6.6 Error Handling

```bash
#!/bin/bash

# Strict mode -- highly recommended for scripts
set -euo pipefail

# set -e : exit on any command failure
# set -u : treat unset variables as errors
# set -o pipefail : pipe fails if any component fails

# Custom error handler
error_handler() {
    local line=$1
    local cmd=$2
    local code=$3
    echo "Error on line $line: command '$cmd' exited with status $code" >&2
}
trap 'error_handler $LINENO "$BASH_COMMAND" $?' ERR

# Try/catch pattern
try() {
    "$@"
    return $?
}

catch() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "Caught error (exit code: $exit_code): $*" >&2
    fi
    return $exit_code
}

# Usage
if output=$(try ls /nonexistent 2>&1); then
    echo "Success: $output"
else
    catch "Failed to list directory"
fi

# Retry pattern
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local cmd=("$@")

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        if "${cmd[@]}"; then
            return 0
        fi
        echo "Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..." >&2
        sleep "$delay"
    done

    echo "All $max_attempts attempts failed." >&2
    return 1
}

# retry 3 2 curl -s http://example.com

# Die function
die() {
    echo "FATAL: $*" >&2
    exit 1
}

[[ -f "/etc/passwd" ]] || die "Cannot find /etc/passwd"

# Cleanup stack pattern
declare -a CLEANUP_COMMANDS=()

push_cleanup() {
    CLEANUP_COMMANDS+=("$1")
}

run_cleanup() {
    for ((i = ${#CLEANUP_COMMANDS[@]} - 1; i >= 0; i--)); do
        eval "${CLEANUP_COMMANDS[$i]}" || true
    done
}

trap run_cleanup EXIT

tmpdir=$(mktemp -d)
push_cleanup "rm -rf '$tmpdir'"

tmpfile=$(mktemp)
push_cleanup "rm -f '$tmpfile'"
```

### 6.7 Working with sed and awk

```bash
#!/bin/bash

# === SED (Stream Editor) ===

# Substitute first occurrence on each line
echo "hello world hello" | sed 's/hello/hi/'          # hi world hello

# Substitute all occurrences
echo "hello world hello" | sed 's/hello/hi/g'          # hi world hi

# Case-insensitive substitution
echo "Hello HELLO hello" | sed 's/hello/hi/gi'         # hi hi hi

# Delete lines matching a pattern
sed '/^#/d' config.txt            # Remove comment lines

# Print only matching lines (like grep)
sed -n '/error/p' logfile.txt

# In-place editing
# sed -i 's/old/new/g' file.txt          # Linux
# sed -i '' 's/old/new/g' file.txt       # macOS

# Multiple operations
sed -e 's/foo/bar/g' -e 's/baz/qux/g' file.txt

# Line ranges
sed '2,5s/old/new/g' file.txt     # Lines 2-5 only
sed '3d' file.txt                 # Delete line 3
sed '1i\Header Line' file.txt     # Insert before line 1
sed '$a\Footer Line' file.txt     # Append after last line

# Extract text between markers
sed -n '/START/,/END/p' file.txt

# Back-references
echo "2026-03-20" | sed 's/\([0-9]*\)-\([0-9]*\)-\([0-9]*\)/\3\/\2\/\1/'
# Output: 20/03/2026


# === AWK (Pattern scanning and processing) ===

# Print specific columns
echo "Alice 30 Engineer" | awk '{print $1, $3}'        # Alice Engineer

# Custom field separator
echo "Alice:30:Engineer" | awk -F: '{print $1, $3}'    # Alice Engineer

# Pattern matching
awk '/error/ {print}' logfile.txt

# Conditional processing
awk '$3 > 50 {print $1, $3}' data.txt

# Built-in variables
echo -e "a\nb\nc" | awk '{print NR": "$0}'
# 1: a
# 2: b
# 3: c

# BEGIN and END blocks
awk 'BEGIN {sum=0} {sum+=$1} END {print "Sum:", sum}' <<< "10
20
30"
# Output: Sum: 60

# Computing averages
awk '{sum+=$1; count++} END {print "Average:", sum/count}' <<< "10
20
30
40"
# Output: Average: 25

# Reformatting output
ps aux | awk 'NR>1 {printf "%-10s %5s %5s %s\n", $1, $3, $4, $11}' | head -5

# Multi-rule AWK programs
awk '
    /^#/  { next }                    # Skip comments
    NF==0 { next }                    # Skip empty lines
    { gsub(/^[[:space:]]+/, ""); print }  # Trim and print
' config.txt

# Associative arrays in AWK
echo -e "apple\nbanana\napple\ncherry\napple\nbanana" | \
    awk '{count[$1]++} END {for (word in count) print word, count[word]}'
```

---

## Part 7: Practical Examples

The following are complete, real-world scripts that demonstrate how to combine multiple BASH concepts into useful tools. Each script is also available in the `examples/` directory.

### 7.1 System Information Reporter

A script that gathers and displays comprehensive system information.

```bash
#!/bin/bash
# system_info.sh -- Collect and display system information

set -euo pipefail

SEPARATOR=$(printf '=%.0s' {1..60})

section() {
    echo ""
    echo "$SEPARATOR"
    echo "  $1"
    echo "$SEPARATOR"
}

section "SYSTEM INFORMATION"
echo "Hostname:      $(hostname)"
echo "Kernel:        $(uname -r)"
echo "Architecture:  $(uname -m)"
echo "OS:            $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)"
echo "Uptime:        $(uptime -p 2>/dev/null || uptime)"
echo "Current User:  $USER"
echo "Date/Time:     $(date '+%Y-%m-%d %H:%M:%S %Z')"

section "CPU INFORMATION"
if [[ -f /proc/cpuinfo ]]; then
    cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
    echo "Model:  $cpu_model"
    echo "Cores:  $cpu_cores"
else
    sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "CPU info unavailable"
fi

load_avg=$(uptime | grep -oP 'load average: \K.*')
echo "Load Average: $load_avg"

section "MEMORY INFORMATION"
if command -v free &>/dev/null; then
    free -h | awk '
        /^Mem:/ {
            printf "Total:     %s\n", $2
            printf "Used:      %s\n", $3
            printf "Available: %s\n", $7
        }
        /^Swap:/ {
            printf "Swap Total: %s\n", $2
            printf "Swap Used:  %s\n", $3
        }'
fi

section "DISK USAGE"
df -h --output=source,size,used,avail,pcent,target 2>/dev/null | \
    grep -E '^/dev/' | \
    while read -r dev size used avail pct mount; do
        printf "%-20s %6s used of %6s (%s) on %s\n" "$dev" "$used" "$size" "$pct" "$mount"
    done

section "NETWORK INTERFACES"
if command -v ip &>/dev/null; then
    ip -br addr show | while read -r iface state addrs; do
        printf "%-15s %-10s %s\n" "$iface" "$state" "$addrs"
    done
elif command -v ifconfig &>/dev/null; then
    ifconfig | grep -E "^[a-z]|inet "
fi

section "TOP 5 PROCESSES BY MEMORY"
ps aux --sort=-%mem 2>/dev/null | head -6 | \
    awk 'NR==1 {printf "%-10s %5s %5s  %s\n", "USER", "%CPU", "%MEM", "COMMAND"}
         NR>1  {printf "%-10s %5s %5s  %s\n", $1, $3, $4, $11}'

echo ""
echo "Report generated at $(date)"
```

### 7.2 Log File Analyzer

A script that parses and summarizes log files.

```bash
#!/bin/bash
# log_analyzer.sh -- Analyze log files for patterns and statistics

set -euo pipefail

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <logfile>

Analyze log files and produce summary reports.

Options:
    -l, --level LEVEL    Filter by log level (ERROR, WARN, INFO, DEBUG)
    -d, --date DATE      Filter by date (YYYY-MM-DD)
    -t, --top N          Show top N entries (default: 10)
    -o, --output FILE    Write report to file
    -h, --help           Show this help message

Examples:
    $(basename "$0") /var/log/syslog
    $(basename "$0") -l ERROR -t 5 app.log
    $(basename "$0") -d 2026-03-20 -o report.txt server.log
EOF
    exit 0
}

# Defaults
level=""
date_filter=""
top_n=10
output_file=""
log_file=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--level)  level="${2^^}"; shift 2 ;;
        -d|--date)   date_filter="$2"; shift 2 ;;
        -t|--top)    top_n="$2"; shift 2 ;;
        -o|--output) output_file="$2"; shift 2 ;;
        -h|--help)   usage ;;
        -*)          echo "Unknown option: $1" >&2; exit 1 ;;
        *)           log_file="$1"; shift ;;
    esac
done

if [[ -z "$log_file" ]]; then
    echo "Error: No log file specified." >&2
    usage
fi

if [[ ! -f "$log_file" ]]; then
    echo "Error: File '$log_file' not found." >&2
    exit 1
fi

analyze() {
    local total_lines
    total_lines=$(wc -l < "$log_file")

    echo "============================================"
    echo "  Log Analysis Report"
    echo "============================================"
    echo "File: $log_file"
    echo "Total lines: $total_lines"
    echo "Analysis date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Count by log level
    echo "--- Log Level Distribution ---"
    for lv in ERROR WARN WARNING INFO DEBUG TRACE; do
        count=$(grep -ci "\[$lv\]\|$lv:" "$log_file" 2>/dev/null || echo 0)
        if [[ $count -gt 0 ]]; then
            pct=$((count * 100 / total_lines))
            bar=$(printf '#%.0s' $(seq 1 $((pct / 2 + 1))))
            printf "  %-10s %6d (%3d%%) %s\n" "$lv" "$count" "$pct" "$bar"
        fi
    done
    echo ""

    # Apply filters
    local filter_cmd="cat '$log_file'"
    [[ -n "$level" ]] && filter_cmd+=" | grep -i '$level'"
    [[ -n "$date_filter" ]] && filter_cmd+=" | grep '$date_filter'"

    # Most frequent messages
    echo "--- Top $top_n Most Frequent Patterns ---"
    eval "$filter_cmd" 2>/dev/null | \
        sed 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}//g; s/[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}//g' | \
        sort | uniq -c | sort -rn | head -"$top_n" | \
        while read -r count pattern; do
            printf "  %6d  %s\n" "$count" "${pattern:0:80}"
        done
    echo ""

    # Errors timeline (if dates are present)
    echo "--- Error Timeline ---"
    grep -i "error" "$log_file" 2>/dev/null | \
        grep -oP '\d{4}-\d{2}-\d{2}' 2>/dev/null | \
        sort | uniq -c | sort -rn | head -"$top_n" | \
        while read -r count date; do
            printf "  %s : %d errors\n" "$date" "$count"
        done 2>/dev/null || echo "  No dated error entries found."

    echo ""
    echo "============================================"
}

if [[ -n "$output_file" ]]; then
    analyze > "$output_file"
    echo "Report written to $output_file"
else
    analyze
fi
```

### 7.3 Automated Backup Script

```bash
#!/bin/bash
# backup.sh -- Automated backup with rotation and compression

set -euo pipefail

# Configuration
BACKUP_SRC="${BACKUP_SRC:-$HOME/documents}"
BACKUP_DST="${BACKUP_DST:-$HOME/backups}"
MAX_BACKUPS="${MAX_BACKUPS:-7}"
COMPRESS="${COMPRESS:-true}"
LOG_FILE="${BACKUP_DST}/backup.log"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}"

log() {
    local level="$1"; shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

die() { log "FATAL" "$*"; exit 1; }

# Verify source exists
[[ -d "$BACKUP_SRC" ]] || die "Source directory '$BACKUP_SRC' does not exist."

# Create backup destination
mkdir -p "$BACKUP_DST"

log "INFO" "Starting backup of '$BACKUP_SRC'"
log "INFO" "Destination: '$BACKUP_DST/$BACKUP_NAME'"

# Create the backup
if $COMPRESS; then
    BACKUP_FILE="${BACKUP_DST}/${BACKUP_NAME}.tar.gz"
    log "INFO" "Creating compressed backup: $BACKUP_FILE"

    if tar -czf "$BACKUP_FILE" -C "$(dirname "$BACKUP_SRC")" "$(basename "$BACKUP_SRC")" 2>&1; then
        size=$(du -h "$BACKUP_FILE" | cut -f1)
        log "INFO" "Backup created successfully ($size)"
    else
        die "Backup creation failed."
    fi
else
    BACKUP_DIR="${BACKUP_DST}/${BACKUP_NAME}"
    log "INFO" "Creating directory backup: $BACKUP_DIR"

    if cp -a "$BACKUP_SRC" "$BACKUP_DIR" 2>&1; then
        size=$(du -sh "$BACKUP_DIR" | cut -f1)
        log "INFO" "Backup created successfully ($size)"
    else
        die "Backup creation failed."
    fi
fi

# Rotate old backups
log "INFO" "Checking backup rotation (keeping last $MAX_BACKUPS)"

backup_count=$(find "$BACKUP_DST" -maxdepth 1 -name "backup_*" | wc -l)

if (( backup_count > MAX_BACKUPS )); then
    remove_count=$((backup_count - MAX_BACKUPS))
    log "INFO" "Removing $remove_count old backup(s)"

    find "$BACKUP_DST" -maxdepth 1 -name "backup_*" -print0 | \
        sort -z | head -z -n "$remove_count" | \
        while IFS= read -r -d '' old_backup; do
            log "INFO" "Removing: $(basename "$old_backup")"
            rm -rf "$old_backup"
        done
fi

# Summary
echo ""
echo "=== Backup Summary ==="
echo "Source:      $BACKUP_SRC"
echo "Destination: $BACKUP_DST"
echo "Backups stored:"
find "$BACKUP_DST" -maxdepth 1 -name "backup_*" -printf "  %f (%s bytes)\n" 2>/dev/null | sort || \
    find "$BACKUP_DST" -maxdepth 1 -name "backup_*" | sort | while read -r f; do
        echo "  $(basename "$f")"
    done

log "INFO" "Backup complete."
```

### 7.4 Directory Synchronizer

```bash
#!/bin/bash
# dir_sync.sh -- Synchronize two directories with conflict detection

set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") [-n|--dry-run] [-v|--verbose] <source> <target>"
    echo "  -n, --dry-run   Show what would be done without making changes"
    echo "  -v, --verbose   Show detailed output"
    exit 1
}

DRY_RUN=false
VERBOSE=false
SOURCE=""
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *)
            if [[ -z "$SOURCE" ]]; then
                SOURCE="$1"
            elif [[ -z "$TARGET" ]]; then
                TARGET="$1"
            else
                usage
            fi
            shift
            ;;
    esac
done

[[ -z "$SOURCE" || -z "$TARGET" ]] && usage
[[ -d "$SOURCE" ]] || { echo "Source '$SOURCE' is not a directory." >&2; exit 1; }

mkdir -p "$TARGET"

declare -i copied=0 updated=0 skipped=0 conflicts=0

log() {
    $VERBOSE && echo "$*"
}

sync_file() {
    local src_file="$1"
    local rel_path="${src_file#$SOURCE/}"
    local tgt_file="$TARGET/$rel_path"

    # Create target directory if needed
    local tgt_dir
    tgt_dir=$(dirname "$tgt_file")
    if [[ ! -d "$tgt_dir" ]]; then
        log "Creating directory: $tgt_dir"
        $DRY_RUN || mkdir -p "$tgt_dir"
    fi

    if [[ ! -e "$tgt_file" ]]; then
        log "COPY: $rel_path"
        $DRY_RUN || cp -p "$src_file" "$tgt_file"
        ((copied++))
    elif [[ "$src_file" -nt "$tgt_file" ]]; then
        log "UPDATE: $rel_path (source is newer)"
        $DRY_RUN || cp -p "$src_file" "$tgt_file"
        ((updated++))
    elif [[ "$tgt_file" -nt "$src_file" ]]; then
        local src_hash tgt_hash
        src_hash=$(md5sum "$src_file" | cut -d' ' -f1)
        tgt_hash=$(md5sum "$tgt_file" | cut -d' ' -f1)
        if [[ "$src_hash" != "$tgt_hash" ]]; then
            echo "CONFLICT: $rel_path (target is newer and different)"
            ((conflicts++))
        else
            log "SKIP: $rel_path (identical)"
            ((skipped++))
        fi
    else
        log "SKIP: $rel_path (same timestamp)"
        ((skipped++))
    fi
}

# Walk source directory
while IFS= read -r -d '' file; do
    sync_file "$file"
done < <(find "$SOURCE" -type f -print0)

# Summary
echo ""
echo "=== Sync Summary ==="
$DRY_RUN && echo "(DRY RUN -- no changes made)"
echo "Copied:    $copied"
echo "Updated:   $updated"
echo "Skipped:   $skipped"
echo "Conflicts: $conflicts"
```

### 7.5 Service Health Monitor

```bash
#!/bin/bash
# health_monitor.sh -- Monitor services and send alerts

set -euo pipefail

# Configuration
CHECK_INTERVAL="${CHECK_INTERVAL:-30}"
MAX_FAILURES="${MAX_FAILURES:-3}"
ALERT_LOG="health_alerts.log"

# Services to monitor: "name|type|target"
declare -a SERVICES=(
    "Google DNS|ping|8.8.8.8"
    "Localhost HTTP|http|http://localhost:80"
    "SSH Service|port|localhost:22"
    "Disk Space|disk|/:90"
)

declare -A failure_count

log_alert() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ALERT: $*" | tee -a "$ALERT_LOG"
}

check_ping() {
    local host="$1"
    ping -c 1 -W 3 "$host" &>/dev/null
}

check_http() {
    local url="$1"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
    [[ "$http_code" =~ ^[23] ]]
}

check_port() {
    local target="$1"
    local host="${target%%:*}"
    local port="${target##*:}"
    timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
}

check_disk() {
    local target="$1"
    local mount="${target%%:*}"
    local threshold="${target##*:}"
    local usage
    usage=$(df "$mount" 2>/dev/null | awk 'NR==2 {gsub(/%/,""); print $5}')
    [[ -n "$usage" ]] && (( usage < threshold ))
}

run_check() {
    local name="$1"
    local check_type="$2"
    local target="$3"

    case "$check_type" in
        ping) check_ping "$target" ;;
        http) check_http "$target" ;;
        port) check_port "$target" ;;
        disk) check_disk "$target" ;;
        *)    echo "Unknown check type: $check_type" >&2; return 1 ;;
    esac
}

monitor_once() {
    local timestamp
    timestamp=$(date '+%H:%M:%S')

    printf "\n[%s] Running health checks...\n" "$timestamp"
    printf "%-25s %-8s %-25s %s\n" "SERVICE" "TYPE" "TARGET" "STATUS"
    printf "%s\n" "$(printf -- '-%.0s' {1..70})"

    for service_spec in "${SERVICES[@]}"; do
        IFS='|' read -r name check_type target <<< "$service_spec"
        local key="${name// /_}"

        if run_check "$name" "$check_type" "$target"; then
            printf "%-25s %-8s %-25s \e[32m%-6s\e[0m\n" "$name" "$check_type" "$target" "OK"
            failure_count[$key]=0
        else
            failure_count[$key]=$(( ${failure_count[$key]:-0} + 1 ))
            local fails=${failure_count[$key]}
            printf "%-25s %-8s %-25s \e[31m%-6s\e[0m (failures: %d)\n" \
                "$name" "$check_type" "$target" "FAIL" "$fails"

            if (( fails >= MAX_FAILURES )); then
                log_alert "$name ($check_type: $target) - $fails consecutive failures!"
            fi
        fi
    done
}

echo "=== Service Health Monitor ==="
echo "Check interval: ${CHECK_INTERVAL}s | Alert threshold: $MAX_FAILURES failures"
echo "Press Ctrl+C to stop."

# Run once or continuously
if [[ "${1:-}" == "--once" ]]; then
    monitor_once
else
    while true; do
        monitor_once
        sleep "$CHECK_INTERVAL"
    done
fi
```

### 7.6 CSV Data Processor

```bash
#!/bin/bash
# csv_processor.sh -- Parse, filter, and transform CSV data

set -euo pipefail

usage() {
    cat << 'EOF'
Usage: csv_processor.sh [OPTIONS] <csvfile>

Options:
    -c, --columns COLS   Comma-separated column numbers or names to display
    -f, --filter EXPR    Filter rows (e.g., "3>100" or "name==Alice")
    -s, --sort COL       Sort by column number
    -r, --reverse        Reverse sort order
    -d, --delimiter D    Field delimiter (default: ,)
    --sum COL            Calculate sum of a numeric column
    --avg COL            Calculate average of a numeric column
    --stats COL          Show statistics for a numeric column
    --no-header          Input has no header row
    -h, --help           Show this help
EOF
    exit 0
}

DELIMITER=","
COLUMNS=""
FILTER=""
SORT_COL=""
REVERSE=false
HAS_HEADER=true
OPERATION=""
OP_COL=""
CSV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--columns)   COLUMNS="$2"; shift 2 ;;
        -f|--filter)    FILTER="$2"; shift 2 ;;
        -s|--sort)      SORT_COL="$2"; shift 2 ;;
        -r|--reverse)   REVERSE=true; shift ;;
        -d|--delimiter) DELIMITER="$2"; shift 2 ;;
        --sum)          OPERATION="sum"; OP_COL="$2"; shift 2 ;;
        --avg)          OPERATION="avg"; OP_COL="$2"; shift 2 ;;
        --stats)        OPERATION="stats"; OP_COL="$2"; shift 2 ;;
        --no-header)    HAS_HEADER=false; shift ;;
        -h|--help)      usage ;;
        -*)             echo "Unknown option: $1" >&2; exit 1 ;;
        *)              CSV_FILE="$1"; shift ;;
    esac
done

[[ -n "$CSV_FILE" ]] || { echo "Error: No CSV file specified." >&2; usage; }
[[ -f "$CSV_FILE" ]] || { echo "Error: File '$CSV_FILE' not found." >&2; exit 1; }

# Read header
if $HAS_HEADER; then
    IFS= read -r header_line < "$CSV_FILE"
    IFS="$DELIMITER" read -ra headers <<< "$header_line"
fi

# Column name to index resolver
col_to_index() {
    local col="$1"
    if [[ "$col" =~ ^[0-9]+$ ]]; then
        echo "$col"
    else
        for i in "${!headers[@]}"; do
            if [[ "${headers[$i]}" == "$col" ]]; then
                echo "$((i + 1))"
                return
            fi
        done
        echo "Error: Column '$col' not found." >&2
        exit 1
    fi
}

# Build awk script
build_awk() {
    local awk_script="BEGIN { FS=\"${DELIMITER}\"; OFS=\"${DELIMITER}\" }"

    # Header line
    if $HAS_HEADER; then
        awk_script+=" NR==1 { print; next }"
    fi

    # Filter
    if [[ -n "$FILTER" ]]; then
        local filter_col filter_op filter_val
        if [[ "$FILTER" =~ ^([a-zA-Z0-9_]+)(==|!=|>|<|>=|<=)(.+)$ ]]; then
            filter_col=$(col_to_index "${BASH_REMATCH[1]}")
            filter_op="${BASH_REMATCH[2]}"
            filter_val="${BASH_REMATCH[3]}"

            case "$filter_op" in
                "==") awk_script+=" \$${filter_col} != \"${filter_val}\" { next }" ;;
                "!=") awk_script+=" \$${filter_col} == \"${filter_val}\" { next }" ;;
                ">")  awk_script+=" \$${filter_col}+0 <= ${filter_val}+0 { next }" ;;
                "<")  awk_script+=" \$${filter_col}+0 >= ${filter_val}+0 { next }" ;;
                ">=") awk_script+=" \$${filter_col}+0 < ${filter_val}+0 { next }" ;;
                "<=") awk_script+=" \$${filter_col}+0 > ${filter_val}+0 { next }" ;;
            esac
        fi
    fi

    # Column selection
    if [[ -n "$COLUMNS" ]]; then
        local col_list=""
        IFS=',' read -ra col_specs <<< "$COLUMNS"
        for cs in "${col_specs[@]}"; do
            local idx
            idx=$(col_to_index "$cs")
            col_list+="${col_list:+, }\$$idx"
        done
        awk_script+=" { print $col_list }"
    else
        awk_script+=" { print }"
    fi

    echo "$awk_script"
}

# Statistics operation
compute_stats() {
    local col
    col=$(col_to_index "$OP_COL")
    local start_line=1
    $HAS_HEADER && start_line=2

    awk -F"$DELIMITER" -v col="$col" -v start="$start_line" -v op="$OPERATION" '
        NR >= start {
            val = $col + 0
            sum += val
            count++
            vals[count] = val
            if (count == 1 || val < min) min = val
            if (count == 1 || val > max) max = val
        }
        END {
            if (count == 0) { print "No data"; exit }
            avg = sum / count

            if (op == "sum")  { printf "Sum: %.2f\n", sum; exit }
            if (op == "avg")  { printf "Average: %.2f\n", avg; exit }

            # Stats: compute stddev
            for (i = 1; i <= count; i++) {
                variance += (vals[i] - avg) ^ 2
            }
            stddev = sqrt(variance / count)

            printf "Count:    %d\n", count
            printf "Sum:      %.2f\n", sum
            printf "Min:      %.2f\n", min
            printf "Max:      %.2f\n", max
            printf "Average:  %.2f\n", avg
            printf "Std Dev:  %.2f\n", stddev
        }
    ' "$CSV_FILE"
}

# Main execution
if [[ -n "$OPERATION" ]]; then
    compute_stats
    exit 0
fi

awk_prog=$(build_awk)

if [[ -n "$SORT_COL" ]]; then
    sort_idx=$(col_to_index "$SORT_COL")
    sort_flags="-t${DELIMITER} -k${sort_idx},${sort_idx}"
    $REVERSE && sort_flags+="r"

    if $HAS_HEADER; then
        awk "$awk_prog" "$CSV_FILE" | (read -r hdr; echo "$hdr"; sort $sort_flags)
    else
        awk "$awk_prog" "$CSV_FILE" | sort $sort_flags
    fi
else
    awk "$awk_prog" "$CSV_FILE"
fi
```

### 7.7 Interactive Menu System

```bash
#!/bin/bash
# menu_system.sh -- Reusable interactive menu framework

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║       System Administration Menu         ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_menu() {
    echo -e "${CYAN}Select an option:${NC}"
    echo ""
    echo -e "  ${BOLD}1)${NC} System Information"
    echo -e "  ${BOLD}2)${NC} Disk Usage Report"
    echo -e "  ${BOLD}3)${NC} Network Information"
    echo -e "  ${BOLD}4)${NC} Process Manager"
    echo -e "  ${BOLD}5)${NC} User Management"
    echo -e "  ${BOLD}6)${NC} Service Status"
    echo -e "  ${BOLD}7)${NC} System Logs"
    echo ""
    echo -e "  ${BOLD}q)${NC} Quit"
    echo ""
}

press_enter() {
    echo ""
    read -rp "Press Enter to continue..."
}

show_system_info() {
    echo -e "${GREEN}=== System Information ===${NC}"
    echo "Hostname:     $(hostname)"
    echo "Kernel:       $(uname -r)"
    echo "Uptime:       $(uptime -p 2>/dev/null || uptime)"
    echo "Users logged: $(who | wc -l)"
    echo "Date:         $(date)"
    press_enter
}

show_disk_usage() {
    echo -e "${GREEN}=== Disk Usage ===${NC}"
    df -h 2>/dev/null | head -20

    echo ""
    echo -e "${YELLOW}Top 10 largest directories in /home:${NC}"
    du -sh /home/*/ 2>/dev/null | sort -rh | head -10 || echo "No data available."
    press_enter
}

show_network_info() {
    echo -e "${GREEN}=== Network Information ===${NC}"

    if command -v ip &>/dev/null; then
        echo -e "\n${BOLD}Interfaces:${NC}"
        ip -br addr show 2>/dev/null

        echo -e "\n${BOLD}Default Gateway:${NC}"
        ip route show default 2>/dev/null
    fi

    echo -e "\n${BOLD}DNS Servers:${NC}"
    grep "^nameserver" /etc/resolv.conf 2>/dev/null || echo "Not available"

    echo -e "\n${BOLD}Listening Ports:${NC}"
    ss -tlnp 2>/dev/null | head -15 || netstat -tlnp 2>/dev/null | head -15 || echo "Not available"
    press_enter
}

process_manager() {
    echo -e "${GREEN}=== Process Manager ===${NC}"
    echo -e "\n${BOLD}Top 15 processes by CPU:${NC}"
    ps aux --sort=-%cpu 2>/dev/null | head -16

    echo ""
    read -rp "Enter PID to view details (or press Enter to skip): " pid
    if [[ -n "$pid" ]]; then
        if [[ -d "/proc/$pid" ]]; then
            echo -e "\n${BOLD}Details for PID $pid:${NC}"
            ps -p "$pid" -o pid,ppid,user,%cpu,%mem,vsz,rss,stat,start,time,comm 2>/dev/null
            echo -e "\n${BOLD}Open files:${NC}"
            ls -l "/proc/$pid/fd" 2>/dev/null | tail -5 || echo "Cannot access"
        else
            echo -e "${RED}PID $pid not found.${NC}"
        fi
    fi
    press_enter
}

user_management() {
    echo -e "${GREEN}=== User Management ===${NC}"
    echo -e "\n${BOLD}Currently logged in:${NC}"
    who 2>/dev/null

    echo -e "\n${BOLD}Recent logins:${NC}"
    last -10 2>/dev/null || echo "Not available"

    echo -e "\n${BOLD}System users:${NC}"
    awk -F: '$3 >= 1000 && $3 < 65534 {printf "  %-20s UID: %s  Home: %s\n", $1, $3, $6}' /etc/passwd
    press_enter
}

service_status() {
    echo -e "${GREEN}=== Service Status ===${NC}"

    if command -v systemctl &>/dev/null; then
        echo -e "\n${BOLD}Failed services:${NC}"
        systemctl --failed 2>/dev/null || echo "No failed services"

        echo -e "\n${BOLD}Active services:${NC}"
        systemctl list-units --type=service --state=running 2>/dev/null | head -20
    else
        echo "systemctl not available"
        echo -e "\n${BOLD}Running services (via ps):${NC}"
        ps aux | grep -E '(sshd|nginx|apache|mysql|postgres)' | grep -v grep || echo "None detected"
    fi
    press_enter
}

show_logs() {
    echo -e "${GREEN}=== System Logs ===${NC}"
    echo "  1) Syslog (last 20 lines)"
    echo "  2) Auth log (last 20 lines)"
    echo "  3) Kernel messages"
    echo "  4) Custom log file"
    echo ""
    read -rp "Choice: " log_choice

    case "$log_choice" in
        1) echo -e "\n${BOLD}Syslog:${NC}"
           tail -20 /var/log/syslog 2>/dev/null || journalctl -n 20 2>/dev/null || echo "Not available" ;;
        2) echo -e "\n${BOLD}Auth log:${NC}"
           tail -20 /var/log/auth.log 2>/dev/null || journalctl -u sshd -n 20 2>/dev/null || echo "Not available" ;;
        3) echo -e "\n${BOLD}Kernel messages:${NC}"
           dmesg 2>/dev/null | tail -20 || echo "Not available" ;;
        4) read -rp "Enter log file path: " logpath
           if [[ -f "$logpath" ]]; then
               tail -30 "$logpath"
           else
               echo -e "${RED}File not found.${NC}"
           fi ;;
        *) echo "Invalid choice" ;;
    esac
    press_enter
}

# Main loop
while true; do
    print_header
    print_menu
    read -rp "Enter choice: " choice

    case "$choice" in
        1) show_system_info ;;
        2) show_disk_usage ;;
        3) show_network_info ;;
        4) process_manager ;;
        5) user_management ;;
        6) service_status ;;
        7) show_logs ;;
        q|Q) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done
```

### 7.8 Batch File Renamer

```bash
#!/bin/bash
# batch_rename.sh -- Rename files in bulk with pattern matching and preview

set -euo pipefail

usage() {
    cat << 'EOF'
Usage: batch_rename.sh [OPTIONS] <directory>

Rename files in bulk using patterns.

Options:
    -p, --pattern PATTERN    Find pattern (glob or regex)
    -r, --replace REPLACE    Replacement string
    -R, --regex              Use regex instead of glob
    -e, --extension EXT      Change file extension to EXT
    --prefix PREFIX          Add prefix to filenames
    --suffix SUFFIX          Add suffix (before extension)
    --lower                  Convert filenames to lowercase
    --upper                  Convert filenames to uppercase
    --number                 Add sequential numbers
    --number-start N         Starting number (default: 1)
    --number-pad N           Zero-padding width (default: 3)
    -n, --dry-run            Show changes without applying
    -h, --help               Show this help

Examples:
    batch_rename.sh --lower /path/to/dir
    batch_rename.sh -p "IMG_" -r "photo_" /path/to/dir
    batch_rename.sh --prefix "2026_" --extension jpg /path/to/dir
    batch_rename.sh --number --number-pad 4 /path/to/dir
EOF
    exit 0
}

PATTERN=""
REPLACE=""
USE_REGEX=false
NEW_EXT=""
PREFIX=""
SUFFIX=""
TO_LOWER=false
TO_UPPER=false
ADD_NUMBER=false
NUM_START=1
NUM_PAD=3
DRY_RUN=false
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--pattern)       PATTERN="$2"; shift 2 ;;
        -r|--replace)       REPLACE="$2"; shift 2 ;;
        -R|--regex)         USE_REGEX=true; shift ;;
        -e|--extension)     NEW_EXT="$2"; shift 2 ;;
        --prefix)           PREFIX="$2"; shift 2 ;;
        --suffix)           SUFFIX="$2"; shift 2 ;;
        --lower)            TO_LOWER=true; shift ;;
        --upper)            TO_UPPER=true; shift ;;
        --number)           ADD_NUMBER=true; shift ;;
        --number-start)     NUM_START="$2"; shift 2 ;;
        --number-pad)       NUM_PAD="$2"; shift 2 ;;
        -n|--dry-run)       DRY_RUN=true; shift ;;
        -h|--help)          usage ;;
        -*)                 echo "Unknown option: $1" >&2; exit 1 ;;
        *)                  TARGET_DIR="$1"; shift ;;
    esac
done

[[ -n "$TARGET_DIR" ]] || { echo "Error: No directory specified." >&2; usage; }
[[ -d "$TARGET_DIR" ]] || { echo "Error: '$TARGET_DIR' is not a directory." >&2; exit 1; }

declare -i count=0 num_counter=$NUM_START

echo "=== Batch File Renamer ==="
$DRY_RUN && echo "(DRY RUN -- no changes will be made)"
echo ""

printf "%-40s -> %s\n" "ORIGINAL" "NEW NAME"
printf "%s\n" "$(printf -- '-%.0s' {1..80})"

for filepath in "$TARGET_DIR"/*; do
    [[ -f "$filepath" ]] || continue

    dir=$(dirname "$filepath")
    filename=$(basename "$filepath")
    name="${filename%.*}"
    ext="${filename##*.}"
    [[ "$name" == "$ext" ]] && ext=""  # No extension

    new_name="$name"
    new_ext="$ext"

    # Pattern replacement
    if [[ -n "$PATTERN" ]]; then
        if $USE_REGEX; then
            new_name=$(echo "$new_name" | sed "s/$PATTERN/$REPLACE/g")
        else
            new_name="${new_name//$PATTERN/$REPLACE}"
        fi
    fi

    # Case conversion
    $TO_LOWER && new_name="${new_name,,}" && new_ext="${new_ext,,}"
    $TO_UPPER && new_name="${new_name^^}" && new_ext="${new_ext^^}"

    # Add prefix/suffix
    [[ -n "$PREFIX" ]] && new_name="${PREFIX}${new_name}"
    [[ -n "$SUFFIX" ]] && new_name="${new_name}${SUFFIX}"

    # Change extension
    [[ -n "$NEW_EXT" ]] && new_ext="${NEW_EXT#.}"

    # Add number
    if $ADD_NUMBER; then
        num_str=$(printf "%0${NUM_PAD}d" "$num_counter")
        new_name="${new_name}_${num_str}"
        ((num_counter++))
    fi

    # Construct new filename
    if [[ -n "$new_ext" ]]; then
        new_filename="${new_name}.${new_ext}"
    else
        new_filename="$new_name"
    fi

    new_filepath="${dir}/${new_filename}"

    # Only process if the name actually changed
    if [[ "$filepath" != "$new_filepath" ]]; then
        printf "%-40s -> %s\n" "$filename" "$new_filename"

        if ! $DRY_RUN; then
            if [[ -e "$new_filepath" ]]; then
                echo "  WARNING: '$new_filename' already exists, skipping."
            else
                mv "$filepath" "$new_filepath"
            fi
        fi
        ((count++))
    fi
done

echo ""
echo "Total files ${DRY_RUN:+would be }renamed: $count"
```

---

## Quick Reference

### Common Special Variables

| Variable | Description |
|----------|-------------|
| `$0` | Script name |
| `$1`..`$9` | Positional parameters |
| `${10}` | 10th parameter (braces required) |
| `$#` | Number of arguments |
| `$@` | All arguments (as separate words) |
| `$*` | All arguments (as single string) |
| `$?` | Exit status of last command |
| `$$` | PID of current shell |
| `$!` | PID of last background process |
| `$_` | Last argument of previous command |
| `$-` | Current shell option flags |
| `$LINENO` | Current line number |
| `$FUNCNAME` | Current function name |
| `$BASH_SOURCE` | Source filename |
| `$RANDOM` | Random integer (0--32767) |
| `$SECONDS` | Seconds since shell started |

### Exit Status Conventions

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Misuse of shell builtin |
| 126 | Command not executable |
| 127 | Command not found |
| 128+N | Killed by signal N |
| 130 | Killed by Ctrl+C (SIGINT) |
| 255 | Exit status out of range |

### Useful One-Liners

```bash
# Find files modified in the last 24 hours
find /path -mtime -1 -type f

# Count lines across all Python files
find . -name "*.py" -exec cat {} + | wc -l

# Monitor a file in real-time
tail -f /var/log/syslog

# Parallel command execution
cat urls.txt | xargs -P4 -I{} curl -sO {}

# Generate a random password
< /dev/urandom tr -dc 'A-Za-z0-9!@#$%' | head -c 20; echo

# Quick HTTP server
python3 -m http.server 8080

# Find duplicate files by checksum
find . -type f -exec md5sum {} + | sort | uniq -w32 -dD

# Replace text across multiple files
find . -name "*.txt" -exec sed -i 's/old/new/g' {} +

# Compress all .log files older than 7 days
find /var/log -name "*.log" -mtime +7 -exec gzip {} \;

# Show directory sizes sorted
du -sh */ | sort -rh

# Remove empty directories recursively
find . -type d -empty -delete

# Extract unique IPs from a log
grep -oP '\d+\.\d+\.\d+\.\d+' access.log | sort -u

# Watch disk usage every 5 seconds
watch -n 5 'df -h | grep /dev/'
```

### Shell Options (set/shopt)

```bash
# Commonly used set options
set -e          # Exit on error
set -u          # Error on undefined variables
set -o pipefail # Pipe fails if any component fails
set -x          # Debug mode (trace)

# Commonly used shopt options
shopt -s extglob     # Extended pattern matching
shopt -s nullglob    # Globs with no matches expand to nothing
shopt -s globstar    # ** matches directories recursively
shopt -s nocaseglob  # Case-insensitive globbing
shopt -s dotglob     # Include hidden files in globs
```

---

## Best Practices Summary

1. **Always use a shebang**: `#!/bin/bash` (or `#!/usr/bin/env bash` for portability)
2. **Use strict mode**: `set -euo pipefail` at the top of scripts
3. **Quote your variables**: `"$var"` prevents word splitting and globbing
4. **Use `[[ ]]` over `[ ]`**: Safer, more features, no word splitting
5. **Prefer `$(...)` over backticks**: Nests cleanly, easier to read
6. **Use `local` in functions**: Prevent accidental global variable modification
7. **Handle errors**: Check return codes, use traps for cleanup
8. **Use `readonly` or `declare -r`**: For constants that should never change
9. **Use arrays**: Instead of space-separated strings for lists
10. **Use `printf` over `echo`**: More portable and predictable
11. **Use `mktemp`**: For safe temporary file creation
12. **Test with ShellCheck**: `shellcheck script.sh` catches common mistakes
