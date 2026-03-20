#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Practical Project: Web Server Log Analyzer
# ============================================================
# Parses Apache/Nginx combined log format entries,
# extracts statistics, and generates a summary report.
# ============================================================

my @sample_logs = (
    '192.168.1.10 - - [20/Mar/2026:10:15:30 +0000] "GET /index.html HTTP/1.1" 200 5432 "https://google.com" "Mozilla/5.0"',
    '192.168.1.15 - - [20/Mar/2026:10:15:31 +0000] "GET /api/users HTTP/1.1" 200 1024 "-" "curl/7.68.0"',
    '10.0.0.5 - admin [20/Mar/2026:10:15:32 +0000] "POST /api/login HTTP/1.1" 200 256 "https://example.com/login" "Mozilla/5.0"',
    '192.168.1.10 - - [20/Mar/2026:10:15:33 +0000] "GET /images/logo.png HTTP/1.1" 200 15234 "https://example.com/" "Mozilla/5.0"',
    '172.16.0.20 - - [20/Mar/2026:10:15:34 +0000] "GET /nonexistent HTTP/1.1" 404 0 "-" "Mozilla/5.0"',
    '192.168.1.10 - - [20/Mar/2026:10:15:35 +0000] "GET /api/products HTTP/1.1" 200 8192 "https://example.com/shop" "Mozilla/5.0"',
    '10.0.0.5 - - [20/Mar/2026:10:15:36 +0000] "DELETE /api/users/5 HTTP/1.1" 403 128 "-" "curl/7.68.0"',
    '192.168.1.15 - - [20/Mar/2026:10:15:37 +0000] "GET /styles.css HTTP/1.1" 200 3456 "https://example.com/" "Mozilla/5.0"',
    '172.16.0.20 - - [20/Mar/2026:10:15:38 +0000] "GET /admin HTTP/1.1" 403 0 "-" "Mozilla/5.0"',
    '192.168.1.10 - - [20/Mar/2026:10:15:39 +0000] "GET /api/products/42 HTTP/1.1" 200 512 "-" "Mozilla/5.0"',
    '10.0.0.5 - - [20/Mar/2026:10:16:00 +0000] "POST /api/orders HTTP/1.1" 201 256 "https://example.com/cart" "Mozilla/5.0"',
    '192.168.1.15 - - [20/Mar/2026:10:16:05 +0000] "GET /api/users HTTP/1.1" 500 0 "-" "Mozilla/5.0"',
    '192.168.1.10 - - [20/Mar/2026:10:16:10 +0000] "GET /index.html HTTP/1.1" 200 5432 "https://google.com" "Mozilla/5.0"',
    '10.0.0.5 - - [20/Mar/2026:10:16:15 +0000] "PUT /api/users/3 HTTP/1.1" 200 128 "-" "curl/7.68.0"',
    '172.16.0.20 - - [20/Mar/2026:10:16:20 +0000] "GET /favicon.ico HTTP/1.1" 404 0 "-" "Mozilla/5.0"',
);

my $LOG_PATTERN = qr{
    ^(\S+)                              # IP address
    \s+\S+\s+\S+                        # ident, auth user
    \s+\[([^\]]+)\]                     # timestamp
    \s+"(\w+)\s+(\S+)\s+\S+"           # method, path, protocol
    \s+(\d{3})                          # status code
    \s+(\d+)                            # response size
    \s+"([^"]*)"                        # referrer
    \s+"([^"]*)"                        # user agent
}x;

my %stats = (
    total_requests  => 0,
    total_bytes     => 0,
    ip_count        => {},
    status_count    => {},
    method_count    => {},
    path_count      => {},
    hourly_count    => {},
    referrer_count  => {},
    error_requests  => [],
);

say "=" x 60;
say "           WEB SERVER LOG ANALYZER";
say "=" x 60;
say "\nParsing " . scalar(@sample_logs) . " log entries...\n";

