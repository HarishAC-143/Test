# Chapter 10: Error Handling

Robust error handling is essential for production Perl code. Perl offers multiple approaches, from simple `die`/`warn` to sophisticated exception objects.

## Basic Error Handling

### die and warn

```perl
#!/usr/bin/perl
use strict;
use warnings;

# warn: print a warning but continue execution
warn "This is a warning message\n";

# die: terminate the program with an error message
# die "Fatal error: something went wrong\n";

# The most common pattern: "do or die"
open(my $fh, "<", "missing_file.txt")
    or die "Cannot open file: $!\n";

# $! contains the system error message
# Without \n, die appends the file and line number automatically
# die "Something failed: $!";   # prints: Something failed: No such file or directory at script.pl line 10.
```

### The or die Pattern

```perl
# File operations
open(my $fh, ">", "output.txt") or die "Cannot open: $!\n";
print $fh "data\n"              or die "Cannot write: $!\n";
close $fh                       or die "Cannot close: $!\n";

# System commands
chdir "/some/directory"         or die "Cannot chdir: $!\n";
mkdir "new_dir"                 or die "Cannot mkdir: $!\n";
unlink "old_file.txt"           or die "Cannot delete: $!\n";
```

## eval — Catching Exceptions

`eval` is Perl's try/catch mechanism. It traps `die` calls and stores the error in `$@`.

```perl
# eval BLOCK — catches runtime errors
eval {
    my $result = 10 / 0;
    print "Result: $result\n";
};
if ($@) {
    print "Caught error: $@\n";
    # Output: Caught error: Illegal division by zero at script.pl line 3.
}

# Practical example: safe file reading
sub read_file_safely {
    my ($filename) = @_;

    my $content;
    eval {
        open(my $fh, "<", $filename)
            or die "Cannot open '$filename': $!";
        local $/;
        $content = <$fh>;
        close $fh;
    };

    if ($@) {
        warn "Warning: $@";
        return undef;
    }

    return $content;
}

my $data = read_file_safely("config.txt");
if (defined $data) {
    print "File contents: $data\n";
} else {
    print "Using default configuration.\n";
}
```

### Nested eval Blocks

```perl
eval {
    print "Outer block starting\n";

    eval {
        print "Inner block starting\n";
        die "Inner error!";
    };

    if ($@) {
        print "Caught inner error: $@\n";
    }

    print "Outer block continuing\n";
    die "Outer error!";
};

if ($@) {
    print "Caught outer error: $@\n";
}
```

### Caveats with eval and $@

```perl
# $@ can be clobbered by code in destructors or other eval blocks
# The safe pattern:

eval {
    some_risky_operation();
    1;   # explicit true return on success
} or do {
    my $error = $@ || "Unknown error";
    handle_error($error);
};
```

## Try::Tiny — Clean Exception Handling

`Try::Tiny` is a popular CPAN module that provides a cleaner try/catch syntax and handles the `$@` caveats automatically.

```perl
use Try::Tiny;

try {
    die "Something broke!";
} catch {
    print "Error: $_\n";    # $_ contains the error, not $@
} finally {
    print "Cleanup code runs regardless.\n";
};

# Multiple error types
try {
    open(my $fh, "<", "data.txt") or die "FileError: Cannot open: $!";
    my $data = decode_json(<$fh>);
    close $fh;
} catch {
    if (/^FileError:/) {
        warn "File problem: $_";
    } elsif (/JSON/) {
        warn "JSON parsing error: $_";
    } else {
        die $_;    # re-throw unknown errors
    }
};
```

## Exception Objects

For complex applications, throw exception objects instead of strings.

```perl
package Exception;

use strict;
use warnings;
use overload '""' => \&to_string;

sub new {
    my ($class, %args) = @_;
    return bless {
        message => $args{message} // "Unknown error",
        code    => $args{code}    // 0,
        file    => (caller(0))[1],
        line    => (caller(0))[2],
    }, $class;
}

sub message { $_[0]->{message} }
sub code    { $_[0]->{code} }

sub to_string {
    my ($self) = @_;
    return sprintf("%s (code: %d) at %s line %d",
        $self->{message}, $self->{code}, $self->{file}, $self->{line});
}

sub throw {
    my ($class, %args) = @_;
    die $class->new(%args);
}

1;

package FileException;
use parent 'Exception';

sub new {
    my ($class, %args) = @_;
    $args{code} //= 100;
    return $class->SUPER::new(%args);
}

1;

package NetworkException;
use parent 'Exception';

sub new {
    my ($class, %args) = @_;
    $args{code} //= 200;
    return $class->SUPER::new(%args);
}

1;
```

Usage:

```perl
use Try::Tiny;

sub process_file {
    my ($filename) = @_;

    open(my $fh, "<", $filename)
        or FileException->throw(message => "Cannot open $filename: $!");

    # ... process file ...
    close $fh;
}

try {
    process_file("missing.txt");
} catch {
    if (ref $_ && $_->isa("FileException")) {
        printf "File error (code %d): %s\n", $_->code, $_->message;
    } elsif (ref $_ && $_->isa("NetworkException")) {
        printf "Network error (code %d): %s\n", $_->code, $_->message;
    } else {
        die $_;   # re-throw unknown errors
    }
};
```

## Defensive Programming Patterns

### Input Validation

```perl
use Carp qw(croak confess);
use Scalar::Util qw(looks_like_number blessed);

sub divide {
    my ($a, $b) = @_;

    croak "First argument must be a number"  unless looks_like_number($a);
    croak "Second argument must be a number" unless looks_like_number($b);
    croak "Division by zero" if $b == 0;

    return $a / $b;
}

# croak reports the error from the CALLER's perspective
eval { divide("abc", 5) };
print "Error: $@\n";   # Error: First argument must be a number at caller.pl line 15

# confess gives a full stack trace
sub deep_function {
    confess "Something went wrong deep in the stack";
}
```

