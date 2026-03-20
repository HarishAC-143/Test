# Chapter 11: Advanced Topics

This chapter covers advanced Perl features that unlock the language's full power: database access, process management, testing, one-liners, and performance optimization.

## Database Access with DBI

DBI (Database Interface) is Perl's standard database abstraction layer.

```perl
#!/usr/bin/perl
use strict;
use warnings;
use DBI;

# Connect to SQLite (install DBD::SQLite from CPAN)
my $dbh = DBI->connect("dbi:SQLite:dbname=myapp.db", "", "", {
    RaiseError => 1,      # die on errors
    AutoCommit => 1,       # commit after each statement
    PrintError => 0,       # don't print errors (RaiseError handles them)
});

# Create a table
$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS users (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name  TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    age   INTEGER
)
SQL

# Insert with placeholders (prevents SQL injection)
my $sth = $dbh->prepare("INSERT INTO users (name, email, age) VALUES (?, ?, ?)");
$sth->execute("Alice", "alice\@example.com", 30);
$sth->execute("Bob",   "bob\@example.com",   25);
$sth->execute("Carol", "carol\@example.com", 28);

# Query — fetch all rows as hash references
$sth = $dbh->prepare("SELECT * FROM users WHERE age > ?");
$sth->execute(26);

while (my $row = $sth->fetchrow_hashref) {
    printf "%-10s %-25s %d\n", $row->{name}, $row->{email}, $row->{age};
}

# Shortcut: selectall_arrayref with hash slices
my $users = $dbh->selectall_arrayref(
    "SELECT name, email FROM users ORDER BY name",
    { Slice => {} }   # return array of hashrefs
);

for my $user (@$users) {
    print "$user->{name}: $user->{email}\n";
}

# Transaction
eval {
    $dbh->begin_work;
    $dbh->do("UPDATE users SET age = age + 1 WHERE name = ?", undef, "Alice");
    $dbh->do("UPDATE users SET age = age + 1 WHERE name = ?", undef, "Bob");
    $dbh->commit;
};
if ($@) {
    $dbh->rollback;
    warn "Transaction failed: $@";
}

$dbh->disconnect;
```

## Process Management and System Interaction

### Running External Commands

```perl
# system() — run a command and wait for it to finish
my $exit_code = system("ls", "-la", "/tmp");
if ($exit_code != 0) {
    warn "Command failed with exit code: ", $exit_code >> 8, "\n";
}

# Backticks / qx() — capture command output
my $output = `date`;
chomp $output;
print "Current date: $output\n";

my @files = `find /tmp -name "*.txt" -maxdepth 1`;
chomp @files;
print "Found ", scalar @files, " text files\n";

# open() with pipe — read from a command
open(my $pipe, "-|", "ps", "aux") or die "Cannot run ps: $!\n";
while (my $line = <$pipe>) {
    print $line if $line =~ /perl/i;
}
close $pipe;

# open() with pipe — write to a command
open(my $mail, "|-", "mail", "-s", "Report", 'admin@example.com')
    or die "Cannot run mail: $!\n";
print $mail "Here is the daily report.\n";
close $mail;
```

### Forking Processes

```perl
use POSIX qw(:sys_wait_h);

my $pid = fork();

if (!defined $pid) {
    die "Cannot fork: $!\n";
} elsif ($pid == 0) {
    # Child process
    print "Child (PID $$) starting work...\n";
    sleep 2;
    print "Child done.\n";
    exit 0;
} else {
    # Parent process
    print "Parent (PID $$) spawned child $pid\n";
    waitpid($pid, 0);
    my $child_exit = $? >> 8;
    print "Child exited with code: $child_exit\n";
}
```

### Signal Handling

```perl
# Catch Ctrl+C
$SIG{INT} = sub {
    print "\nCaught SIGINT! Cleaning up...\n";
    # cleanup code here
    exit 1;
};

# Catch TERM signal
$SIG{TERM} = sub {
    print "Caught SIGTERM, shutting down gracefully.\n";
    exit 0;
};

# Alarm for timeouts
eval {
    local $SIG{ALRM} = sub { die "Timeout!\n" };
    alarm 5;        # 5-second timeout
    # ... long-running operation ...
    sleep 10;       # will be interrupted
    alarm 0;        # cancel alarm
};
if ($@ =~ /Timeout/) {
    print "Operation timed out.\n";
}
```

## Testing with Test::More

Perl has a mature testing ecosystem built around the TAP (Test Anything Protocol).

