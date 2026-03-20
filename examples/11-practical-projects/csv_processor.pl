#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use File::Temp qw(tempfile);

# ============================================================
# Practical Project: CSV Data Processor
# ============================================================
# Reads CSV data, performs filtering/sorting/aggregation,
# and generates formatted reports.
# ============================================================

my $csv_data = <<'CSV';
Name,Department,Title,Salary,YearsExp,City
Alice Johnson,Engineering,Senior Developer,120000,8,New York
Bob Smith,Marketing,Marketing Manager,85000,5,Chicago
Carol Williams,Engineering,Staff Engineer,145000,12,San Francisco
Dave Brown,Sales,Sales Representative,65000,3,Chicago
Eve Davis,Engineering,Junior Developer,75000,1,New York
Frank Miller,Marketing,Content Writer,62000,2,Los Angeles
Grace Wilson,Sales,Sales Manager,95000,7,Chicago
Hank Moore,Engineering,DevOps Engineer,110000,6,San Francisco
Ivy Taylor,HR,HR Specialist,72000,4,New York
Jack Anderson,Sales,Sales Representative,68000,3,Los Angeles
Kate Thomas,Engineering,QA Engineer,90000,5,San Francisco
Leo Jackson,Marketing,SEO Analyst,70000,3,Chicago
CSV

my ($tmpfh, $tmpfile) = tempfile(SUFFIX => '.csv', UNLINK => 1);
print $tmpfh $csv_data;
close($tmpfh);

sub read_csv {
    my ($filename) = @_;
    open(my $fh, '<', $filename) or die "Cannot open '$filename': $!\n";

    my $header_line = <$fh>;
    chomp $header_line;
    my @headers = split /,/, $header_line;

    my @records;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @fields = split /,/, $line;
        my %record;
        @record{@headers} = @fields;
        push @records, \%record;
    }
    close($fh);
    return (\@headers, \@records);
}

my ($headers, $records) = read_csv($tmpfile);

say "=" x 70;
say "               CSV DATA PROCESSOR";
say "=" x 70;

say "\n--- ALL RECORDS ---";
print_table($headers, $records);

say "\n--- FILTER: ENGINEERING DEPARTMENT ---";
my @engineering = grep { $_->{Department} eq "Engineering" } @$records;
print_table($headers, \@engineering);

say "\n--- SORT: BY SALARY (DESCENDING) ---";
my @by_salary = sort { $b->{Salary} <=> $a->{Salary} } @$records;
print_table($headers, \@by_salary);

say "\n--- FILTER: SALARY > \$80,000 AND EXPERIENCE >= 5 YEARS ---";
my @senior_well_paid = grep {
    $_->{Salary} > 80000 && $_->{YearsExp} >= 5
} @$records;
print_table($headers, \@senior_well_paid);

say "\n--- DEPARTMENT SUMMARY ---";
my %dept_stats;
for my $rec (@$records) {
    my $dept = $rec->{Department};
    $dept_stats{$dept}{count}++;
    $dept_stats{$dept}{total_salary} += $rec->{Salary};
    $dept_stats{$dept}{total_exp}    += $rec->{YearsExp};
    push @{$dept_stats{$dept}{salaries}}, $rec->{Salary};
}

printf "%-15s %6s %12s %12s %12s %8s\n",
    "Department", "Count", "Avg Salary", "Min Salary", "Max Salary", "Avg Exp";
say "-" x 70;
for my $dept (sort keys %dept_stats) {
    my $stats = $dept_stats{$dept};
    my @sorted_sal = sort { $a <=> $b } @{$stats->{salaries}};
    printf "%-15s %6d %12s %12s %12s %8.1f\n",
        $dept,
        $stats->{count},
        format_money($stats->{total_salary} / $stats->{count}),
        format_money($sorted_sal[0]),
        format_money($sorted_sal[-1]),
        $stats->{total_exp} / $stats->{count};
}

say "\n--- CITY DISTRIBUTION ---";
my %city_count;
$city_count{$_->{City}}++ for @$records;

for my $city (sort { $city_count{$b} <=> $city_count{$a} } keys %city_count) {
    my $bar = "█" x ($city_count{$city} * 3);
    printf "  %-15s %2d %s\n", $city, $city_count{$city}, $bar;
}

