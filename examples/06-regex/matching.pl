#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Regular Expression Pattern Matching
# ============================================================

say "=== BASIC MATCHING ===";

my $text = "The quick brown fox jumps over the lazy dog";

if ($text =~ /quick/) {
    say "Found 'quick' in the text";
}

if ($text !~ /cat/) {
    say "'cat' NOT found in the text";
}

say "\n=== CASE INSENSITIVE (/i) ===";

if ($text =~ /QUICK BROWN/i) {
    say "Case-insensitive match works!";
}

say "\n=== ANCHORS ===";

if ($text =~ /^The/) {
    say "Text starts with 'The'";
}

if ($text =~ /dog$/) {
    say "Text ends with 'dog'";
}

if ("hello" =~ /^hello$/) {
    say "'hello' is an exact match";
}

say "\n=== CHARACTER CLASSES ===";

my $sample = "My phone is 555-123-4567 and zip is 90210";

my @digits = ($sample =~ /\d/g);
say "Digits found: @digits";

my @words = ($sample =~ /\b\w+\b/g);
say "Words: @words";

if ($sample =~ /[0-9]{3}-[0-9]{3}-[0-9]{4}/) {
    say "Contains a phone number pattern";
}

say "\n=== QUANTIFIERS ===";

my @test_strings = (
    "color",
    "colour",
    "colouur",
    "colr",
);

for my $str (@test_strings) {
    my $match = ($str =~ /colou?r/) ? "MATCH" : "no match";
    printf "  %-10s => %s (u? = zero or one 'u')\n", $str, $match;
}

say "\nGreedy vs Non-Greedy:";
my $html = '<b>bold</b> and <i>italic</i>';
$html =~ /<(.+)>/;
say "  Greedy (.+):     '$1'";

$html =~ /<(.+?)>/;
say "  Non-greedy (.+?): '$1'";

say "\n=== CAPTURING GROUPS ===";

my $date = "Today is 2026-03-20, time is 14:30:00";

if ($date =~ /(\d{4})-(\d{2})-(\d{2})/) {
    say "Year:  $1";
    say "Month: $2";
    say "Day:   $3";
}

say "\nNamed captures:";
if ($date =~ /(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/) {
    say "Year:  $+{year}";
    say "Month: $+{month}";
    say "Day:   $+{day}";
}

say "\n=== ALTERNATION ===";

my @animals = qw(cat dog bird fish cat hamster dog);
for my $animal (@animals) {
    if ($animal =~ /^(?:cat|dog)$/) {
        say "  $animal is a common pet";
    }
}

say "\n=== GLOBAL MATCHING (/g) ===";

my $csv_line = 'alice@example.com, bob@test.org, charlie@domain.net';

my @emails = ($csv_line =~ /[\w.]+\@[\w.]+/g);
say "Emails found:";
say "  $_" for @emails;

say "\nPositions of matches:";
while ($csv_line =~ /[\w.]+\@[\w.]+/g) {
    printf "  Found '%s' at position %d\n", $&, pos($csv_line) - length($&);
}

say "\n=== SPECIAL VARIABLES ===";

my $str = "Hello, Perl World!";
if ($str =~ /(Perl)/) {
    say "Match:  '$&'";      # Matched string
    say "Before: '$`'";      # String before match
    say "After:  '\''";      # String after match
    say "Group:  '$1'";      # First capture group
}

say "\n=== PRACTICAL: VALIDATE FORMATS ===";

my @test_emails = (
    'user@example.com',
    'bad-email@',
    'name.surname@domain.co.uk',
    '@no-user.com',
    'spaces in@email.com',
);

say "Email validation:";
for my $email (@test_emails) {
    my $valid = ($email =~ /^[\w.+-]+\@[\w.-]+\.\w{2,}$/) ? "VALID" : "INVALID";
    printf "  %-30s => %s\n", $email, $valid;
}

my @test_ips = ('192.168.1.1', '10.0.0.1', '999.999.999.999', 'abc.def.ghi.jkl', '127.0.0.1');

say "\nIP address validation (simple pattern):";
for my $ip (@test_ips) {
    my $valid = ($ip =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) ? "MATCH" : "NO MATCH";
    printf "  %-20s => %s\n", $ip, $valid;
}

say "\n--- Regex matching demo complete ---";
