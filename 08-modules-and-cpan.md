# Chapter 8: Modules and CPAN

Modules are Perl's system for code organization and reuse. CPAN (Comprehensive Perl Archive Network) is one of the largest repositories of open-source libraries in any language.

## Using Modules

### Core Modules (Included with Perl)

```perl
#!/usr/bin/perl
use strict;
use warnings;

# List module — utility functions for lists
use List::Util qw(sum min max reduce any all);

my @nums = (4, 7, 2, 9, 1, 8);
print "Sum: ", sum(@nums), "\n";      # 31
print "Min: ", min(@nums), "\n";      # 1
print "Max: ", max(@nums), "\n";      # 9

# Check conditions
print "Has evens: ", (any { $_ % 2 == 0 } @nums) ? "yes" : "no", "\n";
print "All positive: ", (all { $_ > 0 } @nums) ? "yes" : "no", "\n";

# File::Path — create/remove directory trees
use File::Path qw(make_path remove_tree);
# make_path("path/to/deep/dir");

# File::Copy — copy and move files
use File::Copy qw(copy move);
# copy("source.txt", "dest.txt") or die "Copy failed: $!";
# move("old.txt", "new.txt") or die "Move failed: $!";

# POSIX — POSIX functions
use POSIX qw(strftime floor ceil);
print "Date: ", strftime("%Y-%m-%d %H:%M:%S", localtime), "\n";
print "Floor 3.7: ", floor(3.7), "\n";   # 3
print "Ceil 3.2: ", ceil(3.2), "\n";     # 4

# Getopt::Long — parse command-line options
use Getopt::Long;
# GetOptions("verbose" => \$verbose, "output=s" => \$output_file);

# Storable — serialize/deserialize Perl data structures
use Storable qw(freeze thaw store retrieve);
my $data = { name => "Alice", scores => [95, 87, 92] };
my $frozen = freeze($data);
my $thawed = thaw($frozen);
print "Name: $thawed->{name}\n";

# JSON::PP — JSON encoding/decoding (core since 5.14)
use JSON::PP;
my $json = encode_json({ name => "Bob", age => 25 });
print "JSON: $json\n";
my $decoded = decode_json($json);
print "Name from JSON: $decoded->{name}\n";
```

### Useful Core Modules Reference

| Module | Purpose |
|--------|---------|
| `List::Util` | List utility functions (sum, min, max, etc.) |
| `Scalar::Util` | Scalar utilities (blessed, reftype, weaken) |
| `File::Basename` | Parse file paths |
| `File::Spec` | Portable file path operations |
| `File::Path` | Create/remove directory trees |
| `File::Copy` | Copy and move files |
| `File::Temp` | Create temporary files and directories |
| `File::Find` | Recursive directory traversal |
| `Getopt::Long` | Command-line option parsing |
| `Storable` | Serialize Perl data structures |
| `JSON::PP` | JSON encoding/decoding |
| `POSIX` | POSIX functions and constants |
| `Cwd` | Get current working directory |
| `Digest::MD5` | MD5 hashing |
| `Digest::SHA` | SHA hashing |
| `Time::Piece` | Object-oriented time handling |
| `HTTP::Tiny` | Simple HTTP client |

## Creating Your Own Modules

### Module Structure

Create a file `MathHelper.pm`:

```perl
package MathHelper;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(factorial fibonacci is_prime);

sub factorial {
    my ($n) = @_;
    return 1 if $n <= 1;
    return $n * factorial($n - 1);
}

sub fibonacci {
    my ($n) = @_;
    my @fib = (0, 1);
    for my $i (2..$n) {
        $fib[$i] = $fib[$i-1] + $fib[$i-2];
    }
    return @fib[0..$n];
}

sub is_prime {
    my ($n) = @_;
    return 0 if $n < 2;
    return 1 if $n < 4;
    return 0 if $n % 2 == 0;
    for (my $i = 3; $i * $i <= $n; $i += 2) {
        return 0 if $n % $i == 0;
    }
    return 1;
}

1;   # modules must return a true value
```

### Using Your Module

