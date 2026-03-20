#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# File Reading Operations
# ============================================================

my $sample_file = "/tmp/perl_demo_sample.txt";

# First, create a sample file to work with
open(my $setup, '>', $sample_file) or die "Cannot create sample: $!\n";
print $setup <<'SAMPLE';
Alice,30,Engineering,95000
Bob,25,Marketing,72000
Charlie,35,Engineering,110000
Diana,28,Design,68000
Eve,32,Management,98000
Frank,29,Marketing,75000
Grace,40,Engineering,125000
SAMPLE
close($setup);

say "=== READ LINE BY LINE ===";

open(my $fh, '<', $sample_file) or die "Cannot open file: $!\n";

my $line_num = 0;
while (my $line = <$fh>) {
    chomp $line;
    $line_num++;
    say "  Line $line_num: $line";
}

close($fh);

say "\n=== READ ALL LINES INTO ARRAY ===";

open(my $fh2, '<', $sample_file) or die "Cannot open file: $!\n";
my @lines = <$fh2>;
chomp @lines;
close($fh2);

say "Total lines: " . scalar @lines;
say "First line:  $lines[0]";
say "Last line:   $lines[-1]";

say "\n=== SLURP (READ ENTIRE FILE) ===";

open(my $fh3, '<', $sample_file) or die "Cannot open file: $!\n";
my $content = do { local $/; <$fh3> };
close($fh3);

say "File length: " . length($content) . " characters";
say "Line count:  " . (() = $content =~ /\n/g);

say "\n=== PROCESS AS CSV DATA ===";

open(my $fh4, '<', $sample_file) or die "Cannot open file: $!\n";

my @employees;
while (my $line = <$fh4>) {
    chomp $line;
    my ($name, $age, $dept, $salary) = split /,/, $line;
    push @employees, {
        name   => $name,
        age    => $age,
        dept   => $dept,
        salary => $salary,
    };
}
close($fh4);

printf "\n%-12s %-4s %-15s %10s\n", "Name", "Age", "Department", "Salary";
say "-" x 45;
for my $emp (sort { $b->{salary} <=> $a->{salary} } @employees) {
    printf "%-12s %-4d %-15s \$%9s\n",
        $emp->{name}, $emp->{age}, $emp->{dept},
        commify($emp->{salary});
}

my $total_salary = 0;
$total_salary += $_->{salary} for @employees;
my $avg_salary = $total_salary / scalar @employees;
printf "\nAverage salary: \$%s\n", commify(int($avg_salary));

say "\n=== FILE TESTS ===";

say "File exists: "    . (-e $sample_file ? "yes" : "no");
say "Is regular file: " . (-f $sample_file ? "yes" : "no");
say "Is readable: "    . (-r $sample_file ? "yes" : "no");
say "File size: "      . (-s $sample_file) . " bytes";

unlink $sample_file;
say "\nCleaned up sample file.";

say "\n--- File reading demo complete ---";

sub commify {
    my $num = reverse $_[0];
    $num =~ s/(\d{3})(?=\d)/$1,/g;
    return scalar reverse $num;
}
