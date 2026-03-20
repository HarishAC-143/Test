package MathUtils;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    factorial
    fibonacci
    is_prime
    gcd
    lcm
    combinations
    permutations
);

our %EXPORT_TAGS = (
    all  => \@EXPORT_OK,
    basic => [qw(factorial fibonacci is_prime)],
    combinatorics => [qw(combinations permutations)],
);

sub factorial {
    my ($n) = @_;
    die "factorial requires non-negative integer\n" if $n < 0;
    my $result = 1;
    $result *= $_ for 2 .. $n;
    return $result;
}

sub fibonacci {
    my ($n) = @_;
    die "fibonacci requires non-negative integer\n" if $n < 0;
    my @seq = (0, 1);
    for my $i (2 .. $n) {
        push @seq, $seq[-1] + $seq[-2];
    }
    return @seq[0 .. $n];
}

sub is_prime {
    my ($n) = @_;
    return 0 if $n < 2;
    return 1 if $n < 4;
    return 0 if $n % 2 == 0;
    for (my $i = 3; $i <= int(sqrt($n)); $i += 2) {
        return 0 if $n % $i == 0;
    }
    return 1;
}

sub gcd {
    my ($a, $b) = @_;
    ($a, $b) = (abs($a), abs($b));
    while ($b) {
        ($a, $b) = ($b, $a % $b);
    }
    return $a;
}

sub lcm {
    my ($a, $b) = @_;
    return 0 if $a == 0 || $b == 0;
    return abs($a * $b) / gcd($a, $b);
}

sub combinations {
    my ($n, $k) = @_;
    return 0 if $k > $n || $k < 0;
    return 1 if $k == 0 || $k == $n;
    return factorial($n) / (factorial($k) * factorial($n - $k));
}

sub permutations {
    my ($n, $k) = @_;
    $k //= $n;
    return 0 if $k > $n || $k < 0;
    return factorial($n) / factorial($n - $k);
}

1;

__END__

=head1 NAME

MathUtils - A collection of common mathematical functions

=head1 SYNOPSIS

    use MathUtils qw(factorial fibonacci is_prime gcd lcm);

    print factorial(5);          # 120
    print is_prime(17);          # 1 (true)
    print gcd(12, 8);            # 4

=head1 DESCRIPTION

Provides basic math utilities for learning Perl modules.

=head1 EXPORTED FUNCTIONS

=head2 factorial($n)

Returns n! (n factorial).

=head2 fibonacci($n)

Returns the first n+1 Fibonacci numbers.

=head2 is_prime($n)

Returns 1 if n is prime, 0 otherwise.

=head2 gcd($a, $b)

Returns the greatest common divisor.

=head2 lcm($a, $b)

Returns the least common multiple.

=head2 combinations($n, $k)

Returns C(n,k) — "n choose k".

=head2 permutations($n, $k)

Returns P(n,k) — permutations of k items from n.

=cut
