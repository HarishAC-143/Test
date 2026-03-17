#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== CREATING HASHES ===";

my %person = (
    name   => "Alice",
    age    => 30,
    email  => 'alice@example.com',
    city   => "San Francisco",
);

say "Name:  $person{name}";
say "Age:   $person{age}";
say "Email: $person{email}";

say "\n=== ADDING AND MODIFYING ===";

$person{phone} = "555-0123";
$person{age} = 31;
say "Added phone: $person{phone}";
say "Updated age: $person{age}";

say "\n=== CHECKING EXISTENCE AND DELETION ===";

if (exists $person{email}) {
    say "Email exists: $person{email}";
}

if (exists $person{address}) {
    say "Address exists";
} else {
    say "No address on file";
}

delete $person{phone};
say "After deleting phone: " . (exists $person{phone} ? "still there" : "gone");

say "\n=== ITERATING ===";

say "\nUsing keys:";
for my $key (sort keys %person) {
    say "  $key => $person{$key}";
}

say "\nUsing values:";
for my $val (values %person) {
    say "  value: $val";
}

say "\nUsing each:";
while (my ($k, $v) = each %person) {
    say "  $k => $v";
}

say "\n=== HASH SLICES ===";

my @selected_values = @person{qw(name city)};
say "Hash slice (name, city): @selected_values";

say "\n=== HASH OF ARRAYS ===";

my %courses = (
    math    => [qw(Alice Bob Carol)],
    science => [qw(Dave Eve)],
    english => [qw(Alice Frank Grace)],
);

say "\nStudents per course:";
for my $course (sort keys %courses) {
    my @students = @{$courses{$course}};
    printf "  %-10s (%d): %s\n", $course, scalar @students,
           join(", ", @students);
}

say "\n=== COUNTING WITH HASHES ===";

my $text = "the quick brown fox jumps over the lazy dog the fox";
my @words = split /\s+/, $text;

my %word_count;
$word_count{$_}++ for @words;

say "Word frequencies:";
for my $word (sort { $word_count{$b} <=> $word_count{$a} } keys %word_count) {
    printf "  %-10s %d\n", $word, $word_count{$word};
}

say "\n=== MERGING HASHES ===";

my %defaults = (
    color  => "blue",
    size   => "medium",
    shape  => "circle",
    weight => "light",
);

my %overrides = (
    color  => "red",
    weight => "heavy",
    border => "solid",
);

my %merged = (%defaults, %overrides);

say "Merged hash:";
for my $key (sort keys %merged) {
    say "  $key => $merged{$key}";
}

say "\n=== INVERTING A HASH ===";

my %capitals = (
    France  => "Paris",
    Germany => "Berlin",
    Japan   => "Tokyo",
    USA     => "Washington",
);

my %country_of = reverse %capitals;

say "Capital => Country:";
for my $capital (sort keys %country_of) {
    say "  $capital is the capital of $country_of{$capital}";
}

say "\n=== HASH AS A SET ===";

my @list_a = qw(apple banana cherry date elderberry);
my @list_b = qw(banana date fig grape);

my %set_a = map { $_ => 1 } @list_a;
my %set_b = map { $_ => 1 } @list_b;

my @intersection = grep { $set_b{$_} } @list_a;
my @union = keys %{{ map { $_ => 1 } (@list_a, @list_b) }};
my @diff = grep { !$set_b{$_} } @list_a;

say "List A:        @list_a";
say "List B:        @list_b";
say "Intersection:  @intersection";
say "Union:         " . join(" ", sort @union);
say "A - B:         @diff";
