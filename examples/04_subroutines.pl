#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- Functions, Closures, and Callbacks ---

say "=== BASIC SUBROUTINE ===";

sub greet {
    my ($name) = @_;
    return "Hello, $name!";
}

say greet("Alice");
say greet("Bob");

say "\n=== MULTIPLE PARAMETERS ===";

sub rectangle_area {
    my ($width, $height) = @_;
    return $width * $height;
}

printf "Area of 5x3 rectangle: %d\n", rectangle_area(5, 3);

say "\n=== DEFAULT PARAMETER VALUES ===";

sub create_user {
    my (%opts) = @_;
    my $name  = $opts{name}  // "Anonymous";
    my $role  = $opts{role}  // "viewer";
    my $level = $opts{level} // 1;
    return "User: $name, Role: $role, Level: $level";
}

say create_user(name => "Alice", role => "admin", level => 5);
say create_user(name => "Bob");
say create_user();

say "\n=== RETURNING MULTIPLE VALUES ===";

sub stats {
    my @nums = sort { $a <=> $b } @_;
    my $min = $nums[0];
    my $max = $nums[-1];
    my $sum = 0;
    $sum += $_ for @nums;
    my $avg = $sum / scalar(@nums);
    return ($min, $max, $avg, $sum);
}

my ($min, $max, $avg, $sum) = stats(23, 7, 42, 15, 31, 8);
printf "Min: %d, Max: %d, Avg: %.1f, Sum: %d\n", $min, $max, $avg, $sum;

say "\n=== VARIABLE ARGUMENTS ===";

sub sum_all {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}

say "sum_all(1..10) = " . sum_all(1 .. 10);

say "\n=== ANONYMOUS SUBROUTINES ===";

my $double = sub { return $_[0] * 2 };
my $square = sub { return $_[0] ** 2 };

say "double(7)  = " . $double->(7);
say "square(7)  = " . $square->(7);

say "\n=== CLOSURES ===";

sub make_counter {
    my $count = 0;
    return sub { return ++$count };
}

my $counter_a = make_counter();
my $counter_b = make_counter();

say "Counter A: " . $counter_a->();   # 1
say "Counter A: " . $counter_a->();   # 2
say "Counter A: " . $counter_a->();   # 3
say "Counter B: " . $counter_b->();   # 1 (independent)

say "\n=== CLOSURE: MULTIPLIER FACTORY ===";

sub make_multiplier {
    my ($factor) = @_;
    return sub { return $_[0] * $factor };
}

my $triple   = make_multiplier(3);
my $quadruple = make_multiplier(4);

say "triple(10)    = " . $triple->(10);
say "quadruple(10) = " . $quadruple->(10);

say "\n=== CALLBACKS (Higher-Order Functions) ===";

sub apply_to_list {
    my ($func, @list) = @_;
    return map { $func->($_) } @list;
}

my @numbers = (1, 2, 3, 4, 5);
my @doubled = apply_to_list(sub { $_[0] * 2 }, @numbers);
my @squared = apply_to_list($square, @numbers);

say "Original: @numbers";
say "Doubled : @doubled";
say "Squared : @squared";

say "\n=== RECURSIVE SUBROUTINE ===";

sub factorial {
    my ($n) = @_;
    return 1 if $n <= 1;
    return $n * factorial($n - 1);
}

for my $n (1 .. 10) {
    printf "%2d! = %d\n", $n, factorial($n);
}

say "\n=== DISPATCH TABLE ===";

my %operations = (
    add      => sub { $_[0] + $_[1] },
    subtract => sub { $_[0] - $_[1] },
    multiply => sub { $_[0] * $_[1] },
    divide   => sub { $_[1] != 0 ? $_[0] / $_[1] : "ERROR: div by zero" },
);

my @ops = qw(add subtract multiply divide);
for my $op (@ops) {
    printf "  %-10s 20, 5 = %s\n", "$op:", $operations{$op}->(20, 5);
}

say "\nDone!";