```perl
#!/usr/bin/perl
use strict;
use warnings;
use lib '.';   # add current directory to module search path
use MathHelper qw(factorial fibonacci is_prime);

print "5! = ", factorial(5), "\n";           # 120
print "10! = ", factorial(10), "\n";         # 3628800

my @fib = fibonacci(10);
print "Fibonacci: @fib\n";                   # 0 1 1 2 3 5 8 13 21 34 55

for my $n (1..20) {
    print "$n " if is_prime($n);
}
print "\n";   # 2 3 5 7 11 13 17 19
```

### Module with OO Interface

```perl
package Logger;

use strict;
use warnings;
use POSIX qw(strftime);

sub new {
    my ($class, %args) = @_;
    my $self = {
        level    => $args{level}    // "info",
        output   => $args{output}   // \*STDERR,
        prefix   => $args{prefix}   // "",
    };
    return bless $self, $class;
}

my %levels = (debug => 0, info => 1, warn => 2, error => 3, fatal => 4);

sub _should_log {
    my ($self, $level) = @_;
    return ($levels{$level} // 0) >= ($levels{$self->{level}} // 0);
}

sub _log {
    my ($self, $level, $message) = @_;
    return unless $self->_should_log($level);

    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $prefix = $self->{prefix} ? "[$self->{prefix}] " : "";
    my $output = $self->{output};

    printf $output "[%s] [%-5s] %s%s\n", $timestamp, uc($level), $prefix, $message;
}

sub debug { $_[0]->_log("debug", $_[1]) }
sub info  { $_[0]->_log("info",  $_[1]) }
sub warn  { $_[0]->_log("warn",  $_[1]) }
sub error { $_[0]->_log("error", $_[1]) }
sub fatal { $_[0]->_log("fatal", $_[1]) }

1;
```

Usage:

```perl
use lib '.';
use Logger;

my $log = Logger->new(level => "info", prefix => "MyApp");
$log->debug("This won't print (below info level)");
$log->info("Application started");
$log->warn("Disk usage at 85%");
$log->error("Connection refused");
```

## The Exporter Module

`Exporter` controls which symbols a module makes available to its callers.

```perl
package MyUtils;
use strict;
use warnings;
use Exporter qw(import);

# Symbols exported by default (use MyUtils;)
our @EXPORT = qw(hello);

# Symbols available on request (use MyUtils qw(goodbye);)
our @EXPORT_OK = qw(goodbye greet_all);

# Export tags for groups of symbols
our %EXPORT_TAGS = (
    all      => [@EXPORT, @EXPORT_OK],
    greetings => [qw(hello goodbye)],
);

sub hello     { print "Hello!\n" }
sub goodbye   { print "Goodbye!\n" }
sub greet_all { hello(); goodbye(); }

1;

# Usage:
# use MyUtils;                           # imports hello()
# use MyUtils qw(goodbye);              # imports only goodbye()
# use MyUtils qw(:greetings);           # imports hello() and goodbye()
# use MyUtils qw(:all);                 # imports everything
```

## CPAN — The Comprehensive Perl Archive Network

CPAN is the Perl community's central module repository, hosting over 200,000 modules.

### Installing Modules

```bash
# Using cpanm (recommended — install it first if needed)
curl -L https://cpanmin.us | perl - App::cpanminus
cpanm Moo
cpanm JSON::XS
cpanm DBI

# Using the built-in cpan client
cpan install Moo

# On Debian/Ubuntu, many modules are also available as system packages
sudo apt-get install libmoo-perl
```

### Popular CPAN Modules

| Module | Purpose |
|--------|---------|
| `Moo` / `Moose` | Modern object-oriented frameworks |
| `DBI` | Database interface |
| `DBD::SQLite` / `DBD::Pg` / `DBD::mysql` | Database drivers |
| `JSON::XS` | Fast JSON encoding/decoding |
| `YAML::XS` | YAML parsing |
| `LWP::UserAgent` | Full-featured HTTP client |
| `Mojo::UserAgent` | Modern HTTP client (async capable) |
| `Template` | Template Toolkit for templating |
| `DateTime` | Date/time manipulation |
| `Try::Tiny` | Exception handling |
| `Path::Tiny` | Modern file path handling |
| `Log::Any` | Universal logging framework |
| `Test::More` | Testing framework |
| `Plack` / `Mojolicious` / `Dancer2` | Web frameworks |

### Using Popular CPAN Modules

