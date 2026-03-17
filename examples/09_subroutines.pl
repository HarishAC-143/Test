#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== BASIC SUBROUTINES ===";

sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

say greet("Alice");
say greet("Bob");

say "\n=== MULTIPLE PARAMETERS ===";

sub add {
    my ($a, $b) = @_;
    return $a + $b;
}

say "3 + 5 = " . add(3, 5);

say "\n=== MULTIPLE RETURN VALUES ===";

sub min_max {
    my @nums = @_;
    my $min = $nums[0];
    my $max = $nums[0];
    for my $n (@nums) {
        $min = $n if $n < $min;
        $max = $n if $n > $max;
    }
    return ($min, $max);
}

my ($min, $max) = min_max(42, 17, 93, 5, 68);
say "Min: $min, Max: $max";

say "\n=== DEFAULT PARAMETERS ===";

sub create_user {
    my (%args) = @_;
    my $name  = $args{name}  // "Anonymous";
    my $role  = $args{role}  // "viewer";
    my $email = $args{email} // "none";

    return "User: $name (role: $role, email: $email)";
}

say create_user(name => "Alice", role => "admin", email => "alice\@example.com");
say create_user(name => "Bob");
say create_user();

say "\n=== VARIABLE NUMBER OF ARGUMENTS ===";

sub sum_all {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}

say "Sum of 1..5:  " . sum_all(1, 2, 3, 4, 5);
say "Sum of 10,20: " . sum_all(10, 20);

say "\n=== SUBROUTINE REFERENCES ===";

my $multiply = sub {
    my ($a, $b) = @_;
    return $a * $b;
};

say "4 * 7 = " . $multiply->(4, 7);

sub apply {
    my ($func, $a, $b) = @_;
    return $func->($a, $b);
}

my $add_ref = sub { $_[0] + $_[1] };
my $sub_ref = sub { $_[0] - $_[1] };

say "apply(add, 10, 3) = " . apply($add_ref, 10, 3);
say "apply(sub, 10, 3) = " . apply($sub_ref, 10, 3);

say "\n=== CLOSURES ===";

sub make_counter {
    my $count = 0;
    return {
        increment => sub { ++$count },
        decrement => sub { --$count },
        value     => sub { $count },
    };
}

my $counter = make_counter();
$counter->{increment}->();
$counter->{increment}->();
$counter->{increment}->();
$counter->{decrement}->();
say "Counter value: " . $counter->{value}->();    # 2

say "\n=== HIGHER-ORDER FUNCTIONS ===";

sub transform_list {
    my ($func, @list) = @_;
    return map { $func->($_) } @list;
}

my @nums = (1, 2, 3, 4, 5);

my @doubled = transform_list(sub { $_ [0] * 2 }, @nums);
say "Doubled:  @doubled";

my @squared = transform_list(sub { $_[0] ** 2 }, @nums);
say "Squared:  @squared";

my @negated = transform_list(sub { -$_[0] }, @nums);
say "Negated:  @negated";

say "\n=== RECURSIVE SUBROUTINES ===";

sub factorial {
    my ($n) = @_;
    return 1 if $n <= 1;
    return $n * factorial($n - 1);
}

for my $i (1..8) {
    printf "%d! = %d\n", $i, factorial($i);
}

say "\n=== FIBONACCI SEQUENCE ===";

sub fibonacci {
    my ($n) = @_;
    my @fib = (0, 1);
    for my $i (2..$n) {
        push @fib, $fib[-1] + $fib[-2];
    }
    return @fib;
}

my @fib = fibonacci(12);
say "Fibonacci: " . join(", ", @fib);

say "\n=== PROTOTYPES (use sparingly) ===";

sub max_of_two ($$) {
    my ($a, $b) = @_;
    return $a > $b ? $a : $b;
}

say "max_of_two(3, 7) = " . max_of_two(3, 7);

say "\n=== DISPATCH TABLE ===";

my %operations = (
    add      => sub { $_[0] + $_[1] },
    subtract => sub { $_[0] - $_[1] },
    multiply => sub { $_[0] * $_[1] },
    divide   => sub { $_[1] != 0 ? $_[0] / $_[1] : "Error: divide by zero" },
);

for my $op (sort keys %operations) {
    my $result = $operations{$op}->(20, 4);
    printf "  %-10s 20, 4 = %s\n", $op, $result;
}
