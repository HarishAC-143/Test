#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Anonymous Subroutines, Closures, and Higher-Order Functions
# ============================================================

say "=== ANONYMOUS SUBROUTINES ===";

my $square = sub { return $_[0] ** 2 };
my $cube   = sub { return $_[0] ** 3 };

say "Square of 5: " . $square->(5);
say "Cube of 3:   " . $cube->(3);

say "\n=== CLOSURES ===";

sub make_counter {
    my $count = 0;
    return sub { return ++$count };
}

my $counter_a = make_counter();
my $counter_b = make_counter();

say "Counter A: " . $counter_a->(); # 1
say "Counter A: " . $counter_a->(); # 2
say "Counter A: " . $counter_a->(); # 3
say "Counter B: " . $counter_b->(); # 1 (independent)
say "Counter A: " . $counter_a->(); # 4

say "\n=== CLOSURE: MULTIPLIER FACTORY ===";

sub make_multiplier {
    my ($factor) = @_;
    return sub { return $_[0] * $factor };
}

my $double = make_multiplier(2);
my $triple = make_multiplier(3);
my $times10 = make_multiplier(10);

say "Double 7:  " . $double->(7);
say "Triple 7:  " . $triple->(7);
say "x10 of 7:  " . $times10->(7);

say "\n=== CLOSURE: ACCUMULATOR ===";

sub make_accumulator {
    my $total = 0;
    return {
        add   => sub { $total += $_[0]; return $total },
        total => sub { return $total },
        reset => sub { $total = 0; return $total },
    };
}

my $acc = make_accumulator();
$acc->{add}->(10);
$acc->{add}->(20);
$acc->{add}->(30);
say "Accumulator total: " . $acc->{total}->(); # 60
$acc->{reset}->();
say "After reset: " . $acc->{total}->(); # 0

say "\n=== HIGHER-ORDER FUNCTIONS ===";

sub apply_to_each {
    my ($func, @items) = @_;
    return map { $func->($_) } @items;
}

my @numbers = (1, 2, 3, 4, 5);

my @squares = apply_to_each(sub { $_[0] ** 2 }, @numbers);
say "Squares: @squares";

my @formatted = apply_to_each(sub { sprintf("[%02d]", $_[0]) }, @numbers);
say "Formatted: @formatted";

say "\n=== FUNCTION COMPOSITION ===";

sub compose {
    my @funcs = @_;
    return sub {
        my @args = @_;
        my $result;
        for my $func (reverse @funcs) {
            if (defined $result) {
                $result = $func->($result);
            } else {
                $result = $func->(@args);
            }
        }
        return $result;
    };
}

my $add1      = sub { $_[0] + 1 };
my $double_it = sub { $_[0] * 2 };
my $negate    = sub { -$_[0] };

my $transform = compose($negate, $double_it, $add1);
say "compose(negate, double, add1)(5) = " . $transform->(5); # -(2*(5+1)) = -12

say "\n=== DISPATCH TABLE ===";

my %operations = (
    add      => sub { $_[0] + $_[1] },
    subtract => sub { $_[0] - $_[1] },
    multiply => sub { $_[0] * $_[1] },
    divide   => sub { $_[1] != 0 ? $_[0] / $_[1] : "Error: div/0" },
    power    => sub { $_[0] ** $_[1] },
);

my @test_cases = (
    ["add",      10, 3],
    ["subtract", 10, 3],
    ["multiply", 10, 3],
    ["divide",   10, 3],
    ["power",    2,  8],
);

for my $test (@test_cases) {
    my ($op, $a, $b) = @$test;
    my $result = $operations{$op}->($a, $b);
    printf "  %-10s(%d, %d) = %s\n", $op, $a, $b, $result;
}

say "\n=== MEMOIZATION ===";

sub memoize_func {
    my ($func) = @_;
    my %cache;
    return sub {
        my $key = join(",", @_);
        unless (exists $cache{$key}) {
            $cache{$key} = $func->(@_);
        }
        return $cache{$key};
    };
}

my $slow_fib;
$slow_fib = sub {
    my ($n) = @_;
    return $n if $n <= 1;
    return $slow_fib->($n - 1) + $slow_fib->($n - 2);
};

my $fast_fib = memoize_func($slow_fib);

say "Fibonacci(10): " . $fast_fib->(10);
say "Fibonacci(15): " . $fast_fib->(15);
say "Fibonacci(20): " . $fast_fib->(20);

say "\n--- Closures demo complete ---";
