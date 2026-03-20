#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Scalar Variables ($) — Numbers, Strings, and Undefined
# ============================================================

say "=== NUMBERS ===";

my $integer    = 42;
my $negative   = -17;
my $float      = 3.14159;
my $scientific = 6.022e23;        # Avogadro's number
my $hex        = 0xFF;            # 255
my $octal      = 0777;            # 511
my $binary     = 0b11001010;      # 202

say "Integer:    $integer";
say "Negative:   $negative";
say "Float:      $float";
say "Scientific: $scientific";
say "Hex 0xFF:   $hex";
say "Octal 0777: $octal";
say "Binary:     $binary";

say "\n=== STRINGS ===";

my $single = 'Hello, World!';            # Single-quoted (literal)
my $double = "Hello, World!\n";          # Double-quoted (interpolation)
my $name   = "Alice";
my $greeting = "Hello, $name!";          # Variable interpolation
my $calc     = "2 + 2 = @{[2 + 2]}";    # Expression interpolation

say "Single: $single";
print "Double: $double";
say "Greeting: $greeting";
say "Calc: $calc";

say "\n=== ESCAPE SEQUENCES ===";

print "Tab:\tTabbed text\n";
print "Newline above ^\n";
print "Backslash: \\\n";
print "Double quote: \"\n";
print "Null character: \\0\n";
print "Unicode smiley: \x{263A}\n";

say "\n=== AUTOMATIC TYPE CONVERSION ===";

my $str_num = "42abc";
my $result  = $str_num + 8;
say "\"42abc\" + 8 = $result";  # 50 (Perl extracts leading number)

my $pure_str = "hello";
my $num_from_str = $pure_str + 0;
say "\"hello\" + 0 = $num_from_str";  # 0

my $number = 100;
my $as_string = "The value is $number";
say $as_string;

say "\n=== UNDEF ===";

my $undefined;
say "Defined? ", defined($undefined) ? "yes" : "no";

$undefined = "now defined";
say "Defined? ", defined($undefined) ? "yes" : "no";
say "Value: $undefined";

say "\n=== SPECIAL VARIABLES ===";

say "Process ID: $$";
say "Program name: $0";
say "Perl version: $]";

say "\n--- Scalars demo complete ---";
