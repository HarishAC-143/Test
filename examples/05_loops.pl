#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== FOR LOOP (C-style) ===";

for (my $i = 1; $i <= 5; $i++) {
    print "$i ";
}
say "";

say "\n=== FOREACH LOOP ===";

my @languages = ("Perl", "Python", "Ruby", "Go", "Rust");

foreach my $lang (@languages) {
    say "  I know $lang";
}

# foreach and for are interchangeable in Perl
say "\nUsing 'for' as 'foreach':";
for my $lang (@languages) {
    say "  -> $lang";
}

say "\n=== FOREACH WITH INDEX ===";

for my $i (0..$#languages) {
    say "  [$i] $languages[$i]";
}

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
say "";

say "\n=== LOOP CONTROL: next, last, redo ===";

say "\nSkipping even numbers with 'next':";
for my $i (1..10) {
    next if $i % 2 == 0;
    print "$i ";
}
say "";

say "\nStopping at 7 with 'last':";
for my $i (1..20) {
    last if $i > 7;
    print "$i ";
}
say "";

say "\n=== NESTED LOOPS WITH LABELS ===";

OUTER: for my $i (1..3) {
    for my $j (1..3) {
        next OUTER if $j == 2;
        say "  i=$i, j=$j";
    }
}

say "\n=== LOOPING OVER HASHES ===";

my %scores = (
    Alice   => 95,
    Bob     => 82,
    Charlie => 91,
    Diana   => 78,
);

say "Student scores:";
for my $name (sort keys %scores) {
    printf "  %-10s %3d %s\n", $name, $scores{$name},
           ($scores{$name} >= 90 ? "(Honors)" : "");
}

say "\n=== WHILE WITH EACH ===";

say "Using 'each' to iterate hash:";
while (my ($name, $score) = each %scores) {
    say "  $name scored $score";
}

say "\n=== POSTFIX LOOPS ===";

say "  $_" for 1..5;

print "  $_ " for ("a".."e");
say "";

say "\n=== PRACTICAL: Multiplication Table ===";

my $size = 5;
printf "%4s", "";
printf "%4d", $_ for 1..$size;
say "";
say "    " . "----" x $size;

for my $i (1..$size) {
    printf "%3d|", $i;
    for my $j (1..$size) {
        printf "%4d", $i * $j;
    }
    say "";
}

say "\n=== INFINITE LOOP WITH EXIT CONDITION ===";

my $attempts = 0;
while (1) {
    $attempts++;
    my $random = int(rand(10));
    if ($random == 7) {
        say "Found 7 after $attempts attempts!";
        last;
    }
}
