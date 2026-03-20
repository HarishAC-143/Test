# Perl Programming Exercises

Practice problems organized by difficulty. Try to solve each one before looking at the hints.

---

## Beginner Exercises

### Exercise 1: Temperature Converter

Write a script that converts temperatures between Celsius and Fahrenheit.

**Requirements:**
- Accept a temperature and unit (C or F) from the command line
- Display the converted temperature formatted to one decimal place
- Handle invalid input gracefully

**Formula:**
- F = C * 9/5 + 32
- C = (F - 32) * 5/9

**Example:**
```
$ perl temp_convert.pl 100 C
100.0°C = 212.0°F

$ perl temp_convert.pl 72 F
72.0°F = 22.2°C
```

<details>
<summary>Hint</summary>

```perl
my ($temp, $unit) = @ARGV;
die "Usage: $0 <temperature> <C|F>\n" unless defined $temp && defined $unit;
# Use uc() to handle lowercase input
# Use sprintf for formatting
```
</details>

---

### Exercise 2: Word Counter

Write a script that reads a text file and reports:
- Total lines, words, and characters
- The top 10 most frequent words
- The longest and shortest words

**Example:**
```
$ perl word_counter.pl document.txt
Lines:      42
Words:      350
Characters: 2100

Top 10 words:
  the        28
  and        15
  ...

Longest word:  "programming" (11 chars)
Shortest word: "a" (1 char)
```

<details>
<summary>Hint</summary>

```perl
# Split on whitespace: split(/\s+/, $line)
# Clean words: $word =~ s/[^a-zA-Z']//g
# Sort by frequency: sort { $freq{$b} <=> $freq{$a} } keys %freq
```
</details>

---

### Exercise 3: Array Manipulator

Write a script that demonstrates array operations:
- Create an array of 20 random numbers (1-100)
- Print them sorted ascending and descending
- Filter even and odd numbers
- Calculate sum, average, min, and max

<details>
<summary>Hint</summary>

```perl
my @nums = map { int(rand(100)) + 1 } 1..20;
use List::Util qw(sum min max);
my @evens = grep { $_ % 2 == 0 } @nums;
```
</details>

---

## Intermediate Exercises

### Exercise 4: Log Analyzer

Write a script that parses Apache-style access logs and reports:
- Total requests
- Requests per HTTP status code
- Top 10 most requested URLs
- Top 10 client IPs

**Sample log format:**
```
192.168.1.1 - - [20/Mar/2026:10:15:30 +0000] "GET /index.html HTTP/1.1" 200 1234
```

<details>
<summary>Hint</summary>

```perl
my $log_re = qr/^(\S+) .+ "(\w+) (\S+) .+" (\d+) (\d+)/;
# $1 = IP, $2 = method, $3 = URL, $4 = status, $5 = size
```
</details>

---

### Exercise 5: INI Config Parser

Write a module that can:
- Parse INI-format configuration files
- Support sections, key-value pairs, and comments
- Provide get/set methods
- Write the config back to a file

**Example:**
```ini
; Database settings
[database]
host = localhost
port = 5432
name = myapp

[server]
port = 8080
workers = 4
```

<details>
<summary>Hint</summary>

```perl
# Parse sections: if ($line =~ /^\[(.+)\]$/) { $section = $1 }
# Parse values:   if ($line =~ /^(\w+)\s*=\s*(.+)/) { $config{$section}{$1} = $2 }
# Skip comments:  next if $line =~ /^[;#]/ || $line =~ /^\s*$/;
```
</details>

---

### Exercise 6: Data Validator

Write a module with functions to validate:
- Email addresses
- Phone numbers (US format)
- URLs
- IP addresses (v4)
- Dates (YYYY-MM-DD)
- Credit card numbers (Luhn algorithm)

Each function should return a boolean and, optionally, an error message.

<details>
<summary>Hint</summary>

```perl
sub validate_email {
    my ($email) = @_;
    return $email =~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
}

# Luhn algorithm: double every other digit from right, sum digits, check mod 10
```
</details>

---

## Advanced Exercises

### Exercise 7: Mini Database

Implement an in-memory database that supports:
- Creating tables with typed columns
- INSERT, SELECT, UPDATE, DELETE operations
- WHERE clause filtering
- ORDER BY sorting
- Saving/loading to/from JSON files

**Example usage:**
```perl
my $db = MiniDB->new();
$db->create_table("users", [
    { name => "id",    type => "int" },
    { name => "name",  type => "string" },
    { name => "email", type => "string" },
]);
$db->insert("users", { id => 1, name => "Alice", email => "alice@test.com" });
my @results = $db->select("users", where => { name => "Alice" });
```

<details>
<summary>Hint</summary>

```perl
# Store tables as hash of arrays of hashes
# $self->{tables}{$name}{rows} = [ { col => val, ... }, ... ]
# $self->{tables}{$name}{schema} = [ { name => ..., type => ... }, ... ]
# Use grep for WHERE, sort for ORDER BY
```
</details>

---

### Exercise 8: Web Scraper Framework

Build a reusable web scraping framework that:
- Fetches pages with HTTP::Tiny
- Extracts data using regex patterns
- Follows links to crawl multiple pages
- Respects a delay between requests
- Outputs results as CSV or JSON

<details>
<summary>Hint</summary>

```perl
# Use HTTP::Tiny for fetching
# Define extraction rules as regex patterns
# Use a queue (array) for URLs to visit
# Track visited URLs in a hash
# sleep($delay) between requests
```
</details>

---

### Exercise 9: Build System

Create a simple build system (like a mini Make) that:
- Reads a build configuration file defining targets, dependencies, and commands
- Builds a dependency graph
- Executes targets in correct order
- Skips targets that are already up to date (based on file timestamps)

<details>
<summary>Hint</summary>

```perl
# Topological sort for dependency ordering
# Compare file modification times with -M operator
# Use system() to run build commands
```
</details>

---

## Solutions Approach

For each exercise:

1. **Plan**: Break the problem into small functions
2. **Start Simple**: Get the basic version working first
3. **Add Features**: Incrementally add error handling, edge cases, and polish
4. **Test**: Try edge cases and invalid inputs
5. **Refactor**: Clean up your code — use meaningful variable names, add comments for non-obvious logic

Remember Perl's motto: **There's More Than One Way To Do It!** Your solution doesn't need to look like anyone else's.
