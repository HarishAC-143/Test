#!/usr/bin/perl
# 06_file_handling.pl — Reading, writing, and processing files
use strict;
use warnings;
use feature 'say';
use File::Temp qw(tempdir);
use File::Spec;
use Cwd qw(getcwd);

say "=" x 50;
say "  Perl File Handling Demo";
say "=" x 50;

my $tmpdir = tempdir(CLEANUP => 1);
say "Working in temp directory: $tmpdir";

# --- Writing a File ---
say "\n--- Writing Files ---";

my $sample_file = File::Spec->catfile($tmpdir, "sample.txt");

open(my $wfh, '>', $sample_file)
    or die "Cannot open $sample_file for writing: $!\n";

my @lines = (
    "Line 1: The quick brown fox jumps over the lazy dog.",
    "Line 2: Perl is a powerful text-processing language.",
    "Line 3: Regular expressions are Perl's superpower.",
    "Line 4: CPAN has over 200,000 modules.",
    "Line 5: Larry Wall created Perl in 1987.",
    "Line 6: There is more than one way to do it.",
    "Line 7: Use strict and warnings for safer code.",
    "Line 8: Perl 5 is stable, mature, and widely used.",
    "Line 9: Error handling is essential in production code.",
    "Line 10: Always close filehandles when done.",
);

for my $line (@lines) {
    print $wfh "$line\n";
}
close($wfh);
say "Wrote " . scalar(@lines) . " lines to sample.txt";

# --- Reading Line by Line ---
say "\n--- Reading Line by Line ---";

open(my $rfh, '<', $sample_file)
    or die "Cannot open $sample_file for reading: $!\n";

my $line_num = 0;
while (my $line = <$rfh>) {
    chomp $line;
    $line_num++;
    printf "%3d | %s\n", $line_num, $line;
}
close($rfh);

# --- Slurp Entire File ---
say "\n--- Slurp Entire File ---";

open(my $sfh, '<', $sample_file) or die "Cannot open: $!\n";
my $content = do { local $/; <$sfh> };
close($sfh);

my $char_count = length($content);
my $word_count = scalar(split /\s+/, $content);
my $file_lines = scalar(split /\n/, $content);
say "Characters: $char_count";
say "Words:      $word_count";
say "Lines:      $file_lines";

# --- Appending to a File ---
say "\n--- Appending ---";

my $log_file = File::Spec->catfile($tmpdir, "app.log");

for my $i (1..5) {
    open(my $afh, '>>', $log_file) or die "Cannot open log: $!\n";
    my $timestamp = localtime();
    print $afh "[$timestamp] Event #$i occurred\n";
    close($afh);
}
say "Appended 5 log entries";

open(my $lfh, '<', $log_file) or die "Cannot open: $!\n";
while (<$lfh>) {
    print "  $_";
}
close($lfh);

# --- File Tests ---
say "\n--- File Tests ---";

printf "%-20s %s\n", "Exists (-e):",     -e $sample_file ? "yes" : "no";
printf "%-20s %s\n", "Is file (-f):",     -f $sample_file ? "yes" : "no";
printf "%-20s %s\n", "Is dir (-d):",      -d $tmpdir      ? "yes" : "no";
printf "%-20s %s\n", "Readable (-r):",    -r $sample_file ? "yes" : "no";
printf "%-20s %s\n", "Writable (-w):",    -w $sample_file ? "yes" : "no";
printf "%-20s %s bytes\n", "Size (-s):",  -s $sample_file;
printf "%-20s %s\n", "Is text (-T):",     -T $sample_file ? "yes" : "no";

# --- Processing: Filter Lines ---
say "\n--- Filter Lines Containing 'Perl' ---";

open(my $ffh, '<', $sample_file) or die "Cannot open: $!\n";
while (my $line = <$ffh>) {
    chomp $line;
    if ($line =~ /Perl/i) {
        say "  MATCH: $line";
    }
}
close($ffh);

# --- Processing: Transform and Write ---
say "\n--- Transform: Uppercase Copy ---";

my $upper_file = File::Spec->catfile($tmpdir, "upper.txt");

open(my $in,  '<', $sample_file) or die "Cannot open input: $!\n";
open(my $out, '>', $upper_file)  or die "Cannot open output: $!\n";

while (my $line = <$in>) {
    print $out uc($line);
}

close($in);
close($out);

open(my $ufh, '<', $upper_file) or die "Cannot open: $!\n";
while (my $line = <$ufh>) {
    chomp $line;
    say "  $line" if $. <= 3;
}
say "  ..." if -s $upper_file;
close($ufh);

# --- CSV-like File Processing ---
say "\n--- CSV Processing ---";

my $csv_file = File::Spec->catfile($tmpdir, "data.csv");

open(my $csv_w, '>', $csv_file) or die "Cannot open: $!\n";
print $csv_w "Name,Age,City,Score\n";
print $csv_w "Alice,30,New York,92\n";
print $csv_w "Bob,25,London,85\n";
print $csv_w "Carol,35,Tokyo,97\n";
print $csv_w "Dave,28,Paris,78\n";
close($csv_w);

open(my $csv_r, '<', $csv_file) or die "Cannot open: $!\n";
my $header = <$csv_r>;
chomp $header;
my @columns = split /,/, $header;

printf "  %-10s %-5s %-12s %-6s\n", @columns;
printf "  %s\n", "-" x 37;

while (my $row = <$csv_r>) {
    chomp $row;
    my @fields = split /,/, $row;
    printf "  %-10s %-5s %-12s %-6s\n", @fields;
}
close($csv_r);

# --- Directory Operations ---
say "\n--- Directory Listing ---";

my $cwd = getcwd();
opendir(my $dh, $tmpdir) or die "Cannot opendir: $!\n";
my @files = grep { $_ !~ /^\.\.?$/ } readdir($dh);
closedir($dh);

say "Files in temp dir:";
for my $f (sort @files) {
    my $path = File::Spec->catfile($tmpdir, $f);
    my $size = -s $path;
    printf "  %-20s %6d bytes\n", $f, $size;
}

say "\nDone!";
