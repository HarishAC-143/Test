#!/usr/bin/perl
# Demonstrates error handling patterns in Perl.

use strict;
use warnings;
use Carp qw(croak confess);

print "=== BASIC ERROR HANDLING ===\n\n";

sub divide {
    my ($a, $b) = @_;
    croak "Division by zero" if $b == 0;
    return $a / $b;
}

for my $pair ([10, 3], [20, 0], [100, 7]) {
    eval {
        my $result = divide($pair->[0], $pair->[1]);
        printf "  %d / %d = %.4f\n", $pair->[0], $pair->[1], $result;
    };
    if ($@) {
        printf "  %d / %d = ERROR: %s", $pair->[0], $pair->[1], $@;
    }
}

print "\n=== NESTED EVAL ===\n\n";

sub process_data {
    my ($data) = @_;
    die "No data provided\n" unless defined $data;
    die "Data must be a hash ref\n" unless ref $data eq 'HASH';
    die "Missing 'name' field\n" unless exists $data->{name};
    die "Missing 'value' field\n" unless exists $data->{value};
    return "Processed: $data->{name} = $data->{value}";
}

my @test_cases = (
    undef,
    "not a hash",
    { name => "test" },
    { value => 42 },
    { name => "temperature", value => 72 },
);

for my $i (0..$#test_cases) {
    eval {
        my $result = process_data($test_cases[$i]);
        print "  Test $i: $result\n";
    };
    if ($@) {
        chomp(my $err = $@);
        printf "  Test %d: FAILED - %s\n", $i, $err;
    }
}

print "\n=== RETRY PATTERN ===\n\n";

{
    my $attempt_counter = 0;

    sub unreliable_operation {
        $attempt_counter++;
        if ($attempt_counter < 3) {
            die "Temporary failure (attempt $attempt_counter)\n";
        }
        return "Success on attempt $attempt_counter!";
    }

    sub retry_operation {
        my ($action, $max_retries) = @_;
        $max_retries //= 3;

        for my $try (1..$max_retries) {
            my $result = eval { $action->() };
            if ($@) {
                chomp(my $err = $@);
                print "  Attempt $try failed: $err\n";
                next if $try < $max_retries;
                die "All $max_retries attempts failed. Last error: $err\n";
            }
            return $result;
        }
    }

    eval {
        my $result = retry_operation(\&unreliable_operation, 5);
        print "  Result: $result\n";
    };
    if ($@) {
        print "  Final failure: $@\n";
    }
}

print "\n=== GUARD CLAUSES ===\n\n";

sub validate_user {
    my (%user) = @_;
    my @errors;

    push @errors, "name is required"            unless $user{name};
    push @errors, "name must be 2-50 chars"     if $user{name} && (length($user{name}) < 2 || length($user{name}) > 50);
    push @errors, "email is required"           unless $user{email};
    push @errors, "email format invalid"        if $user{email} && $user{email} !~ /^[\w.+-]+@[\w.-]+\.\w{2,}$/;
    push @errors, "age must be 0-150"           if defined $user{age} && ($user{age} < 0 || $user{age} > 150);

    return @errors ? { valid => 0, errors => \@errors }
                   : { valid => 1 };
}

my @users = (
    { name => "Alice", email => "alice\@example.com", age => 30 },
    { name => "",      email => "invalid",            age => -5 },
    { name => "B",     email => "bob\@example.com" },
    { name => "Carol", email => "carol\@example.com", age => 200 },
);

for my $user (@users) {
    my $result = validate_user(%$user);
    printf "  %-10s: %s", $user->{name} || "(empty)", $result->{valid} ? "VALID" : "INVALID";
    unless ($result->{valid}) {
        print " — ", join("; ", @{$result->{errors}});
    }
    print "\n";
}

print "\n=== CLEANUP WITH eval ===\n\n";

sub process_with_cleanup {
    my ($filename) = @_;

    my $temp_file = "/tmp/perl_example_$$.tmp";
    my $fh;
    my $error;

    eval {
        open($fh, ">", $temp_file) or die "Cannot create temp file: $!\n";
        print $fh "Processing: $filename\n";
        die "Simulated processing error\n" if $filename eq "bad_file.txt";
        print $fh "Processing complete.\n";
        print "  Successfully processed '$filename'\n";
    };

    $error = $@;

    if ($fh) {
        close $fh;
    }
    unlink $temp_file if -e $temp_file;
    print "  Cleaned up temp file.\n";

    die $error if $error;
}

for my $file ("good_file.txt", "bad_file.txt", "another_file.txt") {
    eval { process_with_cleanup($file) };
    if ($@) {
        chomp(my $err = $@);
        print "  Error processing '$file': $err\n";
    }
}
