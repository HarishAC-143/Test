#!/usr/bin/perl
# 10_csv_processor.pl — Practical example: CSV data processing and analysis
#
# Demonstrates: file I/O, data structures, sorting, aggregation, formatted reports
# This script generates sample sales data and performs various analyses.
use strict;
use warnings;
use feature 'say';
use File::Temp qw(tempfile);
use List::Util qw(sum min max);

say "=" x 60;
say "  Practical Example: CSV Data Processor";
say "=" x 60;

# --- Generate sample CSV data ---
my ($fh, $csvfile) = tempfile(SUFFIX => '.csv', UNLINK => 1);

my @header = qw(Date Region Product Quantity UnitPrice);
say $fh join(",", @header);

my @regions  = qw(North South East West Central);
my @products = ("Widget A", "Widget B", "Gadget X", "Gadget Y", "Tool Z");
my %base_prices = (
    "Widget A" => 29.99,
    "Widget B" => 49.99,
    "Gadget X" => 99.99,
    "Gadget Y" => 149.99,
    "Tool Z"   => 199.99,
);

srand(123);
for my $month (1..12) {
    for my $day_offset (0..9) {
        my $day = ($day_offset * 3) % 28 + 1;
        my $date = sprintf("2025-%02d-%02d", $month, $day);
        my $region  = $regions[int(rand(@regions))];
        my $product = $products[int(rand(@products))];
        my $qty     = int(rand(50)) + 1;
        my $price   = $base_prices{$product} * (0.9 + rand(0.2));

        printf $fh "%s,%s,%s,%d,%.2f\n", $date, $region, $product, $qty, $price;
    }
}
close($fh);

say "Generated sample CSV: $csvfile\n";

# --- Read and parse CSV ---
open(my $csv, '<', $csvfile) or die "Cannot open CSV: $!\n";

my $header_line = <$csv>;
chomp $header_line;
my @columns = split /,/, $header_line;

my @records;
while (my $line = <$csv>) {
    chomp $line;
    my @fields = split /,/, $line;
    my %record;
    @record{@columns} = @fields;
    $record{Revenue} = $record{Quantity} * $record{UnitPrice};
    ($record{Month}) = $record{Date} =~ /^\d{4}-(\d{2})/;
    push @records, \%record;
}
close($csv);

say "Loaded " . scalar(@records) . " records\n";

# --- Analysis 1: Summary Statistics ---
say "--- Overall Summary ---";

my @revenues = map { $_->{Revenue} } @records;
my @quantities = map { $_->{Quantity} } @records;

printf "  Total Revenue:     \$%12.2f\n", sum(@revenues);
printf "  Total Units Sold:  %14d\n", sum(@quantities);
printf "  Average Order:     \$%12.2f\n", sum(@revenues) / scalar(@revenues);
printf "  Min Order Value:   \$%12.2f\n", min(@revenues);
printf "  Max Order Value:   \$%12.2f\n", max(@revenues);
printf "  Number of Records: %14d\n", scalar(@records);

# --- Analysis 2: Revenue by Region ---
say "\n--- Revenue by Region ---";

my %region_stats;
for my $rec (@records) {
    my $region = $rec->{Region};
    $region_stats{$region}{revenue} += $rec->{Revenue};
    $region_stats{$region}{units}   += $rec->{Quantity};
    $region_stats{$region}{orders}++;
}

printf "  %-10s %12s %10s %8s %12s\n", "Region", "Revenue", "Units", "Orders", "Avg Order";
say "  " . "-" x 56;

for my $region (sort { $region_stats{$b}{revenue} <=> $region_stats{$a}{revenue} } keys %region_stats) {
    my $s = $region_stats{$region};
    printf "  %-10s \$%11.2f %10d %8d \$%11.2f\n",
        $region, $s->{revenue}, $s->{units}, $s->{orders}, $s->{revenue} / $s->{orders};
}

# --- Analysis 3: Revenue by Product ---
say "\n--- Revenue by Product ---";

my %product_stats;
for my $rec (@records) {
    my $product = $rec->{Product};
    $product_stats{$product}{revenue} += $rec->{Revenue};
    $product_stats{$product}{units}   += $rec->{Quantity};
    $product_stats{$product}{orders}++;
}

printf "  %-12s %12s %10s %8s\n", "Product", "Revenue", "Units", "Orders";
say "  " . "-" x 46;

for my $product (sort { $product_stats{$b}{revenue} <=> $product_stats{$a}{revenue} } keys %product_stats) {
    my $s = $product_stats{$product};
    printf "  %-12s \$%11.2f %10d %8d\n",
        $product, $s->{revenue}, $s->{units}, $s->{orders};
}

# --- Analysis 4: Monthly Trend ---
say "\n--- Monthly Revenue Trend ---";

my %monthly;
for my $rec (@records) {
    $monthly{$rec->{Month}} += $rec->{Revenue};
}

my @month_names = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my $max_rev = max(values %monthly);

for my $m (map { sprintf("%02d", $_) } 1..12) {
    my $rev = $monthly{$m} // 0;
    my $bar_len = int(($rev / ($max_rev || 1)) * 35);
    printf "  %s (%s) |%-35s| \$%.0f\n", $m, $month_names[$m - 1], "#" x $bar_len, $rev;
}

# --- Analysis 5: Top 10 Largest Orders ---
say "\n--- Top 10 Largest Orders ---";

my @sorted_by_revenue = sort { $b->{Revenue} <=> $a->{Revenue} } @records;

printf "  %-12s %-10s %-12s %6s %10s %12s\n",
    "Date", "Region", "Product", "Qty", "Price", "Revenue";
say "  " . "-" x 66;

for my $i (0..9) {
    my $rec = $sorted_by_revenue[$i];
    printf "  %-12s %-10s %-12s %6d \$%9.2f \$%11.2f\n",
        $rec->{Date}, $rec->{Region}, $rec->{Product},
        $rec->{Quantity}, $rec->{UnitPrice}, $rec->{Revenue};
}

# --- Analysis 6: Product-Region Cross-tabulation ---
say "\n--- Revenue by Product x Region ---";

my %cross_tab;
my %all_regions;
for my $rec (@records) {
    $cross_tab{$rec->{Product}}{$rec->{Region}} += $rec->{Revenue};
    $all_regions{$rec->{Region}} = 1;
}

my @regions_sorted = sort keys %all_regions;
printf "  %-12s", "Product";
printf " %10s", $_ for @regions_sorted;
say "";
say "  " . "-" x (12 + 10 * scalar(@regions_sorted));

for my $product (sort keys %cross_tab) {
    printf "  %-12s", $product;
    for my $region (@regions_sorted) {
        printf " \$%9.0f", $cross_tab{$product}{$region} // 0;
    }
    say "";
}

say "\nDone!";