### The Carp Module

| Function | Behavior |
|----------|----------|
| `carp` | Like `warn`, but reports from caller's perspective |
| `croak` | Like `die`, but reports from caller's perspective |
| `cluck` | Like `warn`, with a full stack trace |
| `confess` | Like `die`, with a full stack trace |

```perl
use Carp qw(carp croak cluck confess);

sub validate_age {
    my ($age) = @_;
    croak "Age must be positive" unless $age > 0;
    croak "Age must be reasonable" unless $age < 150;
    carp "Warning: age over 100 is unusual" if $age > 100;
    return 1;
}
```

### Guard Clauses

```perl
sub process_order {
    my ($order) = @_;

    return { error => "No order provided" }      unless $order;
    return { error => "Missing customer" }        unless $order->{customer};
    return { error => "No items in order" }       unless @{$order->{items} // []};
    return { error => "Invalid total" }           unless ($order->{total} // 0) > 0;

    # Main processing logic (only reached if all guards pass)
    my $result = {
        order_id => int(rand(100000)),
        status   => "confirmed",
        customer => $order->{customer},
        total    => $order->{total},
    };

    return $result;
}
```

### Retry Pattern

```perl
sub retry {
    my (%args) = @_;
    my $action     = $args{action};
    my $max_tries  = $args{tries}   // 3;
    my $delay      = $args{delay}   // 1;
    my $backoff    = $args{backoff} // 2;
    my $on_failure = $args{on_failure};

    my $attempt = 0;
    my $current_delay = $delay;

    while ($attempt < $max_tries) {
        $attempt++;
        my $result;
        my $ok = eval {
            $result = $action->();
            1;
        };

        return $result if $ok;

        my $error = $@;
        if ($on_failure) {
            $on_failure->($attempt, $error);
        }

        if ($attempt < $max_tries) {
            warn "Attempt $attempt failed, retrying in ${current_delay}s...\n";
            sleep $current_delay;
            $current_delay *= $backoff;
        }
    }

    die "Failed after $max_tries attempts\n";
}

# Usage
my $data = retry(
    action => sub {
        my $resp = HTTP::Tiny->new->get("https://api.example.com/data");
        die "HTTP error: $resp->{status}" unless $resp->{success};
        return $resp->{content};
    },
    tries   => 3,
    delay   => 2,
    backoff => 2,
    on_failure => sub {
        my ($attempt, $error) = @_;
        warn "Attempt $attempt failed: $error";
    },
);
```

## Practical Example: Robust Data Processor

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Carp qw(croak);

sub process_records {
    my ($filename) = @_;
    croak "Filename required" unless $filename;

    my @results;
    my @errors;
    my $line_num = 0;

    open(my $fh, "<", $filename) or croak "Cannot open '$filename': $!";

    while (my $line = <$fh>) {
        $line_num++;
        chomp $line;
        next if $line =~ /^\s*$/ || $line =~ /^#/;

        my $result = eval {
            parse_record($line, $line_num);
        };

        if ($@) {
            push @errors, {
                line    => $line_num,
                content => $line,
                error   => $@,
            };
        } else {
            push @results, $result;
        }
    }

    close $fh;

    return {
        records  => \@results,
        errors   => \@errors,
        total    => $line_num,
        success  => scalar @results,
        failures => scalar @errors,
    };
}

sub parse_record {
    my ($line, $line_num) = @_;

    my @fields = split /,/, $line;
    die "Expected 3 fields, got " . scalar(@fields) . "\n"
        unless @fields == 3;

    my ($name, $age, $email) = @fields;

    die "Invalid age '$age'\n" unless $age =~ /^\d+$/;
    die "Invalid email '$email'\n" unless $email =~ /\@/;

    return {
        name  => $name,
        age   => int($age),
        email => $email,
    };
}

# Demonstration with inline data
my $test_data = <<'END';
Alice,30,alice@example.com
Bob,invalid_age,bob@example.com
Carol,28,carol@example.com
Dave,35
Eve,22,eve_at_example
Frank,40,frank@example.com
END

open(my $tmp, ">", "/tmp/test_data.csv") or die $!;
print $tmp $test_data;
close $tmp;

my $report = process_records("/tmp/test_data.csv");

printf "Processed %d lines: %d success, %d failures\n",
    $report->{total}, $report->{success}, $report->{failures};

if (@{$report->{errors}}) {
    print "\nErrors:\n";
    for my $err (@{$report->{errors}}) {
        printf "  Line %d: %s  -> %s", $err->{line}, $err->{content}, $err->{error};
    }
}

print "\nValid records:\n";
for my $rec (@{$report->{records}}) {
    printf "  %s (age %d, %s)\n", $rec->{name}, $rec->{age}, $rec->{email};
}

unlink "/tmp/test_data.csv";
```

## Chapter Summary

- Use `die` to throw errors and `warn` for non-fatal warnings.
- The `or die` pattern is idiomatic for checking system call results.
- `eval { }` catches exceptions; errors are stored in `$@`.
- `Try::Tiny` provides a cleaner, safer try/catch/finally syntax.
- The `Carp` module (`croak`, `confess`) reports errors from the caller's perspective.
- Exception objects provide structured error information for complex applications.
- Defensive patterns (guard clauses, input validation, retry logic) make code more robust.

---

**Previous**: [Chapter 9 — Object-Oriented Perl](09-object-oriented-perl.md)
**Next**: [Chapter 11 — Advanced Topics](11-advanced-topics.md)
