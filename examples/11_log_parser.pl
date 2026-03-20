#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- Practical Project: Log File Parser ---
# Parses web server-style log entries and generates statistics.

my @log_lines = split /\n/, <<'END_LOG';
2026-03-20 08:15:32 INFO  192.168.1.10 GET /index.html 200 1250 0.045
2026-03-20 08:15:33 INFO  192.168.1.15 GET /about.html 200 2340 0.032
2026-03-20 08:15:35 WARN  192.168.1.10 GET /old-page 301 0 0.012
2026-03-20 08:16:01 INFO  10.0.0.5 POST /api/login 200 450 0.125
2026-03-20 08:16:02 ERROR 10.0.0.5 POST /api/login 401 120 0.089
2026-03-20 08:16:15 INFO  192.168.1.20 GET /products 200 8900 0.234
2026-03-20 08:16:18 INFO  192.168.1.20 GET /products/42 200 3200 0.067
2026-03-20 08:17:00 ERROR 172.16.0.8 GET /admin 403 0 0.008
2026-03-20 08:17:05 INFO  192.168.1.10 GET /css/style.css 200 5600 0.015
2026-03-20 08:17:06 INFO  192.168.1.10 GET /js/app.js 200 12400 0.022
2026-03-20 08:18:00 WARN  10.0.0.12 POST /api/data 400 85 0.034
2026-03-20 08:18:10 INFO  192.168.1.15 GET /contact.html 200 1800 0.028
2026-03-20 08:18:45 INFO  192.168.1.25 GET /index.html 200 1250 0.041
2026-03-20 08:19:00 ERROR 10.0.0.5 DELETE /api/users/99 500 0 0.567
2026-03-20 08:19:30 INFO  192.168.1.20 GET /products/15 200 3100 0.058
2026-03-20 08:20:00 INFO  192.168.1.30 GET /index.html 200 1250 0.038
2026-03-20 08:20:15 WARN  172.16.0.8 GET /debug 404 0 0.005
2026-03-20 08:20:30 INFO  192.168.1.10 POST /api/search 200 6700 0.312
2026-03-20 08:21:00 INFO  192.168.1.15 GET /blog/post-1 200 4500 0.072
2026-03-20 08:21:30 ERROR 10.0.0.5 POST /api/upload 413 0 0.003
END_LOG

say "=" x 65;
say "              WEB SERVER LOG ANALYZER";
say "=" x 65;
say "\nParsing " . scalar(@log_lines) . " log entries...\n";

# --- Parse Log Entries ---
my $log_pattern = qr/
    ^(\d{4}-\d{2}-\d{2})       # date
    \s+(\d{2}:\d{2}:\d{2})     # time
    \s+(INFO|WARN|ERROR)        # level
    \s+(\S+)                    # IP address
    \s+(GET|POST|PUT|DELETE)    # HTTP method
    \s+(\S+)                    # path
    \s+(\d{3})                  # status code
    \s+(\d+)                    # response size
    \s+([\d.]+)                 # response time
    $
/x;

my @entries;
my $parse_errors = 0;

for my $line (@log_lines) {
    if ($line =~ $log_pattern) {
        push @entries, {
            date     => $1,
            time     => $2,
            level    => $3,
            ip       => $4,
            method   => $5,
            path     => $6,
            status   => $7,
            size     => $8,
            duration => $9,
        };
    } else {
        $parse_errors++;
        warn "Failed to parse: $line\n";
    }
}

say "Successfully parsed: " . scalar(@entries) . " entries";
say "Parse errors: $parse_errors" if $parse_errors;

# --- Log Level Summary ---
say "\n--- Log Level Summary ---";
my %level_count;
$level_count{$_->{level}}++ for @entries;

for my $level (qw(INFO WARN ERROR)) {
    my $count = $level_count{$level} // 0;
    my $pct = ($count / scalar(@entries)) * 100;
    my $bar = "#" x $count;
    printf "  %-5s : %3d (%5.1f%%) %s\n", $level, $count, $pct, $bar;
}

# --- HTTP Status Code Breakdown ---
say "\n--- HTTP Status Codes ---";
my %status_count;
$status_count{$_->{status}}++ for @entries;

