#!/usr/bin/perl
# 04_subroutines.pl — Functions, parameters, return values
use strict;
use warnings;
use feature 'say';

say "=" x 50;
say "  Perl Subroutines Demo";
say "=" x 50;

# --- Basic subroutine ---
sub greet {
    my ($name) = @_;
    return "Hello, $name! Welcome to Perl.";
}

say greet("Alice");
say greet("Bob");

# --- Multiple parameters ---
sub rectangle_info {
    my ($width, $height) = @_;
    my $area = $width * $height;
    my $perimeter = 2 * ($width + $height);
    return ($area, $perimeter);
}

my ($area, $perimeter) = rectangle_info(5, 3);
say "\nRectangle 5x3: area=$area, perimeter=$perimeter";

# --- Default values ---
sub connect_db {
    my (%args) = @_;
    my $host = $args{host} // "localhost";
    my $port = $args{port} // 5432;
    my $db   = $args{db}   // "mydb";
    return "postgresql://$host:$port/$db";
}

say "\nDefault: " . connect_db();
say "Custom:  " . connect_db(host => "prod.example.com", db => "app_prod");

# --- Variable number of arguments ---
sub sum_all {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}

say "\nSum(1..10): " . sum_all(1..10);

# --- Returning arrays and hashes ---
sub analyze_numbers {
    my @nums = sort { $a <=> $b } @_;
    return (
        min   => $nums[0],
        max   => $nums[-1],
        count => scalar @nums,
        sum   => sum_all(@nums),
        avg   => sum_all(@nums) / scalar(@nums),
    );
}

my %stats = analyze_numbers(42, 17, 93, 5, 68, 31);
say "\nNumber analysis (42, 17, 93, 5, 68, 31):";
for my $key (qw(min max count sum avg)) {
    printf "  %-6s => %s\n", $key, $stats{$key};
}

# --- Subroutine references ---
sub apply {
    my ($func, @items) = @_;
    return map { $func->($_) } @items;
}

my @doubled = apply(sub { $_[0] * 2 }, 1, 2, 3, 4, 5);
say "\nDoubled: @doubled";

my @formatted = apply(sub { sprintf("[%03d]", $_[0]) }, 1, 20, 300);
say "Formatted: @formatted";

# --- Recursive subroutine ---
sub factorial {
    my ($n) = @_;
    return 1 if $n <= 1;
    return $n * factorial($n - 1);
}

say "\nFactorials:";
for my $n (1..10) {
    printf "  %2d! = %d\n", $n, factorial($n);
}

# --- Fibonacci with memoization ---
{
    my %cache;
    sub fibonacci {
        my ($n) = @_;
        return $n if $n <= 1;
        return $cache{$n} if exists $cache{$n};
        $cache{$n} = fibonacci($n - 1) + fibonacci($n - 2);
        return $cache{$n};
    }
}

say "\nFibonacci sequence:";
say join(", ", map { fibonacci($_) } 0..15);

# --- Closure: counter factory ---
sub make_counter {
    my ($start) = @_;
    $start //= 0;
    return sub { return ++$start };
}

my $counter_a = make_counter(0);
my $counter_b = make_counter(100);

say "\nCounter A: " . join(", ", map { $counter_a->() } 1..5);
say "Counter B: " . join(", ", map { $counter_b->() } 1..5);

# --- Dispatch table ---
my %operations = (
    add      => sub { $_[0] + $_[1] },
    subtract => sub { $_[0] - $_[1] },
    multiply => sub { $_[0] * $_[1] },
    divide   => sub { $_[1] != 0 ? $_[0] / $_[1] : "ERROR: div by zero" },
);

say "\nCalculator (dispatch table):";
for my $op (sort keys %operations) {
    my $result = $operations{$op}->(10, 3);
    printf "  10 %-8s 3 = %s\n", $op, $result;
}

say "\nDone!";
