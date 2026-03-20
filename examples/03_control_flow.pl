#!/usr/bin/perl
# 03_control_flow.pl — Conditionals and Loops
use strict;
use warnings;
use feature 'say';

say "=" x 50;
say "  Perl Control Flow Demo";
say "=" x 50;

# --- IF / ELSIF / ELSE ---
say "\n--- Conditionals ---";

my $score = 82;
say "Score: $score";

if ($score >= 90) {
    say "Grade: A (Excellent!)";
} elsif ($score >= 80) {
    say "Grade: B (Good job!)";
} elsif ($score >= 70) {
    say "Grade: C (Satisfactory)";
} elsif ($score >= 60) {
    say "Grade: D (Needs improvement)";
} else {
    say "Grade: F (Failed)";
}

# unless
my $logged_in = 0;
unless ($logged_in) {
    say "Please log in to continue.";
}

# Postfix conditionals
say "You passed!" if $score >= 60;
say "Study harder!" unless $score >= 60;

# Ternary operator
my $status = ($score >= 60) ? "PASS" : "FAIL";
say "Status: $status";

# --- LOOPS ---
say "\n--- For Loop (C-style) ---";
for (my $i = 1; $i <= 5; $i++) {
    print "$i ";
}
say "";

# Foreach
say "\n--- Foreach Loop ---";
my @animals = ("cat", "dog", "bird", "fish", "rabbit");
foreach my $animal (@animals) {
    say "  I have a $animal";
}

# Range operator
say "\n--- Range Operator ---";
for my $n (1..10) {
    print "$n ";
}
say "";

# While loop
say "\n--- While Loop ---";
my $countdown = 5;
while ($countdown > 0) {
    print "$countdown... ";
    $countdown--;
}
say "Liftoff!";

# Until loop
say "\n--- Until Loop ---";
my $temp = 20;
until ($temp >= 100) {
    $temp += 15;
}
say "Water boils at simulated temp: $temp°C";

# Do-while
say "\n--- Do-While Loop ---";
my $tries = 0;
do {
    $tries++;
} while ($tries < 3);
say "Attempted $tries times";

# Loop control: next, last, redo
say "\n--- Loop Control ---";
say "Odd numbers 1-20 (skipping evens, stopping at 15):";
for my $i (1..20) {
    next if $i % 2 == 0;
    last if $i > 15;
    print "$i ";
}
say "";

# Nested loops with labels
say "\n--- Labeled Loops ---";
say "Multiplication table:";
OUTER: for my $i (1..5) {
    for my $j (1..$i) {
        printf "%4d", $i * $j;
    }
    print "\n";
}

# Loop with index using array
say "\n--- Loop with Index ---";
my @cities = ("Tokyo", "London", "Paris", "Sydney", "Cairo");
for my $idx (0 .. $#cities) {
    say "  $idx: $cities[$idx]";
}

# FizzBuzz
say "\n--- FizzBuzz (1-30) ---";
for my $n (1..30) {
    if ($n % 15 == 0) {
        print "FizzBuzz ";
    } elsif ($n % 3 == 0) {
        print "Fizz ";
    } elsif ($n % 5 == 0) {
        print "Buzz ";
    } else {
        print "$n ";
    }
}
say "";

say "\nDone!";
