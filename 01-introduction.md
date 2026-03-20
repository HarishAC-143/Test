# Chapter 1: Introduction to Perl

## What Is Perl?

Perl (Practical Extraction and Reporting Language) is a high-level, general-purpose, interpreted programming language created by Larry Wall in 1987. It was originally designed for text processing and report generation, but over the decades it has grown into a powerful language used for system administration, web development, network programming, bioinformatics, and more.

Perl's motto is **"There's More Than One Way To Do It" (TMTOWTDI)**, reflecting its philosophy of giving programmers freedom and flexibility.

## Why Learn Perl?

- **Text Processing Powerhouse**: Perl has the most robust regular expression engine of any programming language, making it unmatched for text manipulation.
- **System Administration**: Perl is the go-to language for automating sysadmin tasks across Unix/Linux systems.
- **CPAN Ecosystem**: The Comprehensive Perl Archive Network (CPAN) hosts over 200,000 modules — an enormous library of reusable code.
- **Cross-Platform**: Perl runs on virtually every operating system.
- **Mature and Battle-Tested**: Decades of production use in critical infrastructure at companies like Amazon, Booking.com, and DuckDuckGo.
- **Glue Language**: Perl excels at connecting different systems, formats, and protocols together.

## Installing Perl

### Linux / macOS

Most Unix-like systems come with Perl pre-installed. Check your version:

```bash
perl -v
```

To install or update on Linux:

```bash
# Debian/Ubuntu
sudo apt-get install perl

# Red Hat/CentOS/Fedora
sudo dnf install perl

# macOS (via Homebrew)
brew install perl
```

### Windows

Download Strawberry Perl from [strawberryperl.com](https://strawberryperl.com/) — it includes a compiler, CPAN tools, and many pre-built modules.

### Using perlbrew (Recommended for Development)

`perlbrew` lets you install and manage multiple Perl versions in your home directory:

```bash
curl -L https://install.perlbrew.pl | bash
perlbrew install perl-5.38.0
perlbrew switch perl-5.38.0
```

## Your First Perl Program

Create a file called `hello.pl`:

```perl
#!/usr/bin/perl
use strict;
use warnings;

print "Hello, World!\n";
```

Run it:

```bash
perl hello.pl
```

Output:

```
Hello, World!
```

### Understanding the First Program

| Line | Purpose |
|------|---------|
| `#!/usr/bin/perl` | Shebang line — tells the OS which interpreter to use |
| `use strict;` | Enforces good coding practices (requires variable declarations) |
| `use warnings;` | Enables helpful warning messages for common mistakes |
| `print "Hello, World!\n";` | Prints text to standard output; `\n` is a newline character |

> **Best Practice**: Always include `use strict;` and `use warnings;` at the top of every Perl script. They catch many common bugs at compile time.

## Running Perl Code

### From a File

```bash
perl script.pl
```

### One-Liners (Command Line)

Perl is famous for powerful one-liners:

```bash
# Print lines containing "error" from a log file
perl -ne 'print if /error/i' /var/log/syslog

# Replace text in-place
perl -pi -e 's/old_text/new_text/g' file.txt

# Sum numbers from standard input
echo -e "10\n20\n30" | perl -ne '$sum += $_; END { print "$sum\n" }'
```

### Interactive Mode (Debugger)

```bash
perl -de 0
```

This drops you into the Perl debugger, which can serve as a simple REPL.

## Perl Documentation

Perl has excellent built-in documentation accessible via `perldoc`:

```bash
perldoc perl          # Overview
perldoc perlintro     # Introduction for beginners
perldoc -f print      # Documentation for the print function
perldoc File::Find    # Documentation for a specific module
```

## Chapter Summary

- Perl is a mature, powerful language designed for text processing and general-purpose programming.
- Always start scripts with `use strict;` and `use warnings;`.
- Perl can be run from files, as one-liners, or interactively.
- The `perldoc` tool provides comprehensive built-in documentation.

---

**Next**: [Chapter 2 — Variables and Data Types](02-variables-and-data-types.md)
