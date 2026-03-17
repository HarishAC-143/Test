#!/usr/bin/perl
#
# Report Generator — Creates formatted text reports from structured data.
# Demonstrates string formatting, data aggregation, and report layout.
#
use strict;
use warnings;
use feature 'say';
use List::Util qw(sum min max);
use POSIX qw(strftime);

say generate_report();

sub generate_report {
    my @sales_data = (
        { month => "Jan", product => "Widget A", units => 150, price => 29.99, region => "North" },
        { month => "Jan", product => "Widget B", units => 200, price => 49.99, region => "South" },
        { month => "Jan", product => "Widget A", units => 120, price => 29.99, region => "South" },
        { month => "Feb", product => "Widget A", units => 180, price => 29.99, region => "North" },
        { month => "Feb", product => "Widget B", units => 160, price => 49.99, region => "North" },
        { month => "Feb", product => "Widget C", units => 90,  price => 99.99, region => "East" },
        { month => "Mar", product => "Widget A", units => 210, price => 29.99, region => "North" },
        { month => "Mar", product => "Widget B", units => 250, price => 49.99, region => "South" },
        { month => "Mar", product => "Widget C", units => 130, price => 99.99, region => "East" },
        { month => "Mar", product => "Widget A", units => 170, price => 29.99, region => "West" },
        { month => "Mar", product => "Widget B", units => 180, price => 49.99, region => "West" },
    );

    for my $row (@sales_data) {
        $row->{revenue} = $row->{units} * $row->{price};
    }

    my $report = "";
    my $width = 72;

    $report .= "=" x $width . "\n";
    $report .= center("QUARTERLY SALES REPORT", $width) . "\n";
    $report .= center("Q1 2026", $width) . "\n";
    $report .= center("Generated: " . strftime("%Y-%m-%d %H:%M", localtime), $width) . "\n";
    $report .= "=" x $width . "\n\n";

    # --- Overall Summary ---
    my $total_units   = sum(map { $_->{units} } @sales_data);
    my $total_revenue = sum(map { $_->{revenue} } @sales_data);
    my $avg_price     = $total_revenue / $total_units;

    $report .= section_header("EXECUTIVE SUMMARY", $width);
    $report .= sprintf "  Total Units Sold:    %s\n", commify($total_units);
    $report .= sprintf "  Total Revenue:       \$%s\n", commify(sprintf("%.2f", $total_revenue));
    $report .= sprintf "  Average Unit Price:  \$%.2f\n", $avg_price;
    $report .= sprintf "  Number of Records:   %d\n", scalar @sales_data;
    $report .= "\n";

    # --- Monthly Breakdown ---
    $report .= section_header("MONTHLY BREAKDOWN", $width);

    my %monthly;
    for my $row (@sales_data) {
        $monthly{$row->{month}}{units}   += $row->{units};
        $monthly{$row->{month}}{revenue} += $row->{revenue};
    }

    $report .= sprintf "  %-8s %10s %15s %10s\n", "Month", "Units", "Revenue", "Growth";
    $report .= "  " . "-" x 47 . "\n";

    my $prev_revenue = 0;
    for my $month (qw(Jan Feb Mar)) {
        my $units = $monthly{$month}{units};
        my $revenue = $monthly{$month}{revenue};
        my $growth = $prev_revenue > 0
            ? sprintf("%+.1f%%", (($revenue - $prev_revenue) / $prev_revenue) * 100)
            : "N/A";
        $report .= sprintf "  %-8s %10s %15s %10s\n",
                   $month, commify($units), "\$" . commify(sprintf("%.2f", $revenue)), $growth;
        $prev_revenue = $revenue;
    }
    $report .= "\n";

    # --- Product Performance ---
    $report .= section_header("PRODUCT PERFORMANCE", $width);

    my %product;
    for my $row (@sales_data) {
        $product{$row->{product}}{units}   += $row->{units};
        $product{$row->{product}}{revenue} += $row->{revenue};
        $product{$row->{product}}{price}    = $row->{price};
    }

    $report .= sprintf "  %-12s %8s %8s %13s %8s\n",
               "Product", "Price", "Units", "Revenue", "Share";
    $report .= "  " . "-" x 55 . "\n";

    for my $prod (sort { $product{$b}{revenue} <=> $product{$a}{revenue} } keys %product) {
        my $share = ($product{$prod}{revenue} / $total_revenue) * 100;
        $report .= sprintf "  %-12s \$%6.2f %8s %13s %7.1f%%\n",
                   $prod,
                   $product{$prod}{price},
                   commify($product{$prod}{units}),
                   "\$" . commify(sprintf("%.2f", $product{$prod}{revenue})),
                   $share;
    }
    $report .= "\n";

    # --- Regional Performance ---
    $report .= section_header("REGIONAL PERFORMANCE", $width);

    my %region;
    for my $row (@sales_data) {
        $region{$row->{region}}{units}   += $row->{units};
        $region{$row->{region}}{revenue} += $row->{revenue};
    }

    $report .= sprintf "  %-10s %8s %13s %8s  %s\n",
               "Region", "Units", "Revenue", "Share", "Bar";
    $report .= "  " . "-" x 60 . "\n";

    for my $reg (sort { $region{$b}{revenue} <=> $region{$a}{revenue} } keys %region) {
        my $share = ($region{$reg}{revenue} / $total_revenue) * 100;
        my $bar = "#" x int($share / 2);
        $report .= sprintf "  %-10s %8s %13s %7.1f%%  %s\n",
                   $reg,
                   commify($region{$reg}{units}),
                   "\$" . commify(sprintf("%.2f", $region{$reg}{revenue})),
                   $share,
                   $bar;
    }
    $report .= "\n";

    # --- Detailed Records ---
    $report .= section_header("DETAILED RECORDS", $width);

    $report .= sprintf "  %-5s %-12s %-8s %6s %8s %12s\n",
               "Month", "Product", "Region", "Units", "Price", "Revenue";
    $report .= "  " . "-" x 58 . "\n";

    for my $row (sort { $a->{month} cmp $b->{month}
                        || $a->{product} cmp $b->{product} } @sales_data) {
        $report .= sprintf "  %-5s %-12s %-8s %6d %8.2f %12s\n",
                   $row->{month}, $row->{product}, $row->{region},
                   $row->{units}, $row->{price},
                   "\$" . commify(sprintf("%.2f", $row->{revenue}));
    }
    $report .= "\n";

    # --- Footer ---
    $report .= "=" x $width . "\n";
    $report .= center("END OF REPORT", $width) . "\n";
    $report .= "=" x $width . "\n";

    return $report;
}

sub center {
    my ($text, $width) = @_;
    my $pad = int(($width - length($text)) / 2);
    return " " x $pad . $text;
}

sub section_header {
    my ($title, $width) = @_;
    my $result = "";
    $result .= "-" x $width . "\n";
    $result .= "  $title\n";
    $result .= "-" x $width . "\n";
    return $result;
}

sub commify {
    my ($n) = @_;
    my $text = reverse $n;
    $text =~ s/(\d{3})(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}