```perl
# Try::Tiny — clean exception handling
use Try::Tiny;

try {
    die "Something went wrong!";
} catch {
    print "Caught error: $_\n";
} finally {
    print "This always runs\n";
};

# Path::Tiny — modern file operations
# use Path::Tiny;
# my $file = path("data.txt");
# my $content = $file->slurp_utf8;
# $file->spew_utf8("new content\n");
# my @lines = $file->lines_utf8({ chomp => 1 });

# HTTP::Tiny — simple HTTP requests (core module)
use HTTP::Tiny;
my $response = HTTP::Tiny->new->get('https://httpbin.org/get');
if ($response->{success}) {
    print "Status: $response->{status}\n";
    print "Body: $response->{content}\n";
}
```

## Module Search Path

Perl looks for modules in directories listed in `@INC`:

```perl
# Print the module search path
print join("\n", @INC), "\n";

# Add directories to the search path
use lib '/path/to/my/modules';
use lib './lib';

# Or via command line
# perl -I/path/to/modules script.pl

# Or via environment variable
# export PERL5LIB=/path/to/modules
```

## Practical Example: Building a Complete Module

File structure:

```
lib/
  TextAnalyzer.pm
scripts/
  analyze.pl
```

`lib/TextAnalyzer.pm`:

```perl
package TextAnalyzer;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(word_count char_count word_frequency readability_score);

sub word_count {
    my ($text) = @_;
    my @words = split /\s+/, $text;
    return scalar @words;
}

sub char_count {
    my ($text, %opts) = @_;
    if ($opts{exclude_spaces}) {
        $text =~ s/\s//g;
    }
    return length $text;
}

sub word_frequency {
    my ($text, %opts) = @_;
    my $top_n = $opts{top} // 10;
    my %freq;

    for my $word (split /\s+/, lc $text) {
        $word =~ s/[^\w']//g;
        next unless $word;
        $freq{$word}++;
    }

    my @sorted = sort { $freq{$b} <=> $freq{$a} } keys %freq;
    splice @sorted, $top_n if @sorted > $top_n;

    my %result;
    $result{$_} = $freq{$_} for @sorted;
    return \%result;
}

sub readability_score {
    my ($text) = @_;

    my @words = split /\s+/, $text;
    my @sentences = split /[.!?]+/, $text;
    my $syllables = 0;

    for my $word (@words) {
        $syllables += _count_syllables($word);
    }

    my $word_count = scalar @words || 1;
    my $sent_count = scalar @sentences || 1;

    my $score = 206.835
              - 1.015 * ($word_count / $sent_count)
              - 84.6  * ($syllables / $word_count);

    return sprintf("%.1f", $score);
}

sub _count_syllables {
    my ($word) = @_;
    $word = lc $word;
    $word =~ s/[^a-z]//g;
    return 1 unless $word;

    $word =~ s/e$//;
    my @vowel_groups = ($word =~ /[aeiouy]+/g);
    my $count = scalar @vowel_groups;
    return $count || 1;
}

1;

__END__

=head1 NAME

TextAnalyzer - Analyze text for various statistics

=head1 SYNOPSIS

    use TextAnalyzer qw(word_count word_frequency readability_score);

    my $text = "Some text to analyze...";
    print "Words: ", word_count($text), "\n";

=head1 DESCRIPTION

TextAnalyzer provides functions for analyzing text content including
word counting, character counting, word frequency analysis, and
readability scoring.

=head1 FUNCTIONS

=head2 word_count($text)

Returns the number of words in the text.

=head2 char_count($text, %options)

Returns the character count. Pass C<exclude_spaces =E<gt> 1> to exclude spaces.

=head2 word_frequency($text, %options)

Returns a hash reference of word frequencies. Pass C<top =E<gt> N> to limit results.

=head2 readability_score($text)

Returns the Flesch Reading Ease score (0-100, higher = easier to read).

=cut
```

## Chapter Summary

- Perl modules use `package` to define a namespace and must end with `1;`.
- Use `Exporter` to control which functions a module makes available.
- Perl ships with many powerful core modules — check them before reaching for CPAN.
- CPAN provides over 200,000 third-party modules; `cpanm` is the preferred installer.
- Add directories to `@INC` with `use lib` to find your own modules.
- Include POD documentation in your modules with `=head1`, `=head2`, etc.

---

**Previous**: [Chapter 7 — File I/O](07-file-io.md)
**Next**: [Chapter 9 — Object-Oriented Perl](09-object-oriented-perl.md)
