#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Subroutines (Functions)
# ============================================================

say "=== BASIC SUBROUTINE ===";

sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

say greet("Alice");
say greet("Bob");

say "\n=== MULTIPLE PARAMETERS ===";

sub calculate_bmi {
    my ($weight_kg, $height_m) = @_;
    my $bmi = $weight_kg / ($height_m ** 2);
    return sprintf("%.1f", $bmi);
}

say "BMI: " . calculate_bmi(70, 1.75);
say "BMI: " . calculate_bmi(90, 1.80);

say "\n=== DEFAULT VALUES ===";

sub create_user {
    my (%args) = @_;
    my $name  = $args{name}  // "Anonymous";
    my $role  = $args{role}  // "viewer";
    my $active = $args{active} // 1;

    say "User: $name, Role: $role, Active: $active";
}

create_user(name => "Alice", role => "admin");
create_user(name => "Bob");
create_user();

say "\n=== VARIABLE ARGUMENTS ===";

sub average {
    return 0 unless @_;
    my $sum = 0;
    $sum += $_ for @_;
    return $sum / scalar @_;
}

say "Average of (10,20,30): " . average(10, 20, 30);
say "Average of (5): " . average(5);

say "\n=== RETURNING MULTIPLE VALUES ===";

sub analyze_numbers {
    my @sorted = sort { $a <=> $b } @_;
    my $min = $sorted[0];
    my $max = $sorted[-1];
    my $sum = 0;
    $sum += $_ for @sorted;
    my $avg = $sum / scalar @sorted;

    return ($min, $max, $sum, $avg);
}

my ($min, $max, $sum, $avg) = analyze_numbers(45, 12, 78, 34, 91, 23);
say "Min: $min, Max: $max, Sum: $sum, Avg: $avg";

say "\n=== RETURNING A HASH ===";

sub parse_url {
    my ($url) = @_;
    my %result;

    if ($url =~ m{^(https?)://([^/:]+)(?::(\d+))?(/.*)?$}) {
        %result = (
            protocol => $1,
            host     => $2,
            port     => $3 // ($1 eq 'https' ? 443 : 80),
            path     => $4 // '/',
        );
    }

    return %result;
}

my %parsed = parse_url("https://example.com:8080/api/users");
for my $key (sort keys %parsed) {
    say "  $key: $parsed{$key}";
}

say "\n=== WANTARRAY — CONTEXT-SENSITIVE RETURNS ===";

sub flexible_return {
    my @items = qw(alpha beta gamma delta);

    if (wantarray()) {
        return @items;
    } else {
        return scalar @items;
    }
}

my @list = flexible_return();
say "List context: @list";

my $count = flexible_return();
say "Scalar context: $count";

say "\n=== RECURSIVE SUBROUTINES ===";

sub factorial {
    my ($n) = @_;
    return 1 if $n <= 1;
    return $n * factorial($n - 1);
}

for my $n (1..8) {
    printf "  %d! = %d\n", $n, factorial($n);
}

say "\n--- Tower of Hanoi ---";

sub hanoi {
    my ($n, $from, $to, $aux) = @_;
    if ($n == 1) {
        say "  Move disk 1 from $from to $to";
        return;
    }
    hanoi($n - 1, $from, $aux, $to);
    say "  Move disk $n from $from to $to";
    hanoi($n - 1, $aux, $to, $from);
}

hanoi(3, 'A', 'C', 'B');

say "\n--- Subroutines demo complete ---";
