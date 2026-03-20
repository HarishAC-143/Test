#!/usr/bin/perl
# 11_file_dedup.pl — Practical example: Find duplicate files by content
#
# Demonstrates: file I/O, hashes, directory traversal, checksums, reporting
# This script creates sample files, then finds duplicates by comparing MD5 checksums.
use strict;
use warnings;
use feature 'say';
use File::Temp qw(tempdir);
use File::Spec;
use File::Find;
use Digest::MD5;

say "=" x 60;
say "  Practical Example: File Duplicate Finder";
say "=" x 60;

# --- Set up test files ---
my $testdir = tempdir(CLEANUP => 1);
say "Working in: $testdir\n";

my %file_contents = (
    "report_v1.txt"   => "Quarterly report data with analysis\nRevenue: \$1.2M\n",
    "report_copy.txt" => "Quarterly report data with analysis\nRevenue: \$1.2M\n",
    "notes.txt"       => "Meeting notes from Tuesday\nAction items listed below\n",
    "notes_backup.txt"=> "Meeting notes from Tuesday\nAction items listed below\n",
    "readme.md"       => "# Project Readme\nThis is the main project.\n",
    "config.ini"      => "[database]\nhost=localhost\nport=5432\n",
    "config_old.ini"  => "[database]\nhost=localhost\nport=5432\n",
    "unique.txt"      => "This file has unique content that appears nowhere else.\n",
    "data.csv"        => "id,name,value\n1,alpha,100\n2,beta,200\n",
    "data_copy.csv"   => "id,name,value\n1,alpha,100\n2,beta,200\n",
    "empty1.txt"      => "",
    "empty2.txt"      => "",
);

# Create subdirectories for realistic structure
my $subdir1 = File::Spec->catdir($testdir, "docs");
my $subdir2 = File::Spec->catdir($testdir, "backups");
mkdir $subdir1;
mkdir $subdir2;

my @dirs = ($testdir, $subdir1, $subdir2);
my $file_idx = 0;

for my $filename (sort keys %file_contents) {
    my $dir = $dirs[$file_idx % scalar(@dirs)];
    my $filepath = File::Spec->catfile($dir, $filename);
    open(my $fh, '>', $filepath) or die "Cannot create $filepath: $!\n";
    print $fh $file_contents{$filename};
    close($fh);
    $file_idx++;
}

# --- Scan directory tree and compute checksums ---
say "Scanning directory tree...\n";

my %files_by_size;
my %files_by_hash;
my $total_files = 0;
my $total_size  = 0;

find(sub {
    return unless -f $_;
    my $path = $File::Find::name;
    my $size = -s $path;
    $total_files++;
    $total_size += $size;
    push @{$files_by_size{$size}}, $path;
}, $testdir);

say "--- Scan Results ---";
say "Total files found: $total_files";
printf "Total size:        %d bytes\n", $total_size;

# Only compute checksums for files with matching sizes (optimization)
my $checksums_computed = 0;
for my $size (keys %files_by_size) {
    my @files = @{$files_by_size{$size}};
    next if @files < 2;

    for my $file (@files) {
        open(my $fh, '<', $file) or next;
        binmode $fh;
        my $md5 = Digest::MD5->new->addfile($fh)->hexdigest;
        close($fh);
        push @{$files_by_hash{$md5}}, $file;
        $checksums_computed++;
    }
}

say "Checksums computed: $checksums_computed (only for size-matching files)";

# --- Report duplicates ---
my @duplicate_groups;
my $wasted_space = 0;

for my $hash (sort keys %files_by_hash) {
    my @files = @{$files_by_hash{$hash}};
    next if @files < 2;

    my $file_size = -s $files[0];
    my $wasted = $file_size * (scalar(@files) - 1);
    $wasted_space += $wasted;

    push @duplicate_groups, {
        hash   => $hash,
        size   => $file_size,
        count  => scalar @files,
        wasted => $wasted,
        files  => \@files,
    };
}

@duplicate_groups = sort { $b->{wasted} <=> $a->{wasted} } @duplicate_groups;

say "\n--- Duplicate File Report ---";

if (@duplicate_groups) {
    say "Found " . scalar(@duplicate_groups) . " groups of duplicate files:\n";

    my $group_num = 1;
    for my $group (@duplicate_groups) {
        printf "Group %d [MD5: %s] — %d files, %d bytes each, %d bytes wasted\n",
            $group_num, substr($group->{hash}, 0, 12) . "...",
            $group->{count}, $group->{size}, $group->{wasted};

        for my $file (sort @{$group->{files}}) {
            my $relative = $file;
            $relative =~ s/^\Q$testdir\E\/?//;
            say "    $relative";
        }
        say "";
        $group_num++;
    }

    say "--- Summary ---";
    my $total_dupes = sum(map { $_->{count} - 1 } @duplicate_groups);
    printf "Duplicate groups:     %d\n", scalar @duplicate_groups;
    printf "Total duplicate files:%d\n", $total_dupes;
    printf "Space wasted:         %d bytes\n", $wasted_space;
    printf "Potential savings:    %.1f%% of total\n",
        ($wasted_space / ($total_size || 1)) * 100;
} else {
    say "No duplicate files found.";
}

say "\nDone!";

sub sum {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}
