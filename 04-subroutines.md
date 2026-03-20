# Chapter 4: Subroutines

Subroutines (also called functions) are reusable blocks of code. In Perl, subroutines are defined with the `sub` keyword.

## Defining and Calling Subroutines

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Define a subroutine
sub greet {
    print "Hello, World!\n";
}

# Call it
greet();
```

## Parameters and Arguments

Arguments are passed via the special array `@_`. You should unpack them at the top of the subroutine.

```perl
sub greet_user {
    my ($name) = @_;
    print "Hello, $name!\n";
}

greet_user("Alice");    # Hello, Alice!

# Multiple parameters
sub add {
    my ($a, $b) = @_;
    return $a + $b;
}

my $sum = add(3, 7);
print "Sum: $sum\n";    # Sum: 10

# You can also access @_ directly (but unpacking is preferred)
sub multiply {
    return $_[0] * $_[1];
}
```

### Default Parameter Values

```perl
sub connect_db {
    my (%args) = @_;
    my $host = $args{host} // "localhost";
    my $port = $args{port} // 5432;
    my $db   = $args{database} // "myapp";

    print "Connecting to $db on $host:$port\n";
}

connect_db(database => "production", host => "db.example.com");
# Output: Connecting to production on db.example.com:5432

connect_db();
# Output: Connecting to myapp on localhost:5432
```

### Variable-Length Argument Lists

```perl
sub sum_all {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}

print sum_all(1, 2, 3, 4, 5), "\n";   # 15
print sum_all(10, 20), "\n";           # 30
```

## Return Values

Subroutines return the value of the last expression evaluated, or you can use `return` explicitly.

```perl
sub max_val {
    my ($a, $b) = @_;
    return $a if $a > $b;
    return $b;
}

print max_val(10, 20), "\n";   # 20

# Returning multiple values
sub min_max {
    my @nums = sort { $a <=> $b } @_;
    return ($nums[0], $nums[-1]);
}

my ($min, $max) = min_max(4, 7, 2, 9, 1);
print "Min: $min, Max: $max\n";   # Min: 1, Max: 9

# Returning a hash
sub get_config {
    return (
        host    => "localhost",
        port    => 8080,
        debug   => 1,
    );
}

my %config = get_config();
print "Port: $config{port}\n";
```

## Scope and Lexical Variables

### my — Lexical Scope

Variables declared with `my` are visible only within the enclosing block.

```perl
my $global = "I'm at file scope";

sub demo_scope {
    my $local = "I'm inside the sub";
    print "$global\n";    # accessible
    print "$local\n";     # accessible

    if (1) {
        my $inner = "I'm inside the if block";
        print "$inner\n"; # accessible
    }
    # print "$inner\n";   # ERROR: $inner is out of scope
}

demo_scope();
# print "$local\n";       # ERROR: $local is out of scope
```

### local — Dynamic Scope

`local` temporarily overrides a global variable's value for the current scope and any subroutines called from it.

```perl
our $separator = ", ";

sub format_list {
    return join($separator, @_);
}

sub format_csv {
    local $separator = ";";    # temporarily override
    return format_list(@_);    # format_list sees ";"
}

print format_list("a", "b", "c"), "\n";   # a, b, c
print format_csv("a", "b", "c"), "\n";    # a;b;c
print format_list("a", "b", "c"), "\n";   # a, b, c  (restored)
```

### state — Persistent Lexical Variables

`state` variables retain their value between subroutine calls (like `static` in C).

```perl
use feature 'state';

sub counter {
    state $count = 0;
    $count++;
    return $count;
}

print counter(), "\n";   # 1
print counter(), "\n";   # 2
print counter(), "\n";   # 3
```

## Subroutine References

Subroutines can be referenced, stored in variables, and passed as arguments.

```perl
# Creating a reference to a named subroutine
sub square { return $_[0] ** 2 }
my $sq_ref = \&square;

# Calling through a reference
print $sq_ref->(5), "\n";    # 25

# Anonymous subroutines (closures)
my $cube = sub { return $_[0] ** 3 };
print $cube->(3), "\n";      # 27

# Passing subroutines as arguments
sub apply {
    my ($func, @values) = @_;
    return map { $func->($_) } @values;
}

my @squares = apply(\&square, 1, 2, 3, 4, 5);
print "@squares\n";   # 1 4 9 16 25

