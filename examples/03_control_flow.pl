#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- Conditionals and Loops ---

say "=== IF / ELSIF / ELSE ===";

my $score = 85;
if ($score >= 90) {
    say "Grade: A (Excellent!)";
} elsif ($score >= 80) {
    say "Grade: B (Good job!)";
} elsif ($score >= 70) {
    say "Grade: C (Satisfactory)";
} elsif ($score >= 60) {
    say "Grade: D (Needs improvement)";
} else {
    say "Grade: F (Failing)";
}

say "\n=== UNLESS ===";

my $is_weekend = 0;
unless ($is_weekend) {
    say "Time to work!";
}

say "\n=== TERNARY OPERATOR ===";

my $age = 20;
my $can_vote = ($age >= 18) ? "Yes" : "No";
say "Age $age — Can vote? $can_vote";

say "\n=== POSTFIX CONDITIONALS ===";

my $temp = 105;
say "It's hot!" if $temp > 100;
say "Bundle up!" unless $temp > 50;

say "\n=== FOR LOOP (C-style) ===";

for (my $i = 1; $i <= 5; $i++) {
    print "$i ";
}
print "\n";

say "\n=== FOREACH LOOP ===";

my @fruits = qw(apple banana cherry date elderberry);
foreach my $fruit (@fruits) {
    say "  Fruit: $fruit";
}

say "\n=== FOR with \$_ (default variable) ===";

say "  Uppercased:" ;
for (@fruits) {
    print "  " . uc($_);
}
print "\n";

say "\n=== WHILE LOOP ===";

my $countdown = 5;
while ($countdown > 0) {
    print "$countdown... ";
    $countdown--;
}
say "Liftoff!";

say "\n=== UNTIL LOOP ===";

my $n = 1;
until ($n > 5) {
    print "$n ";
    $n++;
}
print "\n";

say "\n=== LOOP CONTROL: next, last ===";

say "Odd numbers up to 15:";
for my $i (1 .. 20) {
    next if $i % 2 == 0;
    last if $i > 15;
    print "$i ";
}
print "\n";

say "\n=== LABELED LOOPS ===";

say "Multiplication table (skipping diagonal):";
OUTER: for my $i (1 .. 4) {
    for my $j (1 .. 4) {
        next OUTER if $i == $j;
        printf "%d x %d = %2d   ", $i, $j, $i * $j;
    }
    print "\n";
}

say "\n=== LOOPING OVER A HASH ===";

my %capitals = (
    France  => "Paris",
    Japan   => "Tokyo",
    Brazil  => "Brasilia",
    Egypt   => "Cairo",
);

for my $country (sort keys %capitals) {
    say "  $country => $capitals{$country}";
}

say "\n=== CHAINED COMPARISONS WITH GIVEN-LIKE LOGIC ===";

my $day = "Wednesday";
my $type =
    ($day eq "Saturday" || $day eq "Sunday") ? "Weekend" :
    ($day eq "Monday")                       ? "Start of week" :
    ($day eq "Friday")                       ? "Almost weekend" :
                                               "Midweek";
say "Today is $day — $type";

say "\nDone!";
