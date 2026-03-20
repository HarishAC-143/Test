#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- Practical Project: Simple Web Content Fetcher & HTML Parser ---
# Demonstrates text processing of HTML content using only core Perl features.
# No external modules required — works with raw HTML strings.

my $html = <<'END_HTML';
<!DOCTYPE html>
<html>
<head>
    <title>Perl Programming Resources</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>Learn Perl Programming</h1>

    <div class="intro">
        <p>Perl is a powerful, general-purpose programming language originally
        developed for text manipulation. Today it is used for system
        administration, web development, network programming, and more.</p>
    </div>

    <h2>Popular Perl Books</h2>
    <ul id="book-list">
        <li class="beginner">Learning Perl (the Llama Book) - $49.99</li>
        <li class="intermediate">Intermediate Perl (the Alpaca Book) - $39.99</li>
        <li class="advanced">Programming Perl (the Camel Book) - $59.99</li>
        <li class="beginner">Modern Perl - Free online</li>
        <li class="reference">Perl Cookbook - $44.99</li>
    </ul>

    <h2>Useful Links</h2>
    <div class="links">
        <a href="https://www.perl.org">Official Perl Website</a>
        <a href="https://metacpan.org">MetaCPAN - Perl Modules</a>
        <a href="https://perldoc.perl.org">Perl Documentation</a>
        <a href="https://learn.perl.org">Learn Perl</a>
        <a href="https://perlmonks.org">PerlMonks Community</a>
        <a href="https://www.cpan.org">CPAN</a>
    </div>

    <h2>Sample Code Snippets</h2>
    <pre><code>
    # Hello World
    print "Hello, World!\n";

    # File processing
    open(my $fh, '<', 'data.txt') or die $!;
    while (<$fh>) { chomp; print "Line: $_\n"; }
    close($fh);
    </code></pre>

    <table>
        <tr><th>Feature</th><th>Perl</th><th>Python</th><th>Ruby</th></tr>
        <tr><td>Regex</td><td>Excellent</td><td>Good</td><td>Good</td></tr>
        <tr><td>CPAN/PyPI/Gems</td><td>200K+</td><td>400K+</td><td>170K+</td></tr>
        <tr><td>One-liners</td><td>Excellent</td><td>Good</td><td>Good</td></tr>
        <tr><td>OOP</td><td>Flexible</td><td>Built-in</td><td>Built-in</td></tr>
    </table>

    <footer>
        <p>Last updated: 2026-03-20 | Contact: admin@example.com</p>
    </footer>
</body>
</html>
END_HTML

say "=" x 65;
say "           HTML CONTENT PARSER & ANALYZER";
say "=" x 65;

# --- Extract Title ---
say "\n--- Page Title ---";
if ($html =~ /<title>(.*?)<\/title>/s) {
    say "  $1";
}

# --- Extract All Headings ---
say "\n--- Headings ---";
while ($html =~ /<(h[1-6])[^>]*>(.*?)<\/\1>/gs) {
    my ($tag, $text) = ($1, $2);
    $text =~ s/<[^>]+>//g;
    printf "  <%s> %s\n", $tag, $text;
}

# --- Extract All Links ---
say "\n--- Links ---";
my @links;
while ($html =~ /<a\s+href="([^"]*)"[^>]*>(.*?)<\/a>/gs) {
    push @links, { url => $1, text => $2 };
}

for my $link (@links) {
    printf "  %-45s => %s\n", $link->{text}, $link->{url};
}
say "  Total links found: " . scalar @links;

# --- Extract List Items ---
say "\n--- Book List ---";
my @books;
while ($html =~ /<li\s+class="(\w+)">(.*?)<\/li>/gs) {
    push @books, { level => $1, title => $2 };
}

for my $book (@books) {
    printf "  [%-12s] %s\n", $book->{level}, $book->{title};
}

# --- Extract Prices ---
say "\n--- Prices Found ---";
my @prices;
while ($html =~ /\$(\d+\.\d{2})/g) {
    push @prices, $1;
}

my $total = 0;
for my $p (@prices) {
    printf "  \$%s\n", $p;
    $total += $p;
}
printf "  Total: \$%.2f\n", $total;
printf "  Average: \$%.2f\n", $total / scalar(@prices) if @prices;

# --- Extract Table Data ---
say "\n--- Table Data ---";
my @rows;
while ($html =~ /<tr>(.*?)<\/tr>/gs) {
    my $row = $1;
    my @cells;
    while ($row =~ /<t[hd]>(.*?)<\/t[hd]>/g) {
        push @cells, $1;
    }
    push @rows, \@cells if @cells;
}

if (@rows) {
    my $header = shift @rows;
    my @widths = map { length($_) + 2 } @$header;
    for my $row (@rows) {
        for my $i (0 .. $#$row) {
            $widths[$i] = length($row->[$i]) + 2
                if length($row->[$i]) + 2 > ($widths[$i] // 0);
        }
    }

    my $fmt = join(" | ", map { "%-${_}s" } @widths) . "\n";
    printf "  $fmt", @$header;
    printf "  %s\n", join("-+-", map { "-" x $_ } @widths);
    for my $row (@rows) {
        printf "  $fmt", @$row;
    }
}

# --- Extract Email Addresses ---
say "\n--- Email Addresses ---";
my @emails;
while ($html =~ /([\w.+-]+\@[\w.-]+\.\w{2,})/g) {
    push @emails, $1;
}
say "  $_" for @emails;

# --- Text Content (strip HTML tags) ---
say "\n--- Plain Text Content (first 300 chars) ---";
(my $plain = $html) =~ s/<[^>]+>//g;
$plain =~ s/\s+/ /g;
$plain =~ s/^\s+|\s+$//g;
my $preview = substr($plain, 0, 300);
say "  $preview...";

# --- HTML Statistics ---
say "\n--- HTML Statistics ---";
my %tag_count;
while ($html =~ /<(\w+)[\s>]/g) {
    $tag_count{lc($1)}++;
}

printf "  %-12s %s\n", "Tag", "Count";
printf "  %-12s %s\n", "-" x 10, "-" x 5;
for my $tag (sort { $tag_count{$b} <=> $tag_count{$a} } keys %tag_count) {
    printf "  %-12s %d\n", "<$tag>", $tag_count{$tag};
}

say "\n" . "=" x 65;
say "Parsing complete!";
