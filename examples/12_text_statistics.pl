#!/usr/bin/perl
# 12_text_statistics.pl — Practical example: Text analysis and statistics tool
#
# Demonstrates: string operations, regex, hashes, sorting, formatted output
# Analyzes a body of text for word frequency, sentence structure, readability, etc.
use strict;
use warnings;
use feature 'say';
use List::Util qw(sum max);

say "=" x 60;
say "  Practical Example: Text Statistics Analyzer";
say "=" x 60;

my $text = <<'TEXT';
Perl is a family of two high-level, general-purpose, interpreted, dynamic
programming languages. Perl 5 and Perl 6, which is now known as Raku.

Though Perl is not officially an acronym, there are various backronyms in use,
including "Practical Extraction and Reporting Language". Perl was developed by
Larry Wall in 1987 as a general-purpose Unix scripting language to make report
processing easier. Since then, it has undergone many changes and revisions.

Perl 5 gained widespread popularity in the late 1990s as a CGI scripting
language, in part due to its unsurpassed regular expression and string parsing
abilities. In addition to CGI, Perl 5 is used for system administration,
network programming, finance, bioinformatics, and other applications, such as
for GUIs. It has been nicknamed "the Swiss Army chainsaw of scripting languages"
because of its flexibility and power, and also its ugliness.

Perl is a highly expressive programming language: source code for a given
algorithm can be short and highly compressible compared to most other languages.
The language is intended to be practical rather than beautiful. Its key features
include support for multiple programming paradigms, including procedural,
object-oriented, and functional programming. Perl has a built-in regular
expression engine and a large collection of third-party modules available
through CPAN, the Comprehensive Perl Archive Network.
TEXT

say "\n--- Input Text (first 200 chars) ---";
say substr($text, 0, 200) . "...\n";

# --- Basic Counts ---
say "--- Basic Statistics ---";

my @characters = split //, $text;
my $char_count = length($text);
my $char_no_space = () = ($text =~ /\S/g);

