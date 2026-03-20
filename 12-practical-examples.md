# Chapter 12: Practical Examples

This chapter presents complete, real-world Perl programs that tie together concepts from the entire tutorial. Each example is a standalone script you can run, study, and modify.

## Example 1: CSV Data Analyzer

A tool that reads CSV files, computes statistics, and generates reports.

```perl
#!/usr/bin/perl
# File: examples/csv_analyzer.pl
#
# Reads a CSV file and produces summary statistics for numeric columns.
# Usage: perl csv_analyzer.pl sales_data.csv

use strict;
use warnings;
use List::Util qw(sum min max);
use POSIX qw(ceil);

sub main {
    my $filename = $ARGV[0] or die "Usage: $0 <csv_file>\n";

    open(my $fh, "<", $filename) or die "Cannot open '$filename': $!\n";

    my $header_line = <$fh>;
    chomp $header_line;
    my @headers = split /,/, $header_line;

    my @rows;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/;
        my @fields = split /,/, $line;
        my %row;
        @row{@headers} = @fields;
        push @rows, \%row;
    }
    close $fh;

    printf "Loaded %d records with %d columns.\n\n", scalar @rows, scalar @headers;

    for my $col (@headers) {
        my @values = map { $_->{$col} } @rows;
        my @numeric = grep { /^-?\d+\.?\d*$/ } @values;

        if (@numeric == @values && @numeric > 0) {
            printf "Column: %s (numeric)\n", $col;
            printf "  Count:   %d\n",    scalar @numeric;
            printf "  Min:     %.2f\n",  min(@numeric);
            printf "  Max:     %.2f\n",  max(@numeric);
            printf "  Sum:     %.2f\n",  sum(@numeric);
            printf "  Mean:    %.2f\n",  sum(@numeric) / @numeric;
            printf "  Median:  %.2f\n",  median(@numeric);
            print "\n";
        } else {
            my %freq;
            $freq{$_}++ for @values;
            my @top = (sort { $freq{$b} <=> $freq{$a} } keys %freq)[0..min(4, scalar(keys %freq) - 1)];

            printf "Column: %s (categorical)\n", $col;
            printf "  Unique values: %d\n", scalar keys %freq;
            printf "  Top values:\n";
            for my $val (@top) {
                printf "    %-20s %d (%.1f%%)\n", $val, $freq{$val},
                       100 * $freq{$val} / scalar @rows;
            }
            print "\n";
        }
    }
}

sub median {
    my @sorted = sort { $a <=> $b } @_;
    my $n = scalar @sorted;
    if ($n % 2 == 0) {
        return ($sorted[$n/2 - 1] + $sorted[$n/2]) / 2;
    }
    return $sorted[int($n/2)];
}

main();
```

## Example 2: Log File Monitor

A real-time log monitoring tool that watches a log file for patterns and sends alerts.

```perl
#!/usr/bin/perl
# File: examples/log_monitor.pl
#
# Monitors a log file in real time and reports matching patterns.
# Usage: perl log_monitor.pl --file /var/log/syslog --pattern "error|fail|critical"

use strict;
use warnings;
use Getopt::Long;
use POSIX qw(strftime);

my $log_file    = '';
my $pattern     = 'error|fail|critical';
my $ignore_case = 1;
my $context     = 0;
my $summary_interval = 60;

GetOptions(
    'file=s'     => \$log_file,
    'pattern=s'  => \$pattern,
    'case!'      => \$ignore_case,
    'context=i'  => \$context,
    'interval=i' => \$summary_interval,
) or die "Usage: $0 --file FILE [--pattern REGEX] [--nocase] [--context N]\n";

die "Please specify --file\n" unless $log_file;

my $regex = $ignore_case ? qr/$pattern/i : qr/$pattern/;
my %stats;
my @recent_buffer;
my $last_summary = time();

open(my $fh, "<", $log_file) or die "Cannot open '$log_file': $!\n";

seek($fh, 0, 2);

print "Monitoring '$log_file' for pattern: /$pattern/", ($ignore_case ? "i" : ""), "\n";
print "Press Ctrl+C to stop.\n\n";

$SIG{INT} = sub {
    print_summary();
    exit 0;
};

while (1) {
    while (my $line = <$fh>) {
        chomp $line;
        push @recent_buffer, $line;
        shift @recent_buffer if @recent_buffer > 100;

        if ($line =~ $regex) {
            my $timestamp = strftime("%H:%M:%S", localtime);
            print "[$timestamp] MATCH: $line\n";

            while ($line =~ /($regex)/g) {
                $stats{lc $1}++;
            }
            $stats{_total}++;
        }
    }

    if (time() - $last_summary >= $summary_interval && $stats{_total}) {
        print_summary();
        $last_summary = time();
    }

    sleep 1;
    seek($fh, 0, 1);   # clear EOF
}

sub print_summary {
    return unless $stats{_total};

    print "\n--- Summary ---\n";
    printf "Total matches: %d\n", $stats{_total} // 0;

    for my $key (sort { $stats{$b} <=> $stats{$a} } grep { $_ ne '_total' } keys %stats) {
        printf "  %-30s %d\n", $key, $stats{$key};
    }
    print "---\n\n";
}
```

