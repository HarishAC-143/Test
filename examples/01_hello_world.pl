#!/usr/bin/perl
# Your first Perl program — demonstrating basic output and string operations.

use strict;
use warnings;

print "Hello, World!\n";

my $name = "Perl Developer";
my $year = 2026;

print "Welcome, $name!\n";
print "The year is $year.\n";
print "Perl is ", 2026 - 1987, " years old.\n";

my $multiline = <<END_TEXT;
This is a multi-line string.
It preserves formatting.
    Including indentation.
END_TEXT

print $multiline;

print "-" x 40, "\n";
print "String repetition: ", "abc" x 3, "\n";
print "Concatenation: ", "Hello" . ", " . "World!\n";
