#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Practical Project: Text Statistics Analyzer
# ============================================================
# Analyzes text for word frequency, sentence count,
# readability metrics, and other statistics.
# ============================================================

my $sample_text = <<'TEXT';
Perl is a family of two high-level, general-purpose, interpreted, dynamic
programming languages. Perl 5 and Perl Raku (formerly known as Perl 6).

Though Perl is not officially an acronym, there are various backronyms in
use, including "Practical Extraction and Reporting Language". Perl was
developed by Larry Wall in 1987 as a general-purpose Unix scripting
language to make report processing easier. Since then, it has undergone
many changes and revisions.

Perl 5 gained widespread popularity in the late 1990s as a CGI scripting
language, in part due to its powerful regular expression and string
parsing abilities. In addition to CGI, Perl 5 is used for system
administration, network programming, finance, bioinformatics, and other
applications. Perl is nicknamed "the Swiss Army chainsaw" of scripting
languages because of its flexibility and power.

The language is designed around the principle that "there is more than one
way to do it". As a multi-paradigm language, Perl supports procedural,
object-oriented, and functional programming styles. Perl has a rich
ecosystem of third-party modules available through CPAN.
TEXT

say "=" x 60;
say "          TEXT STATISTICS ANALYZER";
say "=" x 60;

my %stats;

my @characters = split //, $sample_text;
$stats{total_chars}     = scalar @characters;
$stats{chars_no_spaces} = scalar grep { $_ ne ' ' && $_ ne "\n" } @characters;

my @words = ($sample_text =~ /\b[a-zA-Z']+\b/g);
$stats{total_words}  = scalar @words;

my @sentences = split /[.!?]+/, $sample_text;
@sentences = grep { /\w/ } @sentences;
$stats{total_sentences} = scalar @sentences;

my @paragraphs = split /\n\s*\n/, $sample_text;
@paragraphs = grep { /\w/ } @paragraphs;
$stats{total_paragraphs} = scalar @paragraphs;

my @lines = split /\n/, $sample_text;
$stats{total_lines} = scalar @lines;

say "\n--- BASIC STATISTICS ---";
printf "  Characters (total):        %d\n", $stats{total_chars};
printf "  Characters (no spaces):    %d\n", $stats{chars_no_spaces};
printf "  Words:                     %d\n", $stats{total_words};
printf "  Sentences:                 %d\n", $stats{total_sentences};
printf "  Paragraphs:                %d\n", $stats{total_paragraphs};
printf "  Lines:                     %d\n", $stats{total_lines};

my $avg_word_len = $stats{total_words} > 0
    ? $stats{chars_no_spaces} / $stats{total_words} : 0;
my $avg_sentence_len = $stats{total_sentences} > 0
    ? $stats{total_words} / $stats{total_sentences} : 0;
my $avg_para_len = $stats{total_paragraphs} > 0
    ? $stats{total_sentences} / $stats{total_paragraphs} : 0;

printf "\n  Avg word length:           %.1f chars\n", $avg_word_len;
printf "  Avg sentence length:       %.1f words\n", $avg_sentence_len;
printf "  Avg paragraph length:      %.1f sentences\n", $avg_para_len;

say "\n--- WORD FREQUENCY (Top 20) ---";
my %word_freq;
for my $word (@words) {
    $word_freq{lc $word}++;
}

my @sorted_words = sort { $word_freq{$b} <=> $word_freq{$a} || $a cmp $b }
                   keys %word_freq;

my $rank = 0;
my $max_freq = $word_freq{$sorted_words[0]} // 1;
for my $word (@sorted_words[0..19]) {
    last unless defined $word;
    $rank++;
    my $bar_len = int(($word_freq{$word} / $max_freq) * 30);
    printf "  %2d. %-15s %3d %s\n",
        $rank, $word, $word_freq{$word}, "#" x $bar_len;
}

say "\n--- WORD LENGTH DISTRIBUTION ---";
my %length_dist;
for my $word (@words) {
    $length_dist{length($word)}++;
}

for my $len (sort { $a <=> $b } keys %length_dist) {
    my $bar_len = int(($length_dist{$len} / $stats{total_words}) * 100);
    printf "  %2d chars: %3d words (%5.1f%%) %s\n",
        $len, $length_dist{$len},
        ($length_dist{$len} / $stats{total_words}) * 100,
        "#" x $bar_len;
}

say "\n--- UNIQUE WORDS ---";
my $unique = scalar keys %word_freq;
my $vocabulary_richness = $stats{total_words} > 0
    ? ($unique / $stats{total_words}) * 100 : 0;
printf "  Unique words:        %d\n", $unique;
printf "  Vocabulary richness: %.1f%% (unique/total)\n", $vocabulary_richness;

my @hapax = grep { $word_freq{$_} == 1 } keys %word_freq;
printf "  Hapax legomena:      %d (words appearing only once)\n", scalar @hapax;

say "\n--- READABILITY SCORES ---";

my $syllable_count = 0;
my $complex_words  = 0;

for my $word (@words) {
    my $syl = count_syllables($word);
    $syllable_count += $syl;
    $complex_words++ if $syl >= 3;
}

my $flesch_reading = 206.835
    - (1.015 * $avg_sentence_len)
    - (84.6 * ($syllable_count / ($stats{total_words} || 1)));

my $flesch_kincaid = (0.39 * $avg_sentence_len)
    + (11.8 * ($syllable_count / ($stats{total_words} || 1)))
    - 15.59;

my $gunning_fog = 0.4 * ($avg_sentence_len
    + 100 * ($complex_words / ($stats{total_words} || 1)));

printf "  Flesch Reading Ease:   %6.1f (%s)\n",
    $flesch_reading, interpret_flesch($flesch_reading);
printf "  Flesch-Kincaid Grade:  %6.1f\n", $flesch_kincaid;
printf "  Gunning Fog Index:     %6.1f\n", $gunning_fog;
printf "  Syllable count:        %d\n", $syllable_count;
printf "  Complex words (3+ syl):%d (%.1f%%)\n",
    $complex_words, ($complex_words / ($stats{total_words} || 1)) * 100;

say "\n--- CHARACTER FREQUENCY ---";
my %char_freq;
for my $char (split //, lc $sample_text) {
    next unless $char =~ /[a-z]/;
    $char_freq{$char}++;
}

my $max_char_freq = (sort { $b <=> $a } values %char_freq)[0] // 1;
for my $char ('a'..'z') {
    my $count = $char_freq{$char} // 0;
    my $bar_len = int(($count / $max_char_freq) * 30);
    printf "  %s: %3d %s\n", $char, $count, "#" x $bar_len if $count > 0;
}

say "\n" . "=" x 60;
say "Analysis complete.";
say "=" x 60;

# --- Helper subroutines ---

sub count_syllables {
    my ($word) = @_;
    $word = lc $word;
    return 1 if length($word) <= 3;

    $word =~ s/(?:es|ed|[^l]e)$//;
    $word =~ s/^y//;

    my @vowel_groups = ($word =~ /[aeiouy]+/g);
    my $count = scalar @vowel_groups;
    return $count > 0 ? $count : 1;
}

sub interpret_flesch {
    my ($score) = @_;
    if    ($score >= 90) { return "Very Easy" }
    elsif ($score >= 80) { return "Easy" }
    elsif ($score >= 70) { return "Fairly Easy" }
    elsif ($score >= 60) { return "Standard" }
    elsif ($score >= 50) { return "Fairly Difficult" }
    elsif ($score >= 30) { return "Difficult" }
    else                 { return "Very Difficult" }
}
