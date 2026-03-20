#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

use FindBin qw($Bin);
use lib $Bin;
use MathUtils qw(factorial fibonacci is_prime gcd lcm combinations permutations);

# ============================================================
# Using Custom Modules — MathUtils Demo
# ============================================================

say "=== FACTORIALS ===";
for my $n (0..10) {
    printf "  %2d! = %d\n", $n, factorial($n);
}

say "\n=== FIBONACCI SEQUENCE ===";
my @fib = fibonacci(15);
say "First 16 Fibonacci numbers:";
say "  " . join(", ", @fib);

say "\n=== PRIME NUMBERS ===";
say "Primes up to 50:";
my @primes = grep { is_prime($_) } 2..50;
say "  @primes";
say "Count: " . scalar @primes;

say "\nPrime check:";
for my $n (1, 2, 17, 20, 97, 100) {
    printf "  %3d => %s\n", $n, is_prime($n) ? "PRIME" : "not prime";
}

say "\n=== GCD AND LCM ===";
my @pairs = ([12, 8], [100, 75], [17, 13], [48, 36]);
for my $pair (@pairs) {
    my ($a, $b) = @$pair;
    printf "  gcd(%3d, %3d) = %3d    lcm(%3d, %3d) = %d\n",
        $a, $b, gcd($a, $b), $a, $b, lcm($a, $b);
}

say "\n=== COMBINATIONS AND PERMUTATIONS ===";
printf "  C(10, 3) = %d  (ways to choose 3 from 10)\n", combinations(10, 3);
printf "  C(52, 5) = %d  (poker hands from a deck)\n", combinations(52, 5);
printf "  P(10, 3) = %d  (ordered arrangements of 3 from 10)\n", permutations(10, 3);
printf "  P(5, 5)  = %d  (arrangements of 5 items = 5!)\n", permutations(5, 5);

say "\n=== USING BUILT-IN MODULES ===";

use Data::Dumper;
say "--- Data::Dumper ---";
my $data = {
    primes => \@primes,
    fib    => [fibonacci(8)],
    facts  => { map { $_ => factorial($_) } 1..5 },
};
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
print Dumper($data);

use File::Basename;
say "--- File::Basename ---";
my $path = "/home/user/documents/report.pdf";
say "  Full path: $path";
say "  Basename:  " . basename($path);
say "  Directory: " . dirname($path);
say "  Suffix:    " . (fileparse($path, qr/\.[^.]*/))[2];

use Cwd;
say "\n--- Cwd ---";
say "  Current directory: " . getcwd();

use POSIX qw(strftime floor ceil);
say "\n--- POSIX ---";
say "  Date/Time: " . strftime("%Y-%m-%d %H:%M:%S", localtime);
say "  floor(3.7): " . floor(3.7);
say "  ceil(3.2):  " . ceil(3.2);

use Getopt::Long;
say "\n--- Getopt::Long (example setup) ---";
say "  Getopt::Long supports: --verbose, --output=FILE, --count=N";
say "  Usage: perl script.pl --verbose --output=out.txt --count=5";

say "\n--- Module demo complete ---";
