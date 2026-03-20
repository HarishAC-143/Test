#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Basic Perl Script Structure
# ============================================================

# Simple output
print "Hello, World!\n";

# say adds a newline automatically
say "Hello from say!";

# String interpolation with double quotes
my $name = "Perl";
my $version = 5;
say "Welcome to $name $version!";

# Single quotes treat everything literally
say 'No interpolation: $name $version\n';

# Multiline output with heredoc
print <<END_MESSAGE;

==========================
  Welcome to Perl!
  Today's date: @{[scalar localtime]}
==========================

END_MESSAGE

# Formatted output with printf
printf("%-15s %5s %10s\n", "Language", "Year", "Creator");
printf("%-15s %5d %10s\n", "Perl",      1987, "Larry Wall");
printf("%-15s %5d %10s\n", "Python",    1991, "Guido van Rossum");
printf("%-15s %5d %10s\n", "Ruby",      1995, "Yukihiro Matsumoto");

# Multi-line strings with qq{}
my $paragraph = qq{
    Perl is a high-level, general-purpose, interpreted,
    dynamic programming language. It was originally developed
    by Larry Wall in 1987.
};
print $paragraph;

say "\n--- Program complete ---";