## Example 3: Web Scraper / API Client

A script that fetches data from a REST API, processes it, and generates a report.

```perl
#!/usr/bin/perl
# File: examples/api_client.pl
#
# Fetches data from the JSONPlaceholder API and generates a user activity report.
# Usage: perl api_client.pl

use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP;

my $base_url = "https://jsonplaceholder.typicode.com";
my $http = HTTP::Tiny->new(
    timeout    => 15,
    agent      => "PerlTutorial/1.0",
);

sub fetch_json {
    my ($endpoint) = @_;
    my $url = "$base_url$endpoint";
    my $response = $http->get($url);

    unless ($response->{success}) {
        die "HTTP $response->{status} fetching $url: $response->{reason}\n";
    }

    return decode_json($response->{content});
}

sub main {
    print "Fetching user data...\n";
    my $users = fetch_json("/users");
    my $posts = fetch_json("/posts");
    my $comments = fetch_json("/comments");

    my %posts_by_user;
    for my $post (@$posts) {
        push @{$posts_by_user{$post->{userId}}}, $post;
    }

    my %comments_by_post;
    for my $comment (@$comments) {
        push @{$comments_by_post{$comment->{postId}}}, $comment;
    }

    print "\n";
    print "=" x 70, "\n";
    print "               USER ACTIVITY REPORT\n";
    print "=" x 70, "\n\n";

    for my $user (sort { $a->{id} <=> $b->{id} } @$users) {
        my $user_posts = $posts_by_user{$user->{id}} // [];
        my $total_comments = 0;
        my $total_word_count = 0;

        for my $post (@$user_posts) {
            my $post_comments = $comments_by_post{$post->{id}} // [];
            $total_comments += scalar @$post_comments;
            $total_word_count += scalar split(/\s+/, $post->{body});
        }

        printf "User: %s (%s)\n", $user->{name}, $user->{email};
        printf "  Company:     %s\n", $user->{company}{name};
        printf "  City:        %s\n", $user->{address}{city};
        printf "  Posts:       %d\n", scalar @$user_posts;
        printf "  Comments:    %d (on their posts)\n", $total_comments;
        printf "  Total words: %d\n", $total_word_count;

        if (@$user_posts) {
            printf "  Avg words/post: %.0f\n", $total_word_count / @$user_posts;

            my $most_commented = (sort {
                scalar(@{$comments_by_post{$b->{id}} // []}) <=>
                scalar(@{$comments_by_post{$a->{id}} // []})
            } @$user_posts)[0];

            printf "  Most discussed: \"%s\" (%d comments)\n",
                   substr($most_commented->{title}, 0, 40),
                   scalar @{$comments_by_post{$most_commented->{id}} // []};
        }

        print "\n";
    }

    print "=" x 70, "\n";
    printf "Totals: %d users, %d posts, %d comments\n",
           scalar @$users, scalar @$posts, scalar @$comments;
    print "=" x 70, "\n";
}

main();
```

## Example 4: Text File Processor

A multi-purpose text processing tool with several modes.

