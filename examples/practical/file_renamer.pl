#!/usr/bin/perl
#
# File Renamer — Batch rename files using regex patterns.
# Demonstrates regex substitution, file operations, and user interaction.
#
# Usage:
#   perl file_renamer.pl [options]
#
# This script demonstrates the renaming logic without modifying real files.
# Set DRY_RUN=0 to enable actual renames.
#
use strict;
use warnings;
use feature 'say';

say "=== BATCH FILE RENAMER ===\n";

my @sample_files = (
    "IMG_20260101_001.jpg",
    "IMG_20260101_002.jpg",
    "IMG_20260215_003.JPG",
    "document (1).pdf",
    "document (2).pdf",
    "document (3).pdf",
    "My Report - Final (v2).docx",
    "photo_2026_03_17.png",
    "DSCN0042.jpg",
    "DSCN0043.jpg",
    "meeting notes 2026-03-01.txt",
    "meeting notes 2026-03-15.txt",
    "video.file.name.with.dots.mp4",
);

sub preview_renames {
    my ($pattern, $replacement, @files) = @_;
    my @results;

    for my $file (@files) {
        (my $new_name = $file) =~ s/$pattern/$replacement/ee;
        if ($new_name ne $file) {
            push @results, { old => $file, new => $new_name };
        }
    }
    return @results;
}

sub display_renames {
    my ($description, @renames) = @_;
    say "--- $description ---";
    if (!@renames) {
        say "  No files would be renamed.\n";
        return;
    }
    printf "  %-45s => %s\n", "Original", "New Name";
    printf "  %s\n", "-" x 80;
    for my $r (@renames) {
        printf "  %-45s => %s\n", $r->{old}, $r->{new};
    }
    say "  (${\scalar @renames} files would be renamed)\n";
}

# --- Renaming Strategy 1: Lowercase all filenames ---
say "STRATEGY 1: Lowercase all filenames\n";
my @lowercase_renames;
for my $file (@sample_files) {
    my $new = lc($file);
    if ($new ne $file) {
        push @lowercase_renames, { old => $file, new => $new };
    }
}
display_renames("Lowercase All", @lowercase_renames);

# --- Renaming Strategy 2: Replace spaces with underscores ---
say "STRATEGY 2: Replace spaces with underscores\n";
my @space_renames;
for my $file (@sample_files) {
    (my $new = $file) =~ s/\s+/_/g;
    if ($new ne $file) {
        push @space_renames, { old => $file, new => $new };
    }
}
display_renames("Spaces to Underscores", @space_renames);

# --- Renaming Strategy 3: Remove parentheses and their contents ---
say "STRATEGY 3: Clean up parenthesized suffixes\n";
my @paren_renames;
for my $file (@sample_files) {
    (my $new = $file) =~ s/\s*\([^)]*\)//g;
    $new =~ s/\s+(?=\.\w+$)//;
    if ($new ne $file) {
        push @paren_renames, { old => $file, new => $new };
    }
}
display_renames("Remove Parentheses", @paren_renames);

# --- Renaming Strategy 4: Sequential numbering ---
say "STRATEGY 4: Sequential numbering by extension\n";
my %by_ext;
for my $file (@sample_files) {
    my ($ext) = ($file =~ /\.(\w+)$/);
    $ext = lc($ext // "unknown");
    push @{$by_ext{$ext}}, $file;
}

my @seq_renames;
for my $ext (sort keys %by_ext) {
    my @files = sort @{$by_ext{$ext}};
    for my $i (0..$#files) {
        my $new = sprintf("file_%03d.%s", $i + 1, $ext);
        push @seq_renames, { old => $files[$i], new => $new };
    }
}
display_renames("Sequential Numbering", @seq_renames);

# --- Renaming Strategy 5: Date format normalization ---
say "STRATEGY 5: Normalize date formats in filenames\n";
my @date_renames;
for my $file (@sample_files) {
    my $new = $file;
    $new =~ s/(\d{4})(\d{2})(\d{2})/$1-$2-$3/g;
    $new =~ s/(\d{4})_(\d{2})_(\d{2})/$1-$2-$3/g;
    if ($new ne $file) {
        push @date_renames, { old => $file, new => $new };
    }
}
display_renames("Normalize Dates", @date_renames);

# --- Renaming Strategy 6: Sanitize filenames ---
say "STRATEGY 6: Full sanitization (lowercase, no spaces, no special chars)\n";
my @sanitized_renames;
for my $file (@sample_files) {
    my $new = lc($file);
    $new =~ s/\s+/-/g;             # spaces to hyphens
    $new =~ s/[()]+//g;            # remove parentheses
    $new =~ s/[^a-z0-9._-]/-/g;   # replace other special chars
    $new =~ s/-{2,}/-/g;           # collapse multiple hyphens
    $new =~ s/-+(?=\.\w+$)//;     # remove trailing hyphens before extension
    if ($new ne $file) {
        push @sanitized_renames, { old => $file, new => $new };
    }
}
display_renames("Full Sanitization", @sanitized_renames);

say "=== SUMMARY ===";
say "This demonstrates various file renaming strategies using Perl regex.";
say "In a real application, you would use rename() to apply the changes:";
say "";
say '  rename($old_name, $new_name) or warn "Cannot rename: $!";';
say "";
