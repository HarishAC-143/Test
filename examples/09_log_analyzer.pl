#!/usr/bin/perl
# 09_log_analyzer.pl — Practical example: Analyze a web server log file
#
# Demonstrates: file I/O, regex, hashes, sorting, formatted output
# This script generates a sample log and then analyzes it.
use strict;
use warnings;
use feature 'say';
use File::Temp qw(tempfile);

say "=" x 60;
say "  Practical Example: Log File Analyzer";
say "=" x 60;

# --- Generate a sample Apache-style access log ---
my ($fh, $logfile) = tempfile(SUFFIX => '.log', UNLINK => 1);

my @sample_ips    = qw(192.168.1.10 10.0.0.5 172.16.0.1 192.168.1.25 10.0.0.12 8.8.8.8);
my @sample_paths  = qw(/ /index.html /about /api/users /api/products /login /dashboard /static/style.css /favicon.ico /api/orders);
my @sample_codes  = (200, 200, 200, 200, 200, 301, 302, 404, 404, 500);
my @sample_methods = qw(GET GET GET POST GET PUT DELETE GET GET GET);

srand(42);
for my $i (1..500) {
    my $ip     = $sample_ips[int(rand(@sample_ips))];
    my $method = $sample_methods[int(rand(@sample_methods))];
    my $path   = $sample_paths[int(rand(@sample_paths))];
    my $code   = $sample_codes[int(rand(@sample_codes))];
    my $size   = int(rand(50000)) + 100;
    my $day    = sprintf("%02d", int(rand(28)) + 1);
    my $hour   = sprintf("%02d", int(rand(24)));
    my $min    = sprintf("%02d", int(rand(60)));
    my $sec    = sprintf("%02d", int(rand(60)));

    print $fh "$ip - - [$day/Mar/2025:$hour:$min:$sec +0000] \"$method $path HTTP/1.1\" $code $size\n";
}
close($fh);

say "Generated 500-line sample log: $logfile\n";

# --- Parse the log file ---
open(my $log, '<', $logfile) or die "Cannot open log: $!\n";

my %ip_count;
my %path_count;
my %status_count;
my %method_count;
my %hourly_traffic;
my %error_paths;
my $total_bytes = 0;
my $total_requests = 0;

my $log_re = qr/
    ^(\S+)                            # IP address
    \s+\S+\s+\S+\s+                   # ident and authuser
    \[(\d{2})\/\w+\/\d{4}:(\d{2})     # day and hour
    :\d{2}:\d{2}\s+\S+\]\s+           # min:sec timezone
    "(\w+)\s+(\S+)\s+\S+"\s+          # method and path
    (\d{3})\s+                         # status code
    (\d+)                              # response size
/x;

while (my $line = <$log>) {
    chomp $line;
    if ($line =~ $log_re) {
        my ($ip, $day, $hour, $method, $path, $status, $bytes) = ($1, $2, $3, $4, $5, $6, $7);

        $ip_count{$ip}++;
        $path_count{$path}++;
        $status_count{$status}++;
        $method_count{$method}++;
        $hourly_traffic{$hour}++;
        $total_bytes += $bytes;
        $total_requests++;

        if ($status >= 400) {
            $error_paths{$path}{$status}++;
        }
    }
}
close($log);

# --- Display Results ---

say "=" x 60;
say "  ANALYSIS RESULTS";
say "=" x 60;

say "\n--- Summary ---";
say "Total requests:   $total_requests";
printf "Total data:       %.2f MB\n", $total_bytes / (1024 * 1024);
printf "Unique IPs:       %d\n", scalar keys %ip_count;
printf "Unique paths:     %d\n", scalar keys %path_count;

say "\n--- Top 10 IPs by Request Count ---";
my @top_ips = (sort { $ip_count{$b} <=> $ip_count{$a} } keys %ip_count)[0..9];
printf "  %-20s %8s %8s\n", "IP Address", "Requests", "Percent";
say "  " . "-" x 38;
for my $ip (@top_ips) {
    last unless defined $ip;
    my $pct = ($ip_count{$ip} / $total_requests) * 100;
    printf "  %-20s %8d %7.1f%%\n", $ip, $ip_count{$ip}, $pct;
}

say "\n--- Top 10 Requested Paths ---";
my @top_paths = (sort { $path_count{$b} <=> $path_count{$a} } keys %path_count)[0..9];
printf "  %-30s %8s\n", "Path", "Requests";
say "  " . "-" x 40;
for my $path (@top_paths) {
    last unless defined $path;
    printf "  %-30s %8d\n", $path, $path_count{$path};
}

say "\n--- HTTP Status Code Distribution ---";
printf "  %-6s %-25s %8s\n", "Code", "Meaning", "Count";
say "  " . "-" x 42;
my %status_meaning = (
    200 => "OK",
    301 => "Moved Permanently",
    302 => "Found (Redirect)",
    304 => "Not Modified",
    400 => "Bad Request",
    403 => "Forbidden",
    404 => "Not Found",
    500 => "Internal Server Error",
);
for my $code (sort keys %status_count) {
    my $meaning = $status_meaning{$code} // "Unknown";
    printf "  %-6s %-25s %8d\n", $code, $meaning, $status_count{$code};
}

say "\n--- HTTP Methods ---";
for my $method (sort keys %method_count) {
    printf "  %-8s %d\n", $method, $method_count{$method};
}

say "\n--- Hourly Traffic Distribution ---";
my $max_hourly = (sort { $b <=> $a } values %hourly_traffic)[0];
for my $hour (map { sprintf("%02d", $_) } 0..23) {
    my $count = $hourly_traffic{$hour} // 0;
    my $bar_len = int(($count / ($max_hourly || 1)) * 40);
    printf "  %s:00 |%-40s| %d\n", $hour, "#" x $bar_len, $count;
}

if (keys %error_paths) {
    say "\n--- Error Paths (4xx/5xx) ---";
    for my $path (sort keys %error_paths) {
        my $errors = $error_paths{$path};
        my $detail = join(", ", map { "$_: $errors->{$_}" } sort keys %$errors);
        printf "  %-30s %s\n", $path, $detail;
    }
}

say "\nDone!";