```perl
#!/usr/bin/perl
# File: examples/text_processor.pl
#
# Swiss-army knife for text file processing.
# Usage: perl text_processor.pl <command> [options] <file>

use strict;
use warnings;
use Getopt::Long;

my %commands = (
    stats     => \&cmd_stats,
    frequency => \&cmd_frequency,
    dedupe    => \&cmd_dedupe,
    extract   => \&cmd_extract,
    transform => \&cmd_transform,
    help      => \&cmd_help,
);

sub main {
    my $command = shift @ARGV // "help";

    if (exists $commands{$command}) {
        $commands{$command}->();
    } else {
        print "Unknown command: $command\n";
        cmd_help();
        exit 1;
    }
}

sub cmd_help {
    print <<'HELP';
Text Processor - A multi-purpose text processing tool

Commands:
  stats      Show text statistics (lines, words, characters)
  frequency  Word frequency analysis
  dedupe     Remove duplicate lines
  extract    Extract patterns (emails, URLs, IPs, dates)
  transform  Transform text (upper, lower, title, reverse, sort)

Examples:
  perl text_processor.pl stats myfile.txt
  perl text_processor.pl frequency --top 20 myfile.txt
  perl text_processor.pl dedupe --output clean.txt myfile.txt
  perl text_processor.pl extract --type emails myfile.txt
  perl text_processor.pl transform --mode title myfile.txt
HELP
}

sub read_input {
    my $file = $ARGV[-1];
    my @lines;

    if ($file && -f $file) {
        open(my $fh, "<", $file) or die "Cannot open '$file': $!\n";
        @lines = <$fh>;
        close $fh;
    } else {
        @lines = <STDIN>;
    }

    chomp @lines;
    return @lines;
}

sub cmd_stats {
    my @lines = read_input();
    my $text = join("\n", @lines);

    my $line_count = scalar @lines;
    my @words = split(/\s+/, $text);
    my $word_count = scalar @words;
    my $char_count = length($text);
    my $char_no_space = $text =~ s/\s//gr;

    my @sentences = split(/[.!?]+/, $text);
    my $blank_lines = scalar grep { /^\s*$/ } @lines;

    my $longest_line = 0;
    my $longest_line_num = 0;
    for my $i (0..$#lines) {
        if (length($lines[$i]) > $longest_line) {
            $longest_line = length($lines[$i]);
            $longest_line_num = $i + 1;
        }
    }

    print "=== Text Statistics ===\n";
    printf "Lines:             %d\n", $line_count;
    printf "Blank lines:       %d\n", $blank_lines;
    printf "Words:             %d\n", $word_count;
    printf "Characters:        %d\n", $char_count;
    printf "Characters (no ws):%d\n", length($char_no_space);
    printf "Sentences:         %d\n", scalar @sentences;
    printf "Avg words/line:    %.1f\n", $line_count ? $word_count / $line_count : 0;
    printf "Avg word length:   %.1f\n", $word_count ? $char_count / $word_count : 0;
    printf "Longest line:      %d chars (line %d)\n", $longest_line, $longest_line_num;
}

sub cmd_frequency {
    my $top_n = 20;
    my $min_length = 1;
    GetOptions(
        'top=i'    => \$top_n,
        'min-len=i' => \$min_length,
    );

    my @lines = read_input();
    my %freq;

    for my $line (@lines) {
        for my $word (split /\s+/, lc $line) {
            $word =~ s/[^\w'-]//g;
            next unless length($word) >= $min_length;
            $freq{$word}++;
        }
    }

    my @sorted = sort { $freq{$b} <=> $freq{$a} } keys %freq;
    splice @sorted, $top_n if @sorted > $top_n;

    my $max_count = $freq{$sorted[0]} // 0;

    printf "\n%-4s %-20s %5s  %s\n", "#", "Word", "Count", "Bar";
    print "-" x 60, "\n";

    my $rank = 1;
    for my $word (@sorted) {
        my $bar_len = $max_count > 0 ? int(30 * $freq{$word} / $max_count) : 0;
        printf "%-4d %-20s %5d  %s\n", $rank++, $word, $freq{$word}, "#" x $bar_len;
    }
}

sub cmd_dedupe {
    my $output_file = '';
    GetOptions('output=s' => \$output_file);

    my @lines = read_input();
    my %seen;
    my @unique = grep { !$seen{$_}++ } @lines;

    my $removed = scalar @lines - scalar @unique;

    if ($output_file) {
        open(my $out, ">", $output_file) or die "Cannot open '$output_file': $!\n";
        print $out "$_\n" for @unique;
        close $out;
        printf "Wrote %d unique lines to '%s' (%d duplicates removed).\n",
               scalar @unique, $output_file, $removed;
    } else {
        print "$_\n" for @unique;
        printf STDERR "%d duplicates removed.\n", $removed if $removed;
    }
}

sub cmd_extract {
    my $type = 'emails';
    GetOptions('type=s' => \$type);

    my @lines = read_input();
    my $text = join("\n", @lines);

    my %patterns = (
        emails  => qr/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/,
        urls    => qr{https?://[^\s<>"]+},
        ips     => qr/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/,
        dates   => qr{\b\d{4}[-/]\d{2}[-/]\d{2}\b},
        phones  => qr{\b\d{3}[-.]?\d{3}[-.]?\d{4}\b},
    );

    my $pattern = $patterns{$type};
    die "Unknown type '$type'. Available: " . join(", ", sort keys %patterns) . "\n"
        unless $pattern;

    my @matches = ($text =~ /$pattern/g);
    my %unique;
    $unique{$_}++ for @matches;

    printf "Found %d %s (%d unique):\n\n", scalar @matches, $type, scalar keys %unique;

    for my $match (sort { $unique{$b} <=> $unique{$a} } keys %unique) {
        printf "  %-40s (%d)\n", $match, $unique{$match};
    }
}

sub cmd_transform {
    my $mode = 'upper';
    GetOptions('mode=s' => \$mode);

    my @lines = read_input();

    my %transforms = (
        upper   => sub { uc $_[0] },
        lower   => sub { lc $_[0] },
        title   => sub { $_[0] =~ s/\b(\w)/\u$1/gr },
        reverse => sub { scalar reverse $_[0] },
        sort    => sub { undef },
        squeeze => sub { $_[0] =~ s/\s+/ /gr =~ s/^\s+|\s+$//gr },
        number  => sub { undef },
    );

    die "Unknown mode '$mode'. Available: " . join(", ", sort keys %transforms) . "\n"
        unless exists $transforms{$mode};

    if ($mode eq 'sort') {
        print "$_\n" for sort @lines;
    } elsif ($mode eq 'number') {
        printf "%4d: %s\n", $_ + 1, $lines[$_] for 0..$#lines;
    } else {
        print $transforms{$mode}->($_), "\n" for @lines;
    }
}

main();
```

