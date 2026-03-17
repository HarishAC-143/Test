#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use File::Basename;
use File::Spec;

my $test_dir = "/tmp/perl_file_examples";
mkdir $test_dir unless -d $test_dir;

say "=== WRITING TO A FILE ===";

my $output_file = File::Spec->catfile($test_dir, "output.txt");

open(my $fh_write, '>', $output_file)
    or die "Cannot open '$output_file' for writing: $!";

print $fh_write "Line 1: Hello, File!\n";
print $fh_write "Line 2: Perl file handling is easy.\n";
print $fh_write "Line 3: This is the third line.\n";
print $fh_write "Line 4: Almost done.\n";
print $fh_write "Line 5: The End.\n";

close($fh_write);
say "Wrote 5 lines to $output_file";

say "\n=== READING A FILE LINE BY LINE ===";

open(my $fh_read, '<', $output_file)
    or die "Cannot open '$output_file' for reading: $!";

my $line_num = 0;
while (my $line = <$fh_read>) {
    chomp $line;
    $line_num++;
    say "  $line_num: $line";
}
close($fh_read);

say "\n=== READING ALL LINES AT ONCE ===";

open(my $fh_all, '<', $output_file)
    or die "Cannot open: $!";
my @all_lines = <$fh_all>;
chomp @all_lines;
close($fh_all);

say "Read " . scalar @all_lines . " lines:";
say "  First: $all_lines[0]";
say "  Last:  $all_lines[-1]";

say "\n=== READING ENTIRE FILE AS STRING ===";

open(my $fh_slurp, '<', $output_file)
    or die "Cannot open: $!";
my $content = do { local $/; <$fh_slurp> };
close($fh_slurp);

say "File length: " . length($content) . " characters";

say "\n=== APPENDING TO A FILE ===";

open(my $fh_append, '>>', $output_file)
    or die "Cannot open for appending: $!";
print $fh_append "Line 6: This was appended.\n";
print $fh_append "Line 7: So was this.\n";
close($fh_append);

say "Appended 2 more lines.";

say "\n=== FILE TESTS ===";

my @test_paths = ($output_file, $test_dir, "/nonexistent/path");

for my $path (@test_paths) {
    say "\n  Path: $path";
    say "    Exists:    " . (-e $path ? "yes" : "no");
    say "    Is file:   " . (-f $path ? "yes" : "no") if -e $path;
    say "    Is dir:    " . (-d $path ? "yes" : "no") if -e $path;
    say "    Readable:  " . (-r $path ? "yes" : "no") if -e $path;
    say "    Writable:  " . (-w $path ? "yes" : "no") if -e $path;
    if (-f $path) {
        say "    Size:      " . (-s $path) . " bytes";
    }
}

say "\n=== WORKING WITH CSV-LIKE DATA ===";

my $csv_file = File::Spec->catfile($test_dir, "people.csv");

open(my $csv_write, '>', $csv_file)
    or die "Cannot open: $!";
print $csv_write "Name,Age,City\n";
print $csv_write "Alice,30,New York\n";
print $csv_write "Bob,25,London\n";
print $csv_write "Carol,35,Tokyo\n";
print $csv_write "Dave,28,Berlin\n";
close($csv_write);

open(my $csv_read, '<', $csv_file)
    or die "Cannot open: $!";

my $header = <$csv_read>;
chomp $header;
my @columns = split /,/, $header;

say "CSV Data (columns: " . join(", ", @columns) . "):";
while (my $line = <$csv_read>) {
    chomp $line;
    my @fields = split /,/, $line;
    printf "  %-10s Age: %2d  City: %s\n", @fields;
}
close($csv_read);

say "\n=== DIRECTORY OPERATIONS ===";

opendir(my $dh, $test_dir)
    or die "Cannot open directory: $!";
my @files = sort grep { -f File::Spec->catfile($test_dir, $_) } readdir($dh);
closedir($dh);

say "Files in $test_dir:";
for my $file (@files) {
    my $full = File::Spec->catfile($test_dir, $file);
    printf "  %-20s %5d bytes\n", $file, -s $full;
}

say "\n=== FILE::BASENAME ===";

my $path = "/home/user/documents/report.txt";
say "Path:      $path";
say "Basename:  " . basename($path);
say "Directory: " . dirname($path);

my ($name, $dir, $ext) = fileparse($path, qr/\.[^.]*/);
say "Name:      $name";
say "Dir:       $dir";
say "Extension: $ext";

say "\n=== CLEANUP ===";

unlink File::Spec->catfile($test_dir, $_) for @files;
rmdir $test_dir;
say "Cleaned up temporary files.";
