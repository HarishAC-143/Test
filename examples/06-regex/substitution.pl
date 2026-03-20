#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Regular Expression Substitution and Transliteration
# ============================================================

say "=== BASIC SUBSTITUTION (s///) ===";

my $str = "Hello, World!";
(my $modified = $str) =~ s/World/Perl/;
say "Original:  $str";
say "Modified:  $modified";

say "\n=== GLOBAL SUBSTITUTION (/g) ===";

my $text = "The cat sat on the mat with another cat";
(my $replaced = $text) =~ s/cat/dog/g;
say "Original: $text";
say "Global:   $replaced";

say "\n=== CASE-INSENSITIVE SUBSTITUTION (/gi) ===";

my $mixed = "Perl perl PERL pErL";
(my $unified = $mixed) =~ s/perl/Perl/gi;
say "Original: $mixed";
say "Unified:  $unified";

say "\n=== USING CAPTURE GROUPS IN REPLACEMENT ===";

my $name = "Smith, John";
(my $reversed = $name) =~ s/(\w+), (\w+)/$2 $1/;
say "Name: $name => $reversed";

my $date = "03/20/2026";
(my $iso_date = $date) =~ s|(\d{2})/(\d{2})/(\d{4})|$3-$1-$2|;
say "Date: $date => $iso_date";

say "\n=== EVALUATE REPLACEMENT (/e) ===";

my $prices = "Widget costs 10 dollars and Gadget costs 25 dollars";
(my $doubled = $prices) =~ s/(\d+)/$1 * 2/ge;
say "Original: $prices";
say "Doubled:  $doubled";

my $template = "Hello, {NAME}! You have {COUNT} messages.";
my %vars = (NAME => "Alice", COUNT => 42);
(my $filled = $template) =~ s/\{(\w+)\}/$vars{$1} \/\/ "UNKNOWN"/ge;
say "\nTemplate: $template";
say "Filled:   $filled";

say "\n=== COMMON TEXT TRANSFORMATIONS ===";

my $messy = "  Hello,   World!   Too   many   spaces.  ";

(my $trimmed = $messy) =~ s/^\s+|\s+$//g;
say "Trimmed:          '$trimmed'";

(my $single_spaced = $trimmed) =~ s/\s+/ /g;
say "Single-spaced:    '$single_spaced'";

my $camelCase = "myVariableName";
(my $snake_case = $camelCase) =~ s/([A-Z])/_\L$1/g;
say "camelToSnake:     $camelCase => $snake_case";

my $snake = "my_variable_name";
(my $camel = $snake) =~ s/_(\w)/\U$1/g;
say "snakeToCamel:     $snake => $camel";

say "\n=== TRANSLITERATION (tr///) ===";

my $original = "Hello, World!";

(my $upper = $original) =~ tr/a-z/A-Z/;
say "Uppercase:   $upper";

(my $lower = $original) =~ tr/A-Z/a-z/;
say "Lowercase:   $lower";

(my $rot13 = $original) =~ tr/A-Za-z/N-ZA-Mn-za-m/;
say "ROT13:       $rot13";

(my $back = $rot13) =~ tr/A-Za-z/N-ZA-Mn-za-m/;
say "ROT13 back:  $back";

my $count_vowels = ($original =~ tr/aeiouAEIOU//);
say "Vowel count: $count_vowels";

(my $no_vowels = $original) =~ tr/aeiouAEIOU//d;
say "No vowels:   $no_vowels";

(my $squeezed = "aaabbbcccdddeee") =~ tr/a-e/a-e/s;
say "Squeezed:    $squeezed";

say "\n=== PRACTICAL: CLEAN AND NORMALIZE DATA ===";

my @raw_data = (
    "  John   Doe  ",
    "JANE    SMITH",
    "  bob jones  ",
    "Alice   WONDERLAND",
);

say "Cleaned names:";
for my $entry (@raw_data) {
    my $clean = $entry;
    $clean =~ s/^\s+|\s+$//g;     # Trim
    $clean =~ s/\s+/ /g;           # Normalize spaces
    $clean =~ s/(\w+)/\u\L$1/g;   # Title case
    printf "  '%-25s' => '%s'\n", $entry, $clean;
}

say "\n=== PRACTICAL: SANITIZE HTML ===";

my $html = '<p>Hello <script>alert("xss")</script> World</p>';
(my $safe = $html) =~ s/<script[^>]*>.*?<\/script>//gi;
say "Original: $html";
say "Cleaned:  $safe";

$safe =~ s/</&lt;/g;
$safe =~ s/>/&gt;/g;
say "Escaped:  $safe";

say "\n--- Substitution demo complete ---";
