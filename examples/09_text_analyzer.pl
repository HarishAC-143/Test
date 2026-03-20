#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- Practical Project: Text File Analyzer ---
# Analyzes a block of text for word frequency, sentence count,
# average word length, and other statistics.

my $sample_text = <<'END_TEXT';
Perl is a highly capable, feature-rich programming language with over 30 years
of development. Perl runs on over 100 platforms from portables to mainframes
and is suitable for both rapid prototyping and large scale development projects.

The Perl language borrows features from other programming languages including C,
shell scripting, AWK, and sed. Perl provides powerful text processing facilities
without the data length limits of many contemporary Unix command-line tools.

Perl is widely used for system administration, web development, network
programming, bioinformatics, and many other tasks. The Comprehensive Perl
Archive Network (CPAN) contains over 200,000 modules of ready-to-use code.

One of Perl's greatest strengths is its regular expression support. Regular
expressions are deeply integrated into Perl's syntax, making text pattern
matching and manipulation extremely easy and efficient. Perl's regex engine
is the basis for PCRE (Perl Compatible Regular Expressions) used in many
other languages.
END_TEXT

say "=" x 60;
say "           TEXT ANALYZER";
say "=" x 60;

# --- Character Analysis ---
my $char_count       = length($sample_text);
my $char_no_spaces   = ($sample_text =~ tr/ \t\n//c);
my $alpha_count      = ($sample_text =~ tr/a-zA-Z//);
my $digit_count      = ($sample_text =~ tr/0-9//);

# --- Word Analysis ---
my @words = ($sample_text =~ /\b[a-zA-Z']+\b/g);
my $word_count = scalar @words;

my @lower_words = map { lc } @words;

my $total_word_len = 0;
$total_word_len += length($_) for @words;
my $avg_word_len = $total_word_len / $word_count;

my @sorted_by_len = sort { length($b) <=> length($a) } @words;
my $longest_word  = $sorted_by_len[0];
my $shortest_word = $sorted_by_len[-1];

# --- Sentence Analysis ---
my @sentences = split /[.!?]+\s*/, $sample_text;
@sentences = grep { /\S/ } @sentences;
my $sentence_count = scalar @sentences;
my $avg_words_per_sentence = $word_count / $sentence_count;

# --- Paragraph Analysis ---
my @paragraphs = split /\n\n+/, $sample_text;
@paragraphs = grep { /\S/ } @paragraphs;
my $para_count = scalar @paragraphs;

# --- Word Frequency ---
my %freq;
$freq{$_}++ for @lower_words;

my @by_freq = sort { $freq{$b} <=> $freq{$a} || $a cmp $b } keys %freq;

# --- Unique Words ---
my $unique_count = scalar keys %freq;

# --- Output Results ---
say "\n--- Character Statistics ---";
printf "  Total characters      : %d\n", $char_count;
printf "  Non-space characters  : %d\n", $char_no_spaces;
printf "  Alphabetic characters : %d\n", $alpha_count;
printf "  Numeric characters    : %d\n", $digit_count;

say "\n--- Word Statistics ---";
printf "  Total words           : %d\n", $word_count;
printf "  Unique words          : %d\n", $unique_count;
printf "  Avg word length       : %.1f characters\n", $avg_word_len;
printf "  Longest word          : '%s' (%d chars)\n", $longest_word, length($longest_word);
printf "  Shortest word         : '%s' (%d chars)\n", $shortest_word, length($shortest_word);

say "\n--- Structure Statistics ---";
printf "  Sentences             : %d\n", $sentence_count;
printf "  Paragraphs            : %d\n", $para_count;
printf "  Avg words/sentence    : %.1f\n", $avg_words_per_sentence;

say "\n--- Top 15 Most Frequent Words ---";
printf "  %-20s %s\n", "Word", "Count";
printf "  %-20s %s\n", "-" x 20, "-" x 5;
for my $i (0 .. 14) {
    last if $i > $#by_freq;
    printf "  %-20s %d\n", $by_freq[$i], $freq{$by_freq[$i]};
}

say "\n--- Words by Length Distribution ---";
my %len_dist;
$len_dist{length($_)}++ for @lower_words;
for my $len (sort { $a <=> $b } keys %len_dist) {
    printf "  %2d letters: %3d words  %s\n",
        $len, $len_dist{$len}, "#" x ($len_dist{$len});
}

say "\n" . "=" x 60;
say "Analysis complete!";
