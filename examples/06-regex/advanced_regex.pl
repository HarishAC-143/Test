#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Advanced Regular Expressions
# ============================================================

say "=== LOOKAHEAD AND LOOKBEHIND ===";

my $text = "foo123bar456baz789end";

say "Positive lookahead (digits before 'bar'):";
if ($text =~ /(\d+)(?=bar)/) {
    say "  Found: $1";
}

say "\nNegative lookahead (digits NOT before 'bar'):";
while ($text =~ /(\d+)(?!bar)/g) {
    say "  Found: $1" if length($1) > 1;
}

say "\nPositive lookbehind (digits after 'bar'):";
if ($text =~ /(?<=bar)(\d+)/) {
    say "  Found: $1";
}

say "\nNegative lookbehind (digits NOT after 'bar'):";
while ($text =~ /(?<!bar)(\d+)/g) {
    say "  Found: $1" if length($1) > 1;
}

say "\n=== PRACTICAL: INSERT COMMAS INTO NUMBERS ===";

my $big_number = "1234567890";
(my $formatted = $big_number) =~ s/(\d)(?=(\d{3})+$)/$1,/g;
say "Formatted: $formatted";

say "\n=== BACKREFERENCES ===";

my @test_strings = ("abcabc", "xyzxyz", "abcxyz", "aabbcc");

say "Finding repeated patterns (\\1 backreference):";
for my $str (@test_strings) {
    if ($str =~ /^(.+)\1$/) {
        say "  '$str' has repeated pattern '$1'";
    } else {
        say "  '$str' does not repeat";
    }
}

say "\nFinding doubled words:";
my $sentence = "The the quick brown fox fox jumps over the the lazy dog";
(my $fixed = $sentence) =~ s/\b(\w+)\s+\1\b/$1/gi;
say "  Original: $sentence";
say "  Fixed:    $fixed";

say "\n=== NAMED CAPTURES AND BACKREFERENCES ===";

my $log_line = '2026-03-20 14:30:05 [ERROR] Database connection failed (host: db.example.com)';

if ($log_line =~ /(?<date>\d{4}-\d{2}-\d{2})\s+(?<time>\d{2}:\d{2}:\d{2})\s+\[(?<level>\w+)\]\s+(?<message>.+)/) {
    say "Log entry parsed:";
    say "  Date:    $+{date}";
    say "  Time:    $+{time}";
    say "  Level:   $+{level}";
    say "  Message: $+{message}";
}

say "\n=== NON-GREEDY QUANTIFIERS ===";

my $html = '<div class="header">Title</div><div class="body">Content</div>';

say "Greedy match:";
if ($html =~ /<div.*>(.+)<\/div>/) {
    say "  Content: $1";
}

say "\nNon-greedy match:";
while ($html =~ /<div[^>]*>(.+?)<\/div>/g) {
    say "  Content: $1";
}

say "\n=== EXTENDED MODE (/x) FOR READABLE REGEX ===";

my $email = 'user.name+tag@example.co.uk';

my $email_regex = qr{
    ^                       # Start of string
    (                       # Begin capture: local part
        [\w.+-]+            #   Word chars, dots, plus, hyphen
    )                       # End capture
    \@                      # Literal @
    (                       # Begin capture: domain
        [\w.-]+             #   Domain name
        \.                  #   Dot
        [a-zA-Z]{2,}       #   TLD (2+ letters)
    )                       # End capture
    $                       # End of string
}x;

if ($email =~ $email_regex) {
    say "Valid email: local='$1', domain='$2'";
}

say "\n=== CONDITIONAL PATTERNS ===";

my @data = ('(abc)', '[abc]', '(abc]', '[abc)', 'abc');

say "Matching paired brackets:";
for my $item (@data) {
    if ($item =~ /^(?:(\()|(\[))   # Match opening bracket
                   \w+              # Content
                   (?(1)\)|\])     # If group 1 matched, expect ), else ]
                  $/x) {
        say "  '$item' => properly paired";
    } else {
        say "  '$item' => NOT properly paired";
    }
}

say "\n=== REGEX WITH SPLIT ===";

my $csv = 'field1,"field, with comma","field with ""quotes""",field4';

my @fields = $csv =~ /("(?:[^"]|"")*"|[^,]*)/g;
say "CSV fields:";
for my $i (0..$#fields) {
    my $field = $fields[$i];
    $field =~ s/^"(.*)"$/$1/;
    $field =~ s/""/"/g;
    say "  [$i] $field";
}

say "\n=== BUILDING COMPLEX PATTERNS ===";

my $ip_octet = qr{
    (?:
        25[0-5]         |  # 250-255
        2[0-4][0-9]     |  # 200-249
        [01]?[0-9]{1,2}   # 0-199
    )
}x;

my $ip_pattern = qr{^$ip_octet\.$ip_octet\.$ip_octet\.$ip_octet$}x;

my @ips = ('192.168.1.1', '10.0.0.1', '255.255.255.255', '256.1.1.1', '1.2.3.999', '127.0.0.1');

say "IP validation (proper range check):";
for my $ip (@ips) {
    my $valid = ($ip =~ $ip_pattern) ? "VALID" : "INVALID";
    printf "  %-20s => %s\n", $ip, $valid;
}

say "\n=== REGEX SPECIAL VARIABLES ===";

my $str = "Hello Beautiful World";
$str =~ /(Beautiful)/;
say "Match (\$&):  $&";
say "Before (\$\`): $`";
say "After (\$'):  $'";

say "\n--- Advanced regex demo complete ---";