## Example 5: System Administration Toolkit

A collection of sysadmin utilities in one script.

```perl
#!/usr/bin/perl
# File: examples/sysadmin_toolkit.pl
#
# System administration toolkit with common utilities.
# Usage: perl sysadmin_toolkit.pl <command>

use strict;
use warnings;
use File::Find;
use File::Basename;
use POSIX qw(strftime);
use Cwd qw(abs_path);

my $command = shift @ARGV // "help";

my %commands = (
    diskusage    => \&cmd_diskusage,
    largefiles   => \&cmd_largefiles,
    oldfiles     => \&cmd_oldfiles,
    dupes        => \&cmd_dupes,
    permissions  => \&cmd_permissions,
    backup       => \&cmd_backup,
    help         => \&cmd_help,
);

if (exists $commands{$command}) {
    $commands{$command}->();
} else {
    print "Unknown command: $command\n\n";
    cmd_help();
}

sub cmd_help {
    print <<'HELP';
System Administration Toolkit

Commands:
  diskusage [dir]            Show directory sizes
  largefiles [dir] [min_mb]  Find files larger than min_mb (default: 100)
  oldfiles [dir] [days]      Find files not modified in N days (default: 90)
  dupes [dir]                Find duplicate files by size and checksum
  permissions [dir]          Find files with unusual permissions
  backup [source] [dest]     Create a timestamped backup

Examples:
  perl sysadmin_toolkit.pl diskusage /home
  perl sysadmin_toolkit.pl largefiles /var/log 50
  perl sysadmin_toolkit.pl oldfiles /tmp 30
  perl sysadmin_toolkit.pl backup /etc /backup
HELP
}

sub cmd_diskusage {
    my $dir = $ARGV[0] // ".";
    die "Directory '$dir' not found\n" unless -d $dir;

    my %dir_sizes;

    find(sub {
        return unless -f $_;
        my $size = -s $_;
        my $parent = $File::Find::dir;
        $dir_sizes{$parent} += $size;
    }, $dir);

    print "Directory sizes in: $dir\n\n";
    printf "%-50s %10s\n", "Directory", "Size";
    print "-" x 62, "\n";

    for my $d (sort { $dir_sizes{$b} <=> $dir_sizes{$a} } keys %dir_sizes) {
        printf "%-50s %10s\n", shorten_path($d, 50), format_size($dir_sizes{$d});
    }

    my $total = 0;
    $total += $_ for values %dir_sizes;
    print "-" x 62, "\n";
    printf "%-50s %10s\n", "TOTAL", format_size($total);
}

sub cmd_largefiles {
    my $dir = $ARGV[0] // ".";
    my $min_mb = $ARGV[1] // 100;
    my $min_bytes = $min_mb * 1024 * 1024;

    die "Directory '$dir' not found\n" unless -d $dir;

    print "Files larger than ${min_mb}MB in $dir:\n\n";
    printf "%-10s %-20s %s\n", "Size", "Modified", "Path";
    print "-" x 70, "\n";

    my @large;
    find(sub {
        return unless -f $_;
        my $size = -s $_;
        return unless $size >= $min_bytes;
        push @large, {
            path => $File::Find::name,
            size => $size,
            mtime => (stat($_))[9],
        };
    }, $dir);

    @large = sort { $b->{size} <=> $a->{size} } @large;

    for my $f (@large) {
        printf "%-10s %-20s %s\n",
               format_size($f->{size}),
               strftime("%Y-%m-%d %H:%M", localtime($f->{mtime})),
               $f->{path};
    }

    printf "\nFound %d files.\n", scalar @large;
}

sub cmd_oldfiles {
    my $dir = $ARGV[0] // ".";
    my $days = $ARGV[1] // 90;

    die "Directory '$dir' not found\n" unless -d $dir;

    my $cutoff = time() - ($days * 86400);

    print "Files not modified in $days days ($dir):\n\n";

    my @old;
    find(sub {
        return unless -f $_;
        my $mtime = (stat($_))[9];
        return unless $mtime < $cutoff;
        push @old, {
            path  => $File::Find::name,
            size  => -s $_,
            mtime => $mtime,
        };
    }, $dir);

    @old = sort { $a->{mtime} <=> $b->{mtime} } @old;

    for my $f (@old) {
        my $age = int((time() - $f->{mtime}) / 86400);
        printf "%4d days ago  %-10s  %s\n",
               $age, format_size($f->{size}), $f->{path};
    }

    my $total_size = 0;
    $total_size += $_->{size} for @old;
    printf "\nFound %d files totaling %s.\n", scalar @old, format_size($total_size);
}

sub cmd_dupes {
    my $dir = $ARGV[0] // ".";
    die "Directory '$dir' not found\n" unless -d $dir;

    require Digest::MD5;

    print "Scanning for duplicate files in $dir...\n\n";

    my %by_size;
    find(sub {
        return unless -f $_;
        my $size = -s $_;
        return if $size == 0;
        push @{$by_size{$size}}, $File::Find::name;
    }, $dir);

    my %by_hash;
    my $candidates = 0;

    for my $size (keys %by_size) {
        next unless @{$by_size{$size}} > 1;
        $candidates += @{$by_size{$size}};

        for my $file (@{$by_size{$size}}) {
            open(my $fh, "<:raw", $file) or next;
            my $md5 = Digest::MD5->new;
            $md5->addfile($fh);
            my $hash = $md5->hexdigest;
            close $fh;

            push @{$by_hash{$hash}}, { path => $file, size => $size };
        }
    }

    my $groups = 0;
    my $wasted = 0;

    for my $hash (sort keys %by_hash) {
        next unless @{$by_hash{$hash}} > 1;
        $groups++;
        my @files = @{$by_hash{$hash}};
        my $size = $files[0]->{size};
        $wasted += $size * (@files - 1);

        printf "Duplicates (size: %s, MD5: %s):\n", format_size($size), substr($hash, 0, 12);
        for my $f (@files) {
            print "  $f->{path}\n";
        }
        print "\n";
    }

    printf "Found %d groups of duplicates. Potential space savings: %s\n",
           $groups, format_size($wasted);
}

sub cmd_permissions {
    my $dir = $ARGV[0] // ".";
    die "Directory '$dir' not found\n" unless -d $dir;

    print "Files with unusual permissions in $dir:\n\n";

    my @issues;
    find(sub {
        return unless -f $_;
        my $mode = (stat($_))[2] & 07777;

        if ($mode & 0002) {
            push @issues, {
                path  => $File::Find::name,
                mode  => sprintf("%04o", $mode),
                issue => "World-writable",
            };
        }

        if ($mode & 04000) {
            push @issues, {
                path  => $File::Find::name,
                mode  => sprintf("%04o", $mode),
                issue => "SUID bit set",
            };
        }

        if ($mode & 02000) {
            push @issues, {
                path  => $File::Find::name,
                mode  => sprintf("%04o", $mode),
                issue => "SGID bit set",
            };
        }
    }, $dir);

    if (@issues) {
        printf "%-20s %-6s %s\n", "Issue", "Mode", "Path";
        print "-" x 70, "\n";
        for my $i (sort { $a->{issue} cmp $b->{issue} } @issues) {
            printf "%-20s %-6s %s\n", $i->{issue}, $i->{mode}, $i->{path};
        }
    } else {
        print "No unusual permissions found.\n";
    }
}

sub cmd_backup {
    my $source = $ARGV[0] // die "Usage: $0 backup <source> <destination>\n";
    my $dest   = $ARGV[1] // die "Usage: $0 backup <source> <destination>\n";

    die "Source '$source' not found\n" unless -e $source;
    mkdir $dest unless -d $dest;

    my $timestamp = strftime("%Y%m%d_%H%M%S", localtime);
    my $basename  = basename($source);
    my $backup_name = "${basename}_backup_${timestamp}.tar.gz";
    my $backup_path = "$dest/$backup_name";

    print "Creating backup: $backup_path\n";

    my $exit = system("tar", "czf", $backup_path, "-C", dirname($source), $basename);

    if ($exit == 0) {
        my $size = -s $backup_path;
        printf "Backup created successfully (%s)\n", format_size($size);
    } else {
        die "Backup failed with exit code: " . ($exit >> 8) . "\n";
    }
}

sub format_size {
    my ($bytes) = @_;
    my @units = ('B', 'KB', 'MB', 'GB', 'TB');
    my $unit = 0;
    my $size = $bytes;
    while ($size >= 1024 && $unit < $#units) {
        $size /= 1024;
        $unit++;
    }
    return sprintf("%.1f%s", $size, $units[$unit]);
}

sub shorten_path {
    my ($path, $max_len) = @_;
    return $path if length($path) <= $max_len;
    return "..." . substr($path, length($path) - $max_len + 3);
}
```

