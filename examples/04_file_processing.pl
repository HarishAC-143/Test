#!/usr/bin/perl
# Demonstrates file I/O operations with practical examples.

use strict;
use warnings;
use File::Basename;
use File::Temp qw(tempfile tempdir);
use Cwd qw(abs_path);

my $tmpdir = tempdir(CLEANUP => 1);

print "=== WRITING FILES ===\n\n";

my $data_file = "$tmpdir/sample_data.txt";
open(my $fh, ">", $data_file) or die "Cannot open: $!\n";
print $fh "Name,Department,Salary\n";
print $fh "Alice,Engineering,95000\n";
print $fh "Bob,Marketing,72000\n";
print $fh "Carol,Engineering,88000\n";
print $fh "Dave,Sales,68000\n";
print $fh "Eve,Engineering,92000\n";
print $fh "Frank,Marketing,75000\n";
print $fh "Grace,Sales,71000\n";
print $fh "Hank,Engineering,97000\n";
close $fh;
print "Created sample data file: $data_file\n\n";

print "=== READING AND PROCESSING ===\n\n";

open($fh, "<", $data_file) or die "Cannot open: $!\n";

my $header = <$fh>;
chomp $header;
my @columns = split /,/, $header;

my @employees;
while (my $line = <$fh>) {
    chomp $line;
    my @fields = split /,/, $line;
    my %emp;
    @emp{@columns} = @fields;
    push @employees, \%emp;
}
close $fh;

printf "Loaded %d employees.\n\n", scalar @employees;

my %dept_stats;
for my $emp (@employees) {
    my $dept = $emp->{Department};
    $dept_stats{$dept}{count}++;
    $dept_stats{$dept}{total} += $emp->{Salary};
    push @{$dept_stats{$dept}{salaries}}, $emp->{Salary};
}

printf "%-15s %5s %10s %10s %10s\n", "Department", "Count", "Total", "Average", "Max";
print "-" x 55, "\n";

for my $dept (sort keys %dept_stats) {
    my $stats = $dept_stats{$dept};
    my $avg = $stats->{total} / $stats->{count};
    my $max = (sort { $b <=> $a } @{$stats->{salaries}})[0];

    printf "%-15s %5d %10d %10.0f %10d\n",
           $dept, $stats->{count}, $stats->{total}, $avg, $max;
}

print "\n=== WRITING REPORT ===\n\n";

my $report_file = "$tmpdir/report.txt";
open(my $out, ">", $report_file) or die "Cannot open: $!\n";

printf $out "Employee Report - Generated %s\n", scalar localtime;
print $out "=" x 50, "\n\n";

my @sorted = sort { $b->{Salary} <=> $a->{Salary} } @employees;
printf $out "%-12s %-15s %8s\n", "Name", "Department", "Salary";
print $out "-" x 38, "\n";

for my $emp (@sorted) {
    printf $out "%-12s %-15s \$%7d\n",
           $emp->{Name}, $emp->{Department}, $emp->{Salary};
}

my $total = 0;
$total += $_->{Salary} for @employees;
printf $out "\nTotal Payroll: \$%d\n", $total;
printf $out "Average Salary: \$%.0f\n", $total / scalar @employees;

close $out;

open(my $verify, "<", $report_file) or die "Cannot open: $!\n";
print while <$verify>;
close $verify;

print "\n=== FILE INFORMATION ===\n\n";

for my $file ($data_file, $report_file) {
    if (-e $file) {
        printf "File: %s\n", basename($file);
        printf "  Size: %d bytes\n", -s $file;
        printf "  Readable: %s\n", -r $file ? "yes" : "no";
        printf "  Writable: %s\n", -w $file ? "yes" : "no";
    }
}

print "\nTemporary files will be cleaned up automatically.\n";
