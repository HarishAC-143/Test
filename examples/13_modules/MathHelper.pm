package MathHelper;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(factorial fibonacci is_prime gcd lcm);

sub factorial {
    my ($n) = @_;
    return 1 if $n <= 1;
    return $n * factorial($n - 1);
}

sub fibonacci {
    my ($n) = @_;
    my @fib = (0, 1);
    for my $i (2..$n) {
        push @fib, $fib[-1] + $fib[-2];
    }
    return @fib[0..$n];
}

sub is_prime {
    my ($n) = @_;
    return 0 if $n < 2;
    return 1 if $n < 4;
    return 0 if $n % 2 == 0;
    for (my $i = 3; $i * $i <= $n; $i += 2) {
        return 0 if $n % $i == 0;
    }
    return 1;
}

sub gcd {
    my ($a, $b) = @_;
    ($a, $b) = ($b, $a % $b) while $b;
    return $a;
}

sub lcm {
    my ($a, $b) = @_;
    return ($a * $b) / gcd($a, $b);
}

1;
