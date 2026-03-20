#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Error Handling Techniques
# ============================================================

say "=== BASIC DIE AND WARN ===";

warn "This is a warning — program continues\n";

eval {
    die "Something went wrong!\n";
};
if ($@) {
    say "Caught error: $@";
}

say "=== EVAL/DIE PATTERN (TRY/CATCH) ===";

sub safe_divide {
    my ($a, $b) = @_;
    die "Division by zero\n" if $b == 0;
    return $a / $b;
}

for my $pair ([10, 3], [10, 0], [100, 7]) {
    my ($a, $b) = @$pair;
    eval {
        my $result = safe_divide($a, $b);
        printf "  %d / %d = %.4f\n", $a, $b, $result;
    };
    if ($@) {
        printf "  %d / %d => ERROR: %s", $a, $b, $@;
    }
}

say "\n=== STRUCTURED ERROR OBJECTS ===";

sub validate_user {
    my (%args) = @_;

    unless ($args{name} && length($args{name}) >= 2) {
        die {
            type    => "ValidationError",
            field   => "name",
            message => "Name must be at least 2 characters",
        };
    }

    unless ($args{age} && $args{age} >= 0 && $args{age} <= 150) {
        die {
            type    => "ValidationError",
            field   => "age",
            message => "Age must be between 0 and 150",
        };
    }

    unless ($args{email} && $args{email} =~ /\w+\@\w+\.\w+/) {
        die {
            type    => "ValidationError",
            field   => "email",
            message => "Invalid email format",
        };
    }

    return { status => "valid", name => $args{name} };
}

my @test_users = (
    { name => "Alice", age => 30, email => 'alice@test.com' },
    { name => "A",     age => 25, email => 'a@test.com' },
    { name => "Bob",   age => -5, email => 'bob@test.com' },
    { name => "Carol", age => 28, email => 'invalid-email' },
);

for my $user (@test_users) {
    eval { validate_user(%$user) };
    if (my $err = $@) {
        if (ref $err eq 'HASH') {
            printf "  FAIL: [%s] %s (field: %s)\n",
                $err->{type}, $err->{message}, $err->{field};
        } else {
            say "  FAIL: $err";
        }
    } else {
        say "  OK:   $user->{name} passed validation";
    }
}

say "\n=== NESTED EVAL FOR MULTIPLE OPERATIONS ===";

sub process_pipeline {
    my @steps = (
        sub { say "  Step 1: Initializing..."; return 1 },
        sub { say "  Step 2: Loading data..."; return 1 },
        sub { say "  Step 3: Simulated failure!"; die "Data corruption detected\n" },
        sub { say "  Step 4: This won't run"; return 1 },
    );

    for my $i (0 .. $#steps) {
        eval { $steps[$i]->() };
        if ($@) {
            say "  Pipeline failed at step " . ($i + 1) . ": $@";
            return 0;
        }
    }
    return 1;
}

say "Running pipeline:";
my $success = process_pipeline();
say "Pipeline result: " . ($success ? "SUCCESS" : "FAILED");

say "\n=== ERROR HANDLING WITH FILE OPERATIONS ===";

sub read_config {
    my ($filename) = @_;
    my %config;

    open(my $fh, '<', $filename)
        or die {
            type    => "IOError",
            message => "Cannot open config file '$filename': $!",
        };

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
        if ($line =~ /^\s*(\w+)\s*=\s*(.+?)\s*$/) {
            $config{$1} = $2;
        } else {
            warn "  Warning: Malformed config line $.: '$line'\n";
        }
    }

    close($fh);
    return %config;
}

eval { my %cfg = read_config("/nonexistent/config.txt") };
if (my $err = $@) {
    if (ref $err eq 'HASH') {
        say "Config error [$err->{type}]: $err->{message}";
    } else {
        say "Config error: $err";
    }
}

say "\n=== CLEANUP WITH EVAL ===";

sub safe_operation {
    my $resource = "Resource acquired";
    say "  $resource";

    eval {
        say "  Performing operation...";
        die "Unexpected error during operation\n";
    };
    my $error = $@;

    say "  Cleanup: releasing resource";

    if ($error) {
        say "  Operation failed: $error";
        return 0;
    }

    say "  Operation succeeded";
    return 1;
}

safe_operation();

say "\n=== $! AND $? FOR SYSTEM ERRORS ===";

eval { open(my $fh, '<', '/definitely/not/a/real/file') or die "Open failed: $!\n" };
say "System error message (\$!): " . $@ if $@;

my $exit = system("perl -e 'exit 42'");
say "Command exit status (\$?): $? (raw), " . ($? >> 8) . " (exit code)";

say "\n--- Error handling demo complete ---";
