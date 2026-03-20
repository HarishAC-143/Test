#!/usr/bin/perl
# 02_variables.pl — Scalars, Arrays, and Hashes
use strict;
use warnings;
use feature 'say';

say "=" x 50;
say "  Perl Variables Demo";
say "=" x 50;

# --- SCALARS ---
say "\n--- Scalars (\$) ---";

my $name    = "Alice";
my $age     = 30;
my $height  = 5.7;
my $nothing = undef;

say "Name:   $name";
say "Age:    $age";
say "Height: $height";
say "Undef:  " . ($nothing // "(undefined)");

# Numeric vs string context
my $num_str = "42abc";
my $as_num  = $num_str + 0;
say "\nString '$num_str' in numeric context: $as_num";

# --- ARRAYS ---
say "\n--- Arrays (\@) ---";

my @fruits = ("apple", "banana", "cherry", "date", "elderberry");
say "All fruits: @fruits";
say "First:  $fruits[0]";
say "Last:   $fruits[-1]";
say "Count:  " . scalar(@fruits);

# Slicing
my @subset = @fruits[1, 3];
say "Slice [1,3]: @subset";

# Stack operations
push @fruits, "fig";
say "After push 'fig': @fruits";

my $removed = pop @fruits;
say "After pop: @fruits (removed: $removed)";

unshift @fruits, "apricot";
say "After unshift 'apricot': @fruits";

$removed = shift @fruits;
say "After shift: @fruits (removed: $removed)";

# Sorting
my @sorted = sort @fruits;
say "Sorted: @sorted";

my @reversed = reverse @fruits;
say "Reversed: @reversed";

# Join and Split
my $csv = join(", ", @fruits);
say "Joined: $csv";

my @parts = split(/,\s*/, "one, two, three, four");
say "Split: @parts";

# Grep and Map
my @long_names = grep { length($_) > 5 } @fruits;
say "Names > 5 chars: @long_names";

my @upper = map { uc($_) } @fruits;
say "Uppercase: @upper";

# --- HASHES ---
say "\n--- Hashes (%) ---";

my %person = (
    name    => "Bob",
    age     => 25,
    city    => "New York",
    country => "USA",
);

say "Name: $person{name}";
say "City: $person{city}";

# Adding and modifying
$person{email} = "bob\@example.com";
$person{age} = 26;
say "Email: $person{email}";
say "Updated age: $person{age}";

# Check existence
say "Has 'name': " . (exists $person{name} ? "yes" : "no");
say "Has 'phone': " . (exists $person{phone} ? "yes" : "no");

# Iteration
say "\nAll entries:";
for my $key (sort keys %person) {
    printf "  %-10s => %s\n", $key, $person{$key};
}

# Delete
delete $person{country};
say "\nAfter deleting 'country':";
say "Keys: " . join(", ", sort keys %person);

# Hash slice
my @info = @person{qw(name age city)};
say "Hash slice (name, age, city): @info";

say "\nDone!";
