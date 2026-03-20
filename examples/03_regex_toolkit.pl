#!/usr/bin/perl
# Demonstrates Perl's regular expression capabilities with practical patterns.

use strict;
use warnings;

print "=== PATTERN MATCHING ===\n\n";

my @test_strings = (
    'user@example.com',
    'invalid-email',
    'admin@server.co.uk',
    'test@',
    'hello.world@domain.org',
);

my $email_re = qr/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

for my $str (@test_strings) {
    my $valid = $str =~ $email_re ? "VALID" : "INVALID";
    printf "  %-30s %s\n", $str, $valid;
}

print "\n=== CAPTURING GROUPS ===\n\n";

my @dates = (
    "2026-03-20",
    "2025-12-31",
    "2024-01-15",
);

for my $date (@dates) {
    if ($date =~ /^(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})$/) {
        printf "  %s -> Year: %s, Month: %s, Day: %s\n",
               $date, $+{year}, $+{month}, $+{day};
    }
}

print "\n=== SEARCH AND REPLACE ===\n\n";

my $text = "The quick brown fox jumps over the lazy dog.";
print "Original: $text\n";

(my $replaced = $text) =~ s/\b(\w)/\u$1/g;
print "Title Case: $replaced\n";

(my $censored = $text) =~ s/\b\w{4,5}\b/****/g;
print "Censored (4-5 letter words): $censored\n";

(my $reversed_words = $text) =~ s/(\w+)/reverse $1/ge;
print "Reversed words: $reversed_words\n";

print "\n=== EXTRACTING DATA ===\n\n";

my $log_entry = '[2026-03-20 14:30:45] ERROR: Connection timeout after 30s (host=db.example.com port=5432)';

if ($log_entry =~ /\[(.+?)\]\s+(\w+):\s+(.+?)\s+\((.+)\)/) {
    my ($timestamp, $level, $message, $details) = ($1, $2, $3, $4);
    print "  Timestamp: $timestamp\n";
    print "  Level:     $level\n";
    print "  Message:   $message\n";
    print "  Details:   $details\n";

    my %params;
    while ($details =~ /(\w+)=(\S+)/g) {
        $params{$1} = $2;
    }
    print "  Parsed params:\n";
    for my $key (sort keys %params) {
        print "    $key = $params{$key}\n";
    }
}

print "\n=== LOOKAHEAD AND LOOKBEHIND ===\n\n";

my $prices = "Apple costs \$1.50, Banana costs \$0.75, Cherry costs \$2.00";
my @amounts = ($prices =~ /(?<=\$)\d+\.\d{2}/g);
print "Prices found: ", join(", ", map { "\$$_" } @amounts), "\n";

my $number = "1234567890";
(my $formatted = $number) =~ s/(\d)(?=(\d{3})+$)/$1,/g;
print "Formatted number: $formatted\n";

print "\n=== PRACTICAL: PASSWORD VALIDATOR ===\n\n";

my @passwords = ("abc", "Password1!", "short", "NoSpecialChar1", 'valid_P@ss1');

for my $pw (@passwords) {
    my @issues;
    push @issues, "too short (min 8)"     if length($pw) < 8;
    push @issues, "needs uppercase"       unless $pw =~ /[A-Z]/;
    push @issues, "needs lowercase"       unless $pw =~ /[a-z]/;
    push @issues, "needs digit"           unless $pw =~ /\d/;
    push @issues, "needs special char"    unless $pw =~ /[!@#\$%^&*_\-+=]/;

    if (@issues) {
        printf "  %-15s WEAK (%s)\n", $pw, join("; ", @issues);
    } else {
        printf "  %-15s STRONG\n", $pw;
    }
}
