#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- Scalars, Arrays, and Hashes ---

say "=== SCALARS ===";

my $name    = "Alice";
my $age     = 30;
my $balance = 1042.57;
my $active  = 1;

say "Name   : $name";
say "Age    : $age";
say "Balance: \$$balance";
say "Active : $active";

# Automatic type conversion
my $str_num = "42";
my $result  = $str_num + 8;
say "\n\"42\" + 8 = $result (string converted to number)";

my $num_str = 100 . " percent";
say "100 . \" percent\" = $num_str (number converted to string)";

# Undefined values
my $undef_var;
say "\nDefined check: " . (defined($undef_var) ? "defined" : "undefined");

say "\n=== ARRAYS ===";

my @colors = ("red", "green", "blue", "yellow", "purple");
say "Colors: @colors";
say "First : $colors[0]";
say "Last  : $colors[-1]";
say "Count : " . scalar(@colors);

# Array slice
my @subset = @colors[1, 3];
say "Slice [1,3]: @subset";

# Range operator
my @nums = (1 .. 10);
say "Range 1..10: @nums";

# Array manipulation
push @colors, "orange";
say "After push 'orange': @colors";

my $popped = pop @colors;
say "Popped: $popped";

unshift @colors, "white";
say "After unshift 'white': @colors";

my $shifted = shift @colors;
say "Shifted: $shifted";

# qw() shortcut for word lists
my @days = qw(Mon Tue Wed Thu Fri Sat Sun);
say "Days: @days";

say "\n=== HASHES ===";

my %person = (
    name    => "Bob",
    age     => 25,
    city    => "New York",
    country => "USA",
);

say "Name   : $person{name}";
say "City   : $person{city}";

# Add and modify entries
$person{email} = "bob\@example.com";
$person{age} = 26;

say "\nAll entries:";
for my $key (sort keys %person) {
    say "  $key => $person{$key}";
}

# Check existence
say "\nHas 'email'? " . (exists $person{email} ? "Yes" : "No");
say "Has 'phone'? " . (exists $person{phone} ? "Yes" : "No");

# Delete
delete $person{country};
say "\nAfter deleting 'country':";
say "  Keys: " . join(", ", sort keys %person);

# Hash from two arrays
my @keys   = qw(a b c d);
my @values = (1, 2, 3, 4);
my %map;
@map{@keys} = @values;
say "\nHash from arrays: " . join(", ", map { "$_ => $map{$_}" } sort keys %map);

say "\nDone!";
