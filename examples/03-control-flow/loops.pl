#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Loop Constructs
# ============================================================

say "=== C-STYLE FOR LOOP ===";

for (my $i = 1; $i <= 5; $i++) {
    print "$i ";
}
say "";

say "\n=== FOREACH LOOP ===";

my @planets = qw(Mercury Venus Earth Mars Jupiter Saturn Uranus Neptune);

foreach my $planet (@planets) {
    say "  Planet: $planet";
}

say "\n=== FOR LOOP WITH RANGE ===";

say "Countdown:";
for my $n (reverse 1..10) {
    print "$n ";
}
say "Liftoff!";

say "\nMultiplication table (5):";
for my $i (1..10) {
    printf "  5 x %2d = %2d\n", $i, 5 * $i;
}

say "\n=== WHILE LOOP ===";

say "Fibonacci sequence (first 10):";
my ($a, $b) = (0, 1);
my $count = 0;
while ($count < 10) {
    print "$a ";
    ($a, $b) = ($b, $a + $b);
    $count++;
}
say "";

say "\n=== UNTIL LOOP ===";

my $fuel = 100;
until ($fuel <= 0) {
    $fuel -= int(rand(25)) + 1;
    $fuel = 0 if $fuel < 0;
    say "  Fuel remaining: $fuel%";
}
say "Out of fuel!";

say "\n=== DO-WHILE LOOP ===";

my $tries = 0;
my $target = int(rand(5)) + 1;
do {
    $tries++;
    my $guess = int(rand(5)) + 1;
    if ($guess == $target) {
        say "  Got it! ($target) in $tries tries";
        last;
    }
} while ($tries < 100);

say "\n=== LOOP CONTROL ===";

say "--- next (skip even numbers) ---";
for my $i (1..10) {
    next if $i % 2 == 0;
    print "$i ";
}
say "";

say "\n--- last (stop at 5) ---";
for my $i (1..100) {
    last if $i > 5;
    print "$i ";
}
say "";

say "\n--- Loop labels ---";
OUTER: for my $i (1..4) {
    for my $j (1..4) {
        next OUTER if $i == $j;
        print "($i,$j) ";
    }
}
say "";

say "\n=== POSTFIX LOOPS ===";

print "$_ " for 1..5;
say "";

say uc($_) for qw(hello world foo bar);

say "\n=== NESTED LOOPS: PATTERN PRINTING ===";

say "Right triangle:";
for my $row (1..5) {
    print "* " x $row;
    say "";
}

say "\nPyramid:";
for my $row (1..5) {
    print " " x (5 - $row);
    print "* " x $row;
    say "";
}

say "\n=== LOOP WITH INDEX (C-style vs each) ===";

my @colors = qw(red green blue yellow);

say "With index:";
for my $i (0 .. $#colors) {
    say "  [$i] $colors[$i]";
}

say "\n--- Loops demo complete ---";