say "\n--- SALARY PERCENTILES ---";
my @all_salaries = sort { $a <=> $b } map { $_->{Salary} } @$records;
my $n = scalar @all_salaries;

printf "  Minimum:     %s\n", format_money($all_salaries[0]);
printf "  25th %%ile:   %s\n", format_money(percentile(\@all_salaries, 25));
printf "  Median:      %s\n", format_money(percentile(\@all_salaries, 50));
printf "  75th %%ile:   %s\n", format_money(percentile(\@all_salaries, 75));
printf "  Maximum:     %s\n", format_money($all_salaries[-1]);
printf "  Total:       %s\n", format_money(sum(@all_salaries));

say "\n--- EXPERIENCE VS SALARY CORRELATION ---";
my @exp   = map { $_->{YearsExp} } @$records;
my @sal   = map { $_->{Salary} }   @$records;
my $corr  = correlation(\@exp, \@sal);
printf "  Pearson correlation (exp vs salary): %.4f\n", $corr;
say "  Interpretation: " . interpret_correlation($corr);

say "\n" . "=" x 70;
say "Processing complete. $n records analyzed.";
say "=" x 70;

# --- Helper subroutines ---

sub print_table {
    my ($headers, $data) = @_;
    my @cols = @$headers;
    my %widths;
    for my $col (@cols) {
        $widths{$col} = length($col);
        for my $rec (@$data) {
            my $len = length($rec->{$col} // "");
            $widths{$col} = $len if $len > $widths{$col};
        }
        $widths{$col} = 18 if $widths{$col} > 18;
    }

    my $fmt = join(" | ", map { "%-$widths{$_}s" } @cols) . "\n";
    printf $fmt, @cols;
    say "-" x (sum(values %widths) + (scalar @cols - 1) * 3);
    for my $rec (@$data) {
        printf $fmt, map { substr($rec->{$_} // "", 0, 18) } @cols;
    }
    say "(" . scalar(@$data) . " rows)";
}

sub format_money {
    my ($amount) = @_;
    return sprintf("\$%s", commify(int($amount)));
}

sub commify {
    my $num = reverse int($_[0]);
    $num =~ s/(\d{3})(?=\d)/$1,/g;
    return scalar reverse $num;
}

sub sum {
    my $total = 0;
    $total += ($_ // 0) for @_;
    return $total;
}

sub percentile {
    my ($sorted_data, $p) = @_;
    my $index = ($p / 100) * (scalar @$sorted_data - 1);
    my $lower = int($index);
    my $frac  = $index - $lower;
    if ($lower + 1 < scalar @$sorted_data) {
        return $sorted_data->[$lower] + $frac * ($sorted_data->[$lower + 1] - $sorted_data->[$lower]);
    }
    return $sorted_data->[$lower];
}

sub correlation {
    my ($x, $y) = @_;
    my $n = scalar @$x;
    return 0 if $n < 2;

    my ($sum_x, $sum_y, $sum_xy, $sum_x2, $sum_y2) = (0, 0, 0, 0, 0);
    for my $i (0 .. $n - 1) {
        $sum_x  += $x->[$i];
        $sum_y  += $y->[$i];
        $sum_xy += $x->[$i] * $y->[$i];
        $sum_x2 += $x->[$i] ** 2;
        $sum_y2 += $y->[$i] ** 2;
    }

    my $numerator   = $n * $sum_xy - $sum_x * $sum_y;
    my $denominator = sqrt(($n * $sum_x2 - $sum_x**2) * ($n * $sum_y2 - $sum_y**2));
    return 0 if $denominator == 0;
    return $numerator / $denominator;
}

sub interpret_correlation {
    my ($r) = @_;
    my $abs_r = abs($r);
    my $dir = $r >= 0 ? "positive" : "negative";
    if    ($abs_r >= 0.9) { return "Very strong $dir correlation" }
    elsif ($abs_r >= 0.7) { return "Strong $dir correlation" }
    elsif ($abs_r >= 0.5) { return "Moderate $dir correlation" }
    elsif ($abs_r >= 0.3) { return "Weak $dir correlation" }
    else                  { return "Very weak or no correlation" }
}
