#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== SCALARS ===";

my $name     = "Alice";
my $age      = 30;
my $height   = 5.7;
my $is_admin = 1;

say "Name: $name";
say "Age: $age";
say "Height: $height feet";
say "Admin: $is_admin";

# Perl converts between strings and numbers automatically
my $num_string = "42";
my $result = $num_string + 8;
say "String '42' + 8 = $result";

my $mixed = "10abc";
my $num_part = $mixed + 5;
say "'10abc' + 5 = $num_part (Perl extracts leading number)";

say "\n=== ARRAYS ===";

my @fruits = ("apple", "banana", "cherry", "date");
say "Fruits: @fruits";
say "First fruit: $fruits[0]";
say "Last fruit: $fruits[-1]";
say "Number of fruits: " . scalar @fruits;

my @numbers = (1..10);
say "Numbers 1-10: @numbers";

my @slice = @fruits[1, 3];
say "Slice [1,3]: @slice";

say "\n=== HASHES ===";

my %user = (
    username => "alice42",
    email    => 'alice@example.com',
    age      => 30,
    active   => 1,
);

say "Username: $user{username}";
say "Email: " . $user{email};

say "\nAll user data:";
for my $key (sort keys %user) {
    say "  $key => $user{$key}";
}

say "\n=== SPECIAL VARIABLES ===";

say "Program name: $0";
say "Process ID: $$";
say "Perl version: $]";

my @args = @ARGV;
if (@args) {
    say "Command-line arguments: @args";
} else {
    say "No command-line arguments provided.";
    say "Try: perl $0 arg1 arg2 arg3";
}

say "\n=== VARIABLE SCOPE ===";

my $outer = "I'm outer";
{
    my $inner = "I'm inner";
    say "Inside block: $outer";
    say "Inside block: $inner";
}
say "Outside block: $outer";
# $inner is not accessible here

say "\n=== UNDEFINED VALUES ===";

my $undef_var;
if (defined $undef_var) {
    say "Defined";
} else {
    say "Variable is undefined (not yet assigned)";
}

$undef_var = "Now I have a value";
say "After assignment: $undef_var";
