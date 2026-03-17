#!/usr/bin/perl
#
# CSV Processor — Demonstrates reading, filtering, sorting, and
# generating summary statistics from CSV data.
#
use strict;
use warnings;
use feature 'say';
use List::Util qw(sum min max);

say "=== CSV DATA PROCESSOR ===\n";

my @csv_data = split /\n/, <<'CSV';
Name,Department,Salary,Years,Rating
Alice Johnson,Engineering,95000,5,4.5
Bob Smith,Marketing,72000,3,3.8
Carol Williams,Engineering,105000,8,4.9
Dave Brown,Marketing,68000,2,3.5
Eve Davis,Engineering,88000,4,4.2
Frank Miller,Sales,78000,6,4.0
Grace Wilson,Sales,82000,7,4.3
Heidi Moore,Engineering,110000,10,4.8
Ivan Taylor,Marketing,75000,4,3.9
Judy Anderson,Sales,71000,3,3.7
CSV

my @headers;
my @records;

for my $i (0..$#csv_data) {
    my @fields = split /,/, $csv_data[$i];
    if ($i == 0) {
        @headers = @fields;
        next;
    }
    push @records, {
        name       => $fields[0],
        department => $fields[1],
        salary     => $fields[2],
        years      => $fields[3],
        rating     => $fields[4],
    };
}

say "--- All Employees ---";
printf "%-20s %-15s %10s %6s %6s\n", @headers;
printf "%-20s %-15s %10s %6s %6s\n", map { "-" x $_ } (20, 15, 10, 6, 6);
for my $r (@records) {
    printf "%-20s %-15s %10s %6s %6s\n",
           $r->{name}, $r->{department}, $r->{salary}, $r->{years}, $r->{rating};
}

say "\n--- Filter: Engineering Department ---";
my @engineers = grep { $_->{department} eq "Engineering" } @records;
for my $e (@engineers) {
    printf "  %-20s \$%s  Rating: %s\n", $e->{name}, commify($e->{salary}), $e->{rating};
}

say "\n--- Filter: Salary > \$80,000 ---";
my @high_earners = sort { $b->{salary} <=> $a->{salary} }
                   grep { $_->{salary} > 80000 } @records;
for my $e (@high_earners) {
    printf "  %-20s \$%s (%s)\n", $e->{name}, commify($e->{salary}), $e->{department};
}

say "\n--- Sort: By Rating (descending) ---";
my @by_rating = sort { $b->{rating} <=> $a->{rating} } @records;
for my $i (0..$#by_rating) {
    my $r = $by_rating[$i];
    printf "  %2d. %-20s %.1f\n", $i + 1, $r->{name}, $r->{rating};
}

say "\n--- Department Statistics ---";
my %dept_stats;
for my $r (@records) {
    my $d = $r->{department};
    push @{$dept_stats{$d}{salaries}}, $r->{salary};
    push @{$dept_stats{$d}{ratings}},  $r->{rating};
    push @{$dept_stats{$d}{years}},    $r->{years};
}

printf "%-15s %5s %12s %12s %12s %8s\n",
       "Department", "Count", "Avg Salary", "Min Salary", "Max Salary", "Avg Rating";
printf "%s\n", "-" x 70;

for my $dept (sort keys %dept_stats) {
    my @sal  = @{$dept_stats{$dept}{salaries}};
    my @rat  = @{$dept_stats{$dept}{ratings}};
    my $count = scalar @sal;
    printf "%-15s %5d %12s %12s %12s %8.1f\n",
           $dept,
           $count,
           "\$" . commify(int(sum(@sal) / $count)),
           "\$" . commify(min(@sal)),
           "\$" . commify(max(@sal)),
           sum(@rat) / $count;
}

say "\n--- Salary Distribution ---";
my @all_salaries = sort { $a <=> $b } map { $_->{salary} } @records;
my $total = sum(@all_salaries);
my $avg   = $total / scalar @all_salaries;
my $median = @all_salaries % 2
    ? $all_salaries[@all_salaries / 2]
    : ($all_salaries[@all_salaries / 2 - 1] + $all_salaries[@all_salaries / 2]) / 2;

printf "  Total payroll:  \$%s\n", commify($total);
printf "  Average salary: \$%s\n", commify(int($avg));
printf "  Median salary:  \$%s\n", commify($median);
printf "  Min salary:     \$%s\n", commify(min(@all_salaries));
printf "  Max salary:     \$%s\n", commify(max(@all_salaries));

say "\n--- Generate CSV Output ---";
say join(",", "Rank", "Name", "Department", "Salary", "Rating");
for my $i (0..$#by_rating) {
    my $r = $by_rating[$i];
    printf "%d,%s,%s,%d,%.1f\n", $i + 1, $r->{name}, $r->{department},
           $r->{salary}, $r->{rating};
}

sub commify {
    my ($n) = @_;
    my $text = reverse int($n);
    $text =~ s/(\d{3})(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}
