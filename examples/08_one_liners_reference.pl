#!/usr/bin/perl
# Reference script that demonstrates what Perl one-liners can do.
# This script simulates common one-liner operations in a longer format.
# For actual one-liners, see the command examples in the comments.

use strict;
use warnings;
use File::Temp qw(tempfile);

# --- Create sample data for demonstration ---

my $sample_text = <<'TEXT';
The quick brown fox jumps over the lazy dog.
Pack my box with five dozen liquor jugs.
How vexingly quick daft zebras jump.
The five boxing wizards jump quickly.
Sphinx of black quartz, judge my vow.
The quick brown fox jumps over the lazy dog.
Pack my box with five dozen liquor jugs.
Jackdaws love my big sphinx of quartz.
TEXT

my ($tmpfh, $tmpfile) = tempfile(SUFFIX => ".txt", UNLINK => 1);
print $tmpfh $sample_text;
close $tmpfh;

print "=== ONE-LINER EQUIVALENTS ===\n";
print "(See comments for actual command-line versions)\n\n";

# --- 1. Print lines matching a pattern ---
# perl -ne 'print if /quick/' file.txt
print "1. Lines containing 'quick':\n";
open(my $fh, "<", $tmpfile) or die $!;
while (<$fh>) { print "   $_" if /quick/ }
close $fh;

# --- 2. Count matching lines ---
# perl -ne '$c++ if /quick/; END{print "$c\n"}' file.txt
print "\n2. Count of lines containing 'quick': ";
my $count = 0;
open($fh, "<", $tmpfile) or die $!;
while (<$fh>) { $count++ if /quick/ }
close $fh;
print "$count\n";

# --- 3. Remove duplicate lines (preserving order) ---
# perl -ne 'print unless $seen{$_}++' file.txt
print "\n3. Unique lines:\n";
my %seen;
open($fh, "<", $tmpfile) or die $!;
while (<$fh>) { print "   $_" unless $seen{$_}++ }
close $fh;

# --- 4. Add line numbers ---
# perl -pe '$_ = sprintf "%4d: %s", $., $_' file.txt
print "\n4. Numbered lines:\n";
open($fh, "<", $tmpfile) or die $!;
while (<$fh>) { printf "   %2d: %s", $., $_ }
close $fh;

# --- 5. Word frequency ---
# perl -lane '$f{lc$_}++ for @F; END{printf "%-15s %d\n",$_,$f{$_} for sort{$f{$b}<=>$f{$a}} keys %f}' file.txt
print "\n5. Word frequency (top 10):\n";
my %freq;
open($fh, "<", $tmpfile) or die $!;
while (<$fh>) {
    for my $word (split /\s+/) {
        $word =~ s/[^a-zA-Z]//g;
        $freq{lc $word}++ if $word;
    }
}
close $fh;
my @top = (sort { $freq{$b} <=> $freq{$a} } keys %freq)[0..9];
printf "   %-12s %d\n", $_, $freq{$_} for @top;

# --- 6. Reverse each line ---
# perl -lpe '$_ = reverse' file.txt
print "\n6. Reversed lines (first 3):\n";
open($fh, "<", $tmpfile) or die $!;
my $n = 0;
while (<$fh>) {
    chomp;
    print "   ", scalar reverse($_), "\n";
    last if ++$n >= 3;
}
close $fh;

# --- 7. Extract words of specific length ---
# perl -lane 'print for grep {length==5} @F' file.txt
print "\n7. Five-letter words:\n   ";
my %five;
open($fh, "<", $tmpfile) or die $!;
while (<$fh>) {
    for my $w (split /\s+/) {
        $w =~ s/[^a-zA-Z]//g;
        $five{lc $w}++ if length($w) == 5;
    }
}
close $fh;
print join(", ", sort keys %five), "\n";

# --- 8. Generate random password ---
# perl -e 'print map { ("a".."z","A".."Z",0..9)[rand 62] } 1..16; print "\n"'
print "\n8. Random passwords:\n";
my @chars = ('a'..'z', 'A'..'Z', 0..9);
for my $i (1..3) {
    my $pw = join '', map { $chars[rand @chars] } 1..20;
    print "   $pw\n";
}

print "\n=== ACTUAL ONE-LINER COMMANDS ===\n";
print <<'COMMANDS';

# Search (like grep):
  perl -ne 'print if /pattern/' file.txt

# Search and replace in-place:
  perl -pi -e 's/old/new/g' file.txt

# Sum numbers:
  seq 1 100 | perl -lne '$s+=$_; END{print $s}'

# Unique lines:
  perl -ne 'print unless $seen{$_}++' file.txt

# Column extraction (like awk):
  perl -lane 'print $F[2]' file.txt

# CSV field extraction:
  perl -F, -lane 'print $F[1]' data.csv

# JSON pretty-print:
  echo '{"a":1}' | perl -MJSON::PP -0e 'print JSON::PP->new->pretty->encode(decode_json(<>))'

# Count lines per pattern:
  perl -ne '$h{/(\S+@\S+)/?$1:"other"}++; END{printf "%-30s %d\n",$_,$h{$_} for sort keys %h}' mail.log

COMMANDS
