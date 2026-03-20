#!/usr/bin/perl
# Demonstrates scalars, arrays, and hashes with practical examples.

use strict;
use warnings;
use Data::Dumper;

print "=== SCALARS ===\n\n";

my $temperature = 72.5;
my $city = "San Francisco";
my $is_sunny = 1;

printf "The temperature in %s is %.1f°F.\n", $city, $temperature;
printf "Sunny: %s\n\n", $is_sunny ? "Yes" : "No";

print "=== ARRAYS ===\n\n";

my @shopping = qw(milk bread eggs cheese butter);
print "Shopping list:\n";
for my $i (0..$#shopping) {
    printf "  %d. %s\n", $i + 1, $shopping[$i];
}

push @shopping, "apples", "oranges";
print "\nAfter adding fruits: @shopping\n";

my @sorted = sort @shopping;
print "Sorted: @sorted\n";

my @expensive = grep { length($_) > 4 } @shopping;
print "Long names: @expensive\n";

my @upper = map { uc $_ } @shopping;
print "Uppercase: @upper\n\n";

print "=== HASHES ===\n\n";

my %capitals = (
    France  => "Paris",
    Japan   => "Tokyo",
    Brazil  => "Brasilia",
    Egypt   => "Cairo",
    India   => "New Delhi",
);

for my $country (sort keys %capitals) {
    printf "  %-10s => %s\n", $country, $capitals{$country};
}

$capitals{Germany} = "Berlin";
print "\nAdded Germany. Total countries: ", scalar keys %capitals, "\n";

if (exists $capitals{Japan}) {
    print "The capital of Japan is $capitals{Japan}.\n";
}

print "\n=== NESTED DATA ===\n\n";

my @students = (
    { name => "Alice", grade => "A", scores => [95, 92, 98] },
    { name => "Bob",   grade => "B", scores => [85, 88, 82] },
    { name => "Carol", grade => "A", scores => [91, 95, 93] },
);

for my $student (@students) {
    my @scores = @{$student->{scores}};
    my $avg = 0;
    $avg += $_ for @scores;
    $avg /= scalar @scores;

    printf "%-8s Grade: %s  Scores: %-15s  Average: %.1f\n",
           $student->{name}, $student->{grade},
           join(", ", @scores), $avg;
}
