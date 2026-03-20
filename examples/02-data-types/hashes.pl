#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Hash Variables (%) — Key-Value Pairs
# ============================================================

say "=== CREATING HASHES ===";

my %person = (
    name   => "Alice",
    age    => 30,
    email  => 'alice@example.com',
    city   => "New York",
);

my %grades = (
    "Alice"   => 95,
    "Bob"     => 82,
    "Charlie" => 91,
    "Diana"   => 88,
);

say "\n=== ACCESSING VALUES ===";

say "Name:  $person{name}";
say "Age:   $person{age}";
say "Email: $person{email}";

say "\n=== MODIFYING HASHES ===";

$person{phone} = "555-1234";
$person{age}   = 31;
say "Added phone: $person{phone}";
say "Updated age: $person{age}";

delete $person{city};
say "Deleted 'city'";

say "\n=== CHECKING EXISTENCE ===";

if (exists $person{name}) {
    say "'name' exists in \%person";
}

if (!exists $person{city}) {
    say "'city' does not exist (we deleted it)";
}

if (defined $person{name}) {
    say "'name' is defined: $person{name}";
}

say "\n=== KEYS, VALUES, EACH ===";

my @keys   = sort keys %grades;
my @values = values %grades;

say "Keys:   @keys";
say "Values: @values";

say "\n--- Iterating with each ---";
while (my ($student, $grade) = each %grades) {
    say "  $student: $grade";
}

say "\n--- Iterating with sorted keys ---";
for my $student (sort keys %grades) {
    say "  $student => $grades{$student}";
}

say "\n=== HASH SLICES ===";

my @selected = @person{qw(name age email)};
say "Slice: @selected";

say "\n=== HASH IN BOOLEAN CONTEXT ===";

my %empty;
if (%person) { say "\%person is non-empty" }
if (!%empty) { say "\%empty is empty" }

say "\n=== COUNTING ELEMENTS ===";

my $size = scalar keys %grades;
say "Number of students: $size";

say "\n=== MERGING HASHES ===";

my %defaults = (color => "blue", size => "medium", weight => 10);
my %overrides = (color => "red", weight => 20);
my %merged = (%defaults, %overrides);

say "Merged hash:";
for my $key (sort keys %merged) {
    say "  $key => $merged{$key}";
}

say "\n=== INVERTING A HASH ===";

my %reversed = reverse %grades;
say "Inverted (grade => student):";
for my $grade (sort { $a <=> $b } keys %reversed) {
    say "  $grade => $reversed{$grade}";
}

say "\n=== WORD FREQUENCY COUNTER ===";

my $sentence = "the quick brown fox jumps over the lazy dog the fox";
my %word_count;
for my $word (split /\s+/, $sentence) {
    $word_count{$word}++;
}

say "Word frequencies:";
for my $word (sort { $word_count{$b} <=> $word_count{$a} } keys %word_count) {
    printf "  %-10s %d\n", $word, $word_count{$word};
}

say "\n--- Hashes demo complete ---";
