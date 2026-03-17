#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use Carp;

say "=== DIE AND WARN ===";

# warn prints a message but continues execution
warn "This is a warning — execution continues.\n";
say "See? Still running after warn.";

say "\n=== EVAL FOR EXCEPTION HANDLING ===";

# eval catches fatal errors (like try/catch)
eval {
    my $result = 10 / 0;
    say "This won't print: $result";
};
if ($@) {
    say "Caught error: $@";
}

eval {
    die "Something went wrong!";
};
if ($@) {
    say "Caught die: $@";
}

eval {
    die { code => 404, message => "Not Found" };
};
if (ref $@ eq 'HASH') {
    say "Structured error: code=$@->{code}, message=$@->{message}";
}

say "\n=== NESTED EVAL ===";

eval {
    say "Outer eval: starting";
    eval {
        die "Inner error";
    };
    if ($@) {
        say "Inner eval caught: $@";
    }
    say "Outer eval: still running";
    die "Outer error";
};
if ($@) {
    say "Outer eval caught: $@";
}

say "\n=== OPEN WITH ERROR HANDLING ===";

my $filename = "/nonexistent/file.txt";

# The idiomatic Perl way
if (open(my $fh, '<', $filename)) {
    my @lines = <$fh>;
    close($fh);
    say "Read " . scalar @lines . " lines";
} else {
    say "Could not open '$filename': $!";
}

# Using die (aborts unless in eval)
eval {
    open(my $fh, '<', $filename)
        or die "Cannot open '$filename': $!";
};
say "Eval caught file error: $@" if $@;

say "\n=== CARP MODULE ===";

sub validate_age {
    my ($age) = @_;
    if (!defined $age) {
        carp "Age is undefined (warning from caller's perspective)";
        return;
    }
    if ($age < 0) {
        croak "Age cannot be negative: $age";
    }
    if ($age > 150) {
        carp "Age seems unusually high: $age";
    }
    return $age;
}

# carp shows the caller's location in the warning
validate_age(200);

eval { validate_age(-5) };
say "Caught croak: $@" if $@;

validate_age(undef);

say "\n=== CUSTOM EXCEPTION CLASS ===";

{
    package AppException;

    sub new {
        my ($class, %args) = @_;
        return bless {
            message => $args{message} // "Unknown error",
            code    => $args{code}    // 500,
            time    => scalar localtime,
        }, $class;
    }

    sub message { return $_[0]->{message}; }
    sub code    { return $_[0]->{code}; }
    sub time    { return $_[0]->{time}; }

    sub stringify {
        my ($self) = @_;
        return sprintf "[%s] Error %d: %s", $self->time, $self->code, $self->message;
    }
}

eval {
    die AppException->new(
        message => "Database connection timeout",
        code    => 503,
    );
};
if (ref $@ && $@->isa('AppException')) {
    say "Custom exception caught:";
    say "  " . $@->stringify();
    say "  Code: " . $@->code();
}

say "\n=== PRACTICAL: SAFE FILE PROCESSING ===";

sub process_file {
    my ($filename) = @_;

    unless (defined $filename && length $filename) {
        die "Filename is required\n";
    }

    unless (-e $filename) {
        die "File '$filename' does not exist\n";
    }

    unless (-r $filename) {
        die "File '$filename' is not readable\n";
    }

    open(my $fh, '<', $filename)
        or die "Cannot open '$filename': $!\n";

    my $line_count = 0;
    while (<$fh>) {
        $line_count++;
    }
    close($fh);

    return $line_count;
}

for my $file (undef, "", "/no/such/file", $0) {
    eval {
        my $count = process_file($file);
        say "  '$file' has $count lines";
    };
    if ($@) {
        chomp $@;
        my $display = defined($file) ? "'$file'" : "undef";
        say "  Error processing $display: $@";
    }
}

say "\n=== CLEANUP WITH eval ===";

say "Simulating resource management:";

eval {
    say "  1. Acquiring resource...";
    my $resource = "database handle";
    say "  2. Doing work with $resource...";
    die "Unexpected failure during work!\n";
    say "  3. This won't execute";
};
my $error = $@;
say "  4. Cleanup always runs (like 'finally')";
if ($error) {
    say "  5. Handling error: $error";
}
