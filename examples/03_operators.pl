#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== ARITHMETIC OPERATORS ===";

my $a = 15;
my $b = 4;

say "$a + $b  = " . ($a + $b);     # 19
say "$a - $b  = " . ($a - $b);     # 11
say "$a * $b  = " . ($a * $b);     # 60
say "$a / $b  = " . ($a / $b);     # 3.75
say "$a % $b  = " . ($a % $b);     # 3
say "$a ** $b = " . ($a ** $b);    # 50625

my $c = 10;
$c += 5;   say "After += 5: $c";   # 15
$c -= 3;   say "After -= 3: $c";   # 12
$c *= 2;   say "After *= 2: $c";   # 24
$c /= 4;   say "After /= 4: $c";   # 6
$c++;      say "After ++:   $c";    # 7
$c--;      say "After --:   $c";    # 6

say "\n=== STRING OPERATORS ===";

my $first = "Hello";
my $last  = "World";

say "Concatenation: " . ($first . ", " . $last . "!");
say "Repetition:    " . ($first x 3);
say "Length:        " . length($first);

say "\n=== NUMERIC COMPARISON ===";

my ($x, $y) = (10, 20);

say "$x == $y  => " . ($x == $y  ? "true" : "false");
say "$x != $y  => " . ($x != $y  ? "true" : "false");
say "$x <  $y  => " . ($x < $y   ? "true" : "false");
say "$x >  $y  => " . ($x > $y   ? "true" : "false");
say "$x <= $y  => " . ($x <= $y  ? "true" : "false");
say "$x >= $y  => " . ($x >= $y  ? "true" : "false");
say "$x <=> $y => " . ($x <=> $y);    # -1 (less than)

say "\n=== STRING COMPARISON ===";

my ($s1, $s2) = ("apple", "banana");

say "'$s1' eq '$s2' => " . ($s1 eq $s2 ? "true" : "false");
say "'$s1' ne '$s2' => " . ($s1 ne $s2 ? "true" : "false");
say "'$s1' lt '$s2' => " . ($s1 lt $s2 ? "true" : "false");
say "'$s1' gt '$s2' => " . ($s1 gt $s2 ? "true" : "false");
say "'$s1' cmp '$s2' => " . ($s1 cmp $s2);    # -1

say "\n=== LOGICAL OPERATORS ===";

my $age = 25;
my $has_license = 1;

say "Can drive (&&): " . (($age >= 16 && $has_license) ? "yes" : "no");
say "Is teen or senior (||): " . (($age < 20 || $age > 65) ? "yes" : "no");
say "Not a minor (!): " . (!($age < 18) ? "true" : "false");

# Short-circuit evaluation
my $default = undef || "fallback";
say "Default value: $default";

# Defined-or operator (//)
my $value = undef;
my $safe = $value // "default";
say "Defined-or: $safe";

say "\n=== TERNARY OPERATOR ===";

my $score = 75;
my $grade = ($score >= 90) ? "A" :
            ($score >= 80) ? "B" :
            ($score >= 70) ? "C" :
            ($score >= 60) ? "D" : "F";
say "Score $score => Grade $grade";

say "\n=== RANGE OPERATOR ===";

my @range = (1..5);
say "Range 1..5: @range";

my @letters = ('a'..'f');
say "Range a..f: @letters";