my @words = ($text =~ /\b[a-zA-Z']+\b/g);
my $word_count = scalar @words;

my @sentences = split /[.!?]+/, $text;
@sentences = grep { /\S/ } @sentences;
my $sentence_count = scalar @sentences;

my @paragraphs = split /\n\n+/, $text;
@paragraphs = grep { /\S/ } @paragraphs;

my @lines = split /\n/, $text;
@lines = grep { /\S/ } @lines;

printf "  Characters (total):    %6d\n", $char_count;
printf "  Characters (no space): %6d\n", $char_no_space;
printf "  Words:                 %6d\n", $word_count;
printf "  Sentences:             %6d\n", $sentence_count;
printf "  Paragraphs:            %6d\n", scalar @paragraphs;
printf "  Lines:                 %6d\n", scalar @lines;

# --- Word Statistics ---
say "\n--- Word Statistics ---";

my @word_lengths = map { length($_) } @words;
my $avg_word_len = sum(@word_lengths) / $word_count;
my $max_word_len = max(@word_lengths);

printf "  Average word length:   %6.1f characters\n", $avg_word_len;
printf "  Longest word:          %6d characters\n", $max_word_len;
printf "  Avg words/sentence:    %6.1f\n", $word_count / $sentence_count;

# --- Word Frequency ---
say "\n--- Top 20 Most Frequent Words ---";

my %word_freq;
for my $word (@words) {
    $word_freq{lc $word}++;
}

my @sorted_words = sort { $word_freq{$b} <=> $word_freq{$a} || $a cmp $b } keys %word_freq;
my $unique_words = scalar @sorted_words;

printf "  Unique words: %d (lexical diversity: %.1f%%)\n\n",
    $unique_words, ($unique_words / $word_count) * 100;

printf "  %-4s %-20s %5s %6s %s\n", "Rank", "Word", "Count", "Freq", "Bar";
say "  " . "-" x 55;

for my $i (0..19) {
    last if $i >= scalar @sorted_words;
    my $word = $sorted_words[$i];
    my $count = $word_freq{$word};
    my $freq = ($count / $word_count) * 100;
    my $bar = "#" x int($freq * 5);
    printf "  %3d. %-20s %5d %5.1f%% %s\n", $i + 1, $word, $count, $freq, $bar;
}

# --- Word Length Distribution ---
say "\n--- Word Length Distribution ---";

my %length_dist;
$length_dist{length(lc $_)}++ for @words;
my $max_count = max(values %length_dist);

for my $len (sort { $a <=> $b } keys %length_dist) {
    my $count = $length_dist{$len};
    my $bar = "#" x int(($count / $max_count) * 30);
    printf "  %2d chars: %-30s %d words\n", $len, $bar, $count;
}

# --- Sentence Analysis ---
say "\n--- Sentence Length Distribution ---";

my @sent_lengths;
for my $sent (@sentences) {
    my @sent_words = ($sent =~ /\b\w+\b/g);
    push @sent_lengths, scalar @sent_words;
}

my $avg_sent_len = sum(@sent_lengths) / scalar(@sent_lengths);
my $max_sent_len = max(@sent_lengths);

printf "  Average sentence length: %.1f words\n", $avg_sent_len;
printf "  Longest sentence:        %d words\n", $max_sent_len;

my %sent_bucket;
for my $len (@sent_lengths) {
    my $bucket = int($len / 5) * 5;
    my $label = sprintf("%d-%d", $bucket, $bucket + 4);
    $sent_bucket{$label}++;
}

say "  Sentence length buckets:";
for my $bucket (sort keys %sent_bucket) {
    printf "    %-10s %s (%d)\n", $bucket, "#" x ($sent_bucket{$bucket} * 3), $sent_bucket{$bucket};
}

# --- Readability Metrics ---
say "\n--- Readability Metrics ---";

sub count_syllables {
    my ($word) = @_;
    $word = lc $word;
    return 1 if length($word) <= 3;
    $word =~ s/(?:[^laeiouy]es|ed|[^laeiouy]e)$//;
    $word =~ s/^y//;
    my @vowel_groups = ($word =~ /[aeiouy]+/g);
    my $count = scalar @vowel_groups;
    return $count > 0 ? $count : 1;
}

my $total_syllables = sum(map { count_syllables($_) } @words);
my $complex_words = scalar grep { count_syllables($_) >= 3 } @words;

# Flesch Reading Ease
my $flesch = 206.835
    - 1.015 * ($word_count / $sentence_count)
    - 84.6 * ($total_syllables / $word_count);

# Flesch-Kincaid Grade Level
my $fk_grade = 0.39 * ($word_count / $sentence_count)
    + 11.8 * ($total_syllables / $word_count)
    - 15.59;

# Gunning Fog Index
my $fog = 0.4 * (($word_count / $sentence_count) + 100 * ($complex_words / $word_count));

printf "  Total syllables:       %6d\n", $total_syllables;
printf "  Complex words (3+ syl):%6d (%.1f%%)\n",
    $complex_words, ($complex_words / $word_count) * 100;
printf "  Flesch Reading Ease:   %6.1f", $flesch;

if ($flesch >= 90)    { say " (Very Easy)" }
elsif ($flesch >= 80) { say " (Easy)" }
elsif ($flesch >= 70) { say " (Fairly Easy)" }
elsif ($flesch >= 60) { say " (Standard)" }
elsif ($flesch >= 50) { say " (Fairly Difficult)" }
elsif ($flesch >= 30) { say " (Difficult)" }
else                  { say " (Very Difficult)" }

printf "  Flesch-Kincaid Grade:  %6.1f\n", $fk_grade;
printf "  Gunning Fog Index:     %6.1f\n", $fog;

# --- Character Frequency ---
say "\n--- Letter Frequency ---";

my %letter_freq;
for my $char (split //, lc $text) {
    $letter_freq{$char}++ if $char =~ /[a-z]/;
}

my $total_letters = sum(values %letter_freq);

for my $letter ('a'..'z') {
    my $count = $letter_freq{$letter} // 0;
    my $pct = ($count / $total_letters) * 100;
    my $bar = "#" x int($pct * 3);
    printf "  %s: %-20s %5.1f%% (%d)\n", $letter, $bar, $pct, $count;
}

say "\nDone!";
