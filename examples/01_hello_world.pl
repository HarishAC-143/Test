#!/usr/bin/perl
use strict;
use warnings;

# --- Basic output ---
print "Hello, World!\n";

# --- Using say (adds newline automatically) ---
use feature 'say';
say "Hello again, World!";

# --- Printing multiple items ---
print "Perl", " is", " awesome!\n";

# --- Using printf for formatted output ---
my $language = "Perl";
my $version  = 5.38;
printf "Welcome to %s version %.2f\n", $language, $version;

# --- Multiline output with heredoc ---
print <<END_GREETING;

=============================
  Welcome to Perl Programming
  Let's start learning!
=============================

END_GREETING
