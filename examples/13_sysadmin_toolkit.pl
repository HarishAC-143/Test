#!/usr/bin/perl
# 13_sysadmin_toolkit.pl — Practical example: System administration tasks
#
# Demonstrates: system commands, file operations, process info, environment, reporting
# A collection of common sysadmin tasks implemented in Perl.
use strict;
use warnings;
use feature 'say';
use POSIX qw(strftime uname);
use File::Find;
use File::Spec;
use Cwd qw(getcwd);

say "=" x 60;
say "  Practical Example: System Administration Toolkit";
say "=" x 60;

# --- System Information ---
say "\n--- System Information ---";

my ($sysname, $nodename, $release, $version, $machine) = uname();
printf "  OS:          %s %s\n", $sysname, $release;
printf "  Hostname:    %s\n", $nodename;
printf "  Machine:     %s\n", $machine;
printf "  Perl:        %s\n", $^V;
printf "  Process ID:  %d\n", $$;
printf "  User:        %s\n", $ENV{USER} // $ENV{LOGNAME} // "unknown";
printf "  Home:        %s\n", $ENV{HOME} // "unknown";
printf "  Shell:       %s\n", $ENV{SHELL} // "unknown";
printf "  CWD:         %s\n", getcwd();
printf "  Date:        %s\n", strftime("%Y-%m-%d %H:%M:%S %Z", localtime);
printf "  Uptime:      %s\n", get_uptime();

sub get_uptime {
    if (-f "/proc/uptime") {
        open(my $fh, '<', "/proc/uptime") or return "N/A";
        my $line = <$fh>;
        close($fh);
        my ($seconds) = split /\s+/, $line;
        my $days  = int($seconds / 86400);
        my $hours = int(($seconds % 86400) / 3600);
        my $mins  = int(($seconds % 3600) / 60);
        return sprintf("%d days, %d hours, %d minutes", $days, $hours, $mins);
    }
    return "N/A (no /proc/uptime)";
}

# --- Environment Variables ---
say "\n--- Key Environment Variables ---";

my @env_keys = qw(PATH HOME USER SHELL LANG TERM EDITOR);
for my $key (@env_keys) {
    my $val = $ENV{$key} // "(not set)";
    $val = substr($val, 0, 60) . "..." if length($val) > 63;
    printf "  %-10s = %s\n", $key, $val;
}

# --- Disk Usage (from df) ---
say "\n--- Disk Usage ---";

if (open(my $df, '-|', 'df -h 2>/dev/null')) {
    my $header = <$df>;
    chomp $header;
    printf "  %s\n", $header;

    while (my $line = <$df>) {
        chomp $line;
        next if $line =~ /^(tmpfs|devtmpfs|overlay)/;
        next unless $line =~ /^\//;
        printf "  %s\n", $line;
    }
    close($df);
} else {
    say "  (df not available)";
}

# --- Memory Info ---
say "\n--- Memory Information ---";

