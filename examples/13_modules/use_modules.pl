#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use File::Basename;

# Add the directory containing our modules to @INC
use lib dirname(__FILE__);

use MathHelper qw(factorial fibonacci is_prime gcd lcm);
use StringHelper qw(trim title_case truncate_str is_palindrome word_count);

say "=== MATH HELPER MODULE ===";

say "\nFactorials:";
for my $n (1..8) {
    printf "  %d! = %d\n", $n, factorial($n);
}

say "\nFibonacci sequence (first 10):";
my @fib = fibonacci(9);
say "  " . join(", ", @fib);

say "\nPrime numbers up to 50:";
my @primes = grep { is_prime($_) } 2..50;
say "  @primes";

say "\nGCD and LCM:";
printf "  GCD(48, 18) = %d\n", gcd(48, 18);
printf "  LCM(12, 8)  = %d\n", lcm(12, 8);

say "\n=== STRING HELPER MODULE ===";

say "\nTrim:";
say "  '" . trim("   hello world   ") . "'";

say "\nTitle case:";
say "  " . title_case("the quick brown fox");
say "  " . title_case("PERL PROGRAMMING TUTORIAL");

say "\nTruncate:";
say "  " . truncate_str("This is a very long string that should be truncated", 30);
say "  " . truncate_str("Short", 30);

say "\nPalindrome check:";
my @test_words = ("racecar", "hello", "A man a plan a canal Panama", "level");
for my $word (@test_words) {
    printf "  %-40s %s\n", "'$word'",
           is_palindrome($word) ? "palindrome" : "not a palindrome";
}

say "\nWord count:";
say "  'Hello World' => " . word_count("Hello World");
say "  'The quick brown fox' => " . word_count("The quick brown fox");

say "\n=== BUILT-IN MODULES ===";

use List::Util qw(sum min max reduce any all);
use POSIX qw(ceil floor);
use Scalar::Util qw(looks_like_number);

my @nums = (3, 1, 4, 1, 5, 9, 2, 6);
say "\nList::Util with (@nums):";
say "  sum:  " . sum(@nums);
say "  min:  " . min(@nums);
say "  max:  " . max(@nums);

say "\nPOSIX:";
say "  ceil(4.2):  " . ceil(4.2);
say "  floor(4.8): " . floor(4.8);

say "\nScalar::Util:";
my @mixed = ("42", "hello", "3.14", "0x1F", "");
for my $val (@mixed) {
    printf "  %-10s => %s\n", "'$val'",
           looks_like_number($val) ? "is a number" : "not a number";
}
