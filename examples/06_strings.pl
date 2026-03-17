#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== STRING QUOTING ===";

my $name = "World";

my $double = "Hello, $name!\n";       # interpolation happens
my $single = 'Hello, $name!\n';       # no interpolation
print "Double-quoted: $double";
say "Single-quoted: $single";

my $qq_str = qq{He said, "Hello, $name!"};
my $q_str  = q{He said, "Hello, $name!"};
say "qq{}: $qq_str";
say "q{}:  $q_str";

say "\n=== HEREDOC ===";

my $message = <<END_MSG;
Dear $name,

This is a multi-line heredoc string.
Variables are interpolated: 2 + 2 = @{[2 + 2]}
Useful for templates and long text blocks.

Regards,
Perl Script
END_MSG
print $message;

# Non-interpolating heredoc (like single quotes)
my $raw = <<'END_RAW';
This $variable is NOT interpolated.
Neither is this \n escape sequence.
END_RAW
print "Raw heredoc: $raw";

say "=== STRING FUNCTIONS ===";

my $str = "  Hello, Perl World!  ";

say "Original:  '$str'";
say "Length:     " . length($str);
say "Uppercase:  " . uc($str);
say "Lowercase:  " . lc($str);
say "ucfirst:    " . ucfirst("hello");
say "lcfirst:    " . lcfirst("HELLO");

say "\n=== SUBSTRING ===";

say "substr(str, 2, 5):  '" . substr($str, 2, 5) . "'";
say "substr(str, -8, 5): '" . substr($str, -8, 5) . "'";

my $mutable = "Hello World";
substr($mutable, 0, 5, "Goodbye");
say "After substr replace: $mutable";

say "\n=== SEARCHING IN STRINGS ===";

my $sentence = "The quick brown fox jumps over the lazy dog";

say "index 'fox':        " . index($sentence, "fox");         # 16
say "index 'cat':        " . index($sentence, "cat");         # -1 (not found)
say "rindex 'the':       " . rindex($sentence, "the");        # 31

say "\n=== SPLIT AND JOIN ===";

my $csv_line = "Alice,30,Engineer,New York";
my @fields = split(/,/, $csv_line);
say "Split CSV: " . join(" | ", @fields);

my @words = split(/\s+/, $sentence);
say "Word count: " . scalar @words;
say "Rejoined:   " . join("-", @words);

say "\n=== STRING REPETITION AND REVERSE ===";

say "Ha" x 5;
say reverse("desserts");    # "stressed"
say reverse("racecar");     # "racecar" — a palindrome!

say "\n=== CHOMP AND CHOP ===";

my $with_newline = "Hello\n";
chomp $with_newline;
say "After chomp: '$with_newline'";

my $chop_me = "Hello!";
my $removed = chop $chop_me;
say "After chop:  '$chop_me' (removed: '$removed')";

say "\n=== STRING INTERPOLATION TRICKS ===";

my @arr = (1, 2, 3);
say "Array in string: @arr";
say "Array joined: @{[join ', ', @arr]}";
say "Expression: @{[ 6 * 7 ]}";

my %hash = (key => "value");
say "Hash value: $hash{key}";

say "\n=== SPRINTF — Formatted Strings ===";

my $formatted = sprintf("Name: %-10s Age: %3d Score: %6.2f%%",
                        "Alice", 30, 95.5);
say $formatted;

printf "%-12s %5s %8s\n", "Product", "Qty", "Price";
printf "%-12s %5d %8.2f\n", "Widget", 42, 9.99;
printf "%-12s %5d %8.2f\n", "Gadget", 7, 149.95;
printf "%-12s %5d %8.2f\n", "Doohickey", 100, 0.50;

say "\n=== TR (TRANSLITERATE) ===";

my $text = "Hello, World! 123";
(my $vowelless = $text) =~ tr/aeiouAEIOU//d;
say "Remove vowels: $vowelless";

(my $rot13 = "Hello World") =~ tr/A-Za-z/N-ZA-Mn-za-m/;
say "ROT13 encode: $rot13";

(my $back = $rot13) =~ tr/A-Za-z/N-ZA-Mn-za-m/;
say "ROT13 decode: $back";

my $count_text = "Mississippi";
(my $copy = $count_text) =~ tr/s//;
my $s_count = ($count_text =~ tr/s//);
say "'$count_text' has $s_count letter 's'";
