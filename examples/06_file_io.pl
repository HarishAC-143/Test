#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use File::Temp qw(tempdir);
use File::Spec;

# --- File Reading, Writing, and Directory Operations ---

my $tmpdir = tempdir(CLEANUP => 1);
say "Working in temporary directory: $tmpdir";

say "\n=== WRITING TO A FILE ===";

my $outfile = File::Spec->catfile($tmpdir, "sample.txt");
open(my $wfh, '>', $outfile) or die "Cannot write to $outfile: $!";
print $wfh "Line 1: Hello, Perl!\n";
print $wfh "Line 2: File I/O is straightforward.\n";
print $wfh "Line 3: This is the third line.\n";
print $wfh "Line 4: Perl makes text processing easy.\n";
print $wfh "Line 5: End of sample file.\n";
close($wfh);
say "Wrote 5 lines to $outfile";

say "\n=== READING LINE BY LINE ===";

open(my $rfh, '<', $outfile) or die "Cannot read $outfile: $!";
my $line_num = 0;
while (my $line = <$rfh>) {
    chomp $line;
    $line_num++;
    say "  [$line_num] $line";
}
close($rfh);

say "\n=== SLURP ENTIRE FILE ===";

open(my $sfh, '<', $outfile) or die "Cannot read $outfile: $!";
my $content = do { local $/; <$sfh> };
close($sfh);
say "File length: " . length($content) . " characters";

say "\n=== READ INTO ARRAY ===";

open(my $afh, '<', $outfile) or die "Cannot read $outfile: $!";
my @lines = <$afh>;
close($afh);
chomp @lines;
say "Number of lines: " . scalar @lines;
say "Last line: $lines[-1]";

say "\n=== APPENDING TO A FILE ===";

open(my $app, '>>', $outfile) or die "Cannot append to $outfile: $!";
print $app "Line 6: This was appended.\n";
close($app);

open($rfh, '<', $outfile) or die "Cannot read $outfile: $!";
my $total_lines = 0;
$total_lines++ while <$rfh>;
close($rfh);
say "Total lines after append: $total_lines";

say "\n=== FILE TESTS ===";

say "  Exists?   " . (-e $outfile ? "Yes" : "No");
say "  Is file?  " . (-f $outfile ? "Yes" : "No");
say "  Is dir?   " . (-d $outfile ? "Yes" : "No");
say "  Readable? " . (-r $outfile ? "Yes" : "No");
say "  Writable? " . (-w $outfile ? "Yes" : "No");
say "  Size:     " . (-s $outfile) . " bytes";

say "\n=== WRITING A CSV FILE ===";

my $csvfile = File::Spec->catfile($tmpdir, "data.csv");
open(my $csv, '>', $csvfile) or die "Cannot write $csvfile: $!";
print $csv "Name,Age,City\n";
print $csv "Alice,30,New York\n";
print $csv "Bob,25,London\n";
print $csv "Carol,28,Tokyo\n";
close($csv);

say "CSV file written. Contents:";
open(my $csvr, '<', $csvfile) or die "Cannot read $csvfile: $!";
while (<$csvr>) {
    chomp;
    say "  $_";
}
close($csvr);

say "\n=== DIRECTORY OPERATIONS ===";

my $subdir = File::Spec->catdir($tmpdir, "subdir");
mkdir $subdir or die "Cannot mkdir $subdir: $!";
say "Created directory: $subdir";

for my $i (1..3) {
    my $f = File::Spec->catfile($subdir, "file_$i.txt");
    open(my $fh, '>', $f) or die "Cannot create $f: $!";
    print $fh "Content of file $i\n";
    close($fh);
}

opendir(my $dh, $subdir) or die "Cannot opendir $subdir: $!";
my @files = grep { !/^\./ } readdir($dh);
closedir($dh);
say "Files in subdir: " . join(", ", sort @files);

say "\n=== GLOB PATTERN MATCHING ===";

my @txt_files = glob(File::Spec->catfile($subdir, "*.txt"));
say "TXT files found via glob: " . scalar(@txt_files);
for my $f (@txt_files) {
    say "  $f";
}

say "\nDone! (Temporary files will be cleaned up automatically)";