```perl
#!/usr/bin/perl
# file: t/math_test.t
use strict;
use warnings;
use Test::More tests => 12;

# Basic assertions
ok(1 + 1 == 2, "basic addition");
ok(defined "hello", "string is defined");

# Equality tests
is(2 + 2, 4, "two plus two is four");
is("hello", "hello", "string equality");
isnt("hello", "world", "strings are different");

# Numeric comparison
cmp_ok(10, '>', 5, "ten is greater than five");
cmp_ok(3.14, '==', 3.14, "pi equals pi");

# Pattern matching
like("Hello, World!", qr/World/, "contains 'World'");
unlike("Hello, World!", qr/Goodbye/, "doesn't contain 'Goodbye'");

# Deep structure comparison
is_deeply(
    [1, 2, 3],
    [1, 2, 3],
    "arrays are identical"
);

is_deeply(
    { name => "Alice", age => 30 },
    { name => "Alice", age => 30 },
    "hashes are identical"
);

# Test that code dies
eval { die "Expected error" };
like($@, qr/Expected error/, "error message matches");
```

Running tests:

```bash
# Run a single test file
perl t/math_test.t

# Run all tests with prove (TAP harness)
prove t/
prove -v t/     # verbose output
prove -r t/     # recursive
```

### Subtests and More

```perl
use Test::More;

subtest "array operations" => sub {
    my @arr = (3, 1, 4, 1, 5);
    is(scalar @arr, 5, "array has 5 elements");

    my @sorted = sort { $a <=> $b } @arr;
    is_deeply(\@sorted, [1, 1, 3, 4, 5], "sorted correctly");

    my @unique = do { my %seen; grep { !$seen{$_}++ } @arr };
    is(scalar @unique, 4, "4 unique elements");
};

subtest "hash operations" => sub {
    my %h = (a => 1, b => 2, c => 3);
    ok(exists $h{b}, "key 'b' exists");
    is($h{c}, 3, "value of 'c' is 3");

    delete $h{a};
    ok(!exists $h{a}, "key 'a' deleted");
};

done_testing();
```

## One-Liner Mastery

Perl one-liners are incredibly powerful for text processing on the command line.

### Common Flags

| Flag | Meaning |
|------|---------|
| `-e` | Execute code from command line |
| `-n` | Loop over input lines (like `while (<>) { ... }`) |
| `-p` | Like `-n`, but prints `$_` after each iteration |
| `-i` | In-place editing (with optional backup extension) |
| `-a` | Auto-split mode (splits `$_` into `@F`) |
| `-F` | Specify split delimiter for `-a` |
| `-l` | Auto-chomp and add newline to print |
| `-0` | Set input record separator |
| `-M` | Load a module |

### Essential One-Liners

```bash
# Print lines matching a pattern (like grep)
perl -ne 'print if /error/i' logfile.txt

# Print lines NOT matching a pattern
perl -ne 'print unless /debug/' logfile.txt

# Count lines matching a pattern
perl -ne '$c++ if /ERROR/; END { print "$c\n" }' logfile.txt

# Extract and print specific fields (like awk)
perl -lane 'print "$F[0] $F[2]"' data.txt

# Process CSV
perl -F, -lane 'print $F[1]' data.csv

# Find and replace across files
perl -pi -e 's/old_function/new_function/g' *.pl

# Find and replace with backup
perl -pi.bak -e 's/http:/https:/g' config.txt

# Sum a column of numbers
perl -lane '$sum += $F[0]; END { print $sum }' numbers.txt

# Print unique lines (preserving order)
perl -ne 'print unless $seen{$_}++' file.txt

# Add line numbers
perl -pe '$_ = sprintf "%4d: %s", $., $_' file.txt

# Print lines between two patterns
perl -ne 'print if /START/../END/' file.txt

# Reverse lines in a file
perl -e 'print reverse <>' file.txt

# Convert tabs to spaces
perl -pe 's/\t/    /g' file.txt

# Remove trailing whitespace
perl -pe 's/\s+$/\n/' file.txt

# JSON pretty-print
echo '{"name":"Alice","age":30}' | perl -MJSON::PP -e '
    local $/;
    print JSON::PP->new->pretty->encode(decode_json(<STDIN>))
'

# Generate a random password
perl -e 'print map { ("a".."z","A".."Z",0..9)[rand 62] } 1..16; print "\n"'

# Show disk usage sorted by size
du -sh * | perl -e 'print sort { ($b=~/[\d.]+/)[0] <=> ($a=~/[\d.]+/)[0] } <>'
```

## Performance Optimization

### Benchmarking

```perl
use Benchmark qw(cmpthese timethis);

# Compare different approaches
cmpthese(1_000_000, {
    'concatenation' => sub {
        my $s = "Hello" . ", " . "World" . "!";
    },
    'interpolation' => sub {
        my $a = "Hello";
        my $s = "$a, World!";
    },
    'join' => sub {
        my $s = join(", ", "Hello", "World!");
    },
});

# Time a specific operation
timethis(100_000, sub {
    my @sorted = sort { $a <=> $b } (1..100);
});
```

### Profiling

```bash
# Use Devel::NYTProf for detailed profiling
perl -d:NYTProf script.pl
nytprofhtml    # generates an HTML report
```

### Common Optimizations

