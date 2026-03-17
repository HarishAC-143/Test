#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== CREATING ARRAYS ===";

my @empty = ();
my @nums = (1, 2, 3, 4, 5);
my @words = ("hello", "world", "perl");
my @mixed = (42, "text", 3.14, undef);
my @range = (1..10);
my @qw = qw(apple banana cherry date);    # quote-words shorthand

say "nums:  @nums";
say "words: @words";
say "range: @range";
say "qw:    @qw";

say "\n=== ACCESSING ELEMENTS ===";

say "First:  $qw[0]";
say "Third:  $qw[2]";
say "Last:   $qw[-1]";
say "Second-to-last: $qw[-2]";

say "\n=== ARRAY INFO ===";

say "Length (scalar):  " . scalar @qw;
say "Last index (\$#): $#qw";
say "Is empty: " . (@empty ? "no" : "yes");

say "\n=== ARRAY SLICES ===";

my @some = @qw[0, 2];
say "Slice [0,2]:   @some";

my @range_slice = @qw[1..3];
say "Slice [1..3]:  @range_slice";

say "\n=== MODIFYING ARRAYS ===";

my @stack = (1, 2, 3);

push @stack, 4, 5;
say "After push 4,5:     @stack";

my $popped = pop @stack;
say "After pop:           @stack (popped: $popped)";

unshift @stack, 0;
say "After unshift 0:     @stack";

my $shifted = shift @stack;
say "After shift:         @stack (shifted: $shifted)";

say "\n=== SPLICE ===";

my @letters = ('a'..'f');
say "Original:      @letters";

my @removed = splice(@letters, 2, 2);
say "After splice(2,2): @letters (removed: @removed)";

splice(@letters, 1, 0, 'X', 'Y');
say "After insert X,Y:  @letters";

splice(@letters, 3, 1, 'Z');
say "After replace [3]:  @letters";

say "\n=== SORTING ===";

my @fruits = qw(banana apple date cherry elderberry);

my @alpha = sort @fruits;
say "Alphabetical: @alpha";

my @rev_alpha = reverse sort @fruits;
say "Reverse:      @rev_alpha";

my @numbers = (42, 5, 17, 3, 99, 28);

my @num_asc = sort { $a <=> $b } @numbers;
say "Numeric asc:  @num_asc";

my @num_desc = sort { $b <=> $a } @numbers;
say "Numeric desc: @num_desc";

my @by_length = sort { length($a) <=> length($b) } @fruits;
say "By length:    @by_length";

say "\n=== MAP ===";

my @values = (1, 2, 3, 4, 5);

my @squared = map { $_ ** 2 } @values;
say "Squared:    @squared";

my @upper = map { uc($_) } @fruits;
say "Uppercase:  @upper";

my @formatted = map { sprintf("[%s]", $_) } @fruits;
say "Formatted:  @formatted";

say "\n=== GREP (filter) ===";

my @all_nums = (1..20);

my @evens = grep { $_ % 2 == 0 } @all_nums;
say "Evens:      @evens";

my @big = grep { $_ > 15 } @all_nums;
say "Greater 15: @big";

my @long_fruits = grep { length($_) > 5 } @fruits;
say "Long fruits: @long_fruits";

say "\n=== ARRAY AS STACK AND QUEUE ===";

# Stack (LIFO): push + pop
my @stack_demo = ();
push @stack_demo, "first";
push @stack_demo, "second";
push @stack_demo, "third";
say "Stack pop: " . pop @stack_demo;    # third
say "Stack pop: " . pop @stack_demo;    # second

# Queue (FIFO): push + shift
my @queue = ();
push @queue, "customer1";
push @queue, "customer2";
push @queue, "customer3";
say "Queue next: " . shift @queue;    # customer1
say "Queue next: " . shift @queue;    # customer2

say "\n=== UNIQUE ELEMENTS ===";

my @with_dupes = (1, 2, 3, 2, 4, 3, 5, 1);
my %seen;
my @unique = grep { !$seen{$_}++ } @with_dupes;
say "With dupes: @with_dupes";
say "Unique:     @unique";

say "\n=== JOINING AND STRINGIFYING ===";

my @csv_fields = ("Alice", 30, "Engineer");
say "CSV: " . join(",", @csv_fields);
say "TSV: " . join("\t", @csv_fields);
say "Readable: " . join(" | ", @csv_fields);

say "\n=== WANTARRAY — Context DETECTION ===";

sub context_demo {
    if (wantarray()) {
        return (1, 2, 3);
    } else {
        return "scalar context";
    }
}

my @list_result = context_demo();
my $scalar_result = context_demo();
say "List context:   @list_result";
say "Scalar context: $scalar_result";
