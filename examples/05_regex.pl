#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- Regular Expressions ---

say "=== BASIC MATCHING ===";

my $text = "The quick brown fox jumps over the lazy dog";

if ($text =~ /quick/) {
    say "Found 'quick' in: \"$text\"";
}

if ($text =~ /QUICK/i) {
    say "Case-insensitive match for 'QUICK' succeeded.";
}

unless ($text =~ /cat/) {
    say "'cat' was NOT found in the text.";
}

say "\n=== CAPTURE GROUPS ===";

if ($text =~ /(\w+)\s+fox/) {
    say "Word before 'fox': $1";
}

if ($text =~ /(\w+)\s+(\w+)\s+(\w+)/) {
    say "First three words: $1, $2, $3";
}

say "\n=== NAMED CAPTURES ===";

my $date_str = "Today is 2026-03-20 (Friday)";
if ($date_str =~ /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/) {
    say "Year : $+{year}";
    say "Month: $+{month}";
    say "Day  : $+{day}";
}

say "\n=== SUBSTITUTION ===";

my $greeting = "Hello World";
(my $modified = $greeting) =~ s/World/Perl/;
say "Original: $greeting";
say "Modified: $modified";

my $csv = "apple,banana,cherry,date";
(my $spaced = $csv) =~ s/,/ | /g;
say "CSV    : $csv";
say "Spaced : $spaced";

say "\n=== GLOBAL MATCHING ===";

my $data = "Scores: 85, 92, 78, 95, 60, 88";
my @scores = ($data =~ /(\d+)/g);
say "Extracted scores: @scores";

my $total = 0;
$total += $_ for @scores;
printf "Average: %.1f\n", $total / scalar(@scores);

say "\n=== QUANTIFIERS ===";

my @test_strings = ("color", "colour", "colouuur", "clr");
for my $s (@test_strings) {
    if ($s =~ /colou?r/) {
        say "  '$s' matches /colou?r/ (? = 0 or 1)";
    }
    if ($s =~ /colou*r/) {
        say "  '$s' matches /colou*r/ (* = 0 or more)";
    }
    if ($s =~ /colou+r/) {
        say "  '$s' matches /colou+r/ (+ = 1 or more)";
    }
}

say "\n=== GREEDY vs. NON-GREEDY ===";

my $html = '<b>bold</b> and <i>italic</i>';
if ($html =~ /<(.+)>/) {
    say "Greedy match    : $1";
}
if ($html =~ /<(.+?)>/) {
    say "Non-greedy match: $1";
}

say "\n=== CHARACTER CLASSES ===";

my @samples = ("hello123", "ALLCAPS", "12345", "mixed_case_42", "   ");
for my $s (@samples) {
    my @props;
    push @props, "has digits"  if $s =~ /\d/;
    push @props, "has letters" if $s =~ /[a-zA-Z]/;
    push @props, "has spaces"  if $s =~ /\s/;
    push @props, "all digits"  if $s =~ /^\d+$/;
    push @props, "all alpha"   if $s =~ /^[a-zA-Z]+$/;
    say sprintf "  %-15s => %s", "'$s'", join(", ", @props);
}

say "\n=== EMAIL VALIDATION ===";

my @emails = (
    'user@example.com',
    'invalid@',
    'name@sub.domain.org',
    '@nodomain.com',
    'user+tag@gmail.com',
);

for my $email (@emails) {
    my $valid = ($email =~ /^[\w.+-]+\@[\w.-]+\.\w{2,}$/) ? "VALID" : "INVALID";
    printf "  %-25s => %s\n", $email, $valid;
}

say "\n=== SPLIT AND JOIN ===";

my $sentence = "Perl is a powerful language";
my @words = split(/\s+/, $sentence);
say "Words: " . join(", ", @words);

my $reversed = join(" ", reverse @words);
say "Reversed: $reversed";

say "\n=== TRANSLITERATION (tr///) ===";

my $msg = "Hello World";
(my $rotated = $msg) =~ tr/A-Za-z/N-ZA-Mn-za-m/;
say "ROT13 of '$msg': $rotated";

my $vowel_count = ($msg =~ tr/aeiouAEIOU//);
say "Vowel count in '$msg': $vowel_count";

say "\n=== EXTENDED MODE (/x) ===";

my $phone = "Call me at (555) 123-4567 please";
if ($phone =~ /
    \(? (\d{3}) \)?   # area code, optional parens
    [-.\s]?            # separator
    (\d{3})            # first 3 digits
    [-.\s]?            # separator
    (\d{4})            # last 4 digits
/x) {
    say "Phone: ($1) $2-$3";
}

say "\nDone!";
