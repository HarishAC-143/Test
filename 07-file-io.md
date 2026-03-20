# Chapter 7: File I/O

File input/output is one of Perl's core strengths. Perl provides simple yet powerful mechanisms for reading, writing, and manipulating files.

## Opening Files

Use the three-argument form of `open()` — it is the safest and most modern approach.

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Read mode
open(my $fh_read, "<", "input.txt")
    or die "Cannot open input.txt: $!\n";

# Write mode (creates or truncates)
open(my $fh_write, ">", "output.txt")
    or die "Cannot open output.txt: $!\n";

# Append mode
open(my $fh_append, ">>", "log.txt")
    or die "Cannot open log.txt: $!\n";

# Read+Write mode
open(my $fh_rw, "+<", "data.txt")
    or die "Cannot open data.txt: $!\n";

# Always close filehandles when done
close $fh_read;
close $fh_write;
close $fh_append;
close $fh_rw;
```

> **Best Practice**: Always use lexical filehandles (`my $fh`) and the three-argument `open`. The older `open(FH, "file.txt")` style uses global bareword filehandles and is error-prone.

## Reading Files

### Line by Line (Most Common)

```perl
open(my $fh, "<", "data.txt") or die "Cannot open: $!\n";

while (my $line = <$fh>) {
    chomp $line;               # remove trailing newline
    print "Line $.: $line\n";  # $. is the current line number
}

close $fh;
```

### Entire File into an Array

```perl
open(my $fh, "<", "data.txt") or die "Cannot open: $!\n";
my @lines = <$fh>;
close $fh;

chomp @lines;   # chomp all elements at once
print "File has ", scalar @lines, " lines\n";
```

### Entire File into a Scalar (Slurp)

```perl
# Method 1: Localize the record separator
my $content;
{
    open(my $fh, "<", "data.txt") or die "Cannot open: $!\n";
    local $/;                   # unset record separator
    $content = <$fh>;           # reads entire file
    close $fh;
}

# Method 2: Using File::Slurp (install from CPAN)
# use File::Slurp;
# my $content = read_file("data.txt");

# Method 3: Using Path::Tiny (modern, recommended)
# use Path::Tiny;
# my $content = path("data.txt")->slurp_utf8;
```

## Writing Files

```perl
# Writing text
open(my $fh, ">", "output.txt") or die "Cannot open: $!\n";

print $fh "First line\n";
print $fh "Second line\n";
printf $fh "Formatted: %s is %d years old\n", "Alice", 30;

close $fh;

# Appending text
open(my $log, ">>", "app.log") or die "Cannot open: $!\n";

my $timestamp = localtime();
print $log "[$timestamp] Application started\n";

close $log;

# Writing an array to a file
my @data = ("apple", "banana", "cherry");
open(my $out, ">", "fruits.txt") or die "Cannot open: $!\n";
print $out "$_\n" for @data;
close $out;
```

## File Testing

Perl provides file test operators to check file properties.

| Operator | Tests |
|----------|-------|
| `-e` | File exists |
| `-f` | Is a plain file |
| `-d` | Is a directory |
| `-r` | Is readable |
| `-w` | Is writable |
| `-x` | Is executable |
| `-z` | File is zero size (empty) |
| `-s` | File size in bytes |
| `-M` | Age of file in days (since modification) |
| `-A` | Age of file in days (since last access) |

```perl
my $file = "data.txt";

if (-e $file) {
    print "$file exists\n";
    print "Size: ", -s $file, " bytes\n";
    print "Modified ", -M $file, " days ago\n";
    print "Readable\n"   if -r $file;
    print "Writable\n"   if -w $file;
    print "Executable\n" if -x $file;
    print "Is a file\n"  if -f $file;
} else {
    print "$file does not exist\n";
}

# Stacked file tests (Perl 5.10+)
if (-f -r -w $file) {
    print "$file is a readable, writable file\n";
}
```

## Working with Directories

```perl
use File::Spec;
use File::Basename;
use Cwd;

# Get current working directory
my $cwd = getcwd();
print "Current directory: $cwd\n";

# Reading directory contents
opendir(my $dh, ".") or die "Cannot open directory: $!\n";
my @entries = readdir($dh);
closedir $dh;

# Filter out . and ..
my @files = grep { $_ ne '.' && $_ ne '..' } @entries;
print "Files: @files\n";

# List only .txt files
my @txt_files = grep { /\.txt$/ } @files;

# Create / remove directories
mkdir("new_dir", 0755) or die "Cannot mkdir: $!\n" unless -d "new_dir";
rmdir("empty_dir") or warn "Cannot rmdir: $!\n";

# Path manipulation
my $path = "/home/user/documents/report.txt";
print "Directory: ", dirname($path), "\n";     # /home/user/documents
print "Filename:  ", basename($path), "\n";    # report.txt
print "Base name: ", basename($path, ".txt"), "\n";   # report