```perl
# 1. Pre-compile regular expressions
my $pattern = qr/\b\d{3}-\d{4}\b/;   # compile once
for my $line (@lines) {
    if ($line =~ $pattern) { ... }    # reuse many times
}

# 2. Use index() instead of regex for simple string matching
if (index($string, "needle") >= 0) {  # faster than /needle/
    ...
}

# 3. Avoid unnecessary copies of large data
sub process_data {
    my ($data_ref) = @_;    # pass reference, not copy
    for my $item (@$data_ref) {
        ...
    }
}

# 4. Use hashes for O(1) lookups instead of arrays
my %valid = map { $_ => 1 } @valid_items;
if ($valid{$item}) { ... }    # O(1) instead of O(n) grep

# 5. Read files efficiently
# Bad: slurp then split (uses 2x memory)
# Good: process line by line
open(my $fh, "<", $file) or die $!;
while (<$fh>) {
    chomp;
    process($_);
}

# 6. Use List::Util instead of manual loops
use List::Util qw(sum min max first);
my $total = sum @numbers;     # faster than manual loop
my $minimum = min @numbers;
```

## IPC and Networking

### Socket Programming

```perl
use IO::Socket::INET;

# Simple TCP client
my $socket = IO::Socket::INET->new(
    PeerAddr => 'httpbin.org',
    PeerPort => 80,
    Proto    => 'tcp',
) or die "Cannot connect: $!\n";

print $socket "GET / HTTP/1.0\r\nHost: httpbin.org\r\n\r\n";

while (my $line = <$socket>) {
    print $line;
    last if $line =~ /^\r?\n$/;   # stop at end of headers
}

close $socket;
```

### HTTP with HTTP::Tiny

```perl
use HTTP::Tiny;
use JSON::PP;

my $http = HTTP::Tiny->new(timeout => 10);

# GET request
my $response = $http->get('https://jsonplaceholder.typicode.com/posts/1');
if ($response->{success}) {
    my $post = decode_json($response->{content});
    print "Title: $post->{title}\n";
}

# POST request
my $resp = $http->post('https://jsonplaceholder.typicode.com/posts', {
    content => encode_json({
        title  => "My Post",
        body   => "Post content here",
        userId => 1,
    }),
    headers => { 'Content-Type' => 'application/json' },
});

if ($resp->{success}) {
    my $created = decode_json($resp->{content});
    print "Created post ID: $created->{id}\n";
}
```

## Multithreading and Parallel Processing

### Using fork for Parallelism

```perl
use POSIX qw(:sys_wait_h);

my @urls = (
    "https://example.com/page1",
    "https://example.com/page2",
    "https://example.com/page3",
    "https://example.com/page4",
);

my @pids;
for my $url (@urls) {
    my $pid = fork();
    die "Cannot fork: $!\n" unless defined $pid;

    if ($pid == 0) {
        # Child process
        print "Processing $url (PID $$)\n";
        sleep(int(rand(3)) + 1);   # simulate work
        print "Done: $url\n";
        exit 0;
    }

    push @pids, $pid;
}

# Wait for all children
for my $pid (@pids) {
    waitpid($pid, 0);
}

print "All tasks complete.\n";
```

### Using Parallel::ForkManager

```perl
# use Parallel::ForkManager;
#
# my $pm = Parallel::ForkManager->new(4);   # max 4 parallel processes
#
# my @tasks = 1..20;
#
# for my $task (@tasks) {
#     $pm->start and next;   # forks a child
#
#     # Child process
#     print "Processing task $task (PID $$)\n";
#     sleep 1;
#
#     $pm->finish;   # child exits
# }
#
# $pm->wait_all_children;
# print "All done.\n";
```

## Unicode and Internationalization

```perl
use utf8;                  # source file is in UTF-8
use open qw(:std :utf8);  # standard handles use UTF-8

# Unicode strings
my $greeting = "こんにちは";    # Japanese
my $emoji = "Hello 🌍";

print "Greeting: $greeting\n";
print "Length: ", length($greeting), "\n";   # 5 characters

# Unicode properties in regex
my $text = "Café résumé naïve";
my @accented = ($text =~ /\w*[\x{80}-\x{FFFF}]\w*/g);
print "Accented words: @accented\n";

# Unicode-aware case conversion
use Unicode::UCD qw(charinfo);
my $upper = uc("straße");     # STRASSE (German sharp S)
print "Upper: $upper\n";
```

## Chapter Summary

- DBI provides a unified interface for database access, with parameterized queries for security.
- Perl offers rich process management via `system()`, backticks, `fork()`, and signals.
- The Test::More framework and `prove` tool provide a mature testing ecosystem.
- Perl one-liners are exceptionally powerful for text processing on the command line.
- Profile with `Devel::NYTProf` and benchmark with `Benchmark` before optimizing.
- HTTP::Tiny (core module) handles basic web requests; use LWP or Mojo for advanced needs.

---

**Previous**: [Chapter 10 — Error Handling](10-error-handling.md)
**Next**: [Chapter 12 — Practical Examples](12-practical-examples.md)
