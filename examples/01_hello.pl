#!/usr/bin/perl
use strict;
use warnings;

# --- Hello World and Basic I/O ---

print "Hello, World!\n";

print "What is your name? ";
my $name = <STDIN>;
chomp $name;

print "Hello, $name! Welcome to Perl.\n";

# Printing with say (adds newline automatically)
use feature 'say';
say "This line uses 'say' — no \\n needed.";

# printf for formatted output
my $price = 49.995;
printf "Formatted price: \$%.2f\n", $price;

# Multiline output with heredoc
print <<END_MESSAGE;

==========================
  Perl Quick Facts
==========================
  Creator  : Larry Wall
  First    : 1987
  Latest   : Perl 5.x
  Motto    : TMTOWTDI
==========================

END_MESSAGE

# String interpolation vs. literal
my $count = 42;
print "Interpolated: I have $count items.\n";
print 'Literal: I have $count items.\n', "\n";

say "Done! Your first Perl script ran successfully.";