# Portable path construction
my $full_path = File::Spec->catfile("home", "user", "file.txt");
print "Path: $full_path\n";
```

## Recursive File Processing

### Using File::Find

```perl
use File::Find;

my @perl_files;

find(sub {
    push @perl_files, $File::Find::name if /\.pl$/ || /\.pm$/;
}, "/path/to/project");

print "Found ", scalar @perl_files, " Perl files:\n";
print "  $_\n" for @perl_files;
```

### Using Path::Tiny (Modern Approach)

```perl
# use Path::Tiny;
#
# my $dir = path("/path/to/project");
# my @perl_files = $dir->children(qr/\.pl$/);
#
# # Recursive iterator
# my $iter = $dir->iterator({ recurse => 1 });
# while (my $path = $iter->()) {
#     next unless $path =~ /\.pm$/;
#     print "$path\n";
# }
```

## Binary File I/O

```perl
# Reading binary data
open(my $bin_in, "<:raw", "image.png") or die "Cannot open: $!\n";
my $data;
read($bin_in, $data, -s "image.png");
close $bin_in;

print "Read ", length($data), " bytes\n";

# Writing binary data
open(my $bin_out, ">:raw", "copy.png") or die "Cannot open: $!\n";
print $bin_out $data;
close $bin_out;

# Using binmode on an existing handle
open(my $fh, "<", "data.bin") or die "Cannot open: $!\n";
binmode($fh);
# ... read binary data ...
close $fh;
```

## Encoding and UTF-8

```perl
# Open with UTF-8 encoding
open(my $fh, "<:encoding(UTF-8)", "unicode.txt")
    or die "Cannot open: $!\n";

while (my $line = <$fh>) {
    chomp $line;
    print "Line: $line\n";
}
close $fh;

# Write UTF-8
open(my $out, ">:encoding(UTF-8)", "output_utf8.txt")
    or die "Cannot open: $!\n";
print $out "Hello in Japanese: こんにちは\n";
close $out;

# Set UTF-8 for all standard handles
use open qw(:std :utf8);

# Or set it globally with a pragma
# use utf8;          # source code is UTF-8
# use open ':utf8';  # default I/O layer
```

## Temporary Files

```perl
use File::Temp qw(tempfile tempdir);

# Create a temporary file
my ($fh, $filename) = tempfile(
    "myapp_XXXX",       # template (X's are replaced with random chars)
    DIR    => "/tmp",
    SUFFIX => ".tmp",
    UNLINK => 1,         # automatically delete when $fh goes out of scope
);

print $fh "Temporary data\n";
print "Temp file: $filename\n";
close $fh;

# Create a temporary directory
my $tmpdir = tempdir("myapp_XXXX", TMPDIR => 1, CLEANUP => 1);
print "Temp dir: $tmpdir\n";
```

## Practical Example: File Search Utility

```perl
#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use File::Basename;
use Getopt::Long;

my $pattern   = '';
my $directory = '.';
my $extension = '';
my $ignore_case = 0;

GetOptions(
    'pattern=s'   => \$pattern,
    'dir=s'       => \$directory,
    'ext=s'       => \$extension,
    'ignore-case' => \$ignore_case,
) or die "Usage: $0 --pattern REGEX [--dir DIR] [--ext EXT] [--ignore-case]\n";

die "Please specify --pattern\n" unless $pattern;

my $regex = $ignore_case ? qr/$pattern/i : qr/$pattern/;
my $total_matches = 0;
my $files_matched = 0;

find(\&search_file, $directory);

sub search_file {
    return unless -f $_;
    return if $extension && $_ !~ /\.\Q$extension\E$/;

    my $filepath = $File::Find::name;

    open(my $fh, "<", $_) or do {
        warn "Cannot open $filepath: $!\n";
        return;
    };

    my $file_has_match = 0;
    while (my $line = <$fh>) {
        if ($line =~ $regex) {
            unless ($file_has_match) {
                print "\n--- $filepath ---\n";
                $file_has_match = 1;
                $files_matched++;
            }
            chomp $line;
            printf "%4d: %s\n", $., $line;
            $total_matches++;
        }
    }

    close $fh;
}

print "\n$total_matches matches in $files_matched files.\n";
```

## Chapter Summary

- Use three-argument `open()` with lexical filehandles for safe file operations.
- Read files line by line in a `while` loop for memory efficiency; slurp for small files.
- File test operators (`-e`, `-f`, `-r`, `-s`, etc.) check file properties concisely.
- Use `File::Find` for recursive directory traversal.
- Handle encoding explicitly with `:encoding(UTF-8)` for internationalized text.
- Use `File::Temp` for secure temporary file creation.

---

**Previous**: [Chapter 6 — References and Data Structures](06-references-and-data-structures.md)
**Next**: [Chapter 8 — Modules and CPAN](08-modules-and-cpan.md)
