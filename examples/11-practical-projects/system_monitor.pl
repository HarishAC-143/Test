#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use POSIX qw(strftime);

# ============================================================
# Practical Project: System Resource Monitor
# ============================================================
# Checks CPU, memory, disk usage, and system info.
# Reports threshold violations and system health status.
# ============================================================

my %thresholds = (
    cpu_warn     => 70,
    cpu_crit     => 90,
    mem_warn     => 75,
    mem_crit     => 90,
    disk_warn    => 80,
    disk_crit    => 95,
);

say "=" x 60;
say "          SYSTEM RESOURCE MONITOR";
say "=" x 60;
say "Timestamp: " . strftime("%Y-%m-%d %H:%M:%S", localtime);
say "Hostname:  " . (eval { chomp(my $h = `hostname`); $h } // "unknown");

say "\n--- SYSTEM INFORMATION ---";
show_system_info();

say "\n--- MEMORY USAGE ---";
show_memory_info();

say "\n--- DISK USAGE ---";
show_disk_usage();

say "\n--- LOAD AVERAGE ---";
show_load_average();

say "\n--- TOP PROCESSES (by memory) ---";
show_top_processes();

say "\n--- NETWORK INTERFACES ---";
show_network_info();

say "\n--- UPTIME ---";
show_uptime();

say "\n" . "=" x 60;
say "Monitor check complete.";
say "=" x 60;

# --- Subroutines ---

sub show_system_info {
    my $os = `uname -s 2>/dev/null` // "Unknown";
    chomp $os;
    my $kernel = `uname -r 2>/dev/null` // "Unknown";
    chomp $kernel;
    my $arch = `uname -m 2>/dev/null` // "Unknown";
    chomp $arch;

    printf "  OS:        %s\n", $os;
    printf "  Kernel:    %s\n", $kernel;
    printf "  Arch:      %s\n", $arch;

    if (open(my $fh, '<', '/proc/cpuinfo')) {
        my $cpu_count = 0;
        my $cpu_model = "Unknown";
        while (<$fh>) {
            if (/^processor\s*:/) { $cpu_count++ }
            if (/^model name\s*:\s*(.+)/) { $cpu_model = $1 }
        }
        close($fh);
        printf "  CPUs:      %d\n", $cpu_count;
        printf "  CPU Model: %s\n", $cpu_model;
    }
}

sub show_memory_info {
    if (open(my $fh, '<', '/proc/meminfo')) {
        my %mem;
        while (<$fh>) {
            if (/^(\w+):\s+(\d+)/) {
                $mem{$1} = $2;
            }
        }
        close($fh);

        my $total = $mem{MemTotal}     // 0;
        my $free  = $mem{MemFree}      // 0;
        my $avail = $mem{MemAvailable} // $free;
        my $buffers = $mem{Buffers}    // 0;
        my $cached  = $mem{Cached}     // 0;

        my $used = $total - $free - $buffers - $cached;
        my $used_pct = $total > 0 ? ($used / $total) * 100 : 0;

        printf "  Total:     %s\n", format_kb($total);
        printf "  Used:      %s (%.1f%%)\n", format_kb($used), $used_pct;
        printf "  Free:      %s\n", format_kb($free);
        printf "  Available: %s\n", format_kb($avail);
        printf "  Buffers:   %s\n", format_kb($buffers);
        printf "  Cached:    %s\n", format_kb($cached);

        my $bar = progress_bar($used_pct, 40);
        printf "  Usage:     %s %.1f%%\n", $bar, $used_pct;

        check_threshold("Memory", $used_pct, $thresholds{mem_warn}, $thresholds{mem_crit});

        if (my $swap_total = $mem{SwapTotal}) {
            my $swap_free = $mem{SwapFree} // 0;
            my $swap_used = $swap_total - $swap_free;
            my $swap_pct = $swap_total > 0 ? ($swap_used / $swap_total) * 100 : 0;
            printf "\n  Swap Total: %s\n", format_kb($swap_total);
            printf "  Swap Used:  %s (%.1f%%)\n", format_kb($swap_used), $swap_pct;
        }
    } else {
        say "  (Cannot read /proc/meminfo — not on Linux?)";
        my $vm = `vm_stat 2>/dev/null`;
        if ($vm) {
            say "  macOS memory stats:";
            for my $line (split /\n/, $vm) {
                say "    $line" if $line =~ /\w/;
            }
        }
    }
}

sub show_disk_usage {
    my $df_output = `df -h 2>/dev/null`;
    if ($df_output) {
        my @lines = split /\n/, $df_output;
        my $header = shift @lines;
        printf "  %s\n", $header;
        say "  " . "-" x 70;

        for my $line (@lines) {
            next if $line =~ /^(tmpfs|devtmpfs|udev|overlay)/;
            next unless $line =~ /^\//;
            printf "  %s\n", $line;

            if ($line =~ /(\d+)%/) {
                my $usage = $1;
                my $mount = ($line =~ /(\S+)\s*$/) ? $1 : "unknown";
                check_threshold("Disk ($mount)", $usage,
                    $thresholds{disk_warn}, $thresholds{disk_crit});
            }
        }
    } else {
        say "  (df command not available)";
    }
}

sub show_load_average {
    if (open(my $fh, '<', '/proc/loadavg')) {
        my $line = <$fh>;
        close($fh);
        chomp $line;
        my @parts = split /\s+/, $line;
        printf "  1-min:  %.2f\n", $parts[0];
        printf "  5-min:  %.2f\n", $parts[1];
        printf "  15-min: %.2f\n", $parts[2];

        if (open(my $cpu_fh, '<', '/proc/cpuinfo')) {
            my $cpu_count = grep { /^processor/ } <$cpu_fh>;
            close($cpu_fh);
            my $load_per_cpu = $parts[0] / ($cpu_count || 1);
            printf "  Load per CPU: %.2f\n", $load_per_cpu;
            check_threshold("CPU Load", $load_per_cpu * 100,
                $thresholds{cpu_warn}, $thresholds{cpu_crit});
        }
    } else {
        my $uptime = `uptime 2>/dev/null`;
        if ($uptime && $uptime =~ /load averages?:\s*(.+)/) {
            say "  Load averages: $1";
        }
    }
}

sub show_top_processes {
    my $ps_output = `ps aux --sort=-%mem 2>/dev/null | head -11`;
    if ($ps_output) {
        my @lines = split /\n/, $ps_output;
        for my $line (@lines) {
            say "  $line";
        }
    } else {
        $ps_output = `ps aux 2>/dev/null | head -11`;
        if ($ps_output) {
            for my $line (split /\n/, $ps_output) {
                say "  $line";
            }
        } else {
            say "  (ps command not available)";
        }
    }
}

sub show_network_info {
    my $ip_output = `ip -brief addr show 2>/dev/null`;
    if ($ip_output) {
        for my $line (split /\n/, $ip_output) {
            next if $line =~ /^\s*$/;
            printf "  %s\n", $line;
        }
    } else {
        my $ifconfig = `ifconfig 2>/dev/null`;
        if ($ifconfig) {
            for my $line (split /\n/, $ifconfig) {
                say "  $line" if $line =~ /inet|flags|ether/;
            }
        } else {
            say "  (Network info commands not available)";
        }
    }
}

sub show_uptime {
    if (open(my $fh, '<', '/proc/uptime')) {
        my $line = <$fh>;
        close($fh);
        my ($uptime_secs) = split /\s+/, $line;
        my $days  = int($uptime_secs / 86400);
        my $hours = int(($uptime_secs % 86400) / 3600);
        my $mins  = int(($uptime_secs % 3600) / 60);
        printf "  System uptime: %d days, %d hours, %d minutes\n",
            $days, $hours, $mins;
    } else {
        my $uptime = `uptime 2>/dev/null`;
        if ($uptime) {
            chomp $uptime;
            say "  $uptime";
        }
    }
}

sub format_kb {
    my ($kb) = @_;
    if ($kb >= 1_048_576) { return sprintf("%.1f GB", $kb / 1_048_576) }
    if ($kb >= 1024)      { return sprintf("%.1f MB", $kb / 1024) }
    return "${kb} KB";
}

sub progress_bar {
    my ($percent, $width) = @_;
    $percent = 100 if $percent > 100;
    $percent = 0   if $percent < 0;
    my $filled = int($width * $percent / 100);
    my $empty  = $width - $filled;
    return "[" . ("#" x $filled) . ("-" x $empty) . "]";
}

sub check_threshold {
    my ($name, $value, $warn, $crit) = @_;
    if ($value >= $crit) {
        printf "  ** CRITICAL: %s at %.1f%% (threshold: %d%%) **\n",
            $name, $value, $crit;
    } elsif ($value >= $warn) {
        printf "  * WARNING: %s at %.1f%% (threshold: %d%%) *\n",
            $name, $value, $warn;
    }
}