for my $line (@sample_logs) {
    if ($line =~ $LOG_PATTERN) {
        my ($ip, $timestamp, $method, $path, $status, $bytes, $referrer, $ua) =
            ($1, $2, $3, $4, $5, $6, $7, $8);

        $stats{total_requests}++;
        $stats{total_bytes} += $bytes;
        $stats{ip_count}{$ip}++;
        $stats{status_count}{$status}++;
        $stats{method_count}{$method}++;
        $stats{path_count}{$path}++;
        $stats{referrer_count}{$referrer}++ if $referrer ne '-';

        if ($timestamp =~ /(\d{2}):/) {
            $stats{hourly_count}{$1}++;
        }

        if ($status >= 400) {
            push @{$stats{error_requests}}, {
                ip     => $ip,
                method => $method,
                path   => $path,
                status => $status,
                time   => $timestamp,
            };
        }
    } else {
        warn "Failed to parse: $line\n";
    }
}

say "--- SUMMARY ---";
printf "Total requests:    %d\n", $stats{total_requests};
printf "Total data served: %s\n", format_bytes($stats{total_bytes});
printf "Unique IPs:        %d\n", scalar keys %{$stats{ip_count}};

say "\n--- REQUESTS BY IP ---";
for my $ip (sort { $stats{ip_count}{$b} <=> $stats{ip_count}{$a} }
            keys %{$stats{ip_count}}) {
    printf "  %-18s %3d requests (%5.1f%%)\n",
        $ip, $stats{ip_count}{$ip},
        ($stats{ip_count}{$ip} / $stats{total_requests}) * 100;
}

say "\n--- STATUS CODE DISTRIBUTION ---";
for my $status (sort keys %{$stats{status_count}}) {
    my $count = $stats{status_count}{$status};
    my $bar = "#" x ($count * 2);
    my $label = status_label($status);
    printf "  %s %-20s %3d %s\n", $status, "($label)", $count, $bar;
}

say "\n--- HTTP METHODS ---";
for my $method (sort keys %{$stats{method_count}}) {
    printf "  %-8s %3d requests\n", $method, $stats{method_count}{$method};
}

say "\n--- TOP REQUESTED PATHS ---";
my @top_paths = sort { $stats{path_count}{$b} <=> $stats{path_count}{$a} }
                keys %{$stats{path_count}};
for my $path (@top_paths[0 .. ($#top_paths > 4 ? 4 : $#top_paths)]) {
    printf "  %-30s %3d hits\n", $path, $stats{path_count}{$path};
}

say "\n--- TOP REFERRERS ---";
for my $ref (sort { $stats{referrer_count}{$b} <=> $stats{referrer_count}{$a} }
             keys %{$stats{referrer_count}}) {
    printf "  %-40s %3d\n", $ref, $stats{referrer_count}{$ref};
}

if (@{$stats{error_requests}}) {
    say "\n--- ERROR REQUESTS (4xx/5xx) ---";
    for my $err (@{$stats{error_requests}}) {
        printf "  [%s] %s %s %-25s from %s\n",
            $err->{status}, $err->{method}, $err->{path},
            "", $err->{ip};
    }
    printf "\n  Error rate: %.1f%%\n",
        (scalar @{$stats{error_requests}} / $stats{total_requests}) * 100;
}

say "\n" . "=" x 60;
say "Analysis complete.";
say "=" x 60;

sub format_bytes {
    my ($bytes) = @_;
    if ($bytes >= 1_073_741_824) { return sprintf("%.2f GB", $bytes / 1_073_741_824) }
    if ($bytes >= 1_048_576)     { return sprintf("%.2f MB", $bytes / 1_048_576) }
    if ($bytes >= 1024)          { return sprintf("%.2f KB", $bytes / 1024) }
    return "$bytes bytes";
}

sub status_label {
    my ($code) = @_;
    my %labels = (
        200 => "OK",
        201 => "Created",
        301 => "Moved Permanently",
        302 => "Found",
        304 => "Not Modified",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        500 => "Internal Server Error",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
    );
    return $labels{$code} // "Unknown";
}
