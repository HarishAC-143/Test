#!/usr/bin/perl
#
# Word Frequency Counter — Reads text input, counts word occurrences,
# and displays frequency analysis with a histogram.
#
use strict;
use warnings;
use feature 'say';
use List::Util qw(sum max);

say "=== WORD FREQUENCY ANALYZER ===\n";

my $sample_text = <<'TEXT';
Perl is a high-level general-purpose interpreted dynamic programming language.
Perl was originally developed by Larry Wall in 1987 as a general-purpose
Unix scripting language to make report processing easier. Since then,
it has undergone many changes and revisions. Perl borrows features from
other programming languages including C, shell scripting, AWK, and sed.
The language provides powerful text processing facilities without the
arbitrary data-length limits of many contemporary Unix command-line tools.

Perl gained widespread popularity in the late 1990s as a CGI scripting language,
in part due to its powerful regular expression and string parsing abilities.
In addition to CGI, Perl is used for system administration, network programming,
finance, bioinformatics, and other applications. Perl is nicknamed
"the Swiss Army chainsaw of scripting languages" because of its flexibility
and power, and also its ugliness.

Perl is a programming language that is both practical and beautiful.
TEXT

my @words = ($sample_text =~ /\b([a-zA-Z]+(?:[-'][a-zA-Z]+)*)\b/g);

my %freq;
my %freq_lower;
$freq{$_}++ for @words;
$freq_lower{lc($_)}++ for @words;

my $total_words = scalar @words;
my $unique_words = scalar keys %freq_lower;

say "--- Text Statistics ---";
say "Total words:  $total_words";
say "Unique words: $unique_words";
printf "Lexical diversity: %.1f%%\n", ($unique_words / $total_words) * 100;

say "\n--- Top 20 Most Frequent Words ---";
my @sorted = sort { $freq_lower{$b} <=> $freq_lower{$a} || $a cmp $b }
             keys %freq_lower;

my $max_count = $freq_lower{$sorted[0]};

printf "%-4s %-20s %5s %6s  %s\n", "Rank", "Word", "Count", "Pct", "Histogram";
printf "%s\n", "-" x 65;

for my $i (0..19) {
    last if $i > $#sorted;
    my $word = $sorted[$i];
    my $count = $freq_lower{$word};
    my $pct = ($count / $total_words) * 100;
    my $bar_width = int(($count / $max_count) * 30);
    printf "%3d. %-20s %5d %5.1f%%  %s\n",
           $i + 1, $word, $count, $pct, "#" x $bar_width;
}

say "\n--- Word Length Distribution ---";
my %length_dist;
$length_dist{length(lc($_))}++ for @words;

my $max_len = max(keys %length_dist);
for my $len (sort { $a <=> $b } keys %length_dist) {
    my $count = $length_dist{$len};
    my $bar = "#" x int(($count / $total_words) * 100);
    printf "  %2d chars: %3d words %s\n", $len, $count, $bar;
}

say "\n--- Words Appearing Exactly Once (Hapax Legomena) ---";
my @hapax = sort grep { $freq_lower{$_} == 1 } keys %freq_lower;
my $hapax_count = scalar @hapax;
printf "Count: %d (%.1f%% of unique words)\n",
       $hapax_count, ($hapax_count / $unique_words) * 100;

my $per_line = 6;
for my $i (0..$#hapax) {
    printf "  %-18s", $hapax[$i];
    print "\n" if ($i + 1) % $per_line == 0;
}
say "" if @hapax % $per_line != 0;

say "\n--- Stop Words Filtered View ---";
my %stop_words = map { $_ => 1 } qw(
    the a an and or but in on at to for of is it its
    as by with from that this was were be been being
    has have had do does did not no nor are am was
    will would should could can may might shall
    he she they we you i my your his her their our
    also both due many other than then very
);

my %content_freq;
for my $word (@words) {
    my $lw = lc($word);
    $content_freq{$lw}++ unless $stop_words{$lw};
}

say "Top content words (stop words removed):";
my @content_sorted = sort { $content_freq{$b} <=> $content_freq{$a} }
                     keys %content_freq;
for my $i (0..14) {
    last if $i > $#content_sorted;
    my $w = $content_sorted[$i];
    printf "  %2d. %-20s %d\n", $i + 1, $w, $content_freq{$w};
}
