#!/usr/bin/perl
#
# Log Analyzer — Parses web server log entries, counts status codes,
# identifies top requesters, and flags errors.
#
use strict;
use warnings;
use feature 'say';

say "=== WEB SERVER LOG ANALYZER ===\n";

my @log_entries = (
    '192.168.1.1 - - [17/Mar/2026:10:00:01] "GET /index.html HTTP/1.1" 200 5120',
    '192.168.1.2 - - [17/Mar/2026:10:00:02] "GET /about.html HTTP/1.1" 200 3072',
    '192.168.1.1 - - [17/Mar/2026:10:00:03] "POST /api/login HTTP/1.1" 200 256',
    '192.168.1.3 - - [17/Mar/2026:10:00:04] "GET /missing.html HTTP/1.1" 404 1024',
    '192.168.1.1 - - [17/Mar/2026:10:00:05] "GET /style.css HTTP/1.1" 200 8192',
    '192.168.1.2 - - [17/Mar/2026:10:00:06] "GET /admin HTTP/1.1" 403 512',
    '192.168.1.4 - - [17/Mar/2026:10:00:07] "GET /index.html HTTP/1.1" 200 5120',
    '192.168.1.1 - - [17/Mar/2026:10:00:08] "GET /images/logo.png HTTP/1.1" 200 15360',
    '192.168.1.3 - - [17/Mar/2026:10:00:09] "POST /api/data HTTP/1.1" 500 128',
    '192.168.1.2 - - [17/Mar/2026:10:00:10] "GET /index.html HTTP/1.1" 200 5120',
    '192.168.1.5 - - [17/Mar/2026:10:00:11] "GET /secret HTTP/1.1" 401 256',
    '192.168.1.1 - - [17/Mar/2026:10:00:12] "GET /contact.html HTTP/1.1" 200 2048',
    '192.168.1.3 - - [17/Mar/2026:10:00:13] "GET /products HTTP/1.1" 301 0',
    '192.168.1.2 - - [17/Mar/2026:10:00:14] "DELETE /api/user/5 HTTP/1.1" 204 0',
    '192.168.1.1 - - [17/Mar/2026:10:00:15] "GET /favicon.ico HTTP/1.1" 404 0',
);

my $log_pattern = qr/
    ^(\S+)              # IP address
    \s+\S+\s+\S+\s+    # ident and auth fields
    \[([^\]]+)\]        # timestamp
    \s+"(\w+)           # HTTP method
    \s+(\S+)            # URL path
    \s+\S+"             # protocol
    \s+(\d{3})          # status code
    \s+(\d+)            # response size
/x;

my %ip_count;
my %status_count;
my %path_count;
my %method_count;
my @errors;
my $total_bytes = 0;
my $total_requests = 0;

for my $entry (@log_entries) {
    if ($entry =~ $log_pattern) {
        my ($ip, $timestamp, $method, $path, $status, $bytes) = ($1, $2, $3, $4, $5, $6);

        $total_requests++;
        $total_bytes += $bytes;
        $ip_count{$ip}++;
        $status_count{$status}++;
        $path_count{$path}++;
        $method_count{$method}++;

        if ($status >= 400) {
            push @errors, {
                ip        => $ip,
                timestamp => $timestamp,
                method    => $method,
                path      => $path,
                status    => $status,
            };
        }
    }
}

say "--- Summary ---";
say "Total requests: $total_requests";
printf "Total bytes transferred: %s\n", format_bytes($total_bytes);
say "";

say "--- Status Code Distribution ---";
for my $status (sort keys %status_count) {
    my $count = $status_count{$status};
    my $pct = ($count / $total_requests) * 100;
    my $label = status_label($status);
    printf "  %s %-25s %3d (%5.1f%%) %s\n",
           $status, $label, $count, $pct, bar($count, $total_requests);
}

say "\n--- Top Requesters (by IP) ---";
my @sorted_ips = sort { $ip_count{$b} <=> $ip_count{$a} } keys %ip_count;
for my $ip (@sorted_ips) {
    printf "  %-15s %3d requests\n", $ip, $ip_count{$ip};
}

say "\n--- Most Requested Paths ---";
my @sorted_paths = sort { $path_count{$b} <=> $path_count{$a} } keys %path_count;
for my $path (@sorted_paths[0..4]) {
    last unless defined $path;
    printf "  %-25s %3d hits\n", $path, $path_count{$path};
}

say "\n--- HTTP Methods ---";
for my $method (sort keys %method_count) {
    printf "  %-8s %3d\n", $method, $method_count{$method};
}

if (@errors) {
    say "\n--- Errors (4xx/5xx) ---";
    for my $err (@errors) {
        printf "  [%s] %s %s %s => %s\n",
               $err->{timestamp}, $err->{ip},
               $err->{method}, $err->{path}, $err->{status};
    }
}

sub format_bytes {
    my ($bytes) = @_;
    my @units = ('B', 'KB', 'MB', 'GB');
    my $unit = 0;
    my $size = $bytes;
    while ($size >= 1024 && $unit < $#units) {
        $size /= 1024;
        $unit++;
    }
    return sprintf("%.1f %s", $size, $units[$unit]);
}

sub status_label {
    my ($code) = @_;
    my %labels = (
        200 => "OK",
        204 => "No Content",
        301 => "Moved Permanently",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        500 => "Internal Server Error",
    );
    return $labels{$code} // "Unknown";
}

sub bar {
    my ($count, $total) = @_;
    my $width = 20;
    my $filled = int(($count / $total) * $width);
    return "[" . "#" x $filled . " " x ($width - $filled) . "]";
}
