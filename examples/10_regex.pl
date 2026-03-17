#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== BASIC MATCHING ===";

my $text = "The quick brown fox jumps over the lazy dog";

if ($text =~ /quick/) {
    say "Found 'quick' in the text";
}

if ($text =~ /cat/) {
    say "Found 'cat'";
} else {
    say "'cat' not found in the text";
}

say "\n=== CASE-INSENSITIVE MATCHING ===";

if ($text =~ /QUICK/i) {
    say "Case-insensitive match for 'QUICK' succeeded";
}

say "\n=== CAPTURING GROUPS ===";

my $date = "Today is 2026-03-17, the deadline is 2026-12-31";

if ($date =~ /(\d{4})-(\d{2})-(\d{2})/) {
    say "First date found:";
    say "  Year:  $1";
    say "  Month: $2";
    say "  Day:   $3";
}

my @all_dates = ($date =~ /(\d{4}-\d{2}-\d{2})/g);
say "All dates: " . join(", ", @all_dates);

say "\n=== NAMED CAPTURES ===";

my $log_line = "2026-03-17 14:30:05 ERROR: Database connection failed";

if ($log_line =~ /(?<date>\d{4}-\d{2}-\d{2})\s+(?<time>\d{2}:\d{2}:\d{2})\s+(?<level>\w+):\s+(?<message>.+)/) {
    say "Log entry:";
    say "  Date:    $+{date}";
    say "  Time:    $+{time}";
    say "  Level:   $+{level}";
    say "  Message: $+{message}";
}

say "\n=== SUBSTITUTION ===";

my $sentence = "I have 3 cats and 5 dogs";

(my $replaced = $sentence) =~ s/cats/birds/;
say "Replace first: $replaced";

(my $global = $sentence) =~ s/\d+/many/g;
say "Replace all numbers: $global";

say "\n=== SUBSTITUTION WITH EVALUATION ===";

my $math_text = "The area is 5*3 and perimeter is 2*(5+3)";
(my $evaluated = $math_text) =~ s/(\d+)\*(\d+)/$1*$2 . "=" . ($1*$2)/e;
say "Evaluated: $evaluated";

my $template = "Hello {name}, you are {age} years old!";
my %vars = (name => "Alice", age => 30);
(my $filled = $template) =~ s/\{(\w+)\}/$vars{$1} \/\/ "{$1}"/ge;
say "Template: $filled";

say "\n=== CHARACTER CLASSES ===";

my @test_strings = ("hello123", "HELLO", "12345", "hello world", "hello_world", "  ");

for my $s (@test_strings) {
    my @matches;
    push @matches, "has digits"  if $s =~ /\d/;
    push @matches, "has letters" if $s =~ /[a-zA-Z]/;
    push @matches, "has spaces"  if $s =~ /\s/;
    push @matches, "all digits"  if $s =~ /^\d+$/;
    push @matches, "all alpha"   if $s =~ /^[a-zA-Z]+$/;
    push @matches, "word chars"  if $s =~ /^\w+$/;

    printf "  %-15s => %s\n", "'$s'", join(", ", @matches);
}

say "\n=== QUANTIFIERS ===";

my $data = "aabbbccccdddddeeeee";

my ($a_match) = ($data =~ /(a+)/);
my ($b_match) = ($data =~ /(b+)/);
my ($c_match) = ($data =~ /(c+)/);
say "a+: '$a_match'";
say "b+: '$b_match'";
say "c+: '$c_match'";

say "\n=== GREEDY vs LAZY ===";

my $html = '<b>bold</b> and <i>italic</i>';

my ($greedy) = ($html =~ /(<.+>)/);
my ($lazy)   = ($html =~ /(<.+?>)/);
say "Greedy: $greedy";
say "Lazy:   $lazy";

say "\n=== ANCHORS ===";

my @lines = ("Hello World", "hello", "say Hello", "HELLO!");

for my $line (@lines) {
    my @info;
    push @info, "starts with Hello" if $line =~ /^Hello/;
    push @info, "ends with Hello"   if $line =~ /Hello$/;
    push @info, "contains Hello/i"  if $line =~ /hello/i;
    push @info, "whole word Hello"  if $line =~ /\bHello\b/;

    printf "  %-15s => %s\n", "'$line'", join(", ", @info) || "no match";
}

say "\n=== SPLIT WITH REGEX ===";

my $csv = "Alice, 30, Engineer, San Francisco";
my @fields = split /,\s*/, $csv;
say "Fields: " . join(" | ", @fields);

my $messy = "one   two\tthree\n\nfour";
my @words = split /\s+/, $messy;
say "Words: " . join(", ", @words);

say "\n=== PRACTICAL: EMAIL VALIDATION ===";

my @emails = (
    'user@example.com',
    'invalid@',
    'name@domain.co.uk',
    '@missing.com',
    'spaces @bad.com',
    'good.name+tag@domain.org',
);

for my $email (@emails) {
    my $valid = ($email =~ /^[a-zA-Z0-9._%+-]+\@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/)
                ? "VALID" : "INVALID";
    printf "  %-30s %s\n", $email, $valid;
}

say "\n=== PRACTICAL: EXTRACT ALL URLS ===";

my $webpage = <<'HTML';
Visit https://www.example.com for more info.
Also check http://docs.perl.org/perl.html
and https://metacpan.org/search?q=regex
HTML

my @urls = ($webpage =~ m{(https?://[^\s<>"]+)}g);
say "Found URLs:";
say "  $_" for @urls;

say "\n=== LOOKAHEAD AND LOOKBEHIND ===";

my $prices = 'apple:$5.99 banana:$1.50 cherry:$3.25';

my @amounts = ($prices =~ /(?<=\$)\d+\.\d{2}/g);
say "Prices: " . join(", ", map { "\$$_" } @amounts);

my $password = 'MyP@ssw0rd!';
my @checks;
push @checks, "8+ chars"    if $password =~ /.{8,}/;
push @checks, "uppercase"   if $password =~ /[A-Z]/;
push @checks, "lowercase"   if $password =~ /[a-z]/;
push @checks, "digit"       if $password =~ /\d/;
push @checks, "special"     if $password =~ /[^a-zA-Z0-9]/;
say "Password '$password' has: " . join(", ", @checks);