## Example 6: Template Engine

A simple but functional template engine.

```perl
#!/usr/bin/perl
# File: examples/template_engine.pl
#
# A lightweight template engine supporting variables, loops, and conditionals.

use strict;
use warnings;

package SimpleTemplate;

sub new {
    my ($class, %args) = @_;
    return bless {
        delimiters => $args{delimiters} // ['{{', '}}'],
    }, $class;
}

sub render {
    my ($self, $template, $data) = @_;
    my ($open, $close) = @{$self->{delimiters}};

    my $qo = quotemeta($open);
    my $qc = quotemeta($close);

    # Process loops: {{#each items}}...{{/each}}
    $template =~ s{
        $qo\#each\s+(\w+)$qc
        (.*?)
        $qo/each$qc
    }{
        $self->_process_loop($1, $2, $data)
    }gsex;

    # Process conditionals: {{#if condition}}...{{else}}...{{/if}}
    $template =~ s{
        $qo\#if\s+(\w+)$qc
        (.*?)
        (?:$qo\s*else\s*$qc(.*?))?
        $qo/if$qc
    }{
        $self->_process_if($1, $2, $3 // '', $data)
    }gsex;

    # Process variables: {{variable}}
    $template =~ s{$qo\s*(\w+(?:\.\w+)*)\s*$qc}{
        $self->_resolve($1, $data) // ''
    }ge;

    return $template;
}

sub _resolve {
    my ($self, $path, $data) = @_;
    my @parts = split /\./, $path;
    my $current = $data;

    for my $part (@parts) {
        if (ref $current eq 'HASH' && exists $current->{$part}) {
            $current = $current->{$part};
        } else {
            return undef;
        }
    }

    return $current;
}

sub _process_loop {
    my ($self, $var, $body, $data) = @_;
    my $items = $self->_resolve($var, $data);
    return '' unless ref $items eq 'ARRAY';

    my $output = '';
    for my $i (0..$#$items) {
        my $item = $items->[$i];
        my $item_data = ref $item eq 'HASH'
            ? { %$data, %$item, _index => $i, _number => $i + 1 }
            : { %$data, _item => $item, _index => $i, _number => $i + 1 };

        $output .= $self->render($body, $item_data);
    }

    return $output;
}

sub _process_if {
    my ($self, $var, $then_block, $else_block, $data) = @_;
    my $value = $self->_resolve($var, $data);

    if ($value) {
        return $self->render($then_block, $data);
    } else {
        return $self->render($else_block, $data);
    }
}

package main;

my $engine = SimpleTemplate->new();

my $template = <<'TEMPLATE';
<!DOCTYPE html>
<html>
<head><title>{{title}}</title></head>
<body>
  <h1>{{title}}</h1>
  <p>Generated by: {{author}}</p>

  {{#if show_intro}}
  <div class="intro">
    <p>Welcome to our product catalog!</p>
  </div>
  {{else}}
  <div class="intro">
    <p>Browse our products below.</p>
  </div>
  {{/if}}

  <h2>Products</h2>
  <table border="1">
    <tr><th>#</th><th>Name</th><th>Price</th><th>In Stock</th></tr>
    {{#each products}}
    <tr>
      <td>{{_number}}</td>
      <td>{{name}}</td>
      <td>${{price}}</td>
      <td>{{#if in_stock}}Yes{{else}}No{{/if}}</td>
    </tr>
    {{/each}}
  </table>

  <footer>
    <p>Contact: {{contact.email}}</p>
  </footer>
</body>
</html>
TEMPLATE

my $data = {
    title      => "Product Catalog",
    author     => "Perl Template Engine",
    show_intro => 1,
    products   => [
        { name => "Widget A",  price => "19.99", in_stock => 1 },
        { name => "Gadget B",  price => "49.99", in_stock => 1 },
        { name => "Gizmo C",   price => "29.99", in_stock => 0 },
        { name => "Doohickey", price => "9.99",  in_stock => 1 },
    ],
    contact => {
        email => "support\@example.com",
    },
};

my $html = $engine->render($template, $data);
print $html;
```