my @cubed = apply($cube, 1, 2, 3);
print "@cubed\n";     # 1 8 27
```

## Closures

A closure is an anonymous subroutine that captures variables from its enclosing scope.

```perl
sub make_multiplier {
    my ($factor) = @_;
    return sub {
        my ($n) = @_;
        return $n * $factor;
    };
}

my $double = make_multiplier(2);
my $triple = make_multiplier(3);

print $double->(5), "\n";   # 10
print $triple->(5), "\n";   # 15

# Closure as a counter with state
sub make_counter {
    my $count = 0;
    return {
        increment => sub { ++$count },
        decrement => sub { --$count },
        value     => sub { $count },
    };
}

my $c = make_counter();
$c->{increment}->();
$c->{increment}->();
$c->{increment}->();
$c->{decrement}->();
print "Counter: ", $c->{value}->(), "\n";   # Counter: 2
```

## Dispatch Tables

A hash of subroutine references creates a powerful dispatch table — an elegant alternative to long if/elsif chains.

```perl
my %operations = (
    add      => sub { $_[0] + $_[1] },
    subtract => sub { $_[0] - $_[1] },
    multiply => sub { $_[0] * $_[1] },
    divide   => sub { $_[1] != 0 ? $_[0] / $_[1] : "Error: division by zero" },
);

my $op = "multiply";
my $result = $operations{$op}->(6, 7);
print "$op: $result\n";   # multiply: 42

# Interactive calculator using dispatch table
sub calculate {
    my ($op, $a, $b) = @_;
    if (exists $operations{$op}) {
        return $operations{$op}->($a, $b);
    }
    return "Unknown operation: $op";
}

print calculate("add", 10, 20), "\n";       # 30
print calculate("divide", 10, 3), "\n";     # 3.33333333333333
print calculate("divide", 10, 0), "\n";     # Error: division by zero
```

## Prototypes

Prototypes hint at how a subroutine should be called. They are rarely needed but useful in some cases.

```perl
sub mysub ($) {    # expects exactly one scalar
    my ($arg) = @_;
    print "Got: $arg\n";
}

sub mysum (\@) {   # expects an array reference
    my ($arr_ref) = @_;
    my $total = 0;
    $total += $_ for @$arr_ref;
    return $total;
}

my @nums = (1, 2, 3, 4, 5);
print mysum(@nums), "\n";   # 15 — @nums is automatically passed as reference
```

> **Note**: Prototypes are a compile-time feature and don't work on method calls or references. Most modern Perl code avoids prototypes in favor of explicit argument handling.

## Practical Example: Text Statistics

```perl
#!/usr/bin/perl
use strict;
use warnings;

sub analyze_text {
    my ($text) = @_;

    my @words      = split(/\s+/, $text);
    my @sentences   = split(/[.!?]+/, $text);
    my @paragraphs  = split(/\n\n+/, $text);

    my %word_freq;
    $word_freq{lc $_}++ for @words;

    my @top_words = (sort { $word_freq{$b} <=> $word_freq{$a} } keys %word_freq)[0..4];

    return {
        word_count      => scalar @words,
        sentence_count  => scalar @sentences,
        paragraph_count => scalar @paragraphs,
        avg_word_length => _avg_length(\@words),
        top_words       => \@top_words,
        word_freq       => \%word_freq,
    };
}

sub _avg_length {
    my ($words_ref) = @_;
    return 0 unless @$words_ref;
    my $total = 0;
    $total += length($_) for @$words_ref;
    return sprintf("%.1f", $total / scalar @$words_ref);
}

my $sample = "Perl is a powerful language. Perl is used for text processing. "
           . "Perl has great regular expressions. The community loves Perl.";

my $stats = analyze_text($sample);

print "Word count: $stats->{word_count}\n";
print "Sentence count: $stats->{sentence_count}\n";
print "Avg word length: $stats->{avg_word_length}\n";
print "Top words: ", join(", ", @{$stats->{top_words}}), "\n";
```

## Chapter Summary

- Subroutines are defined with `sub` and called by name.
- Arguments arrive in the `@_` array; unpack them with `my (...) = @_`.
- Use `my` for lexical scope, `local` for temporary dynamic overrides, and `state` for persistent values.
- Subroutine references and anonymous subs enable powerful patterns like closures and dispatch tables.
- Return multiple values as lists; return complex data as references (covered in detail in Chapter 6).

---

**Previous**: [Chapter 3 — Operators and Control Structures](03-operators-and-control-structures.md)
**Next**: [Chapter 5 — Regular Expressions](05-regular-expressions.md)