if (-f "/proc/meminfo") {
    open(my $mem, '<', "/proc/meminfo") or die "Cannot read meminfo: $!\n";
    my %meminfo;
    while (my $line = <$mem>) {
        if ($line =~ /^(\w+):\s+(\d+)/) {
            $meminfo{$1} = $2;
        }
    }
    close($mem);

    if (exists $meminfo{MemTotal}) {
        printf "  Total:     %8.1f MB\n", $meminfo{MemTotal} / 1024;
        printf "  Free:      %8.1f MB\n", ($meminfo{MemFree} // 0) / 1024;
        printf "  Available: %8.1f MB\n", ($meminfo{MemAvailable} // 0) / 1024;
        printf "  Buffers:   %8.1f MB\n", ($meminfo{Buffers} // 0) / 1024;
        printf "  Cached:    %8.1f MB\n", ($meminfo{Cached} // 0) / 1024;

        if (exists $meminfo{SwapTotal}) {
            printf "  Swap Total:%8.1f MB\n", $meminfo{SwapTotal} / 1024;
            printf "  Swap Free: %8.1f MB\n", ($meminfo{SwapFree} // 0) / 1024;
        }

        my $used_pct = 100 - (($meminfo{MemAvailable} // $meminfo{MemFree} // 0)
                              / $meminfo{MemTotal} * 100);
        printf "  Used:      %8.1f%%\n", $used_pct;
    }
} else {
    say "  (meminfo not available on this platform)";
}

# --- Process List (top consumers) ---
say "\n--- Top 10 Processes by Memory ---";

if (open(my $ps, '-|', 'ps aux --sort=-%mem 2>/dev/null | head -11')) {
    while (my $line = <$ps>) {
        chomp $line;
        say "  $line";
    }
    close($ps);
} else {
    say "  (ps not available)";
}

# --- Directory Size Calculator ---
say "\n--- Directory Size Analysis ---";

sub dir_size {
    my ($dir) = @_;
    my $total = 0;
    my $count = 0;

    find(sub {
        return unless -f $_;
        $total += -s $_;
        $count++;
    }, $dir);

    return ($total, $count);
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
    return sprintf("%.1f %s", $size, $units[$unit]);
}

my $scan_dir = getcwd();
my ($total_size, $file_count) = dir_size($scan_dir);

say "Scanning: $scan_dir";
printf "  Total files: %d\n", $file_count;
printf "  Total size:  %s\n", format_size($total_size);

# Top-level subdirectory breakdown
if (opendir(my $dh, $scan_dir)) {
    my @subdirs = grep { -d File::Spec->catdir($scan_dir, $_) && !/^\./ } readdir($dh);
    closedir($dh);

    if (@subdirs) {
        say "\n  Subdirectory breakdown:";
        printf "  %-30s %12s %8s\n", "Directory", "Size", "Files";
        say "  " . "-" x 52;

        my @dir_stats;
        for my $sub (sort @subdirs) {
            my $path = File::Spec->catdir($scan_dir, $sub);
            my ($size, $count) = dir_size($path);
            push @dir_stats, { name => $sub, size => $size, count => $count };
        }

        for my $d (sort { $b->{size} <=> $a->{size} } @dir_stats) {
            printf "  %-30s %12s %8d\n", $d->{name}, format_size($d->{size}), $d->{count};
        }
    }
}

# --- File Type Inventory ---
say "\n--- File Type Inventory ---";

my %ext_count;
my %ext_size;

find(sub {
    return unless -f $_;
    my ($ext) = $_ =~ /\.(\w+)$/;
    $ext = $ext ? lc($ext) : "(none)";
    $ext_count{$ext}++;
    $ext_size{$ext} += -s $_;
}, $scan_dir);

printf "  %-15s %8s %12s\n", "Extension", "Count", "Total Size";
say "  " . "-" x 38;

for my $ext (sort { $ext_count{$b} <=> $ext_count{$a} } keys %ext_count) {
    printf "  %-15s %8d %12s\n", ".$ext", $ext_count{$ext}, format_size($ext_size{$ext});
    last if $. > 15;
}

# --- Find Large Files ---
say "\n--- Largest Files in Current Directory Tree ---";

my @large_files;
find(sub {
    return unless -f $_;
    my $size = -s $_;
    push @large_files, { path => $File::Find::name, size => $size };
}, $scan_dir);

@large_files = sort { $b->{size} <=> $a->{size} } @large_files;

printf "  %-50s %12s\n", "File", "Size";
say "  " . "-" x 64;

for my $i (0 .. 9) {
    last if $i >= scalar @large_files;
    my $f = $large_files[$i];
    my $relative = $f->{path};
    $relative =~ s/^\Q$scan_dir\E\/?//;
    $relative = substr($relative, 0, 48) . ".." if length($relative) > 50;
    printf "  %-50s %12s\n", $relative, format_size($f->{size});
}

# --- Recently Modified Files ---
say "\n--- Recently Modified Files (last 24 hours) ---";

my @recent;
find(sub {
    return unless -f $_;
    my $age_days = -M $_;
    if ($age_days < 1) {
        push @recent, {
            path => $File::Find::name,
            age  => $age_days,
            size => -s $_,
        };
    }
}, $scan_dir);

@recent = sort { $a->{age} <=> $b->{age} } @recent;

if (@recent) {
    printf "  %-45s %8s %12s\n", "File", "Age", "Size";
    say "  " . "-" x 67;
    for my $i (0 .. 14) {
        last if $i >= scalar @recent;
        my $f = $recent[$i];
        my $relative = $f->{path};
        $relative =~ s/^\Q$scan_dir\E\/?//;
        $relative = substr($relative, 0, 43) . ".." if length($relative) > 45;
        my $age_str = sprintf("%.0f min", $f->{age} * 1440);
        printf "  %-45s %8s %12s\n", $relative, $age_str, format_size($f->{size});
    }
} else {
    say "  No files modified in the last 24 hours.";
}

say "\nDone!";