my %status_desc = (
    200 => "OK",
    301 => "Moved Permanently",
    400 => "Bad Request",
    401 => "Unauthorized",
    403 => "Forbidden",
    404 => "Not Found",
    413 => "Payload Too Large",
    500 => "Internal Server Error",
);

for my $code (sort keys %status_count) {
    my $desc = $status_desc{$code} // "Unknown";
    printf "  %s %-22s : %d\n", $code, $desc, $status_count{$code};
}

# --- Top Requested Paths ---
say "\n--- Top Requested Paths ---";
my %path_count;
$path_count{$_->{path}}++ for @entries;

my @top_paths = sort { $path_count{$b} <=> $path_count{$a} } keys %path_count;
for my $i (0 .. 9) {
    last if $i > $#top_paths;
    printf "  %2d. %-25s %d hits\n", $i + 1, $top_paths[$i], $path_count{$top_paths[$i]};
}

# --- IP Address Activity ---
say "\n--- Client IP Activity ---";
my %ip_data;
for my $e (@entries) {
    $ip_data{$e->{ip}}{count}++;
    push @{$ip_data{$e->{ip}}{paths}}, $e->{path};
}

for my $ip (sort { $ip_data{$b}{count} <=> $ip_data{$a}{count} } keys %ip_data) {
    my $count = $ip_data{$ip}{count};
    my %unique_paths = map { $_ => 1 } @{$ip_data{$ip}{paths}};
    printf "  %-15s : %2d requests, %2d unique paths\n",
        $ip, $count, scalar keys %unique_paths;
}

# --- HTTP Method Distribution ---
say "\n--- HTTP Methods ---";
my %method_count;
$method_count{$_->{method}}++ for @entries;

for my $method (sort keys %method_count) {
    printf "  %-6s : %d\n", $method, $method_count{$method};
}

# --- Response Time Analysis ---
say "\n--- Response Time Analysis ---";
my @times = sort { $a <=> $b } map { $_->{duration} } @entries;
my $total_time = 0;
$total_time += $_ for @times;

printf "  Fastest   : %.3f sec\n", $times[0];
printf "  Slowest   : %.3f sec\n", $times[-1];
printf "  Average   : %.3f sec\n", $total_time / scalar(@times);
printf "  Median    : %.3f sec\n", $times[int(@times / 2)];

# Slow requests (> 0.1 sec)
my @slow = grep { $_->{duration} > 0.1 } @entries;
say "\n  Slow requests (> 0.1s):";
for my $e (sort { $b->{duration} <=> $a->{duration} } @slow) {
    printf "    %.3fs  %s %s (%s)\n", $e->{duration}, $e->{method}, $e->{path}, $e->{status};
}

# --- Error Details ---
say "\n--- Error Log ---";
my @errors = grep { $_->{level} eq "ERROR" } @entries;
if (@errors) {
    for my $e (@errors) {
        printf "  [%s %s] %s %s %s => %s\n",
            $e->{date}, $e->{time}, $e->{ip}, $e->{method}, $e->{path}, $e->{status};
    }
} else {
    say "  No errors found.";
}

# --- Bandwidth ---
say "\n--- Bandwidth Summary ---";
my $total_bytes = 0;
$total_bytes += $_->{size} for @entries;
printf "  Total data transferred: %s\n", format_bytes($total_bytes);

my %path_bytes;
for my $e (@entries) {
    $path_bytes{$e->{path}} += $e->{size};
}
my @top_bw = (sort { $path_bytes{$b} <=> $path_bytes{$a} } keys %path_bytes)[0..4];
say "  Top bandwidth consumers:";
for my $path (@top_bw) {
    printf "    %-25s %s\n", $path, format_bytes($path_bytes{$path});
}

say "\n" . "=" x 65;
say "Analysis complete!";

sub format_bytes {
    my ($bytes) = @_;
    if ($bytes >= 1_048_576) {
        return sprintf("%.2f MB", $bytes / 1_048_576);
    } elsif ($bytes >= 1024) {
        return sprintf("%.2f KB", $bytes / 1024);
    }
    return "$bytes B";
}
