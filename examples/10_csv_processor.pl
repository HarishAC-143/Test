#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use File::Temp qw(tempfile);
use List::Util qw(sum min max);

# --- Practical Project: CSV Data Processor ---
# Demonstrates reading, analyzing, filtering, sorting, and transforming CSV data.

my $csv_data = <<'END_CSV';
Name,Department,Salary,Years,City
Alice Johnson,Engineering,95000,8,San Francisco
Bob Smith,Marketing,72000,5,New York
Carol Williams,Engineering,88000,6,San Francisco
Dave Brown,Sales,68000,3,Chicago
Eve Davis,Engineering,105000,12,San Francisco
Frank Miller,Marketing,76000,7,New York
Grace Wilson,Sales,71000,4,Chicago
Henry Moore,Engineering,92000,9,Boston
Iris Taylor,Marketing,82000,8,New York
Jack Anderson,Sales,65000,2,Chicago
Kate Thomas,Engineering,98000,10,Boston
Leo Jackson,Marketing,70000,3,New York
Mia White,Sales,73000,5,Chicago
Noah Harris,Engineering,110000,15,San Francisco
Olivia Martin,Marketing,85000,9,New York
END_CSV

# --- Parse CSV ---
my @lines = split /\n/, $csv_data;
my $header = shift @lines;
my @columns = split /,/, $header;

my @records;
for my $line (@lines) {
    next unless $line =~ /\S/;
    my @fields = split /,/, $line;
    my %record;
    @record{@columns} = @fields;
    push @records, \%record;
}

say "=" x 65;
say "              CSV DATA PROCESSOR";
say "=" x 65;
say "\nLoaded " . scalar(@records) . " records with columns: " . join(", ", @columns);

# --- Display All Records ---
say "\n--- All Records ---";
printf "%-18s %-14s %8s %5s %-15s\n", @columns;
printf "%-18s %-14s %8s %5s %-15s\n", ("-" x 16), ("-" x 12), ("-" x 8), ("-" x 5), ("-" x 13);
for my $r (@records) {
    printf "%-18s %-14s %8s %5s %-15s\n",
        $r->{Name}, $r->{Department}, $r->{Salary}, $r->{Years}, $r->{City};
}

# --- Department Statistics ---
say "\n--- Department Statistics ---";
my %dept_data;
for my $r (@records) {
    my $dept = $r->{Department};
    push @{$dept_data{$dept}{salaries}}, $r->{Salary};
    push @{$dept_data{$dept}{years}}, $r->{Years};
}

printf "%-14s %6s %10s %10s %10s %8s\n",
    "Department", "Count", "Avg Salary", "Min Salary", "Max Salary", "Avg Yrs";
printf "%-14s %6s %10s %10s %10s %8s\n",
    ("-" x 12), ("-" x 5), ("-" x 10), ("-" x 10), ("-" x 10), ("-" x 7);

for my $dept (sort keys %dept_data) {
    my @sal = @{$dept_data{$dept}{salaries}};
    my @yrs = @{$dept_data{$dept}{years}};
    printf "%-14s %6d %10.0f %10d %10d %8.1f\n",
        $dept,
        scalar(@sal),
        sum(@sal) / scalar(@sal),
        min(@sal),
        max(@sal),
        sum(@yrs) / scalar(@yrs);
}

# --- City Statistics ---
say "\n--- City Statistics ---";
my %city_data;
for my $r (@records) {
    push @{$city_data{$r->{City}}}, $r->{Salary};
}

printf "%-15s %6s %10s\n", "City", "Count", "Avg Salary";
printf "%-15s %6s %10s\n", ("-" x 13), ("-" x 5), ("-" x 10);
for my $city (sort keys %city_data) {
    my @sal = @{$city_data{$city}};
    printf "%-15s %6d %10.0f\n", $city, scalar(@sal), sum(@sal) / scalar(@sal);
}

# --- Filtering ---
say "\n--- Engineers with Salary > 90000 ---";
my @high_eng = grep {
    $_->{Department} eq "Engineering" && $_->{Salary} > 90000
} @records;

for my $r (@high_eng) {
    printf "  %s — \$%s (%s years)\n", $r->{Name}, $r->{Salary}, $r->{Years};
}

# --- Sorting ---
say "\n--- Top 5 Earners ---";
my @top = (sort { $b->{Salary} <=> $a->{Salary} } @records)[0..4];
for my $i (0 .. $#top) {
    printf "  %d. %-18s \$%6d  (%s)\n",
        $i + 1, $top[$i]{Name}, $top[$i]{Salary}, $top[$i]{Department};
}

say "\n--- Most Experienced (10+ years) ---";
my @experienced = sort { $b->{Years} <=> $a->{Years} }
                  grep { $_->{Years} >= 10 } @records;
for my $r (@experienced) {
    printf "  %-18s %2d years  (%s)\n", $r->{Name}, $r->{Years}, $r->{Department};
}

# --- Data Transformation ---
say "\n--- Salary Bands ---";
my %bands = (
    "< 70K"     => sub { $_[0] < 70000 },
    "70K - 80K" => sub { $_[0] >= 70000 && $_[0] < 80000 },
    "80K - 90K" => sub { $_[0] >= 80000 && $_[0] < 90000 },
    "90K+"      => sub { $_[0] >= 90000 },
);

for my $band ("< 70K", "70K - 80K", "80K - 90K", "90K+") {
    my @in_band = grep { $bands{$band}->($_->{Salary}) } @records;
    my $bar = "#" x scalar(@in_band);
    printf "  %-12s [%2d] %s\n", $band, scalar(@in_band), $bar;
}

# --- Generate Summary Report ---
say "\n--- Summary Report ---";
my @all_salaries = map { $_->{Salary} } @records;
my @all_years    = map { $_->{Years} } @records;

printf "  Total employees      : %d\n", scalar @records;
printf "  Total payroll        : \$%s\n", commify(sum(@all_salaries));
printf "  Average salary       : \$%.0f\n", sum(@all_salaries) / scalar(@all_salaries);
printf "  Median salary        : \$%d\n", median(@all_salaries);
printf "  Salary range         : \$%d — \$%d\n", min(@all_salaries), max(@all_salaries);
printf "  Average tenure       : %.1f years\n", sum(@all_years) / scalar(@all_years);
printf "  Departments          : %d\n", scalar keys %dept_data;
printf "  Cities               : %d\n", scalar keys %city_data;

say "\n" . "=" x 65;
say "Processing complete!";

# --- Helper Functions ---

sub median {
    my @sorted = sort { $a <=> $b } @_;
    my $n = scalar @sorted;
    if ($n % 2 == 0) {
        return ($sorted[$n/2 - 1] + $sorted[$n/2]) / 2;
    }
    return $sorted[int($n/2)];
}

sub commify {
    my $num = reverse int($_[0]);
    $num =~ s/(\d{3})(?=\d)/$1,/g;
    return scalar reverse $num;
}
