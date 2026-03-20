#!/usr/bin/perl
# 05_regex.pl — Regular expression matching, substitution, and practical patterns
use strict;
use warnings;
use feature 'say';

say "=" x 50;
say "  Perl Regular Expressions Demo";
say "=" x 50;

# --- Basic Matching ---
say "\n--- Basic Matching ---";

my $text = "The quick brown fox jumps over the lazy dog";
say "Text: '$text'";

say "Contains 'fox':  " . ($text =~ /fox/  ? "YES" : "NO");
say "Contains 'cat':  " . ($text =~ /cat/  ? "YES" : "NO");
say "Starts with 'The': " . ($text =~ /^The/ ? "YES" : "NO");
say "Ends with 'dog':   " . ($text =~ /dog$/ ? "YES" : "NO");

# Case-insensitive
say "Contains 'QUICK' (case-insensitive): " . ($text =~ /QUICK/i ? "YES" : "NO");

# --- Capture Groups ---
say "\n--- Capture Groups ---";

if ($text =~ /(\w+)\s+fox/) {
    say "Word before 'fox': $1";
}

if ($text =~ /(\w+)\s+(\w+)\s+(\w+)/) {
    say "First three words: $1, $2, $3";
}

# Named captures
if ($text =~ /(?<adj>\w+)\s+fox\s+(?<verb>\w+)/) {
    say "Fox adjective: $+{adj}";
    say "Fox verb: $+{verb}";
}

# --- Global Matching ---
say "\n--- Global Matching ---";

my @all_words = ($text =~ /(\w+)/g);
say "Word count: " . scalar(@all_words);
say "Words: " . join(", ", @all_words);

my $vowel_count = () = ($text =~ /[aeiou]/gi);
say "Vowel count: $vowel_count";

# --- Substitution ---
say "\n--- Substitution ---";

(my $replaced = $text) =~ s/fox/cat/;
say "Replace 'fox' -> 'cat': $replaced";

(my $all_replaced = $text) =~ s/the/a/gi;
say "Replace all 'the' -> 'a': $all_replaced";

# Using captures in replacement
my $date = "2025-03-15";
(my $reformatted = $date) =~ s/(\d{4})-(\d{2})-(\d{2})/$3\/$2\/$1/;
say "Date reformatted: $date -> $reformatted";

# Non-destructive substitution with /r
my $original = "Hello World";
my $modified = $original =~ s/World/Perl/r;
say "Original: $original, Modified: $modified";

# --- Character Classes ---
say "\n--- Character Classes ---";

my $mixed = "abc123DEF!@#456ghi";
my @digits  = ($mixed =~ /(\d)/g);
my @letters = ($mixed =~ /([a-zA-Z])/g);
my @special = ($mixed =~ /([^a-zA-Z0-9])/g);

say "Input: $mixed";
say "Digits:  @digits";
say "Letters: @letters";
say "Special: @special";

# --- Quantifiers ---
say "\n--- Quantifiers ---";

my $sample = "color colour colouur";
my @british = ($sample =~ /(colou+r)/g);
say "Matches for 'colou+r': @british";

my @optional = ($sample =~ /(colou?r)/g);
say "Matches for 'colou?r': @optional";

# Greedy vs Non-greedy
my $html = '<b>bold</b> and <i>italic</i>';
my ($greedy) = ($html =~ /(<.*>)/);
say "\nGreedy  '<.*>':  $greedy";

my ($lazy) = ($html =~ /(<.*?>)/);
say "Lazy    '<.*?>': $lazy";

my @all_tags = ($html =~ /(<[^>]+>)/g);
say "All tags: " . join(", ", @all_tags);

# --- Practical Pattern Library ---
say "\n--- Practical Patterns ---";

# Email validation
my @test_emails = ('user@example.com', 'bad@', 'name+tag@sub.domain.org', '@missing.com');
my $email_re = qr/^[\w.+-]+\@[\w-]+(?:\.[\w-]+)+$/;

for my $email (@test_emails) {
    my $valid = $email =~ $email_re ? "VALID" : "INVALID";
    printf "  %-30s %s\n", $email, $valid;
}

# IP address extraction
my $log = "Server 192.168.1.100 connected to 10.0.0.1 via gateway 172.16.0.1";
my @ips = ($log =~ /(\d{1,3}(?:\.\d{1,3}){3})/g);
say "\nIPs found: " . join(", ", @ips);

# URL extraction
my $content = "Visit https://example.com or http://perl.org/docs for more info";
my @urls = ($content =~ /(https?:\/\/\S+)/g);
say "URLs found: " . join(", ", @urls);

# Phone number normalization
my @phones = ("(555) 123-4567", "555.123.4567", "555-123-4567", "5551234567");
say "\nPhone number normalization:";
for my $phone (@phones) {
    (my $normalized = $phone) =~ s/[^0-9]//g;
    $normalized =~ s/(\d{3})(\d{3})(\d{4})/($1) $2-$3/;
    printf "  %-20s -> %s\n", $phone, $normalized;
}

# --- Extended Mode (readable regex) ---
say "\n--- Extended Mode (/x) ---";
my $iso_date_re = qr/
    ^
    (\d{4})       # year
    [-\/]         # separator
    (0[1-9]|1[0-2])  # month (01-12)
    [-\/]         # separator
    (0[1-9]|[12]\d|3[01])  # day (01-31)
    $
/x;

my @dates = ("2025-03-15", "2025/12/31", "2025-13-01", "2025-00-15");
for my $d (@dates) {
    if ($d =~ $iso_date_re) {
        say "  $d => VALID (year=$1, month=$2, day=$3)";
    } else {
        say "  $d => INVALID";
    }
}

# --- Split with Regex ---
say "\n--- Split with Regex ---";
my $csv_line = '  one ,  two  , three,four  ';
my @fields = split(/\s*,\s*/, $csv_line);
say "Split CSV: [" . join("] [", map { s/^\s+|\s+$//gr } @fields) . "]";

say "\nDone!";
