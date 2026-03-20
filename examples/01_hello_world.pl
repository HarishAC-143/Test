#!/usr/bin/perl
# 01_hello_world.pl — Basic Perl program structure
use strict;
use warnings;
use feature 'say';

say "=" x 50;
say "  Perl Hello World & Program Structure";
say "=" x 50;

# Basic output
print "Hello, World!\n";
say "Hello with say (auto-newline)";

# Variable interpolation in double quotes
my $language = "Perl";
my $version  = $^V;
say "Welcome to $language version $version";

# Single quotes prevent interpolation
say 'This is literal: $language \n';

# Multiline with heredoc
my $banner = <<~BANNER;
    ╔══════════════════════════════════╗
    ║  Learning Perl Programming!      ║
    ║  Let's build something great.    ║
    ╚══════════════════════════════════╝
    BANNER

print $banner;

# Special variables
say "\nScript name: $0";
say "Process ID:  $$";
say "Perl path:   $^X";

say "\nDone! You've run your first Perl program.";