## Example 7: Interactive Data Converter

Converts between CSV, JSON, and formatted table output.

```perl
#!/usr/bin/perl
# File: examples/data_converter.pl
#
# Converts data between CSV, JSON, and formatted table output.
# Usage: perl data_converter.pl --from csv --to json input.csv

use strict;
use warnings;
use JSON::PP;
use Getopt::Long;

my $from_format = 'csv';
my $to_format   = 'table';
my $delimiter   = ',';
my $output_file = '';

GetOptions(
    'from=s'      => \$from_format,
    'to=s'        => \$to_format,
    'delimiter=s' => \$delimiter,
    'output=s'    => \$output_file,
) or die "Usage: $0 --from FORMAT --to FORMAT [--delimiter CHAR] [file]\n";

sub main {
    my @records = read_data($from_format);

    die "No data to convert.\n" unless @records;

    my $output = write_data($to_format, \@records);

    if ($output_file) {
        open(my $fh, ">", $output_file) or die "Cannot open '$output_file': $!\n";
        print $fh $output;
        close $fh;
        print "Written to $output_file\n";
    } else {
        print $output;
    }
}

sub read_data {
    my ($format) = @_;

    my $input = do { local $/; <STDIN> if !@ARGV || $ARGV[-1] eq '-'; };
    unless ($input) {
        my $file = $ARGV[-1] // die "No input file specified.\n";
        open(my $fh, "<", $file) or die "Cannot open '$file': $!\n";
        local $/;
        $input = <$fh>;
        close $fh;
    }

    if ($format eq 'csv') {
        return parse_csv($input);
    } elsif ($format eq 'json') {
        return parse_json($input);
    } else {
        die "Unknown input format: $format\n";
    }
}

sub parse_csv {
    my ($text) = @_;
    my @lines = split /\n/, $text;
    return () unless @lines;

    my @headers = split /\Q$delimiter\E/, shift @lines;
    s/^\s+|\s+$//g for @headers;

    my @records;
    for my $line (@lines) {
        next if $line =~ /^\s*$/;
        my @fields = split /\Q$delimiter\E/, $line;
        s/^\s+|\s+$//g for @fields;
        my %record;
        @record{@headers} = @fields;
        push @records, \%record;
    }

    return @records;
}

sub parse_json {
    my ($text) = @_;
    my $data = decode_json($text);
    return ref $data eq 'ARRAY' ? @$data : ($data);
}

sub write_data {
    my ($format, $records) = @_;

    if ($format eq 'csv') {
        return to_csv($records);
    } elsif ($format eq 'json') {
        return to_json_output($records);
    } elsif ($format eq 'table') {
        return to_table($records);
    } else {
        die "Unknown output format: $format\n";
    }
}

sub to_csv {
    my ($records) = @_;
    return '' unless @$records;

    my @headers = sort keys %{$records->[0]};
    my $output = join($delimiter, @headers) . "\n";

    for my $rec (@$records) {
        my @values = map { $rec->{$_} // '' } @headers;
        $output .= join($delimiter, @values) . "\n";
    }

    return $output;
}

sub to_json_output {
    my ($records) = @_;
    return JSON::PP->new->pretty->canonical->encode($records);
}

sub to_table {
    my ($records) = @_;
    return '' unless @$records;

    my @headers = sort keys %{$records->[0]};

    my %widths;
    for my $h (@headers) {
        $widths{$h} = length($h);
    }
    for my $rec (@$records) {
        for my $h (@headers) {
            my $len = length($rec->{$h} // '');
            $widths{$h} = $len if $len > $widths{$h};
        }
    }

    my $separator = "+-" . join("-+-", map { "-" x $widths{$_} } @headers) . "-+\n";

    my $output = $separator;
    $output .= "| " . join(" | ", map { sprintf("%-*s", $widths{$_}, $_) } @headers) . " |\n";
    $output .= $separator;

    for my $rec (@$records) {
        $output .= "| ";
        $output .= join(" | ", map { sprintf("%-*s", $widths{$_}, $rec->{$_} // '') } @headers);
        $output .= " |\n";
    }
    $output .= $separator;

    $output .= sprintf("(%d rows)\n", scalar @$records);
    return $output;
}

main();
```

## Summary

These practical examples demonstrate how Perl's features come together to solve real-world problems:

| Example | Key Concepts Used |
|---------|-------------------|
| CSV Analyzer | File I/O, hashes, arrays, statistics, formatted output |
| Log Monitor | File tailing, regex, signal handling, real-time processing |
| API Client | HTTP, JSON, data aggregation, formatted reports |
| Text Processor | Dispatch tables, regex, Getopt, multiple modes |
| Sysadmin Toolkit | File::Find, system commands, file tests, checksums |
| Template Engine | OOP, regex, recursion, nested data structures |
| Data Converter | Format parsing, JSON, formatted tables, modular design |

Each example is designed to be a starting point you can extend and adapt for your own projects.

---

**Previous**: [Chapter 11 — Advanced Topics](11-advanced-topics.md)
**Back to**: [Table of Contents](README.md)
